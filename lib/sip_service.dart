import 'package:flutter/foundation.dart';

import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sip_ua/sip_ua.dart';

import 'api.dart';

class SipService extends ChangeNotifier implements SipUaHelperListener {
  SipService._() {
    helper.addSipUaHelperListener(this);
    _rendererReady = _remoteRenderer.initialize();
    _platform.setMethodCallHandler((call) async {
      if (call.method == 'answerCall') await answer();
      if (call.method == 'rejectCall') reject();
    });
  }
  static final instance = SipService._();
  final SIPUAHelper helper = SIPUAHelper();
  static const _platform = MethodChannel('com.dfw.communication/native');
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  late final Future<void> _rendererReady;
  Map<String, dynamic>? config;
  RegistrationStateEnum registration = RegistrationStateEnum.NONE;
  TransportStateEnum transport = TransportStateEnum.NONE;
  Call? activeCall;
  CallStateEnum callState = CallStateEnum.NONE;
  String? error;
  bool muted = false, held = false, speaker = false;
  bool answering = false;
  int durationSeconds = 0;
  Timer? _durationTimer;
  bool _ending = false;

  bool get registered => registration == RegistrationStateEnum.REGISTERED;
  bool get _incomingPending =>
      activeCall?.direction == Direction.incoming &&
      (callState == CallStateEnum.CALL_INITIATION ||
          callState == CallStateEnum.PROGRESS);
  bool get incoming => _incomingPending && !answering;
  bool get connected =>
      callState == CallStateEnum.ACCEPTED ||
      callState == CallStateEnum.CONFIRMED ||
      callState == CallStateEnum.STREAM;
  bool get inCall =>
      activeCall != null &&
      callState != CallStateEnum.ENDED &&
      callState != CallStateEnum.FAILED;
  String get status => switch (registration) {
    RegistrationStateEnum.REGISTERED => 'Registered',
    RegistrationStateEnum.REGISTRATION_FAILED => 'Registration failed',
    RegistrationStateEnum.UNREGISTERED => 'Disconnected',
    _ => transport == TransportStateEnum.CONNECTING ? 'Connecting…' : 'Offline',
  };

