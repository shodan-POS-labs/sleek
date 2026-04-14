import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../services/receipt_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../utils/error_helpers.dart';
import '../models/sale.dart';
import '../models/receipt_settings.dart';
import '../widgets/app_modals.dart';

class SavedReceiptsScreen extends StatefulWidget {
  const SavedReceiptsScreen({super.key});

  @override
  State<SavedReceiptsScreen> createState() => _SavedReceiptsScreenState();
}

class _SavedReceiptsScreenState extends State<SavedReceiptsScreen> {
  final _db = FirestoreService();
  final _auth = AuthService();
  final _receiptService = ReceiptService();

  List<Sale> _allSales = [];
  List<Sale> _filteredSales = [];
  final Map<String, List<SaleItem>> _itemCache = {}; // Cache for lazy loaded items
  
  bool _loading = true;
  bool _isAscending = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  String get _shopId => _auth.currentUser?.shopId ?? '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (_shopId.isEmpty) return;
    setState(() => _loading = true);
    
    try {
      // Load 100 recent sales - Fetching only Sales is MUCH faster than sales + items
      final sales = await _db.getRecentSales(_shopId, limit: 100);
      
      if (mounted) {
        setState(() {
          _allSales = sales;
          _loading = false;
          _applyFilters();
        });
      }
    } catch (e) {
      debugPrint("Error loading sales history: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    final query = _searchQuery.toLowerCase().trim();
    List<Sale> results = _allSales;

    if (query.isNotEmpty) {
      results = results.where((sale) {
        final matchInvoice = sale.invoiceNumber.toLowerCase().contains(query);
        
        // 1. Check denormalized productNames (fast)
        final matchProductDenorm = sale.productNames.any((p) => 
          p.toLowerCase().contains(query)
        );

        // 2. Check item cache (for existing sales without denormalized data)
        final cachedItems = _itemCache[sale.id] ?? [];
        final matchProductCache = cachedItems.any((item) =>
          item.productName.toLowerCase().contains(query)
        );

        return matchInvoice || matchProductDenorm || matchProductCache;
      }).toList();

      // If we find very few results and haven't fetched all items yet, 
      // trigger a background "Deep Search"
      _triggerDeepSearchIfNeeded();
    }

    results.sort((a, b) => _isAscending 
        ? a.createdAt.compareTo(b.createdAt) 
        : b.createdAt.compareTo(a.createdAt));

    setState(() => _filteredSales = results);
  }

  bool _isDeepSearching = false;
  Future<void> _triggerDeepSearchIfNeeded() async {
    // Only search if we have a query and haven't fetched items for everything yet
    if (_searchQuery.isEmpty || _isDeepSearching) return;
    
    // Find sales that are missing from cache AND missing productNames
    final missingIds = _allSales
        .where((s) => s.id != null && !_itemCache.containsKey(s.id) && s.productNames.isEmpty)
        .map((s) => s.id!)
        .toList();

    if (missingIds.isEmpty) return;

    _isDeepSearching = true;
    try {
      final allItems = await _db.getSaleItemsForSales(_shopId, missingIds);
      
      // Group and Cache
      for (final item in allItems) {
        if (!_itemCache.containsKey(item.saleId)) {
          _itemCache[item.saleId] = [];
        }
        _itemCache[item.saleId]!.add(item);
      }
      
      // Re-apply filters with new data
      if (mounted) {
        _applyFilters();
      }
    } catch (e) {
      debugPrint("Deep search fetch failed: $e");
    } finally {
      _isDeepSearching = false;
    }
  }

  Future<List<SaleItem>> _ensureItems(Sale sale) async {
    if (_itemCache.containsKey(sale.id)) return _itemCache[sale.id]!;
    
    final items = await _db.getSaleItems(_shopId, sale.id!);
    _itemCache[sale.id!] = items;
    return items;
  }

  void _showPreview(Sale sale) async {
    // Show a loading indicator if items aren't cached
    if (!_itemCache.containsKey(sale.id)) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
      await _ensureItems(sale);
      if (mounted) Navigator.pop(context);
    }

    final items = _itemCache[sale.id]!;
    
    AppModals.showAppBottomSheet(
      context: context,
      title: 'Receipt Details',
      child: _ReceiptPreviewModal(
        sale: sale,
        items: items,
        onPrint: (type) => _reprint(sale, type),
      ),
    );
  }

