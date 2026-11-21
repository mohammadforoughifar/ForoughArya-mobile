// ============================================================
//  مدل‌های اسناد خرید/فروش و پیش‌فاکتور (فاز ۲ فروشگاهی کایر)
//  آینهٔ دقیق DTOهای سرور:
//    Inventory.Shared/OrderLineAmounts.cs
//    Inventory.Shared/Dtos/OperationDtos.cs
//    Inventory.Shared/Dtos/SalesProformaDtos.cs
//    Inventory.Shared/Dtos/ShopPricingDtos.cs
// ============================================================

import 'dart:math' as math;

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

/// تصمیم مشتری بابت مازاد چک در برگشت کالا (SaleChequeReturnDecision)
class ChequeReturnDecision {
  static const none = 0;
  static const replaceCheque = 1;
  static const keepChequeForGoods = 2;
}

/// محاسبه‌گر استاندارد تخفیف و ارزش افزودهٔ ردیف فاکتور — آینهٔ `OrderLineAmounts.cs`
class OrderLineAmounts {
  const OrderLineAmounts._();

  static const double maxVatValue = 9999999999999999.99;

  static double gross(double quantity, double price) =>
      ((quantity * price) * 100).roundToDouble() / 100;

  static double discount(
    double quantity,
    double price,
    double percent,
    double amount,
    bool isAmount,
  ) {
    final g = gross(quantity, price);
    if (isAmount) {
      return amount.roundToDouble().clamp(0, math.max(0.0, g)).toDouble();
    }
    if (percent <= 0) return 0;
    final p = percent.clamp(0.0, 100.0);
    return (g * p / 100).roundToDouble();
  }

  /// تا ۱۰۰ = درصد روی مبلغ پس از تخفیف، بالاتر از ۱۰۰ = مبلغ ثابت ریالی
  static double vat(double afterDiscount, double value) {
    if (value <= 0) return 0;
    if (value <= 100) {
      final baseVal = math.max(0.0, afterDiscount);
      return ((baseVal * value / 100) * 100).roundToDouble() / 100;
    }
    return value;
  }

  static double total(
    double quantity,
    double price,
    double percent,
    double amount,
    bool isAmount,
    double vatValue,
  ) {
    final g = gross(quantity, price);
    final d = discount(quantity, price, percent, amount, isAmount);
    final after = math.max(0.0, g - d);
    return after + vat(after, vatValue);
  }
}

/// حساب خزانه (صندوق/بانک/کارتخوان/تنخواه) — آینهٔ `TrsAccount`
class TrsAccount {
  TrsAccount({
    this.id = 0,
    this.companyId,
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
  final int? companyId;
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
    companyId: (j['companyId'] as num?)?.toInt(),
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
    if (companyId != null && companyId! > 0) 'companyId': companyId,
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
    this.description,
    this.unit = '',
    this.quantity = 0,
    this.price = 0,
    this.discountPercent = 0,
    this.discountAmount = 0,
    this.discountIsAmount = false,
    this.grossAmount,
    this.vatValue = 0,
    this.vatAmount = 0,
    this.isService = false,
    this.returnedQuantity = 0,
    this.unitCost,
    this.profit,
    this.commission,
  });

  final int id;
  final int productId;
  final String productName;
  final String? description;
  final String unit;
  final double quantity;
  final double price;
  final double discountPercent;
  final double discountAmount;
  final bool discountIsAmount;
  final double? grossAmount;
  final double vatValue;
  final double vatAmount;
  final bool isService;
  final double returnedQuantity;
  final double? unitCost;
  final double? profit;
  final double? commission;

  double get gross => grossAmount ?? (quantity * price);

  double get afterDiscount => math.max(0.0, gross - discountAmount);

  double get computedVat =>
      vatAmount > 0 ? vatAmount : OrderLineAmounts.vat(afterDiscount, vatValue);

  /// همان فرمول سرور: AfterDiscount + VatAmount
  double get total => afterDiscount + computedVat;

  double get remainingQuantity => math.max(0.0, quantity - returnedQuantity);

