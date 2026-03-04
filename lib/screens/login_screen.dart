import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/app_notification.dart';
import '../utils/error_helpers.dart';

class LoginScreen extends StatefulWidget {
  final bool startWithEmail;
  const LoginScreen({super.key, this.startWithEmail = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _db = FirestoreService();

  String _pin = '';
  bool _isLoading = false;
  bool _canCheckBiometrics = false;
  bool _obscurePassword = true;
  bool _moreOptionsExpanded = false;
  
  late bool _requiresEmailLogin = widget.startWithEmail;
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
      // Tell the system autofill to save credentials (Google Password Manager prompt)
      TextInput.finishAutofillContext();
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
              'Welcome Back',
              style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Log in with your email and password.',
              style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            AutofillGroup(
              child: Column(
                children: [
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email, AutofillHints.username],
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: const Icon(LucideIcons.user),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(LucideIcons.key),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye, size: 20),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
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
            const SizedBox(height: 20),
            Center(child: _buildMoreOptionsToggle()),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildOptionsList([
                _OptionItem(
                  icon: LucideIcons.keyRound,
                  label: 'Forgot Password?',
                  color: AppTheme.error,
                  onTap: () => _showForgotPasswordDialog(),
                ),
                _OptionItem(
                  icon: LucideIcons.lock,
                  label: 'Login with PIN',
                  onTap: () => setState(() {
                    _requiresEmailLogin = false;
                    _moreOptionsExpanded = false;
                  }),
                ),
                _OptionItem(
                  icon: LucideIcons.plusCircle,
                  label: 'Register a new shop',
                  onTap: () => context.go('/shop-setup'),
                ),
              ]),
              crossFadeState: _moreOptionsExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinLoginForm() {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 48),
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
            Text('Sleek POS', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
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
                    const SizedBox(height: 20),
                    _buildMoreOptionsToggle(),
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: _buildOptionsList([
                        _OptionItem(
                          icon: LucideIcons.keyRound,
                          label: 'Forgot PIN?',
                          color: AppTheme.error,
                          onTap: () => _showForgotPinDialog(),
                        ),
                        _OptionItem(
                          icon: LucideIcons.mail,
                          label: 'Use Email / Password',
                          onTap: () => setState(() {
                            _requiresEmailLogin = true;
                            _moreOptionsExpanded = false;
                          }),
                        ),
                        _OptionItem(
                          icon: LucideIcons.plusCircle,
                          label: 'Register a new shop',
                          onTap: () => context.go('/shop-setup'),
                        ),
                      ]),
                      crossFadeState: _moreOptionsExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreOptionsToggle() {
    return GestureDetector(
      onTap: () => setState(() => _moreOptionsExpanded = !_moreOptionsExpanded),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.textSecondary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'More options',
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: _moreOptionsExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(LucideIcons.chevronDown, size: 16, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsList(List<_OptionItem> items) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          children: items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final isLast = i == items.length - 1;
            return Column(
              children: [
                InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(i == 0 ? 16 : 0),
                    bottom: Radius.circular(isLast ? 16 : 0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(item.icon, size: 18, color: item.color ?? AppTheme.textSecondary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: item.color ?? AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        Icon(LucideIcons.chevronRight, size: 16, color: AppTheme.textTertiary),
                      ],
                    ),
                  ),
                ),
                if (!isLast)
                  Divider(height: 0, thickness: 1, color: AppTheme.borderLight, indent: 46),
              ],
            );
          }).toList(),
        ),
      ),
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

  // ── Forgot Password Dialog ──────────────────────────────────────────────

  void _showForgotPasswordDialog() {
    final resetEmailCtrl = TextEditingController(text: _emailCtrl.text);
    bool sending = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(LucideIcons.mailQuestion, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text('Reset Password', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter your email address and we\'ll send you a link to reset your password.',
                  style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: resetEmailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: const Icon(LucideIcons.mail),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              OutlinedButton(
                onPressed: sending ? null : () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: sending
                    ? null
                    : () async {
                        if (resetEmailCtrl.text.trim().isEmpty) return;
                        setStateSB(() => sending = true);
                        try {
                          await _auth.sendPasswordResetEmail(resetEmailCtrl.text.trim());
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password reset email sent! Check your inbox.'), backgroundColor: Colors.green),
                            );
                          }
                        } catch (e) {
                          setStateSB(() => sending = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: AppTheme.error),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, minimumSize: const Size(0, 48)),
                child: sending
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Send Reset Link'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Forgot PIN Dialog ───────────────────────────────────────────────────

  void _showForgotPinDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(LucideIcons.keyRound, color: AppTheme.warning),
            const SizedBox(width: 8),
            Text('Forgot PIN?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose how you want to reset your PIN:',
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            // Option 1: Admin self-reset
            _resetOptionTile(
              icon: LucideIcons.shield,
              color: AppTheme.primaryColor,
              title: 'I\'m an Admin',
              subtitle: 'Log in with email first, then change your PIN in Settings.',
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _requiresEmailLogin = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Log in with email, then go to Settings → Profile to reset your PIN.'),
                    duration: Duration(seconds: 4),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            // Option 2: Cashier → notify admin
            _resetOptionTile(
              icon: LucideIcons.userCircle,
              color: AppTheme.warning,
              title: 'I\'m a Cashier',
              subtitle: 'Send a request to your admin to reset your PIN.',
              onTap: () {
                Navigator.pop(ctx);
                _showCashierResetRequestDialog();
              },
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _resetOptionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight, size: 18, color: AppTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  // ── Cashier Reset Request ───────────────────────────────────────────────

  void _showCashierResetRequestDialog() {
    final emailCtrl = TextEditingController();
    bool sending = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Request PIN Reset', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter your email so we can find your account and notify your admin.',
                  style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Your Email',
                    prefixIcon: const Icon(LucideIcons.mail),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              OutlinedButton(
                onPressed: sending ? null : () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: sending
                    ? null
                    : () async {
                        final email = emailCtrl.text.trim();
                        if (email.isEmpty) return;
                        setStateSB(() => sending = true);
                        try {
                          // Find the cashier by email
                          final cashier = await _db.queryUserByEmail(email);
                          if (cashier == null) {
                            throw Exception('No account found with this email.');
                          }
                          // Find admin for the same shop
                          final admin = await _auth.getShopAdmin(cashier.shopId);
                          if (admin == null) {
                            throw Exception('Could not find your shop admin.');
                          }
                          // Create notification for admin
                          await _db.createNotification(
                            cashier.shopId,
                            AppNotification(
                              type: 'pin_reset_request',
                              title: 'PIN Reset Request',
                              body: '${cashier.name} ($email) has requested a PIN reset. Go to Settings → Manage Cashiers to reset their PIN.',
                              createdAt: DateTime.now(),
                              metadata: {
                                'requesterUid': cashier.uid,
                                'requesterName': cashier.name,
                                'requesterEmail': email,
                              },
                            ),
                          );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Reset request sent to your admin. They will set a new PIN for you.'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 4),
                              ),
                            );
                          }
                        } catch (e) {
                          setStateSB(() => sending = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: AppTheme.error),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning, foregroundColor: Colors.white, minimumSize: const Size(0, 48)),
                child: sending
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Send Request'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OptionItem {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _OptionItem({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });
}
