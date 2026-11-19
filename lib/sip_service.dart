import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sip_ua/sip_ua.dart';

import 'api.dart';

class SipService extends ChangeNotifier implements SipUaHelperListener {
  SipService._() {
    helper.addSipUaHelperListener(this);
  }
  static final instance = SipService._();
  final SIPUAHelper helper = SIPUAHelper();
  Map<String, dynamic>? config;
  RegistrationStateEnum registration = RegistrationStateEnum.NONE;
  TransportStateEnum transport = TransportStateEnum.NONE;
  Call? activeCall;
  CallStateEnum callState = CallStateEnum.NONE;
  String? error;
  bool muted = false, held = false, speaker = false;

  bool get registered => registration == RegistrationStateEnum.REGISTERED;
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
        ..contact_uri = 'sip:$extension@$domain';
      settings.webSocketSettings.allowBadCertificate = false;
      await helper.start(settings);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> call(String number) async {
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
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
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

  void hangup() => activeCall?.hangup();
  void toggleMute() {
    if (activeCall == null) return;
    muted ? activeCall!.unmute(true, false) : activeCall!.mute(true, false);
    muted = !muted;
    notifyListeners();
  }

  void toggleHold() {
    if (activeCall == null) return;
    held ? activeCall!.unhold() : activeCall!.hold();
    held = !held;
    notifyListeners();
  }

  void sendDtmf(String digit) => activeCall?.sendDTMF(digit);

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
    activeCall = call;
    callState = state.state;
    if (state.state == CallStateEnum.ENDED ||
        state.state == CallStateEnum.FAILED) {
      Future.delayed(const Duration(milliseconds: 500), () {
        activeCall = null;
        muted = held = false;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {}
  @override
  void onNewNotify(Notify ntf) {}
  @override
  void onNewReinvite(ReInvite event) {}
}
