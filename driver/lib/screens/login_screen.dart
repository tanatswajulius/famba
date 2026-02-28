import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../core/driver_state.dart';
import '../core/driver_api.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _checkAppVersion();
      final state = context.read<DriverState>();
      final restored = await state.loadSavedAuth();
      if (restored && mounted) {
        DriverApi.setToken(state.accessToken);
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }

  Future<void> _checkAppVersion() async {
    try {
      final result = await DriverApi.checkAppVersion(currentVersion: '1.0.0');
      if (!mounted) return;
      if (result['force'] == true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Update Required'),
            content: Text(result['message'] ?? 'Please update Famba Driver to continue.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else if (result['update_available'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'A new version is available.')),
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    final password = _passCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    if (phone.isEmpty || password.isEmpty || (!_isLogin && name.isEmpty)) {
      setState(() => _error = "Please fill in all fields");
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      Map<String, dynamic> result;
      if (_isLogin) {
        result = await DriverApi.login(phone: phone, password: password);
      } else {
        result = await DriverApi.register(phone: phone, name: name, password: password);
      }

      if (result.containsKey('access_token')) {
        final token = result['access_token'] as String;
        DriverApi.setToken(token);

        final me = await DriverApi.getMe();

        if (mounted) {
          context.read<DriverState>().setAuth(
            driverId: me['id'] ?? '',
            name: me['name'] ?? name,
            phone: me['phone'] ?? phone,
            accessToken: token,
          );
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        setState(() {
          _error = result['detail'] ?? 'Authentication failed';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() { _error = 'Connection error. Check your network.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [FambaColors.surface, FambaColors.background],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  // Logo
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      color: FambaColors.primary,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: FambaColors.primary.withValues(alpha: 0.4),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.motorcycle, size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Famba Driver',
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1.5, color: FambaColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rides & Deliveries',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: FambaColors.textSecondary),
                  ),
                  const SizedBox(height: 40),

                  // Toggle
                  Container(
                    decoration: BoxDecoration(
                      color: FambaColors.card,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _tabBtn("Sign In", _isLogin, () => setState(() => _isLogin = true)),
                        _tabBtn("Register", !_isLogin, () => setState(() => _isLogin = false)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (!_isLogin) ...[
                    _inputField(_nameCtrl, "Full Name", Icons.person_outline, false, TextInputType.name),
                    const SizedBox(height: 14),
                  ],
                  _inputField(_phoneCtrl, "Phone Number", Icons.phone_outlined, false, TextInputType.phone),
                  const SizedBox(height: 14),
                  _inputField(_passCtrl, "Password", Icons.lock_outline, true, TextInputType.visiblePassword),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: FambaColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: FambaColors.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: const TextStyle(color: FambaColors.error, fontSize: 13, fontWeight: FontWeight.w500))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Text(_isLogin ? "Sign In" : "Create Account", style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Feature tags
                  Wrap(
                    spacing: 10, runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _featureTag(Icons.motorcycle_rounded, "Ride requests"),
                      _featureTag(Icons.restaurant_rounded, "Food deliveries"),
                      _featureTag(Icons.attach_money_rounded, "Track earnings"),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabBtn(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? FambaColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600,
              color: active ? Colors.white : FambaColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String hint, IconData icon, bool obscure, TextInputType type) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: type,
      style: const TextStyle(color: FambaColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: FambaColors.textSecondary),
        prefixIcon: Icon(icon, color: FambaColors.primary),
      ),
    );
  }

  Widget _featureTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: FambaColors.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: FambaColors.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: FambaColors.textPrimary)),
        ],
      ),
    );
  }
}
