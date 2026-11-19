import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'api.dart';
import 'communications.dart';
import 'sip_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DfwApp());
}

const mint = Color(0xff38d6b0),
    ink = Color(0xff0b171d),
    panel = Color(0xff12252d),
    line = Color(0xff294049);

class DfwApp extends StatefulWidget {
  const DfwApp({super.key});
  @override
  State<DfwApp> createState() => _DfwAppState();
}

class _DfwAppState extends State<DfwApp> {
  Map<String, dynamic>? user;
  bool ready = false;
  ThemeMode themeMode = ThemeMode.dark;
  static const storage = FlutterSecureStorage();
  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    final values = await Future.wait([
      ApiService.instance.restoreUser(),
      storage.read(key: 'theme_mode'),
    ]);
    user = values[0] as Map<String, dynamic>?;
    themeMode = values[1] == 'light' ? ThemeMode.light : ThemeMode.dark;
    if (mounted) setState(() => ready = true);
  }

  Future<void> setTheme(ThemeMode value) async {
    setState(() => themeMode = value);
    await storage.write(
      key: 'theme_mode',
      value: value == ThemeMode.light ? 'light' : 'dark',
    );
  }

  @override
  Widget build(BuildContext c) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'DFW Communication',
    themeMode: themeMode,
    theme: ThemeData.light(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xfff4f7f6),
      colorScheme: const ColorScheme.light(
        primary: Color(0xff087b65),
        surface: Colors.white,
        onSurface: Color(0xff102127),
        outline: Color(0xffcbd8d4),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xffd5e1de)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xffcbd8d4)),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Color(0xffcfece5),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xfff4f7f6),
        surfaceTintColor: Colors.transparent,
      ),
    ),
    darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: ink,
      colorScheme: const ColorScheme.dark(primary: mint, surface: panel),
      cardTheme: CardThemeData(
        color: panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xff172b34),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xff0e2027),
        indicatorColor: Color(0xff214039),
      ),
    ),
    home: !ready
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : user == null
        ? Login(onLogin: (u) => setState(() => user = u))
        : Shell(
            user: user!,
            themeMode: themeMode,
            onThemeChanged: setTheme,
            onLogout: () async {
              await ApiService.instance.logout();
              setState(() => user = null);
            },
          ),
  );
}

class Login extends StatefulWidget {
  const Login({super.key, required this.onLogin});
  final ValueChanged<Map<String, dynamic>> onLogin;
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final email = TextEditingController(), pass = TextEditingController();
  bool busy = false, hide = true;
  String? error;
  Future<void> submit() async {
    if (email.text.trim().isEmpty || pass.text.isEmpty) {
      setState(() => error = 'Enter your email and password.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      widget.onLogin(await ApiService.instance.login(email.text, pass.text));
    } catch (e) {
      setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      child: CircleAvatar(
                        radius: 31,
                        backgroundColor: Color(0xff184b40),
                        child: Icon(Icons.forum_rounded, color: mint, size: 34),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'DFW Communication',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Log in to your workspace',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 26),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: pass,
                      obscureText: hide,
                      onSubmitted: (_) => submit(),
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => hide = !hide),
                          icon: Icon(
                            hide ? Icons.visibility_off : Icons.visibility,
                          ),
                        ),
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: busy ? null : submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                      child: busy
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'SIGN IN',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your credentials are encrypted in transit and stored securely.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(c).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class Shell extends StatefulWidget {
  const Shell({
    super.key,
    required this.user,
    required this.onLogout,
    required this.themeMode,
    required this.onThemeChanged,
  });
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  static const platform = MethodChannel('com.dfw.communication/native');
  int index = 0;
  StreamSubscription? events;
  final sip = SipService.instance;
  bool incomingDialogOpen = false;
  bool foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Permission.notification.request();
    platform.invokeMethod('startService');
    platform.invokeMethod('requestFullScreenAccess');
    listen();
    sip.addListener(_onCallChanged);
    sip.initialize();
  }

  Future<void> listen() async {
    try {
      events = (await ApiService.instance.events()).listen((e) {
        if (mounted && e['type'] == 'message.received') {
          final payload = e['data'] as Map? ?? e;
          final sender =
              '${payload['sender_name'] ?? payload['contact_name'] ?? 'New message'}';
          final preview =
              '${payload['body'] ?? payload['message'] ?? 'Open DFW Communication to read it'}';
          if (!foreground) {
            platform.invokeMethod('showMessage', {
              'title': sender,
              'body': preview,
            });
          } else {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('$sender: $preview')));
          }
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    events?.cancel();
    sip.removeListener(_onCallChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
  }

  void _onCallChanged() {
    if (!mounted) return;
    // Answer/decline can originate from the native full-screen call UI. Close
    // the already-open Flutter prompt as soon as SIP starts answering or the
    // incoming call ends, so the user never has to act twice.
    if (incomingDialogOpen &&
        (!sip.incoming || sip.answering || sip.connected || !sip.inCall)) {
      Navigator.of(context, rootNavigator: true).maybePop();
      return;
    }
    if (!sip.incoming || incomingDialogOpen) return;
    incomingDialogOpen = true;
    final number = sip.activeCall?.remote_identity ?? 'Unknown caller';
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final answer = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Incoming call'),
          content: Text(number),
          actions: [
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, false),
              icon: const Icon(Icons.call_end),
              label: const Text('Decline'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.call),
              label: const Text('Answer'),
            ),
          ],
        ),
      );
      incomingDialogOpen = false;
      if (!mounted) return;
      if (answer == true) {
        final started = await sip.answer();
        if (mounted && started && sip.inCall) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ActiveCall(number: number)),
          );
        }
      } else if (answer == false) {
        sip.reject();
      }
    });
  }

  @override
  Widget build(BuildContext c) {
    final pages = [
      Dashboard(user: widget.user, navigate: (i) => setState(() => index = i)),
      const Conversations(),
      const SmsHome(),
      const Calls(),
      Settings(
        user: widget.user,
        onLogout: () {
          platform.invokeMethod('stopService');
          widget.onLogout();
        },
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
      ),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'WhatsApp',
          ),
          NavigationDestination(icon: Icon(Icons.sms_outlined), label: 'SMS'),
          NavigationDestination(
            icon: Icon(Icons.phone_outlined),
            label: 'Calls',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class Frame extends StatelessWidget {
  const Frame({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
  });
  final String title;
  final Widget child;
  final List<Widget> actions;
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      actions: actions,
    ),
    body: SafeArea(child: child),
  );
}

