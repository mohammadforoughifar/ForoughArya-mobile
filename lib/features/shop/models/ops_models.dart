// ============================================================
//  مدل‌های فاز ۴ «سامانه فروشگاهی» — بیجک، تعمیرات، هزینه‌ها و گزارش‌ها
//  منبع: Inventory.Shared/Dtos/GoodsIssueDtos.cs
//        Inventory.Shared/Dtos/RepairDtos.cs
//        Inventory.Shared/Dtos/OperationDtos.cs (ExpenseDto/ExpenseCategoryDto)
//        Inventory.Shared/Dtos/OperationsReportDtos.cs
//  ⚠️ هیچ فیلدی خارج از سرور اضافه نشده است.
// ============================================================

// ------------------------------------------------------------
//  بیجک (حوالهٔ تحویل کالا) — سند «فقط مقدار»
// ------------------------------------------------------------

/// سطر حواله — نام کالا متن آزاد است و ProductId معمولاً صفر
class GoodsIssueLine {
  GoodsIssueLine({
    this.id = 0,
    this.productId = 0,
    this.productName = '',
    this.quantity = 0,
    this.note,
  });

  int id;
  int productId;
  String productName;
  double quantity;
  String? note;

  factory GoodsIssueLine.fromJson(Map<String, dynamic> j) => GoodsIssueLine(
    id: (j['id'] as num?)?.toInt() ?? 0,
    productId: (j['productId'] as num?)?.toInt() ?? 0,
    productName: (j['productName'] ?? '').toString(),
    quantity: _d(j['quantity']),
    note: _s(j['note']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'productName': productName.trim(),
    'quantity': quantity,
    'note': note,
  };
}

/// حواله تحویل کالا — آینهٔ `GoodsIssueDto`
class GoodsIssue {
  GoodsIssue({
    this.id = 0,
    this.number = '',
    this.date,
    this.partyId = 0,
    this.partyName = '',
    this.description,
    this.lines = const [],
  });

  final int id;
  final String number;
  final DateTime? date;
  final int partyId;
  final String partyName;
  final String? description;
  final List<GoodsIssueLine> lines;

  double get totalQuantity => lines.fold(0, (s, l) => s + l.quantity);
  int get lineCount => lines.length;

