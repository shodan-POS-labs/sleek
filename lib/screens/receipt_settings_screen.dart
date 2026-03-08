// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/app_theme.dart';
import '../models/receipt_settings.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/error_helpers.dart';

class ReceiptSettingsScreen extends StatefulWidget {
  const ReceiptSettingsScreen({super.key});

  @override
  State<ReceiptSettingsScreen> createState() => _ReceiptSettingsScreenState();
}

class _ReceiptSettingsScreenState extends State<ReceiptSettingsScreen> {
  final _auth = AuthService();
  final _db   = FirestoreService();

  ReceiptSettings _settings = const ReceiptSettings();
  bool _loading = true;
  bool _saving  = false;

  // controllers for editable text fields
  late final TextEditingController _bizNameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _taxIdCtrl;
  late final TextEditingController _thankYouCtrl;
  late final TextEditingController _returnPolicyCtrl;
  late final TextEditingController _warrantyCtrl;
  late final TextEditingController _headerNoteCtrl;

  @override
  void initState() {
    super.initState();
    _bizNameCtrl      = TextEditingController();
    _addressCtrl      = TextEditingController();
    _phoneCtrl        = TextEditingController();
    _emailCtrl        = TextEditingController();
    _taxIdCtrl        = TextEditingController();
    _thankYouCtrl     = TextEditingController();
    _returnPolicyCtrl = TextEditingController();
    _warrantyCtrl     = TextEditingController();
    _headerNoteCtrl   = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_bizNameCtrl, _addressCtrl, _phoneCtrl, _emailCtrl,
      _taxIdCtrl, _thankYouCtrl, _returnPolicyCtrl, _warrantyCtrl, _headerNoteCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final data = await _db.getShopDetails(user.shopId);
      ReceiptSettings loaded = const ReceiptSettings();
      if (data != null && data['receiptSettingsV2'] != null) {
        loaded = ReceiptSettings.fromMap(Map<String, dynamic>.from(data['receiptSettingsV2'] as Map));
      } else if (data != null) {
        // Pre-fill business info from shop profile
        loaded = loaded.copyWith(
          businessName: data['name']    as String? ?? '',
          address:      data['address'] as String? ?? '',
          phone:        data['phone']   as String? ?? '',
          email:        data['email']   as String? ?? '',
        );
      }
      _applyToControllers(loaded);
      setState(() { _settings = loaded; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _applyToControllers(ReceiptSettings s) {
    _bizNameCtrl.text      = s.businessName;
    _addressCtrl.text      = s.address;
    _phoneCtrl.text        = s.phone;
    _emailCtrl.text        = s.email;
    _taxIdCtrl.text        = s.taxId;
    _thankYouCtrl.text     = s.thankYouMessage;
    _returnPolicyCtrl.text = s.returnPolicy;
    _warrantyCtrl.text     = s.warrantyText;
    _headerNoteCtrl.text   = s.headerNote;
  }

  Future<void> _save() async {
    final user = _auth.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final final_ = _settings.copyWith(
        businessName:   _bizNameCtrl.text.trim(),
        address:        _addressCtrl.text.trim(),
        phone:          _phoneCtrl.text.trim(),
        email:          _emailCtrl.text.trim(),
        taxId:          _taxIdCtrl.text.trim(),
        thankYouMessage: _thankYouCtrl.text.trim(),
        returnPolicy:   _returnPolicyCtrl.text.trim(),
        warrantyText:   _warrantyCtrl.text.trim(),
        headerNote:     _headerNoteCtrl.text.trim(),
      );
      await _db.updateShopDetails(user.shopId, {'receiptSettingsV2': final_.toMap()});
      setState(() { _settings = final_; _saving = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt settings saved!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _setToggle(String key, bool value) {
    final updated = Map<String, bool>.from(_settings.toggles);
    updated[key] = value;
    setState(() => _settings = _settings.copyWith(toggles: updated));
  }

  void _applyTemplate(ReceiptTemplate t) {
    final newToggles = ReceiptSettings.defaultTogglesFor(t);
    setState(() => _settings = _settings.copyWith(template: t, toggles: newToggles));
  }

  @override
  Widget build(BuildContext context) {
    final isWifi = _settings.printerType == PrinterType.wifi;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        title: Text('Receipt Settings',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
        elevation: 0,
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionHeader('Template', LucideIcons.layoutTemplate),
                _templatePicker(),
                const SizedBox(height: 20),
                _sectionHeader('Printer Setup', LucideIcons.printer),
                _printerSetup(),
                const SizedBox(height: 20),
                _sectionHeader('Business Info', LucideIcons.building2),
                _businessInfoFields(),
                const SizedBox(height: 20),
                _sectionHeader('Show / Hide Sections', LucideIcons.toggleLeft),
                _togglesCard('Header', [
                  _toggle('showBusinessInfo', 'Business Name & Address'),
                  if (isWifi) _toggle('showTaxId',        'Tax / VAT ID'),
                  _toggle('showReceiptNumber','Receipt Number'),
                  _toggle('showDateTime',     'Date & Time'),
                  _toggle('showCashierName',  'Cashier Name'),
                ]),
                const SizedBox(height: 8),
                _togglesCard('Customer', [
                  _toggle('showCustomerInfo', 'Customer Name & Phone'),
                ]),
                const SizedBox(height: 8),
                _togglesCard('Items', [
                  if (isWifi) _toggle('showItemSKU',      'Product SKU / ID'),
                  _toggle('showVariants',     'Selected Variant (Size etc.)'),
                  _toggle('showModifiers',    'Add-ons / Modifiers'),
                  _toggle('showItemDiscount', 'Per-item Discount'),
                  _toggle('showItemNotes',    'Item Notes'),
                ]),
                const SizedBox(height: 8),
                _togglesCard('Totals', [
                  _toggle('showSubtotal',   'Subtotal'),
                  _toggle('showDiscount',   'Discount Total'),
                  if (isWifi) _toggle('showTax',        'Tax Amount'),
                  _toggle('showGrandTotal', 'Grand Total'),
                ]),
                const SizedBox(height: 8),
                _togglesCard('Payment', [
                  _toggle('showPaymentMethod', 'Payment Method'),
                  _toggle('showAmountPaid',    'Amount Paid'),
                  _toggle('showChange',        'Change'),
                ]),
                const SizedBox(height: 8),
                _togglesCard('Advance / Deposit', [
                  _toggle('showAdvanceAmount', 'Advance Amount Received'),
                  _toggle('showRemainingBal',  'Remaining Balance Due'),
                  _toggle('showDueDate',       'Due Date'),
                ]),
                const SizedBox(height: 8),
                _togglesCard('Business-Specific', [
                  _toggle('showExpiryDate',    'Expiry Date (Pharmacy)'),
                  _toggle('showBatchNumber',   'Batch Number (Pharmacy)'),
                  _toggle('showDoctorName',    'Doctor Name (Pharmacy)'),
                  _toggle('showTableNumber',   'Table Number (Restaurant)'),
                  _toggle('showOrderType',     'Order Type (Restaurant)'),
                  _toggle('showDeviceInfo',    'Device / IMEI (Repair)'),
                  _toggle('showTechnicianName','Technician Name (Repair)'),
                ]),
                const SizedBox(height: 8),
                _togglesCard('Footer', [
                  _toggle('showReturnPolicy',  'Return Policy Text'),
                  _toggle('showWarrantyText',  'Warranty Text'),
                  if (isWifi) _toggle('showSignatureBox',  'Signature Box'),
                  _toggle('showThankYouMsg',   'Thank You Message'),
                  if (isWifi) _toggle('showQRCode',        'QR Code'),
                ]),
                const SizedBox(height: 20),
                _sectionHeader('Custom Messages', LucideIcons.messageSquare),
                _customMessagesFields(),
                if (isWifi) ...[
                  const SizedBox(height: 20),
                  _sectionHeader('Appearance', LucideIcons.type),
                  _appearanceCard(),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(LucideIcons.save),
                    label: Text('Save Settings', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  // ── Section Header ──────────────────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.8)),
      ]),
    );
  }

  // ── Template Picker ──────────────────────────────────────────────────────

  Widget _templatePicker() {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ReceiptTemplate.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final t = ReceiptTemplate.values[i];
          final selected = _settings.template == t;
          return GestureDetector(
            onTap: () => _applyTemplate(t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 140,
              decoration: BoxDecoration(
                color: selected ? AppTheme.primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: selected ? AppTheme.primaryColor : AppTheme.borderLight, width: selected ? 2 : 1),
                boxShadow: selected ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))] : [],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_templateIcon(t), size: 22, color: selected ? Colors.white : AppTheme.primaryColor),
                  const SizedBox(height: 6),
                  Text(t.label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppTheme.textPrimary), maxLines: 1),
                  const SizedBox(height: 2),
                  Text(t.description, style: GoogleFonts.inter(fontSize: 9, color: selected ? Colors.white70 : AppTheme.textTertiary), maxLines: 2),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _templateIcon(ReceiptTemplate t) {
    switch (t) {
      case ReceiptTemplate.standard:       return LucideIcons.receipt;
      case ReceiptTemplate.advancePayment: return LucideIcons.banknote;
      case ReceiptTemplate.finalPayment:   return LucideIcons.checkCircle;
      case ReceiptTemplate.pharmacy:       return LucideIcons.pill;
      case ReceiptTemplate.restaurant:     return LucideIcons.utensils;
    }
  }

  // ── Printer Setup ────────────────────────────────────────────────────────

  Widget _printerSetup() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.borderLight)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Printer Type', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 10),
          Row(children: [
            _printerTypeChip(PrinterType.bluetooth, LucideIcons.bluetooth, 'Bluetooth'),
            const SizedBox(width: 10),
            _printerTypeChip(PrinterType.wifi, LucideIcons.wifi, 'WiFi / Network'),
          ]),
          const SizedBox(height: 16),
          Text('Paper Format', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PaperFormat.values.map((f) {
              final isThermal = f.isThermal;
              // Only show thermal formats for bluetooth, full formats for wifi
              if (_settings.printerType == PrinterType.bluetooth && !isThermal) return const SizedBox.shrink();
              if (_settings.printerType == PrinterType.wifi && isThermal) return const SizedBox.shrink();
              final selected = _settings.paperFormat == f;
              return GestureDetector(
                onTap: () => setState(() => _settings = _settings.copyWith(paperFormat: f)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primaryColor : AppTheme.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? AppTheme.primaryColor : AppTheme.borderMedium),
                  ),
                  child: Text(f.label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? Colors.white : AppTheme.textPrimary)),
                ),
              );
            }).toList(),
          ),
          if (_settings.printerType == PrinterType.wifi) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.primarySurface, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(LucideIcons.info, size: 14, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(child: Text('WiFi prints via your device\'s system print dialog. Supports any AirPrint / Google Cloud Print compatible printer.', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary))),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _printerTypeChip(PrinterType type, IconData icon, String label) {
    final selected = _settings.printerType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _settings = _settings.copyWith(
            printerType: type,
            paperFormat: type == PrinterType.bluetooth ? PaperFormat.mm80 : PaperFormat.a4,
          );
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : AppTheme.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppTheme.primaryColor : AppTheme.borderMedium),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: selected ? Colors.white : AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? Colors.white : AppTheme.textPrimary)),
        ]),
      ),
    );
  }

  // ── Business Info ────────────────────────────────────────────────────────

  Widget _businessInfoFields() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.borderLight)),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _field(_bizNameCtrl, 'Business Name', LucideIcons.building2),
          const SizedBox(height: 12),
          _field(_addressCtrl, 'Address', LucideIcons.mapPin),
          const SizedBox(height: 12),
          _field(_phoneCtrl, 'Phone', LucideIcons.phone),
          const SizedBox(height: 12),
          _field(_emailCtrl, 'Email', LucideIcons.mail),
          const SizedBox(height: 12),
          _field(_taxIdCtrl, 'Tax ID / VAT Number', LucideIcons.hash),
        ],
      ),
    );
  }

  // ── Toggles ──────────────────────────────────────────────────────────────

  Widget _togglesCard(String groupTitle, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.borderLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(groupTitle, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textTertiary, letterSpacing: 0.6)),
          ),
          ...rows,
        ],
      ),
    );
  }

  Widget _toggle(String key, String label) {
    final value = _settings.toggles[key] ?? _defaultToggle(key);
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      title: Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
      value: value,
      activeColor: AppTheme.primaryColor,
      onChanged: (v) => _setToggle(key, v),
      dense: true,
    );
  }

  bool _defaultToggle(String key) {
    return ReceiptSettings.defaultTogglesFor(_settings.template)[key] ?? false;
  }

  // ── Custom Messages ──────────────────────────────────────────────────────

  Widget _customMessagesFields() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.borderLight)),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _field(_headerNoteCtrl, 'Header Note (e.g. branch name / tagline)', LucideIcons.alignLeft),
          const SizedBox(height: 12),
          _field(_thankYouCtrl, 'Thank You Message', LucideIcons.heart),
          const SizedBox(height: 12),
          _field(_returnPolicyCtrl, 'Return Policy', LucideIcons.rotateCcw, maxLines: 2),
          const SizedBox(height: 12),
          _field(_warrantyCtrl, 'Warranty Text', LucideIcons.shieldCheck, maxLines: 2),
        ],
      ),
    );
  }

  // ── Appearance ────────────────────────────────────────────────────────────

  Widget _appearanceCard() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.borderLight)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Font Size', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 10),
          Row(children: ReceiptFontSize.values.map((fs) {
            final selected = _settings.fontSize == fs;
            final lbl = fs.name[0].toUpperCase() + fs.name.substring(1);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _settings = _settings.copyWith(fontSize: fs)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primaryColor : AppTheme.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? AppTheme.primaryColor : AppTheme.borderMedium),
                  ),
                  child: Text(lbl, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? Colors.white : AppTheme.textPrimary)),
                ),
              ),
            );
          }).toList()),
        ],
      ),
    );
  }

  // ── Shared field builder ──────────────────────────────────────────────────

  Widget _field(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: AppTheme.textTertiary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
    );
  }
}
