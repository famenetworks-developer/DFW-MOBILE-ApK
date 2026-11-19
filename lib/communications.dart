import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import 'api.dart';
import 'sip_service.dart';

const _mint = Color(0xff38d6b0),
    _panel = Color(0xff12252d),
    _line = Color(0xff294049);

class SmsHome extends StatefulWidget {
  const SmsHome({super.key});
  @override
  State<SmsHome> createState() => _SmsHomeState();
}

class _SmsHomeState extends State<SmsHome> {
  late Future<dynamic> _numbers;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _numbers = ApiService.instance.get('sms-api/numbers');
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Text messages',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      actions: [
        IconButton(
          onPressed: () => setState(_load),
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          onPressed: () => _newSms(context),
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: FutureBuilder<dynamic>(
      future: _numbers,
      builder: (context, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) return _Error('${s.error}', () => setState(_load));
        final numbers = List<Map<String, dynamic>>.from(
          ((s.data as Map?)?['numbers'] ?? []).map(
            (e) => Map<String, dynamic>.from(e),
          ),
        );
        if (numbers.isEmpty) {
          return const Center(
            child: Text('No SMS business numbers are assigned.'),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Choose a business number',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ...numbers.map(
              (n) => Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xff195347),
                    child: Icon(Icons.sms_outlined, color: _mint),
                  ),
                  title: Text(
                    '${n['business'] ?? n['label'] ?? 'Business SMS'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('${n['label'] ?? ''}  ${n['e164'] ?? ''}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SmsThreads(number: n)),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
  Future<void> _newSms(BuildContext context) async {
    try {
      final data = await _numbers;
      final numbers = List<Map<String, dynamic>>.from(
        ((data as Map)['numbers'] ?? []).map(
          (e) => Map<String, dynamic>.from(e),
        ),
      );
      if (!context.mounted) return;
      if (numbers.isEmpty) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => NewSmsSheet(numbers: numbers),
      );
    } catch (_) {}
  }
}

class SmsThreads extends StatefulWidget {
  const SmsThreads({super.key, required this.number});
  final Map<String, dynamic> number;
  @override
  State<SmsThreads> createState() => _SmsThreadsState();
}

class _SmsThreadsState extends State<SmsThreads> {
  late Future<dynamic> _threads;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _load() => _threads = ApiService.instance.get(
    'sms-api/conversations',
    query: {'number_id': widget.number['id'], 'limit': 100},
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.number['business'] ?? widget.number['label'] ?? 'SMS'}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            '${widget.number['e164'] ?? ''}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => setState(_load),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<dynamic>(
      future: _threads,
      builder: (context, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) return _Error('${s.error}', () => setState(_load));
        final rows = List<Map<String, dynamic>>.from(
          ((s.data as Map?)?['conversations'] ?? []).map(
            (e) => Map<String, dynamic>.from(e),
          ),
        );
        if (rows.isEmpty) {
          return const Center(child: Text('No text conversations yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(10),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(color: _line, height: 1),
          itemBuilder: (context, i) {
            final x = rows[i];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              leading: const CircleAvatar(
                backgroundColor: _mint,
                child: Icon(Icons.person_outline, color: Colors.black),
              ),
              title: Text(
                '${x['counterparty'] ?? 'Unknown number'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${x['last_message'] ?? 'Message content unavailable'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: (x['unread_count'] ?? 0) > 0
                  ? Badge(label: Text('${x['unread_count']}'))
                  : const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SmsConversation(number: widget.number, thread: x),
                  ),
                );
                if (mounted) setState(_load);
              },
            );
          },
        );
      },
    ),
  );
}

class SmsConversation extends StatefulWidget {
  const SmsConversation({
    super.key,
    required this.number,
    required this.thread,
  });
  final Map<String, dynamic> number, thread;
  @override
  State<SmsConversation> createState() => _SmsConversationState();
}

