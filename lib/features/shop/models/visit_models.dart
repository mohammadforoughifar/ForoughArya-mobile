// ============================================================
//  مدل‌های فاز ۶ — فروش و ویزیتوری (سفارش میدانی) + معرف‌ها
//  آینهٔ DTOهای سرور:
//    Inventory.Shared/Dtos/SalesVisitDtos.cs
//    Inventory.Shared/Dtos/SalesVisitStatus.cs  (VisOrderStatus)
//    Inventory.Shared/Dtos/CatalogDtos.cs        (Referrer / ReferrerPayment)
// ============================================================

String? _s(dynamic v) {
  if (v == null) return null;
  final t = v.toString().trim();
  return t.isEmpty ? null : t;
}

double _d(dynamic v) => v is num ? v.toDouble() : 0;

int _i(dynamic v) => v is num ? v.toInt() : 0;

DateTime? _dt(dynamic v) =>
    DateTime.tryParse((v ?? '').toString())?.toLocal();

/// وضعیت سفارش ویزیتور — آینهٔ `VisOrderStatus`
class VisStatus {
  static const draft = 0;
  static const submitted = 1;
  static const approved = 2;
  static const returned = 3;
  static const rejected = 4;
  static const invoiced = 5;
  static const closed = 6;
  static const canceled = 7;

  static String title(int s) => switch (s) {
    draft => 'پیش‌نویس',
    submitted => 'در انتظار تأیید',
    approved => 'تأییدشده',
    returned => 'برگشتی برای اصلاح',
    rejected => 'رد‌شده',
    invoiced => 'فاکتورشده',
    closed => 'بسته‌شده',
    _ => 'ابطال‌شده',
  };

  /// وب فقط این سه وضعیت را برای ویزیتور قابل ویرایش می‌داند
  static bool canEdit(int s) => s == draft || s == submitted || s == returned;

  /// وب: ابطال در پیش‌نویس/برگشتی/ارسال‌شده
  static bool canCancel(int s) =>
      s == draft || s == returned || s == submitted;
}

/// سطر سفارش ویزیتور — `VisOrderLineDto`
class VisLine {
  VisLine({
    this.id = 0,
    this.productId = 0,
    this.productCode = '',
    this.productName = '',
    this.unit,
    this.quantity = 1,
    this.unitPrice = 0,
    this.discountPercent = 0,
    this.discountAmount = 0,
    this.discountIsAmount = false,
    this.lineTotal = 0,
    this.note,
  });

  int id;
  int productId;
  String productCode;
  String productName;
  String? unit;
  double quantity;
  double unitPrice;
  double discountPercent;
  double discountAmount;
  bool discountIsAmount;
  double lineTotal;
  String? note;

  /// همان `DiscountText` وب
  String get discountText => discountIsAmount
      ? '${discountAmount.toStringAsFixed(0)} ریال'
      : '${discountPercent.toStringAsFixed(discountPercent % 1 == 0 ? 0 : 2)}٪';

  double get gross => quantity * unitPrice;

  /// محاسبهٔ جمع سطر — دقیقاً مثل وب:
  /// ریالی → gross − discountAmount ، درصدی → gross × (1 − p/100)
  double computeTotal() => discountIsAmount
      ? (gross - discountAmount) < 0
            ? 0
            : gross - discountAmount
      : gross * (1 - discountPercent / 100);

  factory VisLine.fromJson(Map<String, dynamic> j) => VisLine(
    id: _i(j['id']),
    productId: _i(j['productId']),
    productCode: (j['productCode'] ?? '').toString(),
    productName: (j['productName'] ?? '').toString(),
    unit: _s(j['unit']),
    quantity: _d(j['quantity']),
    unitPrice: _d(j['unitPrice']),
    discountPercent: _d(j['discountPercent']),
    discountAmount: _d(j['discountAmount']),
    discountIsAmount: j['discountIsAmount'] == true,
    lineTotal: _d(j['lineTotal']),
    note: _s(j['note']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'discountPercent': discountPercent,
    'discountAmount': discountAmount,
    'discountIsAmount': discountIsAmount,
    'note': _s(note),
  };
}

/// یک ردیف گردش سفارش — `VisOrderHistoryDto`
class VisHistory {
  VisHistory({
    this.id = 0,
    this.fromStatus,
    this.toStatus = 0,
    this.userName = '',
    this.at,
    this.comment,
  });

