// ============================================================
//  مدل‌های «سامانه فروشگاهی» — آینهٔ دقیق DTOهای سرور
//  منبع: Inventory.Shared/Dtos/CatalogDtos.cs و OperationDtos.cs
//  ⚠️ هیچ فیلدی خارج از سرور اضافه نمی‌شود (تصویر/امتیاز/… نداریم).
// ============================================================

/// نوع طرف حساب (PartyType)
class PartyType {
  static const customer = 0;
  static const supplier = 1;
}

/// یک طرف حساب (مشتری/تأمین‌کننده) — آینهٔ DTO «Party»
class Party {
  Party({
    this.id = 0,
    this.type = PartyType.customer,
    this.name = '',
    this.phone,
    this.mobile,
    this.address,
    this.taxId,
    this.postalCode,
    this.note,
    this.isActive = true,
    this.referrerId,
    this.referrerName,
    this.registeredByName,
    this.registeredByReferrerName,
    this.registeredAt,
    this.balance = 0,
    this.bouncedChequesCount = 0,
    this.bouncedChequesTotal = 0,
    this.overdueInstallmentsCount = 0,
    this.overdueInstallmentsTotal = 0,
  });

  final int id;
  final int type;
  final String name;
  final String? phone;
  final String? mobile;
  final String? address;
  final String? taxId;
  final String? postalCode;
  final String? note;
  final bool isActive;
  final int? referrerId;
  final String? referrerName;
  final String? registeredByName;
  final String? registeredByReferrerName;
  final DateTime? registeredAt;
  final double balance;
  final int bouncedChequesCount;
  final double bouncedChequesTotal;
  final int overdueInstallmentsCount;
  final double overdueInstallmentsTotal;

  bool get hasBouncedCheque => bouncedChequesCount > 0;
  bool get hasOverdueInstallment => overdueInstallmentsCount > 0;

  factory Party.fromJson(Map<String, dynamic> j) => Party(
    id: _int(j['id']),
    type: _int(j['type']),
    name: (j['name'] ?? '').toString(),
    phone: _str(j['phone']),
    mobile: _str(j['mobile']),
    address: _str(j['address']),
    taxId: _str(j['taxId']),
    postalCode: _str(j['postalCode']),
    note: _str(j['note']),
    isActive: j['isActive'] != false,
    referrerId: _intOrNull(j['referrerId']),
    referrerName: _str(j['referrerName']),
    registeredByName: _str(j['registeredByName']),
    registeredByReferrerName: _str(j['registeredByReferrerName']),
    registeredAt: DateTime.tryParse((j['registeredAt'] ?? '').toString())
        ?.toLocal(),
    balance: _dbl(j['balance']),
    bouncedChequesCount: _int(j['bouncedChequesCount']),
    bouncedChequesTotal: _dbl(j['bouncedChequesTotal']),
    overdueInstallmentsCount: _int(j['overdueInstallmentsCount']),
    overdueInstallmentsTotal: _dbl(j['overdueInstallmentsTotal']),
  );

  /// بدنهٔ ارسال به `POST /api/parties` (همان DTO «Party»)
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'name': name.trim(),
    'phone': _nullIfEmpty(phone),
    'mobile': _nullIfEmpty(mobile),
    'address': _nullIfEmpty(address),
    'taxId': _nullIfEmpty(taxId),
    'postalCode': _nullIfEmpty(postalCode),
    'note': _nullIfEmpty(note),
    'isActive': isActive,
    if (referrerId != null) 'referrerId': referrerId,
  };

  Party copyWith({
    int? id,
    int? type,
    String? name,
    String? phone,
    String? mobile,
    String? address,
    String? taxId,
    String? postalCode,
    String? note,
    bool? isActive,
    int? referrerId,
    bool clearReferrer = false,
  }) => Party(
    id: id ?? this.id,
    type: type ?? this.type,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    mobile: mobile ?? this.mobile,
    address: address ?? this.address,
    taxId: taxId ?? this.taxId,
    postalCode: postalCode ?? this.postalCode,
    note: note ?? this.note,
    isActive: isActive ?? this.isActive,
    referrerId: clearReferrer ? null : (referrerId ?? this.referrerId),
    referrerName: referrerName,
    registeredByName: registeredByName,
    registeredByReferrerName: registeredByReferrerName,
    registeredAt: registeredAt,
    balance: balance,
    bouncedChequesCount: bouncedChequesCount,
    bouncedChequesTotal: bouncedChequesTotal,
    overdueInstallmentsCount: overdueInstallmentsCount,
    overdueInstallmentsTotal: overdueInstallmentsTotal,
  );
}

