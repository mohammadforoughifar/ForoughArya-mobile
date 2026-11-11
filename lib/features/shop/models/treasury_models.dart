// ============================================================
//  مدل‌های فاز ۵ — خزانه، چک، اقساط و مانده‌های اولیه
//  آینهٔ DTOهای سرور:
//    Inventory.Shared/Dtos/TreasuryDtos.cs
//    Inventory.Shared/Dtos/OperationDtos.cs (ShopChequeItem / ShopInstallmentItem / ShopCreditSummary)
//    Inventory.Shared/Enums.cs (TreasuryKind / TreasuryStatus / PayMethod / ChequeKind / ChequeStatus)
// ============================================================

import 'dart:math' as math;

String? _s(dynamic v) {
  if (v == null) return null;
  final t = v.toString().trim();
  return t.isEmpty ? null : t;
}

double _d(dynamic v) => v is num ? v.toDouble() : 0;

/// نوع سند خزانه — آینهٔ `TreasuryKind`
class TrsKind {
  static const receipt = 0;
  static const payment = 1;
  static const transfer = 2;

  static String title(int k) => switch (k) {
    receipt => 'دریافت',
    payment => 'پرداخت',
    _ => 'انتقال',
  };

  static String longTitle(int k) => switch (k) {
    receipt => 'سند دریافت',
    payment => 'سند پرداخت',
    _ => 'انتقال بین حساب‌ها',
  };
}

/// وضعیت سند خزانه — آینهٔ `TreasuryStatus`
class TrsState {
  static const draft = 0;
  static const confirmed = 1;
  static const cancelled = 2;

  static String title(int s) => switch (s) {
    draft => 'پیش‌نویس',
    confirmed => 'قطعی',
    _ => 'ابطال شده',
  };
}

/// ابزار پرداخت هر سطر — آینهٔ `PayMethod`
class TrsMethod {
  static const cash = 0;
  static const card = 1;
  static const transfer = 2;
  static const cheque = 3;
  static const discount = 4;

  static String title(int m) => switch (m) {
    cash => 'نقد',
    card => 'کارتخوان',
    transfer => 'حواله بانکی',
    cheque => 'چک',
    _ => 'تخفیف و کسورات',
  };

  /// فقط این سه ابزار به صندوق/بانک نیاز دارند
  static bool needsAccount(int m) =>
      m == cash || m == card || m == transfer;
}

/// نوع چک — آینهٔ `ChequeKind`
class ChequeKind {
  static const received = 0;
  static const issued = 1;

  static String title(int k) => k == received ? 'چک دریافتی' : 'چک پرداختی';
}

/// وضعیت چک — آینهٔ `ChequeStatus`
class TrsChequeState {
  static const inHand = 0;
  static const inCollection = 1;
  static const cleared = 2;
  static const bounced = 3;
  static const endorsed = 4;
  static const cancelled = 5;

  static String title(int s, {int kind = ChequeKind.received}) =>
      switch (s) {
        inHand => kind == ChequeKind.received ? 'نزد صندوق' : 'تحویل شده',
        inCollection => 'در جریان وصول',
        cleared => kind == ChequeKind.received ? 'وصول شده' : 'پاس شده',
        bounced => 'برگشتی',
        endorsed => 'خرج شده',
        _ => 'ابطال شده',
      };

  static bool isOpen(int s) => s == inHand || s == inCollection;

  /// همان `EnsureTransition` سرور — فقط برای پنهان‌کردن دکمه‌های نامجاز
  static bool canGo(int kind, int from, int to) {
    if (from == to) return false;
    if (from == cleared || from == endorsed || from == cancelled) return false;
    if (kind == ChequeKind.received) {
      return switch (from) {
        inHand => to == inCollection ||
            to == cleared ||
            to == endorsed ||
            to == cancelled,
        inCollection => to == cleared || to == bounced || to == inHand,
        bounced => to == inCollection || to == cleared || to == cancelled,
        _ => false,
      };
    }
    return switch (from) {
      inHand => to == cleared || to == bounced || to == cancelled,
      bounced => to == cleared || to == cancelled,
      _ => false,
    };
  }
}

// ------------------------------------------------------------
//  ۱) صندوق، بانک، کارتخوان و تنخواه — `TrsAccount`
// ------------------------------------------------------------

/// حساب خزانه با مانده‌های محاسباتی سرور (`withBalances=true`)
class TreasuryAccount {
  TreasuryAccount({
    this.id = 0,
    this.code = '',
    this.name = '',
    this.kind = 0,
    this.accountId,
    this.accountCode,
    this.accountName,
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
    this.sortOrder = 0,
    this.totalIn = 0,
    this.totalOut = 0,
    this.balance = 0,
    this.moveCount = 0,
  });

