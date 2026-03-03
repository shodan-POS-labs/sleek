// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/report_export_service.dart';
import '../models/sale.dart';
import '../models/product.dart';
import '../models/business_config.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _db = FirestoreService();
  final _auth = AuthService();
  final _exportService = ReportExportService();

  String _period = 'daily'; // 'daily' or 'monthly'
  bool _loading = true;
  BusinessConfig _config = BusinessConfig.forType(BusinessType.retail);

  String get _shopId => _auth.currentUser?.shopId ?? '';

  // ── Computed analytics data ──
  double _totalRevenue = 0;
  int _totalOrders = 0;
  double _growthPercent = 0;
  List<Map<String, dynamic>> _chartData = [];
  List<Map<String, dynamic>> _topItems = [];

  // Profit summary (retail / pharmacy)
  double _totalCost = 0;
  double _totalDiscount = 0;

  // Restaurant-specific
  Map<String, int> _orderTypeCounts = {};
  Map<String, double> _orderTypeRevenue = {};

  // Repair-specific
  Map<String, int> _jobStatusCounts = {};
  double _totalAdvance = 0;
  double _totalCollected = 0;

  // Pharmacy-specific
  List<Product> _expiringProducts = [];

  // Retail-specific
  List<Product> _lowStockProducts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── Date helpers ──

  DateTime get _periodStart {
    final now = DateTime.now();
    if (_period == 'daily') {
      return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    } else {
      return DateTime(now.year - 1, now.month + 1, 1);
    }
  }

  DateTime get _periodEnd {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  DateTime get _prevPeriodStart {
    if (_period == 'daily') {
      return _periodStart.subtract(const Duration(days: 7));
    } else {
      final s = _periodStart;
      return DateTime(s.year - 1, s.month, 1);
    }
  }

  DateTime get _prevPeriodEnd {
    return _periodStart.subtract(const Duration(seconds: 1));
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final config = await _db.getBusinessConfig(_shopId);
      final sales = await _db.getSalesInRange(_shopId, _periodStart, _periodEnd);
      final prevSales = await _db.getSalesInRange(_shopId, _prevPeriodStart, _prevPeriodEnd);

      // ── Basic metrics ──
      final revenue = sales.fold(0.0, (s, e) => s + e.totalAmount);
      final prevRevenue = prevSales.fold(0.0, (s, e) => s + e.totalAmount);
      final growth = prevRevenue > 0 ? ((revenue - prevRevenue) / prevRevenue) * 100 : (revenue > 0 ? 100 : 0);

      // ── Chart data ──
      final chartData = _buildChartData(sales);

      // ── Top items ──
      final saleIds = sales.where((s) => s.id != null).map((s) => s.id!).toList();
      List<Map<String, dynamic>> topItems = [];
      if (saleIds.isNotEmpty) {
        final items = await _db.getSaleItemsForSales(_shopId, saleIds);
        topItems = _computeTopItems(items);
      }

      // ── Business-specific ──
      double totalCost = 0;
      double totalDiscount = sales.fold(0.0, (s, e) => s + e.discount);

      Map<String, int> orderTypeCounts = {};
      Map<String, double> orderTypeRevenue = {};
      Map<String, int> jobStatusCounts = {};
      double totalAdvance = 0;
      double totalCollected = 0;
      List<Product> expiringProducts = [];
      List<Product> lowStockProducts = [];

      if (config.hasWholesalePrice) {
        // For retail & pharmacy: estimate cost from wholesale prices
        final products = await _db.getProducts(_shopId);
        final priceMap = <String, double>{};
        for (final p in products) {
          if (p.id != null) priceMap[p.id!] = p.wholesalePrice;
        }
        if (saleIds.isNotEmpty) {
          final allItems = await _db.getSaleItemsForSales(_shopId, saleIds);
          for (final item in allItems) {
            final wp = priceMap[item.productId] ?? 0;
            totalCost += wp * item.quantity;
          }
        }
      }

      if (config.hasStockManagement) {
        lowStockProducts = await _db.getLowStockProducts(_shopId, threshold: 10);
      }

      if (config.hasDineInTakeaway) {
        for (final sale in sales) {
          final type = sale.orderType.isEmpty ? 'dine-in' : sale.orderType;
          orderTypeCounts[type] = (orderTypeCounts[type] ?? 0) + 1;
          orderTypeRevenue[type] = (orderTypeRevenue[type] ?? 0) + sale.totalAmount;
        }
      }

      if (config.hasJobCards) {
        for (final sale in sales) {
          final status = sale.jobStatus.isEmpty ? 'pending' : sale.jobStatus;
          jobStatusCounts[status] = (jobStatusCounts[status] ?? 0) + 1;
        }
        totalAdvance = sales.fold(0.0, (s, e) => s + e.advanceAmount);
        totalCollected = revenue;
      }

      if (config.hasExpiryTracking) {
        expiringProducts = await _db.getExpiringProducts(_shopId, days: 90);
        expiringProducts.sort((a, b) => (a.expiryDate ?? DateTime(2099)).compareTo(b.expiryDate ?? DateTime(2099)));
      }

      if (mounted) {
        setState(() {
          _config = config;
          _totalRevenue = revenue;
          _totalOrders = sales.length;
          _growthPercent = growth.toDouble();
          _chartData = chartData;
          _topItems = topItems;
          _totalCost = totalCost;
          _totalDiscount = totalDiscount;
          _orderTypeCounts = orderTypeCounts;
          _orderTypeRevenue = orderTypeRevenue;
          _jobStatusCounts = jobStatusCounts;
          _totalAdvance = totalAdvance;
          _totalCollected = totalCollected;
          _expiringProducts = expiringProducts;
          _lowStockProducts = lowStockProducts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _buildChartData(List<Sale> sales) {
    if (_period == 'daily') {
      // Last 7 days
      final now = DateTime.now();
      final List<Map<String, dynamic>> data = [];
      for (int i = 6; i >= 0; i--) {
        final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
        final dayEnd = day.add(const Duration(days: 1));
        final daySales = sales.where((s) => s.createdAt.isAfter(day.subtract(const Duration(seconds: 1))) && s.createdAt.isBefore(dayEnd));
        final total = daySales.fold(0.0, (s, e) => s + e.totalAmount);
        data.add({'label': DateFormat('EEE').format(day), 'sales': total});
      }
      return data;
    } else {
      // Last 12 months
      final now = DateTime.now();
      final List<Map<String, dynamic>> data = [];
      for (int i = 11; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final nextMonth = DateTime(month.year, month.month + 1, 1);
        final monthSales = sales.where((s) => s.createdAt.isAfter(month.subtract(const Duration(seconds: 1))) && s.createdAt.isBefore(nextMonth));
        final total = monthSales.fold(0.0, (s, e) => s + e.totalAmount);
        data.add({'label': DateFormat('MMM').format(month), 'sales': total});
      }
      return data;
    }
  }

  List<Map<String, dynamic>> _computeTopItems(List<SaleItem> items) {
    final Map<String, Map<String, dynamic>> agg = {};
    for (final item in items) {
      final key = item.productName;
      if (!agg.containsKey(key)) {
        agg[key] = {'name': key, 'sold': 0, 'revenue': 0.0};
      }
      agg[key]!['sold'] = (agg[key]!['sold'] as int) + item.quantity;
      agg[key]!['revenue'] = (agg[key]!['revenue'] as double) + item.total;
    }
    final list = agg.values.toList();
    list.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
    return list.take(5).toList();
  }

  String _fmtCurrency(double amount) {
    if (amount >= 1000000) return 'Rs. ${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return 'Rs. ${NumberFormat('#,###').format(amount.toInt())}';
    return 'Rs. ${amount.toStringAsFixed(0)}';
  }

  String _fmtNumber(int n) => NumberFormat('#,###').format(n);

  @override
  Widget build(BuildContext context) {
    final maxSales = _chartData.isEmpty ? 1.0 : _chartData.map((e) => e['sales'] as double).reduce((a, b) => a > b ? a : b);
    final chartInterval = maxSales > 0 ? (maxSales / 4).ceilToDouble() : 10000.0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // ── Header ──
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 24, right: 24, bottom: 24,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Reports & Analytics', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w500, color: Colors.white)),
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _showDownloadSheet(context),
                        child: const Icon(LucideIcons.download, size: 22, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Period Selector
                Row(
                  children: [
                    _periodTab('daily', 'Daily'),
                    const SizedBox(width: 8),
                    _periodTab('monthly', 'Monthly'),
                  ],
                ),
              ],
            ),
          ),

          // ── Content ──
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: AppTheme.primaryColor,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // ── Summary Cards ──
                          _buildSummaryCards(),
                          const SizedBox(height: 16),

                          // ── Sales Trend ──
                          _buildSalesTrendChart(maxSales, chartInterval),
                          const SizedBox(height: 16),

                          // ── Revenue Breakdown ──
                          _buildRevenueBreakdownChart(maxSales, chartInterval),
                          const SizedBox(height: 16),

                          // ── Business-specific sections ──
                          ..._buildBusinessSpecificSections(),

                          // ── Top Selling Items ──
                          _buildTopSellingItems(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 3),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DOWNLOAD SHEET — Choose month & format
  // ═══════════════════════════════════════════════════════════

  void _showDownloadSheet(BuildContext context) {
    final now = DateTime.now();
    int selectedYear = now.year;
    int selectedMonth = now.month;
    bool isExporting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          final monthLabel = DateFormat('MMMM yyyy').format(DateTime(selectedYear, selectedMonth));

          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: AppTheme.borderMedium, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Row(
                    children: [
                      const Icon(LucideIcons.download, size: 22, color: AppTheme.primaryColor),
                      const SizedBox(width: 10),
                      Text('Download Sales Report', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Month selector
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(LucideIcons.chevronLeft, size: 20),
                          onPressed: () {
                            setStateSB(() {
                              if (selectedMonth == 1) {
                                selectedMonth = 12;
                                selectedYear--;
                              } else {
                                selectedMonth--;
                              }
                            });
                          },
                        ),
                        Text(monthLabel, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500)),
                        IconButton(
                          icon: const Icon(LucideIcons.chevronRight, size: 20),
                          onPressed: (selectedYear == now.year && selectedMonth >= now.month)
                              ? null
                              : () {
                                  setStateSB(() {
                                    if (selectedMonth == 12) {
                                      selectedMonth = 1;
                                      selectedYear++;
                                    } else {
                                      selectedMonth++;
                                    }
                                  });
                                },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Export buttons
                  if (isExporting)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: AppTheme.primaryColor),
                          SizedBox(height: 12),
                          Text('Generating report...'),
                        ],
                      ),
                    )
                  else ...[
                    // PDF button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => _doExport(ctx, setStateSB, selectedYear, selectedMonth, 'pdf', () => isExporting = true, () => isExporting = false),
                        icon: const Icon(LucideIcons.fileText, size: 20),
                        label: Text('Download as PDF', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Excel button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => _doExport(ctx, setStateSB, selectedYear, selectedMonth, 'excel', () => isExporting = true, () => isExporting = false),
                        icon: const Icon(LucideIcons.table, size: 20, color: Color(0xFF217346)),
                        label: Text('Download as Excel', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(0xFF217346))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF217346)),
                          minimumSize: const Size(0, 52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _doExport(
    BuildContext ctx,
    void Function(void Function()) setStateSB,
    int year,
    int month,
    String format,
    VoidCallback setLoading,
    VoidCallback clearLoading,
  ) async {
    setStateSB(setLoading);
    try {
      if (format == 'pdf') {
        await _exportService.exportMonthlySalesPdf(shopId: _shopId, year: year, month: month);
      } else {
        await _exportService.exportMonthlySalesExcel(shopId: _shopId, year: year, month: month);
      }
      if (ctx.mounted) {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${format.toUpperCase()} report downloaded!'),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      setStateSB(clearLoading);
      if (ctx.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // PERIOD TAB
  // ═══════════════════════════════════════════════════════════

  Widget _periodTab(String value, String label) {
    final active = _period == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_period != value) {
            setState(() => _period = value);
            _loadData();
          }
        },
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: active ? AppTheme.primaryColor : Colors.white)),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SUMMARY CARDS
  // ═══════════════════════════════════════════════════════════

  Widget _buildSummaryCards() {
    return Row(
      children: [
        _SummaryCard(
          icon: LucideIcons.dollarSign,
          label: 'Revenue',
          value: _fmtCurrency(_totalRevenue),
          iconBg: const Color(0xFFECFDF5),
          iconColor: AppTheme.primaryColor,
        ),
        const SizedBox(width: 12),
        _SummaryCard(
          icon: LucideIcons.shoppingBag,
          label: _config.hasJobCards ? 'Jobs' : 'Orders',
          value: _fmtNumber(_totalOrders),
          iconBg: const Color(0xFFEFF6FF),
          iconColor: AppTheme.info,
        ),
        const SizedBox(width: 12),
        _SummaryCard(
          icon: _growthPercent >= 0 ? LucideIcons.trendingUp : LucideIcons.trendingDown,
          label: 'Growth',
          value: '${_growthPercent >= 0 ? '+' : ''}${_growthPercent.toStringAsFixed(1)}%',
          iconBg: const Color(0xFFFAF5FF),
          iconColor: AppTheme.purple,
          valueColor: _growthPercent >= 0 ? Colors.green : AppTheme.error,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SALES TREND LINE CHART
  // ═══════════════════════════════════════════════════════════

  Widget _buildSalesTrendChart(double maxSales, double chartInterval) {
    return _cardContainer(
      title: 'Sales Trend',
      child: SizedBox(
        height: 200,
        child: _chartData.isEmpty
            ? Center(child: Text('No sales data', style: GoogleFonts.inter(color: AppTheme.textSecondary)))
            : LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: chartInterval,
                    getDrawingHorizontalLine: (value) => const FlLine(color: Color(0xFFF0F0F0), strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < _chartData.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(_chartData[idx]['label'] as String, style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textSecondary)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(_chartData.length, (i) => FlSpot(i.toDouble(), _chartData[i]['sales'] as double)),
                      isCurved: true,
                      color: AppTheme.primaryColor,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                          radius: 4, color: AppTheme.primaryColor, strokeWidth: 2, strokeColor: Colors.white,
                        ),
                      ),
                      belowBarData: BarAreaData(show: true, color: AppTheme.primaryColor.withOpacity(0.1)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // REVENUE BREAKDOWN BAR CHART
  // ═══════════════════════════════════════════════════════════

  Widget _buildRevenueBreakdownChart(double maxSales, double chartInterval) {
    return _cardContainer(
      title: 'Revenue Breakdown',
      child: SizedBox(
        height: 200,
        child: _chartData.isEmpty
            ? Center(child: Text('No sales data', style: GoogleFonts.inter(color: AppTheme.textSecondary)))
            : BarChart(
                BarChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: chartInterval,
                    getDrawingHorizontalLine: (value) => const FlLine(color: Color(0xFFF0F0F0), strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < _chartData.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(_chartData[idx]['label'] as String, style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textSecondary)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(_chartData.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: _chartData[i]['sales'] as double,
                          color: AppTheme.primaryColor,
                          width: _period == 'daily' ? 20 : 14,
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // BUSINESS-SPECIFIC SECTIONS
  // ═══════════════════════════════════════════════════════════

  List<Widget> _buildBusinessSpecificSections() {
    final widgets = <Widget>[];

    // ── Profit Summary (Retail & Pharmacy) ──
    if (_config.hasWholesalePrice) {
      final netProfit = _totalRevenue - _totalCost - _totalDiscount;
      widgets.add(_cardContainer(
        title: 'Profit Summary',
        child: Column(
          children: [
            _ProfitRow(label: 'Total Revenue', value: _fmtCurrency(_totalRevenue), color: AppTheme.textPrimary),
            const Divider(height: 1, color: AppTheme.borderLight),
            _ProfitRow(label: 'Cost of Goods', value: '- ${_fmtCurrency(_totalCost)}', color: AppTheme.error),
            const Divider(height: 1, color: AppTheme.borderLight),
            _ProfitRow(label: 'Discounts Given', value: '- ${_fmtCurrency(_totalDiscount)}', color: AppTheme.warning),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(color: AppTheme.primarySurface, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Net Profit', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
                  Text(
                    _fmtCurrency(netProfit),
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: netProfit >= 0 ? AppTheme.primaryColor : AppTheme.error),
                  ),
                ],
              ),
            ),
          ],
        ),
      ));
      widgets.add(const SizedBox(height: 16));
    }

    // ── Low Stock Alerts (Retail & Pharmacy) ──
    if (_config.hasStockManagement && _lowStockProducts.isNotEmpty) {
      widgets.add(_cardContainer(
        title: 'Low Stock Alerts',
        titleIcon: LucideIcons.alertTriangle,
        titleIconColor: AppTheme.warning,
        child: Column(
          children: _lowStockProducts.take(5).map((p) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(LucideIcons.packageMinus, size: 18, color: AppTheme.warning),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${p.stock} left in stock', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: p.stock <= 0 ? AppTheme.error.withOpacity(0.1) : AppTheme.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      p.stock <= 0 ? 'OUT' : 'LOW',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: p.stock <= 0 ? AppTheme.error : AppTheme.warning),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ));
      widgets.add(const SizedBox(height: 16));
    }

    // ── Order Type Breakdown (Restaurant) ──
    if (_config.hasDineInTakeaway && _orderTypeCounts.isNotEmpty) {
      final typeColors = {
        'dine-in': AppTheme.primaryColor,
        'takeaway': AppTheme.warning,
        'delivery': AppTheme.info,
      };
      final typeIcons = {
        'dine-in': LucideIcons.utensils,
        'takeaway': LucideIcons.shoppingBag,
        'delivery': LucideIcons.truck,
      };

      widgets.add(_cardContainer(
        title: 'Order Type Breakdown',
        child: Column(
          children: _orderTypeCounts.entries.map((entry) {
            final type = entry.key;
            final count = entry.value;
            final revenue = _orderTypeRevenue[type] ?? 0;
            final pct = _totalOrders > 0 ? (count / _totalOrders * 100) : 0;
            final color = typeColors[type] ?? AppTheme.textSecondary;
            final icon = typeIcons[type] ?? LucideIcons.shoppingBag;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_capitalise(type), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                          Text(_fmtCurrency(revenue), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct / 100,
                          backgroundColor: AppTheme.borderLight,
                          valueColor: AlwaysStoppedAnimation(color),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('$count orders (${pct.toStringAsFixed(0)}%)', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                    ]),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ));
      widgets.add(const SizedBox(height: 16));
    }

    // ── Job Status Board (Repair) ──
    if (_config.hasJobCards) {
      final statusColors = {'pending': AppTheme.warning, 'in-progress': AppTheme.info, 'done': AppTheme.primaryColor};
      final statusIcons = {'pending': LucideIcons.clock, 'in-progress': LucideIcons.wrench, 'done': LucideIcons.checkCircle};

      widgets.add(_cardContainer(
        title: 'Job Status Board',
        child: Column(
          children: [
            Row(
              children: ['pending', 'in-progress', 'done'].map((status) {
                final count = _jobStatusCounts[status] ?? 0;
                final color = statusColors[status] ?? AppTheme.textSecondary;
                final icon = statusIcons[status] ?? LucideIcons.circle;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                    child: Column(children: [
                      Icon(icon, size: 22, color: color),
                      const SizedBox(height: 6),
                      Text('$count', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: color)),
                      Text(_capitalise(status), style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _ProfitRow(label: 'Total Billed', value: _fmtCurrency(_totalCollected), color: AppTheme.textPrimary),
            const Divider(height: 1, color: AppTheme.borderLight),
            _ProfitRow(label: 'Advance Received', value: _fmtCurrency(_totalAdvance), color: AppTheme.info),
            const Divider(height: 1, color: AppTheme.borderLight),
            _ProfitRow(label: 'Balance Due', value: _fmtCurrency(_totalCollected - _totalAdvance), color: AppTheme.warning),
          ],
        ),
      ));
      widgets.add(const SizedBox(height: 16));
    }

    // ── Expiring Stock Alerts (Pharmacy) ──
    if (_config.hasExpiryTracking && _expiringProducts.isNotEmpty) {
      widgets.add(_cardContainer(
        title: 'Expiring Stock Alerts',
        titleIcon: LucideIcons.alertTriangle,
        titleIconColor: AppTheme.error,
        child: Column(
          children: _expiringProducts.take(5).map((p) {
            final daysLeft = p.expiryDate != null ? p.expiryDate!.difference(DateTime.now()).inDays : 999;
            final isExpired = daysLeft <= 0;
            final isUrgent = daysLeft <= 30;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: isExpired ? AppTheme.error.withOpacity(0.1) : (isUrgent ? AppTheme.warning.withOpacity(0.1) : const Color(0xFFEFF6FF)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(LucideIcons.pill, size: 18, color: isExpired ? AppTheme.error : (isUrgent ? AppTheme.warning : AppTheme.info)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        p.batchNumber != null ? 'Batch: ${p.batchNumber}' : 'Stock: ${p.stock}',
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isExpired ? AppTheme.error.withOpacity(0.1) : (isUrgent ? AppTheme.warning.withOpacity(0.1) : AppTheme.info.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isExpired ? 'EXPIRED' : '${daysLeft}d left',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: isExpired ? AppTheme.error : (isUrgent ? AppTheme.warning : AppTheme.info)),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ));
      widgets.add(const SizedBox(height: 16));
    }

    return widgets;
  }

  // ═══════════════════════════════════════════════════════════
  // TOP SELLING ITEMS
  // ═══════════════════════════════════════════════════════════

  Widget _buildTopSellingItems() {
    final itemLabel = _config.hasJobCards
        ? 'Top Services'
        : _config.hasDineInTakeaway
            ? 'Top Menu Items'
            : 'Top Selling ${_config.salesItemLabel}s';

    return _cardContainer(
      title: itemLabel,
      child: _topItems.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('No data for this period', style: GoogleFonts.inter(color: AppTheme.textSecondary))),
            )
          : Column(
              children: _topItems.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final name = item['name'] as String;
                final sold = item['sold'] as int;
                final revenue = item['revenue'] as double;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: AppTheme.primarySurface, borderRadius: BorderRadius.circular(8)),
                        child: Center(child: Text('${i + 1}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.primaryColor))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(
                            _config.hasJobCards ? '$sold jobs' : '$sold units sold',
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ]),
                      ),
                      Text(_fmtCurrency(revenue), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.primaryColor)),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════

  Widget _cardContainer({required String title, required Widget child, IconData? titleIcon, Color? titleIconColor}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (titleIcon != null) ...[
              Icon(titleIcon, size: 16, color: titleIconColor ?? AppTheme.textSecondary),
              const SizedBox(width: 6),
            ],
            Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  String _capitalise(String s) {
    if (s.isEmpty) return s;
    return s.split('-').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join('-');
  }
}

// ═══════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconBg;
  final Color iconColor;
  final Color? valueColor;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconBg,
    required this.iconColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: valueColor ?? AppTheme.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfitRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ProfitRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary)),
          Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
        ],
      ),
    );
  }
}