  Future<void> _reprint(Sale sale, String type) async {
    try {
      final items = await _ensureItems(sale);
      
      if (type == 'wifi') {
        await _receiptService.reprintSale(context: context, sale: sale, items: items, shopId: _shopId);
      } else {
        final settings = await _db.getReceiptSettings(_shopId);
        final shopDetails = await _db.getShopDetails(_shopId) ?? {};
        
        await _receiptService.printReceipt(
          context: context,
          sale: sale,
          items: items,
          settings: settings.copyWith(printerType: PrinterType.bluetooth),
          shopDetails: shopDetails,
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print job sent!'), backgroundColor: AppTheme.primaryColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e)), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        title: Text('Sales History',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isAscending ? LucideIcons.arrowUp : LucideIcons.arrowDown),
            tooltip: _isAscending ? 'Oldest First' : 'Newest First',
            onPressed: () {
              setState(() => _isAscending = !_isAscending);
              _applyFilters();
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: AppTheme.primaryColor,
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                _searchQuery = val;
                _applyFilters();
              },
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by invoice or product...',
                hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.7)),
                prefixIcon: const Icon(LucideIcons.search, color: Colors.white70, size: 20),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, color: Colors.white70, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _applyFilters();
                      },
                    )
                  : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                : _filteredSales.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: AppTheme.primaryColor,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredSales.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => _saleTile(_filteredSales[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _saleTile(Sale sale) {
    final date = DateFormat('dd MMM, hh:mm a').format(sale.createdAt);
    final products = sale.productNames.isEmpty ? ['Tap to view items'] : sale.productNames;
    final itemsSummary = products.take(2).join(', ');
    final hasMore = products.length > 2;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        onTap: () => _showPreview(sale),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: AppTheme.primarySurface, borderRadius: BorderRadius.circular(12)),
          child: const Icon(LucideIcons.fileText, color: AppTheme.primaryColor, size: 24),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                sale.invoiceNumber, 
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text('Rs. ${sale.totalAmount.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(date, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 2),
            Text(
              itemsSummary + (hasMore ? '... +${products.length - 2} more' : ''),
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppTheme.borderMedium),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_searchQuery.isEmpty ? LucideIcons.inbox : LucideIcons.searchX, size: 64, color: AppTheme.borderMedium),
          const SizedBox(height: 20),
          Text(_searchQuery.isEmpty ? 'No sales found' : 'No matching receipts',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          if (_searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Try searching with a different keyword',
                  style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textTertiary)),
            ),
        ],
      ),
    );
  }
}

class _ReceiptPreviewModal extends StatelessWidget {
  final Sale sale;
  final List<SaleItem> items;
  final Function(String) onPrint;

  const _ReceiptPreviewModal({
    required this.sale,
    required this.items,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd MMM yyyy, hh:mm a').format(sale.createdAt);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primarySurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _infoRow('Invoice', sale.invoiceNumber, bold: true),
              const SizedBox(height: 4),
              _infoRow('Date', date),
              const SizedBox(height: 4),
              _infoRow('Payment', sale.paymentMethod.toUpperCase(), 
                  color: sale.paymentMethod == 'cash' ? Colors.green : AppTheme.primaryColor),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Items List
        Text('ITEMS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textTertiary, letterSpacing: 1)),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final item = items[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.productName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                          Text('${item.quantity} x Rs. ${item.price.toStringAsFixed(0)}', 
                              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    Text('Rs. ${item.total.toStringAsFixed(0)}', 
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            },
          ),
        ),

        const Divider(height: 32, thickness: 1),

        // Totals
        _totalRow('Subtotal', 'Rs. ${(sale.totalAmount + sale.discount).toStringAsFixed(0)}'),
        const SizedBox(height: 8),
        _totalRow('Discount', '- Rs. ${sale.discount.toStringAsFixed(0)}', color: Colors.red),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              Text('Rs. ${sale.totalAmount.toStringAsFixed(0)}', 
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onPrint('wifi'),
                icon: const Icon(LucideIcons.printer, size: 18),
                label: const Text('WiFi'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: AppTheme.borderMedium),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => onPrint('bt'),
                icon: const Icon(LucideIcons.bluetooth, size: 18),
                label: const Text('Bluetooth'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _infoRow(String label, String value, {bool bold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
        Text(value, style: GoogleFonts.inter(
          fontSize: 13, 
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: color ?? AppTheme.textPrimary,
        )),
      ],
    );
  }

  Widget _totalRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary)),
        Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