  final int id;
  final String code;
  final String name;
  final int kind;

  final int? accountId;
  final String? accountCode;
  final String? accountName;

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
  final int sortOrder;

  final double totalIn;
  final double totalOut;
  final double balance;
  final int moveCount;

  /// همان `KindTitle` وب
  String get kindTitle => switch (kind) {
    0 => 'صندوق',
    1 => 'بانک',
    2 => 'کارتخوان',
    _ => 'تنخواه‌گردان',
  };

  /// همان `DisplayName` وب: بانک + نام بانک
  String get displayName =>
      kind == 1 && (bankName ?? '').trim().isNotEmpty
      ? '$name — $bankName'
      : name;

  bool get hasAccounting => (accountId ?? 0) > 0;

  factory TreasuryAccount.fromJson(Map<String, dynamic> j) => TreasuryAccount(
    id: (j['id'] as num?)?.toInt() ?? 0,
    code: (j['code'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    kind: (j['kind'] as num?)?.toInt() ?? 0,
    accountId: (j['accountId'] as num?)?.toInt(),
    accountCode: _s(j['accountCode']),
    accountName: _s(j['accountName']),
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
    sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
    totalIn: _d(j['totalIn']),
    totalOut: _d(j['totalOut']),
    balance: _d(j['balance']),
    moveCount: (j['moveCount'] as num?)?.toInt() ?? 0,
  );

  /// همهٔ فیلدهای `TrsAccount` سرور (حتی محاسباتی‌ها، تا مثل وب کامل باشد)
  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code.trim(),
    'name': name.trim(),
    'kind': kind,
    'accountId': accountId,
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
    'sortOrder': sortOrder,
  };
}

// ------------------------------------------------------------
//  ۲) سند دریافت / پرداخت / انتقال — `TrsVoucher`
// ------------------------------------------------------------

/// یک سطر (ابزار) سند خزانه — `TrsVoucherLine`
class VoucherLine {
  VoucherLine({
    this.id = 0,
    this.rowNo = 1,
    this.method = TrsMethod.cash,
    this.trsAccountId,
    this.trsAccountName,
    this.amount = 0,
    this.refNumber,
    this.description,
    this.chequeId,
    this.chequeNumber,
    this.sayadId,
    this.chequeBankName,
    this.chequeBranchName,
    this.chequeAccountNumber,
    this.issueDate,
    this.dueDate,
    this.chequeStatus,
  });

  int id;
  int rowNo;
  int method;
  int? trsAccountId;
  String? trsAccountName;
  double amount;
  String? refNumber;
  String? description;

  // مشخصات چک (وقتی method = cheque)
  int? chequeId;
  String? chequeNumber;
  String? sayadId;
  String? chequeBankName;
  String? chequeBranchName;
  String? chequeAccountNumber;
  DateTime? issueDate;
  DateTime? dueDate;
  int? chequeStatus;

  String get methodTitle => TrsMethod.title(method);

  bool get needsAccount => TrsMethod.needsAccount(method);

