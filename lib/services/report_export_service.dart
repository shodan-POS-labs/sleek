import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import '../models/sale.dart';
import '../models/business_config.dart';
import '../services/firestore_service.dart';

/// Handles monthly sales-report generation in PDF & Excel formats.
class ReportExportService {
  final FirestoreService _db = FirestoreService();
  final _currencyFmt = NumberFormat('#,###');

  // ── Public entry points ────────────────────────────────────

  /// Generate and open a **PDF** monthly sales report.
  Future<File> exportMonthlySalesPdf({
    required String shopId,
    required int year,
    required int month,
  }) async {
    final data = await _gatherMonthlyData(shopId, year, month);
    final pdfDoc = await _buildPdf(data);
    final bytes = await pdfDoc.save();
    final file = await _writeFile(bytes, 'Sales_Report_${data.monthLabel}.pdf');
    await OpenFile.open(file.path);
    return file;
  }

  /// Generate and open an **Excel** monthly sales report.
  Future<File> exportMonthlySalesExcel({
    required String shopId,
    required int year,
    required int month,
  }) async {
    final data = await _gatherMonthlyData(shopId, year, month);
    final bytes = _buildExcel(data);
    final file = await _writeFile(bytes, 'Sales_Report_${data.monthLabel}.xlsx');
    await OpenFile.open(file.path);
    return file;
  }

  // ── Data gathering ─────────────────────────────────────────

  Future<_MonthlyReportData> _gatherMonthlyData(
      String shopId, int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59); // last day

    final config = await _db.getBusinessConfig(shopId);
    final shopDetails = await _db.getShopDetails(shopId);
    final shopName = shopDetails?['name'] as String? ?? 'My Shop';

    final sales = await _db.getSalesInRange(shopId, start, end);
    final saleIds =
        sales.where((s) => s.id != null).map((s) => s.id!).toList();

    List<SaleItem> allItems = [];
    if (saleIds.isNotEmpty) {
      allItems = await _db.getSaleItemsForSales(shopId, saleIds);
    }

    // Build product price map for cost estimation
    final products = await _db.getProducts(shopId);
    final wholesaleMap = <String, double>{};
    for (final p in products) {
      if (p.id != null) wholesaleMap[p.id!] = p.wholesalePrice;
    }

    // Aggregate
    final totalRevenue =
        sales.fold(0.0, (s, e) => s + e.totalAmount);
    final totalDiscount =
        sales.fold(0.0, (s, e) => s + e.discount);
    double totalCost = 0;
    if (config.hasWholesalePrice) {
      for (final item in allItems) {
        totalCost += (wholesaleMap[item.productId] ?? 0) * item.quantity;
      }
    }

    // Daily breakdown
    final dailyMap = <int, _DaySummary>{};
    for (final sale in sales) {
      final day = sale.createdAt.day;
      dailyMap.putIfAbsent(day, () => _DaySummary(day: day));
      dailyMap[day]!.revenue += sale.totalAmount;
      dailyMap[day]!.orders += 1;
      dailyMap[day]!.discount += sale.discount;
    }
    final dailyList = dailyMap.values.toList()..sort((a, b) => a.day.compareTo(b.day));

    // Top items
    final itemAgg = <String, _ItemSummary>{};
    for (final item in allItems) {
      itemAgg.putIfAbsent(
          item.productName, () => _ItemSummary(name: item.productName));
      itemAgg[item.productName]!.qty += item.quantity;
      itemAgg[item.productName]!.revenue += item.total;
    }
    final topItems = itemAgg.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    // Payment method breakdown
    final paymentMap = <String, double>{};
    for (final sale in sales) {
      final method = sale.paymentMethod.isEmpty ? 'cash' : sale.paymentMethod;
      paymentMap[method] = (paymentMap[method] ?? 0) + sale.totalAmount;
    }