  final int id;
  final int? fromStatus;
  final int toStatus;
  final String userName;
  final DateTime? at;
  final String? comment;

  factory VisHistory.fromJson(Map<String, dynamic> j) => VisHistory(
    id: _i(j['id']),
    fromStatus: j['fromStatus'] == null ? null : _i(j['fromStatus']),
    toStatus: _i(j['toStatus']),
    userName: (j['userName'] ?? '').toString(),
    at: _dt(j['at']),
    comment: _s(j['comment']),
  );
}

/// هشدار کسری موجودی — `VisStockWarning`
class VisStockWarning {
  VisStockWarning({
    this.productId = 0,
    this.productName = '',
    this.required = 0,
    this.available = 0,
  });

  final int productId;
  final String productName;
  final double required;
  final double available;

  double get shortage => required - available;

  factory VisStockWarning.fromJson(Map<String, dynamic> j) => VisStockWarning(
    productId: _i(j['productId']),
    productName: (j['productName'] ?? '').toString(),
    required: _d(j['required']),
    available: _d(j['available']),
  );
}

/// سفارش ویزیتور — `VisOrderDto`
class VisOrder {
  VisOrder({
    this.id = 0,
    this.number = '',
    this.date,
    this.deliveryDate,
    this.finalDeliveryDate,
    this.finalDateSetBy,
    this.referrerId = 0,
    this.referrerName = '',
    this.partyId = 0,
    this.partyName = '',
    this.partyMobile,
    this.warehouseId = 0,
    this.warehouseName = '',
    this.status = 0,
    this.paymentMethod = 0,
    this.totalGross = 0,
    this.totalDiscount = 0,
    this.totalNet = 0,
    this.note,
    this.createdAt,
    this.createdByName = '',
    this.submittedAt,
    this.decidedAt,
    this.decidedBy,
    this.decisionNote,
    this.returnCount = 0,
    this.discountOverLimit = false,
    this.invoiceId,
    this.invoiceNumber,
    this.invoiceStatus,
    this.expiresAt,
    List<VisLine>? lines,
    List<VisHistory>? history,
    List<VisStockWarning>? stockWarnings,
  }) : lines = lines ?? [],
       history = history ?? [],
       stockWarnings = stockWarnings ?? [];

  final int id;
  final String number;
  final DateTime? date;
  final DateTime? deliveryDate;
  final DateTime? finalDeliveryDate;
  final String? finalDateSetBy;
  final int referrerId;
  final String referrerName;
  final int partyId;
  final String partyName;
  final String? partyMobile;
  final int warehouseId;
  final String warehouseName;
  final int status;
  final int paymentMethod;
  final double totalGross;
  final double totalDiscount;
  final double totalNet;
  final String? note;
  final DateTime? createdAt;
  final String createdByName;
  final DateTime? submittedAt;
  final DateTime? decidedAt;
  final String? decidedBy;
  final String? decisionNote;
  final int returnCount;
  final bool discountOverLimit;
  final int? invoiceId;
  final int? invoiceNumber;
  final String? invoiceStatus;
  final DateTime? expiresAt;

  final List<VisLine> lines;
  final List<VisHistory> history;
  final List<VisStockWarning> stockWarnings;

  String get statusTitle => VisStatus.title(status);

  /// همان `EffectiveDeliveryDate` وب
  DateTime? get effectiveDeliveryDate => finalDeliveryDate ?? deliveryDate;

  /// همان `FinalDateChanged` وب
  bool get finalDateChanged =>
      finalDeliveryDate != null &&
      deliveryDate != null &&
      !_sameDay(finalDeliveryDate!, deliveryDate!);

