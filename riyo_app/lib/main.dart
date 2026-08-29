import 'package:flutter/material.dart';
import 'riyo_api.dart';
import 'api_config.dart';

void main() => runApp(const RiyoApp());

class RiyoApp extends StatelessWidget {
  const RiyoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Riyo',
        theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
        home: const LoginScreen(),
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
        appBar: AppBar(title: const Text('Riyo · Student Login')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/riyo_logo.png', height: 64),
              const SizedBox(height: 16),
              TextField(controller: _user, decoration: const InputDecoration(labelText: 'Admission No / Username')),
              TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
              const SizedBox(height: 16),
              if (_err.isNotEmpty) Text(_err, style: const TextStyle(color: Colors.red)),
              ElevatedButton(
                onPressed: _busy ? null : _login,
                child: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Login'),
              ),
            ],
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
                      title: Text(_dash?['student']?['firstname'] ?? ''),
                      subtitle: Text(
                          '${_dash?['student']?['class']} - ${_dash?['student']?['section']}'),
                      leading: const Icon(Icons.person),
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
        child: ListTile(leading: Icon(icon), title: Text(label), onTap: onTap),
      );

  void _push(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: const Center(child: Text('Use the menu items to view exam results, attendance, fees and profile.')),
      );
}

class ExamResultsScreen extends StatefulWidget {
  const ExamResultsScreen({super.key});
  @override
  State<ExamResultsScreen> createState() => _ExamResultsScreenState();
}

class _ExamResultsScreenState extends State<ExamResultsScreen> {
  final _api = RiyoApi();
  List _groups = [];
  bool _busy = true;
  @override
  void initState() { super.initState(); _api.examResults().then((r) { _groups = r['exam_groups'] ?? []; if (mounted) setState(() => _busy = false); }); }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Exam Results')),
        body: _busy
            ? const Center(child: CircularProgressIndicator())
            : _groups.isEmpty
                ? const Center(child: Text('No published exam results yet.'))
                : ListView.builder(
                    itemCount: _groups.length,
                    itemBuilder: (_, i) {
                      final g = _groups[i];
                      final subs = g['subjects'] as List;
                      return Card(
                        margin: const EdgeInsets.all(10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g['exam_group'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              ...subs.map((s) => ListTile(
                                    dense: true,
                                    title: Text(s['subject'] ?? ''),
                                    trailing: Text('${s['get_marks'] ?? '-'} / ${s['max_marks'] ?? '-'}'),
                                  )),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total', style: TextStyle(fontWeight: FontWeight.w600)),
                                  Text('${g['total_get'] ?? '-'} / ${g['total_max'] ?? '-'}'),
                                ],
                              ),
                              if (g['percentage'] != null)
                                Chip(label: Text('${g['percentage']}%')),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      );
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
  @override
  void initState() { super.initState(); _api.attendance().then((r) { _rows = r['attendance'] ?? []; if (mounted) setState(() => _busy = false); }); }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Attendance')),
        body: _busy
            ? const Center(child: CircularProgressIndicator())
            : _rows.isEmpty
                ? const Center(child: Text('No attendance records yet.'))
                : ListView.builder(
                    itemCount: _rows.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(_rows[i]['date'] ?? ''),
                      trailing: Chip(label: Text(_rows[i]['status'] ?? _rows[i]['remark'] ?? '')),
                    ),
                  ),
      );
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
  Widget _line(String k, String v, {Color? color}) => ListTile(
        title: Text(k), trailing: Text(v, style: TextStyle(color: color, fontSize: 18)),
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
  Widget _line(String k, String v) => ListTile(title: Text(k), trailing: Text(v));
}
