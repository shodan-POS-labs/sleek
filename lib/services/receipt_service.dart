// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../models/receipt_settings.dart';
import '../models/sale.dart';

/// ReceiptService
///
/// Responsibilities:
///   1. [buildReceiptPdf]   — build a pw.Document from sale data + settings
///   2. [saveReceiptPdf]    — persist PDF to Sleek_Receipts/ directory
///   3. [printReceipt]      — route to WiFi (system dialog) or Bluetooth (ESC/POS)
///   4. [shareReceipt]      — share saved PDF via system share sheet
///   5. [listReceiptFiles]  — list saved receipts newest-first

class ReceiptService {
  static const _dir = 'Sleek_Receipts';
  final _fmt = NumberFormat('#,###.00');

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Build a PDF document for the given sale.
  Future<pw.Document> buildReceiptPdf({
    required Sale sale,
    required List<SaleItem> items,
    required ReceiptSettings settings,
    required Map<String, dynamic> shopDetails,
    String? cashierName,
    String? customerName,
    String? customerPhone,
    double amountPaid = 0,
  }) async {
    final sName = settings.businessName.isNotEmpty
        ? settings.businessName
        : (shopDetails['name'] as String? ?? 'Sleek POS');
    final sAddr  = settings.address.isNotEmpty  ? settings.address  : (shopDetails['address']  as String? ?? '');
    final sPhone = settings.phone.isNotEmpty    ? settings.phone    : (shopDetails['phone']    as String? ?? '');
    final sEmail = settings.email.isNotEmpty    ? settings.email    : (shopDetails['email']    as String? ?? '');
    final sTaxId = settings.taxId.isNotEmpty    ? settings.taxId    : (shopDetails['taxId']    as String? ?? '');

    final ht = _htmlFontSize(settings.fontSize);
    final isThermal = settings.paperFormat.isThermal;
    final pw.PageTheme theme;

    if (isThermal) {
      final w = settings.paperFormat.widthPt;
      theme = pw.PageTheme(
        pageFormat: PdfPageFormat(w, double.infinity, marginAll: 6),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
      );
    } else {
      final pf = _pdfPageFormat(settings.paperFormat);
      theme = pw.PageTheme(
        pageFormat: pf,
        margin: const pw.EdgeInsets.symmetric(horizontal: 42, vertical: 36),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
        ),
      );
    }

    final doc = pw.Document(theme: theme.theme);

    final subtotal = items.fold(0.0, (s, i) => s + i.total);
    final discountTotal = sale.discount + items.fold(0.0, (s, i) => s + i.discount);
    final grandTotal = sale.totalAmount;
    final change = amountPaid > grandTotal ? amountPaid - grandTotal : 0.0;
    final remaining = grandTotal - sale.advanceAmount;

    if (isThermal) {
      // Thermal: single continuous page
      doc.addPage(
        pw.Page(
          pageTheme: theme,
          build: (ctx) => _buildThermalContent(
            sale: sale,
            items: items,
            settings: settings,
            shopName: sName,
            address: sAddr,
            phone: sPhone,
            email: sEmail,
            taxId: sTaxId,
            cashierName: cashierName,
            customerName: customerName,
            customerPhone: customerPhone,
            subtotal: subtotal,
            discountTotal: discountTotal,
            grandTotal: grandTotal,
            amountPaid: amountPaid,
            change: change,
            remaining: remaining,
            ht: ht,
          ),
        ),
      );
    } else {
      // A4/A5/Letter: proper paged layout
      doc.addPage(
        pw.MultiPage(
          pageTheme: theme,
          build: (ctx) => _buildFullPageContent(
            sale: sale,
            items: items,
            settings: settings,
            shopName: sName,
            address: sAddr,
            phone: sPhone,
            email: sEmail,
            taxId: sTaxId,
            cashierName: cashierName,
            customerName: customerName,
            customerPhone: customerPhone,
            subtotal: subtotal,
            discountTotal: discountTotal,
            grandTotal: grandTotal,
            amountPaid: amountPaid,
            change: change,
            remaining: remaining,
            ht: ht,
          ),
        ),
      );
    }

