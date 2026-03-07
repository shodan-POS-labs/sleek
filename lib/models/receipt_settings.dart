// ReceiptSettings — stored in Firestore under shops/{id}.receiptSettings
//
// Drives both PDF receipts (WiFi/A4+) and ESC/POS thermal prints (Bluetooth 58/80mm).

// ── Enums ──────────────────────────────────────────────────────────────────

enum PrinterType { bluetooth, wifi }

enum PaperFormat {
  mm58,
  mm80,
  a5,
  a4,
  letter;

  String get label {
    switch (this) {
      case PaperFormat.mm58:   return '58 mm (Thermal)';
      case PaperFormat.mm80:   return '80 mm (Thermal)';
      case PaperFormat.a5:     return 'A5';
      case PaperFormat.a4:     return 'A4';
      case PaperFormat.letter: return 'Letter';
    }
  }

  bool get isThermal => this == PaperFormat.mm58 || this == PaperFormat.mm80;

  /// Width in PDF points (72 pt = 1 inch; 1 mm ≈ 2.835 pt)
  double get widthPt {
    switch (this) {
      case PaperFormat.mm58:   return 58  * 2.8346;
      case PaperFormat.mm80:   return 80  * 2.8346;
      case PaperFormat.a5:     return 148 * 2.8346;
      case PaperFormat.a4:     return 595.28;
      case PaperFormat.letter: return 612.0;
    }
  }

  double? get heightPt {
    switch (this) {
      case PaperFormat.mm58:
      case PaperFormat.mm80:   return null; // continuous roll
      case PaperFormat.a5:     return 420 * 2.8346;
      case PaperFormat.a4:     return 841.89;
      case PaperFormat.letter: return 792.0;
    }
  }
}

enum ReceiptFontSize { small, medium, large }

enum ReceiptTemplate {
  standard,
  advancePayment,
  finalPayment,
  pharmacy,
  restaurant;

  String get label {
    switch (this) {
      case ReceiptTemplate.standard:       return 'Standard';
      case ReceiptTemplate.advancePayment: return 'Advance Payment';
      case ReceiptTemplate.finalPayment:   return 'Final Payment';
      case ReceiptTemplate.pharmacy:       return 'Pharmacy';
      case ReceiptTemplate.restaurant:     return 'Restaurant';
    }
  }

  String get description {
    switch (this) {
      case ReceiptTemplate.standard:       return 'General purpose receipt for all business types';
      case ReceiptTemplate.advancePayment: return 'Shows advance received & remaining balance';
      case ReceiptTemplate.finalPayment:   return 'Full payment receipt with balance cleared';
      case ReceiptTemplate.pharmacy:       return 'Includes expiry date, batch & doctor info';
      case ReceiptTemplate.restaurant:     return 'Table number, order type and kitchen notes';
    }
  }
}

// ── Model ──────────────────────────────────────────────────────────────────

class ReceiptSettings {
  // Template
  final ReceiptTemplate template;

  // Printer
  final PrinterType printerType;
  final PaperFormat paperFormat;
  final String bluetoothDeviceAddress; // saved for auto-reconnect
  final String wifiPrinterIp;          // IP address for network printer
  final int    wifiPrinterPort;        // port (default 9100 for RAW)

  // Business info (override shop profile values per-receipt)
  final String businessName;
  final String address;
  final String phone;
  final String email;
  final String taxId;
  final String logoBase64; // empty = no logo

  // Section toggles
  final Map<String, bool> toggles;

  // Custom text
  final String thankYouMessage;
  final String returnPolicy;
  final String warrantyText;
  final String headerNote;

  // Appearance
  final ReceiptFontSize fontSize;

  const ReceiptSettings({
    this.template = ReceiptTemplate.standard,
    this.printerType = PrinterType.bluetooth,
    this.paperFormat = PaperFormat.mm80,
    this.bluetoothDeviceAddress = '',
    this.wifiPrinterIp = '',
    this.wifiPrinterPort = 9100,
    this.businessName = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.taxId = '',
    this.logoBase64 = '',
    Map<String, bool>? toggles,
    this.thankYouMessage = 'Thank you for your purchase!',
    this.returnPolicy = '',
    this.warrantyText = '',
    this.headerNote = '',
    this.fontSize = ReceiptFontSize.medium,
  }) : toggles = toggles ?? const {};