/// یک معرف (بازاریاب) — فقط برای انتخابگر «معرف» در فرم مشتری
/// (فیلد `ReferrerId` در DTO طرف حساب وجود دارد)
class Referrer {
  const Referrer({
    required this.id,
    required this.name,
    this.companyName,
    this.goodsCommissionPercent = 0,
    this.serviceCommissionPercent = 0,
  });
  final int id;
  final String name;
  final String? companyName;

  /// درصد پورسانت فروش کالا — بر مبنای «سود» سطر
  final double goodsCommissionPercent;

  /// درصد پورسانت فروش خدمات — بر مبنای «کل مبلغ» سطر
  final double serviceCommissionPercent;

  String get label =>
      companyName == null || companyName!.trim().isEmpty
      ? name
      : '$name (${companyName!.trim()})';

  factory Referrer.fromJson(Map<String, dynamic> j) => Referrer(
    id: _int(j['id']),
    name: (j['name'] ?? '').toString(),
    companyName: _str(j['companyName']),
    goodsCommissionPercent: _dbl(j['goodsCommissionPercent']),
    serviceCommissionPercent: _dbl(j['serviceCommissionPercent']),
  );
}

/// خلاصهٔ گزارش طلب و بدهی اشخاص (PartyStatementReportDto) — سرفصل صفحهٔ گزارش
class PartyStatementSummary {
  const PartyStatementSummary({
    this.totalReceivable = 0,
    this.totalPayable = 0,
  });
  final double totalReceivable;
  final double totalPayable;

  factory PartyStatementSummary.fromJson(Map<String, dynamic> j) =>
      PartyStatementSummary(
        totalReceivable: _dbl(
          j['totalReceivable'] ?? j['receivable'] ?? j['totalDebit'] ?? 0,
        ),
        totalPayable: _dbl(
          j['totalPayable'] ?? j['payable'] ?? j['totalCredit'] ?? 0,
        ),
      );
}

/// یک ردیف از لیست‌های انتخاب (`LookupItem`) — انبار/کالا/… 
class ShopLookup {
  const ShopLookup({required this.id, required this.name, this.subtitle});
  final int id;
  final String name;
  final String? subtitle;

  factory ShopLookup.fromJson(Map<String, dynamic> j) => ShopLookup(
    id: _int(j['id']),
    name: (j['name'] ?? '').toString(),
    subtitle: _str(j['subtitle'] ?? j['info']),
  );
}

/// نوع ورود اکسل اطلاعات پایه — آینهٔ `ProductImportKind`
class ProductImportKind {
  static const goods = 0;
  static const services = 1;
}

/// کالا / خدمت — آینهٔ DTO «Product» (CatalogDtos.cs)
class Product {
  Product({
    this.id = 0,
    this.code = '',
    this.name = '',
    this.unit = 'عدد',
    this.category,
    this.barcode,
    this.taxCode,
    this.salePrice = 0,
    this.purchasePrice = 0,
    this.invoiceVatValue,
    this.reorderPoint = 0,
    this.maxStock = 0,
    this.description,
    this.isActive = true,
    this.isService = false,
    this.warehouseId,
    this.warehouseName,
    this.createdAt,
    this.totalStock = 0,
    this.avgCost = 0,
  });

  final int id;
  final String code;
  final String name;
  final String unit;
  final String? category;
  final String? barcode;
  final String? taxCode;
  final double salePrice;
  final double purchasePrice;

  /// ارزش افزوده پیش‌فرض فاکتور: تا ۱۰۰ = درصد، بالاتر = مبلغ ریالی
  final double? invoiceVatValue;
  final double reorderPoint;
  final double maxStock;
  final String? description;
  final bool isActive;
  final bool isService;
  final int? warehouseId;
  final String? warehouseName;
  final DateTime? createdAt;
  final double totalStock;
  final double avgCost;

