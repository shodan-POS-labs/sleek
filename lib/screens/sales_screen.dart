import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/business_config.dart';
import 'package:barcode_scan2/barcode_scan2.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _db = FirestoreService();
  final _auth = AuthService();
  String _searchQuery = '';
  bool _showCart = false;
  List<Product> _products = [];
  bool _loading = true;
  BusinessConfig _config = BusinessConfig.forType(BusinessType.retail);

  String get _shopId => _auth.currentUser?.shopId ?? '';

  // Cart: productId -> {product, quantity, modifiers, variant, notes}
  final Map<String, _CartEntry> _cart = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final config = await _db.getBusinessConfig(_shopId);
    final products = await _db.getProducts(_shopId, search: _searchQuery.isEmpty ? null : _searchQuery);
    if (mounted) setState(() { _config = config; _products = products; _loading = false; });
  }

  double get totalAmount {
    return _cart.values.fold(0.0, (sum, e) {
      final modPrice = e.selectedModifiers.fold(0.0, (s, m) => s + ((m['price'] as num?)?.toDouble() ?? 0));
      return sum + (e.product.retailPrice + e.variantPriceAdjustment + modPrice) * e.quantity;
    });
  }
  int get totalItems => _cart.values.fold(0, (sum, e) => sum + e.quantity);

  void _addToCart(Product product, {List<Map<String, dynamic>> modifiers = const [], String? variant, double variantPrice = 0}) {
    setState(() {
      final key = '${product.id}_${variant ?? ''}_${modifiers.map((m) => m['name']).join(',')}';
      if (_cart.containsKey(key)) {
        _cart[key]!.quantity++;
      } else {
        _cart[key] = _CartEntry(
          product: product,
          quantity: 1,
          selectedModifiers: modifiers,
          selectedVariant: variant,
          variantPriceAdjustment: variantPrice,
        );
      }
      _showCart = true;
    });
  }

  void _showModifierSheet(Product product) {
    final selected = <Map<String, dynamic>>[];
    String? chosenVariant;
    double variantPrice = 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.borderMedium, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(product.name, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Rs. ${NumberFormat('#,###').format(product.retailPrice.toInt())}', style: GoogleFonts.inter(fontSize: 16, color: AppTheme.primaryColor, fontWeight: FontWeight.w500)),

                // Scrollable middle section for variants & modifiers
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Variants (e.g. Small / Medium / Large)
                        if (product.variants.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('Size / Variant', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: product.variants.map((v) {
                              final label = v['label'] as String? ?? '';
                              final price = (v['price'] as num?)?.toDouble() ?? 0;
                              final isChosen = chosenVariant == label;
                              return ChoiceChip(
                                label: Text('$label (+Rs.${price.toInt()})'),
                                selected: isChosen,
                                onSelected: (_) => setStateSB(() { chosenVariant = label; variantPrice = price; }),
                                selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                              );
                            }).toList(),
                          ),
                        ],

                        // Modifiers (e.g. Extra Cheese, Extra Sauce)
                        if (product.modifiers.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('Add-ons / Extras', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                          const SizedBox(height: 8),
                          ...product.modifiers.map((m) {
                            final name = m['name'] as String? ?? '';
                            final price = (m['price'] as num?)?.toDouble() ?? 0;
                            final isOn = selected.any((s) => s['name'] == name);
                            return CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('$name (+Rs.${price.toInt()})', style: GoogleFonts.inter(fontSize: 14)),
                              value: isOn,
                              activeColor: AppTheme.primaryColor,
                              onChanged: (val) => setStateSB(() {
                                if (val == true) { selected.add(m); } else { selected.removeWhere((s) => s['name'] == name); }
                              }),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _addToCart(product, modifiers: selected, variant: chosenVariant, variantPrice: variantPrice);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text('Add to Cart', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _removeFromCart(String productId) {
    setState(() {
      _cart.remove(productId);
      if (_cart.isEmpty) _showCart = false;
    });
  }

  void _updateQuantity(String productId, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _removeFromCart(productId);
      } else {
        _cart[productId]?.quantity = quantity;
      }
    });
  }

  Future<void> _handlePayment() async {
    if (_cart.isEmpty) return;

    final invoiceNumber = await _db.generateInvoiceNumber(_shopId);
    final sale = Sale(
      invoiceNumber: invoiceNumber,
      totalAmount: totalAmount,
      paymentMethod: 'cash',
    );
    final saleItems = _cart.entries.map((e) => SaleItem(
      saleId: '', // Will be set by the DB
      productId: e.key,
      productName: e.value.product.name,
      price: e.value.product.retailPrice,
      quantity: e.value.quantity,
    )).toList();

    await _db.insertSale(_shopId, sale, saleItems);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment of Rs. ${NumberFormat('#,###').format(totalAmount.toInt())} processed! $invoiceNumber'),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      setState(() { _cart.clear(); _showCart = false; });
      _loadProducts(); // Refresh stock
    }
  }

  Future<void> _scanAndAddToCart() async {
    try {
      final result = await BarcodeScanner.scan();
      final barcode = result.rawContent;
      if (barcode.isEmpty) return;

      // First check if the product is already in the loaded list
      Product? found;
      try {
        found = _products.firstWhere((p) => p.barcode == barcode);
      } catch (_) {
        found = null;
      }

      // If not found in loaded list, query Firestore directly
      if (found == null) {
        final all = await _db.getProducts(_shopId);
        final matches = all.where((p) => p.barcode == barcode);
        found = matches.isEmpty ? null : matches.first;
      }


      if (found != null) {
        _addToCart(found);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${found.name}" to cart'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No product found with barcode: $barcode'),
            backgroundColor: AppTheme.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {
      // User cancelled scan
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 24, right: 24, bottom: 24,
                ),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Color(0x20000000), blurRadius: 15, offset: Offset(0, 5))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_config.salesScreenTitle, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w500, color: Colors.white)),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: TextField(
                        onChanged: (value) {
                          _searchQuery = value;
                          _loadProducts();
                        },
                        decoration: InputDecoration(
                          hintText: 'Search by name or barcode...',
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 16, right: 12),
                            child: Icon(LucideIcons.search, size: 20, color: AppTheme.textTertiary),
                          ),
                          suffixIcon: GestureDetector(
                            onTap: _scanAndAddToCart,
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(12)),
                              child: const Icon(LucideIcons.scan, size: 20, color: Colors.white),
                            ),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Product List
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                    : _products.isEmpty
                        ? Center(child: Text('No products found', style: GoogleFonts.inter(color: AppTheme.textSecondary)))
                        : ListView.builder(
                            padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: _showCart && _cart.isNotEmpty ? 300 : 16),
                            itemCount: _products.length,
                            itemBuilder: (context, index) {
                              final product = _products[index];
                              final emoji = _getEmoji(product.category);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.borderLight),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 56, height: 56,
                                      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                                      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(product.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 4),
                                          Text('Rs. ${NumberFormat('#,###').format(product.retailPrice.toInt())}', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                                          if (_config.hasStockManagement)
                                            Text('Stock: ${product.stock}', style: GoogleFonts.inter(fontSize: 12, color: product.stock < 30 ? AppTheme.warning : AppTheme.textSecondary)),
                                          if (_config.hasModifiers && product.modifiers.isNotEmpty)
                                            Text('${product.modifiers.length} add-ons available', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.info)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Material(
                                      color: product.stock > 0 ? AppTheme.primaryColor : AppTheme.textTertiary,
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: product.stock > 0 || !_config.hasStockManagement
                                            ? () {
                                                if (_config.hasModifiers && (product.modifiers.isNotEmpty || product.variants.isNotEmpty)) {
                                                  _showModifierSheet(product);
                                                } else {
                                                  _addToCart(product);
                                                }
                                              }
                                            : null,
                                        child: const SizedBox(width: 48, height: 48, child: Icon(LucideIcons.plus, size: 24, color: Colors.white)),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),

          // Cart Panel
          if (_showCart && _cart.isNotEmpty)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Drag handle to dismiss cart ──
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _showCart = false),
                      onVerticalDragUpdate: (details) {
                        if (details.primaryDelta != null && details.primaryDelta! > 10) {
                          setState(() => _showCart = false);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 4),
                        child: Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.borderMedium, borderRadius: BorderRadius.circular(2)))),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Cart ($totalItems items)', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: _cart.entries.map((entry) {
                          final e = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(e.product.name, style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      if (e.selectedVariant != null)
                                        Text('Variant: ${e.selectedVariant}', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.info)),
                                      if (e.selectedModifiers.isNotEmpty)
                                        Text(e.selectedModifiers.map((m) => m['name']).join(', '), style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                                      Text('Rs. ${NumberFormat('#,###').format(e.product.retailPrice.toInt())}', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.primaryColor)),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    _QuantityButton(label: '-', onTap: () => _updateQuantity(entry.key, e.quantity - 1), filled: false),
                                    SizedBox(width: 32, child: Center(child: Text('${e.quantity}', style: GoogleFonts.inter(fontSize: 14)))),
                                    _QuantityButton(label: '+', onTap: () => _updateQuantity(entry.key, e.quantity + 1), filled: true),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _removeFromCart(entry.key),
                                  child: const SizedBox(width: 32, height: 32, child: Icon(LucideIcons.trash2, size: 20, color: AppTheme.error)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), border: Border(top: BorderSide(color: AppTheme.borderMedium))),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Amount:', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
                              Text('Rs. ${NumberFormat('#,###.00').format(totalAmount)}', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity, height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _handlePayment,
                              icon: const Icon(LucideIcons.printer, size: 20),
                              label: Text('Pay & Print', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500)),
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Cart Badge FAB
          if (_cart.isNotEmpty && !_showCart)
            Positioned(
              bottom: 80, right: 16,
              child: GestureDetector(
                onTap: () => setState(() => _showCart = true),
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text('$totalItems', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                      Positioned(
                        top: 12, right: 12,
                        child: Container(
                          width: 20, height: 20,
                          decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                          child: Center(child: Text('!', style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    );
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
}

class _CartEntry {
  final Product product;
  int quantity;
  final List<Map<String, dynamic>> selectedModifiers;
  final String? selectedVariant;
  final double variantPriceAdjustment;
  _CartEntry({
    required this.product,
    required this.quantity,
    this.selectedModifiers = const [],
    this.selectedVariant,
    this.variantPriceAdjustment = 0,
  });
}

class _QuantityButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _QuantityButton({required this.label, required this.onTap, required this.filled});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: filled ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: filled ? null : Border.all(color: AppTheme.borderMedium),
        ),
        child: Center(child: Text(label, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: filled ? Colors.white : AppTheme.textPrimary))),
      ),
    );
  }
}
