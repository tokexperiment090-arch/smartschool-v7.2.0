import 'package:flutter/material.dart';
import 'riyo_api.dart';
import 'api_config.dart';
import 'riyo_theme.dart';
import 'state_widgets.dart';

// Single shared API client. The 401 handler is set after MaterialApp is built
// (see [_RiyoAppState]) so the navigator is available to pop to the login
// screen when the token expires or the server rejects the session.
final RiyoApi api = RiyoApi();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Best-effort: hit the site root once so the InfinityFree JS-challenge
  // cookie is set. If it fails the warmup is silently ignored and the first
  // real API call may surface an `invalidResponse` error (handled gracefully).
  try {
    await api.warmup();
  } catch (_) {}
  runApp(const RiyoApp());
}

class RiyoApp extends StatefulWidget {
  const RiyoApp({super.key});
  @override
  State<RiyoApp> createState() => _RiyoAppState();
}

class _RiyoAppState extends State<RiyoApp> {
  final _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // When the API reports an expired/invalid session, clear the token and
    // pop everything back to the login screen.
    api.setUnauthorizedHandler(() {
      _navKey.currentState?.popUntil((r) => r.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Riyo',
        theme: RiyoTheme.light,
        navigatorKey: _navKey,
        home: const _RootGate(),
        debugShowCheckedModeBanner: false,
      );
}

/// Decides whether to show login or the home screen, based on a stored token.
class _RootGate extends StatefulWidget {
  const _RootGate();
  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  bool? _hasToken;

  @override
  void initState() {
    super.initState();
    api.token.then((t) {
      if (!mounted) return;
      setState(() => _hasToken = t != null);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasToken == null) return const LoadingView(message: 'Starting Riyo…');
    return _hasToken! ? const HomeScreen() : const LoginScreen();
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _err;

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final res = await api.login(_user.text.trim(), _pass.text);
      if (!mounted) return;
      if (res['status'] == 'success') {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        setState(() => _err = 'Unexpected response from the server.');
      }
    } catch (e) {
      if (mounted) setState(() => _err = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [RiyoTheme.brand, RiyoTheme.brandDark],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/riyo_logo.png', height: 64),
                      const SizedBox(height: 8),
                      const Text('Student / Parent Login',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _user,
                        enabled: !_busy,
                        decoration: const InputDecoration(labelText: 'Admission No / Username'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pass,
                        enabled: !_busy,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password'),
                      ),
                      const SizedBox(height: 16),
                      if (_err != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(_err!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _login,
                          child: _busy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Login'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _dash;
  Object? _err;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      _dash = await api.dashboard();
    } catch (e) {
      _err = e;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final body = StateBody<Map<String, dynamic>>(
      loading: _busy,
      error: _err,
      data: _dash,
      isEmpty: (d) => false,
      builder: (d) => _homeList(d),
      onRetry: _load,
      emptyTitle: '',
    );
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Image.asset('assets/riyo_logo_small.png', height: 28),
          const SizedBox(width: 8),
          const Text('Riyo'),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () async {
              await api.clearToken();
              if (mounted) {
                Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          )
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: body),
    );
  }

  Widget _homeList(Map<String, dynamic> d) {
    final s = d['student'] as Map?;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            title: Text(s?['firstname'] ?? '',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            subtitle: Text('${s?['class']} - ${s?['section']}'),
            leading: const CircleAvatar(
              backgroundColor: RiyoTheme.brandLight,
              child: Icon(Icons.person, color: RiyoTheme.brand),
            ),
          ),
        ),
        _tile(Icons.dashboard, 'Dashboard', () => _push(const DashboardScreen())),
        _tile(Icons.assessment, 'Exam Results', () => _push(const ExamResultsScreen())),
        _tile(Icons.check_circle, 'Attendance', () => _push(const AttendanceScreen())),
        _tile(Icons.attach_money, 'Fees', () => _push(const FeesScreen())),
        _tile(Icons.campaign, 'Notices', () => _push(const NoticesScreen())),
        _tile(Icons.person, 'Profile', () => _push(const ProfileScreen())),
      ],
    );
  }

  Widget _tile(IconData icon, String label, VoidCallback onTap) => Card(
        child: ListTile(
          leading: Icon(icon, color: RiyoTheme.brand),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );

  void _push(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
}

// ---------- generic data screen with pull-to-refresh and StateBody ----------

abstract class _AsyncScreen<T> extends StatefulWidget {
  const _AsyncScreen();
  Future<T> Function() get fetcher;
  String get title;
  Widget buildContent(BuildContext context, T data);
  bool isEmpty(T data);
  String? get emptyTitle => null;
  String? get emptyMessage => null;
  IconData get emptyIcon => Icons.inbox_outlined;
}

class _AsyncScreenState<T> extends State<_AsyncScreen<T>> {
  T? _data;
  Object? _err;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      _data = await widget.fetcher();
    } catch (e) {
      _err = e;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: StateBody<T>(
          loading: _busy,
          error: _err,
          data: _data,
          isEmpty: widget.isEmpty,
          builder: (d) => widget.buildContent(context, d),
          onRetry: _load,
          emptyTitle: widget.emptyTitle ?? 'Nothing here yet',
          emptyMessage: widget.emptyMessage,
          emptyIcon: widget.emptyIcon,
        ),
      ),
    );
  }
}

// ---------- concrete screens ----------

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: RefreshIndicator(
          onRefresh: () async {
            // Re-render by popping & pushing; simplest is to rely on the parent's pull.
          },
          child: _DashboardBody(),
        ),
      );
}

