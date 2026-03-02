// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import '../core/theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/product.dart';
import '../models/app_user.dart';
import '../models/business_config.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _db = FirestoreService();
  final _auth = AuthService();
  String _searchQuery = '';
  List<Product> _products = [];
  List<String> _categories = [];
  bool _loading = true;
  BusinessConfig _config = BusinessConfig.forType(BusinessType.retail);

  String get _shopId => _auth.currentUser?.shopId ?? '';
  bool get _isAdmin => _auth.currentUser?.role == UserRole.admin;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final config = await _db.getBusinessConfig(_shopId);
    final products = await _db.getProducts(_shopId, search: _searchQuery.isEmpty ? null : _searchQuery);
    final categories = await _db.getCategories(_shopId);
    if (mounted) setState(() { _config = config; _products = products; _categories = categories; _loading = false; });
  }

  void _showProductSheet({Product? existing}) {
    final isEditing = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final barcodeCtrl = TextEditingController(text: existing?.barcode ?? '');
    final retailCtrl = TextEditingController(text: existing != null ? existing.retailPrice.toString() : '');
    final wholesaleCtrl = TextEditingController(text: existing != null ? existing.wholesalePrice.toString() : '');
    final stockCtrl = TextEditingController(text: existing != null ? existing.stock.toString() : '');
    final batchCtrl = TextEditingController(text: existing?.batchNumber ?? '');
    final serviceChargeCtrl = TextEditingController(text: existing != null && existing.serviceCharge > 0 ? existing.serviceCharge.toString() : '');
    final deviceInfoCtrl = TextEditingController(text: existing?.deviceInfo ?? '');
    DateTime? selectedExpiry = existing?.expiryDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddProductSheet(
        config: _config,
        isEditing: isEditing,
        initialCategory: existing?.category,
        initialModifiers: existing?.modifiers ?? [],
        initialVariants: existing?.variants ?? [],
        initialExpiry: selectedExpiry,
        onExpiryChanged: (d) => selectedExpiry = d,
        nameCtrl: nameCtrl,
        barcodeCtrl: barcodeCtrl,
        retailCtrl: retailCtrl,
        wholesaleCtrl: wholesaleCtrl,
        stockCtrl: stockCtrl,
        batchCtrl: batchCtrl,
        serviceChargeCtrl: serviceChargeCtrl,
        deviceInfoCtrl: deviceInfoCtrl,
        categories: _categories,
        onSubmit: (category, modifiers, variants) async {
          if (nameCtrl.text.isEmpty) return;
          final product = Product(
            id: existing?.id,
            name: nameCtrl.text,
            barcode: barcodeCtrl.text,
            retailPrice: double.tryParse(retailCtrl.text) ?? 0,
            wholesalePrice: double.tryParse(wholesaleCtrl.text) ?? 0,
            stock: int.tryParse(stockCtrl.text) ?? 0,
            category: category ?? 'General',
            batchNumber: batchCtrl.text.isEmpty ? null : batchCtrl.text,
            serviceCharge: double.tryParse(serviceChargeCtrl.text) ?? 0,
            deviceInfo: deviceInfoCtrl.text.isEmpty ? null : deviceInfoCtrl.text,
            expiryDate: selectedExpiry,
            modifiers: modifiers,
            variants: variants,
          );
          if (isEditing) {
            await _db.updateProduct(_shopId, product);
          } else {
            await _db.insertProduct(_shopId, product);
          }
          if (!ctx.mounted) return;
          Navigator.of(ctx).pop();
          _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEditing ? '${_config.salesItemLabel} updated!' : '${_config.salesItemLabel} added successfully!'),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(Product p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete ${_config.salesItemLabel}?', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text('"${p.name}" will be permanently deleted.', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.inter(color: AppTheme.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true && p.id != null) {
      await _db.deleteProduct(_shopId, p.id!);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${p.name}" deleted'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  String _getEmoji(String category) {
    switch (category.toLowerCase()) {
      case 'dairy': return '🥛';
      case 'beverages': return '🥤';
      case 'personal care': return '🧼';
      case 'frozen': return '🌭';
      case 'instant food': return '🍜';
      case 'groceries': return '🌾';
      default: return '📦';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, left: 24, right: 24, bottom: 24),
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Color(0x20000000), blurRadius: 15, offset: Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_config.salesItemLabel} Management', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w500, color: Colors.white)),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: TextField(
                    onChanged: (v) { _searchQuery = v; _loadData(); },
                    decoration: InputDecoration(
                      hintText: _config.searchHint,
                      prefixIcon: const Padding(padding: EdgeInsets.only(left: 16, right: 12), child: Icon(LucideIcons.search, size: 20, color: AppTheme.textTertiary)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Products List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                : _products.isEmpty
                    ? Center(child: Text('No ${_config.salesItemLabel.toLowerCase()}s found', style: GoogleFonts.inter(color: AppTheme.textSecondary)))
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: AppTheme.primaryColor,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final p = _products[index];
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _isAdmin ? () => _showProductSheet(existing: p) : null,
                                onLongPress: _isAdmin ? () => _confirmDelete(p) : null,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderLight)),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 64, height: 64,
                                        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                                        child: Center(child: Text(_getEmoji(p.category), style: const TextStyle(fontSize: 28))),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(child: Text(p.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary))),
                                                if (_isAdmin) const Icon(LucideIcons.pencil, size: 14, color: AppTheme.textTertiary),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                  Text('Retail Price', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                                                  Text('Rs. ${NumberFormat('#,###').format(p.retailPrice.toInt())}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.primaryColor)),
                                                ])),
                                                if (_config.hasWholesalePrice)
                                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                    Text('Wholesale', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                                                    Text('Rs. ${NumberFormat('#,###').format(p.wholesalePrice.toInt())}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.info)),
                                                  ])),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                if (_config.hasStockManagement)
                                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                    Text('Stock', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                                                    Text('${p.stock} units', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: p.stock < 30 ? AppTheme.warning : AppTheme.textPrimary)),
                                                  ])),
                                                if (_config.hasBarcode)
                                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                    Text('Barcode', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                                                    Text(p.barcode, style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary)),
                                                  ])),
                                                if (p.modifiers.isNotEmpty)
                                                  Expanded(child: Text('${p.modifiers.length} add-ons', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.info))),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: _isAdmin ? FloatingActionButton(
        onPressed: () => _showProductSheet(),
        backgroundColor: AppTheme.primaryColor,
        elevation: 8,
        child: const Icon(LucideIcons.plus, size: 32, color: Colors.white),
      ) : null,
      bottomNavigationBar: const BottomNav(currentIndex: 2),
    );
  }
}

