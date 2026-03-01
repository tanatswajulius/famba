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
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic)),
    );
    _controller.forward();

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
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
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
        setState(() { _error = result['detail'] ?? 'Invalid phone or password'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection error. Please try again.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FambaColors.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 48),
              FadeTransition(
                opacity: _fadeIn,
                child: Column(
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.motorcycle_rounded, size: 36, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'famba driver',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -2,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Earn on every ride',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              SlideTransition(
                position: _slideUp,
                child: FadeTransition(
                  opacity: _fadeIn,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: Row(
                            children: [
                              _tabButton("Sign In", _isLogin, () => setState(() => _isLogin = true)),
                              _tabButton("Register", !_isLogin, () => setState(() => _isLogin = false)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (!_isLogin) ...[
                          _inputField(_nameCtrl, "Full Name", Icons.person_outline_rounded, false, TextInputType.name),
                          const SizedBox(height: 14),
                        ],
                        _inputField(_phoneCtrl, "Phone Number", Icons.phone_outlined, false, TextInputType.phone),
                        const SizedBox(height: 14),
                        _inputField(_passCtrl, "Password", Icons.lock_outline_rounded, true, TextInputType.visiblePassword),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: FambaColors.error.withValues(alpha: 0.08),
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
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FambaColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: FambaColors.primary.withValues(alpha: 0.5),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _loading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                : Text(_isLogin ? "Sign In" : "Create Account", style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: _fadeIn,
                child: Wrap(
                  spacing: 10, runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    _featurePill(Icons.motorcycle_rounded, "Ride requests"),
                    _featurePill(Icons.restaurant_rounded, "Food deliveries"),
                    _featurePill(Icons.attach_money_rounded, "Track earnings"),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)] : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600,
              color: active ? FambaColors.textPrimary : FambaColors.textSecondary,
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
      textCapitalization: type == TextInputType.name ? TextCapitalization.words : TextCapitalization.none,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: Icon(icon, color: FambaColors.primary, size: 22),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: FambaColors.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _featurePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }
}