class _DashboardBody extends StatefulWidget {
  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  Map<String, dynamic>? _data;
  Object? _err;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      _data = await api.dashboard();
    } catch (e) {
      _err = e;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: StateBody<Map<String, dynamic>>(
        loading: _busy,
        error: _err,
        data: _data,
        isEmpty: (_) => false,
        onRetry: _load,
        builder: (d) {
          final s = d['student'] as Map?;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _stat('Attendance Records', d['attendance_records']?.toString() ?? '0', Icons.check_circle),
              const SizedBox(height: 12),
              _stat('Class', s?['class'] ?? '-', Icons.class_),
              const SizedBox(height: 12),
              _stat('Section', s?['section'] ?? '-', Icons.group),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon) => Card(
        child: ListTile(
          leading: Icon(icon, color: RiyoTheme.brand),
          title: Text(label),
          trailing: Text(value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      );
}

class ExamResultsScreen extends StatefulWidget {
  const ExamResultsScreen({super.key});
  @override
  State<ExamResultsScreen> createState() => _ExamResultsScreenState();
}

class _ExamResultsScreenState extends State<ExamResultsScreen> {
  List _sessions = [];
  Object? _err;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final r = await api.examResults();
      _sessions = (r['sessions'] as List?) ?? const [];
    } catch (e) {
      _err = e;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Exam Results')),
        body: RefreshIndicator(
          onRefresh: _load,
          child: StateBody<List>(
            loading: _busy,
            error: _err,
            data: _sessions,
            isEmpty: (d) => d.isEmpty,
            onRetry: _load,
            emptyTitle: 'No exam results yet',
            emptyMessage: 'Published results will appear here.',
            emptyIcon: Icons.assignment_outlined,
            builder: (sessions) => ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: sessions.length,
              itemBuilder: (_, si) {
                final sess = sessions[si];
                final groups = (sess['exam_groups'] as List?) ?? const [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Text('${sess['session']}  ·  ${sess['class']}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: RiyoTheme.brand)),
                    ),
                    ...groups.map((g) => _examCard(g as Map)).toList(),
                  ],
                );
              },
            ),
          ),
        ),
      );

  Widget _examCard(Map g) {
    final subs = (g['subjects'] as List?) ?? const [];
    final pct = g['percentage']?.toString();
    final grade = g['grade']?.toString();
    final pctNum = double.tryParse(pct ?? '');
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Text(g['exam_group']?.toString() ?? '',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                if (grade != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: RiyoTheme.brand, borderRadius: BorderRadius.circular(8)),
                    child: Text(grade,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...subs.map((s) {
              final m = s is Map ? s : const {};
              final get = m['get_marks'];
              final max = m['max_marks'];
              final low = (get is num && max is num && get < max * 0.5);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(m['subject']?.toString() ?? '')),
                    Text('$get / $max',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: low ? Colors.red : RiyoTheme.text)),
                  ],
                ),
              );
            }),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.w600)),
                Text('${g['total_get']} / ${g['total_max']}'),
              ],
            ),
            if (pctNum != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Percentage', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('$pct%',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: RiyoTheme.brand)),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: pctNum / 100,
                backgroundColor: RiyoTheme.brandLight,
                color: RiyoTheme.brand,
                minHeight: 8,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String _month = '';
  List _rows = [];
  Object? _err;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = '$n${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}';
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final r = await api.attendance(_month);
      _rows = (r['attendance'] as List?) ?? const [];
    } catch (e) {
      _err = e;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Attendance')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, color: RiyoTheme.brand),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _month,
                    items: List.generate(12, (i) {
                      final m = i + 1;
                      final y = DateTime.now().year;
                      final val = '$y-${m.toString().padLeft(2, '0')}';
                      return DropdownMenuItem(value: val, child: Text(_label(val)));
                    }),
                    onChanged: _busy
                        ? null
                        : (v) {
                            if (v != null) {
                              setState(() => _month = v);
                              _load();
                            }
                          },
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _busy ? null : _load,
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: StateBody<List>(
                  loading: _busy,
                  error: _err,
                  data: _rows,
                  isEmpty: (d) => d.isEmpty,
                  onRetry: _load,
                  emptyTitle: 'No attendance this month',
                  emptyMessage: 'Try a different month, or pull down to refresh.',
                  emptyIcon: Icons.event_busy,
                  builder: (rows) => ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (_, i) {
                      final r = rows[i] as Map;
                      final status = r['status']?.toString() ?? r['remark']?.toString() ?? '';
                      final present = status.toLowerCase().contains('present');
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            present ? Icons.check_circle : Icons.cancel,
                            color: present ? Colors.green : Colors.red,
                          ),
                          title: Text(r['date']?.toString() ?? ''),
                          trailing: Chip(label: Text(status)),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  String _label(String ym) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final p = ym.split('-');
    return '${names[int.parse(p[1]) - 1]} ${p[0]}';
  }
}