  /// تبدیل به `OrderLineInput` برای ارسال به سرور
  Map<String, dynamic> toInput({double? newSalePrice}) => {
    'id': id,
    'productId': productId,
    'quantity': quantity,
    'price': price,
    if (newSalePrice != null && newSalePrice > 0) 'newSalePrice': newSalePrice,
    'discountPercent': discountPercent,
    'discountAmount': discountAmount,
    'discountIsAmount': discountIsAmount,
    'vatValue': vatValue,
  };

  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
    id: (j['id'] as num?)?.toInt() ?? 0,
    productId: (j['productId'] as num?)?.toInt() ?? 0,
    productName: (j['productName'] ?? '').toString(),
    description: _s(j['description']),
    unit: (j['unit'] ?? '').toString(),
    quantity: _d(j['quantity']),
    price: _d(j['price']),
    discountPercent: _d(j['discountPercent']),
    discountAmount: _d(j['discountAmount']),
    discountIsAmount: j['discountIsAmount'] == true,
    grossAmount: (j['grossAmount'] as num?)?.toDouble(),
    vatValue: _d(j['vatValue']),
    vatAmount: _d(j['vatAmount']),
    isService: j['isService'] == true,
    returnedQuantity: _d(j['returnedQuantity']),
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
    this.status = 0,
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
  int status;
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
    status: (j['status'] as num?)?.toInt() ?? 0,
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
    'status': status,
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

/// ورودی ماشین‌حساب تاخیر تادیه چک — آینهٔ `SaleChequeChargeInput`
class SaleChequeChargeInput {
  const SaleChequeChargeInput({
    required this.calculatorBaseAmount,
    required this.calculatorRatePercent,
    required this.calculatorMonths,
    this.adjustmentRatePercent = 0,
    this.adjustmentPeriodDays = 30,
    this.confirmedCreditDueDate,
  });

  final double calculatorBaseAmount;
  final double calculatorRatePercent;
  final int calculatorMonths;
  final double adjustmentRatePercent;
  final int adjustmentPeriodDays;
  final DateTime? confirmedCreditDueDate;

  factory SaleChequeChargeInput.fromJson(Map<String, dynamic> j) =>
      SaleChequeChargeInput(
        calculatorBaseAmount: _d(j['calculatorBaseAmount']),
        calculatorRatePercent: _d(j['calculatorRatePercent']),
        calculatorMonths: (j['calculatorMonths'] as num?)?.toInt() ?? 1,
        adjustmentRatePercent: _d(j['adjustmentRatePercent']),
        adjustmentPeriodDays:
            (j['adjustmentPeriodDays'] as num?)?.toInt() ?? 30,
        confirmedCreditDueDate: DateTime.tryParse(
          (j['confirmedCreditDueDate'] ?? '').toString(),
        )?.toLocal(),
      );

