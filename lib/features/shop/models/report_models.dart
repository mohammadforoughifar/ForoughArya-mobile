// ============================================================
//  مدل‌های گزارش کاردکس و گزارش‌های عملیاتی فاز ۳ — آینهٔ DTOهای سرور:
//    Inventory.Shared/Dtos/OperationDtos.cs        → KardexRow / ExpenseReportDto
//    Inventory.Shared/Dtos/WarehousingDtos.cs      → InvKardexRow / InvKardexResult
//    Inventory.Shared/Dtos/OperationsReportDtos.cs → ChequeIncomeReportDto
//    Inventory.Shared/Dtos/ShopWarrantyDtos.cs     → ShopWarrantyDto
//    Inventory.Shared/Dtos/SalesVisitReportDtos.cs → VisRequestsReportDto
// ============================================================

import 'dart:math' as math;

import 'ops_models.dart';

double _kd(dynamic v) => v is num ? v.toDouble() : 0;
int _ki(dynamic v) => v is num ? v.toInt() : 0;
String? _ks(dynamic v) {
  final t = v?.toString().trim();
  return (t == null || t.isEmpty || t == 'null') ? null : t;
}

DateTime _kdt(dynamic v) =>
    DateTime.tryParse((v ?? '').toString())?.toLocal() ?? DateTime(2000);

/// یک سطر کاردکس تعدادی — `KardexRow`
class KardexRow {
  KardexRow({
    required this.date,
    this.type = 0,
    this.documentNo = '',
    this.partyName,
    this.description,
    this.inQty = 0,
    this.outQty = 0,
    this.balance = 0,
    this.unitPrice = 0,
    this.inPrice = 0,
    this.inValue = 0,
    this.outPrice = 0,
    this.outValue = 0,
    this.balanceQty = 0,
    this.balanceValue = 0,
  });

  final DateTime date;

  /// `TransactionType`: ۱ خرید · ۲ فروش · غیر آن = اصلاح موجودی
  final int type;
  final String documentNo;
  final String? partyName;
  final String? description;
  final double inQty;
  final double outQty;
  final double balance;
  final double unitPrice;

  // فقط در کاردکس ریالی پر می‌شوند
  final double inPrice;
  final double inValue;
  final double outPrice;
  final double outValue;
  final double balanceQty;
  final double balanceValue;

  /// `BalanceAvg` سرور: ارزش مانده ÷ مقدار مانده
  double get balanceAvg => balanceQty != 0 ? balanceValue / balanceQty : 0;

  String get typeTitle => switch (type) {
    2 => 'فروش',
    1 => 'خرید',
    _ => 'اصلاح موجودی',
  };

  factory KardexRow.fromJson(Map<String, dynamic> j) {
    final qty = _kd(j['balanceQty']);
    final bal = qty != 0 ? qty : _kd(j['balance']);
    return KardexRow(
      date: _kdt(j['date']),
      type: _ki(j['type']),
      documentNo: (j['documentNo'] ?? j['number'] ?? '').toString(),
      partyName: _ks(j['partyName']),
      description: _ks(j['description']),
      inQty: _kd(j['inQty']),
      outQty: _kd(j['outQty']),
      balance: bal,
      unitPrice: _kd(j['unitPrice']),
      inPrice: _kd(j['inPrice']),
      inValue: _kd(j['inValue']),
      outPrice: _kd(j['outPrice']),
      outValue: _kd(j['outValue']),
      balanceQty: qty,
      balanceValue: _kd(j['balanceValue']),
    );
  }
}

/// نتیجهٔ کاردکس تعدادی — همان فهرست سطرها + جمع‌های محاسبه‌شده در کلاینت
class KardexQuantityResult {
  const KardexQuantityResult({
    this.productName = '',
    this.productCode = '',
    this.unit = '',
    this.warehouseName,
    this.rows = const [],
  });

  final String productName;
  final String productCode;
  final String unit;
  final String? warehouseName;
  final List<KardexRow> rows;

  double get totalIn => rows.fold<double>(0, (s, r) => s + r.inQty);
  double get totalOut => rows.fold<double>(0, (s, r) => s + r.outQty);

