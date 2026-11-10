// ============================================================
//  مدل‌های گزارش کاردکس — آینهٔ DTOهای سرور:
//    Inventory.Shared/Dtos/OperationDtos.cs   → KardexRow
//    Inventory.Shared/Dtos/WarehousingDtos.cs → InvKardexRow / InvKardexResult
//
//  دو گزارش مستقل‌اند:
//   • تعدادی  → GET /api/kardex?productId&warehouseId&from&to
//   • ریالی   → GET /api/inv/reports/kardex?productId&warehouseId&from&to
// ============================================================

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
