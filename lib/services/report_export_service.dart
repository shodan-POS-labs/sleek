import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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

  /// Generate a **PDF** monthly sales report and return the file.
  Future<File> exportMonthlySalesPdf({
    required String shopId,
    required int year,
    required int month,
  }) async {
    final data = await _gatherMonthlyData(shopId, year, month);
    final pdfDoc = await _buildPdf(data);
    final bytes = await pdfDoc.save();
    final file = await _writeFile(bytes, 'Sales_Report_${data.monthLabel}.pdf');
    return file;
  }

  /// Generate an **Excel** monthly sales report and return the file.
  Future<File> exportMonthlySalesExcel({
    required String shopId,
    required int year,
    required int month,
  }) async {
    final data = await _gatherMonthlyData(shopId, year, month);
    final bytes = _buildExcel(data);
    final file = await _writeFile(bytes, 'Sales_Report_${data.monthLabel}.xlsx');
    return file;
  }

  /// Share a generated report file using the system share sheet.
  Future<void> shareFile(File file) async {
    final xFile = XFile(file.path);
    await Share.shareXFiles(
      [xFile],
      subject: 'Sleek POS — Sales Report',
    );
  }

  // ── Data gathering ─────────────────────────────────────────

  Future<_MonthlyReportData> _gatherMonthlyData(
      String shopId, int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59, 999); // last ms of last day

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
    final avgOrderValue =
        d.totalOrders > 0 ? d.totalRevenue / d.totalOrders : 0.0;

    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      backgroundColorHex: ExcelColor.fromHexString('#059669'),
      fontColorHex: ExcelColor.white,
    );

    // ── Sheet 1: Summary ──
    final summary = excel['Summary'];
    summary.appendRow([TextCellValue('${d.shopName} — Monthly Sales Report')]);
    summary.appendRow([TextCellValue(d.monthDisplay)]);
    summary.appendRow([TextCellValue('')]);
    summary.appendRow([TextCellValue('Metric'), TextCellValue('Value')]);

    // Apply title styles to rows 0 and 1
    _styleCell(summary, 0, 0, CellStyle(bold: true, fontSize: 14));
    _styleCell(summary, 1, 0, CellStyle(bold: true, fontSize: 12));
    // Apply header style to row 3
    _styleCell(summary, 3, 0, headerStyle);
    _styleCell(summary, 3, 1, headerStyle);

    summary.appendRow(
        [TextCellValue('Total Revenue'), TextCellValue(_fmt(d.totalRevenue))]);
    summary.appendRow(
        [TextCellValue('Total Orders'), TextCellValue('${d.totalOrders}')]);
    summary.appendRow([
      TextCellValue('Avg. Order Value'),
      TextCellValue(_fmt(avgOrderValue))
    ]);
    summary.appendRow([
      TextCellValue('Total Discounts'),
      TextCellValue(_fmt(d.totalDiscount))
    ]);
    if (d.config.hasWholesalePrice) {
      summary.appendRow([
        TextCellValue('Cost of Goods'),
        TextCellValue(_fmt(d.totalCost))
      ]);
      summary.appendRow(
          [TextCellValue('Net Profit'), TextCellValue(_fmt(netProfit))]);
    }

    // Payment breakdown
    summary.appendRow([TextCellValue('')]);
    summary
        .appendRow([TextCellValue('Payment Method'), TextCellValue('Amount')]);
    // Style payment header
    final payHeaderRow = d.config.hasWholesalePrice ? 11 : 9;
    _styleCell(summary, payHeaderRow, 0, headerStyle);
    _styleCell(summary, payHeaderRow, 1, headerStyle);
    for (final e in d.paymentBreakdown.entries) {
      summary.appendRow([
        TextCellValue(_capitalize(e.key)),
        TextCellValue(_fmt(e.value))
      ]);
    }

    // Set column widths for readability
    summary.setColumnWidth(0, 28);
    summary.setColumnWidth(1, 22);

    // ── Sheet 2: Daily Breakdown ──
    final daily = excel['Daily Breakdown'];
    daily.appendRow([
      TextCellValue('Date'),
      TextCellValue('Orders'),
      TextCellValue('Revenue'),
      TextCellValue('Discounts'),
    ]);
    for (int c = 0; c < 4; c++) {
      _styleCell(daily, 0, c, headerStyle);
    }
    for (final day in d.dailyBreakdown) {
      daily.appendRow([
        TextCellValue('${day.day}/${d.month}/${d.year}'),
        IntCellValue(day.orders),
        DoubleCellValue(day.revenue),
        DoubleCellValue(day.discount),
      ]);
    }
    daily.setColumnWidth(0, 16);
    daily.setColumnWidth(1, 12);
    daily.setColumnWidth(2, 18);
    daily.setColumnWidth(3, 18);

    // ── Sheet 3: Top Items ──
    final topSheet = excel['Top Items'];
    topSheet.appendRow([
      TextCellValue('#'),
      TextCellValue('Item'),
      TextCellValue('Qty Sold'),
      TextCellValue('Revenue'),
    ]);
    for (int c = 0; c < 4; c++) {
      _styleCell(topSheet, 0, c, headerStyle);
    }
    for (var i = 0; i < d.topItems.length; i++) {
      final item = d.topItems[i];
      topSheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(item.name),
        DoubleCellValue(item.qty),
        DoubleCellValue(item.revenue),
      ]);
    }
    topSheet.setColumnWidth(0, 6);
    topSheet.setColumnWidth(1, 30);
    topSheet.setColumnWidth(2, 12);
    topSheet.setColumnWidth(3, 18);

    // ── Sheet 4: Transactions ──
    final txSheet = excel['Transactions'];
    txSheet.appendRow([
      TextCellValue('Invoice #'),
      TextCellValue('Date'),
      TextCellValue('Amount'),
      TextCellValue('Discount'),
      TextCellValue('Payment'),
    ]);
    for (int c = 0; c < 5; c++) {
      _styleCell(txSheet, 0, c, headerStyle);
    }
    for (final s in d.sales) {
      txSheet.appendRow([
        TextCellValue(s.invoiceNumber),
        TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(s.createdAt)),
        DoubleCellValue(s.totalAmount),
        DoubleCellValue(s.discount),
        TextCellValue(_capitalize(s.paymentMethod)),
      ]);
    }
    txSheet.setColumnWidth(0, 16);
    txSheet.setColumnWidth(1, 20);
    txSheet.setColumnWidth(2, 16);
    txSheet.setColumnWidth(3, 14);
    txSheet.setColumnWidth(4, 14);

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
    for (int c = 0; c < 6; c++) {
      _styleCell(itemsSheet, 0, c, headerStyle);
    }
    for (final item in d.allItems) {
      itemsSheet.appendRow([
        TextCellValue(item.saleId),
        TextCellValue(item.productName),
        DoubleCellValue(item.price),
        DoubleCellValue(item.quantity),
        DoubleCellValue(item.discount),
        DoubleCellValue(item.total),
      ]);
    }
    itemsSheet.setColumnWidth(0, 24);
    itemsSheet.setColumnWidth(1, 28);
    itemsSheet.setColumnWidth(2, 14);
    itemsSheet.setColumnWidth(3, 8);
    itemsSheet.setColumnWidth(4, 14);
    itemsSheet.setColumnWidth(5, 14);

    // Remove default 'Sheet1' if it exists
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    return excel.encode()!;
  }

  /// Apply a CellStyle to a specific cell by row/col index (after appendRow).
  void _styleCell(Sheet sheet, int row, int col, CellStyle style) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        .cellStyle = style;
  }

  // ── Helpers ────────────────────────────────────────────────

  String _fmt(double amount) => 'Rs. ${_currencyFmt.format(amount.toInt())}';
  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Future<File> _writeFile(List<int> bytes, String filename) async {
    final dir = await _getReportsDir();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Returns the reports directory, creating it if needed.
  Future<Directory> _getReportsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${dir.path}/Sleek_Reports');
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }
    return reportsDir;
  }

  /// List all generated report files, sorted newest-first.
  Future<List<File>> listReportFiles() async {
    final dir = await _getReportsDir();
    if (!await dir.exists()) return [];
    final entities = await dir.list().toList();
    final files = entities
        .whereType<File>()
        .where((f) {
          final ext = f.path.split('.').last.toLowerCase();
          return ext == 'pdf' || ext == 'xlsx';
        })
        .toList();
    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

  /// Rename a report file (keeps it in the same directory).
  Future<File> renameFile(File file, String newName) async {
    final dir = file.parent.path;
    final newPath = '$dir/$newName';
    return await file.rename(newPath);
  }

  /// Delete a report file.
  Future<void> deleteFile(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Returns the full path to the reports directory (for display).
  Future<String> getReportsDirPath() async {
    final dir = await _getReportsDir();
    return dir.path;
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
  double qty = 0;
  double revenue = 0;
  _ItemSummary({required this.name});
}
