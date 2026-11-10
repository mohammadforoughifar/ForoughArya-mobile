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