    return doc;
  }

  /// Save a receipt PDF to Sleek_Receipts directory. Returns the saved file.
  Future<File> saveReceiptPdf(pw.Document doc, String invoiceNumber) async {
    final bytes = await doc.save();
    final dir = await _getReceiptsDir();
    final file = File('${dir.path}/Receipt_$invoiceNumber.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Full print pipeline: build → save → print via correct path.
  /// Returns the saved File so caller can show "View" action.
  Future<File> printReceipt({
    required BuildContext context,
    required Sale sale,
    required List<SaleItem> items,
    required ReceiptSettings settings,
    required Map<String, dynamic> shopDetails,
    String? cashierName,
    String? customerName,
    String? customerPhone,
    double amountPaid = 0,
  }) async {
    final doc = await buildReceiptPdf(
      sale: sale,
      items: items,
      settings: settings,
      shopDetails: shopDetails,
      cashierName: cashierName,
      customerName: customerName,
      customerPhone: customerPhone,
      amountPaid: amountPaid,
    );

    final savedFile = await saveReceiptPdf(doc, sale.invoiceNumber);

    if (settings.printerType == PrinterType.wifi) {
      if (settings.wifiPrinterIp.isNotEmpty) {
        // Direct WiFi ESC/POS printing via raw socket
        await _printWifi(
          sale: sale,
          items: items,
          settings: settings,
          shopDetails: shopDetails,
          cashierName: cashierName,
          customerName: customerName,
          amountPaid: amountPaid,
        );
      } else {
        // Fallback: system print dialog
        final bytes = await doc.save();
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: 'Receipt_${sale.invoiceNumber}',
        );
      }
    } else {
      // Bluetooth ESC/POS thermal
      await _printBluetooth(
        sale: sale,
        items: items,
        settings: settings,
        shopDetails: shopDetails,
        cashierName: cashierName,
        customerName: customerName,
        amountPaid: amountPaid,
      );
    }

    return savedFile;
  }

  /// Share a saved receipt file.
  Future<void> shareReceipt(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Sleek POS — Receipt',
    );
  }

  /// Re-print from a saved PDF file (WiFi only — opens system dialog).
  Future<void> reprintWifi(File file) async {
    final bytes = await file.readAsBytes();
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: file.path.split('/').last,
    );
  }

  /// List all saved receipt PDFs, newest-first.
  Future<List<File>> listReceiptFiles() async {
    final dir = await _getReceiptsDir();
    if (!await dir.exists()) return [];
    final entities = await dir.list().toList();
    final files = entities
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.pdf'))
        .toList();
    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

  /// Delete a saved receipt file.
  Future<void> deleteFile(File file) async {
    if (await file.exists()) await file.delete();
  }

  /// Returns the full path string (for display).
  Future<String> getReceiptsDirPath() async {
    final d = await _getReceiptsDir();
    return d.path;
  }

  // ── Directory ────────────────────────────────────────────────────────────

  Future<Directory> _getReceiptsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_dir');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ── Bluetooth ESC/POS ────────────────────────────────────────────────────

  Future<void> _printBluetooth({
    required Sale sale,
    required List<SaleItem> items,
    required ReceiptSettings settings,
    required Map<String, dynamic> shopDetails,
    String? cashierName,
    String? customerName,
    double amountPaid = 0,
  }) async {
    final bt = BlueThermalPrinter.instance;
    final connected = await bt.isConnected ?? false;
    if (!connected) throw Exception('No Bluetooth printer connected. Check Printer Settings.');

    final profile = await CapabilityProfile.load();
    final paper = settings.paperFormat == PaperFormat.mm58 ? PaperSize.mm58 : PaperSize.mm80;
    final generator = Generator(paper, profile);
    var bytes = <int>[];

    final sName = settings.businessName.isNotEmpty
        ? settings.businessName
        : (shopDetails['name'] as String? ?? 'Sleek POS');
    final sAddr  = settings.address.isNotEmpty ? settings.address  : (shopDetails['address']  as String? ?? '');
    final sPhone = settings.phone.isNotEmpty   ? settings.phone    : (shopDetails['phone']    as String? ?? '');

    bytes += generator.reset();

    // Header
    if (settings.showBusinessInfo) {
      bytes += generator.text(sName.toUpperCase(), styles: const PosStyles(bold: true, align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size2));
      if (sAddr.isNotEmpty)  bytes += generator.text(sAddr,  styles: const PosStyles(align: PosAlign.center));
      if (sPhone.isNotEmpty) bytes += generator.text('Tel: $sPhone', styles: const PosStyles(align: PosAlign.center));
    }
    if (settings.headerNote.isNotEmpty) bytes += generator.text(settings.headerNote, styles: const PosStyles(align: PosAlign.center));

    bytes += generator.hr();

    // Transaction info
    if (settings.showReceiptNumber) bytes += generator.text('Receipt: ${sale.invoiceNumber}');
    if (settings.showDateTime) {
      final dateStr = DateFormat('dd/MM/yyyy  HH:mm').format(sale.createdAt);
      bytes += generator.text('Date: $dateStr');
    }
    if (settings.showCashierName && cashierName != null && cashierName.isNotEmpty) {
      bytes += generator.text('Cashier: $cashierName');
    }
    if (settings.showCustomerInfo && customerName != null && customerName.isNotEmpty) {
      bytes += generator.text('Customer: $customerName');
    }
    if (settings.showTableNumber && (sale.tableNumber?.isNotEmpty ?? false)) {
      bytes += generator.text('Table: ${sale.tableNumber}');
    }
    if (settings.showOrderType && sale.orderType.isNotEmpty) {
      bytes += generator.text('Type: ${_capitalize(sale.orderType)}');
    }
    if (settings.showDeviceInfo && (sale.deviceInfo?.isNotEmpty ?? false)) {
      bytes += generator.text('Device: ${sale.deviceInfo}');
    }

    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'ITEM', width: 8, styles: const PosStyles(bold: true)),
      PosColumn(text: 'TOTAL', width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);
    bytes += generator.hr();

    // Items
    double subtotal = 0;
    double discountTotal = sale.discount;
    for (final item in items) {
      final lineTotal = item.total;
      subtotal += lineTotal;
      discountTotal += item.discount;

      bytes += generator.row([
        PosColumn(text: item.productName, width: 8),
        PosColumn(text: _fmt.format(lineTotal), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.text('  x${item.quantity} @ ${_fmt.format(item.price)}');

      if (settings.showVariants && (item.selectedVariant?.isNotEmpty ?? false)) {
        bytes += generator.text('  Variant: ${item.selectedVariant}');
      }
      if (settings.showModifiers && item.selectedModifiers.isNotEmpty) {
        for (final mod in item.selectedModifiers) {
          final mp = (mod['price'] as num?)?.toDouble() ?? 0;
          final mn = mod['name'] as String? ?? '';
          bytes += generator.text('  + $mn  +${_fmt.format(mp)}');
        }
      }
      if (settings.showItemNotes && (item.notes?.isNotEmpty ?? false)) {
        bytes += generator.text('  Note: ${item.notes}');
      }
    }

    bytes += generator.hr();

    // Totals
    if (settings.showSubtotal) {
      bytes += generator.row([
        PosColumn(text: 'Subtotal', width: 6),
        PosColumn(text: _fmt.format(subtotal), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    if (settings.showDiscount && discountTotal > 0) {
      bytes += generator.row([
        PosColumn(text: 'Discount', width: 6),
        PosColumn(text: '-${_fmt.format(discountTotal)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    if (settings.showGrandTotal) {
      bytes += generator.hr();
      bytes += generator.row([
        PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
        PosColumn(text: _fmt.format(sale.totalAmount), width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2, align: PosAlign.right)),
      ]);
    }

    // Advance payment
    if (settings.showAdvanceAmount && sale.advanceAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Advance Paid', width: 6),
        PosColumn(text: _fmt.format(sale.advanceAmount), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      final remaining = sale.totalAmount - sale.advanceAmount;
      if (settings.showRemainingBal) {
        bytes += generator.row([
          PosColumn(text: 'Balance Due', width: 6, styles: const PosStyles(bold: true)),
          PosColumn(text: _fmt.format(remaining), width: 6, styles: const PosStyles(bold: true, align: PosAlign.right)),
        ]);
      }
    }

    // Payment
    if (settings.showPaymentMethod && sale.paymentMethod.isNotEmpty) {
      bytes += generator.text('Payment: ${_capitalize(sale.paymentMethod)}');
    }
    if (settings.showAmountPaid && amountPaid > 0) {
      bytes += generator.row([
        PosColumn(text: 'Amount Paid', width: 6),
        PosColumn(text: _fmt.format(amountPaid), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      if (settings.showChange && amountPaid > sale.totalAmount) {
        final change = amountPaid - sale.totalAmount;
        bytes += generator.row([
          PosColumn(text: 'Change', width: 6),
          PosColumn(text: _fmt.format(change), width: 6, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }
    }

    bytes += generator.hr();

    // Footer
    if (settings.showReturnPolicy && settings.returnPolicy.isNotEmpty) {
      bytes += generator.text(settings.returnPolicy, styles: const PosStyles(align: PosAlign.center));
    }
    if (settings.showWarrantyText && settings.warrantyText.isNotEmpty) {
      bytes += generator.text(settings.warrantyText, styles: const PosStyles(align: PosAlign.center));
    }
    if (settings.showSignatureBox) {
      bytes += generator.emptyLines(2);
      bytes += generator.text('Customer Signature: ___________');
      bytes += generator.emptyLines(1);
    }
    if (settings.showThankYouMsg && settings.thankYouMessage.isNotEmpty) {
      bytes += generator.text(settings.thankYouMessage, styles: const PosStyles(align: PosAlign.center, bold: true));
    }

    bytes += generator.emptyLines(2);
    bytes += generator.cut();

    await bt.writeBytes(Uint8List.fromList(bytes));
  }

  // ── WiFi ESC/POS (raw socket) ────────────────────────────────────────────

  Future<void> _printWifi({
    required Sale sale,
    required List<SaleItem> items,
    required ReceiptSettings settings,
    required Map<String, dynamic> shopDetails,
    String? cashierName,
    String? customerName,
    double amountPaid = 0,
  }) async {
    final ip = settings.wifiPrinterIp;
    final port = settings.wifiPrinterPort;
    if (ip.isEmpty) throw Exception('WiFi printer IP is not configured. Go to Settings → Printer Settings → WiFi tab.');

    final profile = await CapabilityProfile.load();
    final paper = settings.paperFormat == PaperFormat.mm58 ? PaperSize.mm58 : PaperSize.mm80;
    final generator = Generator(paper, profile);
    var bytes = <int>[];

    final sName = settings.businessName.isNotEmpty
        ? settings.businessName
        : (shopDetails['name'] as String? ?? 'Sleek POS');
    final sAddr  = settings.address.isNotEmpty ? settings.address  : (shopDetails['address']  as String? ?? '');
    final sPhone = settings.phone.isNotEmpty   ? settings.phone    : (shopDetails['phone']    as String? ?? '');

    bytes += generator.reset();

    // Header
    if (settings.showBusinessInfo) {
      bytes += generator.text(sName.toUpperCase(), styles: const PosStyles(bold: true, align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size2));
      if (sAddr.isNotEmpty)  bytes += generator.text(sAddr,  styles: const PosStyles(align: PosAlign.center));
      if (sPhone.isNotEmpty) bytes += generator.text('Tel: $sPhone', styles: const PosStyles(align: PosAlign.center));
    }
    if (settings.headerNote.isNotEmpty) bytes += generator.text(settings.headerNote, styles: const PosStyles(align: PosAlign.center));

    bytes += generator.hr();

    // Transaction info
    if (settings.showReceiptNumber) bytes += generator.text('Receipt: ${sale.invoiceNumber}');
    if (settings.showDateTime) {
      final dateStr = DateFormat('dd/MM/yyyy  HH:mm').format(sale.createdAt);
      bytes += generator.text('Date: $dateStr');
    }
    if (settings.showCashierName && cashierName != null && cashierName.isNotEmpty) {
      bytes += generator.text('Cashier: $cashierName');
    }
    if (settings.showCustomerInfo && customerName != null && customerName.isNotEmpty) {
      bytes += generator.text('Customer: $customerName');
    }
    if (settings.showTableNumber && (sale.tableNumber?.isNotEmpty ?? false)) {
      bytes += generator.text('Table: ${sale.tableNumber}');
    }
    if (settings.showOrderType && sale.orderType.isNotEmpty) {
      bytes += generator.text('Type: ${_capitalize(sale.orderType)}');
    }

    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'ITEM', width: 8, styles: const PosStyles(bold: true)),
      PosColumn(text: 'TOTAL', width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);
    bytes += generator.hr();

    // Items
    double subtotal = 0;
    double discountTotal = sale.discount;
    for (final item in items) {
      final lineTotal = item.total;
      subtotal += lineTotal;
      discountTotal += item.discount;

      bytes += generator.row([
        PosColumn(text: item.productName, width: 8),
        PosColumn(text: _fmt.format(lineTotal), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.text('  x${item.quantity} @ ${_fmt.format(item.price)}');

      if (settings.showVariants && (item.selectedVariant?.isNotEmpty ?? false)) {
        bytes += generator.text('  Variant: ${item.selectedVariant}');
      }
      if (settings.showModifiers && item.selectedModifiers.isNotEmpty) {
        for (final mod in item.selectedModifiers) {
          final mp = (mod['price'] as num?)?.toDouble() ?? 0;
          final mn = mod['name'] as String? ?? '';
          bytes += generator.text('  + $mn  +${_fmt.format(mp)}');
        }
      }
      if (settings.showItemNotes && (item.notes?.isNotEmpty ?? false)) {
        bytes += generator.text('  Note: ${item.notes}');
      }
    }

    bytes += generator.hr();

    // Totals
    if (settings.showSubtotal) {
      bytes += generator.row([
        PosColumn(text: 'Subtotal', width: 6),
        PosColumn(text: _fmt.format(subtotal), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    if (settings.showDiscount && discountTotal > 0) {
      bytes += generator.row([
        PosColumn(text: 'Discount', width: 6),
        PosColumn(text: '-${_fmt.format(discountTotal)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    if (settings.showGrandTotal) {
      bytes += generator.hr();
      bytes += generator.row([
        PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
        PosColumn(text: _fmt.format(sale.totalAmount), width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2, align: PosAlign.right)),
      ]);
    }

    // Advance payment
    if (settings.showAdvanceAmount && sale.advanceAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Advance Paid', width: 6),
        PosColumn(text: _fmt.format(sale.advanceAmount), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      final remaining = sale.totalAmount - sale.advanceAmount;
      if (settings.showRemainingBal) {
        bytes += generator.row([
          PosColumn(text: 'Balance Due', width: 6, styles: const PosStyles(bold: true)),
          PosColumn(text: _fmt.format(remaining), width: 6, styles: const PosStyles(bold: true, align: PosAlign.right)),
        ]);
      }
    }

    // Payment
    if (settings.showPaymentMethod && sale.paymentMethod.isNotEmpty) {
      bytes += generator.text('Payment: ${_capitalize(sale.paymentMethod)}');
    }
    if (settings.showAmountPaid && amountPaid > 0) {
      bytes += generator.row([
        PosColumn(text: 'Amount Paid', width: 6),
        PosColumn(text: _fmt.format(amountPaid), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      if (settings.showChange && amountPaid > sale.totalAmount) {
        final change = amountPaid - sale.totalAmount;
        bytes += generator.row([
          PosColumn(text: 'Change', width: 6),
          PosColumn(text: _fmt.format(change), width: 6, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }
    }

    bytes += generator.hr();

    // Footer
    if (settings.showReturnPolicy && settings.returnPolicy.isNotEmpty) {
      bytes += generator.text(settings.returnPolicy, styles: const PosStyles(align: PosAlign.center));
    }
    if (settings.showWarrantyText && settings.warrantyText.isNotEmpty) {
      bytes += generator.text(settings.warrantyText, styles: const PosStyles(align: PosAlign.center));
    }
    if (settings.showSignatureBox) {
      bytes += generator.emptyLines(2);
      bytes += generator.text('Customer Signature: ___________');
      bytes += generator.emptyLines(1);
    }
    if (settings.showThankYouMsg && settings.thankYouMessage.isNotEmpty) {
      bytes += generator.text(settings.thankYouMessage, styles: const PosStyles(align: PosAlign.center, bold: true));
    }

    bytes += generator.emptyLines(2);
    bytes += generator.cut();

    // Send bytes over TCP socket
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      socket.add(Uint8List.fromList(bytes));
      await socket.flush();
    } finally {
      socket?.destroy();
    }
  }

  // ── PDF : Thermal content (single Page) ─────────────────────────────────

  pw.Widget _buildThermalContent({
    required Sale sale,
    required List<SaleItem> items,
    required ReceiptSettings settings,
    required String shopName,
    required String address,
    required String phone,
    required String email,
    required String taxId,
    String? cashierName,
    String? customerName,
    String? customerPhone,
    required double subtotal,
    required double discountTotal,
    required double grandTotal,
    required double amountPaid,
    required double change,
    required double remaining,
    required double ht,
  }) {
    final widgets = <pw.Widget>[];

    // Header
    if (settings.showBusinessInfo) {
      widgets.add(pw.Center(child: pw.Text(shopName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: ht + 2))));
      if (address.isNotEmpty) widgets.add(pw.Center(child: pw.Text(address, style: pw.TextStyle(fontSize: ht - 1))));
      if (phone.isNotEmpty)   widgets.add(pw.Center(child: pw.Text('Tel: $phone', style: pw.TextStyle(fontSize: ht - 1))));
      if (email.isNotEmpty)   widgets.add(pw.Center(child: pw.Text(email, style: pw.TextStyle(fontSize: ht - 1))));
      if (settings.showTaxId && taxId.isNotEmpty) widgets.add(pw.Center(child: pw.Text('Tax ID: $taxId', style: pw.TextStyle(fontSize: ht - 1))));
    }
    if (settings.headerNote.isNotEmpty) {
      widgets.add(pw.Center(child: pw.Text(settings.headerNote, style: pw.TextStyle(fontSize: ht - 1))));
    }

    widgets.add(_thermalDivider());
    if (settings.showReceiptNumber) widgets.add(pw.Text('Receipt: ${sale.invoiceNumber}', style: pw.TextStyle(fontSize: ht)));
    if (settings.showDateTime) widgets.add(pw.Text('Date: ${DateFormat('dd/MM/yyyy  HH:mm').format(sale.createdAt)}', style: pw.TextStyle(fontSize: ht)));
    if (settings.showCashierName && (cashierName?.isNotEmpty ?? false)) widgets.add(pw.Text('Cashier: $cashierName', style: pw.TextStyle(fontSize: ht)));
    if (settings.showCustomerInfo && (customerName?.isNotEmpty ?? false)) {
      widgets.add(pw.Text('Customer: $customerName', style: pw.TextStyle(fontSize: ht)));
      if (customerPhone?.isNotEmpty ?? false) widgets.add(pw.Text('Phone: $customerPhone', style: pw.TextStyle(fontSize: ht)));
    }
    if (settings.showTableNumber && (sale.tableNumber?.isNotEmpty ?? false)) {
      widgets.add(pw.Text('Table: ${sale.tableNumber}', style: pw.TextStyle(fontSize: ht)));
    }
    if (settings.showOrderType && sale.orderType.isNotEmpty) {
      widgets.add(pw.Text('Order: ${_capitalize(sale.orderType)}', style: pw.TextStyle(fontSize: ht)));
    }
    if (settings.showDeviceInfo && (sale.deviceInfo?.isNotEmpty ?? false)) {
      widgets.add(pw.Text('Device: ${sale.deviceInfo}', style: pw.TextStyle(fontSize: ht)));
    }

    widgets.add(_thermalDivider());

    // Items header
    widgets.add(
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('ITEM', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: ht)),
        pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: ht)),
      ]),
    );
    widgets.add(_thermalDivider());

    // Items
    for (final item in items) {
      widgets.add(
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Expanded(child: pw.Text(item.productName, style: pw.TextStyle(fontSize: ht))),
          pw.Text(_fmtNum(item.total), style: pw.TextStyle(fontSize: ht)),
        ]),
      );
      widgets.add(pw.Text('  x${item.quantity} @ ${_fmtNum(item.price)}', style: pw.TextStyle(fontSize: ht - 1, color: PdfColors.grey700)));
      if (settings.showVariants && (item.selectedVariant?.isNotEmpty ?? false)) {
        widgets.add(pw.Text('  Variant: ${item.selectedVariant}', style: pw.TextStyle(fontSize: ht - 1)));
      }
      if (settings.showModifiers) {
        for (final mod in item.selectedModifiers) {
          final mp = (mod['price'] as num?)?.toDouble() ?? 0;
          widgets.add(pw.Text('  + ${mod['name']}  +${_fmtNum(mp)}', style: pw.TextStyle(fontSize: ht - 1)));
        }
      }
      if (settings.showItemNotes && (item.notes?.isNotEmpty ?? false)) {
        widgets.add(pw.Text('  Note: ${item.notes}', style: pw.TextStyle(fontSize: ht - 1, color: PdfColors.grey600)));
      }
    }

    widgets.add(_thermalDivider());

    // Totals
    if (settings.showSubtotal) widgets.add(_thermalRow('Subtotal', _fmtNum(subtotal), ht));
    if (settings.showDiscount && discountTotal > 0) widgets.add(_thermalRow('Discount', '-${_fmtNum(discountTotal)}', ht));
    widgets.add(_thermalDivider());
    if (settings.showGrandTotal) {
      widgets.add(_thermalRow('TOTAL', _fmtNum(grandTotal), ht + 1, bold: true));
    }

    // Advance payment block
    if (settings.showAdvanceAmount && sale.advanceAmount > 0) {
      widgets.add(_thermalRow('Advance Paid', _fmtNum(sale.advanceAmount), ht));
      if (settings.showRemainingBal) widgets.add(_thermalRow('Balance Due', _fmtNum(remaining), ht, bold: true));
    }

    if (settings.showPaymentMethod && sale.paymentMethod.isNotEmpty) {
      widgets.add(pw.Text('Payment: ${_capitalize(sale.paymentMethod)}', style: pw.TextStyle(fontSize: ht)));
    }
    if (settings.showAmountPaid && amountPaid > 0) {
      widgets.add(_thermalRow('Amount Paid', _fmtNum(amountPaid), ht));
      if (settings.showChange && change > 0) widgets.add(_thermalRow('Change', _fmtNum(change), ht));
    }

    widgets.add(_thermalDivider());

    // Footer
    if (settings.showReturnPolicy && settings.returnPolicy.isNotEmpty) {
      widgets.add(pw.Center(child: pw.Text(settings.returnPolicy, style: pw.TextStyle(fontSize: ht - 1))));
    }
    if (settings.showWarrantyText && settings.warrantyText.isNotEmpty) {
      widgets.add(pw.Center(child: pw.Text(settings.warrantyText, style: pw.TextStyle(fontSize: ht - 1))));
    }
    if (settings.showSignatureBox) {
      widgets.add(pw.SizedBox(height: 12));
      widgets.add(pw.Text('Customer Signature: ___________', style: pw.TextStyle(fontSize: ht)));
      widgets.add(pw.SizedBox(height: 8));
    }
    if (settings.showThankYouMsg && settings.thankYouMessage.isNotEmpty) {
      widgets.add(pw.SizedBox(height: 4));
      widgets.add(pw.Center(child: pw.Text(settings.thankYouMessage, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: ht))));
    }
    widgets.add(pw.SizedBox(height: 12));

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: widgets);
  }

  // ── PDF : Full page (A4/A5/Letter) ──────────────────────────────────────

  List<pw.Widget> _buildFullPageContent({
    required Sale sale,
    required List<SaleItem> items,
    required ReceiptSettings settings,
    required String shopName,
    required String address,
    required String phone,
    required String email,
    required String taxId,
    String? cashierName,
    String? customerName,
    String? customerPhone,
    required double subtotal,
    required double discountTotal,
    required double grandTotal,
    required double amountPaid,
    required double change,
    required double remaining,
    required double ht,
  }) {
    final widgets = <pw.Widget>[];
    const emerald = PdfColor.fromInt(0xFF059669);

    // ── Header Card ──
    widgets.add(
      pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: emerald,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(shopName, style: pw.TextStyle(fontSize: ht + 6, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            if (address.isNotEmpty) pw.Text(address, style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
            if (phone.isNotEmpty)   pw.Text('Tel: $phone | ${email.isNotEmpty ? email : ''}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
            if (settings.showTaxId && taxId.isNotEmpty) pw.Text('Tax ID: $taxId', style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
          ],
        ),
      ),
    );
    widgets.add(pw.SizedBox(height: 12));

    // ── Receipt type banner (template) ──
    final templateLabel = {
      ReceiptTemplate.advancePayment: 'ADVANCE PAYMENT RECEIPT',
      ReceiptTemplate.finalPayment:   'FINAL PAYMENT RECEIPT',
      ReceiptTemplate.pharmacy:       'PHARMACY RECEIPT',
      ReceiptTemplate.restaurant:     'RESTAURANT BILL',
    }[settings.template];
    if (templateLabel != null) {
      widgets.add(pw.Center(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFD1FAE5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(templateLabel, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: emerald)),
        ),
      ));
      widgets.add(pw.SizedBox(height: 12));
    }

    // ── Transaction meta ──
    final metaRows = <List<String>>[];
    if (settings.showReceiptNumber) metaRows.add(['Receipt #', sale.invoiceNumber]);
    if (settings.showDateTime)      metaRows.add(['Date', DateFormat('dd MMM yyyy  HH:mm').format(sale.createdAt)]);
    if (settings.showCashierName && (cashierName?.isNotEmpty ?? false)) metaRows.add(['Cashier', cashierName!]);
    if (settings.showCustomerInfo && (customerName?.isNotEmpty ?? false)) {
      metaRows.add(['Customer', customerName!]);
      if (customerPhone?.isNotEmpty ?? false) metaRows.add(['Phone', customerPhone!]);
    }
    if (settings.showTableNumber && (sale.tableNumber?.isNotEmpty ?? false)) metaRows.add(['Table', sale.tableNumber!]);
    if (settings.showOrderType && sale.orderType.isNotEmpty) metaRows.add(['Order Type', _capitalize(sale.orderType)]);
    if (settings.showDeviceInfo && (sale.deviceInfo?.isNotEmpty ?? false)) metaRows.add(['Device', sale.deviceInfo!]);

    if (metaRows.isNotEmpty) {
      widgets.add(
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {0: const pw.FlexColumnWidth(1.5), 1: const pw.FlexColumnWidth(3)},
          children: metaRows.map((r) => pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.all(6),
              child: pw.Text(r[0], style: pw.TextStyle(fontSize: ht - 1, color: PdfColors.grey700))),
            pw.Padding(padding: const pw.EdgeInsets.all(6),
              child: pw.Text(r[1], style: pw.TextStyle(fontSize: ht - 1, fontWeight: pw.FontWeight.bold))),
          ])).toList(),
        ),
      );
      widgets.add(pw.SizedBox(height: 14));
    }

    // ── Items table ──
    final headerCols = <String>['#', 'Item'];
    if (settings.showItemSKU)     headerCols.add('SKU');
    headerCols.addAll(['Qty', 'Unit Price']);
    if (settings.showItemDiscount) headerCols.add('Discount');
    headerCols.add('Total');

    final tableData = <List<String>>[];
    for (var idx = 0; idx < items.length; idx++) {
      final item = items[idx];
      final row = <String>['${idx + 1}', item.productName];
      if (settings.showItemSKU) row.add(item.productId.length > 8 ? item.productId.substring(0, 8) : item.productId);
      row.addAll(['${item.quantity}', _fmtNum(item.price)]);
      if (settings.showItemDiscount) row.add(item.discount > 0 ? '-${_fmtNum(item.discount)}' : '-');
      row.add(_fmtNum(item.total));
      tableData.add(row);
    }

    widgets.add(
      pw.TableHelper.fromTextArray(
        headers: headerCols,
        data: tableData,
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: ht, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: emerald),
        cellStyle: pw.TextStyle(fontSize: ht - 1),
        cellAlignments: {for (var i = 0; i < headerCols.length; i++) i: i < 2 ? pw.Alignment.centerLeft : pw.Alignment.centerRight},
        border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      ),
    );
    widgets.add(pw.SizedBox(height: 12));

    // ── Totals block ──
    final totalsRows = <List<String>>[];
    if (settings.showSubtotal)   totalsRows.add(['Subtotal',  _fmtNum(subtotal)]);
    if (settings.showDiscount && discountTotal > 0) totalsRows.add(['Discount', '-${_fmtNum(discountTotal)}']);
    if (settings.showTax)        totalsRows.add(['Tax', 'Rs. 0.00']);
    if (settings.showGrandTotal) totalsRows.add(['GRAND TOTAL', _fmtNum(grandTotal)]);

    if (settings.showAdvanceAmount && sale.advanceAmount > 0) {
      totalsRows.add(['Advance Paid', _fmtNum(sale.advanceAmount)]);
      if (settings.showRemainingBal) totalsRows.add(['Balance Due', _fmtNum(remaining)]);
    }
    if (settings.showPaymentMethod && sale.paymentMethod.isNotEmpty) {
      totalsRows.add(['Payment Method', _capitalize(sale.paymentMethod)]);
    }
    if (settings.showAmountPaid && amountPaid > 0) {
      totalsRows.add(['Amount Paid', _fmtNum(amountPaid)]);
      if (settings.showChange && change > 0) totalsRows.add(['Change', _fmtNum(change)]);
    }

    widgets.add(
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.SizedBox(
          width: 240,
          child: pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {0: const pw.FlexColumnWidth(1.8), 1: const pw.FlexColumnWidth(1)},
            children: totalsRows.asMap().entries.map((e) {
              final isGrand = e.value[0].contains('GRAND') || e.value[0].contains('Balance Due');
              return pw.TableRow(
                decoration: isGrand ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFD1FAE5)) : null,
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(e.value[0], style: pw.TextStyle(fontSize: ht - 1, fontWeight: isGrand ? pw.FontWeight.bold : null, color: isGrand ? emerald : PdfColors.grey800))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(e.value[1], textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: ht - 1, fontWeight: isGrand ? pw.FontWeight.bold : null, color: isGrand ? emerald : PdfColors.black))),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
    widgets.add(pw.SizedBox(height: 16));

    // ── Signature box ──
    if (settings.showSignatureBox) {
      widgets.add(
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Customer Signature', style: pw.TextStyle(fontSize: ht - 1, color: PdfColors.grey600)),
            pw.SizedBox(height: 24),
            pw.Container(width: 140, height: 0.5, color: PdfColors.grey500),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Authorized Signature', style: pw.TextStyle(fontSize: ht - 1, color: PdfColors.grey600)),
            pw.SizedBox(height: 24),
            pw.Container(width: 140, height: 0.5, color: PdfColors.grey500),
          ]),
        ]),
      );
      widgets.add(pw.SizedBox(height: 12));
    }

    // ── Footer texts ──
    if (settings.showReturnPolicy && settings.returnPolicy.isNotEmpty) {
      widgets.add(pw.Text(settings.returnPolicy, style: pw.TextStyle(fontSize: ht - 2, color: PdfColors.grey600)));
    }
    if (settings.showWarrantyText && settings.warrantyText.isNotEmpty) {
      widgets.add(pw.Text(settings.warrantyText, style: pw.TextStyle(fontSize: ht - 2, color: PdfColors.grey600)));
    }
    if (settings.showThankYouMsg && settings.thankYouMessage.isNotEmpty) {
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(pw.Center(
        child: pw.Text(settings.thankYouMessage, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: ht, color: emerald)),
      ));
    }

    return widgets;
  }

  // ── PDF helpers ──────────────────────────────────────────────────────────

  PdfPageFormat _pdfPageFormat(PaperFormat fmt) {
    switch (fmt) {
      case PaperFormat.a4:     return PdfPageFormat.a4;
      case PaperFormat.a5:     return PdfPageFormat.a5;
      case PaperFormat.letter: return PdfPageFormat.letter;
      default:                 return PdfPageFormat.a4;
    }
  }

  double _htmlFontSize(ReceiptFontSize fs) {
    switch (fs) {
      case ReceiptFontSize.small:  return 8.0;
      case ReceiptFontSize.medium: return 10.0;
      case ReceiptFontSize.large:  return 12.0;
    }
  }

  pw.Widget _thermalDivider() => pw.Divider(thickness: 0.5, color: PdfColors.black);

  pw.Widget _thermalRow(String label, String value, double fontSize, {bool bold = false}) {
    final style = pw.TextStyle(fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : null);
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(label, style: style),
      pw.Text(value, style: style),
    ]);
  }

  String _fmtNum(double v) => NumberFormat('#,###.00').format(v);
  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
