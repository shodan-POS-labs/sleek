import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../models/sale.dart';
import '../models/business_config.dart';
import '../models/app_notification.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = FirestoreService();
  final _auth = AuthService();
  final _notifSvc = NotificationService();
  double _todaySales = 0;
  int _productCount = 0;
  int _lowStockCount = 0;
  int _creditCustomerCount = 0;
  double _totalOutstanding = 0;
  List<Sale> _recentSales = [];
  bool _loading = true;
  BusinessConfig _config = BusinessConfig.forType(BusinessType.retail);
  int _unreadNotifCount = 0;

  String get _shopId => _auth.currentUser?.shopId ?? '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final config = await _db.getBusinessConfig(_shopId);
    final todaySales = await _db.getTodaySales(_shopId);
    final productCount = await _db.getProductCount(_shopId);
    final lowStock = await _db.getLowStockProducts(_shopId);
    final creditCount = await _db.getCustomerCount(_shopId);
    final outstanding = await _db.getTotalOutstanding(_shopId);
    final recentSales = await _db.getRecentSales(_shopId, limit: 5);

    // Run notification checks in background (non-blocking)
    _notifSvc.checkAndGenerate(_shopId).then((_) async {
      if (!mounted) return;
      final count = await _db.getUnreadNotificationCount(_shopId);
      if (mounted) setState(() => _unreadNotifCount = count);
    });

    if (mounted) {
      setState(() {
        _config = config;
        _todaySales = todaySales;
        _productCount = productCount;
        _lowStockCount = lowStock.length;
        _creditCustomerCount = creditCount;
        _totalOutstanding = outstanding;
        _recentSales = recentSales;
        _loading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) return 'Rs. ${(amount / 1000000).toStringAsFixed(1)}M';
    return 'Rs. ${NumberFormat('#,###').format(amount.toInt())}';
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ── Seed Dummy Notifications (for testing) ──────────────────
  Future<void> _seedDummyNotifications() async {
    final now = DateTime.now();
    final dummies = [
      AppNotification(
        type: 'daily_summary',
        title: 'Daily Sales Summary',
        body: 'Yesterday you made 12 sales totalling Rs. 8,450. Top seller: Paracetamol 500mg.',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        type: 'low_stock',
        title: 'Low Stock Alert',
        body: 'Amoxicillin 250mg has only 3 units left — consider restocking.',
        createdAt: now.subtract(const Duration(hours: 5)),
        metadata: {'productName': 'Amoxicillin 250mg', 'stock': 3},
      ),
      AppNotification(
        type: 'expiring_stock',
        title: 'Medicine Expiring Soon',
        body: 'Ibuprofen 400mg expires in 15 days (batch BN-0042).',
        createdAt: now.subtract(const Duration(hours: 8)),
        metadata: {'productName': 'Ibuprofen 400mg', 'daysUntilExpiry': 15},
      ),
      AppNotification(
        type: 'expired_stock',
        title: 'Expired Medicine Found',
        body: 'Cetirizine 10mg (batch BN-0018) expired 5 days ago — remove from shelf.',
        createdAt: now.subtract(const Duration(hours: 12)),
        metadata: {'productName': 'Cetirizine 10mg'},
      ),
      AppNotification(
        type: 'low_stock',
        title: 'Low Stock Alert',
        body: 'Aspirin 75mg has only 5 units remaining.',
        createdAt: now.subtract(const Duration(days: 1)),
        metadata: {'productName': 'Aspirin 75mg', 'stock': 5},
      ),
      AppNotification(
        type: 'new_product_reminder',
        title: 'New Stock Reminder',
        body: 'Have you received new medicines this week? Tap here to add them.',
        createdAt: now.subtract(const Duration(days: 1, hours: 6)),
      ),
      AppNotification(
        type: 'daily_summary',
        title: 'Daily Sales Summary',
        body: 'You had 8 sales yesterday with total revenue Rs. 5,200.',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ];

    for (final n in dummies) {
      await _db.createNotification(_shopId, n);
    }

    final count = await _db.getUnreadNotificationCount(_shopId);
    if (mounted) {
      setState(() => _unreadNotifCount = count);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('7 test notifications created!'),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Notification Sheet ──────────────────────────────────────
  Future<void> _showNotificationsSheet(BuildContext context) async {
    List<AppNotification> notifications = [];
    bool loading = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          // Load on first build
          if (loading) {
            _db.getNotifications(_shopId, limit: 30).then((list) {
              if (ctx.mounted) setStateSB(() { notifications = list; loading = false; });
            });
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppTheme.borderMedium, borderRadius: BorderRadius.circular(2)),
                ),
                // Title bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Notifications', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
                      if (!loading && notifications.any((n) => !n.isRead))
                        TextButton(
                          onPressed: () async {
                            await _db.markAllNotificationsRead(_shopId);
                            final refreshed = await _db.getNotifications(_shopId, limit: 30);
                            if (ctx.mounted) setStateSB(() => notifications = refreshed);
                            if (mounted) setState(() => _unreadNotifCount = 0);
                          },
                          child: Text('Mark all read', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.primaryColor)),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppTheme.borderLight),
                // Content
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                      : notifications.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.bellOff, size: 48, color: AppTheme.textTertiary),
                                  const SizedBox(height: 12),
                                  Text('No notifications yet', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: notifications.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, indent: 68, color: AppTheme.borderLight),
                              itemBuilder: (context, i) {
                                final n = notifications[i];
                                final iconData = _notifIcon(n.type);
                                final iconColor = _notifColor(n.type);

                                return InkWell(
                                  onTap: () async {
                                    if (!n.isRead && n.id != null) {
                                      await _db.markNotificationRead(_shopId, n.id!);
                                      final refreshed = await _db.getNotifications(_shopId, limit: 30);
                                      final count = await _db.getUnreadNotificationCount(_shopId);
                                      if (ctx.mounted) setStateSB(() => notifications = refreshed);
                                      if (mounted) setState(() => _unreadNotifCount = count);
                                    }
                                  },
                                  child: Container(
                                    color: n.isRead ? Colors.transparent : AppTheme.primarySurface.withOpacity(0.5),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 40, height: 40,
                                          decoration: BoxDecoration(
                                            color: iconColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(iconData, size: 18, color: iconColor),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      n.title,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 13,
                                                        fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  if (!n.isRead)
                                                    Container(
                                                      width: 8, height: 8,
                                                      decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(n.body, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                                              const SizedBox(height: 4),
                                              Text(_timeAgo(n.createdAt), style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textTertiary)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _notifIcon(String type) {
    switch (type) {
      case 'daily_summary':     return LucideIcons.barChart2;
      case 'low_stock':         return LucideIcons.packageMinus;
      case 'restock_reminder':  return LucideIcons.refreshCcw;
      case 'expiring_stock':    return LucideIcons.timer;
      case 'expired_stock':     return LucideIcons.alertOctagon;
      case 'new_product_reminder': return LucideIcons.plus;
      case 'daily_menu_reminder':  return LucideIcons.chefHat;
      case 'pending_jobs':      return LucideIcons.clock;
      case 'overdue_jobs':      return LucideIcons.alertTriangle;
      default:                  return LucideIcons.bell;
    }
  }

  Color _notifColor(String type) {
    switch (type) {
      case 'daily_summary':     return AppTheme.primaryColor;
      case 'low_stock':         return AppTheme.warning;
      case 'restock_reminder':  return AppTheme.info;
      case 'expiring_stock':    return AppTheme.warning;
      case 'expired_stock':     return AppTheme.error;
      case 'new_product_reminder': return AppTheme.purple;
      case 'daily_menu_reminder':  return AppTheme.warning;
      case 'pending_jobs':      return AppTheme.warning;
      case 'overdue_jobs':      return AppTheme.error;
      default:                  return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(now);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 24, right: 24, bottom: 28,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [BoxShadow(color: Color(0x20000000), blurRadius: 15, offset: Offset(0, 5))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dashboard',
                        style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w500, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(dateStr,
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.75))),
                  ],
                ),
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _showNotificationsSheet(context),
                    onLongPress: _seedDummyNotifications,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(LucideIcons.bell, size: 22, color: Colors.white),
                        if (_unreadNotifCount > 0)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppTheme.error,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                _unreadNotifCount > 9 ? '9+' : '$_unreadNotifCount',
                                style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: AppTheme.primaryColor,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Stats 2×2 grid using Row+Expanded (no aspect ratio) ──
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _StatCard(
                                  icon: LucideIcons.dollarSign,
                                  bgColor: const Color(0xFFECFDF5),
                                  iconColor: AppTheme.primaryColor,
                                  title: 'Today Sales',
                                  value: _formatCurrency(_todaySales),
                                  trend: _todaySales > 0 ? 'Active' : 'No sales yet',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  icon: LucideIcons.package,
                                  bgColor: const Color(0xFFEFF6FF),
                                  iconColor: AppTheme.info,
                                  title: '${_config.salesItemLabel}s',
                                  value: NumberFormat('#,###').format(_productCount),
                                  trend: '$_productCount in catalog',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _StatCard(
                                  icon: LucideIcons.alertTriangle,
                                  bgColor: const Color(0xFFFFF7ED),
                                  iconColor: AppTheme.warning,
                                  title: 'Low Stock',
                                  value: '$_lowStockCount',
                                  trend: _lowStockCount > 0 ? 'Need restock' : 'All stocked',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  icon: LucideIcons.users,
                                  bgColor: const Color(0xFFFAF5FF),
                                  iconColor: AppTheme.purple,
                                  title: 'Credit',
                                  value: '$_creditCustomerCount',
                                  trend: 'Rs. ${NumberFormat('#,###').format(_totalOutstanding.toInt())} due',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── Quick Actions ────────────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Quick Actions',
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 44,
                                        child: ElevatedButton.icon(
                                          onPressed: () => context.go('/sales'),
                                          icon: const Icon(LucideIcons.dollarSign, size: 18),
                                          label: Text('New Sale', style: GoogleFonts.inter(fontSize: 13)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primaryColor,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            elevation: 0,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: SizedBox(
                                        height: 44,
                                        child: ElevatedButton.icon(
                                          onPressed: () => context.go('/products'),
                                          icon: const Icon(LucideIcons.package, size: 18),
                                          label: Text('Add Product', style: GoogleFonts.inter(fontSize: 13)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFF3F4F6),
                                            foregroundColor: AppTheme.textPrimary,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            elevation: 0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Recent Transactions ───────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Recent Transactions',
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                                const SizedBox(height: 12),
                                if (_recentSales.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: Text('No transactions yet',
                                          style: GoogleFonts.inter(color: AppTheme.textSecondary)),
                                    ),
                                  )
                                else
                                  ..._recentSales.map(
                                    (sale) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(sale.invoiceNumber,
                                                    style: GoogleFonts.inter(
                                                        fontSize: 13, fontWeight: FontWeight.w500,
                                                        color: AppTheme.textPrimary),
                                                    overflow: TextOverflow.ellipsis),
                                                Text(_timeAgo(sale.createdAt),
                                                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Rs. ${NumberFormat('#,###').format(sale.totalAmount.toInt())}',
                                            style: GoogleFonts.inter(
                                                fontSize: 13, fontWeight: FontWeight.w500,
                                                color: AppTheme.primaryColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }
}

// ── Stat Card ───────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final String title;
  final String value;
  final String trend;

  const _StatCard({
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,       // ← shrinks to content, no overflow
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(title,
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(trend,
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