  Map<String, dynamic> toJson() => {
    'calculatorBaseAmount': calculatorBaseAmount,
    'calculatorRatePercent': calculatorRatePercent,
    'calculatorMonths': calculatorMonths,
    'adjustmentRatePercent': adjustmentRatePercent,
    'adjustmentPeriodDays': adjustmentPeriodDays,
    if (confirmedCreditDueDate != null)
      'confirmedCreditDueDate': confirmedCreditDueDate!.toIso8601String(),
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
    this.partyPhone,
    this.partyAddress,
    this.partyTaxId,
    this.type = TxnType.sale,
    this.number = '',
    this.date,
    this.description = '',
    this.lines = const [],
    this.totalAmount = 0,
    this.chequeIncomeAmount = 0,
    this.hasChequeCharge = false,
    this.returnedGoodsAmount = 0,
    this.returnedChequeIncomeAmount = 0,
    this.customerCreditAmount = 0,
    this.availableCustomerCredit = 0,
    this.isCancelled = false,
    this.chequeChargeSnapshot,
    this.referrerId,
    this.referrerName,
    this.totalProfit,
    this.commissionAmount,
    this.netProfit,
    this.paymentMethod = PayMethod.cash,
    this.cashType,
    this.cashTrackingNumber,
    this.cashAmount = 0,
    this.shopCashLedgerEnabled = false,
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
  final String? partyPhone;
  final String? partyAddress;
  final String? partyTaxId;
  final int type;
  final String number;
  final DateTime? date;
  final String description;
  final List<OrderLine> lines;
  final double totalAmount;
  final double chequeIncomeAmount;
  final bool hasChequeCharge;
  final double returnedGoodsAmount;
  final double returnedChequeIncomeAmount;
  final double customerCreditAmount;
  final double availableCustomerCredit;
  final bool isCancelled;
  final SaleChequeChargeInput? chequeChargeSnapshot;
  final int? referrerId;
  final String? referrerName;
  final double? totalProfit;
  final double? commissionAmount;
  final double? netProfit;
  final int paymentMethod;
  final int? cashType;
  final String? cashTrackingNumber;
  final double cashAmount;
  final bool shopCashLedgerEnabled;
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
  double get goodsAmount => totalAmount - chequeIncomeAmount;

  factory ShopOrder.fromJson(Map<String, dynamic> j) => ShopOrder(
    id: (j['id'] as num?)?.toInt() ?? 0,
    warehouseId: (j['warehouseId'] as num?)?.toInt() ?? 0,
    warehouseName: _s(j['warehouseName']),
    partyId: (j['partyId'] as num?)?.toInt() ?? 0,
    partyName: _s(j['partyName']),
    partyPhone: _s(j['partyPhone']),
    partyAddress: _s(j['partyAddress']),
    partyTaxId: _s(j['partyTaxId']),
    type: (j['type'] as num?)?.toInt() ?? TxnType.sale,
    number: (j['number'] ?? '').toString(),
    date: DateTime.tryParse((j['date'] ?? '').toString())?.toLocal(),
    description: (j['description'] ?? '').toString(),
    lines: (j['lines'] as List? ?? [])
        .whereType<Map>()
        .map((e) => OrderLine.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    totalAmount: _d(j['totalAmount']),
    chequeIncomeAmount: _d(j['chequeIncomeAmount']),
    hasChequeCharge: j['hasChequeCharge'] == true,
    returnedGoodsAmount: _d(j['returnedGoodsAmount']),
    returnedChequeIncomeAmount: _d(j['returnedChequeIncomeAmount']),
    customerCreditAmount: _d(j['customerCreditAmount']),
    availableCustomerCredit: _d(j['availableCustomerCredit']),
    isCancelled: j['isCancelled'] == true,
    chequeChargeSnapshot: j['chequeChargeSnapshot'] is Map
        ? SaleChequeChargeInput.fromJson(
            Map<String, dynamic>.from(j['chequeChargeSnapshot'] as Map),
          )
        : null,
    referrerId: (j['referrerId'] as num?)?.toInt(),
    referrerName: _s(j['referrerName']),
    totalProfit: (j['totalProfit'] as num?)?.toDouble(),
    commissionAmount: (j['commissionAmount'] as num?)?.toDouble(),
    netProfit: (j['netProfit'] as num?)?.toDouble(),
    paymentMethod: (j['paymentMethod'] as num?)?.toInt() ?? PayMethod.cash,
    cashType: (j['cashType'] as num?)?.toInt(),
    cashTrackingNumber: _s(j['cashTrackingNumber']),
    cashAmount: _d(j['cashAmount']),
    shopCashLedgerEnabled: j['shopCashLedgerEnabled'] == true,
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

/// موجودی به تاریخ سند در انبار — آینهٔ `InvoiceStockItem`
class InvoiceStockItem {
  const InvoiceStockItem({
    required this.warehouseId,
    required this.productId,
    required this.quantity,
    required this.sellableQuantity,
  });

  final int warehouseId;
  final int productId;
  final double quantity;
  final double sellableQuantity;

  factory InvoiceStockItem.fromJson(Map<String, dynamic> j) => InvoiceStockItem(
    warehouseId: (j['warehouseId'] as num?)?.toInt() ?? 0,
    productId: (j['productId'] as num?)?.toInt() ?? 0,
    quantity: _d(j['quantity']),
    sellableQuantity: _d(j['sellableQuantity']),
  );
}

/// قیمت فروش تاریخ‌دار کالا — آینهٔ `DatedSalePriceDto`
class DatedSalePrice {
  const DatedSalePrice({this.price, this.source});

  final double? price;
  final String? source;

  bool get isCatalogFallback => source == 'catalog';

  factory DatedSalePrice.fromJson(Map<String, dynamic> j) => DatedSalePrice(
    price: (j['price'] as num?)?.toDouble(),
    source: _s(j['source']),
  );
}

/// مبنای حداقل سود در تاریخ فاکتور — آینهٔ `ShopMinimumProfitBasisDto`
class MinimumProfitBasis {
  const MinimumProfitBasis({
    this.minimumProfitEnabled = false,
    this.minimumMarkupPercent = 0,
    this.purchaseNumber,
    this.netUnitCost,
    this.minimumUnitRevenue,
    this.reason,
  });

  final bool minimumProfitEnabled;
  final double minimumMarkupPercent;
  final String? purchaseNumber;
  final double? netUnitCost;
  final double? minimumUnitRevenue;
  final String? reason;

  factory MinimumProfitBasis.fromJson(Map<String, dynamic> j) =>
      MinimumProfitBasis(
        minimumProfitEnabled: j['minimumProfitEnabled'] == true,
        minimumMarkupPercent: _d(j['minimumMarkupPercent']),
        purchaseNumber: _s(j['purchaseNumber']),
        netUnitCost: (j['netUnitCost'] as num?)?.toDouble(),
        minimumUnitRevenue:
            (j['minimumUnitRevenueBeforeSaleDiscountAndCommission'] as num?)
                ?.toDouble(),
        reason: _s(j['reason']),
      );
}

// ---------------- پیش‌فاکتور فروش (`SalesProformaDtos.cs`) ----------------

class SalesProformaLine {
  const SalesProformaLine({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.isService,
    required this.quantity,
    required this.price,
    this.discountPercent = 0,
    this.discountAmount = 0,
    this.discountIsAmount = false,
    this.vatValue = 0,
  });

  final int productId;
  final String productName;
  final String unit;
  final bool isService;
  final double quantity;
  final double price;
  final double discountPercent;
  final double discountAmount;
  final bool discountIsAmount;
  final double vatValue;

  double get total => OrderLineAmounts.total(
    quantity,
    price,
    discountPercent,
    discountAmount,
    discountIsAmount,
    vatValue,
  );

  factory SalesProformaLine.fromJson(Map<String, dynamic> j) =>
      SalesProformaLine(
        productId: (j['productId'] as num?)?.toInt() ?? 0,
        productName: (j['productName'] ?? '').toString(),
        unit: (j['unit'] ?? '').toString(),
        isService: j['isService'] == true,
        quantity: _d(j['quantity']),
        price: _d(j['price']),
        discountPercent: _d(j['discountPercent']),
        discountAmount: _d(j['discountAmount']),
        discountIsAmount: j['discountIsAmount'] == true,
        vatValue: _d(j['vatValue']),
      );

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'unit': unit,
    'isService': isService,
    'quantity': quantity,
    'price': price,
    'discountPercent': discountPercent,
    'discountAmount': discountAmount,
    'discountIsAmount': discountIsAmount,
    'vatValue': vatValue,
  };
}

class SalesProformaCommand {
  const SalesProformaCommand({
    required this.warehouseId,
    required this.partyId,
    required this.date,
    this.description,
    this.referrerId,
    this.lines = const [],
  });

  final int warehouseId;
  final int partyId;
  final DateTime date;
  final String? description;
  final int? referrerId;
  final List<SalesProformaLine> lines;

  double get totalAmount => lines.fold<double>(0, (s, l) => s + l.total);

  factory SalesProformaCommand.fromJson(Map<String, dynamic> j) =>
      SalesProformaCommand(
        warehouseId: (j['warehouseId'] as num?)?.toInt() ?? 0,
        partyId: (j['partyId'] as num?)?.toInt() ?? 0,
        date:
            DateTime.tryParse((j['date'] ?? '').toString())?.toLocal() ??
            DateTime.now(),
        description: _s(j['description']),
        referrerId: (j['referrerId'] as num?)?.toInt(),
        lines: (j['lines'] as List? ?? [])
            .whereType<Map>()
            .map((e) => SalesProformaLine.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'warehouseId': warehouseId,
    'partyId': partyId,
    'date': date.toIso8601String(),
    if ((description ?? '').trim().isNotEmpty)
      'description': description!.trim(),
    if (referrerId != null && referrerId! > 0) 'referrerId': referrerId,
    'lines': lines.map((l) => l.toJson()).toList(),
  };
}

class SalesProforma {
  const SalesProforma({
    required this.id,
    this.companyId = 0,
    required this.number,
    required this.partyName,
    this.partyPhone,
    this.partyAddress,
    this.partyTaxId,
    required this.warehouseName,
    required this.document,
    this.saleOrderId,
  });

  final String id;
  final int companyId;
  final String number;
  final String partyName;
  final String? partyPhone;
  final String? partyAddress;
  final String? partyTaxId;
  final String warehouseName;
  final SalesProformaCommand document;
  final int? saleOrderId;

  bool get isConverted => (saleOrderId ?? 0) > 0;

  /// تبدیل به ساختار `ShopOrder` برای چاپ یا پرکردن فرم تبدیل به فروش (مشابه `ProformaOrder` در وب)
  ShopOrder toOrder() {
    final mappedLines = document.lines.map((l) {
      final g = OrderLineAmounts.gross(l.quantity, l.price);
      final d = OrderLineAmounts.discount(
        l.quantity,
        l.price,
        l.discountPercent,
        l.discountAmount,
        l.discountIsAmount,
      );
      final after = math.max(0.0, g - d);
      final v = OrderLineAmounts.vat(after, l.vatValue);
      return OrderLine(
        productId: l.productId,
        productName: l.productName,
        unit: l.unit,
        isService: l.isService,
        quantity: l.quantity,
        price: l.price,
        grossAmount: g,
        discountPercent: l.discountPercent,
        discountAmount: d,
        discountIsAmount: l.discountIsAmount,
        vatValue: l.vatValue,
        vatAmount: v,
      );
    }).toList();
    return ShopOrder(
      type: TxnType.sale,
      number: number,
      date: document.date,
      partyId: document.partyId,
      partyName: partyName,
      partyPhone: partyPhone,
      partyAddress: partyAddress,
      partyTaxId: partyTaxId,
      warehouseId: document.warehouseId,
      warehouseName: warehouseName,
      description: document.description ?? '',
      referrerId: document.referrerId,
      lines: mappedLines,
      totalAmount: mappedLines.fold<double>(0, (s, l) => s + l.total),
    );
  }

  factory SalesProforma.fromJson(Map<String, dynamic> j) => SalesProforma(
    id: (j['id'] ?? '').toString(),
    companyId: (j['companyId'] as num?)?.toInt() ?? 0,
    number: (j['number'] ?? '').toString(),
    partyName: (j['partyName'] ?? '').toString(),
    partyPhone: _s(j['partyPhone']),
    partyAddress: _s(j['partyAddress']),
    partyTaxId: _s(j['partyTaxId']),
    warehouseName: (j['warehouseName'] ?? '').toString(),
    document: j['document'] is Map
        ? SalesProformaCommand.fromJson(
            Map<String, dynamic>.from(j['document'] as Map),
          )
        : SalesProformaCommand(
            warehouseId: 0,
            partyId: 0,
            date: DateTime.now(),
          ),
    saleOrderId: (j['saleOrderId'] as num?)?.toInt(),
  );
}

// ---------------- نسیه و سوابق فاکتور (`ShopOrderCreditState`) ----------------

class ShopOrderCreditReceipt {
  const ShopOrderCreditReceipt({
    required this.id,
    required this.amount,
    required this.trsAccountId,
    required this.accountName,
    this.date,
    this.createdBy,
    this.reversalDate,
    this.reversedBy,
  });

  final int id;
  final double amount;
  final int trsAccountId;
  final String accountName;
  final DateTime? date;
  final String? createdBy;
  final DateTime? reversalDate;
  final String? reversedBy;

  bool get isReversed => reversalDate != null;

  factory ShopOrderCreditReceipt.fromJson(Map<String, dynamic> j) =>
      ShopOrderCreditReceipt(
        id: (j['id'] as num?)?.toInt() ?? 0,
        amount: _d(j['amount']),
        trsAccountId: (j['trsAccountId'] as num?)?.toInt() ?? 0,
        accountName: (j['accountName'] ?? '').toString(),
        date: DateTime.tryParse((j['date'] ?? '').toString())?.toLocal(),
        createdBy: _s(j['createdBy']),
        reversalDate: DateTime.tryParse(
          (j['reversalDate'] ?? '').toString(),
        )?.toLocal(),
        reversedBy: _s(j['reversedBy']),
      );
}

class ShopOrderCreditState {
  const ShopOrderCreditState({
    this.outstanding = 0,
    this.reservedForCheques = 0,
    this.reservedForInstallments = 0,
    this.availableCredit = 0,
    this.isCancelled = false,
    this.receipts = const [],
  });

  final double outstanding;
  final double reservedForCheques;
  final double reservedForInstallments;
  final double availableCredit;
  final bool isCancelled;
  final List<ShopOrderCreditReceipt> receipts;

  factory ShopOrderCreditState.fromJson(Map<String, dynamic> j) =>
      ShopOrderCreditState(
        outstanding: _d(j['outstanding']),
        reservedForCheques: _d(j['reservedForCheques']),
        reservedForInstallments: _d(j['reservedForInstallments']),
        availableCredit: _d(j['availableCredit']),
        isCancelled: j['isCancelled'] == true,
        receipts: (j['receipts'] as List? ?? [])
            .whereType<Map>()
            .map(
              (e) => ShopOrderCreditReceipt.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList(),
      );
}

// ---------------- برگشت فاکتور چکی (`SaleChequeReturnPreviewDto`) ----------------

class SaleChequeReturnPreview {
  const SaleChequeReturnPreview({
    this.goodsBeforeVat = 0,
    this.vat = 0,
    this.income = 0,
    this.totalCredit = 0,
    this.balanceBefore = 0,
    this.balanceAfter = 0,
    this.uncollectedChequeExcess = 0,
  });

  final double goodsBeforeVat;
  final double vat;
  final double income;
  final double totalCredit;
  final double balanceBefore;
  final double balanceAfter;
  final double uncollectedChequeExcess;

  factory SaleChequeReturnPreview.fromJson(Map<String, dynamic> j) =>
      SaleChequeReturnPreview(
        goodsBeforeVat: _d(j['goodsBeforeVat']),
        vat: _d(j['vat']),
        income: _d(j['income']),
        totalCredit: _d(j['totalCredit']),
        balanceBefore: _d(j['balanceBefore']),
        balanceAfter: _d(j['balanceAfter']),
        uncollectedChequeExcess: _d(j['uncollectedChequeExcess']),
      );
}

/// مشخصات شرکت و سرصفحه/پاورقی چاپ فاکتور — آینهٔ `CompanyProfileDto`
class CompanyProfile {
  const CompanyProfile({
    this.id = 0,
    this.name = '',
    this.logoDataUrl,
    this.accountNumber,
    this.phone,
    this.address,
    this.economicCode,
    this.taxId,
    this.email,
    this.website,
    this.printHeaderLines,
    this.printFooterLines,
    this.printPaperSize = 'A4',
  });

  final int id;
  final String name;
  final String? logoDataUrl;
  final String? accountNumber;
  final String? phone;
  final String? address;
  final String? economicCode;
  final String? taxId;
  final String? email;
  final String? website;
  final String? printHeaderLines;
  final String? printFooterLines;
  final String printPaperSize;

  factory CompanyProfile.fromJson(Map<String, dynamic> j) => CompanyProfile(
    id: (j['id'] as num?)?.toInt() ?? 0,
    name: (j['name'] ?? '').toString(),
    logoDataUrl: _s(j['logoDataUrl']),
    accountNumber: _s(j['accountNumber']),
    phone: _s(j['phone']),
    address: _s(j['address']),
    economicCode: _s(j['economicCode']),
    taxId: _s(j['taxId']),
    email: _s(j['email']),
    website: _s(j['website']),
    printHeaderLines: _s(j['printHeaderLines']),
    printFooterLines: _s(j['printFooterLines']),
    printPaperSize: (j['printPaperSize'] ?? 'A4').toString(),
  );
}

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
String? _s(dynamic v) {
  final s = v?.toString();
  return (s == null || s.isEmpty || s == 'null') ? null : s;
}