class AsyncPane extends StatelessWidget {
  const AsyncPane({super.key, required this.future, required this.builder});
  final Future<dynamic> future;
  final Widget Function(dynamic) builder;
  @override
  Widget build(BuildContext c) => FutureBuilder(
    future: future,
    builder: (c, s) {
      if (s.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (s.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('${s.error}', textAlign: TextAlign.center),
          ),
        );
      }
      return builder(s.data);
    },
  );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, required this.user, required this.navigate});
  final Map<String, dynamic> user;
  final ValueChanged<int> navigate;
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late Future data;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() => data = ApiService.instance.get('api/dashboard/summary');
  @override
  Widget build(BuildContext c) {
    final raw = (widget.user['email'] ?? 'there').toString().split('@').first,
        name = raw.isEmpty
            ? 'There'
            : '${raw[0].toUpperCase()}${raw.substring(1)}';
    return Frame(
      title: 'DFW Communication',
      actions: [
        IconButton(
          onPressed: () => setState(reload),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'YOUR COMMUNICATION HUB',
            style: TextStyle(
              color: mint,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Welcome back, $name.',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Conversations, calls, and meetings. One place to get started.',
            style: TextStyle(
              color: Theme.of(c).colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (c, k) => GridView.count(
              crossAxisCount: k.maxWidth > 650 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: k.maxWidth > 650 ? 1.2 : .82,
              children: [
                Hub(
                  Icons.chat_bubble_outline,
                  mint,
                  'WhatsApp',
                  'Messages, media, and approved templates.',
                  () => widget.navigate(1),
                ),
                Hub(
                  Icons.sms_outlined,
                  Colors.lightBlueAccent,
                  'Text messages',
                  'Send and receive business SMS.',
                  () => widget.navigate(2),
                ),
                Hub(
                  Icons.phone_in_talk_outlined,
                  Colors.orangeAccent,
                  'Call history',
                  'Use your assigned PBX extension.',
                  () => widget.navigate(3),
                ),
                const Hub(
                  Icons.video_call_outlined,
                  Colors.purpleAccent,
                  'Video rooms',
                  'Create secure meeting invitations.',
                  null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'Workspace overview',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          AsyncPane(
            future: data,
            builder: (d) {
              final m = Map<String, dynamic>.from(d);
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.65,
                children: [
                  Metric(
                    'Unread messages',
                    m['unread_message_count'] ?? 0,
                    mint,
                  ),
                  Metric(
                    'Open conversations',
                    m['open_conversation_count'] ?? 0,
                    Colors.white,
                  ),
                  Metric(
                    'Active numbers',
                    m['assigned_whatsapp_account_count'] ?? 0,
                    Colors.white,
                  ),
                  Metric(
                    'Active operators',
                    m['active_operator_count'] ?? 0,
                    Colors.white,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class Hub extends StatelessWidget {
  const Hub(
    this.icon,
    this.color,
    this.title,
    this.subtitle,
    this.tap, {
    super.key,
  });
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback? tap;
  @override
  Widget build(BuildContext c) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: tap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              maxLines: 3,
              style: TextStyle(
                color: Theme.of(c).colorScheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward, color: color),
          ],
        ),
      ),
    ),
  );
}

class Metric extends StatelessWidget {
  const Metric(this.label, this.value, this.color, {super.key});
  final String label;
  final dynamic value;
  final Color color;
  @override
  Widget build(BuildContext c) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(color: Theme.of(c).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 29,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class Conversations extends StatefulWidget {
  const Conversations({super.key});
  @override
  State<Conversations> createState() => _ConversationsState();
}

class _ConversationsState extends State<Conversations> {
  late Future list;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() => list = ApiService.instance.get(
    'api/conversations',
    query: {'limit': 100, 'status': 'open'},
  );
  @override
  Widget build(BuildContext context) => Frame(
    title: 'WhatsApp',
    actions: [
      IconButton(
        onPressed: () => setState(reload),
        icon: const Icon(Icons.refresh),
      ),
    ],
    child: AsyncPane(
      future: list,
      builder: (data) {
        final rows = (data as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (rows.isEmpty) {
          return const Center(child: Text('No open conversations'));
        }
        return ClipRect(
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: ListView.custom(
              padding: const EdgeInsets.all(12),
              clipBehavior: Clip.hardEdge,
              scrollCacheExtent: const ScrollCacheExtent.pixels(160),
              childrenDelegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index.isOdd) return const Divider(height: 1);
                  final rowIndex = index ~/ 2;
                  final row = rows[rowIndex];
                  final contact = row['contact'] as Map? ?? {};
                  final message = row['last_message'] as Map? ?? {};
                  final name =
                      (contact['profile_name'] ??
                              contact['phone_number'] ??
                              'Unknown contact')
                          .toString();
                  return ListTile(
                    key: ValueKey(row['id'] ?? rowIndex),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xff1a5146),
                      child: Text(name.substring(0, 1).toUpperCase()),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      message['body']?.toString() ?? 'Media message',
                      maxLines: 1,
                    ),
                    trailing: (row['unread_message_count'] ?? 0) > 0
                        ? Badge(label: Text('${row['unread_message_count']}'))
                        : const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Chat(conversation: row),
                      ),
                    ),
                  );
                },
                childCount: rows.length * 2 - 1,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: false,
                addSemanticIndexes: true,
              ),
            ),
          ),
        );
      },
    ),
  );
}

class Chat extends StatefulWidget {
  const Chat({super.key, required this.conversation});
  final Map<String, dynamic> conversation;
  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  late Future messages;
  final text = TextEditingController();
  bool sending = false;
  @override
  void initState() {
    super.initState();
    reload();
    ApiService.instance.post(
      'api/conversations/${widget.conversation['id']}/read',
    );
  }

  void reload() => messages = ApiService.instance.get(
    'api/conversations/${widget.conversation['id']}/messages',
    query: {'limit': 100},
  );
  Future<void> send() async {
    final body = text.text.trim();
    if (body.isEmpty) return;
    setState(() => sending = true);
    try {
      await ApiService.instance.post(
        'api/conversations/${widget.conversation['id']}/messages',
        data: {'body': body},
        idempotent: true,
      );
      text.clear();
      setState(reload);
    } catch (e) {
      if (mounted) {
        if (e is ApiException && e.code == 'outside_customer_window') {
          await _chooseTemplate();
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _chooseTemplate() async {
    try {
      final response = await ApiService.instance.get(
        'api/message-templates',
        query: {'limit': 100},
      );
      final templates = (response as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (!mounted) return;
      if (templates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No approved templates are available.')),
        );
        return;
      }
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        builder: (context) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Choose an approved template',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'The 24-hour customer-service window is closed.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              ...templates.map(
                (template) => Card(
                  child: ListTile(
                    title: Text('${template['name'] ?? 'Template'}'),
                    subtitle: Text(
                      '${template['body'] ?? template['template_body'] ?? template['content'] ?? ''}',
                      maxLines: 3,
                    ),
                    onTap: () => Navigator.pop(context, template),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      if (selected == null || !mounted) return;
      final variables = List<Map<String, dynamic>>.from(
        (selected['variables'] as List? ?? []).map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );
      final values = <String, String>{};
      if (variables.isNotEmpty) {
        final controllers = <String, TextEditingController>{
          for (final variable in variables)
            '${variable['key']}': TextEditingController(),
        };
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('${selected['name']}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: variables
                    .map(
                      (variable) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          controller: controllers['${variable['key']}'],
                          decoration: InputDecoration(
                            labelText:
                                '${variable['label'] ?? variable['key']}',
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Send template'),
              ),
            ],
          ),
        );
        if (confirmed != true) {
          for (final controller in controllers.values) {
            controller.dispose();
          }
          return;
        }
        for (final entry in controllers.entries) {
          values[entry.key] = entry.value.text.trim();
          entry.value.dispose();
        }
      }
      await ApiService.instance.post(
        'api/conversations/${widget.conversation['id']}/messages',
        data: {'template_id': selected['id'], 'variables': values},
        idempotent: true,
      );
      text.clear();
      if (mounted) setState(reload);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contact = widget.conversation['contact'] as Map? ?? {};
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${contact['profile_name'] ?? contact['phone_number'] ?? 'Conversation'}',
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: AsyncPane(
              future: messages,
              builder: (data) {
                final items = (data as List)
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(14),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final message = items[items.length - 1 - i];
                    final outbound = message['direction'] == 'outbound';
                    return Align(
                      alignment: outbound
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * .78,
                        ),
                        decoration: BoxDecoration(
                          color: outbound ? const Color(0xff156b59) : panel,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              message['body']?.toString() ??
                                  '[${message['message_type'] ?? 'media'}]',
                              style: TextStyle(
                                fontSize: 16,
                                color: outbound ? Colors.white : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${message['status'] ?? ''}',
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
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: text,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        prefixIcon: Icon(Icons.attach_file),
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
}

class LegacySmsHome extends StatefulWidget {
  const LegacySmsHome({super.key});
  @override
  State<LegacySmsHome> createState() => _LegacySmsState();
}

class _LegacySmsState extends State<LegacySmsHome> {
  late Future numbers;
  @override
  void initState() {
    super.initState();
    numbers = ApiService.instance.get('sms-api/numbers');
  }

  @override
  Widget build(BuildContext c) => Frame(
    title: 'Text messages',
    child: AsyncPane(
      future: numbers,
      builder: (d) {
        final raw = d is Map ? (d['numbers'] ?? []) : d,
            a = List.from(raw as List);
        if (a.isEmpty) {
          return const Center(child: Text('No SMS numbers assigned'));
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: a
              .map(
                (x) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.sms_outlined),
                    ),
                    title: Text('${x['label'] ?? x['e164']}'),
                    subtitle: Text('${x['e164']}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      c,
                      MaterialPageRoute(
                        builder: (_) => LegacySmsThreads(
                          number: Map<String, dynamic>.from(x),
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    ),
  );
}

class LegacySmsThreads extends StatelessWidget {
  const LegacySmsThreads({super.key, required this.number});
  final Map<String, dynamic> number;
  @override
  Widget build(BuildContext c) => Frame(
    title: 'SMS · ${number['label'] ?? number['e164']}',
    child: AsyncPane(
      future: ApiService.instance.get(
        'sms-api/conversations',
        query: {'number_id': number['id'], 'limit': 100},
      ),
      builder: (d) {
        final raw = d is Map ? (d['conversations'] ?? d['threads'] ?? []) : d,
            a = List.from(raw);
        if (a.isEmpty) {
          return const Center(child: Text('No text conversations'));
        }
        return ListView(
          children: a
              .map(
                (x) => ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(
                    '${x['contact_name'] ?? x['to'] ?? x['from'] ?? 'Contact'}',
                  ),
                  subtitle: Text(
                    '${x['last_message_body'] ?? ''}',
                    maxLines: 1,
                  ),
                ),
              )
              .toList(),
        );
      },
    ),
  );
}

class LegacyCalls extends StatefulWidget {
  const LegacyCalls({super.key});
  @override
  State<LegacyCalls> createState() => _LegacyCallsState();
}

class _LegacyCallsState extends State<LegacyCalls> {
  late Future data;
  @override
  void initState() {
    super.initState();
    data = Future.wait([
      ApiService.instance.get('api/phone/config'),
      ApiService.instance.get('api/phone/calls', query: {'limit': 50}),
    ]);
  }

  @override
  Widget build(BuildContext c) => Frame(
    title: 'Calls',
    actions: [
      IconButton(
        onPressed: () =>
            showDialog(context: c, builder: (_) => const LegacyDialer()),
        icon: const Icon(Icons.dialpad),
      ),
    ],
    child: AsyncPane(
      future: data,
      builder: (d) {
        final config = (d[0] as Map)['config'],
            calls = d[1] is Map ? (d[1]['calls'] ?? []) : d[1];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: (config == null ? Colors.orange : mint)
                      .withValues(alpha: .2),
                  child: Icon(
                    Icons.phone_in_talk,
                    color: config == null ? Colors.orange : mint,
                  ),
                ),
                title: Text(
                  config == null
                      ? 'No phone assigned'
                      : 'Extension ${config['extension']}',
                ),
                subtitle: Text(
                  config == null
                      ? 'Ask an administrator to assign an extension.'
                      : '${config['displayName'] ?? config['label'] ?? 'Ready'}',
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Recent calls',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            if ((calls as List).isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: Text('No call history')),
              ),
            ...calls.map(
              (x) => ListTile(
                leading: Icon(
                  x['direction'] == 'inbound'
                      ? Icons.call_received
                      : Icons.call_made,
                  color: x['status'] == 'answered' ? mint : Colors.redAccent,
                ),
                title: Text(
                  '${x['remoteNumber'] ?? x['remote_number'] ?? 'Unknown'}',
                ),
                subtitle: Text('${x['status'] ?? ''}'),
                trailing: Text(formatDate(x['startedAt'] ?? x['started_at'])),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class LegacyDialer extends StatefulWidget {
  const LegacyDialer({super.key});
  @override
  State<LegacyDialer> createState() => _LegacyDialerState();
}

class _LegacyDialerState extends State<LegacyDialer> {
  String n = '';
  @override
  Widget build(BuildContext c) => AlertDialog(
    title: const Text('Dial pad'),
    content: SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            n.isEmpty ? 'Enter a number' : n,
            style: const TextStyle(fontSize: 26),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            children: '123456789*0#'
                .split('')
                .map(
                  (x) => TextButton(
                    onPressed: () => setState(() => n += x),
                    child: Text(x, style: const TextStyle(fontSize: 24)),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () =>
            setState(() => n = n.isEmpty ? '' : n.substring(0, n.length - 1)),
        child: const Text('Delete'),
      ),
      FilledButton.icon(
        onPressed: n.isEmpty
            ? null
            : () {
                Navigator.pop(c);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'SIP registration is required before calling.',
                    ),
                  ),
                );
              },
        icon: const Icon(Icons.call),
        label: const Text('Call'),
      ),
    ],
  );
}

class Settings extends StatelessWidget {
  const Settings({
    super.key,
    required this.user,
    required this.onLogout,
    required this.themeMode,
    required this.onThemeChanged,
  });
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  @override
  Widget build(BuildContext c) => Frame(
    title: 'Settings',
    child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xff1a5146),
                  child: Icon(Icons.person, color: mint),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${user['email']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        '${user['role'] ?? 'operator'}',
                        style: TextStyle(
                          color: Theme.of(c).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const ListTile(
          leading: Icon(Icons.security),
          title: Text('Secure session'),
          subtitle: Text('Access token protected by Android secure storage'),
        ),
        SwitchListTile(
          secondary: Icon(
            themeMode == ThemeMode.light
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
          ),
          title: const Text('Day mode'),
          subtitle: const Text('Use the light, high-contrast appearance'),
          value: themeMode == ThemeMode.light,
          onChanged: (enabled) =>
              onThemeChanged(enabled ? ThemeMode.light : ThemeMode.dark),
        ),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('DFW Communication'),
          subtitle: Text('Native Android client · 1.0.0'),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    ),
  );
}

String formatDate(dynamic v) {
  if (v == null) return '';
  try {
    return DateFormat('MMM d, h:mm a')
        .format(DateTime.parse(v.toString()).toLocal());
  } catch (_) {
    return v.toString();
  }
}