  // ── Toggle helpers ──────────────────────────────────────────

  bool get showLogo            => toggles['showLogo']            ?? false;
  bool get showBusinessInfo    => toggles['showBusinessInfo']    ?? true;
  bool get showTaxId           => toggles['showTaxId']           ?? false;
  bool get showReceiptNumber   => toggles['showReceiptNumber']   ?? true;
  bool get showDateTime        => toggles['showDateTime']        ?? true;
  bool get showCashierName     => toggles['showCashierName']     ?? true;
  bool get showCustomerInfo    => toggles['showCustomerInfo']    ?? false;
  bool get showItemSKU         => toggles['showItemSKU']         ?? false;
  bool get showItemDiscount    => toggles['showItemDiscount']    ?? true;
  bool get showVariants        => toggles['showVariants']        ?? true;
  bool get showModifiers       => toggles['showModifiers']       ?? true;
  bool get showItemNotes       => toggles['showItemNotes']       ?? true;
  bool get showSubtotal        => toggles['showSubtotal']        ?? true;
  bool get showTax             => toggles['showTax']             ?? false;
  bool get showDiscount        => toggles['showDiscount']        ?? true;
  bool get showGrandTotal      => toggles['showGrandTotal']      ?? true;
  bool get showPaymentMethod   => toggles['showPaymentMethod']   ?? true;
  bool get showAmountPaid      => toggles['showAmountPaid']      ?? true;
  bool get showChange          => toggles['showChange']          ?? true;
  bool get showAdvanceAmount   => toggles['showAdvanceAmount']   ?? false;
  bool get showRemainingBal    => toggles['showRemainingBal']    ?? false;
  bool get showDueDate         => toggles['showDueDate']         ?? false;
  bool get showSignatureBox    => toggles['showSignatureBox']    ?? false;
  bool get showReturnPolicy    => toggles['showReturnPolicy']    ?? false;
  bool get showWarrantyText    => toggles['showWarrantyText']    ?? false;
  bool get showThankYouMsg     => toggles['showThankYouMsg']     ?? true;
  bool get showQRCode          => toggles['showQRCode']          ?? false;
  // Business-specific
  bool get showExpiryDate      => toggles['showExpiryDate']      ?? false;
  bool get showBatchNumber     => toggles['showBatchNumber']     ?? false;
  bool get showDoctorName      => toggles['showDoctorName']      ?? false;
  bool get showTableNumber     => toggles['showTableNumber']     ?? false;
  bool get showOrderType       => toggles['showOrderType']       ?? false;
  bool get showDeviceInfo      => toggles['showDeviceInfo']      ?? false;
  bool get showTechnicianName  => toggles['showTechnicianName']  ?? false;

  // ── Default presets per template ───────────────────────────

  static Map<String, bool> defaultTogglesFor(ReceiptTemplate t) {
    final base = <String, bool>{
      'showLogo': false,
      'showBusinessInfo': true,
      'showTaxId': false,
      'showReceiptNumber': true,
      'showDateTime': true,
      'showCashierName': true,
      'showCustomerInfo': false,
      'showItemSKU': false,
      'showItemDiscount': true,
      'showVariants': true,
      'showModifiers': true,
      'showItemNotes': true,
      'showSubtotal': true,
      'showTax': false,
      'showDiscount': true,
      'showGrandTotal': true,
      'showPaymentMethod': true,
      'showAmountPaid': true,
      'showChange': true,
      'showAdvanceAmount': false,
      'showRemainingBal': false,
      'showDueDate': false,
      'showSignatureBox': false,
      'showReturnPolicy': false,
      'showWarrantyText': false,
      'showThankYouMsg': true,
      'showQRCode': false,
      'showExpiryDate': false,
      'showBatchNumber': false,
      'showDoctorName': false,
      'showTableNumber': false,
      'showOrderType': false,
      'showDeviceInfo': false,
      'showTechnicianName': false,
    };
    switch (t) {
      case ReceiptTemplate.advancePayment:
        return {...base, 'showAdvanceAmount': true, 'showRemainingBal': true, 'showDueDate': true, 'showSignatureBox': true, 'showCustomerInfo': true};
      case ReceiptTemplate.finalPayment:
        return {...base, 'showSignatureBox': true, 'showCustomerInfo': true, 'showWarrantyText': true};
      case ReceiptTemplate.pharmacy:
        return {...base, 'showExpiryDate': true, 'showBatchNumber': true, 'showDoctorName': true, 'showCustomerInfo': true, 'showReturnPolicy': true};
      case ReceiptTemplate.restaurant:
        return {...base, 'showTableNumber': true, 'showOrderType': true, 'showModifiers': true, 'showItemNotes': true, 'showThankYouMsg': true};
      case ReceiptTemplate.standard:
        return base;
    }
  }