  /// همان `PaymentMethodTitle` وب (بدون «ترکیبی» — ویزیتوری این حالت را ندارد)
  String get paymentMethodTitle => switch (paymentMethod) {
    0 => 'نقدی',
    1 => 'نسیه',
    2 => 'چک',
    3 => 'اقساطی',
    _ => '—',
  };

  int get lineCount => lines.length;

  double get totalQuantity => lines.fold<double>(0, (s, l) => s + l.quantity);

  bool get discountOverLimitFlag => discountOverLimit;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  factory VisOrder.fromJson(Map<String, dynamic> j) => VisOrder(
    id: _i(j['id']),
    number: (j['number'] ?? '').toString(),
    date: _dt(j['date']),
    deliveryDate: _dt(j['deliveryDate']),
    finalDeliveryDate: _dt(j['finalDeliveryDate']),
    finalDateSetBy: _s(j['finalDateSetBy']),
    referrerId: _i(j['referrerId']),
    referrerName: (j['referrerName'] ?? '').toString(),
    partyId: _i(j['partyId']),
    partyName: (j['partyName'] ?? '').toString(),
    partyMobile: _s(j['partyMobile']),
    warehouseId: _i(j['warehouseId']),
    warehouseName: (j['warehouseName'] ?? '').toString(),
    status: _i(j['status']),
    paymentMethod: _i(j['paymentMethod']),
    totalGross: _d(j['totalGross']),
    totalDiscount: _d(j['totalDiscount']),
    totalNet: _d(j['totalNet']),
    note: _s(j['note']),
    createdAt: _dt(j['createdAt']),
    createdByName: (j['createdByName'] ?? '').toString(),
    submittedAt: _dt(j['submittedAt']),
    decidedAt: _dt(j['decidedAt']),
    decidedBy: _s(j['decidedBy']),
    decisionNote: _s(j['decisionNote']),
    returnCount: _i(j['returnCount']),
    discountOverLimit: j['discountOverLimit'] == true,
    invoiceId: j['invoiceId'] == null ? null : _i(j['invoiceId']),
    invoiceNumber: j['invoiceNumber'] == null ? null : _i(j['invoiceNumber']),
    invoiceStatus: _s(j['invoiceStatus']),
    expiresAt: _dt(j['expiresAt']),
    lines: (j['lines'] as List? ?? [])
        .whereType<Map>()
        .map((e) => VisLine.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    history: (j['history'] as List? ?? [])
        .whereType<Map>()
        .map((e) => VisHistory.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    stockWarnings: (j['stockWarnings'] as List? ?? [])
        .whereType<Map>()
        .map((e) => VisStockWarning.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

/// توان‌های کاربر جاری — `VisActorInfo`
class VisActor {
  VisActor({
    this.userId = 0,
    this.userName = '',
    this.referrerId,
    this.referrerName = '',
    this.isAdmin = false,
    this.canCreate = false,
    this.canApprove = false,
    this.canFinance = false,
    this.maxDiscountPercent = 0,
    this.companyId,
    this.companyName = '',
    this.warehouseCount = 0,
    this.productCount = 0,
    this.defaultWarehouseId = 0,
  });

  final int userId;
  final String userName;
  final int? referrerId;
  final String referrerName;
  final bool isAdmin;
  final bool canCreate;
  final bool canApprove;
  final bool canFinance;
  final double maxDiscountPercent;
  final int? companyId;
  final String companyName;
  final int warehouseCount;
  final int productCount;
  final int defaultWarehouseId;

  /// وب: سقف تخفیف فقط برای غیرمدیر اعمال می‌شود
  bool get enforcesDiscountCap =>
      !canApprove && !isAdmin && maxDiscountPercent > 0;

  factory VisActor.fromJson(Map<String, dynamic> j) => VisActor(
    userId: _i(j['userId']),
    userName: (j['userName'] ?? '').toString(),
    referrerId: j['referrerId'] == null ? null : _i(j['referrerId']),
    referrerName: (j['referrerName'] ?? '').toString(),
    isAdmin: j['isAdmin'] == true,
    canCreate: j['canCreate'] == true,
    canApprove: j['canApprove'] == true,
    canFinance: j['canFinance'] == true,
    maxDiscountPercent: _d(j['maxDiscountPercent']),
    companyId: j['companyId'] == null ? null : _i(j['companyId']),
    companyName: (j['companyName'] ?? '').toString(),
    warehouseCount: _i(j['warehouseCount']),
    productCount: _i(j['productCount']),
    defaultWarehouseId: _i(j['defaultWarehouseId']),
  );
}

/// مشتری سبک — `VisCustomerLite`
class VisCustomer {
  VisCustomer({
    this.id = 0,
    this.name = '',
    this.phone,
    this.mobile,
    this.address,
    this.balance = 0,
    this.referrerName,
    this.ownedByMe = false,
  });

  final int id;
  final String name;
  final String? phone;
  final String? mobile;
  final String? address;
  final double balance;
  final String? referrerName;
  final bool ownedByMe;

  factory VisCustomer.fromJson(Map<String, dynamic> j) => VisCustomer(
    id: _i(j['id']),
    name: (j['name'] ?? '').toString(),
    phone: _s(j['phone']),
    mobile: _s(j['mobile']),
    address: _s(j['address']),
    balance: _d(j['balance']),
    referrerName: _s(j['referrerName']),
    ownedByMe: j['ownedByMe'] == true,
  );
}

/// کالای سبک با موجودی همان انبار — `VisProductLite`
class VisProduct {
  VisProduct({
    this.id = 0,
    this.code = '',
    this.name = '',
    this.unit,
    this.salePrice = 0,
    this.stock = 0,
    this.isService = false,
  });

  final int id;
  final String code;
  final String name;
  final String? unit;
  final double salePrice;
  final double stock;
  final bool isService;

  factory VisProduct.fromJson(Map<String, dynamic> j) => VisProduct(
    id: _i(j['id']),
    code: (j['code'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    unit: _s(j['unit']),
    salePrice: _d(j['salePrice']),
    stock: _d(j['stock']),
    isService: j['isService'] == true,
  );
}

/// انبار سبک — `VisWarehouseLite`
class VisWarehouse {
  const VisWarehouse({this.id = 0, this.name = ''});

  final int id;
  final String name;

  factory VisWarehouse.fromJson(Map<String, dynamic> j) =>
      VisWarehouse(id: _i(j['id']), name: (j['name'] ?? '').toString());
}

/// ردیف صف تأیید — `VisApprovalItem`
class VisApprovalItem {
  VisApprovalItem({
    required this.order,
    List<VisStockWarning>? stockWarnings,
    this.creditOverLimit = false,
    this.customerBalance = 0,
    this.creditLimit,
  }) : stockWarnings = stockWarnings ?? [];

  final VisOrder order;
  final List<VisStockWarning> stockWarnings;
  final bool creditOverLimit;
  final double customerBalance;
  final double? creditLimit;

  factory VisApprovalItem.fromJson(Map<String, dynamic> j) => VisApprovalItem(
    order: VisOrder.fromJson(Map<String, dynamic>.from(j['order'] as Map? ?? {})),
    stockWarnings: (j['stockWarnings'] as List? ?? [])
        .whereType<Map>()
        .map((e) => VisStockWarning.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    creditOverLimit: j['creditOverLimit'] == true,
    customerBalance: _d(j['customerBalance']),
    creditLimit: j['creditLimit'] == null ? null : _d(j['creditLimit']),
  );
}

/// آمار کارتابلی — `VisQueueStats`
class VisStats {
  VisStats({
    this.draft = 0,
    this.submitted = 0,
    this.approved = 0,
    this.returned = 0,
    this.invoiced = 0,
    this.rejected = 0,
    this.canceled = 0,
    this.approvedAmount = 0,
    this.invoicedAmount = 0,
    this.commissionEstimate = 0,
  });

  final int draft;
  final int submitted;
  final int approved;
  final int returned;
  final int invoiced;
  final int rejected;
  final int canceled;
  final double approvedAmount;
  final double invoicedAmount;
  final double commissionEstimate;

  factory VisStats.fromJson(Map<String, dynamic> j) => VisStats(
    draft: _i(j['draft']),
    submitted: _i(j['submitted']),
    approved: _i(j['approved']),
    returned: _i(j['returned']),
    invoiced: _i(j['invoiced']),
    rejected: _i(j['rejected']),
    canceled: _i(j['canceled']),
    approvedAmount: _d(j['approvedAmount']),
    invoicedAmount: _d(j['invoicedAmount']),
    commissionEstimate: _d(j['commissionEstimate']),
  );
}

// ------------------------------------------------------------
//  معرف‌ها (کامل، برای صفحهٔ «معرف‌ها» و «کیف پول معرف‌ها»)
// ------------------------------------------------------------

/// معرف کامل — `Referrer` (فیلدهای محاسباتی سرور هم خوانده می‌شوند)
class ShopReferrer {
  ShopReferrer({
    this.id = 0,
    this.name = '',
    this.companyName,
    this.phone,
    this.goodsCommissionPercent = 0,
    this.serviceCommissionPercent = 0,
    this.cardNumber,
    this.iban,
    this.canViewProducts = false,
    this.maxDiscountPercent = 0,
    this.isActive = true,
    this.orderCount = 0,
    this.totalCommission = 0,
    this.totalPaid = 0,
    this.walletBalance = 0,
  });

  final int id;
  final String name;
  final String? companyName;
  final String? phone;
  final double goodsCommissionPercent;
  final double serviceCommissionPercent;
  final String? cardNumber;
  final String? iban;
  final bool canViewProducts;

  /// سقف تخفیف مجاز این ویزیتور (۰ = بدون سقف)
  final double maxDiscountPercent;

  final bool isActive;
  final int orderCount;
  final double totalCommission;
  final double totalPaid;
  final double walletBalance;

  factory ShopReferrer.fromJson(Map<String, dynamic> j) => ShopReferrer(
    id: _i(j['id']),
    name: (j['name'] ?? '').toString(),
    companyName: _s(j['companyName']),
    phone: _s(j['phone']),
    goodsCommissionPercent: _d(j['goodsCommissionPercent']),
    serviceCommissionPercent: _d(j['serviceCommissionPercent']),
    cardNumber: _s(j['cardNumber']),
    iban: _s(j['iban']),
    canViewProducts: j['canViewProducts'] == true,
    maxDiscountPercent: _d(j['maxDiscountPercent']),
    isActive: j['isActive'] != false,
    orderCount: _i(j['orderCount']),
    totalCommission: _d(j['totalCommission']),
    totalPaid: _d(j['totalPaid']),
    walletBalance: _d(j['walletBalance']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name.trim(),
    'companyName': _s(companyName),
    'phone': _s(phone),
    'goodsCommissionPercent': goodsCommissionPercent,
    'serviceCommissionPercent': serviceCommissionPercent,
    'cardNumber': _s(cardNumber),
    'iban': _s(iban),
    'canViewProducts': canViewProducts,
    'maxDiscountPercent': maxDiscountPercent,
    'isActive': isActive,
  };
}

/// سند پرداخت پورسانت — `ReferrerPayment`
class ReferrerPayment {
  ReferrerPayment({
    this.id = 0,
    this.referrerId = 0,
    this.referrerName,
    this.number = '',
    this.amount = 0,
    this.date,
    this.description,
  });

  final int id;
  final int referrerId;
  final String? referrerName;
  final String number;
  final double amount;
  final DateTime? date;
  final String? description;

  factory ReferrerPayment.fromJson(Map<String, dynamic> j) => ReferrerPayment(
    id: _i(j['id']),
    referrerId: _i(j['referrerId']),
    referrerName: _s(j['referrerName']),
    number: (j['number'] ?? '').toString(),
    amount: _d(j['amount']),
    date: _dt(j['date']),
    description: _s(j['description']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'referrerId': referrerId,
    'amount': amount,
    'date': (date ?? DateTime.now()).toIso8601String(),
    'description': _s(description),
  };
}
