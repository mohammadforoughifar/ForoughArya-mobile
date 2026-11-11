// ============================================================
//  مدل‌های اسناد خرید/فروش (فاز ۳) — آینهٔ DTOهای سرور
//  منبع: Inventory.Shared/Dtos/OperationDtos.cs
//        (Order, OrderLine, OrderCommand, OrderLineInput,
//         ChequeDto, InstallmentDto) + Inventory.Shared/Enums.cs
// ============================================================

/// نوع سند (TransactionType)
class TxnType {
  static const purchase = 1;
  static const sale = 2;
}

/// روش پرداخت اعلامی (PaymentMethod)
class PayMethod {
  static const cash = 0;
  static const credit = 1;
  static const cheque = 2;
  static const installment = 3;
  static const mixed = 4;
}

/// نوع دریافت/پرداخت نقدی (CashType)
class CashKind {
  static const cash = 0;
  static const cardReader = 1;
  static const cardTransfer = 2;
}

/// نوع حساب خزانه (TreasuryAccountKind)
class AccountKind {
  static const cash = 0;
  static const bank = 1;
  static const pos = 2;
  static const pettyCash = 3;
}

/// حساب خزانه (صندوق/بانک/کارتخوان/تنخواه) — آینهٔ `TrsAccount`
class TrsAccount {
  TrsAccount({
    this.id = 0,
    this.code = '',
    this.name = '',
    this.kind = AccountKind.cash,
    this.bankName,
    this.branchName,
    this.branchCode,
    this.accountNumber,
    this.iban,
    this.cardNumber,
    this.openingBalance = 0,
    this.isDefault = false,
    this.isActive = true,
    this.description,
  });

  final int id;
  final String code;
  final String name;
  final int kind;
  final String? bankName;
  final String? branchName;
  final String? branchCode;
  final String? accountNumber;
  final String? iban;
  final String? cardNumber;
  final double openingBalance;
  final bool isDefault;
  final bool isActive;
  final String? description;

  /// DisplayName سرور: «بانک — نام» یا خود نام
  String get displayName =>
      (bankName ?? '').trim().isEmpty ? name : '$bankName — $name';

