// ============================================================
//  مدل‌های فاز ۴ «سامانه فروشگاهی» — بیجک، تعمیرات، گارانتی، طرح تعویض، هزینه‌ها و گزارش‌ها
//  منبع: Inventory.Shared/Dtos/GoodsIssueDtos.cs
//        Inventory.Shared/Dtos/RepairDtos.cs
//        Inventory.Shared/Dtos/ShopWarrantyDtos.cs
//        Inventory.Shared/Dtos/ShopTradeInDtos.cs
//        Inventory.Shared/Dtos/OperationDtos.cs (ExpenseDto/ExpenseCategoryDto)
//        Inventory.Shared/Dtos/OperationsReportDtos.cs
//  ⚠️ هیچ فیلدی خارج از سرور اضافه نشده است.
// ============================================================

import 'dart:math' as math;

import 'shop_models.dart';

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

/// تصمیم گارانتی (`WarrantyDecision`)
class WarrantyDecision {
  static const unspecified = 0;
  static const accepted = 1;
  static const rejected = 2;

  static String label(int d) => switch (d) {
    accepted => 'گارانتی پذیرفته (رایگان)',
    rejected => 'گارانتی پذیرفته‌نشده',
    _ => 'تعمیر عادی',
  };

  static String shortLabel(int d) => switch (d) {
    accepted => 'پذیرفته',
    rejected => 'پذیرفته‌نشده',
    _ => 'تعیین‌نشده',
  };
}

/// وضعیت پیامک پذیرش (`RepairSmsNotificationDto`)
class RepairSmsNotification {
  const RepairSmsNotification({
    this.eventType = 1,
    this.status = 1,
    this.providerMessageId,
    this.providerCode,
    this.providerMessageStatus,
    this.createdAtUtc,
    this.completedAtUtc,
  });

  final int eventType;
  final int status;
  final int? providerMessageId;
  final int? providerCode;
  final int? providerMessageStatus;
  final DateTime? createdAtUtc;
  final DateTime? completedAtUtc;

  String get eventTitle => switch (eventType) {
    1 => 'پیامک ثبت پذیرش',
    2 => 'پیامک آمادهٔ تحویل',
    3 => 'پیامک تحویل نهایی',
    _ => 'پیامک اطلاع‌رسانی',
  };

  bool get isSuccess => status == 3 || status == 4;
  bool get isFailure =>
      status == 5 ||
      status == 7 ||
      status == 8 ||
      status == 9 ||
      status == 10 ||
      status == 11 ||
      status == 12 ||
      status == 13 ||
      status == 14;

  String get statusTitle => switch (status) {
    1 => 'در صف ارسال',
    2 => 'در حال ارسال',
    3 => 'تحویل به اپراتور',
    4 => 'تحویل به گوشی مشتری',
    5 => 'ارسال ناموفق',
    6 => 'وضعیت نامشخص',
    7 => 'شماره موبایل نامعتبر',
    8 => 'سرویس پیامک غیرفعال',
    9 => 'تنظیم‌نشده',
    10 => 'لغوشده',
    11 => 'ماژول غیرفعال',
    12 => 'نام شرکت نامعتبر',
    13 => 'شماره پذیرش نامعتبر',
    14 => 'نام مشتری نامعتبر',
    _ => 'نامشخص',
  };