  /// همان `finalBalance` وب: ماندهٔ آخرین سطر
  double get finalBalance => rows.isEmpty ? 0 : rows.last.balance;
}

/// نتیجهٔ کامل کاردکس ریالی — `InvKardexResult`
class KardexRialResult {
  const KardexRialResult({
    this.productId = 0,
    this.productCode = '',
    this.productName = '',
    this.unit = '',
    this.warehouseName,
    this.methodTitle = '',
    this.openingQty = 0,
    this.openingValue = 0,
    this.rows = const [],
    this.totalInQty = 0,
    this.totalInValue = 0,
    this.totalOutQty = 0,
    this.totalOutValue = 0,
    this.closingQty = 0,
    this.closingValue = 0,
  });

  final int productId;
  final String productCode;
  final String productName;
  final String unit;
  final String? warehouseName;
  final String methodTitle;
  final double openingQty;
  final double openingValue;
  final List<KardexRow> rows;
  final double totalInQty;
  final double totalInValue;
  final double totalOutQty;
  final double totalOutValue;
  final double closingQty;
  final double closingValue;

  factory KardexRialResult.fromJson(Map<String, dynamic> j) => KardexRialResult(
    productId: _ki(j['productId']),
    productCode: (j['productCode'] ?? '').toString(),
    productName: (j['productName'] ?? '').toString(),
    unit: (j['unit'] ?? '').toString(),
    warehouseName: _ks(j['warehouseName']),
    methodTitle: (j['methodTitle'] ?? '').toString(),
    openingQty: _kd(j['openingQty']),
    openingValue: _kd(j['openingValue']),
    rows: (j['rows'] as List? ?? [])
        .whereType<Map>()
        .map((e) => KardexRow.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    totalInQty: _kd(j['totalInQty']),
    totalInValue: _kd(j['totalInValue']),
    totalOutQty: _kd(j['totalOutQty']),
    totalOutValue: _kd(j['totalOutValue']),
    closingQty: _kd(j['closingQty']),
    closingValue: _kd(j['closingValue']),
  );
}

// ============================================================
//  پنل معرف (Referrer Role) — آینهٔ DTOهای سرور:
//    Inventory.Shared/Dtos/AuthDtos.cs      → ReferrerDashboard / ReferrerSaleRow
//    Inventory.Shared/Dtos/OperationDtos.cs → ReferrerProductItem
//    Inventory.Shared/Dtos/CatalogDtos.cs   → ReferrerPayment
//
//  مسیرها: api/my/dashboard · api/my/payments · api/my/products
// ============================================================

/// یک سطر فروش دارای پورسانت — `ReferrerSaleRow`
class ReferrerSaleRow {
  const ReferrerSaleRow({
    this.number = '',
    this.date,
    this.customerName,
    this.amount = 0,
    this.commission = 0,
  });

  final String number;
  final DateTime? date;
  final String? customerName;
  final double amount;
  final double commission;

  factory ReferrerSaleRow.fromJson(Map<String, dynamic> j) => ReferrerSaleRow(
    number: (j['number'] ?? '').toString(),
    date: DateTime.tryParse((j['date'] ?? '').toString())?.toLocal(),
    customerName: _ks(j['customerName']),
    amount: _kd(j['amount']),
    commission: _kd(j['commission']),
  );
}

/// داشبورد معرف — `ReferrerDashboard`
class ReferrerDashboard {
  const ReferrerDashboard({
    this.referrerName = '',
    this.companyName,
    this.phone,
    this.canViewProducts = false,
    this.goodsCommissionPercent = 0,
    this.serviceCommissionPercent = 0,
    this.orderCount = 0,
    this.totalSales = 0,
    this.totalCommission = 0,
    this.totalPaid = 0,
    this.walletBalance = 0,
    this.monthCommission = 0,
    this.recentSales = const [],
    this.recentPayments = const [],
  });