  factory GoodsIssue.fromJson(Map<String, dynamic> j) => GoodsIssue(
    id: (j['id'] as num?)?.toInt() ?? 0,
    number: (j['number'] ?? '').toString(),
    date: DateTime.tryParse((j['date'] ?? '').toString())?.toLocal(),
    partyId: (j['partyId'] as num?)?.toInt() ?? 0,
    partyName: (j['partyName'] ?? '').toString(),
    description: _s(j['description']),
    lines: (j['lines'] as List? ?? [])
        .whereType<Map>()
        .map((e) => GoodsIssueLine.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

// ------------------------------------------------------------
//  تعمیرات
// ------------------------------------------------------------

/// وضعیت پذیرش (RepairStatus)
class RepairStatus {
  static const received = 0;
  static const inProgress = 1;
  static const ready = 2;
  static const delivered = 3;
  static const cancelled = 4;

  static String label(int s) => switch (s) {
    received => 'پذیرش شده',
    inProgress => 'در حال تعمیر',
    ready => 'آماده تحویل',
    delivered => 'تحویل شده',
    _ => 'انصراف',
  };
}

/// تعمیرکار — آینهٔ `Technician`
class Technician {
  Technician({
    this.id = 0,
    this.name = '',
    this.phone,
    this.specialty,
    this.isActive = true,
    this.activeRepairs = 0,
  });

  final int id;
  final String name;
  final String? phone;
  final String? specialty;
  final bool isActive;
  final int activeRepairs;

  factory Technician.fromJson(Map<String, dynamic> j) => Technician(
    id: (j['id'] as num?)?.toInt() ?? 0,
    name: (j['name'] ?? '').toString(),
    phone: _s(j['phone']),
    specialty: _s(j['specialty']),
    isActive: j['isActive'] != false,
    activeRepairs: (j['activeRepairs'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name.trim(),
    'phone': phone,
    'specialty': specialty,
    'isActive': isActive,
  };
}

/// یک دستگاه در پذیرش — آینهٔ `RepairDeviceDto`
class RepairDevice {
  RepairDevice({
    this.id = 0,
    this.deviceType = '',
    this.deviceModel,
    this.serialNumber,
    this.problemDescription,
    this.accessories,
    this.quotedPrice = 0,
  });

  final int id;
  final String deviceType;
  final String? deviceModel;
  final String? serialNumber;
  final String? problemDescription;
  final String? accessories;
  final double quotedPrice;

  factory RepairDevice.fromJson(Map<String, dynamic> j) => RepairDevice(
    id: (j['id'] as num?)?.toInt() ?? 0,
    deviceType: (j['deviceType'] ?? '').toString(),
    deviceModel: _s(j['deviceModel']),
    serialNumber: _s(j['serialNumber']),
    problemDescription: _s(j['problemDescription']),
    accessories: _s(j['accessories']),
    quotedPrice: _d(j['quotedPrice']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceType': deviceType.trim(),
    'deviceModel': deviceModel,
    'serialNumber': serialNumber,
    'problemDescription': problemDescription,
    'accessories': accessories,
    'quotedPrice': quotedPrice,
  };
}

/// ردیف کار/قطعه — آینهٔ `RepairItemDto`
class RepairItem {
  RepairItem({
    this.id = 0,
    this.description = '',
    this.productId,
    this.productName,
    this.quantity = 1,
    this.cost = 0,
    this.price = 0,
  });

  final int id;
  final String description;
  final int? productId;
  final String? productName;
  final double quantity;
  final double cost;
  final double price;

  double get rowCost => cost * quantity;
  double get rowPrice => price * quantity;
  double get rowProfit => (price - cost) * quantity;

  factory RepairItem.fromJson(Map<String, dynamic> j) => RepairItem(
    id: (j['id'] as num?)?.toInt() ?? 0,
    description: (j['description'] ?? '').toString(),
    productId: (j['productId'] as num?)?.toInt(),
    productName: _s(j['productName']),
    quantity: _d(j['quantity']),
    cost: _d(j['cost']),
    price: _d(j['price']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description.trim(),
    'productId': (productId ?? 0) > 0 ? productId : null,
    'quantity': quantity,
    'cost': cost,
    'price': price,
  };
}

/// پذیرش تعمیر — آینهٔ `RepairOrderDto`
class RepairOrder {
  RepairOrder({
    this.id = 0,
    this.number = '',
    this.partyId = 0,
    this.partyName,
    this.partyPhone,
    this.partyMobile,
    this.technicianId,
    this.technicianName,
    this.technicianPhone,
    this.status = RepairStatus.received,
    this.receivedAt,
    this.deliveredAt,
    this.quotedPrice = 0,
    this.invoiceTransactionId,
    this.invoiceNumber,
    this.note,
    this.devices = const [],
    this.items = const [],
    this.totalPrice = 0,
    this.totalCost = 0,
    this.profit = 0,
  });

  final int id;
  final String number;
  final int partyId;
  final String? partyName;
  final String? partyPhone;
  final String? partyMobile;
  final int? technicianId;
  final String? technicianName;
  final String? technicianPhone;
  final int status;
  final DateTime? receivedAt;
  final DateTime? deliveredAt;
  final double quotedPrice;
  final int? invoiceTransactionId;
  final String? invoiceNumber;
  final String? note;
  final List<RepairDevice> devices;
  final List<RepairItem> items;
  final double totalPrice;
  final double totalCost;
  final double profit;

  bool get hasInvoice => (invoiceTransactionId ?? 0) > 0;

  /// خلاصهٔ دستگاه‌ها برای فهرست — همان DeviceSummary وب
  String get deviceSummary {
    if (devices.isEmpty) return '—';
    final d = devices.first;
    final label = (d.deviceModel ?? '').trim().isEmpty
        ? d.deviceType
        : '${d.deviceType} ${d.deviceModel}'.trim();
    return devices.length > 1 ? '$label و ${devices.length - 1} دستگاه' : label;
  }

  String get partyTel =>
      (partyMobile ?? '').trim().isNotEmpty ? partyMobile! : (partyPhone ?? '');

  /// همان `RepairOrderDto` که سرور برای ثبت/ویرایش می‌گیرد
  /// (فیلدهای تختِ کارت اول هم برای سازگاری فرستاده می‌شوند — مثل وب)
  Map<String, dynamic> toJson() {
    final primary = devices.isNotEmpty ? devices.first : null;
    return {
      'id': id,
      'partyId': partyId,
      'technicianId': (technicianId ?? 0) > 0 ? technicianId : null,
      'status': status,
      'receivedAt': (receivedAt ?? DateTime.now()).toIso8601String(),
      'note': note,
      'deviceType': primary?.deviceType ?? '',
      'deviceModel': primary?.deviceModel,
      'serialNumber': primary?.serialNumber,
      'problemDescription': primary?.problemDescription,
      'accessories': primary?.accessories,
      'quotedPrice': devices.fold<double>(0, (s, d) => s + d.quotedPrice),
      'devices': devices.map((d) => d.toJson()).toList(),
      'items': items.map((i) => i.toJson()).toList(),
    };
  }

  factory RepairOrder.fromJson(Map<String, dynamic> j) => RepairOrder(
    id: (j['id'] as num?)?.toInt() ?? 0,
    number: (j['number'] ?? '').toString(),
    partyId: (j['partyId'] as num?)?.toInt() ?? 0,
    partyName: _s(j['partyName']),
    partyPhone: _s(j['partyPhone']),
    partyMobile: _s(j['partyMobile']),
    technicianId: (j['technicianId'] as num?)?.toInt(),
    technicianName: _s(j['technicianName']),
    technicianPhone: _s(j['technicianPhone']),
    status: (j['status'] as num?)?.toInt() ?? RepairStatus.received,
    receivedAt: DateTime.tryParse((j['receivedAt'] ?? '').toString())?.toLocal(),
    deliveredAt: DateTime.tryParse(
      (j['deliveredAt'] ?? '').toString(),
    )?.toLocal(),
    quotedPrice: _d(j['quotedPrice']),
    invoiceTransactionId: (j['invoiceTransactionId'] as num?)?.toInt(),
    invoiceNumber: _s(j['invoiceNumber']),
    note: _s(j['note']),
    devices: (j['devices'] as List? ?? [])
        .whereType<Map>()
        .map((e) => RepairDevice.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    items: (j['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => RepairItem.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    totalPrice: _d(j['totalPrice']),
    totalCost: _d(j['totalCost']),
    profit: _d(j['profit']),
  );
}

// ------------------------------------------------------------
//  هزینه‌ها
// ------------------------------------------------------------

/// نوع هزینه — آینهٔ `ExpenseCategoryDto`
class ExpenseCategory {
  ExpenseCategory({
    this.id = 0,
    this.name = '',
    this.isActive = true,
    this.expenseCount = 0,
    this.totalAmount = 0,
  });

  final int id;
  final String name;
  final bool isActive;
  final int expenseCount;
  final double totalAmount;

  factory ExpenseCategory.fromJson(Map<String, dynamic> j) => ExpenseCategory(
    id: (j['id'] as num?)?.toInt() ?? 0,
    name: (j['name'] ?? '').toString(),
    isActive: j['isActive'] != false,
    expenseCount: (j['expenseCount'] as num?)?.toInt() ?? 0,
    totalAmount: _d(j['totalAmount']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name.trim(),
    'isActive': isActive,
  };

  ExpenseCategory copyWith({String? name, bool? isActive}) => ExpenseCategory(
    id: id,
    name: name ?? this.name,
    isActive: isActive ?? this.isActive,
    expenseCount: expenseCount,
    totalAmount: totalAmount,
  );
}

/// سند هزینه — آینهٔ `ExpenseDto`
class ShopExpense {
  ShopExpense({
    this.id = 0,
    this.number = '',
    this.categoryId = 0,
    this.categoryName,
    this.amount = 0,
    this.date,
    this.payType = 0,
    this.trsAccountId,
    this.trsAccountName,
    this.payee,
    this.description,
  });

  final int id;
  final String number;
  final int categoryId;
  final String? categoryName;
  final double amount;
  final DateTime? date;
  final int payType;
  final int? trsAccountId;
  final String? trsAccountName;
  final String? payee;
  final String? description;

  factory ShopExpense.fromJson(Map<String, dynamic> j) => ShopExpense(
    id: (j['id'] as num?)?.toInt() ?? 0,
    number: (j['number'] ?? '').toString(),
    categoryId: (j['categoryId'] as num?)?.toInt() ?? 0,
    categoryName: _s(j['categoryName']),
    amount: _d(j['amount']),
    date: DateTime.tryParse((j['date'] ?? '').toString())?.toLocal(),
    payType: (j['payType'] as num?)?.toInt() ?? 0,
    trsAccountId: (j['trsAccountId'] as num?)?.toInt(),
    trsAccountName: _s(j['trsAccountName']),
    payee: _s(j['payee']),
    description: _s(j['description']),
  );

  /// سرور همان `ExpenseDto` را می‌گیرد (بدون CreatedAt/Number در ایجاد)
  Map<String, dynamic> toJson() => {
    'id': id,
    'categoryId': categoryId,
    'amount': amount,
    'date': (date ?? DateTime.now()).toIso8601String(),
    'payType': payType,
    'trsAccountId': trsAccountId,
    'trsAccountName': trsAccountName,
    'payee': payee,
    'description': description,
  };
}

// ------------------------------------------------------------
//  گزارش‌های عملیات (خرید/فروش/تعمیرات)
// ------------------------------------------------------------

/// یک بازه از روند گزارش خرید/فروش
class OrderReportTrendPoint {
  const OrderReportTrendPoint({
    this.label = '',
    this.documentCount = 0,
    this.amount = 0,
  });

  final String label;
  final int documentCount;
  final double amount;

  factory OrderReportTrendPoint.fromJson(Map<String, dynamic> j) =>
      OrderReportTrendPoint(
        label: (j['label'] ?? '').toString(),
        documentCount: (j['documentCount'] as num?)?.toInt() ?? 0,
        amount: _d(j['amount']),
      );
}

/// تجمیع به تفکیک طرف حساب
class OrderReportPartyRow {
  const OrderReportPartyRow({
    this.partyId = 0,
    this.partyName = '',
    this.documentCount = 0,
    this.totalQuantity = 0,
    this.totalAmount = 0,
  });

  final int partyId;
  final String partyName;
  final int documentCount;
  final double totalQuantity;
  final double totalAmount;

  factory OrderReportPartyRow.fromJson(Map<String, dynamic> j) =>
      OrderReportPartyRow(
        partyId: (j['partyId'] as num?)?.toInt() ?? 0,
        partyName: (j['partyName'] ?? '').toString(),
        documentCount: (j['documentCount'] as num?)?.toInt() ?? 0,
        totalQuantity: _d(j['totalQuantity']),
        totalAmount: _d(j['totalAmount']),
      );
}

/// گزارش تحلیلی خرید/فروش — آینهٔ `OperationsOrderReportDto`
class OrderReport {
  const OrderReport({
    this.documentCount = 0,
    this.lineCount = 0,
    this.totalQuantity = 0,
    this.totalAmount = 0,
    this.averageDocumentAmount = 0,
    this.trend = const [],
    this.topParties = const [],
  });

  final int documentCount;
  final int lineCount;
  final double totalQuantity;
  final double totalAmount;
  final double averageDocumentAmount;
  final List<OrderReportTrendPoint> trend;
  final List<OrderReportPartyRow> topParties;

  factory OrderReport.fromJson(Map<String, dynamic> j) => OrderReport(
    documentCount: (j['documentCount'] as num?)?.toInt() ?? 0,
    lineCount: (j['lineCount'] as num?)?.toInt() ?? 0,
    totalQuantity: _d(j['totalQuantity']),
    totalAmount: _d(j['totalAmount']),
    averageDocumentAmount: _d(j['averageDocumentAmount']),
    trend: (j['trend'] as List? ?? [])
        .whereType<Map>()
        .map((e) => OrderReportTrendPoint.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    topParties: (j['topParties'] as List? ?? [])
        .whereType<Map>()
        .map((e) => OrderReportPartyRow.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

/// نقطهٔ روند داشبورد عملیات
class OpsTrendPoint {
  const OpsTrendPoint({
    this.label = '',
    this.purchase = 0,
    this.sale = 0,
    this.repairRevenue = 0,
    this.repairCost = 0,
    this.repairProfit = 0,
    this.repairPartsCost = 0,
    this.repairLaborCost = 0,
  });

  final String label;
  final double purchase;
  final double sale;
  final double repairRevenue;
  final double repairCost;
  final double repairProfit;
  final double repairPartsCost;
  final double repairLaborCost;

  factory OpsTrendPoint.fromJson(Map<String, dynamic> j) => OpsTrendPoint(
    label: (j['label'] ?? '').toString(),
    purchase: _d(j['purchase']),
    sale: _d(j['sale']),
    repairRevenue: _d(j['repairRevenue']),
    repairCost: _d(j['repairCost']),
    repairProfit: _d(j['repairProfit']),
    repairPartsCost: _d(j['repairPartsCost']),
    repairLaborCost: _d(j['repairLaborCost']),
  );
}

/// رتبهٔ معرف در گزارش فروش
class OpsReferrerRank {
  const OpsReferrerRank({
    this.referrerId = 0,
    this.referrerName = '',
    this.saleCount = 0,
    this.salesAmount = 0,
  });

  final int referrerId;
  final String referrerName;
  final int saleCount;
  final double salesAmount;

  factory OpsReferrerRank.fromJson(Map<String, dynamic> j) => OpsReferrerRank(
    referrerId: (j['referrerId'] as num?)?.toInt() ?? 0,
    referrerName: (j['referrerName'] ?? '').toString(),
    saleCount: (j['saleCount'] as num?)?.toInt() ?? 0,
    salesAmount: _d(j['salesAmount']),
  );
}

/// داشبورد یکپارچهٔ عملیات — آینهٔ `OperationsDashboardDto`
class OpsDashboard {
  const OpsDashboard({
    this.purchaseCount = 0,
    this.purchaseTotal = 0,
    this.saleCount = 0,
    this.saleTotal = 0,
    this.repairRevenue = 0,
    this.repairCost = 0,
    this.repairPartsCost = 0,
    this.repairLaborCost = 0,
    this.repairProfit = 0,
    this.repairCount = 0,
    this.activeRepairCount = 0,
    this.deliveredRepairCount = 0,
    this.cancelledRepairCount = 0,
    this.openRepairCount = 0,
    this.openReceivedCount = 0,
    this.openInProgressCount = 0,
    this.openReadyCount = 0,
    this.openAge0To3DaysCount = 0,
    this.openAge4To7DaysCount = 0,
    this.openAgeOver7DaysCount = 0,
    this.averageRepairTurnaroundDays,
    this.topReferrers = const [],
    this.bestReferrer,
    this.trend = const [],
  });

  final int purchaseCount;
  final double purchaseTotal;
  final int saleCount;
  final double saleTotal;
  final double repairRevenue;
  final double repairCost;
  final double repairPartsCost;
  final double repairLaborCost;
  final double repairProfit;
  final int repairCount;
  final int activeRepairCount;
  final int deliveredRepairCount;
  final int cancelledRepairCount;
  final int openRepairCount;
  final int openReceivedCount;
  final int openInProgressCount;
  final int openReadyCount;
  final int openAge0To3DaysCount;
  final int openAge4To7DaysCount;
  final int openAgeOver7DaysCount;
  final double? averageRepairTurnaroundDays;
  final List<OpsReferrerRank> topReferrers;
  final OpsReferrerRank? bestReferrer;
  final List<OpsTrendPoint> trend;

  /// حاشیهٔ سود تعمیرات (درصد) — همان محاسبهٔ وب
  double get repairMargin =>
      repairRevenue <= 0 ? 0 : (repairProfit / repairRevenue) * 100;

  factory OpsDashboard.fromJson(Map<String, dynamic> j) {
    final best = j['bestReferrer'];
    return OpsDashboard(
      purchaseCount: (j['purchaseCount'] as num?)?.toInt() ?? 0,
      purchaseTotal: _d(j['purchaseTotal']),
      saleCount: (j['saleCount'] as num?)?.toInt() ?? 0,
      saleTotal: _d(j['saleTotal']),
      repairRevenue: _d(j['repairRevenue']),
      repairCost: _d(j['repairCost']),
      repairPartsCost: _d(j['repairPartsCost']),
      repairLaborCost: _d(j['repairLaborCost']),
      repairProfit: _d(j['repairProfit']),
      repairCount: (j['repairCount'] as num?)?.toInt() ?? 0,
      activeRepairCount: (j['activeRepairCount'] as num?)?.toInt() ?? 0,
      deliveredRepairCount: (j['deliveredRepairCount'] as num?)?.toInt() ?? 0,
      cancelledRepairCount: (j['cancelledRepairCount'] as num?)?.toInt() ?? 0,
      openRepairCount: (j['openRepairCount'] as num?)?.toInt() ?? 0,
      openReceivedCount: (j['openReceivedCount'] as num?)?.toInt() ?? 0,
      openInProgressCount: (j['openInProgressCount'] as num?)?.toInt() ?? 0,
      openReadyCount: (j['openReadyCount'] as num?)?.toInt() ?? 0,
      openAge0To3DaysCount: (j['openAge0To3DaysCount'] as num?)?.toInt() ?? 0,
      openAge4To7DaysCount: (j['openAge4To7DaysCount'] as num?)?.toInt() ?? 0,
      openAgeOver7DaysCount:
          (j['openAgeOver7DaysCount'] as num?)?.toInt() ?? 0,
      averageRepairTurnaroundDays:
          (j['averageRepairTurnaroundDays'] as num?)?.toDouble(),
      topReferrers: (j['topReferrers'] as List? ?? [])
          .whereType<Map>()
          .map((e) => OpsReferrerRank.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      bestReferrer: best is Map
          ? OpsReferrerRank.fromJson(Map<String, dynamic>.from(best))
          : null,
      trend: (j['trend'] as List? ?? [])
          .whereType<Map>()
          .map((e) => OpsTrendPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
String? _s(dynamic v) {
  final s = v?.toString();
  return (s == null || s.isEmpty || s == 'null') ? null : s;
}