  // ── Serialisation ───────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    'template': template.name,
    'printerType': printerType.name,
    'paperFormat': paperFormat.name,
    'bluetoothDeviceAddress': bluetoothDeviceAddress,
    'wifiPrinterIp': wifiPrinterIp,
    'wifiPrinterPort': wifiPrinterPort,
    'businessName': businessName,
    'address': address,
    'phone': phone,
    'email': email,
    'taxId': taxId,
    'logoBase64': logoBase64,
    'toggles': toggles,
    'thankYouMessage': thankYouMessage,
    'returnPolicy': returnPolicy,
    'warrantyText': warrantyText,
    'headerNote': headerNote,
    'fontSize': fontSize.name,
  };

  factory ReceiptSettings.fromMap(Map<String, dynamic> m) {
    return ReceiptSettings(
      template: ReceiptTemplate.values.firstWhere(
          (e) => e.name == (m['template'] as String?),
          orElse: () => ReceiptTemplate.standard),
      printerType: PrinterType.values.firstWhere(
          (e) => e.name == (m['printerType'] as String?),
          orElse: () => PrinterType.bluetooth),
      paperFormat: PaperFormat.values.firstWhere(
          (e) => e.name == (m['paperFormat'] as String?),
          orElse: () => PaperFormat.mm80),
      bluetoothDeviceAddress: m['bluetoothDeviceAddress'] as String? ?? '',
      wifiPrinterIp: m['wifiPrinterIp'] as String? ?? '',
      wifiPrinterPort: (m['wifiPrinterPort'] as num?)?.toInt() ?? 9100,
      businessName: m['businessName'] as String? ?? '',
      address: m['address'] as String? ?? '',
      phone: m['phone'] as String? ?? '',
      email: m['email'] as String? ?? '',
      taxId: m['taxId'] as String? ?? '',
      logoBase64: m['logoBase64'] as String? ?? '',
      toggles: (m['toggles'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as bool?) ?? false)) ??
          {},
      thankYouMessage: m['thankYouMessage'] as String? ?? 'Thank you for your purchase!',
      returnPolicy: m['returnPolicy'] as String? ?? '',
      warrantyText: m['warrantyText'] as String? ?? '',
      headerNote: m['headerNote'] as String? ?? '',
      fontSize: ReceiptFontSize.values.firstWhere(
          (e) => e.name == (m['fontSize'] as String?),
          orElse: () => ReceiptFontSize.medium),
    );
  }

  ReceiptSettings copyWith({
    ReceiptTemplate? template,
    PrinterType? printerType,
    PaperFormat? paperFormat,
    String? bluetoothDeviceAddress,
    String? wifiPrinterIp,
    int? wifiPrinterPort,
    String? businessName,
    String? address,
    String? phone,
    String? email,
    String? taxId,
    String? logoBase64,
    Map<String, bool>? toggles,
    String? thankYouMessage,
    String? returnPolicy,
    String? warrantyText,
    String? headerNote,
    ReceiptFontSize? fontSize,
  }) {
    return ReceiptSettings(
      template: template ?? this.template,
      printerType: printerType ?? this.printerType,
      paperFormat: paperFormat ?? this.paperFormat,
      bluetoothDeviceAddress: bluetoothDeviceAddress ?? this.bluetoothDeviceAddress,
      wifiPrinterIp: wifiPrinterIp ?? this.wifiPrinterIp,
      wifiPrinterPort: wifiPrinterPort ?? this.wifiPrinterPort,
      businessName: businessName ?? this.businessName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      taxId: taxId ?? this.taxId,
      logoBase64: logoBase64 ?? this.logoBase64,
      toggles: toggles ?? this.toggles,
      thankYouMessage: thankYouMessage ?? this.thankYouMessage,
      returnPolicy: returnPolicy ?? this.returnPolicy,
      warrantyText: warrantyText ?? this.warrantyText,
      headerNote: headerNote ?? this.headerNote,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}
