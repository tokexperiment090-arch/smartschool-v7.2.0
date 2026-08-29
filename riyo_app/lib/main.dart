import 'package:flutter/material.dart';
import 'riyo_api.dart';
import 'api_config.dart';
import 'riyo_theme.dart';

void main() => runApp(const RiyoApp());

class RiyoApp extends StatelessWidget {
  const RiyoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Riyo',
        theme: RiyoTheme.light,
        home: const LoginScreen(),
        debugShowCheckedModeBanner: false,
      );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _api = RiyoApi();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _api.token.then((t) {
      if (t != null) _goHome();
    });
  }

  void _goHome() => Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (_) => const HomeScreen()));

  Future<void> _login() async {
    setState(() => _busy = true);
    try {
      final res = await _api.login(_user.text.trim(), _pass.text);
      if (res['status'] == 'success') _goHome();
    } on ApiException catch (e) {
      setState(() => _err = e.message);
    } finally {
      setState(() => _busy = false);
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
                    children: [
                      Image.asset('assets/riyo_logo.png', height: 64),
                      const SizedBox(height: 8),
                      const Text('Student / Parent Login',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _user,
                        decoration: const InputDecoration(labelText: 'Admission No / Username'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pass,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password'),
                      ),
                      const SizedBox(height: 16),
                      if (_err.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(_err, style: const TextStyle(color: Colors.red)),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _login,
                          child: _busy
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
  final _api = RiyoApi();
  Map<String, dynamic>? _dash;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _dash = await _api.dashboard();
    } on ApiException catch (_) {
      await _api.clearToken();
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Row(children: [
            Image.asset('assets/riyo_logo_small.png', height: 28),
            const SizedBox(width: 8),
            const Text('Riyo'),
          ]),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await _api.clearToken();
                if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
            )
          ],
        ),
        body: _busy
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      title: Text(_dash?['student']?['firstname'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      subtitle: Text('${_dash?['student']?['class']} - ${_dash?['student']?['section']}'),
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
                  _tile(Icons.person, 'Profile', () => _push(const ProfileScreen())),
                ],
              ),
      );

  Widget _tile(IconData icon, String label, VoidCallback onTap) => Card(
        child: ListTile(leading: Icon(icon, color: RiyoTheme.brand), title: Text(label), trailing: const Icon(Icons.chevron_right), onTap: onTap),
      );

  void _push(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = RiyoApi();
  Map<String, dynamic>? _dash;
  bool _busy = true;
  @override
  void initState() { super.initState(); _api.dashboard().then((r) { _dash = r; if (mounted) setState(() => _busy = false); }); }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: _busy
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _stat('Attendance Records', _dash?['attendance_records']?.toString() ?? '0', Icons.check_circle),
                    const SizedBox(height: 12),
                    _stat('Class', _dash?['student']?['class'] ?? '-', Icons.class_),
                    const SizedBox(height: 12),
                    _stat('Section', _dash?['student']?['section'] ?? '-', Icons.group),
                    const Spacer(),
                    const Text('Tip: open Exam Results to see marks by session.', style: TextStyle(color: RiyoTheme.muted)),
                  ],
                ),
              ),
      );
  Widget _stat(String label, String value, IconData icon) => Card(
        child: ListTile(leading: Icon(icon, color: RiyoTheme.brand), title: Text(label), trailing: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
      );
}

class ExamResultsScreen extends StatefulWidget {
  const ExamResultsScreen({super.key});
  @override
  State<ExamResultsScreen> createState() => _ExamResultsScreenState();
}

