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
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'dart:io';
import 'dart:typed_data';
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
          {'icon': LucideIcons.folderOpen, 'label': 'Saved Receipts', 'color': AppTheme.primaryColor, 'bg': const Color(0xFFF0FDF4), 'action': 'saved_receipts'},
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
            {'icon': LucideIcons.shieldAlert, 'label': 'Manage Cashiers', 'color': AppTheme.info, 'bg': const Color(0xFFEFF6FF), 'action': 'manage_cashiers'},
          ],
        },
      if (isAdmin)
        {
          'title': 'Cloud Backup & Sync',
          'items': [
            {'icon': LucideIcons.cloud, 'label': 'Cloud Sync is Active (Auto)', 'color': AppTheme.primaryColor, 'bg': AppTheme.primarySurface},
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
                                    context.push('/receipt-settings');
                                  } else if (item['action'] == 'saved_receipts') {
                                    context.push('/saved-receipts');
                                  } else if (item['action'] == 'printer_settings') {
                                    _showPrinterSettingsDialog(context);
                                  } else if (item['action'] == 'privacy_policy') {
                                    _showPrivacyPolicyDialog(context);
                                  } else if (item['action'] == 'help_support') {
                                    _showHelpSupportDialog(context);
                                  } else if (item['action'] == 'notifications') {
                                    _showNotificationsDialog(context);
                                  } else if (item['action'] == 'manage_cashiers') {
                                    _showManageCashiersDialog(context);
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
                        Text('Sleek POS', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text('Version 1.0.0', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(height: 8),
                        Text('\u00a9 2026 Sleek. All rights reserved.', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary)),
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
            insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
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
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: AppTheme.error));
                    }
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
            insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
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
      final allDevices = await bluetooth.getBondedDevices();
      // Filter out devices that are obviously not printers (headphones, speakers, watches, etc.)
      const _nonPrinterKeywords = ['headphone', 'earphone', 'earbud', 'buds', 'airpod', 'speaker',
        'watch', 'band', 'fitbit', 'garmin', 'galaxy watch', 'mi band', 'audio',
        'soundbar', 'jbl', 'sony wh', 'sony wf', 'bose', 'beats', 'airdots',
        'car', 'handsfree', 'hands-free', 'hfp', 'keyboard', 'mouse', 'gamepad',
        'controller', 'tv', 'laptop', 'phone', 'tablet', 'pc'];
      devices = allDevices.where((d) {
        final name = (d.name ?? '').toLowerCase();
        return !_nonPrinterKeywords.any((kw) => name.contains(kw));
      }).toList();
    } catch (_) {}
    if (context.mounted) Navigator.pop(context);

    if (!context.mounted) return;

    // WiFi printer state
    final wifiIpCtrl = TextEditingController();
    final wifiPortCtrl = TextEditingController(text: '9100');
    bool wifiConnected = false;
    bool wifiConnecting = false;
    String wifiStatus = 'Not connected';
    Socket? wifiSocket;
    int selectedTab = 0; // 0 = Bluetooth, 1 = WiFi

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          // ── Bluetooth content ──
          Widget bluetoothContent() => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (devices.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.bluetoothOff, size: 20, color: AppTheme.error),
                      const SizedBox(width: 8),
                      Expanded(child: Text('No paired Bluetooth printers found.\nPair a printer in device settings first.', style: GoogleFonts.inter(color: AppTheme.error, fontSize: 13))),
                    ],
                  ),
                ),
              if (devices.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.info, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(child: Text('Only thermal receipt printers are shown. If your printer is missing, make sure it is paired in device Bluetooth settings.', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary))),
                    ],
                  ),
                ),
                DropdownButtonFormField<BluetoothDevice>(
                  value: selectedDevice,
                  decoration: InputDecoration(
                    labelText: 'Select Printer',
                    prefixIcon: const Icon(LucideIcons.bluetooth, size: 18, color: AppTheme.info),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  isExpanded: true,
                  items: devices.map((d) => DropdownMenuItem(value: d, child: Text(d.name ?? 'Unknown', overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
                  onChanged: (val) {
                    setStateSB(() => selectedDevice = val);
                  },
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isConnected ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isConnected ? Colors.green.withOpacity(0.3) : AppTheme.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(isConnected ? LucideIcons.checkCircle2 : LucideIcons.xCircle, size: 18, color: isConnected ? Colors.green : AppTheme.error),
                    const SizedBox(width: 8),
                    Text(isConnected ? 'Connected' : 'Disconnected', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: isConnected ? Colors.green : AppTheme.error)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(isConnected ? LucideIcons.unplug : LucideIcons.plug, size: 16),
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
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: AppTheme.error));
                            }
                          }
                        }
                      },
                      label: Text(isConnected ? 'Disconnect' : 'Connect'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(LucideIcons.printer, size: 16),
                      onPressed: (!isConnected || selectedDevice == null) ? null : () async {
                        try {
                          await bluetooth.printCustom("Sleek POS", 3, 1);
                          await bluetooth.printNewLine();
                          await bluetooth.printCustom("Test Print Successful!", 1, 1);
                          await bluetooth.printNewLine();
                          await bluetooth.printNewLine();
                          await bluetooth.paperCut();
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test page sent to Bluetooth printer'), backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: AppTheme.error));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                      label: const Text('Test Print'),
                    ),
                  ),
                ],
              ),
            ],
          );

          // ── WiFi content ──
          Widget wifiContent() => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.wifi, size: 18, color: AppTheme.info),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Connect to a network/WiFi receipt printer using its IP address and port.', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary))),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: wifiIpCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Printer IP Address',
                  hintText: 'e.g. 192.168.1.100',
                  prefixIcon: const Icon(LucideIcons.globe, size: 18, color: AppTheme.info),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: wifiPortCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Port',
                  hintText: '9100',
                  prefixIcon: const Icon(LucideIcons.hash, size: 18, color: AppTheme.info),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: wifiConnected ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: wifiConnected ? Colors.green.withOpacity(0.3) : AppTheme.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    if (wifiConnecting)
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Icon(wifiConnected ? LucideIcons.checkCircle2 : LucideIcons.xCircle, size: 18, color: wifiConnected ? Colors.green : AppTheme.error),
                    const SizedBox(width: 8),
                    Expanded(child: Text(wifiStatus, style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13, color: wifiConnected ? Colors.green : (wifiConnecting ? AppTheme.textSecondary : AppTheme.error)))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(wifiConnected ? LucideIcons.unplug : LucideIcons.plug, size: 16),
                      onPressed: wifiConnecting ? null : () async {
                        final ip = wifiIpCtrl.text.trim();
                        final port = int.tryParse(wifiPortCtrl.text.trim()) ?? 9100;
                        if (ip.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter the printer IP address'), backgroundColor: AppTheme.error));
                          return;
                        }
                        if (wifiConnected) {
                          // Disconnect
                          try { wifiSocket?.destroy(); } catch (_) {}
                          setStateSB(() { wifiConnected = false; wifiSocket = null; wifiStatus = 'Disconnected'; });
                        } else {
                          // Connect
                          setStateSB(() { wifiConnecting = true; wifiStatus = 'Connecting to $ip:$port...'; });
                          try {
                            final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
                            wifiSocket = socket;
                            setStateSB(() { wifiConnected = true; wifiConnecting = false; wifiStatus = 'Connected to $ip:$port'; });
                          } catch (e) {
                            setStateSB(() { wifiConnecting = false; wifiStatus = friendlyErrorMessage(e); });
                          }
                        }
                      },
                      label: Text(wifiConnected ? 'Disconnect' : 'Connect'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(LucideIcons.printer, size: 16),
                      onPressed: !wifiConnected ? null : () async {
                        try {
                          final profile = await CapabilityProfile.load();
                          final generator = Generator(PaperSize.mm80, profile);
                          var bytes = <int>[];
                          bytes += generator.reset();
                          bytes += generator.text('Sleek POS', styles: const PosStyles(bold: true, align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size2));
                          bytes += generator.emptyLines(1);
                          bytes += generator.text('WiFi Test Print Successful!', styles: const PosStyles(align: PosAlign.center));
                          bytes += generator.emptyLines(2);
                          bytes += generator.cut();
                          wifiSocket?.add(Uint8List.fromList(bytes));
                          await wifiSocket?.flush();
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test page sent to WiFi printer'), backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: AppTheme.error));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                      label: const Text('Test Print'),
                    ),
                  ),
                ],
              ),
            ],
          );

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(LucideIcons.printer, color: AppTheme.info),
                const SizedBox(width: 8),
                Text('Printer Settings', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tab selector
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setStateSB(() => selectedTab = 0),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: selectedTab == 0 ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: selectedTab == 0 ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)] : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.bluetooth, size: 16, color: selectedTab == 0 ? AppTheme.info : AppTheme.textSecondary),
                                    const SizedBox(width: 6),
                                    Text('Bluetooth', style: GoogleFonts.inter(fontSize: 13, fontWeight: selectedTab == 0 ? FontWeight.w600 : FontWeight.normal, color: selectedTab == 0 ? AppTheme.textPrimary : AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setStateSB(() => selectedTab = 1),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: selectedTab == 1 ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: selectedTab == 1 ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)] : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.wifi, size: 16, color: selectedTab == 1 ? AppTheme.info : AppTheme.textSecondary),
                                    const SizedBox(width: 6),
                                    Text('WiFi', style: GoogleFonts.inter(fontSize: 13, fontWeight: selectedTab == 1 ? FontWeight.w600 : FontWeight.normal, color: selectedTab == 1 ? AppTheme.textPrimary : AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Tab content
                    if (selectedTab == 0) bluetoothContent(),
                    if (selectedTab == 1) wifiContent(),
                  ],
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () {
                  // Clean up wifi socket on close if still connected
                  if (wifiConnected && wifiSocket != null) {
                    try { wifiSocket!.destroy(); } catch (_) {}
                  }
                  Navigator.pop(ctx);
                },
                child: Text('Close', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Privacy Policy', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Text(
            'We value your privacy. All Sleek POS data is stored securely in Firebase, '
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
            insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
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
                      ..from = Address(username, 'Sleek POS App')
                      ..recipients.add('somapalagalagedara@gmail.com')
                      ..subject = 'Support Request: Sleek POS'
                      ..text = 'Support Request from ${_auth.currentUser?.name} (Shop ID: ${_auth.currentUser?.shopId})\n\nMessage:\n${messageCtrl.text.trim()}';

                    await send(message, smtpServer);
                    
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message sent successfully!'), backgroundColor: Colors.green));
                    }
                  } catch (e) {
                    setStateSB(() => isLoading = false);
                    if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: AppTheme.error));
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
              insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
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
            insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
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

  // ── Manage Cashiers (Admin resets cashier PIN) ─────────────────────────────

  Future<void> _showManageCashiersDialog(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null || user.role != UserRole.admin) return;

    bool loading = true;
    List<AppUser> cashiers = [];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          // Load cashiers on first build
          if (loading) {
            _firestoreService.getShopUsers(user.shopId).then((users) {
              if (ctx.mounted) {
                setStateSB(() {
                  cashiers = users.where((u) => u.role == UserRole.cashier).toList();
                  loading = false;
                });
              }
            });
          }

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(LucideIcons.users, color: AppTheme.info),
                const SizedBox(width: 8),
                Text('Manage Cashiers', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: loading
                  ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                  : cashiers.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.userX, size: 48, color: AppTheme.textTertiary),
                              const SizedBox(height: 12),
                              Text('No cashiers found', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: cashiers.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final c = cashiers[i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              leading: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(color: AppTheme.info.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                child: const Icon(LucideIcons.userCircle, color: AppTheme.info),
                              ),
                              title: Text(c.name, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                              subtitle: Text(c.email ?? '', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                              trailing: TextButton.icon(
                                icon: const Icon(LucideIcons.keyRound, size: 16),
                                label: const Text('Reset PIN'),
                                style: TextButton.styleFrom(foregroundColor: AppTheme.warning),
                                onPressed: () => _showResetCashierPinDialog(ctx, c, setStateSB),
                              ),
                            );
                          },
                        ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Close', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showResetCashierPinDialog(BuildContext parentCtx, AppUser cashier, void Function(void Function()) parentSetState) {
    final pinCtrl = TextEditingController();
    bool resetting = false;

    showDialog(
      context: parentCtx,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Reset PIN for ${cashier.name}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set a new 6-digit PIN for this cashier. No previous PIN is required.',
                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New 6-Digit PIN',
                    prefixIcon: const Icon(LucideIcons.key, color: AppTheme.warning),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    counterText: '',
                  ),
                ),
              ],
            ),
            actions: [
              OutlinedButton(
                onPressed: resetting ? null : () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: resetting
                    ? null
                    : () async {
                        if (pinCtrl.text.length != 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('PIN must be exactly 6 digits'), backgroundColor: AppTheme.error),
                          );
                          return;
                        }
                        setStateSB(() => resetting = true);
                        try {
                          await _auth.adminResetCashierPin(cashierUid: cashier.uid, newPin: pinCtrl.text);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('PIN reset for ${cashier.name}!'), backgroundColor: Colors.green),
                            );
                          }
                        } catch (e) {
                          setStateSB(() => resetting = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: AppTheme.error),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning, foregroundColor: Colors.white, minimumSize: const Size(0, 48)),
                child: resetting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Reset PIN'),
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

// Inline extension – kept at end of file
// No extra file needed



