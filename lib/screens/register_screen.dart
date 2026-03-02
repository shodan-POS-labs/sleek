import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../utils/error_helpers.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  int _step = 1; // 1: Admin setup, 2: Add Cashiers

  // Admin PIN setup controllers
  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();

  // Cashier controllers
  final _cashierNameCtrl = TextEditingController();
  final _cashierEmailCtrl = TextEditingController();
  final _cashierPasswordCtrl = TextEditingController();
  final _cashierPinCtrl = TextEditingController();

  final List<Map<String, String>> _addedCashiers = [];

  Future<void> _setupAdminPin() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      await _auth.setupAdminPIN(_pinCtrl.text);
      
      setState(() {
        _step = 2;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: Colors.red));
    }
  }

  Future<void> _addCashier() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      await _auth.addCashier(
        name: _cashierNameCtrl.text.trim(),
        email: _cashierEmailCtrl.text.trim(),
        password: _cashierPasswordCtrl.text,
        pin: _cashierPinCtrl.text,
      );
      setState(() {
        _addedCashiers.add({
          'name': _cashierNameCtrl.text.trim(),
          'email': _cashierEmailCtrl.text.trim(),
        });
        _cashierNameCtrl.clear();
        _cashierEmailCtrl.clear();
        _cashierPasswordCtrl.clear();
        _cashierPinCtrl.clear();
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cashier added!')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: _step == 1 ? _buildAdminStep() : _buildCashierStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(LucideIcons.lock, size: 64, color: AppTheme.primaryColor),
        const SizedBox(height: 24),
        Text(
          'Set Admin PIN',
          style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Set a 6-digit PIN for quick access to your shop.',
          style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        _buildTextField('6-Digit PIN', _pinCtrl, isPin: true, icon: LucideIcons.lock),
        const SizedBox(height: 16),
        _buildTextField('Confirm 6-Digit PIN', _confirmPinCtrl, isPin: true, icon: LucideIcons.lock, validator: (v) {
          if (v != _pinCtrl.text) return 'PINs do not match';
          return null;
        }),
        const SizedBox(height: 32),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _setupAdminPin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text('Save PIN & Continue', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildCashierStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(LucideIcons.users, size: 64, color: AppTheme.primaryColor),
        const SizedBox(height: 24),
        Text(
          'Add Cashiers',
          style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'You can add cashiers now or do it later from Settings.',
          style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        if (_addedCashiers.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.borderLight)),
            child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text('Added Cashiers:', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                 const SizedBox(height: 8),
                 ..._addedCashiers.map((c) => Text('• ${c['name']} (${c['email']})', style: GoogleFonts.inter())),
               ]
            ),
          ),
          const SizedBox(height: 24),
        ],
        _buildTextField('Cashier Name', _cashierNameCtrl, icon: LucideIcons.user),
        const SizedBox(height: 16),
        _buildTextField('Cashier Email', _cashierEmailCtrl, icon: LucideIcons.mail, isEmail: true),
        const SizedBox(height: 16),
        _buildTextField('Cashier Password (min 6 chars)', _cashierPasswordCtrl, icon: LucideIcons.key, obscure: true, minLength: 6),
        const SizedBox(height: 16),
        _buildTextField('Cashier 6-Digit PIN', _cashierPinCtrl, isPin: true, icon: LucideIcons.lock),
        const SizedBox(height: 24),
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _addCashier,
            icon: const Icon(LucideIcons.plus),
            label: Text('Add Cashier', style: GoogleFonts.inter()),
            style: OutlinedButton.styleFrom(
               foregroundColor: AppTheme.primaryColor,
               side: const BorderSide(color: AppTheme.primaryColor),
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              context.go('/dashboard');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text('Done, go to Dashboard', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label, 
    TextEditingController controller, {
    bool isPin = false, 
    bool obscure = false, 
    bool isEmail = false,
    int? minLength,
    IconData? icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPin || obscure,
      keyboardType: isPin ? TextInputType.number : (isEmail ? TextInputType.emailAddress : TextInputType.text),
      maxLength: isPin ? 6 : null,
      validator: validator ?? (value) {
        if (value == null || value.trim().isEmpty) return 'Required';
        if (minLength != null && value.length < minLength) return 'Must be at least $minLength chars';
        if (isEmail && !value.contains('@')) return 'Enter valid email';
        if (isPin && value.length != 6) return 'Must be 6 digits';
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: AppTheme.textSecondary) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderLight)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderLight)),
        counterText: '',
      ),
    );
  }
}
