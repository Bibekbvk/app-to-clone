import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LoginVaultApp());
}

class LoginVaultApp extends StatelessWidget {
  const LoginVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login Vault',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF090D16),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF00E5FF),
          surface: Color(0xFF131B2E),
        ),
      ),
      home: const VaultScreen(),
    );
  }
}

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  static const _channel = MethodChannel('com.example.login_vault_app/sys_info');

  Map<String, String> _sysInfo = {};
  bool _isLoggedIn = false;
  String _currentUsername = '';
  String _sessionToken = '';
  String _loginTime = '';
  String _privateNote = '';

  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final info = await _channel.invokeMapMethod<String, dynamic>('getSysInfo');
      if (info != null) {
        _sysInfo = info.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      _currentUsername = prefs.getString('session_username') ?? '';
      _sessionToken = prefs.getString('session_token') ?? '';
      _loginTime = prefs.getString('session_time') ?? '';
      _privateNote = prefs.getString('private_note') ?? '';
      _noteController.text = _privateNote;
    });
  }

  Future<void> _handleLogin(String username) async {
    if (username.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final token = 'TOKEN_${DateTime.now().millisecondsSinceEpoch}_${username.toUpperCase()}';
    final timeStr = DateTime.now().toLocal().toString().substring(11, 19);

    await prefs.setBool('is_logged_in', true);
    await prefs.setString('session_username', username.trim());
    await prefs.setString('session_token', token);
    await prefs.setString('session_time', timeStr);

    setState(() {
      _isLoggedIn = true;
      _currentUsername = username.trim();
      _sessionToken = token;
      _loginTime = timeStr;
    });
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_logged_in');
    await prefs.remove('session_username');
    await prefs.remove('session_token');
    await prefs.remove('session_time');

    setState(() {
      _isLoggedIn = false;
      _currentUsername = '';
      _sessionToken = '';
      _loginTime = '';
      _userController.clear();
      _passController.clear();
    });
  }

  Future<void> _saveNote() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('private_note', _noteController.text);
    setState(() {
      _privateNote = _noteController.text;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved to isolated SharedPreferences!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _sysInfo['uid'] ?? 'Unknown';
    final pkg = _sysInfo['packageName'] ?? 'com.example.login_vault_app';
    final dataDir = _sysInfo['dataDir'] ?? '/data/user/0/...';

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔐 Login Vault (Account Sandbox)'),
        backgroundColor: const Color(0xFF10172A),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Kernel & Storage Diagnostics Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF131B2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF223150)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚙️ KERNEL & ISOLATION TELEMETRY',
                      style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  const SizedBox(height: 10),
                  _buildDiagRow('Linux Kernel UID', uid, const Color(0xFF10B981)),
                  _buildDiagRow('Package Identity', pkg, const Color(0xFF818CF8)),
                  _buildDiagRow('Storage Path', dataDir, const Color(0xFF94A3B8)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (!_isLoggedIn) ...[
              // Logged Out State
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1528),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE11D48).withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 48, color: Color(0xFFF43F5E)),
                    const SizedBox(height: 12),
                    const Text('🔒 NOT LOGGED IN', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('This instance has its own clean, isolated session.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13), textAlign: TextAlign.center),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _userController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: const Color(0xFF131B2E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.key_outlined),
                  filled: true,
                  fillColor: const Color(0xFF131B2E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),

              // Quick account preset buttons
              Wrap(
                spacing: 8,
                children: [
                  _buildPresetChip('Alice (Acc 1)'),
                  _buildPresetChip('Bob (Acc 2)'),
                  _buildPresetChip('Charlie (Acc 3)'),
                  _buildPresetChip('Boss (Acc 4)'),
                ],
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Log In to This Instance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: () => _handleLogin(_userController.text),
              ),
            ] else ...[
              // Logged In State
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF064E3B), Color(0xFF065F46)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 54, color: Color(0xFF34D399)),
                    const SizedBox(height: 10),
                    Text('LOGGED IN AS', style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 13, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_currentUsername, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Session: $_sessionToken', style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 11, fontFamily: 'monospace')),
                    ),
                    const SizedBox(height: 6),
                    Text('Logged in at: $_loginTime', style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Isolated Note Storage (Proof of private disk storage)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF131B2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF223150)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📝 ISOLATED PRIVATE NOTE', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        hintText: 'Enter secret note for this account...',
                        filled: true,
                        fillColor: const Color(0xFF090D16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.save_rounded, size: 18),
                        label: const Text('Save Note'),
                        onPressed: _saveNote,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Log Out (This Instance Only)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: _handleLogout,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiagRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: valueColor, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String name) {
    return ActionChip(
      label: Text(name),
      onPressed: () {
        _userController.text = name.split(' ').first;
        _passController.text = 'Password123';
      },
    );
  }
}
