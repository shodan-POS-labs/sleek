import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../utils/error_helpers.dart';
import '../services/receipt_service.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/business_config.dart';
import '../models/receipt_settings.dart';
import '../widgets/app_modals.dart';

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
    try {
      final config = await _db.getBusinessConfig(_shopId);
      final products = await _db.getProducts(_shopId, search: _searchQuery.isEmpty ? null : _searchQuery);
      if (mounted) setState(() { _config = config; _products = products; _loading = false; });
    } catch (e) {
      debugPrint("Error loading products for sale: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  double get totalAmount {
    return _cart.values.fold(0.0, (sum, e) {
      final modPrice = e.selectedModifiers.fold(0.0, (s, m) => s + ((m['price'] as num?)?.toDouble() ?? 0));
      double multiplier = e.product.isWeighable ? (e.quantity / (e.product.weightQuantity > 0 ? e.product.weightQuantity : 1.0)) : e.quantity;
      return sum + (e.product.retailPrice + e.variantPriceAdjustment + modPrice) * multiplier;
    });
  }
  int get totalItems => _cart.values.fold(0, (sum, e) => sum + (e.product.isWeighable ? 1 : e.quantity.toInt()));

  Future<void> _addToCart(Product product, {List<Map<String, dynamic>> modifiers = const [], String? variant, double variantPrice = 0}) async {
    if (product.isWeighable) {
      final weightCtrl = TextEditingController();
      final weight = await AppModals.showAppDialog<double>(
        context: context,
        title: 'Enter amount (${product.unitType})',
        child: TextField(
          controller: weightCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. 1.5 or 250',
          ),
        ),
        primaryAction: ElevatedButton(
          onPressed: () => Navigator.pop(context, double.tryParse(weightCtrl.text)),
          child: const Text('Add to Cart'),
        ),
        secondaryAction: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      );
      if (weight != null && weight > 0) {
        _executeAddToCart(product, modifiers: modifiers, variant: variant, variantPrice: variantPrice, quantity: weight);
      }
    } else {
      _executeAddToCart(product, modifiers: modifiers, variant: variant, variantPrice: variantPrice, quantity: 1.0);
    }
  }

  void _executeAddToCart(Product product, {List<Map<String, dynamic>> modifiers = const [], String? variant, double variantPrice = 0, required double quantity}) {
    final key = '${product.id}_${variant ?? ''}_${modifiers.map((m) => m['name']).join(',')}';
    double currentQty = 0;
    if (_cart.containsKey(key)) {
      currentQty = _cart[key]!.quantity;
    }

    if ((currentQty + quantity) > product.stock && _config.hasStockManagement) {
      _showStockWarning(product.stock);
      return;
    }

    setState(() {
      if (_cart.containsKey(key)) {
        _cart[key]!.quantity += quantity;
      } else {
        _cart[key] = _CartEntry(
          product: product,
          quantity: quantity,
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

  void _updateQuantity(String productId, double quantity) {
    if (!_cart.containsKey(productId)) return;
    final entry = _cart[productId]!;

    if (quantity > entry.product.stock && _config.hasStockManagement) {
      _showStockWarning(entry.product.stock);
      return;
    }

    setState(() {
      if (quantity <= 0) {
        _removeFromCart(productId);
      } else {
        _cart[productId]?.quantity = quantity;
      }
    });
  }

  void _showStockWarning(num max) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cannot exceed available stock ($max)'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handlePayment() async {
    if (_cart.isEmpty) return;
    setState(() => _loading = true);

    try {
      final invoiceNumber = await _db.generateInvoiceNumber(_shopId);
      final sale = Sale(
        invoiceNumber: invoiceNumber,
        totalAmount: totalAmount,
        paymentMethod: 'cash',
      );
      final saleItems = _cart.entries.map((e) => SaleItem(
        saleId: '',
        productId: e.value.product.id ?? '',
        productName: e.value.product.name,
        price: e.value.product.retailPrice,
        quantity: e.value.quantity,
        selectedModifiers: e.value.selectedModifiers,
        selectedVariant: e.value.selectedVariant,
        variantPriceAdjustment: e.value.variantPriceAdjustment,
        notes: '',
      )).toList();

      await _db.insertSale(_shopId, sale, saleItems);

      // ── Print & Save Receipt ──────────────────────────────
      if (mounted) {
        final shopData = await _db.getShopDetails(_shopId);
        ReceiptSettings receiptSettings = const ReceiptSettings();
        if (shopData != null && shopData['receiptSettingsV2'] != null) {
          receiptSettings = ReceiptSettings.fromMap(
              Map<String, dynamic>.from(shopData['receiptSettingsV2'] as Map));
        }

        final cashierName = _auth.currentUser?.name ?? '';
        try {
          if (!mounted) return;
          final savedFile = await ReceiptService().printReceipt(
            context: context,
            sale: sale,
            items: saleItems,
            settings: receiptSettings,
            shopDetails: shopData ?? {},
            cashierName: cashierName,
          );
          if (mounted) {
            setState(() { _cart.clear(); _showCart = false; _loading = false; });
            _loadProducts();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Rs. ${NumberFormat('#,###').format(totalAmount.toInt())} — $invoiceNumber  ·  Receipt saved'),
                backgroundColor: AppTheme.primaryColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                action: SnackBarAction(
                  label: 'Share',
                  textColor: Colors.white,
                  onPressed: () => ReceiptService().shareReceipt(savedFile),
                ),
              ),
            );
          }
        } catch (printErr) {
          // Print failed (e.g. no printer) — sale is still saved, just show info
          if (mounted) {
            setState(() { _cart.clear(); _showCart = false; _loading = false; });
            _loadProducts();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Payment saved — $invoiceNumber. Print failed: $printErr'),
                backgroundColor: AppTheme.warning,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _lookupAndAddBarcode(String barcode) async {
    // First check if the product is already in the loaded list
    Product? found;
    try {
      found = _products.firstWhere((p) => p.barcode == barcode);
    } catch (_) {
      found = null;
    }

    // If not found in loaded list, query Firestore directly for this specific barcode
    if (found == null) {
      found = await _db.getProductByBarcode(_shopId, barcode);
    }

    if (found != null) {
      _addToCart(found);
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.click);
      if (!mounted) return;
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No product found with this barcode'),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _openScannerSheet() {
    AppModals.showAppBottomSheet(
      context: context,
      title: 'Scan & Checkout',
      child: StatefulBuilder(
        builder: (ctx, setStateSB) => _ScannerCartSheet(
          cart: _cart,
          totalAmount: totalAmount,
          totalItems: totalItems,
          onScanned: (barcode) async {
            await _lookupAndAddBarcode(barcode);
            setStateSB(() {});
          },
          onUpdateQuantity: (key, qty) {
            _updateQuantity(key, qty);
            setStateSB(() {});
          },
          onRemove: (key) {
            _removeFromCart(key);
            setStateSB(() {});
          },
          onPay: () {
            Navigator.pop(ctx);
            _handlePayment();
          },
          formatPrice: (price) => 'Rs. ${NumberFormat('#,###').format(price.toInt())}',
          formatTotal: (price) => 'Rs. ${NumberFormat('#,###.00').format(price)}',
        ),
      ),
    );
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
                            onTap: _openScannerSheet,
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
                                            Text(
                                              product.isWeighable 
                                                ? 'Stock: ${product.stock} ${product.unitType}' 
                                                : 'Stock: ${product.stock.toInt()}', 
                                              style: GoogleFonts.inter(fontSize: 12, color: product.stock < 30 ? AppTheme.warning : AppTheme.textSecondary)
                                            ),
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
                                    if (e.product.isWeighable) ...[
                                      Text('${e.quantity} ${e.product.unitType}', style: GoogleFonts.inter(fontSize: 14)),
                                      IconButton(
                                        icon: const Icon(LucideIcons.edit2, size: 16, color: AppTheme.primaryColor),
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        constraints: const BoxConstraints(),
                                        onPressed: () async {
                                          final weightCtrl = TextEditingController(text: e.quantity.toString());
                                          final weight = await AppModals.showAppDialog<double>(
                                            context: context,
                                            title: 'Edit amount (${e.product.unitType})',
                                            child: TextField(
                                              controller: weightCtrl,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              autofocus: true,
                                              decoration: InputDecoration(
                                                filled: true,
                                                fillColor: const Color(0xFFF9FAFB),
                                                border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                    borderSide: BorderSide.none),
                                              ),
                                            ),
                                            primaryAction: ElevatedButton(
                                              onPressed: () => Navigator.pop(context, double.tryParse(weightCtrl.text)),
                                              child: const Text('Save Changes'),
                                            ),
                                            secondaryAction: TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                                            ),
                                          );
                                          if (weight != null && weight > 0) {
                                            _updateQuantity(entry.key, weight);
                                          }
                                        }
                                      ),
                                    ] else ...[
                                      _QuantityButton(label: '-', onTap: () => _updateQuantity(entry.key, e.quantity - 1), filled: false),
                                      SizedBox(width: 32, child: Center(child: Text('${e.quantity.toInt()}', style: GoogleFonts.inter(fontSize: 14)))),
                                      _QuantityButton(label: '+', onTap: () => _updateQuantity(entry.key, e.quantity + 1), filled: true),
                                    ],
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
  double quantity;
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

// ─── Inline Scanner + Cart Sheet ────────────────────────────────────────
class _ScannerCartSheet extends StatefulWidget {
  final Map<String, _CartEntry> cart;
  final double totalAmount;
  final int totalItems;
  final Future<void> Function(String barcode) onScanned;
  final void Function(String key, double qty) onUpdateQuantity;
  final void Function(String key) onRemove;
  final VoidCallback onPay;
  final String Function(double) formatPrice;
  final String Function(double) formatTotal;

  const _ScannerCartSheet({
    required this.cart,
    required this.totalAmount,
    required this.totalItems,
    required this.onScanned,
    required this.onUpdateQuantity,
    required this.onRemove,
    required this.onPay,
    required this.formatPrice,
    required this.formatTotal,
  });

  @override
  State<_ScannerCartSheet> createState() => _ScannerCartSheetState();
}

class _ScannerCartSheetState extends State<_ScannerCartSheet> {
  final MobileScannerController _scannerCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _torchOn = false;
  String? _lastScanned;
  DateTime _lastScanTime = DateTime(2000);

  @override
  void dispose() {
    _scannerCtrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null || barcode.isEmpty) return;

    // Debounce: ignore same barcode within 2.5 seconds
    final now = DateTime.now();
    if (barcode == _lastScanned && now.difference(_lastScanTime).inMilliseconds < 2500) return;

    _lastScanned = barcode;
    _lastScanTime = now;
    widget.onScanned(barcode);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Drag handle ──
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.borderMedium, borderRadius: BorderRadius.circular(2)))),
          ),

          // ── Scanner area ──
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Camera preview
                MobileScanner(
                  controller: _scannerCtrl,
                  onDetect: _onDetect,
                ),
                // Scan overlay
                Center(
                  child: Container(
                    width: 200, height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                    ),
                  ),
                ),
                // Corner accents
                ..._buildCornerAccents(),
                // Scan line animation
                Center(
                  child: Container(
                    width: 180, height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, AppTheme.primaryColor.withOpacity(0.8), Colors.transparent],
                      ),
                    ),
                  ),
                ),
                // Top bar with controls
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.scan, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text('Scan Products', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white)),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            _scannerCtrl.toggleTorch();
                            setState(() => _torchOn = !_torchOn);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _torchOn ? AppTheme.primaryColor : Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(_torchOn ? LucideIcons.zapOff : LucideIcons.zap, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Bottom hint
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter, end: Alignment.topCenter,
                        colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                      ),
                    ),
                    child: Center(
                      child: Text('Point camera at barcode', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Cart header ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(LucideIcons.shoppingCart, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text('Cart (${widget.totalItems} items)', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(widget.formatTotal(widget.totalAmount), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),

          // ── Cart items ──
          Expanded(
            child: widget.cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.shoppingCart, size: 40, color: AppTheme.textTertiary.withOpacity(0.4)),
                        const SizedBox(height: 8),
                        Text('Scan a product to add it here', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textTertiary)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: widget.cart.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final entry = widget.cart.entries.elementAt(index);
                      final e = entry.value;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.product.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  if (e.selectedVariant != null)
                                    Text('Variant: ${e.selectedVariant}', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.info)),
                                  Text(widget.formatPrice(e.product.retailPrice), style: GoogleFonts.inter(fontSize: 13, color: AppTheme.primaryColor, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                if (e.product.isWeighable) ...[
                                  Text('${e.quantity} ${e.product.unitType}', style: GoogleFonts.inter(fontSize: 13)),
                                  IconButton(
                                    icon: const Icon(LucideIcons.edit2, size: 14, color: AppTheme.primaryColor),
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    constraints: const BoxConstraints(),
                                    onPressed: () async {
                                      final weightCtrl = TextEditingController(text: e.quantity.toString());
                                      final weight = await AppModals.showAppDialog<double>(
                                        context: context,
                                        title: 'Edit amount (${e.product.unitType})',
                                        child: TextField(
                                          controller: weightCtrl,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          autofocus: true,
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: const Color(0xFFF9FAFB),
                                            border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide.none),
                                          ),
                                        ),
                                        primaryAction: ElevatedButton(
                                          onPressed: () => Navigator.pop(context, double.tryParse(weightCtrl.text)),
                                          child: const Text('Save Changes'),
                                        ),
                                        secondaryAction: TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                                        ),
                                      );
                                      if (weight != null && weight > 0) {
                                        widget.onUpdateQuantity(entry.key, weight);
                                      }
                                    }
                                  ),
                                ] else ...[
                                  _QuantityButton(label: '-', onTap: () => widget.onUpdateQuantity(entry.key, e.quantity - 1), filled: false),
                                  SizedBox(width: 28, child: Center(child: Text('${e.quantity.toInt()}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)))),
                                  _QuantityButton(label: '+', onTap: () => widget.onUpdateQuantity(entry.key, e.quantity + 1), filled: true),
                                ],
                              ],
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => widget.onRemove(entry.key),
                              child: const SizedBox(width: 28, height: 28, child: Icon(LucideIcons.trash2, size: 16, color: AppTheme.error)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // ── Pay button ──
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.borderLight)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: widget.cart.isEmpty ? null : widget.onPay,
                icon: const Icon(LucideIcons.printer, size: 20),
                label: Text(
                  widget.cart.isEmpty ? 'Scan to add items' : 'Pay ${widget.formatTotal(widget.totalAmount)}',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.borderMedium,
                  disabledForegroundColor: AppTheme.textTertiary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCornerAccents() {
    const size = 24.0;
    const thickness = 3.0;
    const color = AppTheme.primaryColor;
    const offset = 24.0;

    Widget corner({
      required AlignmentGeometry alignment,
      required BorderRadius borderRadius,
    }) {
      return Align(
        alignment: alignment,
        child: Container(
          margin: const EdgeInsets.all(offset),
          width: size, height: size,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border(
              top: alignment == Alignment.topLeft || alignment == Alignment.topRight
                  ? const BorderSide(color: color, width: thickness)
                  : BorderSide.none,
              bottom: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight
                  ? const BorderSide(color: color, width: thickness)
                  : BorderSide.none,
              left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft
                  ? const BorderSide(color: color, width: thickness)
                  : BorderSide.none,
              right: alignment == Alignment.topRight || alignment == Alignment.bottomRight
                  ? const BorderSide(color: color, width: thickness)
                  : BorderSide.none,
            ),
          ),
        ),
      );
    }

    return [
      corner(alignment: Alignment.topLeft, borderRadius: const BorderRadius.only(topLeft: Radius.circular(8))),
      corner(alignment: Alignment.topRight, borderRadius: const BorderRadius.only(topRight: Radius.circular(8))),
      corner(alignment: Alignment.bottomLeft, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8))),
      corner(alignment: Alignment.bottomRight, borderRadius: const BorderRadius.only(bottomRight: Radius.circular(8))),
    ];
  }
}