  factory RepairSmsNotification.fromJson(Map<String, dynamic> j) =>
      RepairSmsNotification(
        eventType: (j['eventType'] as num?)?.toInt() ?? 1,
        status: (j['status'] as num?)?.toInt() ?? 1,
        providerMessageId: (j['providerMessageId'] as num?)?.toInt(),
        providerCode: (j['providerCode'] as num?)?.toInt(),
        providerMessageStatus: (j['providerMessageStatus'] as num?)?.toInt(),
        createdAtUtc: DateTime.tryParse(
          (j['createdAtUtc'] ?? '').toString(),
        )?.toLocal(),
        completedAtUtc: DateTime.tryParse(
          (j['completedAtUtc'] ?? '').toString(),
        )?.toLocal(),
      );
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
    this.warrantyDecision = WarrantyDecision.unspecified,
    this.warrantySupplied = true,
    this.warrantyPerformed = true,
    this.productIsService = false,
  });

  final int id;
  final String description;
  final int? productId;
  final String? productName;
  final double quantity;
  final double cost;
  final double price;
  final int warrantyDecision;
  final bool warrantySupplied;
  final bool warrantyPerformed;
  final bool productIsService;

  bool get isUnusedWarrantyPart =>
      warrantyDecision != WarrantyDecision.unspecified &&
      (productId ?? 0) > 0 &&
      !productIsService &&
      !warrantySupplied;

  bool get isUnperformedWarrantyWork =>
      warrantyDecision != WarrantyDecision.unspecified &&
      ((productId ?? 0) <= 0 || productIsService) &&
      !warrantyPerformed;

  double get customerUnitPrice =>
      warrantyDecision == WarrantyDecision.accepted ||
          isUnusedWarrantyPart ||
          isUnperformedWarrantyWork
      ? 0
      : price;

  double get effectiveUnitCost =>
      isUnusedWarrantyPart || isUnperformedWarrantyWork ? 0 : cost;

  double get rowCost => effectiveUnitCost * quantity;
  double get rowPrice => customerUnitPrice * quantity;
  double get rowProfit => (customerUnitPrice - effectiveUnitCost) * quantity;

  factory RepairItem.fromJson(Map<String, dynamic> j) => RepairItem(
    id: (j['id'] as num?)?.toInt() ?? 0,
    description: (j['description'] ?? '').toString(),
    productId: (j['productId'] as num?)?.toInt(),
    productName: _s(j['productName']),
    quantity: _d(j['quantity']),
    cost: _d(j['cost']),
    price: _d(j['price']),
    warrantyDecision:
        (j['warrantyDecision'] as num?)?.toInt() ??
        WarrantyDecision.unspecified,
    warrantySupplied: j['warrantySupplied'] != false,
    warrantyPerformed: j['warrantyPerformed'] != false,
    productIsService: j['productIsService'] == true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description.trim(),
    'productId': (productId ?? 0) > 0 ? productId : null,
    'quantity': quantity,
    'cost': cost,
    'price': price,
    'warrantyDecision': warrantyDecision,
    'warrantySupplied': warrantySupplied,
    'warrantyPerformed': warrantyPerformed,
    'productIsService': productIsService,
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
    this.warrantyProcessed = false,
    this.warrantyStockTransactionId,
    this.note,
    this.devices = const [],
    this.items = const [],
    this.smsNotifications = const [],
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
  final bool warrantyProcessed;
  final int? warrantyStockTransactionId;
  final String? note;
  final List<RepairDevice> devices;
  final List<RepairItem> items;
  final List<RepairSmsNotification> smsNotifications;
  final double totalPrice;
  final double totalCost;
  final double profit;

  bool get hasInvoice => (invoiceTransactionId ?? 0) > 0;

  bool get hasWarrantyRows =>
      items.any((i) => i.warrantyDecision != WarrantyDecision.unspecified);

  bool get isFreeWarranty => hasWarrantyRows && totalPrice <= 0;

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
    warrantyProcessed: j['warrantyProcessed'] == true,
    warrantyStockTransactionId: (j['warrantyStockTransactionId'] as num?)
        ?.toInt(),
    note: _s(j['note']),
    devices: (j['devices'] as List? ?? [])
        .whereType<Map>()
        .map((e) => RepairDevice.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    items: (j['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => RepairItem.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    smsNotifications: (j['smsNotifications'] as List? ?? [])
        .whereType<Map>()
        .map(
          (e) => RepairSmsNotification.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList(),
    totalPrice: _d(j['totalPrice']),
    totalCost: _d(j['totalCost']),
    profit: _d(j['profit']),
  );
}

// ------------------------------------------------------------
//  گارانتی فروشگاهی (`ShopWarrantyDto`)
// ------------------------------------------------------------

class ShopWarrantyDevice {
  ShopWarrantyDevice({
    this.id = 0,
    this.deviceType = '',
    this.deviceModel,
    this.serialNumber,
    this.problemDescription,
    this.accessories,
  });

  int id;
  String deviceType;
  String? deviceModel;
  String? serialNumber;
  String? problemDescription;
  String? accessories;

  String get label => (deviceModel ?? '').trim().isEmpty
      ? (deviceType.trim().isEmpty ? 'دستگاه' : deviceType.trim())
      : '${deviceType.trim()} ${deviceModel!.trim()}'.trim();

  factory ShopWarrantyDevice.fromJson(Map<String, dynamic> j) =>
      ShopWarrantyDevice(
        id: (j['id'] as num?)?.toInt() ?? 0,
        deviceType: (j['deviceType'] ?? '').toString(),
        deviceModel: _s(j['deviceModel']),
        serialNumber: _s(j['serialNumber']),
        problemDescription: _s(j['problemDescription']),
        accessories: _s(j['accessories']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceType': deviceType.trim(),
    'deviceModel': deviceModel,
    'serialNumber': serialNumber,
    'problemDescription': problemDescription,
    'accessories': accessories,
  };
}

class ShopWarrantyItem {
  ShopWarrantyItem({
    this.id = 0,
    this.description = '',
    this.productId,
    this.productName,
    this.quantity = 1,
    this.unitCost = 0,
    this.customerUnitPrice,
    this.decision = WarrantyDecision.unspecified,
    this.supplied = false,
    this.performed = true,
  });

  int id;
  String description;
  int? productId;
  String? productName;
  double quantity;
  double unitCost;
  double? customerUnitPrice;
  int decision;
  bool supplied;
  bool performed;

  bool get isPart => (productId ?? 0) > 0;
  bool get isDone => isPart ? supplied : performed;
  bool get isChargeable => decision == WarrantyDecision.rejected && isDone;

  double get customerAmount =>
      isChargeable && customerUnitPrice != null && customerUnitPrice! > 0
      ? (quantity * customerUnitPrice!).roundToDouble()
      : 0;

  factory ShopWarrantyItem.fromJson(Map<String, dynamic> j) => ShopWarrantyItem(
    id: (j['id'] as num?)?.toInt() ?? 0,
    description: (j['description'] ?? '').toString(),
    productId: (j['productId'] as num?)?.toInt(),
    productName: _s(j['productName']),
    quantity: _d(j['quantity'] ?? 1),
    unitCost: _d(j['unitCost']),
    customerUnitPrice: j['customerUnitPrice'] == null
        ? null
        : _d(j['customerUnitPrice']),
    decision:
        (j['decision'] as num?)?.toInt() ?? WarrantyDecision.unspecified,
    supplied: j['supplied'] == true,
    performed: j['performed'] != false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description.trim(),
    'productId': isPart ? productId : null,
    'quantity': quantity,
    'unitCost': unitCost,
    'customerUnitPrice': customerUnitPrice,
    'decision': decision,
    'supplied': supplied,
    'performed': performed,
  };
}

class ShopWarrantyLookups {
  const ShopWarrantyLookups({
    this.customers = const [],
    this.products = const [],
    this.warehouses = const [],
    this.technicians = const [],
  });

  final List<ShopLookup> customers;
  final List<ShopLookup> products;
  final List<ShopLookup> warehouses;
  final List<ShopLookup> technicians;

  factory ShopWarrantyLookups.fromJson(Map<String, dynamic> j) {
    List<ShopLookup> listOf(String k) => (j[k] as List? ?? [])
        .whereType<Map>()
        .map((e) => ShopLookup.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return ShopWarrantyLookups(
      customers: listOf('customers'),
      products: listOf('products'),
      warehouses: listOf('warehouses'),
      technicians: listOf('technicians'),
    );
  }
}

class ShopWarranty {
  ShopWarranty({
    this.id = 0,
    this.operationId = '',
    this.number = '',
    this.partyId = 0,
    this.partyName = '',
    this.technicianId,
    this.technicianName,
    this.warehouseId = 0,
    this.deviceType = '',
    this.deviceModel,
    this.serialNumber,
    this.problemDescription,
    this.accessories,
    this.note,
    this.receivedAt,
    this.finalizedAt,
    this.stockTransactionId,
    this.chargePolicyVersion = 1,
    this.chargeTransactionId,
    this.chargeTransactionNumber,
    this.settledAmount = 0,
    this.devices = const [],
    this.items = const [],
  });

  final int id;
  final String operationId;
  final String number;
  final int partyId;
  final String partyName;
  final int? technicianId;
  final String? technicianName;
  final int warehouseId;
  final String deviceType;
  final String? deviceModel;
  final String? serialNumber;
  final String? problemDescription;
  final String? accessories;
  final String? note;
  final DateTime? receivedAt;
  final DateTime? finalizedAt;
  final int? stockTransactionId;
  final int chargePolicyVersion;
  final int? chargeTransactionId;
  final String? chargeTransactionNumber;
  final double settledAmount;
  final List<ShopWarrantyDevice> devices;
  final List<ShopWarrantyItem> items;

  bool get isFinalized => finalizedAt != null;
  bool get hasCharge => (chargeTransactionId ?? 0) > 0;

  List<ShopWarrantyDevice> get effectiveDevices => devices.isNotEmpty
      ? devices
      : [
          ShopWarrantyDevice(
            deviceType: deviceType,
            deviceModel: deviceModel,
            serialNumber: serialNumber,
            problemDescription: problemDescription,
            accessories: accessories,
          ),
        ];

  String get deviceSummary {
    final list = effectiveDevices;
    if (list.isEmpty) return '—';
    final first = list.first.label;
    return list.length > 1 ? '$first و ${list.length - 1} دستگاه' : first;
  }

  int get acceptedCount =>
      items.where((i) => i.decision == WarrantyDecision.accepted).length;
  int get rejectedCount =>
      items.where((i) => i.decision == WarrantyDecision.rejected).length;

  double get internalCost => items
      .where((i) => i.isDone)
      .fold<double>(0, (s, i) => s + (i.quantity * i.unitCost).roundToDouble());

  double get customerAmount => isFinalized && chargePolicyVersion == 0
      ? 0
      : items.fold<double>(0, (s, i) => s + i.customerAmount);

  double get unpaidAmount =>
      isFinalized ? math.max(0, customerAmount - settledAmount) : 0;

  factory ShopWarranty.fromJson(Map<String, dynamic> j) => ShopWarranty(
    id: (j['id'] as num?)?.toInt() ?? 0,
    operationId: (j['operationId'] ?? '').toString(),
    number: (j['number'] ?? '').toString(),
    partyId: (j['partyId'] as num?)?.toInt() ?? 0,
    partyName: (j['partyName'] ?? '').toString(),
    technicianId: (j['technicianId'] as num?)?.toInt(),
    technicianName: _s(j['technicianName']),
    warehouseId: (j['warehouseId'] as num?)?.toInt() ?? 0,
    deviceType: (j['deviceType'] ?? '').toString(),
    deviceModel: _s(j['deviceModel']),
    serialNumber: _s(j['serialNumber']),
    problemDescription: _s(j['problemDescription']),
    accessories: _s(j['accessories']),
    note: _s(j['note']),
    receivedAt: DateTime.tryParse((j['receivedAt'] ?? '').toString())?.toLocal(),
    finalizedAt: DateTime.tryParse(
      (j['finalizedAt'] ?? '').toString(),
    )?.toLocal(),
    stockTransactionId: (j['stockTransactionId'] as num?)?.toInt(),
    chargePolicyVersion: (j['chargePolicyVersion'] as num?)?.toInt() ?? 1,
    chargeTransactionId: (j['chargeTransactionId'] as num?)?.toInt(),
    chargeTransactionNumber: _s(j['chargeTransactionNumber']),
    settledAmount: _d(j['settledAmount']),
    devices: (j['devices'] as List? ?? [])
        .whereType<Map>()
        .map((e) => ShopWarrantyDevice.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    items: (j['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => ShopWarrantyItem.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );

  Map<String, dynamic> toJson() {
    final first = effectiveDevices.isNotEmpty ? effectiveDevices.first : null;
    return {
      'id': id,
      'operationId': operationId,
      'number': number,
      'partyId': partyId,
      'technicianId': (technicianId ?? 0) > 0 ? technicianId : null,
      'warehouseId': warehouseId,
      'deviceType': first?.deviceType.trim() ?? '',
      'deviceModel': first?.deviceModel,
      'serialNumber': first?.serialNumber,
      'problemDescription': first?.problemDescription,
      'accessories': first?.accessories,
      'note': note,
      'receivedAt': (receivedAt ?? DateTime.now()).toIso8601String(),
      'devices': devices.map((d) => d.toJson()).toList(),
      'items': items.map((i) => i.toJson()).toList(),
    };
  }
}

// ------------------------------------------------------------
//  طرح تعویض کالای کارکرده (`ShopTradeInDto`)
// ------------------------------------------------------------

class TradeInUseKind {
  static const applyToSale = 1;
  static const refund = 2;
}

class ShopTradeInUse {
  const ShopTradeInUse({
    this.id = 0,
    this.kind = TradeInUseKind.applyToSale,
    this.targetSaleId,
    this.targetSaleNumber,
    this.trsAccountName,
    this.amount = 0,
    this.date,
    this.createdBy,
  });

  final int id;
  final int kind;
  final int? targetSaleId;
  final String? targetSaleNumber;
  final String? trsAccountName;
  final double amount;
  final DateTime? date;
  final String? createdBy;

  String get kindLabel =>
      kind == TradeInUseKind.applyToSale ? 'تسویه فاکتور فروش' : 'پرداخت وجه';

  String get destinationLabel =>
      targetSaleNumber ?? trsAccountName ?? '—';

  factory ShopTradeInUse.fromJson(Map<String, dynamic> j) => ShopTradeInUse(
    id: (j['id'] as num?)?.toInt() ?? 0,
    kind: (j['kind'] as num?)?.toInt() ?? TradeInUseKind.applyToSale,
    targetSaleId: (j['targetSaleId'] as num?)?.toInt(),
    targetSaleNumber: _s(j['targetSaleNumber']),
    trsAccountName: _s(j['trsAccountName']),
    amount: _d(j['amount']),
    date: DateTime.tryParse((j['date'] ?? '').toString())?.toLocal(),
    createdBy: _s(j['createdBy']),
  );
}

class ShopTradeInTargetSale {
  const ShopTradeInTargetSale({
    this.id = 0,
    this.number = '',
    this.date,
    this.totalAmount = 0,
  });

  final int id;
  final String number;
  final DateTime? date;
  final double totalAmount;

  factory ShopTradeInTargetSale.fromJson(Map<String, dynamic> j) =>
      ShopTradeInTargetSale(
        id: (j['id'] as num?)?.toInt() ?? 0,
        number: (j['number'] ?? '').toString(),
        date: DateTime.tryParse((j['date'] ?? '').toString())?.toLocal(),
        totalAmount: _d(j['totalAmount']),
      );
}

class ShopTradeIn {
  const ShopTradeIn({
    this.id = 0,
    this.operationId = '',
    this.number = '',
    this.partyId = 0,
    this.partyName = '',
    this.deviceType = '',
    this.deviceModel,
    this.serialNumber,
    this.note,
    this.value = 0,
    this.receivedAt,
    this.finalizedAt,
    this.usedAmount = 0,
    this.uses = const [],
  });

  final int id;
  final String operationId;
  final String number;
  final int partyId;
  final String partyName;
  final String deviceType;
  final String? deviceModel;
  final String? serialNumber;
  final String? note;
  final double value;
  final DateTime? receivedAt;
  final DateTime? finalizedAt;
  final double usedAmount;
  final List<ShopTradeInUse> uses;

  bool get isFinalized => finalizedAt != null;
  double get availableCredit =>
      isFinalized ? math.max(0, value - usedAmount) : 0;

  String get deviceLabel => (deviceModel ?? '').trim().isEmpty
      ? deviceType
      : '$deviceType ${deviceModel!.trim()}'.trim();

  factory ShopTradeIn.fromJson(Map<String, dynamic> j) => ShopTradeIn(
    id: (j['id'] as num?)?.toInt() ?? 0,
    operationId: (j['operationId'] ?? '').toString(),
    number: (j['number'] ?? '').toString(),
    partyId: (j['partyId'] as num?)?.toInt() ?? 0,
    partyName: (j['partyName'] ?? '').toString(),
    deviceType: (j['deviceType'] ?? '').toString(),
    deviceModel: _s(j['deviceModel']),
    serialNumber: _s(j['serialNumber']),
    note: _s(j['note']),
    value: _d(j['value']),
    receivedAt: DateTime.tryParse((j['receivedAt'] ?? '').toString())?.toLocal(),
    finalizedAt: DateTime.tryParse(
      (j['finalizedAt'] ?? '').toString(),
    )?.toLocal(),
    usedAmount: _d(j['usedAmount']),
    uses: (j['uses'] as List? ?? [])
        .whereType<Map>()
        .map((e) => ShopTradeInUse.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'operationId': operationId,
    'number': number,
    'partyId': partyId,
    'deviceType': deviceType.trim(),
    'deviceModel': deviceModel,
    'serialNumber': serialNumber,
    'note': note,
    'value': value,
    'receivedAt': (receivedAt ?? DateTime.now()).toIso8601String(),
  };
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
    this.goodsAmount = 0,
    this.chequeIncomeAmount = 0,
    this.totalAmount = 0,
    this.averageDocumentAmount = 0,
    this.trend = const [],
    this.topParties = const [],
  });

  final int documentCount;
  final int lineCount;
  final double totalQuantity;
  final double goodsAmount;
  final double chequeIncomeAmount;
  final double totalAmount;
  final double averageDocumentAmount;
  final List<OrderReportTrendPoint> trend;
  final List<OrderReportPartyRow> topParties;

  factory OrderReport.fromJson(Map<String, dynamic> j) => OrderReport(
    documentCount: (j['documentCount'] as num?)?.toInt() ?? 0,
    lineCount: (j['lineCount'] as num?)?.toInt() ?? 0,
    totalQuantity: _d(j['totalQuantity']),
    goodsAmount: _d(j['goodsAmount']),
    chequeIncomeAmount: _d(j['chequeIncomeAmount']),
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
