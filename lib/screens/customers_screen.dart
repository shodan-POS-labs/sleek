// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/customer.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _db = FirestoreService();
  final _auth = AuthService();
  String _searchQuery = '';
  List<Customer> _customers = [];
  bool _loading = true;

  String get _shopId => _auth.currentUser?.shopId ?? '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final customers = await _db.getCustomers(_shopId, search: _searchQuery.isEmpty ? null : _searchQuery);
    if (mounted) setState(() { _customers = customers; _loading = false; });
  }

  List<Customer> get _customersWithBalance => _customers.where((c) => c.balance > 0).toList();
  double get _totalOutstanding => _customersWithBalance.fold(0.0, (sum, c) => sum + c.balance);

  void _showPaymentDialog(Customer customer) {
    final amountCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.borderMedium, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Add Payment', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Customer', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Text(customer.name, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text('Outstanding Balance', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Text('Rs. ${NumberFormat('#,###').format(customer.balance.toInt())}', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, color: AppTheme.error)),
              ]),
            ),
            const SizedBox(height: 16),
            Text('Payment Amount', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '0.00', filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.borderMedium)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.borderMedium)),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => amountCtrl.text = customer.balance.toStringAsFixed(0),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text('Full Amount', style: GoogleFonts.inter(fontSize: 14)),
              )),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(
                onPressed: () => amountCtrl.text = (customer.balance / 2).toStringAsFixed(0),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text('Half', style: GoogleFonts.inter(fontSize: 14)),
              )),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text) ?? 0;
                  if (amount > 0 && customer.id != null) {
                    await _db.updateCustomerBalance(_shopId, customer.id!, customer.balance - amount);
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Rs. ${NumberFormat('#,###').format(amount.toInt())} received from ${customer.name}'),
                        backgroundColor: AppTheme.primaryColor,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                child: Text('Confirm Payment', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.borderMedium, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Add Customer', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            Text('Name', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(hintText: 'Customer name', filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderMedium)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderMedium)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Phone', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(hintText: '07X-XXXXXXX', filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderMedium)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderMedium)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
                  final customer = Customer(name: nameCtrl.text, phone: phoneCtrl.text);
                  await _db.insertCustomer(_shopId, customer);
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${nameCtrl.text} added'), backgroundColor: AppTheme.primaryColor, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                child: Text('Add Customer', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, left: 24, right: 24, bottom: 24),
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Color(0x20000000), blurRadius: 15, offset: Offset(0, 5))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Customers & Credit', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w500, color: Colors.white)),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: TextField(
                  onChanged: (v) { _searchQuery = v; _loadData(); },
                  decoration: InputDecoration(
                    hintText: 'Search customers...',
                    prefixIcon: const Padding(padding: EdgeInsets.only(left: 16, right: 12), child: Icon(LucideIcons.search, size: 20, color: AppTheme.textTertiary)),
                    border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Total Outstanding', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                    const SizedBox(height: 4),
                    Text('Rs. ${NumberFormat('#,###').format(_totalOutstanding.toInt())}', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white)),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('Credit Customers', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                    const SizedBox(height: 4),
                    Text('${_customersWithBalance.length}', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white)),
                  ]),
                ]),
              ),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: AppTheme.primaryColor,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _customers.length,
                      itemBuilder: (context, index) {
                        final c = _customers[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderLight)),
                          child: Column(children: [
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(color: AppTheme.primarySurface, borderRadius: BorderRadius.circular(12)),
                                child: Center(child: Text(c.name.substring(0, 1), style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.primaryColor))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(c.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                                const SizedBox(height: 4),
                                Row(children: [const Icon(LucideIcons.phone, size: 12, color: AppTheme.textSecondary), const SizedBox(width: 4), Text(c.phone, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary))]),
                                if (c.lastPurchase != null) ...[const SizedBox(height: 2), Text('Last: ${c.lastPurchase}', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary))],
                              ])),
                              c.balance > 0
                                  ? Text('Rs. ${NumberFormat('#,###').format(c.balance.toInt())}', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.error))
                                  : Text('Paid', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.green)),
                            ]),
                            if (c.balance > 0) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity, height: 40,
                                child: ElevatedButton.icon(
                                  onPressed: () => _showPaymentDialog(c),
                                  icon: const Icon(LucideIcons.dollarSign, size: 16),
                                  label: Text('Add Payment', style: GoogleFonts.inter(fontSize: 14)),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                                ),
                              ),
                            ],
                          ]),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomerDialog,
        backgroundColor: AppTheme.primaryColor,
        elevation: 8,
        child: const Icon(LucideIcons.plus, size: 32, color: Colors.white),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 3),
    );
  }
}