class _SmsConversationState extends State<SmsConversation> {
  final draft = TextEditingController();
  late Future<dynamic> _messages;
  bool sending = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  void _load() => _messages = ApiService.instance.get(
    'sms-api/conversations/${widget.thread['id']}/messages',
    query: {'limit': 100},
  );
  Future<void> send() async {
    final body = draft.text.trim();
    if (body.isEmpty || sending || widget.thread['is_suppressed'] == true) {
      return;
    }
    setState(() => sending = true);
    try {
      await ApiService.instance.post(
        'sms-api/conversations/${widget.thread['id']}/reply',
        data: {'text': body},
        idempotent: true,
      );
      draft.clear();
      setState(_load);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.thread['counterparty'] ?? 'Conversation'}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            'From ${widget.number['e164'] ?? ''}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
    body: Column(
      children: [
        Expanded(
          child: FutureBuilder<dynamic>(
            future: _messages,
            builder: (context, s) {
              if (s.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (s.hasError) {
                return _Error('${s.error}', () => setState(_load));
              }
              final items = List<Map<String, dynamic>>.from(
                ((s.data as Map?)?['messages'] ?? []).map(
                  (e) => Map<String, dynamic>.from(e),
                ),
              );
              if (items.isNotEmpty) {
                final last = items.last['id'];
                ApiService.instance.post(
                  'sms-api/conversations/${widget.thread['id']}/read',
                  data: {'through_id': '$last'},
                );
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(14),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final m = items[items.length - 1 - i],
                      out = m['direction'] == 'out';
                  return Align(
                    alignment: out
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.all(13),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * .8,
                      ),
                      decoration: BoxDecoration(
                        color: out ? const Color(0xff167762) : _panel,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${m['body'] ?? ''}',
                            style: TextStyle(
                              fontSize: 16,
                              color: out ? Colors.white : null,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${m['status'] ?? ''}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (widget.thread['is_suppressed'] == true)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'This recipient opted out. Sending is disabled.',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft,
                    maxLines: 4,
                    minLines: 1,
                    enabled: widget.thread['is_suppressed'] != true,
                    onSubmitted: (_) => send(),
                    decoration: const InputDecoration(
                      hintText: 'Write a text message',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: sending ? null : send,
                  icon: sending
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class NewSmsSheet extends StatefulWidget {
  const NewSmsSheet({super.key, required this.numbers});
  final List<Map<String, dynamic>> numbers;
  @override
  State<NewSmsSheet> createState() => _NewSmsSheetState();
}

class _NewSmsSheetState extends State<NewSmsSheet> {
  late Map<String, dynamic> number = widget.numbers.first;
  final phone = TextEditingController(), text = TextEditingController();
  bool busy = false;
  Future<void> send() async {
    final p = phone.text.trim(), body = text.text.trim();
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(p) || body.isEmpty) return;
    setState(() => busy = true);
    try {
      await ApiService.instance.post(
        'sms-api/conversations',
        data: {'number_id': number['id'], 'recipient_phone': p, 'text': body},
        idempotent: true,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'New text message',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<Map<String, dynamic>>(
          initialValue: number,
          items: widget.numbers
              .map(
                (n) => DropdownMenuItem(
                  value: n,
                  child: Text('${n['business'] ?? n['label']} · ${n['e164']}'),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => number = v!),
          decoration: const InputDecoration(labelText: 'Sending number'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Recipient',
            hintText: '+15551234567',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: text,
          maxLines: 4,
          maxLength: 2048,
          decoration: const InputDecoration(labelText: 'Message'),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: busy ? null : send,
          child: busy
              ? const CircularProgressIndicator()
              : const Text('Send text message'),
        ),
      ],
    ),
  );
}

class Calls extends StatefulWidget {
  const Calls({super.key});
  @override
  State<Calls> createState() => _CallsState();
}

class _CallsState extends State<Calls> {
  late Future<dynamic> _calls;
  final sip = SipService.instance;
  @override
  void initState() {
    super.initState();
    _load();
    sip.addListener(_changed);
    sip.initialize();
  }

  @override
  void dispose() {
    sip.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _load() => _calls = ApiService.instance.get(
    'api/phone/calls',
    query: {'limit': 100},
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Calls', style: TextStyle(fontWeight: FontWeight.w700)),
      actions: [
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const IphoneDialer()),
          ),
          icon: const Icon(Icons.dialpad),
        ),
      ],
    ),
    body: FutureBuilder<dynamic>(
      future: _calls,
      builder: (context, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) return _Error('${s.error}', () => setState(_load));
        final data = s.data as Map? ?? {},
            rows = List<Map<String, dynamic>>.from(
              (data['calls'] ?? []).map((e) => Map<String, dynamic>.from(e)),
            );
        return RefreshIndicator(
          onRefresh: () async => setState(_load),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: CircleAvatar(
                    backgroundColor: (sip.registered ? _mint : Colors.orange)
                        .withValues(alpha: .2),
                    child: Icon(
                      Icons.phone_in_talk,
                      color: sip.registered ? _mint : Colors.orange,
                    ),
                  ),
                  title: Text(
                    sip.config == null
                        ? 'Phone extension'
                        : 'Extension ${sip.config!['extension']}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(sip.error ?? sip.status),
                  trailing: IconButton(
                    onPressed: () => sip.initialize(force: true),
                    icon: const Icon(Icons.sync),
                  ),
                ),
              ),
              if (sip.inCall)
                Card(
                  color: const Color(0xff174a40),
                  child: ListTile(
                    title: Text(
                      sip.activeCall?.remote_identity ?? 'Active call',
                    ),
                    subtitle: Text(sip.callState.name),
                    trailing: IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: sip.hangup,
                      icon: const Icon(Icons.call_end),
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              const Text(
                'Recent calls',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: Text('No call history')),
                ),
              ...rows.map((x) {
                final number = '${x['number'] ?? 'Unknown'}';
                return ListTile(
                  leading: Icon(
                    x['direction'] == 'inbound'
                        ? Icons.call_received
                        : Icons.call_made,
                    color: x['outcome'] == 'answered'
                        ? _mint
                        : Colors.redAccent,
                  ),
                  title: Text(
                    number,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${x['outcome'] ?? ''} · ${_callTime(x['started_at'])}',
                  ),
                  trailing: IconButton(
                    onPressed: number == 'Unknown'
                        ? null
                        : () => _placeCall(context, number),
                    icon: const Icon(Icons.phone_outlined),
                  ),
                );
              }),
            ],
          ),
        );
      },
    ),
  );
  Future<void> _placeCall(BuildContext context, String number) async {
    final ok = await sip.call(number);
    if (!context.mounted) return;
    if (ok) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ActiveCall(number: number)),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(sip.error ?? 'Unable to call')));
    }
  }
}

class IphoneDialer extends StatefulWidget {
  const IphoneDialer({super.key});
  @override
  State<IphoneDialer> createState() => _IphoneDialerState();
}

class _IphoneDialerState extends State<IphoneDialer> {
  String number = '';
  static const keys = [
    ['1', ''],
    ['2', 'ABC'],
    ['3', 'DEF'],
    ['4', 'GHI'],
    ['5', 'JKL'],
    ['6', 'MNO'],
    ['7', 'PQRS'],
    ['8', 'TUV'],
    ['9', 'WXYZ'],
    ['*', ''],
    ['0', '+'],
    ['#', ''],
  ];
  Future<void> call() async {
    if (number.isEmpty) return;
    final ok = await SipService.instance.call(number);
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ActiveCall(number: number)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SipService.instance.error ?? 'Unable to place call'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Keypad'), centerTitle: true),
    body: SafeArea(
      child: Column(
        children: [
          const Spacer(),
          SizedBox(
            height: 60,
            child: Text(
              number,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w400),
            ),
          ),
          if (number.isNotEmpty)
            TextButton(
              onPressed: () {},
              child: const Text(
                'Add Number',
                style: TextStyle(color: Colors.blueAccent),
              ),
            ),
          const SizedBox(height: 15),
          SizedBox(
            width: 330,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 28,
              ),
              itemCount: 12,
              itemBuilder: (_, i) {
                final k = keys[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(50),
                  onTap: () => setState(() => number += k[0]),
                  onLongPress: k[0] == '0'
                      ? () => setState(() => number += '+')
                      : null,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xff29383e),
                      shape: BoxShape.circle,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(k[0], style: const TextStyle(fontSize: 32)),
                        if (k[1].isNotEmpty)
                          Text(
                            k[1],
                            style: const TextStyle(
                              fontSize: 10,
                              letterSpacing: 2,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 72),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xff34c759),
                  minimumSize: const Size(72, 72),
                ),
                onPressed: number.isEmpty ? null : call,
                icon: const Icon(Icons.call, size: 34, color: Colors.white),
              ),
              SizedBox(
                width: 72,
                child: number.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => setState(
                          () => number = number.substring(0, number.length - 1),
                        ),
                        icon: const Icon(Icons.backspace_outlined),
                      ),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    ),
  );
}

class ActiveCall extends StatefulWidget {
  const ActiveCall({super.key, required this.number});
  final String number;
  @override
  State<ActiveCall> createState() => _ActiveCallState();
}

class _ActiveCallState extends State<ActiveCall> {
  final sip = SipService.instance;
  @override
  void initState() {
    super.initState();
    sip.addListener(changed);
  }

  @override
  void dispose() {
    sip.removeListener(changed);
    super.dispose();
  }

  void changed() {
    if (!mounted) return;
    if (!sip.inCall) {
      Navigator.maybePop(context);
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 650;
          final buttonSize = constraints.maxWidth < 360 ? 58.0 : 66.0;
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: compact ? 18 : 32,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(height: compact ? 16 : 90),
                    Column(
                      children: [
                        Text(
                          widget.number,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          sip.connected
                              ? _duration(sip.durationSeconds)
                              : sip.callState.name.toLowerCase(),
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 36 : 180),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CallButton(
                            size: buttonSize,
                            icon: sip.muted ? Icons.mic_off : Icons.mic,
                            label: 'mute',
                            active: sip.muted,
                            onTap: sip.toggleMute,
                          ),
                          _CallButton(
                            size: buttonSize,
                            icon: Icons.dialpad,
                            label: 'keypad',
                            onTap: () => showModalBottomSheet(
                              context: context,
                              builder: (_) => _DtmfPad(),
                            ),
                          ),
                          _CallButton(
                            size: buttonSize,
                            icon: sip.held ? Icons.play_arrow : Icons.pause,
                            label: 'hold',
                            active: sip.held,
                            onTap: sip.toggleHold,
                          ),
                          _CallButton(
                            size: buttonSize,
                            icon: sip.speaker
                                ? Icons.volume_up
                                : Icons.volume_down,
                            label: 'speaker',
                            active: sip.speaker,
                            onTap: sip.toggleSpeaker,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: compact ? 30 : 54),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(78, 78),
                      ),
                      onPressed: sip.hangup,
                      icon: const Icon(Icons.call_end, size: 36),
                    ),
                    SizedBox(height: compact ? 18 : 42),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    required this.size,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final double size;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: active
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            foregroundColor: active
                ? Theme.of(context).colorScheme.surface
                : Theme.of(context).colorScheme.onSurface,
            minimumSize: Size(size, size),
          ),
          onPressed: onTap,
          icon: Icon(icon, size: size * .44),
        ),
        const SizedBox(height: 9),
        Text(label, maxLines: 1, style: const TextStyle(fontSize: 14)),
      ],
    ),
  );
}

class _DtmfPad extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SafeArea(
    child: GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      padding: const EdgeInsets.all(30),
      children: '123456789*0#'
          .split('')
          .map(
            (x) => TextButton(
              onPressed: () {
                final sent = SipService.instance.sendDtmf(x);
                if (!sent) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      duration: Duration(milliseconds: 700),
                      content: Text(
                        'DTMF is available after the call connects.',
                      ),
                    ),
                  );
                }
              },
              child: Text(x, style: const TextStyle(fontSize: 28)),
            ),
          )
          .toList(),
    ),
  );
}

String _duration(int seconds) {
  final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
  final remainder = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$remainder';
}

class _Error extends StatelessWidget {
  const _Error(this.message, this.retry);
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

String _callTime(dynamic value) {
  if (value == null) return '';
  try {
    return DateFormat('MMM d, h:mm a')
        .format(DateTime.parse(value.toString()).toLocal());
  } catch (_) {
    return value.toString();
  }
}