  Future<void> initialize({bool force = false}) async {
    if (inCall) return;
    if (!force && (registered || transport == TransportStateEnum.CONNECTING)) {
      return;
    }
    error = null;
    notifyListeners();
    try {
      final response = await ApiService.instance.get('api/phone/config');
      config = response is Map
          ? Map<String, dynamic>.from(response['config'] ?? {})
          : null;
      if (config == null || config!.isEmpty || config!['enabled'] == false) {
        error = 'No enabled phone extension is assigned.';
        notifyListeners();
        return;
      }
      final domain = config!['sipDomain']?.toString() ?? '';
      final extension = config!['extension']?.toString() ?? '';
      final settings = UaSettings()
        ..transportType = TransportType.WS
        ..webSocketUrl = config!['websocketUrl']?.toString()
        ..uri = '$extension@$domain'
        ..host = domain
        ..authorizationUser =
            config!['authorizationUser']?.toString() ?? extension
        ..password = config!['password']?.toString()
        ..displayName = config!['displayName']?.toString() ?? extension
        ..userAgent = 'DFW Communication Android'
        ..dtmfMode = DtmfMode.RFC2833
        ..iceGatheringTimeout = 5000
        ..iceServers = <Map<String, String>>[
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun.cloudflare.com:3478'},
        ]
        ..logCallStatistics = true;
      settings.webSocketSettings.allowBadCertificate = false;
      await helper.start(settings);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> call(String number) async {
    if (inCall) {
      error = 'Another call is already active.';
      notifyListeners();
      return false;
    }
    if (!registered) {
      await initialize(force: true);
    }
    if (!registered) {
      error = 'Phone is not registered with the PBX.';
      notifyListeners();
      return false;
    }
    if (await Permission.microphone.request() != PermissionStatus.granted) {
      error = 'Microphone permission is required for calls.';
      notifyListeners();
      return false;
    }
    try {
      final stream = await _createAudioStream();
      final domain = config!['sipDomain'];
      return await helper.call(
        'sip:$number@$domain',
        voiceOnly: true,
        mediaStream: stream,
      );
    } catch (e) {
      error = 'Unable to start call: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> answer() async {
    final call = activeCall;
    if (call == null || !incoming || answering) return false;
    answering = true;
    error = null;
    debugPrint(
      '[SIP call=${call.id ?? 'unknown'}] Answer requested; state=${callState.name}',
    );
    notifyListeners();
    if (await Permission.microphone.request() != PermissionStatus.granted) {
      error = 'Microphone permission is required to answer calls.';
      answering = false;
      notifyListeners();
      return false;
    }
    try {
      await _platform.invokeMethod('stopRinging');
      await _platform.invokeMethod('startCallAudio');
      debugPrint(
        '[SIP call=${call.id ?? 'unknown'}] Creating microphone stream',
      );
      final stream = await _createAudioStream();
      if (!identical(activeCall, call) || !_incomingPending) {
        for (final track in stream.getTracks()) {
          track.stop();
        }
        throw StateError('Incoming call ended before it could be answered.');
      }
      debugPrint('[SIP call=${call.id ?? 'unknown'}] Invoking SIP answer');
      call.answer(helper.buildCallOptions(true), mediaStream: stream);
      await Helper.setSpeakerphoneOn(false);
      return true;
    } catch (e) {
      error = 'Unable to answer call: $e';
      answering = false;
      await _platform.invokeMethod('stopCallAudio');
      debugPrint('[SIP call=${call.id ?? 'unknown'}] Answer failed: $e');
      notifyListeners();
      return false;
    }
  }

  void reject() {
    final call = activeCall;
    if (call == null || !incoming) return;
    _platform.invokeMethod('stopRinging');
    call.hangup({'status_code': 486, 'reason_phrase': 'Busy Here'});
  }

  void hangup() {
    final call = activeCall;
    if (call == null || _ending) return;
    _ending = true;
    try {
      call.hangup();
    } finally {
      Future.delayed(const Duration(seconds: 2), () => _ending = false);
    }
  }

  void toggleMute() {
    if (activeCall == null || !connected) return;
    muted ? activeCall!.unmute(true, false) : activeCall!.mute(true, false);
    muted = !muted;
    notifyListeners();
  }

  void toggleHold() {
    if (activeCall == null || !connected) return;
    held ? activeCall!.unhold() : activeCall!.hold();
    held = !held;
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    if (!inCall) return;
    final next = !speaker;
    try {
      await Helper.setSpeakerphoneOn(next);
      speaker = next;
      notifyListeners();
    } catch (e) {
      error = 'Unable to change audio output: $e';
      notifyListeners();
    }
  }

  bool sendDtmf(String digit) {
    if (!RegExp(r'^[0-9*#]$').hasMatch(digit)) return false;
    final call = activeCall;
    if (call == null || !connected || _ending) return false;
    try {
      call.sendDTMF(digit, {'duration': 160, 'interToneGap': 90});
      return true;
    } catch (e) {
      error = 'DTMF failed: $e';
      notifyListeners();
      return false;
    }
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    registration = state.state ?? RegistrationStateEnum.NONE;
    if (registration == RegistrationStateEnum.REGISTRATION_FAILED) {
      error =
          'PBX registration failed: ${state.cause ?? 'check extension settings'}';
    }
    notifyListeners();
  }

  @override
  void transportStateChanged(TransportState state) {
    transport = state.state;
    notifyListeners();
  }

  @override
  void callStateChanged(Call call, CallState state) {
    if (activeCall != null && !identical(activeCall, call) && inCall) {
      return;
    }
    activeCall = call;
    callState = state.state;
    debugPrint(
      '[SIP call=${call.id ?? 'unknown'} direction=${call.direction?.name ?? 'unknown'}] '
      'State=${state.state.name} originator=${state.originator?.name ?? 'none'} '
      'cause=${state.cause ?? 'none'}',
    );
    if (state.state == CallStateEnum.CALL_INITIATION &&
        call.direction == Direction.incoming) {
      _platform.invokeMethod('startRinging', {
        'caller': call.remote_identity ?? 'Unknown caller',
      });
    }
    if (state.state == CallStateEnum.STREAM && state.stream != null) {
      if (state.originator == Originator.remote) {
        _attachRemoteStream(state.stream!);
      } else if (state.originator == Originator.local) {
        for (final track in state.stream!.getAudioTracks()) {
          track.enabled = true;
          track.enableSpeakerphone(false);
        }
      }
    }
    if (state.state == CallStateEnum.ACCEPTED ||
        state.state == CallStateEnum.CONFIRMED) {
      answering = false;
      _platform.invokeMethod('stopRinging');
      _platform.invokeMethod('startCallAudio');
      Helper.setSpeakerphoneOn(false).catchError((_) {});
      _startDuration();
    }
    if (state.state == CallStateEnum.ENDED ||
        state.state == CallStateEnum.FAILED) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (identical(activeCall, call)) activeCall = null;
        _durationTimer?.cancel();
        _platform.invokeMethod('stopRinging');
        _platform.invokeMethod('stopCallAudio');
        _remoteRenderer.srcObject = null;
        muted = held = speaker = false;
        answering = false;
        Helper.setSpeakerphoneOn(false).catchError((_) {});
        durationSeconds = 0;
        _ending = false;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void _startDuration() {
    if (_durationTimer?.isActive == true) return;
    durationSeconds = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!connected) return;
      durationSeconds++;
      notifyListeners();
    });
  }

  Future<void> _attachRemoteStream(MediaStream stream) async {
    await _rendererReady;
    _remoteRenderer.srcObject = stream;
    for (final track in stream.getAudioTracks()) {
      track.enabled = true;
    }
  }

  Future<MediaStream> _createAudioStream() =>
      navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });

  @override
  void onNewMessage(SIPMessageRequest msg) {}
  @override
  void onNewNotify(Notify ntf) {}
  @override
  void onNewReinvite(ReInvite event) {}
}
