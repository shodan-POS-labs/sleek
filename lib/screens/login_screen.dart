import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../utils/error_helpers.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  String _pin = '';
  bool _isLoading = false;
  bool _canCheckBiometrics = false;
  
  bool _requiresEmailLogin = false;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await _auth.hasValidSessionForBiometrics();
    if (mounted) {
      setState(() => _canCheckBiometrics = available);
    }
  }

  void _onKeypadPressed(String val) {
    if (_pin.length < 6) {
      setState(() => _pin += val);
      if (_pin.length == 6) {
        _handleLogin();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    try {
      final user = await _auth.loginWithPIN(_pin);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (user != null) {
        context.go('/dashboard');
      } else {
        setState(() => _pin = '');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid PIN. Try again.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (e is StateError) {
        setState(() {
          _requiresEmailLogin = true;
          _pin = '';
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppTheme.error));
      } else {
        setState(() => _pin = '');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _handleBiometric() async {
    setState(() => _isLoading = true);
    try {
      final user = await _auth.loginWithBiometrics();
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (user != null) {
        context.go('/dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric login failed or not set up.')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (e is StateError) {
        setState(() {
          _requiresEmailLogin = true;
          _pin = '';
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppTheme.error));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _loginWithEmail() async {
    if (_emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await _auth.loginWithEmail(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
      if (mounted) context.go('/dashboard');
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: _requiresEmailLogin ? _buildEmailLoginForm() : _buildPinLoginForm(),
      ),
    );
  }

  Widget _buildEmailLoginForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(LucideIcons.mail, size: 64, color: AppTheme.primaryColor),
            const SizedBox(height: 24),
            Text(
              'Session Expired',
              style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please log in with your email and password.',
              style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(LucideIcons.user),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(LucideIcons.key),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _loginWithEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Log In', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _requiresEmailLogin = false),
              child: const Text('Back to PIN Login'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/shop-setup'),
              child: Text('Register a new shop', style: GoogleFonts.inter(color: AppTheme.primaryColor, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinLoginForm() {
    return Column(
      children: [
        const Spacer(flex: 2),
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: const Icon(LucideIcons.store, size: 40, color: Colors.white),
        ),
        const SizedBox(height: 24),
        Text('ShopFlow POS', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        Text('Enter your 6-digit PIN', style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondary)),
        const SizedBox(height: 48),

        // PIN Dots Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 16, height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < _pin.length ? AppTheme.primaryColor : AppTheme.borderMedium,
              ),
            );
          }),
        ),
        const SizedBox(height: 48),

        if (_isLoading)
          const CircularProgressIndicator(color: AppTheme.primaryColor)
        else
          // Custom Numeric Keypad
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ['1','2','3'].map(_buildKey).toList()),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ['4','5','6'].map(_buildKey).toList()),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: ['7','8','9'].map(_buildKey).toList()),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _canCheckBiometrics
                        ? IconButton(icon: const Icon(LucideIcons.fingerprint, size: 36, color: AppTheme.primaryColor), onPressed: _handleBiometric)
                        : const SizedBox(width: 64, height: 64),
                    _buildKey('0'),
                    IconButton(icon: const Icon(LucideIcons.delete, size: 32, color: AppTheme.textSecondary), onPressed: _onBackspace),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextButton(
                    onPressed: () => setState(() => _requiresEmailLogin = true),
                    child: const Text('Use Email / Password'),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/shop-setup'),
                  child: Text('Register a new shop', style: GoogleFonts.inter(color: AppTheme.primaryColor, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        const Spacer(flex: 3),
      ],
    );
  }

  Widget _buildKey(String val) {
    return InkWell(
      onTap: () => _onKeypadPressed(val),
      borderRadius: BorderRadius.circular(32),
      child: Container(
        width: 64, height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: AppTheme.borderLight)),
        child: Text(val, style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
      ),
    );
  }
}