class _AddProductSheet extends StatefulWidget {
  final BusinessConfig config;
  final TextEditingController nameCtrl, barcodeCtrl, retailCtrl, wholesaleCtrl, stockCtrl;
  final TextEditingController batchCtrl, serviceChargeCtrl, deviceInfoCtrl;
  final List<String> categories;
  final void Function(String? category, List<Map<String, dynamic>> modifiers, List<Map<String, dynamic>> variants) onSubmit;

  final bool isEditing;
  final String? initialCategory;
  final List<Map<String, dynamic>> initialModifiers;
  final List<Map<String, dynamic>> initialVariants;
  final DateTime? initialExpiry;
  final ValueChanged<DateTime?>? onExpiryChanged;

  const _AddProductSheet({
    required this.config,
    this.isEditing = false,
    this.initialCategory,
    this.initialModifiers = const [],
    this.initialVariants = const [],
    this.initialExpiry,
    this.onExpiryChanged,
    required this.nameCtrl, required this.barcodeCtrl, required this.retailCtrl,
    required this.wholesaleCtrl, required this.stockCtrl,
    required this.batchCtrl, required this.serviceChargeCtrl, required this.deviceInfoCtrl,
    required this.categories, required this.onSubmit,
  });

  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
  String? _selectedCategory;
  DateTime? _selectedExpiry;
  final _categoryCtrl = TextEditingController();
  late final List<Map<String, dynamic>> _modifiers;
  late final List<Map<String, dynamic>> _variants;
  final _modNameCtrl = TextEditingController();
  final _modPriceCtrl = TextEditingController();
  final _varLabelCtrl = TextEditingController();
  final _varPriceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Seed from existing product data when editing
    _selectedExpiry = widget.initialExpiry;
    _modifiers = List<Map<String, dynamic>>.from(widget.initialModifiers);
    _variants = List<Map<String, dynamic>>.from(widget.initialVariants);
    if (widget.initialCategory != null) {
      // If it matches an existing category use dropdown, else use text field
      if (widget.categories.contains(widget.initialCategory)) {
        _selectedCategory = widget.initialCategory;
      } else {
        _categoryCtrl.text = widget.initialCategory!;
      }
    }
  }

  String get _effectiveCategory {
    if (_categoryCtrl.text.trim().isNotEmpty) return _categoryCtrl.text.trim();
    return _selectedCategory ?? 'General';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.borderMedium, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(widget.isEditing ? 'Edit ${c.salesItemLabel}' : c.addItemLabel, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),

            // ── Name (always) ──
            _label('${c.salesItemLabel} Name'),
            _field(widget.nameCtrl, c.itemNameHint),
            const SizedBox(height: 16),

            // ── Barcode (retail / pharmacy) ──
            if (c.hasBarcode) ...[
              _label('Barcode'),
              TextField(
                controller: widget.barcodeCtrl,
                decoration: InputDecoration(
                  hintText: 'Scan or enter barcode',
                  filled: true, fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderMedium)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderMedium)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
                  suffixIcon: IconButton(
                    icon: const Icon(LucideIcons.scan, color: AppTheme.primaryColor),
                    tooltip: 'Scan barcode',
                    onPressed: () async {
                      try {
                        final result = await BarcodeScanner.scan();
                        if (result.rawContent.isNotEmpty) {
                          setState(() => widget.barcodeCtrl.text = result.rawContent);
                        }
                      } catch (e) { /* cancelled */ }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Price row ──
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Price'),
                _field(widget.retailCtrl, '0.00', num: true),
              ])),
              if (c.hasWholesalePrice) ...[
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Wholesale Price'),
                  _field(widget.wholesaleCtrl, '0.00', num: true),
                ])),
              ],
            ]),
            const SizedBox(height: 16),

            // ── Stock (retail / pharmacy) ──
            if (c.hasStockManagement) ...[
              _label('Stock Quantity'),
              _field(widget.stockCtrl, '0', num: true),
              const SizedBox(height: 16),
            ],

            // ── Service Charge (repair) ──
            if (c.hasServiceCharge) ...[
              _label('Service Charge'),
              _field(widget.serviceChargeCtrl, '0.00', num: true),
              const SizedBox(height: 16),
            ],

            // ── Device Info (repair) ──
            if (c.hasDeviceTracking) ...[
              _label('Device IMEI / Serial'),
              _field(widget.deviceInfoCtrl, 'Enter device serial'),
              const SizedBox(height: 16),
            ],

            // ── Pharmacy: Batch + Expiry ──
            if (c.hasBatchTracking) ...[
              _label('Batch Number'),
              _field(widget.batchCtrl, 'Enter batch number'),
              const SizedBox(height: 16),
            ],
            if (c.hasExpiryTracking) ...[
              _label('Expiry Date'),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedExpiry ?? DateTime.now().add(const Duration(days: 365)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null && mounted) {
                    setState(() => _selectedExpiry = picked);
                    widget.onExpiryChanged?.call(picked);
                  }
                },
                icon: const Icon(LucideIcons.calendar, size: 16),
                label: Text(
                  _selectedExpiry != null
                      ? 'Expires: ${_selectedExpiry!.day}/${_selectedExpiry!.month}/${_selectedExpiry!.year}'
                      : 'Select Expiry Date',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  foregroundColor: _selectedExpiry != null ? AppTheme.primaryColor : null,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ══════════════════════════════════════════════════════
            // ── MODIFIERS / ADD-ONS (Restaurant) ──
            // ══════════════════════════════════════════════════════
            if (c.hasModifiers) ...[
              _label('Add-ons / Extras'),
              const SizedBox(height: 4),
              if (_modifiers.isNotEmpty)
                Wrap(
                  spacing: 8, runSpacing: 6,
                  children: _modifiers.asMap().entries.map((entry) {
                    final m = entry.value;
                    return Chip(
                      label: Text('${m['name']} +Rs.${(m['price'] as num).toInt()}', style: GoogleFonts.inter(fontSize: 12)),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setState(() => _modifiers.removeAt(entry.key)),
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.08),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _field(_modNameCtrl, 'e.g. Extra Cheese')),
                const SizedBox(width: 8),
                SizedBox(width: 80, child: _field(_modPriceCtrl, 'Price', num: true)),
                const SizedBox(width: 8),
                Material(
                  color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      if (_modNameCtrl.text.trim().isEmpty) return;
                      setState(() {
                        _modifiers.add({'name': _modNameCtrl.text.trim(), 'price': double.tryParse(_modPriceCtrl.text) ?? 0});
                        _modNameCtrl.clear(); _modPriceCtrl.clear();
                      });
                    },
                    child: const SizedBox(width: 44, height: 44, child: Icon(LucideIcons.plus, size: 20, color: Colors.white)),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
            ],

            // ══════════════════════════════════════════════════════
            // ── VARIANTS / SIZES (Restaurant) ──
            // ══════════════════════════════════════════════════════
            if (c.hasVariants) ...[
              _label('Size / Variants'),
              const SizedBox(height: 4),
              if (_variants.isNotEmpty)
                Wrap(
                  spacing: 8, runSpacing: 6,
                  children: _variants.asMap().entries.map((entry) {
                    final v = entry.value;
                    return Chip(
                      label: Text('${v['label']} +Rs.${(v['price'] as num).toInt()}', style: GoogleFonts.inter(fontSize: 12)),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setState(() => _variants.removeAt(entry.key)),
                      backgroundColor: const Color(0xFFEFF6FF),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _field(_varLabelCtrl, 'e.g. Large')),
                const SizedBox(width: 8),
                SizedBox(width: 80, child: _field(_varPriceCtrl, 'Price', num: true)),
                const SizedBox(width: 8),
                Material(
                  color: AppTheme.info, borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      if (_varLabelCtrl.text.trim().isEmpty) return;
                      setState(() {
                        _variants.add({'label': _varLabelCtrl.text.trim(), 'price': double.tryParse(_varPriceCtrl.text) ?? 0});
                        _varLabelCtrl.clear(); _varPriceCtrl.clear();
                      });
                    },
                    child: const SizedBox(width: 44, height: 44, child: Icon(LucideIcons.plus, size: 20, color: Colors.white)),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
            ],

            // ── Category (combined dropdown + text input) ──
            _label('Category'),
            const SizedBox(height: 4),
            if (widget.categories.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.borderMedium)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: Text('Select existing category', style: GoogleFonts.inter(color: AppTheme.textTertiary)),
                    value: _selectedCategory,
                    onChanged: (val) => setState(() { _selectedCategory = val; _categoryCtrl.clear(); }),
                    items: widget.categories.map((ct) => DropdownMenuItem(value: ct, child: Text(ct, style: GoogleFonts.inter()))).toList(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(child: Text('— or type a new one —', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary))),
              ),
            ],
            _field(_categoryCtrl, c.categoryHint),
            const SizedBox(height: 24),

            // ── Submit Button ──
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () => widget.onSubmit(_effectiveCategory, _modifiers, _variants),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                child: Text(widget.isEditing ? 'Save Changes' : c.addItemLabel, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
  );

  Widget _field(TextEditingController ctrl, String hint, {bool num = false}) => TextField(
    controller: ctrl,
    keyboardType: num ? TextInputType.number : TextInputType.text,
    decoration: InputDecoration(
      hintText: hint, filled: true, fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderMedium)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderMedium)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
    ),
  );
}