  final String referrerName;
  final String? companyName;
  final String? phone;
  final bool canViewProducts;
  final double goodsCommissionPercent;
  final double serviceCommissionPercent;
  final int orderCount;
  final double totalSales;
  final double totalCommission;
  final double totalPaid;
  final double walletBalance;
  final double monthCommission;
  final List<ReferrerSaleRow> recentSales;
  final List<ReferrerPaymentRow> recentPayments;

  factory ReferrerDashboard.fromJson(Map<String, dynamic> j) =>
      ReferrerDashboard(
        referrerName: (j['referrerName'] ?? '').toString(),
        companyName: _ks(j['companyName']),
        phone: _ks(j['phone']),
        canViewProducts: j['canViewProducts'] == true,
        goodsCommissionPercent: _kd(j['goodsCommissionPercent']),
        serviceCommissionPercent: _kd(j['serviceCommissionPercent']),
        orderCount: _ki(j['orderCount']),
        totalSales: _kd(j['totalSales']),
        totalCommission: _kd(j['totalCommission']),
        totalPaid: _kd(j['totalPaid']),
        walletBalance: _kd(j['walletBalance']),
        monthCommission: _kd(j['monthCommission']),
        recentSales: (j['recentSales'] as List? ?? [])
            .whereType<Map>()
            .map((e) => ReferrerSaleRow.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        recentPayments: (j['recentPayments'] as List? ?? [])
            .whereType<Map>()
            .map(
              (e) => ReferrerPaymentRow.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList(),
      );
}

/// سند پرداخت پورسانت (نمای معرف) — `ReferrerPayment`
class ReferrerPaymentRow {
  const ReferrerPaymentRow({
    this.id = 0,
    this.number = '',
    this.date,
    this.amount = 0,
    this.description,
  });

  final int id;
  final String number;
  final DateTime? date;
  final double amount;
  final String? description;

  factory ReferrerPaymentRow.fromJson(Map<String, dynamic> j) =>
      ReferrerPaymentRow(
        id: _ki(j['id']),
        number: (j['number'] ?? '').toString(),
        date: DateTime.tryParse((j['date'] ?? '').toString())?.toLocal(),
        amount: _kd(j['amount']),
        description: _ks(j['description']),
      );
}

/// کالای موجود در پنل معرف — `ReferrerProductItem`
class ReferrerProductItem {
  const ReferrerProductItem({
    this.name = '',
    this.code = '',
    this.unit = '',
    this.category,
    this.inStock = true,
  });

  final String name;
  final String code;
  final String unit;
  final String? category;
  final bool inStock;

  factory ReferrerProductItem.fromJson(Map<String, dynamic> j) =>
      ReferrerProductItem(
        name: (j['name'] ?? '').toString(),
        code: (j['code'] ?? '').toString(),
        unit: (j['unit'] ?? '').toString(),
        category: _ks(j['category']),
        inStock: j['inStock'] != false,
      );
}

// ============================================================
//  ۱) گزارش تاخیر تادیه چک — `ChequeIncomeReportDto`
//     GET /api/operations/reports/cheque-income?from&to&partyId
// ============================================================

class ChequeIncomeRow {
  const ChequeIncomeRow({
    required this.date,
    this.saleId = 0,
    this.saleNumber = '',
    this.partyId,
    this.partyName = '',
    this.eventId = 0,
    this.voucherNumber = 0,
    this.kind = 0,
    this.income = 0,
  });

  final DateTime date;
  final int saleId;
  final String saleNumber;
  final int? partyId;
  final String partyName;
  final int eventId;
  final int voucherNumber;

  /// `SaleChequeChargeEventKind`: ۱ سود اولیه · ۲ تغییر سررسید · ۳ برگشت کالا · ۴ ابطال
  final int kind;
  final double income;

  String get kindTitle => switch (kind) {
    1 => 'سود اولیه چک فاکتور',
    2 => 'تغییر سررسید',
    3 => 'برگشت کالا',
    4 => 'ابطال فاکتور',
    _ => 'سایر',
  };

  factory ChequeIncomeRow.fromJson(Map<String, dynamic> j) => ChequeIncomeRow(
    date: _kdt(j['date']),
    saleId: _ki(j['saleId']),
    saleNumber: (j['saleNumber'] ?? '').toString(),
    partyId: j['partyId'] == null ? null : _ki(j['partyId']),
    partyName: (j['partyName'] ?? '').toString(),
    eventId: _ki(j['eventId']),
    voucherNumber: _ki(j['voucherNumber']),
    kind: _ki(j['kind']),
    income: _kd(j['income']),
  );
}

class ChequeIncomeReport {
  const ChequeIncomeReport({
    this.from,
    this.to,
    this.totalIncome = 0,
    this.rows = const [],
  });

  final DateTime? from;
  final DateTime? to;
  final double totalIncome;
  final List<ChequeIncomeRow> rows;

  factory ChequeIncomeReport.fromJson(Map<String, dynamic> j) =>
      ChequeIncomeReport(
        from: DateTime.tryParse((j['from'] ?? '').toString())?.toLocal(),
        to: DateTime.tryParse((j['to'] ?? '').toString())?.toLocal(),
        totalIncome: _kd(j['totalIncome']),
        rows: (j['rows'] as List? ?? [])
            .whereType<Map>()
            .map((e) => ChequeIncomeRow.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

// ============================================================
//  ۲) گزارش هزینه‌ها — `ExpenseReportDto`
//     GET /api/expenses/report?categoryId&from&to
// ============================================================

class ExpenseReportCategory {
  const ExpenseReportCategory({
    this.categoryId = 0,
    this.name = '',
    this.count = 0,
    this.amount = 0,
  });

  final int categoryId;
  final String name;
  final int count;
  final double amount;

  factory ExpenseReportCategory.fromJson(Map<String, dynamic> j) =>
      ExpenseReportCategory(
        categoryId: _ki(j['categoryId']),
        name: (j['name'] ?? '').toString(),
        count: _ki(j['count']),
        amount: _kd(j['amount']),
      );
}

class ExpenseReport {
  const ExpenseReport({
    this.count = 0,
    this.totalAmount = 0,
    this.categories = const [],
    this.items = const [],
  });

  final int count;
  final double totalAmount;
  final List<ExpenseReportCategory> categories;
  final List<ShopExpense> items;

  factory ExpenseReport.fromJson(Map<String, dynamic> j) => ExpenseReport(
    count: _ki(j['count']),
    totalAmount: _kd(j['totalAmount']),
    categories: (j['categories'] as List? ?? [])
        .whereType<Map>()
        .map(
          (e) => ExpenseReportCategory.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList(),
    items: (j['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => ShopExpense.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

// ============================================================
//  ۳) گزارش گارانتی — `ShopWarrantyDto`
//     GET /api/shop-warranties/report?from&to
// ============================================================

class ShopWarrantyReportItem {
  const ShopWarrantyReportItem({
    this.id = 0,
    this.description = '',
    this.productId,
    this.productName,
    this.quantity = 1,
    this.unitCost = 0,
    this.customerUnitPrice,
    this.decision = 0,
    this.supplied = false,
    this.performed = true,
  });

  final int id;
  final String description;
  final int? productId;
  final String? productName;
  final double quantity;
  final double unitCost;
  final double? customerUnitPrice;

  /// `WarrantyDecision`: ۰ نامشخص · ۱ پذیرفته · ۲ پذیرفته‌نشده
  final int decision;
  final bool supplied;
  final bool performed;

  bool get isPart => (productId ?? 0) > 0;

  bool get executed => isPart ? supplied : performed;

  bool get isAccepted => decision == 1;

  bool get isRejected => decision == 2;

  bool get isChargeable => isRejected && executed;

  double get internalCost =>
      executed ? (quantity * unitCost).roundToDouble() : 0;

  double get customerAmount => isChargeable && customerUnitPrice != null
      ? (quantity * customerUnitPrice!).roundToDouble()
      : 0;

  factory ShopWarrantyReportItem.fromJson(Map<String, dynamic> j) =>
      ShopWarrantyReportItem(
        id: _ki(j['id']),
        description: (j['description'] ?? '').toString(),
        productId: j['productId'] == null ? null : _ki(j['productId']),
        productName: _ks(j['productName']),
        quantity: _kd(j['quantity']),
        unitCost: _kd(j['unitCost']),
        customerUnitPrice: j['customerUnitPrice'] == null
            ? null
            : _kd(j['customerUnitPrice']),
        decision: _ki(j['decision']),
        supplied: j['supplied'] == true,
        performed: j['performed'] != false,
      );
}

class ShopWarrantyReportRow {
  const ShopWarrantyReportRow({
    this.id = 0,
    this.number = '',
    this.partyId = 0,
    this.partyName = '',
    this.technicianName,
    this.deviceType = '',
    this.deviceModel,
    this.serialNumber,
    this.receivedAt,
    this.finalizedAt,
    this.chargePolicyVersion = 1,
    this.settledAmount = 0,
    this.deviceCount = 1,
    this.items = const [],
  });

  final int id;
  final String number;
  final int partyId;
  final String partyName;
  final String? technicianName;
  final String deviceType;
  final String? deviceModel;
  final String? serialNumber;
  final DateTime? receivedAt;
  final DateTime? finalizedAt;
  final int chargePolicyVersion;
  final double settledAmount;
  final int deviceCount;
  final List<ShopWarrantyReportItem> items;

  double get internalCost =>
      items.fold<double>(0, (s, it) => s + it.internalCost);

  double get customerAmount => finalizedAt != null && chargePolicyVersion == 0
      ? 0
      : items.fold<double>(0, (s, it) => s + it.customerAmount);

  double get unpaidAmount =>
      finalizedAt != null ? math.max(0, customerAmount - settledAmount) : 0;

  String get deviceLabel {
    final base = [
      deviceType.trim(),
      (deviceModel ?? '').trim(),
    ].where((s) => s.isNotEmpty).join(' ');
    if (deviceCount > 1) {
      return '$base و ${deviceCount - 1} دستگاه دیگر';
    }
    return base.isEmpty ? '—' : base;
  }

  factory ShopWarrantyReportRow.fromJson(Map<String, dynamic> j) {
    final devices = j['devices'] as List?;
    return ShopWarrantyReportRow(
      id: _ki(j['id']),
      number: (j['number'] ?? '').toString(),
      partyId: _ki(j['partyId']),
      partyName: (j['partyName'] ?? '').toString(),
      technicianName: _ks(j['technicianName']),
      deviceType: (j['deviceType'] ?? '').toString(),
      deviceModel: _ks(j['deviceModel']),
      serialNumber: _ks(j['serialNumber']),
      receivedAt: DateTime.tryParse(
        (j['receivedAt'] ?? '').toString(),
      )?.toLocal(),
      finalizedAt: DateTime.tryParse(
        (j['finalizedAt'] ?? '').toString(),
      )?.toLocal(),
      chargePolicyVersion: (j['chargePolicyVersion'] as num?)?.toInt() ?? 1,
      settledAmount: _kd(j['settledAmount']),
      deviceCount: devices == null || devices.isEmpty ? 1 : devices.length,
      items: (j['items'] as List? ?? [])
          .whereType<Map>()
          .map(
            (e) =>
                ShopWarrantyReportItem.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
    );
  }
}

// ============================================================
//  ۴) گزارش تجمیع درخواست‌های ویزیتوری — `VisRequestsReportDto`
//     GET /api/sales-visit/requests-report?from&to&includeCanceled
// ============================================================

class VisRequestsReportRow {
  const VisRequestsReportRow({
    this.productId = 0,
    this.productCode = '',
    this.productName = '',
    this.unit,
    this.orderedQty = 0,
    this.orderCount = 0,
    this.stockQty = 0,
    this.amount = 0,
    this.shortageQty = 0,
    this.isService = false,
  });

  final int productId;
  final String productCode;
  final String productName;
  final String? unit;
  final double orderedQty;
  final int orderCount;
  final double stockQty;
  final double amount;
  final double shortageQty;
  final bool isService;

  bool get hasShortage => !isService && shortageQty > 0;

  factory VisRequestsReportRow.fromJson(Map<String, dynamic> j) =>
      VisRequestsReportRow(
        productId: _ki(j['productId']),
        productCode: (j['productCode'] ?? '').toString(),
        productName: (j['productName'] ?? '').toString(),
        unit: _ks(j['unit']),
        orderedQty: _kd(j['orderedQty']),
        orderCount: _ki(j['orderCount']),
        stockQty: _kd(j['stockQty']),
        amount: _kd(j['amount']),
        shortageQty: _kd(j['shortageQty']),
        isService: j['isService'] == true,
      );
}

class VisRequestsGroupRow {
  const VisRequestsGroupRow({
    this.id = 0,
    this.title = '',
    this.orderCount = 0,
    this.lineCount = 0,
    this.productCount = 0,
    this.totalQty = 0,
    this.totalAmount = 0,
    this.totalDiscount = 0,
    this.shortageQty = 0,
  });

  final int id;
  final String title;
  final int orderCount;
  final int lineCount;
  final int productCount;
  final double totalQty;
  final double totalAmount;
  final double totalDiscount;
  final double shortageQty;

  factory VisRequestsGroupRow.fromJson(Map<String, dynamic> j) =>
      VisRequestsGroupRow(
        id: _ki(j['id']),
        title: (j['title'] ?? '').toString(),
        orderCount: _ki(j['orderCount']),
        lineCount: _ki(j['lineCount']),
        productCount: _ki(j['productCount']),
        totalQty: _kd(j['totalQty']),
        totalAmount: _kd(j['totalAmount']),
        totalDiscount: _kd(j['totalDiscount']),
        shortageQty: _kd(j['shortageQty']),
      );
}

class VisRequestsReport {
  const VisRequestsReport({
    this.from,
    this.to,
    this.orderCount = 0,
    this.rows = const [],
    this.totalOrderedQty = 0,
    this.totalShortageQty = 0,
    this.shortageRowCount = 0,
    this.referrerRows = const [],
    this.customerRows = const [],
    this.totalAmount = 0,
    this.totalDiscount = 0,
    this.includesCanceled = false,
    this.scopedToMe = false,
  });

  final DateTime? from;
  final DateTime? to;
  final int orderCount;
  final List<VisRequestsReportRow> rows;
  final double totalOrderedQty;
  final double totalShortageQty;
  final int shortageRowCount;
  final List<VisRequestsGroupRow> referrerRows;
  final List<VisRequestsGroupRow> customerRows;
  final double totalAmount;
  final double totalDiscount;
  final bool includesCanceled;
  final bool scopedToMe;

  int get productCount => rows.length;

  bool get hasData => rows.isNotEmpty;

  String get scopeText => scopedToMe
      ? 'فقط درخواست‌های ثبت‌شده توسط شما'
      : 'همهٔ درخواست‌های شرکت';

  factory VisRequestsReport.fromJson(Map<String, dynamic> j) =>
      VisRequestsReport(
        from: DateTime.tryParse((j['from'] ?? '').toString())?.toLocal(),
        to: DateTime.tryParse((j['to'] ?? '').toString())?.toLocal(),
        orderCount: _ki(j['orderCount']),
        rows: (j['rows'] as List? ?? [])
            .whereType<Map>()
            .map(
              (e) =>
                  VisRequestsReportRow.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList(),
        totalOrderedQty: _kd(j['totalOrderedQty']),
        totalShortageQty: _kd(j['totalShortageQty']),
        shortageRowCount: _ki(j['shortageRowCount']),
        referrerRows: (j['referrerRows'] as List? ?? [])
            .whereType<Map>()
            .map(
              (e) => VisRequestsGroupRow.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList(),
        customerRows: (j['customerRows'] as List? ?? [])
            .whereType<Map>()
            .map(
              (e) => VisRequestsGroupRow.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList(),
        totalAmount: _kd(j['totalAmount']),
        totalDiscount: _kd(j['totalDiscount']),
        includesCanceled: j['includesCanceled'] == true,
        scopedToMe: j['scopedToMe'] == true,
      );
}
