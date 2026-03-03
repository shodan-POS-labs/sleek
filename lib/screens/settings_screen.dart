import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/app_user.dart';
import '../models/business_config.dart';
import '../utils/error_helpers.dart';
import '../utils/database_seeder.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = AuthService();
  final _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final isAdmin = user?.role.name == 'admin';
    final settingsSections = [
      {
        'title': 'Account',
        'items': [
          {'icon': LucideIcons.user, 'label': 'Profile Settings', 'color': AppTheme.info, 'bg': const Color(0xFFEFF6FF), 'action': 'profile_settings'},
          {'icon': LucideIcons.bell, 'label': 'Notifications', 'color': AppTheme.purple, 'bg': const Color(0xFFFAF5FF), 'action': 'notifications'},
        ],
      },
      {
        'title': 'Preferences',
        'items': [
          {'icon': LucideIcons.receipt, 'label': 'Receipt Settings', 'color': AppTheme.warning, 'bg': const Color(0xFFFFF7ED), 'action': 'receipt_settings'},
          {'icon': LucideIcons.printer, 'label': 'Printer Settings', 'color': AppTheme.info, 'bg': const Color(0xFFEFF6FF), 'action': 'printer_settings'},
          {'icon': LucideIcons.shieldCheck, 'label': 'Privacy Policy', 'color': AppTheme.error, 'bg': const Color(0xFFFEF2F2), 'action': 'privacy_policy'},
        ],
      },
      {
        'title': 'Support',
        'items': [
          {'icon': LucideIcons.helpCircle, 'label': 'Help & Support', 'color': const Color(0xFF0891B2), 'bg': const Color(0xFFECFEFF), 'action': 'help_support'},
        ],
      },
      if (isAdmin)
        {
          'title': 'Management',
          'items': [
            {'icon': LucideIcons.users, 'label': 'Add Cashier', 'color': AppTheme.warning, 'bg': const Color(0xFFFFF7ED), 'action': 'add_cashier'},
          ],
        },
      if (isAdmin)
        {
          'title': 'Cloud Backup & Sync',
          'items': [
            {'icon': LucideIcons.cloud, 'label': 'Cloud Sync is Active (Auto)', 'color': AppTheme.primaryColor, 'bg': AppTheme.primarySurface},
          ],
        },
      if (isAdmin)
        {
          'title': 'Developer Tools',
          'items': [
            {'icon': LucideIcons.database, 'label': 'Seed Database (Test Data)', 'color': const Color(0xFFD97706), 'bg': const Color(0xFFFEF3C7), 'action': 'seed_database'},
          ],
        },
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 24, right: 24, bottom: 32,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [BoxShadow(color: Color(0x20000000), blurRadius: 15, offset: Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Settings', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w500, color: Colors.white)),
                const SizedBox(height: 16),
                // Profile Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(LucideIcons.user, size: 32, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'User', 
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.email ?? 'No email set', 
                              style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withOpacity(0.7)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isAdmin ? 'Admin / Owner' : 'Cashier', 
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.7)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Settings Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ...settingsSections.map((section) {
                    final items = section['items'] as List<Map<String, dynamic>>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Text(
                              section['title'] as String,
                              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ),
                          ...items.map((item) {
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  if (item['action'] == 'add_cashier') {
                                    _showAddCashierDialog(context);
                                  } else if (item['action'] == 'profile_settings') {
                                    _showProfileSettingsDialog(context);
                                  } else if (item['action'] == 'receipt_settings') {
                                    _showReceiptSettingsDialog(context);
                                  } else if (item['action'] == 'printer_settings') {
                                    _showPrinterSettingsDialog(context);
                                  } else if (item['action'] == 'privacy_policy') {
                                    _showPrivacyPolicyDialog(context);
                                  } else if (item['action'] == 'help_support') {
                                    _showHelpSupportDialog(context);
                                  } else if (item['action'] == 'notifications') {
                                    _showNotificationsDialog(context);
                                  } else if (item['action'] == 'seed_database') {
                                    _showSeedDatabaseDialog(context);
                                  }
                                },
                                borderRadius: BorderRadius.circular(0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border(bottom: BorderSide(color: AppTheme.borderLight.withOpacity(0.5))),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44, height: 44,
                                        decoration: BoxDecoration(
                                          color: item['bg'] as Color,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(item['icon'] as IconData, size: 20, color: item['color'] as Color),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          item['label'] as String,
                                          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary),
                                        ),
                                      ),
                                      const Icon(LucideIcons.chevronRight, size: 20, color: AppTheme.textTertiary),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),

                  // App Info
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.primarySurface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(LucideIcons.store, size: 32, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(height: 12),
                        Text('ShopFlow POS', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text('Version 1.0.0', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(height: 8),
                        Text('Â© 2026 ShopFlow. All rights reserved.', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await _auth.logout();
                        if (context.mounted) context.go('/login');
                      },
                      icon: const Icon(LucideIcons.logOut, size: 20, color: AppTheme.error),
                      label: Text('Logout', style: GoogleFonts.inter(fontSize: 16, color: AppTheme.error)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFFEF2F2),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 4),
    );
  }

  Future<void> _showSeedDatabaseDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(LucideIcons.alertTriangle, color: Color(0xFFD97706), size: 22),
            const SizedBox(width: 8),
            Text('Seed Database', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'This will create 3 test shops (Pharmacy, Restaurant, Retail) with full dummy data including products, sales, customers, and notifications.\n\n'
          'Accounts:\n'
          '• somapalagalagedara@gmail.com → Pharmacy\n'
          '• dingiribanda125@gmail.com → Restaurant\n'
          '• pabasaraf79@gmail.com → Retail\n\n'
          'Password: Test@1234  |  PIN: 123456\n\n'
          'This may take a minute. Continue?',
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Seed Now', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              const CircularProgressIndicator(color: AppTheme.primaryColor),
              const SizedBox(height: 20),
              Text('Seeding database...', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Creating shops, users, products, sales...',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ),
    );

    String result;
    try {
      result = await DatabaseSeeder.seed();
    } catch (e) {
      result = 'Error: $e';
    }

    if (!context.mounted) return;
    Navigator.pop(context); // Dismiss progress dialog

    // Show result
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Seed Result', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: SelectableText(result, style: GoogleFonts.firaCode(fontSize: 11, height: 1.5)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Done', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddCashierDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    bool isAdding = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Add Cashier', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email Address'),
                      validator: (v) => !v!.contains('@') ? 'Valid email required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password (min 6 chars)'),
                      validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: pinCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: '6-Digit App PIN'),
                      validator: (v) => v!.length != 6 ? 'Must be 6 digits' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: isAdding ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: isAdding ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  setStateSB(() => isAdding = true);
                  try {
                    await _auth.addCashier(
                      name: nameCtrl.text.trim(),
                      email: emailCtrl.text.trim(),
                      password: passCtrl.text,
                      pin: pinCtrl.text,
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cashier added securely via Firebase Auth.')));
                    }
                  } catch (e) {
                    setStateSB(() => isAdding = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: AppTheme.error));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                child: isAdding ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Add Cashier'),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _showProfileSettingsDialog(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final isAdmin = user.role == UserRole.admin;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: user.name);
    final currentPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final shopNameCtrl = TextEditingController();
    bool biometricEnabled = user.biometricEnabled;
    bool isLoading = false;
    
    // Pre-load shop name BEFORE opening the dialog
    if (isAdmin && user.shopId.isNotEmpty) {
      try {
        final shopData = await _firestoreService.getShopDetails(user.shopId);
        shopNameCtrl.text = shopData?['name'] as String? ?? '';
      } catch (_) {}
    }
    
    if (!context.mounted) return;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Profile Settings', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Personal Information', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: InputDecoration(labelText: 'Full Name', prefixIcon: const Icon(LucideIcons.user, color: AppTheme.primaryColor), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),
                      Text('Security', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: currentPinCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        obscureText: true,
                        decoration: InputDecoration(labelText: 'Current PIN (required to change)', prefixIcon: const Icon(LucideIcons.lock, color: AppTheme.textSecondary), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), counterText: ''),
                        validator: (v) {
                          if (newPinCtrl.text.isNotEmpty) {
                            if (v == null || v.isEmpty) return 'Required to set a new PIN';
                            if (v.length != 6) return 'Must be 6 digits';
                            if (!_auth.verifyPin(v)) return 'Incorrect current PIN';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: newPinCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        obscureText: true,
                        decoration: InputDecoration(labelText: 'New 6-Digit PIN (optional)', prefixIcon: const Icon(LucideIcons.key, color: AppTheme.primaryColor), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), counterText: ''),
                        validator: (v) {
                          if (v != null && v.isNotEmpty && v.length != 6) return 'Must be 6 digits';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Biometric Login', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                        value: biometricEnabled,
                        onChanged: (val) async {
                          try {
                            final success = await _auth.toggleBiometrics(val);
                            if (success && ctx.mounted) setStateSB(() => biometricEnabled = val);
                          } catch (e) {
                            if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: AppTheme.error));
                          }
                        },
                        activeColor: AppTheme.primaryColor,
                      ),
                      if (isAdmin) ...[
                        const SizedBox(height: 24),
                        Text('Shop Settings', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 1.2)),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: shopNameCtrl,
                          decoration: InputDecoration(labelText: 'Shop Name', prefixIcon: const Icon(LucideIcons.store, color: AppTheme.primaryColor), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                        const SizedBox(height: 20),
                        _AdminCategoriesSection(shopId: user.shopId, firestoreService: _firestoreService),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: isLoading ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  setStateSB(() => isLoading = true);
                  try {
                    await _auth.updateUserProfile(name: nameCtrl.text.trim(), pin: newPinCtrl.text.isNotEmpty ? newPinCtrl.text : null);
                    if (isAdmin && shopNameCtrl.text.isNotEmpty) {
                      await _firestoreService.updateShopDetails(user.shopId, {'name': shopNameCtrl.text.trim()});
                    }
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!'), backgroundColor: Colors.green));
                      setState(() {});
                    }
                  } catch (e) {
                    setStateSB(() => isLoading = false);
                    if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: AppTheme.error));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, minimumSize: const Size(0, 48)),
                child: isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  } 

  Future<void> _showReceiptSettingsDialog(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null || user.role != UserRole.admin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only Admins can change receipt settings.')));
      return;
    }

    final headerCtrl = TextEditingController();
    final footerCtrl = TextEditingController();
    
    // Pre-load existing settings BEFORE opening the dialog
    try {
      final data = await _firestoreService.getShopDetails(user.shopId);
      if (data != null && data['receiptSettings'] != null) {
        headerCtrl.text = data['receiptSettings']['header'] ?? '';
        footerCtrl.text = data['receiptSettings']['footer'] ?? '';
      }
    } catch (_) {}

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Receipt Settings', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Custom Messages', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: headerCtrl,
                    decoration: InputDecoration(
                      labelText: 'Header/Greeting',
                      prefixIcon: const Icon(LucideIcons.messageSquare, color: AppTheme.primaryColor),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: footerCtrl,
                    decoration: InputDecoration(
                      labelText: 'Footer/Thank You',
                      prefixIcon: const Icon(LucideIcons.messageSquare, color: AppTheme.primaryColor),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _firestoreService.updateShopDetails(user.shopId, {
                    'receiptSettings': {
                      'header': headerCtrl.text.trim(),
                      'footer': footerCtrl.text.trim(),
                    }
                  });
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt settings saved!'), backgroundColor: Colors.green));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                child: const Text('Save'),
              ),
            ],
          );
        }
      ),
    );
  }

  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<BluetoothDevice> devices = [];
  BluetoothDevice? selectedDevice;
  bool isConnected = false;

  void initPrinter() {
    bluetooth.onStateChanged().listen((state) {
      switch (state) {
        case BlueThermalPrinter.CONNECTED:
          setState(() { isConnected = true; });
          break;
        case BlueThermalPrinter.DISCONNECTED:
          setState(() { isConnected = false; });
          break;
      }
    });
  }

  Future<void> _showPrinterSettingsDialog(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(content: SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))),
    );
    try {
      devices = await bluetooth.getBondedDevices();
    } catch (_) {}
    if (context.mounted) Navigator.pop(context);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Printer Settings', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (devices.isEmpty)
                  Text('No paired Bluetooth printers found. Pair a printer in device settings first.', style: GoogleFonts.inter(color: AppTheme.error)),
                if (devices.isNotEmpty)
                  DropdownButtonFormField<BluetoothDevice>(
                    value: selectedDevice,
                    decoration: InputDecoration(
                      labelText: 'Select Printer',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: devices.map((d) => DropdownMenuItem(value: d, child: Text(d.name ?? 'Unknown'))).toList(),
                    onChanged: (val) {
                      setStateSB(() => selectedDevice = val);
                    },
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Status: ', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    Text(isConnected ? 'Connected' : 'Disconnected', style: GoogleFonts.inter(color: isConnected ? Colors.green : AppTheme.error)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: selectedDevice == null ? null : () async {
                          if (isConnected) {
                            await bluetooth.disconnect();
                            setStateSB(() => isConnected = false);
                            setState(() => isConnected = false);
                          } else {
                            try {
                              await bluetooth.connect(selectedDevice!);
                              setStateSB(() => isConnected = true);
                              setState(() => isConnected = true);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to connect: $e')));
                            }
                          }
                        },
                        child: Text(isConnected ? 'Disconnect' : 'Connect'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Close', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: (!isConnected || selectedDevice == null) ? null : () async {
                  await bluetooth.printCustom("ShopFlow POS", 3, 1);
                  await bluetooth.printNewLine();
                  await bluetooth.printCustom("Test Print Successful!", 1, 1);
                  await bluetooth.printNewLine();
                  await bluetooth.printNewLine();
                  await bluetooth.paperCut();
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                child: const Text('Test Print'),
              ),
            ],
          );
        }
      ),
    );
  }
  Future<void> _showPrivacyPolicyDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Privacy Policy', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Text(
            'We value your privacy. All ShopFlow POS data is stored securely in Firebase, '
            'with role-based access controls to protect sensitive business information. '
            'We do not sell your data to third parties. By using this application, you '
            'agree to our standard formality terms and conditions regarding data handling '
            'and offline sync backups.',
            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: GoogleFonts.inter(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _showHelpSupportDialog(BuildContext context) async {
    final messageCtrl = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Contact Support', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Send us a message and we will get back to you as soon as possible.', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                TextField(
                  controller: messageCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Describe your issue...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              OutlinedButton(
onPressed: isLoading ? null : () => Navigator.pop(ctx),
child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: isLoading ? null : () async {
                  if (messageCtrl.text.trim().isEmpty) return;
                  setStateSB(() => isLoading = true);
                  
                  try {
                    String username = 'somapalagalagedara@gmail.com';
                    String password = 'gmsq cxug zkhv jtik';
                    
                    final smtpServer = gmail(username, password);
                    final message = Message()
                      ..from = Address(username, 'ShopFlow POS App')
                      ..recipients.add('somapalagalagedara@gmail.com')
                      ..subject = 'Support Request: ShopFlow POS'
                      ..text = 'Support Request from ${_auth.currentUser?.name} (Shop ID: ${_auth.currentUser?.shopId})\n\nMessage:\n${messageCtrl.text.trim()}';

                    await send(message, smtpServer);
                    
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message sent successfully!'), backgroundColor: Colors.green));
                    }
                  } catch (e) {
                    setStateSB(() => isLoading = false);
                    if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send message: ${e.toString().split('\n')[0]}'), backgroundColor: AppTheme.error));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                child: isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Send'),
              ),
            ],
          );
        }
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS SETTINGS DIALOG
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _showNotificationsDialog(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final shopId = user.shopId;

    // Show the dialog immediately — load data inside with a spinner
    bool loadFired = false;
    bool dataReady = false;
    bool isSaving = false;
    Map<String, dynamic> prefs = {
      'dailySalesSummary': true,
      'lowStockAlerts': true,
      'expiringMedicineAlert': true,
      'expiredStockAlert': true,
      'newProductReminder': true,
      'pendingJobsReminder': true,
      'overdueJobsAlert': true,
      'restockReminder': true,
      'dailyMenuReminder': true,
    };
    BusinessConfig config = BusinessConfig.forType(BusinessType.retail);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {

          // Kick off the async load once
          if (!loadFired) {
            loadFired = true;
            Future.microtask(() async {
              try {
                final loadedPrefs = await _firestoreService.getNotificationPreferences(shopId);
                final loadedConfig = await _firestoreService.getBusinessConfig(shopId);
                if (ctx.mounted) {
                  setStateSB(() {
                    prefs = loadedPrefs;
                    config = loadedConfig;
                    dataReady = true;
                  });
                }
              } catch (_) {
                if (ctx.mounted) setStateSB(() => dataReady = true);
              }
            });
          }

          if (!dataReady) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Notifications', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              content: const SizedBox(
                width: double.maxFinite,
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
                ),
              ],
            );
          }
          // ── Helper to build a category header ──
          Widget sectionHeader(String title) => Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 4),
                child: Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1.2)),
              );

          // ── Helper to build a toggle row ──
          Widget toggle(
            String key,
            String label,
            String subtitle,
            IconData icon,
            Color iconColor,
          ) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: iconColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w500)),
                        Text(subtitle,
                            style: GoogleFonts.inter(
                                fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Switch(
                    value: prefs[key] == true,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (val) => setStateSB(() => prefs[key] = val),
                  ),
                ],
              ),
            );
          }

          // ── Build toggle list ──
          final children = <Widget>[
            sectionHeader('GENERAL'),
            toggle(
              'dailySalesSummary',
              'Daily Sales Summary',
              'Recap of yesterday\'s revenue & orders',
              LucideIcons.barChart2,
              AppTheme.primaryColor,
            ),
          ];

          // Stock alerts (retail + pharmacy)
          if (config.hasStockManagement) {
            children.add(sectionHeader('STOCK ALERTS'));
            children.add(toggle(
              'lowStockAlerts',
              'Low Stock Alerts',
              'When ${config.salesItemLabel.toLowerCase()}s fall below 10 units',
              LucideIcons.packageMinus,
              AppTheme.warning,
            ));
            // Retail-only restock reminder
            if (!config.hasExpiryTracking) {
              children.add(toggle(
                'restockReminder',
                'Weekly Restock Reminder',
                'Monday reminder to review & reorder inventory',
                LucideIcons.refreshCcw,
                AppTheme.info,
              ));
            }
          }

          // Pharmacy
          if (config.hasExpiryTracking) {
            children.add(sectionHeader('PHARMACY ALERTS'));
            children.add(toggle(
              'expiringMedicineAlert',
              'Expiring Medicine Alert',
              'Medicines expiring within 30 days',
              LucideIcons.timer,
              AppTheme.error,
            ));
            children.add(toggle(
              'expiredStockAlert',
              'Expired Stock Alert',
              'Medicines that have already expired',
              LucideIcons.alertOctagon,
              AppTheme.error,
            ));
            children.add(toggle(
              'newProductReminder',
              'New Product Reminder',
              'Weekly reminder to add newly received medicines',
              LucideIcons.plus,
              AppTheme.purple,
            ));
            children.add(toggle(
              'lowStockAlerts',
              'Low Stock Alerts',
              'When medicines fall below 10 units',
              LucideIcons.packageMinus,
              AppTheme.warning,
            ));
          }

          // Restaurant
          if (config.hasDineInTakeaway) {
            children.add(sectionHeader('RESTAURANT ALERTS'));
            children.add(toggle(
              'dailyMenuReminder',
              'Daily Menu Reminder',
              'Reminder to update specials or mark items unavailable',
              LucideIcons.chefHat,
              AppTheme.warning,
            ));
          }

          // Repair
          if (config.hasJobCards) {
            children.add(sectionHeader('JOB ALERTS'));
            children.add(toggle(
              'pendingJobsReminder',
              'Pending Jobs Reminder',
              'Daily reminder of uncompleted repair jobs',
              LucideIcons.clock,
              AppTheme.warning,
            ));
            children.add(toggle(
              'overdueJobsAlert',
              'Overdue Jobs Alert',
              'Jobs pending for more than 3 days',
              LucideIcons.alertTriangle,
              AppTheme.error,
            ));
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text('Notifications',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed:
                    isSaving ? null : () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: GoogleFonts.inter(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setStateSB(() => isSaving = true);
                        try {
                          await _firestoreService
                              .saveNotificationPreferences(shopId, prefs);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Notification preferences saved!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setStateSB(() => isSaving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(friendlyErrorMessage(e)),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminCategoriesSection extends StatefulWidget {
  final String shopId;
  final FirestoreService firestoreService;
  const _AdminCategoriesSection({required this.shopId, required this.firestoreService});

  @override
  State<_AdminCategoriesSection> createState() => _AdminCategoriesSectionState();
}

class _AdminCategoriesSectionState extends State<_AdminCategoriesSection> {
  List<String> _categories = [];
  bool _loading = true;
  final _newCatCtrl = TextEditingController();
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cats = await widget.firestoreService.getCategories(widget.shopId);
      if (mounted) setState(() { _categories = cats; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _addCategory() async {
    final name = _newCatCtrl.text.trim();
    if (name.isEmpty || _categories.contains(name)) return;
    setState(() => _adding = true);
    await widget.firestoreService.insertCategory(widget.shopId, name);
    _newCatCtrl.clear();
    await _load();
    setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Product Categories', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        if (_loading)
          const LinearProgressIndicator()
        else if (_categories.isEmpty)
          Text('No categories yet.', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13))
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _categories.map((c) => Chip(
              label: Text(c, style: GoogleFonts.inter(fontSize: 12)),
              backgroundColor: AppTheme.primaryColor.withOpacity(0.08),
              side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.2)),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () async {
                setState(() => _categories.remove(c));
              },
            )).toList(),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newCatCtrl,
                decoration: InputDecoration(
                  hintText: 'New category name...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _adding ? null : _addCategory,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), minimumSize: const Size(0, 40)),
              child: _adding ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.add, size: 20),
            ),
          ],
        ),
      ],
    );
  }
}








