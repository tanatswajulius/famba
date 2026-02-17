import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../core/api.dart';
import '../core/app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  late Animation<double> _scaleIn;

  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic)),
    );
    _scaleIn = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)),
    );
    _controller.forward();

    // Try to restore saved session
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final state = context.read<AppState>();
      final restored = await state.loadSavedAuth();
      if (restored && mounted) {
        Api.setToken(state.accessToken);
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
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
        result = await Api.login(phone: phone, password: password);
      } else {
        result = await Api.register(phone: phone, name: name, password: password);
      }

      if (result.containsKey('access_token')) {
        final token = result['access_token'] as String;
        Api.setToken(token);

        // Fetch user profile
        final me = await Api.getMe();

        if (mounted) {
          context.read<AppState>().setAuth(
            userId: me['id'] ?? '',
            name: me['name'] ?? name,
            phone: me['phone'] ?? phone,
            accessToken: token,
            refreshToken: result['refresh_token'] ?? '',
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [FambaColors.primary.withOpacity(0.15), FambaColors.background, Colors.white],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 48),
                // Logo
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Transform.scale(
                    scale: _scaleIn.value,
                    child: Opacity(opacity: _fadeIn.value, child: child),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(color: FambaColors.primary.withOpacity(0.3), blurRadius: 40, offset: const Offset(0, 16)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Image.asset('assets/images/famba.png', fit: BoxFit.contain),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text("Famba", style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -2, color: FambaColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text(
                        "Rides & Food Delivery",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: FambaColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // Toggle Login/Register
                SlideTransition(
                  position: _slideUp,
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              _tabButton("Sign In", _isLogin, () => setState(() => _isLogin = true)),
                              _tabButton("Register", !_isLogin, () => setState(() => _isLogin = false)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (!_isLogin) ...[
                          TextField(
                            controller: _nameCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              hintText: "Full Name",
                              prefixIcon: Icon(Icons.person_outline_rounded, color: FambaColors.primary),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            hintText: "Phone Number",
                            prefixIcon: Icon(Icons.phone_outlined, color: FambaColors.primary),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: "Password",
                            prefixIcon: Icon(Icons.lock_outline_rounded, color: FambaColors.primary),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: FambaColors.error.withOpacity(0.1),
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
                        const SizedBox(height: 16),
                        // Feature pills
                        Wrap(
                          spacing: 10, runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            _featurePill(Icons.flash_on_rounded, "Fast pickup"),
                            _featurePill(Icons.restaurant_rounded, "Food delivery"),
                            _featurePill(Icons.offline_bolt_rounded, "Works offline"),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)] : null,
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

  Widget _featurePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
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