  factory VoucherLine.fromJson(Map<String, dynamic> j) => VoucherLine(
    id: (j['id'] as num?)?.toInt() ?? 0,
    rowNo: (j['rowNo'] as num?)?.toInt() ?? 1,
    method: (j['method'] as num?)?.toInt() ?? 0,
    trsAccountId: (j['trsAccountId'] as num?)?.toInt(),
    trsAccountName: _s(j['trsAccountName']),
    amount: _d(j['amount']),
    refNumber: _s(j['refNumber']),
    description: _s(j['description']),
    chequeId: (j['chequeId'] as num?)?.toInt(),
    chequeNumber: _s(j['chequeNumber']),
    sayadId: _s(j['sayadId']),
    chequeBankName: _s(j['chequeBankName']),
    chequeBranchName: _s(j['chequeBranchName']),
    chequeAccountNumber: _s(j['chequeAccountNumber']),
    issueDate: DateTime.tryParse((j['issueDate'] ?? '').toString())?.toLocal(),
    dueDate: DateTime.tryParse((j['dueDate'] ?? '').toString())?.toLocal(),
    chequeStatus: (j['chequeStatus'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'rowNo': rowNo,
    'method': method,
    'trsAccountId': trsAccountId,
    'amount': amount,
    'refNumber': _s(refNumber),
    'description': _s(description),
    'chequeId': chequeId,
    'chequeNumber': _s(chequeNumber),
    'sayadId': _s(sayadId),
    'chequeBankName': _s(chequeBankName),
    'chequeBranchName': _s(chequeBranchName),
    'chequeAccountNumber': _s(chequeAccountNumber),
    'issueDate': issueDate?.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
  };
}

/// تخصیص سند به یک فاکتور — `TrsInvoiceAllocationDto`
class InvoiceAllocation {
  InvoiceAllocation({
    this.invoiceId = 0,
    this.invoiceNumber = 0,
    this.invoiceKind = 0,
    this.invoiceDate,
    this.invoiceTotal = 0,
    this.remainingBeforeSettlement = 0,
    this.effectiveAmount = 0,
    this.amount = 0,
  });

  int invoiceId;
  int invoiceNumber;
  int invoiceKind;
  DateTime? invoiceDate;
  double invoiceTotal;
  double remainingBeforeSettlement;
  double effectiveAmount;
  double amount;

  factory InvoiceAllocation.fromJson(Map<String, dynamic> j) =>
      InvoiceAllocation(
        invoiceId: (j['invoiceId'] as num?)?.toInt() ?? 0,
        invoiceNumber: (j['invoiceNumber'] as num?)?.toInt() ?? 0,
        invoiceKind: (j['invoiceKind'] as num?)?.toInt() ?? 0,
        invoiceDate: DateTime.tryParse(
          (j['invoiceDate'] ?? '').toString(),
        )?.toLocal(),
        invoiceTotal: _d(j['invoiceTotal']),
        remainingBeforeSettlement: _d(j['remainingBeforeSettlement']),
        effectiveAmount: _d(j['effectiveAmount']),
        amount: _d(j['amount']),
      );

  Map<String, dynamic> toJson() => {
    'invoiceId': invoiceId,
    'invoiceNumber': invoiceNumber,
    'invoiceKind': invoiceKind,
    'amount': amount,
  };
}

/// فاکتور باز قابل تسویه — `TrsSettlementInvoice`
class SettlementInvoice {
  SettlementInvoice({
    this.invoiceId = 0,
    this.invoiceNumber = 0,
    this.invoiceKind = 0,
    this.invoiceDate,
    this.dueDate,
    this.invoiceTotal = 0,
    this.settledAmount = 0,
    this.remainingAmount = 0,
  });

  final int invoiceId;
  final int invoiceNumber;
  final int invoiceKind;
  final DateTime? invoiceDate;
  final DateTime? dueDate;
  final double invoiceTotal;
  final double settledAmount;
  final double remainingAmount;

  String get kindTitle => switch (invoiceKind) {
    1 => 'فاکتور خرید',
    2 => 'فاکتور فروش',
    3 => 'برگشت از خرید',
    _ => 'برگشت از فروش',
  };

  factory SettlementInvoice.fromJson(Map<String, dynamic> j) =>
      SettlementInvoice(
        invoiceId: (j['invoiceId'] as num?)?.toInt() ?? 0,
        invoiceNumber: (j['invoiceNumber'] as num?)?.toInt() ?? 0,
        invoiceKind: (j['invoiceKind'] as num?)?.toInt() ?? 0,
        invoiceDate: DateTime.tryParse(
          (j['invoiceDate'] ?? '').toString(),
        )?.toLocal(),
        dueDate: DateTime.tryParse((j['dueDate'] ?? '').toString())?.toLocal(),
        invoiceTotal: _d(j['invoiceTotal']),
        settledAmount: _d(j['settledAmount']),
        remainingAmount: _d(j['remainingAmount']),
      );
}

/// سند دریافت / پرداخت / انتقال — `TrsVoucher`
class TreasuryVoucher {
  TreasuryVoucher({
    this.id = 0,
    this.number = 0,
    this.kind = TrsKind.receipt,
    this.date,
    this.partyId,
    this.partyName,
    this.description,
    this.refNumber,
    this.status = TrsState.draft,
    this.fromAccountId,
    this.fromAccountName,
    this.toAccountId,
    this.toAccountName,
    this.feeAmount = 0,
    this.invoiceId,
    this.invoiceNumber,
    List<InvoiceAllocation>? invoiceAllocations,
    List<VoucherLine>? lines,
    this.totalAmount = 0,
    this.cashAmount = 0,
    this.chequeAmount = 0,
    this.discountAmount = 0,
    this.voucherId,
    this.voucherNumber,
    this.lineCount = 0,
    this.createdBy,
    this.createdAt,
    this.confirmedBy,
    this.confirmedAt,
  }) : invoiceAllocations = invoiceAllocations ?? [],
       lines = lines ?? [];

  int id;
  int number;
  int kind;
  DateTime? date;
  int? partyId;
  String? partyName;
  String? description;
  String? refNumber;
  int status;

  // انتقال بین حساب‌ها
  int? fromAccountId;
  String? fromAccountName;
  int? toAccountId;
  String? toAccountName;
  double feeAmount;

  int? invoiceId;
  int? invoiceNumber;
  List<InvoiceAllocation> invoiceAllocations;
  List<VoucherLine> lines;

  double totalAmount;
  double cashAmount;
  double chequeAmount;
  double discountAmount;

  int? voucherId;
  int? voucherNumber;
  int lineCount;
  String? createdBy;
  DateTime? createdAt;
  String? confirmedBy;
  DateTime? confirmedAt;

  String get kindTitle => TrsKind.longTitle(kind);

  String get statusTitle => TrsState.title(status);

  bool get isIncoming => kind == TrsKind.receipt;

  bool get isTransfer => kind == TrsKind.transfer;

  /// فقط پیش‌نویس قابل ویرایش/قطعی/حذف است (قاعدهٔ وب و سرور)
  bool get isEditable => status == TrsState.draft;

  bool get isConfirmed => status == TrsState.confirmed;

  factory TreasuryVoucher.fromJson(Map<String, dynamic> j) => TreasuryVoucher(
    id: (j['id'] as num?)?.toInt() ?? 0,
    number: (j['number'] as num?)?.toInt() ?? 0,
    kind: (j['kind'] as num?)?.toInt() ?? 0,
    date: DateTime.tryParse((j['date'] ?? '').toString())?.toLocal(),
    partyId: (j['partyId'] as num?)?.toInt(),
    partyName: _s(j['partyName']),
    description: _s(j['description']),
    refNumber: _s(j['refNumber']),
    status: (j['status'] as num?)?.toInt() ?? 0,
    fromAccountId: (j['fromAccountId'] as num?)?.toInt(),
    fromAccountName: _s(j['fromAccountName']),
    toAccountId: (j['toAccountId'] as num?)?.toInt(),
    toAccountName: _s(j['toAccountName']),
    feeAmount: _d(j['feeAmount']),
    invoiceId: (j['invoiceId'] as num?)?.toInt(),
    invoiceNumber: (j['invoiceNumber'] as num?)?.toInt(),
    invoiceAllocations: (j['invoiceAllocations'] as List? ?? [])
        .whereType<Map>()
        .map((e) => InvoiceAllocation.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    lines: (j['lines'] as List? ?? [])
        .whereType<Map>()
        .map((e) => VoucherLine.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    totalAmount: _d(j['totalAmount']),
    cashAmount: _d(j['cashAmount']),
    chequeAmount: _d(j['chequeAmount']),
    discountAmount: _d(j['discountAmount']),
    voucherId: (j['voucherId'] as num?)?.toInt(),
    voucherNumber: (j['voucherNumber'] as num?)?.toInt(),
    lineCount: (j['lineCount'] as num?)?.toInt() ?? 0,
    createdBy: _s(j['createdBy']),
    createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal(),
    confirmedBy: _s(j['confirmedBy']),
    confirmedAt: DateTime.tryParse(
      (j['confirmedAt'] ?? '').toString(),
    )?.toLocal(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'kind': kind,
    'date': (date ?? DateTime.now()).toIso8601String(),
    'partyId': partyId,
    'description': _s(description),
    'refNumber': _s(refNumber),
    'status': status,
    'fromAccountId': fromAccountId,
    'toAccountId': toAccountId,
    'feeAmount': feeAmount,
    'invoiceId': invoiceId,
    'invoiceAllocations': [for (final a in invoiceAllocations) a.toJson()],
    'lines': [for (final l in lines) l.toJson()],
    'totalAmount': totalAmount,
  };
}

// ------------------------------------------------------------
//  ۳) چک — `TrsCheque`
// ------------------------------------------------------------

/// یک عملیات انجام‌شده روی چک — `TrsChequeAction`
class ChequeAction {
  ChequeAction({
    this.id = 0,
    this.chequeId = 0,
    this.status = 0,
    this.date,
    this.trsAccountId,
    this.trsAccountName,
    this.description,
    this.voucherNumber,
    this.createdBy,
    this.createdAt,
  });

  final int id;
  final int chequeId;
  final int status;
  final DateTime? date;
  final int? trsAccountId;
  final String? trsAccountName;
  final String? description;
  final int? voucherNumber;
  final String? createdBy;
  final DateTime? createdAt;

  String get statusTitle => switch (status) {
    0 => 'ثبت اولیه',
    1 => 'واگذاری به بانک',
    2 => 'وصول',
    3 => 'برگشت',
    4 => 'خرج چک',
    _ => 'ابطال',
  };

  factory ChequeAction.fromJson(Map<String, dynamic> j) => ChequeAction(
    id: (j['id'] as num?)?.toInt() ?? 0,
    chequeId: (j['chequeId'] as num?)?.toInt() ?? 0,
    status: (j['status'] as num?)?.toInt() ?? 0,
    date: DateTime.tryParse((j['date'] ?? '').toString())?.toLocal(),
    trsAccountId: (j['trsAccountId'] as num?)?.toInt(),
    trsAccountName: _s(j['trsAccountName']),
    description: _s(j['description']),
    voucherNumber: (j['voucherNumber'] as num?)?.toInt(),
    createdBy: _s(j['createdBy']),
    createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal(),
  );
}

/// چک دریافتی/پرداختی — `TrsCheque`
class TreasuryCheque {
  TreasuryCheque({
    this.id = 0,
    this.kind = ChequeKind.received,
    this.number = '',
    this.sayadId,
    this.amount = 0,
    this.issueDate,
    this.dueDate,
    this.bankName,
    this.branchName,
    this.accountNumber,
    this.ownerName,
    this.partyId,
    this.partyName,
    this.trsAccountId,
    this.trsAccountName,
    this.status = 0,
    this.statusDate,
    this.description,
    this.trsVoucherId,
    this.trsVoucherNumber,
    this.createdBy,
    this.createdAt,
    List<ChequeAction>? actions,
  }) : actions = actions ?? [];

  int id;
  int kind;
  String number;
  String? sayadId;
  double amount;
  DateTime? issueDate;
  DateTime? dueDate;
  String? bankName;
  String? branchName;
  String? accountNumber;
  String? ownerName;
  int? partyId;
  String? partyName;
  int? trsAccountId;
  String? trsAccountName;
  int status;
  DateTime? statusDate;
  String? description;
  int? trsVoucherId;
  int? trsVoucherNumber;
  String? createdBy;
  DateTime? createdAt;
  List<ChequeAction> actions;

  String get kindTitle => ChequeKind.title(kind);

  String get statusTitle => TrsChequeState.title(status, kind: kind);

  bool get isOpen => TrsChequeState.isOpen(status);

  bool get isCleared => status == TrsChequeState.cleared;

  bool get isBounced => status == TrsChequeState.bounced;

  /// همان `DaysToDue` سرور
  int get daysToDue =>
      (dueDate ?? DateTime.now()).difference(_today).inDays;

  bool get isOverdue => isOpen && daysToDue < 0;

  bool get isDueSoon => isOpen && daysToDue >= 0 && daysToDue <= 7;

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  factory TreasuryCheque.fromJson(Map<String, dynamic> j) => TreasuryCheque(
    id: (j['id'] as num?)?.toInt() ?? 0,
    kind: (j['kind'] as num?)?.toInt() ?? 0,
    number: (j['number'] ?? '').toString(),
    sayadId: _s(j['sayadId']),
    amount: _d(j['amount']),
    issueDate: DateTime.tryParse((j['issueDate'] ?? '').toString())?.toLocal(),
    dueDate: DateTime.tryParse((j['dueDate'] ?? '').toString())?.toLocal(),
    bankName: _s(j['bankName']),
    branchName: _s(j['branchName']),
    accountNumber: _s(j['accountNumber']),
    ownerName: _s(j['ownerName']),
    partyId: (j['partyId'] as num?)?.toInt(),
    partyName: _s(j['partyName']),
    trsAccountId: (j['trsAccountId'] as num?)?.toInt(),
    trsAccountName: _s(j['trsAccountName']),
    status: (j['status'] as num?)?.toInt() ?? 0,
    statusDate: DateTime.tryParse(
      (j['statusDate'] ?? '').toString(),
    )?.toLocal(),
    description: _s(j['description']),
    trsVoucherId: (j['trsVoucherId'] as num?)?.toInt(),
    trsVoucherNumber: (j['trsVoucherNumber'] as num?)?.toInt(),
    createdBy: _s(j['createdBy']),
    createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal(),
    actions: (j['actions'] as List? ?? [])
        .whereType<Map>()
        .map((e) => ChequeAction.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'number': number.trim(),
    'sayadId': _s(sayadId),
    'amount': amount,
    'issueDate': (issueDate ?? DateTime.now()).toIso8601String(),
    'dueDate': (dueDate ?? DateTime.now()).toIso8601String(),
    'bankName': _s(bankName),
    'branchName': _s(branchName),
    'accountNumber': _s(accountNumber),
    'ownerName': _s(ownerName),
    'partyId': partyId,
    'trsAccountId': trsAccountId,
    'description': _s(description),
  };
}

// ------------------------------------------------------------
//  ۴) گزارش گردش و داشبورد خزانه
// ------------------------------------------------------------

/// یک سطر گردش صندوق/بانک — `TrsFlowRow`
class FlowRow {
  FlowRow({
    this.date,
    this.trsVoucherId = 0,
    this.number = 0,
    this.kind = 0,
    this.method = '',
    this.partyName,
    this.description,
    this.refNumber,
    this.inAmount = 0,
    this.out = 0,
    this.balance = 0,
  });

  final DateTime? date;
  final int trsVoucherId;
  final int number;
  final int kind;
  final String method;
  final String? partyName;
  final String? description;
  final String? refNumber;
  final double inAmount;
  final double out;
  final double balance;

  factory FlowRow.fromJson(Map<String, dynamic> j) => FlowRow(
    date: DateTime.tryParse((j['date'] ?? '').toString())?.toLocal(),
    trsVoucherId: (j['trsVoucherId'] as num?)?.toInt() ?? 0,
    number: (j['number'] as num?)?.toInt() ?? 0,
    kind: (j['kind'] as num?)?.toInt() ?? 0,
    method: (j['method'] ?? '').toString(),
    partyName: _s(j['partyName']),
    description: _s(j['description']),
    refNumber: _s(j['refNumber']),
    inAmount: _d(j['in']),
    out: _d(j['out']),
    balance: _d(j['balance']),
  );
}

/// خروجی گزارش گردش — `TrsFlowResult`
class FlowResult {
  FlowResult({
    this.trsAccountId = 0,
    this.accountName = '',
    this.accountKindTitle = '',
    this.from,
    this.to,
    this.openingBalance = 0,
    List<FlowRow>? rows,
    this.totalIn = 0,
    this.totalOut = 0,
    this.closingBalance = 0,
  }) : rows = rows ?? [];

  final int trsAccountId;
  final String accountName;
  final String accountKindTitle;
  final DateTime? from;
  final DateTime? to;
  final double openingBalance;
  final List<FlowRow> rows;
  final double totalIn;
  final double totalOut;
  final double closingBalance;

  factory FlowResult.fromJson(Map<String, dynamic> j) => FlowResult(
    trsAccountId: (j['trsAccountId'] as num?)?.toInt() ?? 0,
    accountName: (j['accountName'] ?? '').toString(),
    accountKindTitle: (j['accountKindTitle'] ?? '').toString(),
    from: DateTime.tryParse((j['from'] ?? '').toString())?.toLocal(),
    to: DateTime.tryParse((j['to'] ?? '').toString())?.toLocal(),
    openingBalance: _d(j['openingBalance']),
    rows: (j['rows'] as List? ?? [])
        .whereType<Map>()
        .map((e) => FlowRow.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    totalIn: _d(j['totalIn']),
    totalOut: _d(j['totalOut']),
    closingBalance: _d(j['closingBalance']),
  );
}

/// داشبورد خزانه — `TrsDashboard`
class TreasuryDashboard {
  TreasuryDashboard({
    List<TreasuryAccount>? accounts,
    this.totalBalance = 0,
    this.totalCashBalance = 0,
    this.totalBankBalance = 0,
    this.periodIn = 0,
    this.periodOut = 0,
    this.receiptCount = 0,
    this.paymentCount = 0,
    this.draftCount = 0,
    this.receivedChequeTotal = 0,
    this.issuedChequeTotal = 0,
    this.receivedChequeCount = 0,
    this.issuedChequeCount = 0,
    this.overdueChequeCount = 0,
    this.overdueChequeTotal = 0,
    List<TreasuryCheque>? upcomingCheques,
  }) : accounts = accounts ?? [],
       upcomingCheques = upcomingCheques ?? [];

  final List<TreasuryAccount> accounts;
  final double totalBalance;
  final double totalCashBalance;
  final double totalBankBalance;
  final double periodIn;
  final double periodOut;
  final int receiptCount;
  final int paymentCount;
  final int draftCount;
  final double receivedChequeTotal;
  final double issuedChequeTotal;
  final int receivedChequeCount;
  final int issuedChequeCount;
  final int overdueChequeCount;
  final double overdueChequeTotal;
  final List<TreasuryCheque> upcomingCheques;

  factory TreasuryDashboard.fromJson(Map<String, dynamic> j) =>
      TreasuryDashboard(
        accounts: (j['accounts'] as List? ?? [])
            .whereType<Map>()
            .map((e) => TreasuryAccount.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        totalBalance: _d(j['totalBalance']),
        totalCashBalance: _d(j['totalCashBalance']),
        totalBankBalance: _d(j['totalBankBalance']),
        periodIn: _d(j['periodIn']),
        periodOut: _d(j['periodOut']),
        receiptCount: (j['receiptCount'] as num?)?.toInt() ?? 0,
        paymentCount: (j['paymentCount'] as num?)?.toInt() ?? 0,
        draftCount: (j['draftCount'] as num?)?.toInt() ?? 0,
        receivedChequeTotal: _d(j['receivedChequeTotal']),
        issuedChequeTotal: _d(j['issuedChequeTotal']),
        receivedChequeCount: (j['receivedChequeCount'] as num?)?.toInt() ?? 0,
        issuedChequeCount: (j['issuedChequeCount'] as num?)?.toInt() ?? 0,
        overdueChequeCount: (j['overdueChequeCount'] as num?)?.toInt() ?? 0,
        overdueChequeTotal: _d(j['overdueChequeTotal']),
        upcomingCheques: (j['upcomingCheques'] as List? ?? [])
            .whereType<Map>()
            .map((e) => TreasuryCheque.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

// ------------------------------------------------------------
//  ۵) مدیریت چک و اقساط فروشگاهی (shop/credit-management)
// ------------------------------------------------------------

/// چک فروشگاهی — `ShopChequeItem`
class ShopCheque {
  ShopCheque({
    this.id = 0,
    this.transactionId = 0,
    this.orderNumber = '',
    this.transactionType = 0,
    this.partyId = 0,
    this.partyName = '',
    this.partyMobile,
    this.number = '',
    this.bankName,
    this.accountInfo,
    this.ownerName,
    this.amount = 0,
    this.dueDate,
    this.isCleared = false,
    this.clearedAt,
    this.status = 0,
    this.bouncedAt,
    this.bounceReason,
    this.note,
    this.daysOverdue = 0,
  });

  final int id;
  final int transactionId;
  final String orderNumber;

  /// ۱ = خرید (پرداختی ما) · ۲ = فروش (دریافتی)
  final int transactionType;
  final int partyId;
  final String partyName;
  final String? partyMobile;
  final String number;
  final String? bankName;
  final String? accountInfo;
  final String? ownerName;
  final double amount;
  final DateTime? dueDate;
  final bool isCleared;
  final DateTime? clearedAt;
  final int status;
  final DateTime? bouncedAt;
  final String? bounceReason;
  final String? note;
  final int daysOverdue;

  bool get isReceivable => transactionType == 2;

  bool get isBounced => status == TrsChequeState.bounced;

  factory ShopCheque.fromJson(Map<String, dynamic> j) => ShopCheque(
    id: (j['id'] as num?)?.toInt() ?? 0,
    transactionId: (j['transactionId'] as num?)?.toInt() ?? 0,
    orderNumber: (j['orderNumber'] ?? '').toString(),
    transactionType: (j['transactionType'] as num?)?.toInt() ?? 0,
    partyId: (j['partyId'] as num?)?.toInt() ?? 0,
    partyName: (j['partyName'] ?? '').toString(),
    partyMobile: _s(j['partyMobile']),
    number: (j['number'] ?? '').toString(),
    bankName: _s(j['bankName']),
    accountInfo: _s(j['accountInfo']),
    ownerName: _s(j['ownerName']),
    amount: _d(j['amount']),
    dueDate: DateTime.tryParse((j['dueDate'] ?? '').toString())?.toLocal(),
    isCleared: j['isCleared'] == true,
    clearedAt: DateTime.tryParse((j['clearedAt'] ?? '').toString())?.toLocal(),
    status: (j['status'] as num?)?.toInt() ?? 0,
    bouncedAt: DateTime.tryParse((j['bouncedAt'] ?? '').toString())?.toLocal(),
    bounceReason: _s(j['bounceReason']),
    note: _s(j['note']),
    daysOverdue: (j['daysOverdue'] as num?)?.toInt() ?? 0,
  );
}

/// قسط فروشگاهی — `ShopInstallmentItem`
class ShopInstallment {
  ShopInstallment({
    this.id = 0,
    this.transactionId = 0,
    this.orderNumber = '',
    this.partyId = 0,
    this.partyName = '',
    this.partyMobile,
    this.no = 1,
    this.amount = 0,
    this.dueDate,
    this.isPaid = false,
    this.paidAt,
    this.daysOverdue = 0,
  });

  final int id;
  final int transactionId;
  final String orderNumber;
  final int partyId;
  final String partyName;
  final String? partyMobile;
  final int no;
  final double amount;
  final DateTime? dueDate;
  final bool isPaid;
  final DateTime? paidAt;
  final int daysOverdue;

  factory ShopInstallment.fromJson(Map<String, dynamic> j) => ShopInstallment(
    id: (j['id'] as num?)?.toInt() ?? 0,
    transactionId: (j['transactionId'] as num?)?.toInt() ?? 0,
    orderNumber: (j['orderNumber'] ?? '').toString(),
    partyId: (j['partyId'] as num?)?.toInt() ?? 0,
    partyName: (j['partyName'] ?? '').toString(),
    partyMobile: _s(j['partyMobile']),
    no: (j['no'] as num?)?.toInt() ?? 1,
    amount: _d(j['amount']),
    dueDate: DateTime.tryParse((j['dueDate'] ?? '').toString())?.toLocal(),
    isPaid: j['isPaid'] == true,
    paidAt: DateTime.tryParse((j['paidAt'] ?? '').toString())?.toLocal(),
    daysOverdue: (j['daysOverdue'] as num?)?.toInt() ?? 0,
  );
}

/// خلاصهٔ چک و اقساط — `ShopCreditSummary`
class ShopCreditSummary {
  ShopCreditSummary({
    this.inHandChequesCount = 0,
    this.inHandChequesTotal = 0,
    this.clearedChequesCount = 0,
    this.clearedChequesTotal = 0,
    this.bouncedChequesCount = 0,
    this.bouncedChequesTotal = 0,
    this.pendingInstallmentsCount = 0,
    this.pendingInstallmentsTotal = 0,
    this.paidInstallmentsCount = 0,
    this.paidInstallmentsTotal = 0,
    this.overdueInstallmentsCount = 0,
    this.overdueInstallmentsTotal = 0,
  });

  final int inHandChequesCount;
  final double inHandChequesTotal;
  final int clearedChequesCount;
  final double clearedChequesTotal;
  final int bouncedChequesCount;
  final double bouncedChequesTotal;
  final int pendingInstallmentsCount;
  final double pendingInstallmentsTotal;
  final int paidInstallmentsCount;
  final double paidInstallmentsTotal;
  final int overdueInstallmentsCount;
  final double overdueInstallmentsTotal;

  /// همان کارت چهارم وب: وصولی‌های قطعی = چک‌های وصول‌شده + اقساط پرداخت‌شده
  int get collectedCount => clearedChequesCount + paidInstallmentsCount;

  double get collectedTotal => clearedChequesTotal + paidInstallmentsTotal;

  factory ShopCreditSummary.fromJson(Map<String, dynamic> j) =>
      ShopCreditSummary(
        inHandChequesCount: (j['inHandChequesCount'] as num?)?.toInt() ?? 0,
        inHandChequesTotal: _d(j['inHandChequesTotal']),
        clearedChequesCount: (j['clearedChequesCount'] as num?)?.toInt() ?? 0,
        clearedChequesTotal: _d(j['clearedChequesTotal']),
        bouncedChequesCount: (j['bouncedChequesCount'] as num?)?.toInt() ?? 0,
        bouncedChequesTotal: _d(j['bouncedChequesTotal']),
        pendingInstallmentsCount:
            (j['pendingInstallmentsCount'] as num?)?.toInt() ?? 0,
        pendingInstallmentsTotal: _d(j['pendingInstallmentsTotal']),
        paidInstallmentsCount:
            (j['paidInstallmentsCount'] as num?)?.toInt() ?? 0,
        paidInstallmentsTotal: _d(j['paidInstallmentsTotal']),
        overdueInstallmentsCount:
            (j['overdueInstallmentsCount'] as num?)?.toInt() ?? 0,
        overdueInstallmentsTotal: _d(j['overdueInstallmentsTotal']),
      );
}

/// گزینهٔ حساب حسابداری برای اتصال صندوق/بانک — `LookupItem`
class AccLookup {
  const AccLookup({required this.id, required this.name});

  final int id;
  final String name;

  factory AccLookup.fromJson(Map<String, dynamic> j) => AccLookup(
    id: (j['id'] as num?)?.toInt() ?? 0,
    name: (j['name'] ?? '').toString(),
  );
}

/// کمک‌تابع: تقسیم مبلغ اقساط با گرد کردن ریالی (همان منطق وب)
/// آخرین قسط باقی‌مانده را می‌گیرد تا جمع دقیقاً برابر کل باشد.
List<double> splitInstallments(double total, int count) {
  if (count <= 0) return const [];
  final each = (total / count).roundToDouble();
  final list = <double>[];
  for (var i = 0; i < count; i++) {
    list.add(i == count - 1 ? total - each * (count - 1) : each);
  }
  return list;
}

/// بازهٔ تاریخ ماه جاری — کمک برای فیلترها
({DateTime from, DateTime to}) currentMonthRange([DateTime? now]) {
  final n = now ?? DateTime.now();
  return (
    from: DateTime(n.year, n.month, 1),
    to: DateTime(n.year, n.month + 1, 0),
  );
}

/// کوچک‌ترین مضرب برای نمایش «روز» در نمودارها
double niceMax(Iterable<double> values) {
  var m = 0.0;
  for (final v in values) {
    if (v > m) m = v;
  }
  return m <= 0 ? 0 : math.max(1, m);
}