class _ExamResultsScreenState extends State<ExamResultsScreen> {
  final _api = RiyoApi();
  List _sessions = [];
  bool _busy = true;
  @override
  void initState() { super.initState(); _api.examResults().then((r) { _sessions = r['sessions'] ?? []; if (mounted) setState(() => _busy = false); }); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Exam Results')),
        body: _busy
            ? const Center(child: CircularProgressIndicator())
            : _sessions.isEmpty
                ? const Center(child: Text('No published exam results yet.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _sessions.length,
                    itemBuilder: (_, si) {
                      final sess = _sessions[si];
                      final groups = sess['exam_groups'] as List;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            child: Text('${sess['session']}  ·  ${sess['class']}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: RiyoTheme.brand)),
                          ),
                          ...groups.map((g) => _examCard(g)).toList(),
                        ],
                      );
                    },
                  ),
      );

  Widget _examCard(Map g) {
    final subs = g['subjects'] as List;
    final pct = g['percentage'];
    final grade = g['grade'];
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
                Expanded(child: Text(g['exam_group'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                if (grade != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: RiyoTheme.brand, borderRadius: BorderRadius.circular(8)),
                    child: Text(grade, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...subs.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(s['subject'] ?? '')),
                      Text('${s['get_marks'] ?? '-'} / ${s['max_marks'] ?? '-'}',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: (s['get_marks'] != null && s['max_marks'] != null && (s['get_marks'] as num) < (s['max_marks'] as num) * 0.5)
                                  ? Colors.red
                                  : RiyoTheme.text)),
                    ],
                  ),
                )),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.w600)),
                Text('${g['total_get'] ?? '-'} / ${g['total_max'] ?? '-'}'),
              ],
            ),
            if (pct != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Percentage', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('$pct%', style: const TextStyle(fontWeight: FontWeight.bold, color: RiyoTheme.brand)),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: (double.tryParse(pct.toString()) ?? 0) / 100,
                backgroundColor: RiyoTheme.brandLight,
                color: RiyoTheme.brand,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
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
  final _api = RiyoApi();
  List _rows = [];
  bool _busy = true;
  String _month = '';

  @override
  void initState() {
    super.initState();
    _month = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final r = await _api.attendance(_month);
      _rows = r['attendance'] ?? [];
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
                      return DropdownMenuItem(value: val, child: Text(_monthLabel(val)));
                    }),
                    onChanged: (v) { if (v != null) { _month = v; _load(); } },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _busy
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                      ? const Center(child: Text('No attendance records for this month.'))
                      : ListView.builder(
                          itemCount: _rows.length,
                          itemBuilder: (_, i) {
                            final status = _rows[i]['status'] ?? _rows[i]['remark'] ?? '';
                            final present = status.toLowerCase().contains('present');
                            return Card(
                              child: ListTile(
                                leading: Icon(present ? Icons.check_circle : Icons.cancel, color: present ? Colors.green : Colors.red),
                                title: Text(_rows[i]['date'] ?? ''),
                                trailing: Chip(label: Text(status)),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      );

  String _monthLabel(String ym) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final parts = ym.split('-');
    return '${names[int.parse(parts[1]) - 1]} ${parts[0]}';
  }
}

class FeesScreen extends StatefulWidget {
  const FeesScreen({super.key});
  @override
  State<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends State<FeesScreen> {
  final _api = RiyoApi();
  Map? _f;
  bool _busy = true;
  @override
  void initState() { super.initState(); _api.fees().then((r) { _f = r['fees']; if (mounted) setState(() => _busy = false); }); }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Fees')),
        body: _busy
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _line('Expected', _f?['expected']?.toString() ?? '0'),
                    _line('Paid', _f?['paid']?.toString() ?? '0'),
                    _line('Balance', _f?['balance']?.toString() ?? '0', color: Colors.red),
                  ],
                ),
              ),
      );
  Widget _line(String k, String v, {Color? color}) => Card(
        child: ListTile(title: Text(k), trailing: Text(v, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold))),
      );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = RiyoApi();
  Map? _s;
  bool _busy = true;
  @override
  void initState() { super.initState(); _api.profile().then((r) { _s = r['student']; if (mounted) setState(() => _busy = false); }); }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: _busy
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _line('Admission No', _s?['admission_no'] ?? ''),
                  _line('Name', '${_s?['firstname']} ${_s?['lastname']}'),
                  _line('Gender', _s?['gender'] ?? ''),
                  _line('Class', _s?['class'] ?? ''),
                  _line('Section', _s?['section'] ?? ''),
                ],
              ),
      );
  Widget _line(String k, String v) => Card(child: ListTile(title: Text(k, style: const TextStyle(color: RiyoTheme.muted)), trailing: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))));
}