  /// همان قاعدهٔ سرور: ReorderPoint > 0 && TotalStock <= ReorderPoint
  bool get belowReorder => reorderPoint > 0 && totalStock <= reorderPoint;

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: _int(j['id']),
    code: (j['code'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    unit: (j['unit'] ?? 'عدد').toString(),
    category: _str(j['category']),
    barcode: _str(j['barcode']),
    taxCode: _str(j['taxCode']),
    salePrice: _dbl(j['salePrice']),
    purchasePrice: _dbl(j['purchasePrice']),
    invoiceVatValue: (j['invoiceVatValue'] as num?)?.toDouble(),
    reorderPoint: _dbl(j['reorderPoint']),
    maxStock: _dbl(j['maxStock']),
    description: _str(j['description']),
    isActive: j['isActive'] != false,
    isService: j['isService'] == true,
    warehouseId: _intOrNull(j['warehouseId']),
    warehouseName: _str(j['warehouseName']),
    createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal(),
    totalStock: _dbl(j['totalStock']),
    avgCost: _dbl(j['avgCost']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code.trim(),
    'name': name.trim(),
    'unit': unit.trim().isEmpty ? 'عدد' : unit.trim(),
    'category': _nullIfEmpty(category),
    'barcode': _nullIfEmpty(barcode),
    'taxCode': _nullIfEmpty(taxCode),
    'salePrice': salePrice,
    'purchasePrice': purchasePrice,
    'invoiceVatValue': invoiceVatValue,
    'reorderPoint': reorderPoint,
    'maxStock': maxStock,
    'description': _nullIfEmpty(description),
    'isActive': isActive,
    'isService': isService,
    'warehouseId': warehouseId,
  };
}

/// گروه کالا — آینهٔ «ProductCategory»
class ProductCategory {
  ProductCategory({
    this.id = 0,
    this.name = '',
    this.parentId,
    this.description,
    this.isActive = true,
    this.createdAt,
    this.productCount = 0,
    this.depth = 0,
  });

  final int id;
  final String name;
  final int? parentId;
  final String? description;
  final bool isActive;
  final DateTime? createdAt;
  final int productCount;
  final int depth;

  factory ProductCategory.fromJson(Map<String, dynamic> j) => ProductCategory(
    id: _int(j['id']),
    name: (j['name'] ?? '').toString(),
    parentId: _intOrNull(j['parentId']),
    description: _str(j['description']),
    isActive: j['isActive'] != false,
    createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal(),
    productCount: _int(j['productCount']),
    depth: _int(j['depth']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name.trim(),
    'parentId': parentId,
    'description': _nullIfEmpty(description),
    'isActive': isActive,
  };
}

/// واحد شمارش — آینهٔ «MeasureUnit»
class MeasureUnit {
  MeasureUnit({
    this.id = 0,
    this.name = '',
    this.isActive = true,
    this.createdAt,
    this.productCount = 0,
  });

  final int id;
  final String name;
  final bool isActive;
  final DateTime? createdAt;
  final int productCount;

  factory MeasureUnit.fromJson(Map<String, dynamic> j) => MeasureUnit(
    id: _int(j['id']),
    name: (j['name'] ?? '').toString(),
    isActive: j['isActive'] != false,
    createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal(),
    productCount: _int(j['productCount']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name.trim(),
    'isActive': isActive,
  };
}

/// انبار — آینهٔ «Warehouse»
class Warehouse {
  Warehouse({
    this.id = 0,
    this.name = '',
    this.address,
    this.phone,
    this.note,
    this.isActive = true,
    this.itemCount = 0,
  });

  final int id;
  final String name;
  final String? address;
  final String? phone;
  final String? note;
  final bool isActive;
  final int itemCount;

  factory Warehouse.fromJson(Map<String, dynamic> j) => Warehouse(
    id: _int(j['id']),
    name: (j['name'] ?? '').toString(),
    address: _str(j['address']),
    phone: _str(j['phone']),
    note: _str(j['note']),
    isActive: j['isActive'] != false,
    itemCount: _int(j['itemCount']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name.trim(),
    'address': _nullIfEmpty(address),
    'phone': _nullIfEmpty(phone),
    'note': _nullIfEmpty(note),
    'isActive': isActive,
  };
}

/// یک ردیف موجودی انبار — آینهٔ «StockItem»
class StockItem {
  const StockItem({
    required this.warehouseId,
    required this.productId,
    required this.productName,
    required this.productCode,
    required this.unit,
    required this.quantity,
    required this.avgCost,
    required this.lastSalePrice,
    required this.reorderPoint,
    required this.maxStock,
    this.warehouseName,
    this.category,
  });

  final int warehouseId;
  final String? warehouseName;
  final int productId;
  final String productName;
  final String productCode;
  final String unit;
  final double quantity;
  final double avgCost;
  final double lastSalePrice;
  final double reorderPoint;
  final double maxStock;
  final String? category;

  bool get belowReorder => reorderPoint > 0 && quantity <= reorderPoint;

  /// همان محاسبهٔ ستون «ارزش کل موجودی» در وب: تعداد × میانگین خرید
  double get totalValue => quantity * avgCost;

  factory StockItem.fromJson(Map<String, dynamic> j) => StockItem(
    warehouseId: _int(j['warehouseId']),
    warehouseName: _str(j['warehouseName']),
    productId: _int(j['productId']),
    productName: (j['productName'] ?? '').toString(),
    productCode: (j['productCode'] ?? '').toString(),
    unit: (j['unit'] ?? '').toString(),
    quantity: _dbl(j['quantity']),
    avgCost: _dbl(j['avgCost']),
    lastSalePrice: _dbl(j['lastSalePrice']),
    reorderPoint: _dbl(j['reorderPoint']),
    maxStock: _dbl(j['maxStock']),
    category: _str(j['category']),
  );
}

// ---------------- تنظیمات فروشگاه (ShopPrintSettingsDto / ShopVisitorDiscountDto) ----------------

class ShopPrintBank {
  const ShopPrintBank({this.card = '', this.iban = ''});

  final String card;
  final String iban;

  factory ShopPrintBank.fromJson(Map<String, dynamic> j) => ShopPrintBank(
    card: (j['card'] ?? '').toString(),
    iban: (j['iban'] ?? '').toString(),
  );

  Map<String, dynamic> toJson() => {'card': card, 'iban': iban};
}

class ShopPrintSettings {
  const ShopPrintSettings({this.banks = const []});

  final List<ShopPrintBank> banks;

  factory ShopPrintSettings.fromJson(Map<String, dynamic> j) {
    final raw = j['banks'];
    final list = raw is List
        ? raw
              .whereType<Map>()
              .map((e) => ShopPrintBank.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : const <ShopPrintBank>[];
    return ShopPrintSettings(banks: list);
  }

  Map<String, dynamic> toJson() => {
    'banks': banks.map((b) => b.toJson()).toList(),
  };
}

class ShopVisitorDiscount {
  ShopVisitorDiscount({
    required this.companyId,
    required this.userId,
    required this.userName,
    required this.maxDiscountPercent,
  });

  final int companyId;
  final int userId;
  final String userName;
  double maxDiscountPercent;

  factory ShopVisitorDiscount.fromJson(Map<String, dynamic> j) =>
      ShopVisitorDiscount(
        companyId: _int(j['companyId']),
        userId: _int(j['userId']),
        userName: (j['userName'] ?? '').toString(),
        maxDiscountPercent: _dbl(j['maxDiscountPercent']),
      );

  Map<String, dynamic> toJson() => {
    'companyId': companyId,
    'userId': userId,
    'userName': userName,
    'maxDiscountPercent': maxDiscountPercent,
  };
}

/// پروفایل شرکت فعال برای پیش‌نمایش چاپ — آینهٔ `CompanyProfileDto`
class ShopCompanyProfile {
  const ShopCompanyProfile({
    this.id = 0,
    this.name = '',
    this.phone,
    this.address,
    this.logoDataUrl,
  });

  final int id;
  final String name;
  final String? phone;
  final String? address;
  final String? logoDataUrl;

  factory ShopCompanyProfile.fromJson(Map<String, dynamic> j) =>
      ShopCompanyProfile(
        id: _int(j['id']),
        name: (j['name'] ?? '').toString(),
        phone: _str(j['phone']),
        address: _str(j['address']),
        logoDataUrl: _str(j['logoDataUrl']),
      );
}

// ---------------- قیمت‌گذاری و حداقل سود (ShopPricingDtos.cs) ----------------

class ShopPricingPolicy {
  ShopPricingPolicy({
    this.minimumProfitEnabled = false,
    this.minimumMarkupPercent = 0,
    this.updatedAt,
    this.updatedBy,
  });

  bool minimumProfitEnabled;
  double minimumMarkupPercent;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory ShopPricingPolicy.fromJson(Map<String, dynamic> j) =>
      ShopPricingPolicy(
        minimumProfitEnabled: j['minimumProfitEnabled'] == true,
        minimumMarkupPercent: _dbl(j['minimumMarkupPercent']),
        updatedAt: DateTime.tryParse(
          (j['updatedAt'] ?? '').toString(),
        )?.toLocal(),
        updatedBy: _str(j['updatedBy']),
      );

  Map<String, dynamic> toJson() => {
    'minimumProfitEnabled': minimumProfitEnabled,
    'minimumMarkupPercent': minimumMarkupPercent,
  };
}

class ShopPriceAdjustmentRequest {
  const ShopPriceAdjustmentRequest({
    required this.categoryId,
    required this.includeDescendants,
    required this.increase,
    required this.percent,
    required this.effectiveDate,
  });

  final int categoryId;
  final bool includeDescendants;
  final bool increase;
  final double percent;
  final DateTime effectiveDate;

  String get _dateOnly =>
      '${effectiveDate.year.toString().padLeft(4, '0')}-'
      '${effectiveDate.month.toString().padLeft(2, '0')}-'
      '${effectiveDate.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'categoryId': categoryId,
    'includeDescendants': includeDescendants,
    'increase': increase,
    'percent': percent,
    'effectiveDate': _dateOnly,
  };

  bool sameAs(ShopPriceAdjustmentRequest other) =>
      categoryId == other.categoryId &&
      includeDescendants == other.includeDescendants &&
      increase == other.increase &&
      percent == other.percent &&
      _dateOnly == other._dateOnly;
}

class ShopPriceAdjustmentRow {
  const ShopPriceAdjustmentRow({
    required this.productId,
    required this.code,
    required this.name,
    required this.isActive,
    this.previousPrice,
    this.newPrice,
    this.reason,
  });

  final int productId;
  final String code;
  final String name;
  final bool isActive;
  final double? previousPrice;
  final double? newPrice;
  final String? reason;

  factory ShopPriceAdjustmentRow.fromJson(Map<String, dynamic> j) =>
      ShopPriceAdjustmentRow(
        productId: _int(j['productId']),
        code: (j['code'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        isActive: j['isActive'] != false,
        previousPrice: (j['previousPrice'] as num?)?.toDouble(),
        newPrice: (j['newPrice'] as num?)?.toDouble(),
        reason: _str(j['reason']),
      );
}

class ShopPriceAdjustmentPreview {
  const ShopPriceAdjustmentPreview({
    this.rows = const [],
    this.previewHash = '',
  });

  final List<ShopPriceAdjustmentRow> rows;
  final String previewHash;

  int get changeableCount => rows.where((r) => r.newPrice != null).length;

  factory ShopPriceAdjustmentPreview.fromJson(Map<String, dynamic> j) {
    final raw = j['rows'];
    final list = raw is List
        ? raw
              .whereType<Map>()
              .map(
                (e) => ShopPriceAdjustmentRow.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
        : const <ShopPriceAdjustmentRow>[];
    return ShopPriceAdjustmentPreview(
      rows: list,
      previewHash: (j['previewHash'] ?? '').toString(),
    );
  }
}

class ShopPriceHistoryItem {
  const ShopPriceHistoryItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productCode,
    this.effectiveDate,
    required this.price,
    this.previousPrice,
    required this.source,
    this.purchaseTransactionId,
    this.createdAt,
    this.createdBy,
  });

  final int id;
  final int productId;
  final String productName;
  final String productCode;
  final DateTime? effectiveDate;
  final double price;
  final double? previousPrice;
  final String source;
  final int? purchaseTransactionId;
  final DateTime? createdAt;
  final String? createdBy;

  /// همان `SourceTitle` وب در `Pricing.razor`
  String get sourceTitle => switch (source) {
    'baseline' => 'مبنای اولیه',
    'catalog' => 'ویرایش کالا',
    'purchase' =>
      purchaseTransactionId != null
          ? 'فاکتور خرید #$purchaseTransactionId'
          : 'خرید',
    'group' => 'تغییر گروهی',
    _ => source,
  };

  factory ShopPriceHistoryItem.fromJson(Map<String, dynamic> j) =>
      ShopPriceHistoryItem(
        id: _int(j['id']),
        productId: _int(j['productId']),
        productName: (j['productName'] ?? '').toString(),
        productCode: (j['productCode'] ?? '').toString(),
        effectiveDate: DateTime.tryParse(
          (j['effectiveDate'] ?? '').toString(),
        )?.toLocal(),
        price: _dbl(j['price']),
        previousPrice: (j['previousPrice'] as num?)?.toDouble(),
        source: (j['source'] ?? '').toString(),
        purchaseTransactionId: _intOrNull(j['purchaseTransactionId']),
        createdAt: DateTime.tryParse(
          (j['createdAt'] ?? '').toString(),
        )?.toLocal(),
        createdBy: _str(j['createdBy']),
      );
}

// ---------------- کمکی ----------------

int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
int? _intOrNull(dynamic v) => (v as num?)?.toInt();
double _dbl(dynamic v) => (v as num?)?.toDouble() ?? 0;
String? _str(dynamic v) {
  final s = v?.toString();
  return (s == null || s.isEmpty || s == 'null') ? null : s;
}

String? _nullIfEmpty(String? v) =>
    (v == null || v.trim().isEmpty) ? null : v.trim();