    return _MonthlyReportData(
      shopName: shopName,
      monthLabel: DateFormat('MMMM_yyyy').format(start),
      monthDisplay: DateFormat('MMMM yyyy').format(start),
      config: config,
      totalRevenue: totalRevenue,
      totalOrders: sales.length,
      totalCost: totalCost,
      totalDiscount: totalDiscount,
      dailyBreakdown: dailyList,
      topItems: topItems.take(15).toList(),
      paymentBreakdown: paymentMap,
      sales: sales,
      allItems: allItems,
      year: year,
      month: month,
    );
  }

  // ── PDF Builder ────────────────────────────────────────────

  Future<pw.Document> _buildPdf(_MonthlyReportData d) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    );

    final netProfit = d.totalRevenue - d.totalCost - d.totalDiscount;
    final avgOrderValue = d.totalOrders > 0 ? d.totalRevenue / d.totalOrders : 0.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _pdfHeader(d, context),
        footer: (context) => _pdfFooter(context),
        build: (context) {
          final widgets = <pw.Widget>[];

          // ── Summary Section ──
          widgets.add(_pdfSectionTitle('Summary'));
          widgets.add(
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(3),
              },
              children: [
                _pdfKvRow('Total Revenue', _fmt(d.totalRevenue)),
                _pdfKvRow('Total Orders', '${d.totalOrders}'),
                _pdfKvRow('Avg. Order Value', _fmt(avgOrderValue)),
                _pdfKvRow('Total Discounts', _fmt(d.totalDiscount)),
                if (d.config.hasWholesalePrice) ...[
                  _pdfKvRow('Cost of Goods', _fmt(d.totalCost)),
                  _pdfKvRow('Net Profit', _fmt(netProfit)),
                ],
              ],
            ),
          );
          widgets.add(pw.SizedBox(height: 16));

          // ── Payment Breakdown ──
          if (d.paymentBreakdown.isNotEmpty) {
            widgets.add(_pdfSectionTitle('Payment Method Breakdown'));
            widgets.add(
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(3),
                },
                children: d.paymentBreakdown.entries.map((e) {
                  return _pdfKvRow(_capitalize(e.key), _fmt(e.value));
                }).toList(),
              ),
            );
            widgets.add(pw.SizedBox(height: 16));
          }

          // ── Daily Breakdown ──
          widgets.add(_pdfSectionTitle('Daily Breakdown'));
          widgets.add(
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.green50,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              headers: ['Day', 'Orders', 'Revenue', 'Discounts'],
              data: d.dailyBreakdown.map((day) {
                return [
                  '${day.day}/${d.month}/${d.year}',
                  '${day.orders}',
                  _fmt(day.revenue),
                  _fmt(day.discount),
                ];
              }).toList(),
            ),
          );
          widgets.add(pw.SizedBox(height: 16));

          // ── Top Selling Items ──
          if (d.topItems.isNotEmpty) {
            widgets.add(_pdfSectionTitle(
              d.config.hasJobCards
                  ? 'Top Services'
                  : d.config.hasDineInTakeaway
                      ? 'Top Menu Items'
                      : 'Top Selling Items',
            ));
            widgets.add(
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.green50),
                cellAlignment: pw.Alignment.centerLeft,
                headers: ['#', 'Item', 'Qty Sold', 'Revenue'],
                data: d.topItems.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  return [
                    '${i + 1}',
                    item.name,
                    '${item.qty}',
                    _fmt(item.revenue),
                  ];
                }).toList(),
              ),
            );
            widgets.add(pw.SizedBox(height: 16));
          }

          // ── Full Transaction Log ──
          widgets.add(_pdfSectionTitle('Transaction Log'));
          widgets.add(
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green50),
              cellAlignment: pw.Alignment.centerLeft,
              headers: ['Invoice #', 'Date', 'Amount', 'Discount', 'Payment'],
              data: d.sales.map((s) {
                return [
                  s.invoiceNumber,
                  DateFormat('dd/MM HH:mm').format(s.createdAt),
                  _fmt(s.totalAmount),
                  _fmt(s.discount),
                  _capitalize(s.paymentMethod),
                ];
              }).toList(),
            ),
          );

          return widgets;
        },
      ),
    );

    return pdf;
  }

  pw.Widget _pdfHeader(_MonthlyReportData d, pw.Context context) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(d.shopName,
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('Monthly Sales Report',
                    style:
                        const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(d.monthDisplay,
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                pw.SizedBox(height: 2),
                pw.Text(
                    'Generated: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
              ],
            ),
          ],
        ),
        pw.Divider(color: PdfColors.green, thickness: 2),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _pdfFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
      ),
    );
  }

  pw.Widget _pdfSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(title,
          style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green900)),
    );
  }

  pw.TableRow _pdfKvRow(String key, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(key,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(value,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ),
      ],
    );
  }

  // ── Excel Builder ──────────────────────────────────────────

  List<int> _buildExcel(_MonthlyReportData d) {
    final excel = Excel.createExcel();
    final netProfit = d.totalRevenue - d.totalCost - d.totalDiscount;
    final avgOrderValue = d.totalOrders > 0 ? d.totalRevenue / d.totalOrders : 0.0;

    // ── Sheet 1: Summary ──
    final summary = excel['Summary'];
    _excelTitle(summary, 0, '${d.shopName} — Monthly Sales Report');
    _excelTitle(summary, 1, d.monthDisplay);
    summary.appendRow([TextCellValue('')]);

    final summaryRows = [
      ['Total Revenue', _fmt(d.totalRevenue)],
      ['Total Orders', '${d.totalOrders}'],
      ['Avg. Order Value', _fmt(avgOrderValue)],
      ['Total Discounts', _fmt(d.totalDiscount)],
    ];
    if (d.config.hasWholesalePrice) {
      summaryRows.add(['Cost of Goods', _fmt(d.totalCost)]);
      summaryRows.add(['Net Profit', _fmt(netProfit)]);
    }
    for (final row in summaryRows) {
      summary.appendRow([TextCellValue(row[0]), TextCellValue(row[1])]);
    }

    // Payment breakdown
    summary.appendRow([TextCellValue('')]);
    summary.appendRow([TextCellValue('Payment Method'), TextCellValue('Amount')]);
    for (final e in d.paymentBreakdown.entries) {
      summary.appendRow([TextCellValue(_capitalize(e.key)), TextCellValue(_fmt(e.value))]);
    }

    // ── Sheet 2: Daily Breakdown ──
    final daily = excel['Daily Breakdown'];
    daily.appendRow([
      TextCellValue('Date'),
      TextCellValue('Orders'),
      TextCellValue('Revenue'),
      TextCellValue('Discounts'),
    ]);
    for (final day in d.dailyBreakdown) {
      daily.appendRow([
        TextCellValue('${day.day}/${d.month}/${d.year}'),
        IntCellValue(day.orders),
        DoubleCellValue(day.revenue),
        DoubleCellValue(day.discount),
      ]);
    }

    // ── Sheet 3: Top Items ──
    final topSheet = excel['Top Items'];
    topSheet.appendRow([
      TextCellValue('#'),
      TextCellValue('Item'),
      TextCellValue('Qty Sold'),
      TextCellValue('Revenue'),
    ]);
    for (var i = 0; i < d.topItems.length; i++) {
      final item = d.topItems[i];
      topSheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(item.name),
        IntCellValue(item.qty),
        DoubleCellValue(item.revenue),
      ]);
    }

    // ── Sheet 4: Transactions ──
    final txSheet = excel['Transactions'];
    txSheet.appendRow([
      TextCellValue('Invoice #'),
      TextCellValue('Date'),
      TextCellValue('Amount'),
      TextCellValue('Discount'),
      TextCellValue('Payment'),
    ]);
    for (final s in d.sales) {
      txSheet.appendRow([
        TextCellValue(s.invoiceNumber),
        TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(s.createdAt)),
        DoubleCellValue(s.totalAmount),
        DoubleCellValue(s.discount),
        TextCellValue(_capitalize(s.paymentMethod)),
      ]);
    }

    // ── Sheet 5: Line Items ──
    final itemsSheet = excel['Line Items'];
    itemsSheet.appendRow([
      TextCellValue('Sale ID'),
      TextCellValue('Product'),
      TextCellValue('Price'),
      TextCellValue('Qty'),
      TextCellValue('Discount'),
      TextCellValue('Total'),
    ]);
    for (final item in d.allItems) {
      itemsSheet.appendRow([
        TextCellValue(item.saleId),
        TextCellValue(item.productName),
        DoubleCellValue(item.price),
        IntCellValue(item.quantity),
        DoubleCellValue(item.discount),
        DoubleCellValue(item.total),
      ]);
    }

    // Remove default 'Sheet1' if it exists
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    return excel.encode()!;
  }

  void _excelTitle(Sheet sheet, int row, String text) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
        TextCellValue(text);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle =
        CellStyle(bold: true, fontSize: 14);
  }

  // ── Helpers ────────────────────────────────────────────────

  String _fmt(double amount) => 'Rs. ${_currencyFmt.format(amount.toInt())}';
  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Future<File> _writeFile(List<int> bytes, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${dir.path}/ShopFlow_Reports');
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }
    final file = File('${reportsDir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file;
  }
}

// ── Internal data models ─────────────────────────────────────

class _MonthlyReportData {
  final String shopName;
  final String monthLabel;
  final String monthDisplay;
  final BusinessConfig config;
  final double totalRevenue;
  final int totalOrders;
  final double totalCost;
  final double totalDiscount;
  final List<_DaySummary> dailyBreakdown;
  final List<_ItemSummary> topItems;
  final Map<String, double> paymentBreakdown;
  final List<Sale> sales;
  final List<SaleItem> allItems;
  final int year;
  final int month;

  _MonthlyReportData({
    required this.shopName,
    required this.monthLabel,
    required this.monthDisplay,
    required this.config,
    required this.totalRevenue,
    required this.totalOrders,
    required this.totalCost,
    required this.totalDiscount,
    required this.dailyBreakdown,
    required this.topItems,
    required this.paymentBreakdown,
    required this.sales,
    required this.allItems,
    required this.year,
    required this.month,
  });
}

class _DaySummary {
  final int day;
  double revenue = 0;
  int orders = 0;
  double discount = 0;
  _DaySummary({required this.day});
}

class _ItemSummary {
  final String name;
  int qty = 0;
  double revenue = 0;
  _ItemSummary({required this.name});
}