  factory TrsAccount.fromJson(Map<String, dynamic> j) => TrsAccount(
    id: (j['id'] as num?)?.toInt() ?? 0,
    code: (j['code'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    kind: (j['kind'] as num?)?.toInt() ?? 0,
    bankName: _s(j['bankName']),
    branchName: _s(j['branchName']),
    branchCode: _s(j['branchCode']),
    accountNumber: _s(j['accountNumber']),
    iban: _s(j['iban']),
    cardNumber: _s(j['cardNumber']),
    openingBalance: _d(j['openingBalance']),
    isDefault: j['isDefault'] == true,
    isActive: j['isActive'] != false,
    description: _s(j['description']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code.trim(),
    'name': name.trim(),
    'kind': kind,
    'bankName': _s(bankName),
    'branchName': _s(branchName),
    'branchCode': _s(branchCode),
    'accountNumber': _s(accountNumber),
    'iban': _s(iban),
    'cardNumber': _s(cardNumber),
    'openingBalance': openingBalance,
    'isDefault': isDefault,
    'isActive': isActive,
    'description': _s(description),
  };
}

/// یک قلم سند فروش/خرید — آینهٔ `OrderLine`
class OrderLine {
  OrderLine({
    this.id = 0,
    this.productId = 0,
    this.productName = '',
    this.unit = '',
    this.quantity = 0,
    this.price = 0,
    this.discountPercent = 0,
    this.discountAmount = 0,
    this.discountIsAmount = false,
    this.isService = false,
    this.unitCost,
    this.profit,
    this.commission,
  });

  final int id;
  final int productId;
  final String productName;
  final String unit;
  final double quantity;
  final double price;
  final double discountPercent;
  final double discountAmount;
  final bool discountIsAmount;
  final bool isService;
  final double? unitCost;
  final double? profit;
  final double? commission;

  /// همان فرمول سرور: max(0, مقدار×قیمت − تخفیف)
  double get total {
    final t = quantity * price - discountAmount;
    return t < 0 ? 0 : t;
  }

  /// برای بازگرداندن سطر به فرم (OrderLineInput) — فقط همین شش فیلد
  Map<String, dynamic> toInput() => {
    'id': id,
    'productId': productId,
    'quantity': quantity,
    'price': price,
    'discountPercent': discountPercent,
    'discountAmount': discountAmount,
    'discountIsAmount': discountIsAmount,
  };

  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
    id: (j['id'] as num?)?.toInt() ?? 0,
    productId: (j['productId'] as num?)?.toInt() ?? 0,
    productName: (j['productName'] ?? '').toString(),
    unit: (j['unit'] ?? '').toString(),
    quantity: _d(j['quantity']),
    price: _d(j['price']),
    discountPercent: _d(j['discountPercent']),
    discountAmount: _d(j['discountAmount']),
    discountIsAmount: j['discountIsAmount'] == true,
    isService: j['isService'] == true,
    unitCost: (j['unitCost'] as num?)?.toDouble(),
    profit: (j['profit'] as num?)?.toDouble(),
    commission: (j['commission'] as num?)?.toDouble(),
  );
}

/// چک سند — آینهٔ `ChequeDto`
class OrderCheque {
  OrderCheque({
    this.id = 0,
    this.number = '',
    this.trsAccountId,
    this.bankName,
    this.accountInfo,
    this.ownerName,
    this.amount = 0,
    this.dueDate,
    this.isCleared = false,
    this.note,
  });

  int id;
  String number;
  int? trsAccountId;
  String? bankName;
  String? accountInfo;
  String? ownerName;
  double amount;
  DateTime? dueDate;
  bool isCleared;
  String? note;

  factory OrderCheque.fromJson(Map<String, dynamic> j) => OrderCheque(
    id: (j['id'] as num?)?.toInt() ?? 0,
    number: (j['number'] ?? '').toString(),
    trsAccountId: (j['trsAccountId'] as num?)?.toInt(),
    bankName: _s(j['bankName']),
    accountInfo: _s(j['accountInfo']),
    ownerName: _s(j['ownerName']),
    amount: _d(j['amount']),
    dueDate: DateTime.tryParse((j['dueDate'] ?? '').toString())?.toLocal(),
    isCleared: j['isCleared'] == true,
    note: _s(j['note']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number.trim(),
    'trsAccountId': trsAccountId,
    'bankName': _s(bankName),
    'accountInfo': _s(accountInfo),
    'ownerName': _s(ownerName),
    'amount': amount,
    'dueDate': (dueDate ?? DateTime.now()).toIso8601String(),
    'isCleared': isCleared,
    'note': _s(note),
  };
}

/// قسط سند — آینهٔ `InstallmentDto`
class OrderInstallment {
  OrderInstallment({
    this.id = 0,
    this.no = 1,
    this.amount = 0,
    this.dueDate,
    this.isPaid = false,
  });

  int id;
  int no;
  double amount;
  DateTime? dueDate;
  bool isPaid;

  factory OrderInstallment.fromJson(Map<String, dynamic> j) => OrderInstallment(
    id: (j['id'] as num?)?.toInt() ?? 0,
    no: (j['no'] as num?)?.toInt() ?? 1,
    amount: _d(j['amount']),
    dueDate: DateTime.tryParse((j['dueDate'] ?? '').toString())?.toLocal(),
    isPaid: j['isPaid'] == true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'no': no,
    'amount': amount,
    'dueDate': (dueDate ?? DateTime.now()).toIso8601String(),
    'isPaid': isPaid,
  };
}

/// سند خرید/فروش — آینهٔ `Order`
class ShopOrder {
  ShopOrder({
    this.id = 0,
    this.warehouseId = 0,
    this.warehouseName,
    this.partyId = 0,
    this.partyName,
    this.type = TxnType.sale,
    this.number = '',
    this.date,
    this.description = '',
    this.lines = const [],
    this.totalAmount = 0,
    this.referrerId,
    this.referrerName,
    this.totalProfit,
    this.commissionAmount,
    this.netProfit,
    this.paymentMethod = PayMethod.cash,
    this.cashType,
    this.cashAmount = 0,
    this.trsAccountId,
    this.trsAccountName,
    this.dueDate,
    this.settledAmount = 0,
    this.cheques = const [],
    this.installments = const [],
    this.isPosted = true,
    this.canDelete = true,
  });

  final int id;
  final int warehouseId;
  final String? warehouseName;
  final int partyId;
  final String? partyName;
  final int type;
  final String number;
  final DateTime? date;
  final String description;
  final List<OrderLine> lines;
  final double totalAmount;
  final int? referrerId;
  final String? referrerName;
  final double? totalProfit;
  final double? commissionAmount;
  final double? netProfit;
  final int paymentMethod;
  final int? cashType;
  final double cashAmount;
  final int? trsAccountId;
  final String? trsAccountName;
  final DateTime? dueDate;
  final double settledAmount;
  final List<OrderCheque> cheques;
  final List<OrderInstallment> installments;
  final bool isPosted;
  final bool canDelete;

  bool get isSale => type == TxnType.sale;
  bool get isPurchase => type == TxnType.purchase;

  factory ShopOrder.fromJson(Map<String, dynamic> j) => ShopOrder(
    id: (j['id'] as num?)?.toInt() ?? 0,
    warehouseId: (j['warehouseId'] as num?)?.toInt() ?? 0,
    warehouseName: _s(j['warehouseName']),
    partyId: (j['partyId'] as num?)?.toInt() ?? 0,
    partyName: _s(j['partyName']),
    type: (j['type'] as num?)?.toInt() ?? TxnType.sale,
    number: (j['number'] ?? '').toString(),
    date: DateTime.tryParse((j['date'] ?? '').toString())?.toLocal(),
    description: (j['description'] ?? '').toString(),
    lines: (j['lines'] as List? ?? [])
        .whereType<Map>()
        .map((e) => OrderLine.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    totalAmount: _d(j['totalAmount']),
    referrerId: (j['referrerId'] as num?)?.toInt(),
    referrerName: _s(j['referrerName']),
    totalProfit: (j['totalProfit'] as num?)?.toDouble(),
    commissionAmount: (j['commissionAmount'] as num?)?.toDouble(),
    netProfit: (j['netProfit'] as num?)?.toDouble(),
    paymentMethod: (j['paymentMethod'] as num?)?.toInt() ?? PayMethod.cash,
    cashType: (j['cashType'] as num?)?.toInt(),
    cashAmount: _d(j['cashAmount']),
    trsAccountId: (j['trsAccountId'] as num?)?.toInt(),
    trsAccountName: _s(j['trsAccountName']),
    dueDate: DateTime.tryParse((j['dueDate'] ?? '').toString())?.toLocal(),
    settledAmount: _d(j['settledAmount']),
    cheques: (j['cheques'] as List? ?? [])
        .whereType<Map>()
        .map((e) => OrderCheque.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    installments: (j['installments'] as List? ?? [])
        .whereType<Map>()
        .map((e) => OrderInstallment.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    isPosted: j['isPosted'] != false,
    canDelete: j['canDelete'] != false,
  );

  /// برچسب روش پرداخت — همان PayBadge وب
  String get payLabel => switch (paymentMethod) {
    PayMethod.cash => 'نقدی',
    PayMethod.credit => 'نسیه',
    PayMethod.cheque => 'چک',
    PayMethod.mixed => 'ترکیبی',
    _ => 'اقساطی',
  };
}

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
String? _s(dynamic v) {
  final s = v?.toString();
  return (s == null || s.isEmpty || s == 'null') ? null : s;
}