class FeesScreen extends StatefulWidget {
  const FeesScreen({super.key});
  @override
  State<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends State<FeesScreen> {
  Map? _f;
  Object? _err;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final r = await api.fees();
      _f = r['fees'] as Map?;
    } catch (e) {
      _err = e;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Fees')),
        body: RefreshIndicator(
          onRefresh: _load,
          child: StateBody<Map>(
            loading: _busy,
            error: _err,
            data: _f == null ? const {} : _f!,
            isEmpty: (d) => d.isEmpty,
            onRetry: _load,
            emptyTitle: 'No fee information yet',
            builder: (d) => Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _line('Expected', d['expected']?.toString() ?? '0'),
                  _line('Paid', d['paid']?.toString() ?? '0'),
                  _line('Balance', d['balance']?.toString() ?? '0', color: Colors.red),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _line(String k, String v, {Color? color}) => Card(
        child: ListTile(
          title: Text(k),
          trailing: Text(v,
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      );
}

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});
  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  List _rows = [];
  Object? _err;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final r = await api.notices();
      _rows = (r['notices'] as List?) ?? const [];
    } catch (e) {
      _err = e;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notices')),
        body: RefreshIndicator(
          onRefresh: _load,
          child: StateBody<List>(
            loading: _busy,
            error: _err,
            data: _rows,
            isEmpty: (d) => d.isEmpty,
            onRetry: _load,
            emptyTitle: 'No notices',
            emptyMessage: 'School notices will appear here when published.',
            emptyIcon: Icons.campaign_outlined,
            builder: (rows) => ListView.builder(
              itemCount: rows.length,
              itemBuilder: (_, i) {
                final n = rows[i] as Map;
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.campaign, color: RiyoTheme.brand),
                    title: Text(n['title']?.toString() ?? ''),
                    subtitle: Text(n['message']?.toString() ?? ''),
                    trailing: Text(n['publish_date']?.toString() ?? n['date']?.toString() ?? ''),
                  ),
                );
              },
            ),
          ),
        ),
      );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map? _s;
  Object? _err;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final r = await api.profile();
      _s = r['student'] as Map?;
    } catch (e) {
      _err = e;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: RefreshIndicator(
          onRefresh: _load,
          child: StateBody<Map>(
            loading: _busy,
            error: _err,
            data: _s == null ? const {} : _s!,
            isEmpty: (d) => d.isEmpty,
            onRetry: _load,
            emptyTitle: 'No profile data',
            builder: (s) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _line('Admission No', s['admission_no']?.toString() ?? ''),
                _line('Name', '${s['firstname']} ${s['lastname']}'),
                _line('Gender', s['gender']?.toString() ?? ''),
                _line('Class', s['class']?.toString() ?? ''),
                _line('Section', s['section']?.toString() ?? ''),
              ],
            ),
          ),
        ),
      );

  Widget _line(String k, String v) => Card(
        child: ListTile(
          title: Text(k, style: const TextStyle(color: RiyoTheme.muted)),
          trailing: Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      );
}
