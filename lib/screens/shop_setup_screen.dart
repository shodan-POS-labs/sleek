import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../models/business_config.dart';
import '../utils/error_helpers.dart';

class ShopSetupScreen extends StatefulWidget {
  const ShopSetupScreen({super.key});

  @override
  State<ShopSetupScreen> createState() => _ShopSetupScreenState();
}

class _ShopSetupScreenState extends State<ShopSetupScreen> {
  final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _shopNameCtrl = TextEditingController();
  final _adminNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  BusinessType _selectedType = BusinessType.retail;
  bool _isLoading = false;

  Future<void> _registerShop() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      await _auth.registerShopAndAdmin(
        shopName: _shopNameCtrl.text.trim(),
        adminName: _adminNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        businessType: _selectedType.name,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      
      // Navigate to step 2: Admin PIN setup
      context.go('/register-pin');
      
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(LucideIcons.store, size: 64, color: AppTheme.primaryColor),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to ShopFlow',
                    style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Let\'s setup your Shop and Admin Account.',
                    style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _buildTextField('Shop Name', _shopNameCtrl, icon: LucideIcons.building),
                  const SizedBox(height: 24),

                  // ── Business Type Selector ──────────────────────
                  Text(
                    'Business Type',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.2,
                    children: BusinessConfig.allTypes.map((config) {
                      final isSelected = _selectedType == config.type;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedType = config.type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryColor.withOpacity(0.08) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryColor : AppTheme.borderLight,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Text(config.emoji, style: const TextStyle(fontSize: 24)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  config.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                    color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 20),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  _buildTextField('Your Full Name', _adminNameCtrl, icon: LucideIcons.user),
                  const SizedBox(height: 16),
                  _buildTextField('Admin Email', _emailCtrl, icon: LucideIcons.mail, isEmail: true),
                  const SizedBox(height: 16),
                  _buildTextField('Password (min 6 chars)', _passwordCtrl, icon: LucideIcons.key, obscure: true, minLength: 6),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _registerShop,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text('Create Shop & Account', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label, 
    TextEditingController controller, {
    bool obscure = false, 
    bool isEmail = false,
    int? minLength,
    IconData? icon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Required field';
        if (minLength != null && value.length < minLength) return 'Must be at least $minLength characters';
        if (isEmail && !value.contains('@')) return 'Enter a valid email';
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: AppTheme.textSecondary) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderLight)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderLight)),
      ),
    );
  }
}
