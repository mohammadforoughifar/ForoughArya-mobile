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
  const Referrer({required this.id, required this.name, this.companyName});
  final int id;
  final String name;
  final String? companyName;

  String get label =>
      companyName == null || companyName!.trim().isEmpty
      ? name
      : '$name (${companyName!.trim()})';

  factory Referrer.fromJson(Map<String, dynamic> j) => Referrer(
    id: _int(j['id']),
    name: (j['name'] ?? '').toString(),
    companyName: _str(j['companyName']),
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
