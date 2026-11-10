// ============================================================
//  مدل‌های «درخواست خدمت IT» — فاز ۹-ب
//  منبع (عیناً، بدون فیلد اضافه):
//    Inventory.Api/Entities/ItAssets/ItRequest.cs
//    Inventory.Api/Controllers/ItAssets/ItRequestsController.cs → ToItem / ToPageList
//    اعداد و متن‌ها از Pages/ItAssets/ItRequests.razor
// ============================================================

/// نوع درخواست — همان `TypeFa` وب
class ItRequestType {
  static const hardware = 'Hardware';
  static const software = 'Software';
  static const network = 'Network';
  static const telecom = 'Telecom';

  static const all = [hardware, software, network, telecom];

  static String label(String t) => switch (t) {
    software => 'نرم‌افزار',
    network => 'شبکه و زیرساخت',
    telecom => 'مخابرات',
    _ => 'سخت‌افزار',
  };
}

/// وضعیت‌ها — رشته‌های سرور
class ItRequestStatus {
  static const created = 'New';
  static const assigned = 'Assigned';
  static const managerApproved = 'ManagerApproved';
  static const completed = 'Completed';
  static const rejected = 'Rejected';

  /// همان `StatusBadge` وب — تفاوت متن بین نمای «درخواست‌های من» و کارتابل
  static String label(String status, {bool requesterView = false}) =>
      switch (status) {
        created => 'ثبت شده',
        assigned => requesterView ? 'در حال بررسی' : 'ارجاع شده',
        managerApproved =>
          requesterView ? 'در انتظار تایید شما' : 'پاسخ ارسال شده',
        completed => 'تکمیل شده ✔',
        rejected => 'رد شده ✖',
        _ => status,
      };
}

/// یک ارجاع به کارشناس — آینهٔ `ItRequestAssignment`
class ItAssignment {
  const ItAssignment({
    this.id = 0,
    this.expertUserId = 0,
    this.expertName = '',
    this.managerInstruction,
    this.expertReport,
    this.reportSubmitted = false,
    this.done,
    this.managerDecision,
    this.managerDecisionNote,
    this.includeInFinal = true,
    this.repliedAt,
  });

  final int id;
  final int expertUserId;
  final String expertName;
  final String? managerInstruction;
  final String? expertReport;
  final bool reportSubmitted;

  /// true=انجام شد | false=انجام نشد | null=هنوز پاسخ نداده
  final bool? done;

  /// Approved | Rejected | null
  final String? managerDecision;
  final String? managerDecisionNote;
  final bool includeInFinal;
  final DateTime? repliedAt;

  bool get approved => managerDecision == 'Approved';
  bool get pendingDecision => reportSubmitted && managerDecision == null;

  factory ItAssignment.fromJson(Map<String, dynamic> j) => ItAssignment(
    id: (j['id'] as num?)?.toInt() ?? 0,
    expertUserId: (j['expertUserId'] as num?)?.toInt() ?? 0,
    expertName: (j['expertName'] ?? '').toString(),
    managerInstruction: _s(j['managerInstruction']),
    expertReport: _s(j['expertReport']),
    reportSubmitted: j['reportSubmitted'] == true,
    done: j['done'] is bool ? j['done'] as bool : null,
    managerDecision: _s(j['managerDecision']),
    managerDecisionNote: _s(j['managerDecisionNote']),
    includeInFinal: j['includeInFinal'] != false,
    repliedAt: _d(j['repliedAt']),
  );
}

/// یک درخواست خدمت IT — آینهٔ آیتم `ToItem` کنترلر
class ItRequestItem {
  const ItRequestItem({
    this.id = 0,
    this.number = '',
    this.seen = true,
    this.requesterName = '',
    this.requesterUserId = 0,
    this.systemInfoId,
    this.systemLabel,
    this.requestType = ItRequestType.hardware,
    this.title = '',
    this.description = '',
    this.status = ItRequestStatus.created,
    this.isExternal = false,
    this.sourceCompanyId,
    this.companyName,
    this.companyCode,
    this.requesterPhone,
    this.requesterEmail,
    this.managerNote,
    this.finalResponse,
    this.createdAt,
    this.assignedAt,
    this.approvedAt,
    this.completedAt,
    this.attachmentCount = 0,
    this.assignments = const [],
  });

  final int id;
  final String number;

  /// سرور: `Seen = رویت‌شده توسط کاربر جاری`
  final bool seen;
  final String requesterName;
  final int requesterUserId;
  final int? systemInfoId;
  final String? systemLabel;
  final String requestType;
  final String title;
  final String description;
  final String status;
  final bool isExternal;
  final int? sourceCompanyId;
  final String? companyName;
  final String? companyCode;
  final String? requesterPhone;
  final String? requesterEmail;
  final String? managerNote;
  final String? finalResponse;
  final DateTime? createdAt;
  final DateTime? assignedAt;
  final DateTime? approvedAt;
  final DateTime? completedAt;
  final int attachmentCount;
  final List<ItAssignment> assignments;

  bool get isNew => !seen;
  int get reportsSubmitted => assignments.where((a) => a.reportSubmitted).length;
  bool get allReportsSubmitted =>
      assignments.isNotEmpty && reportsSubmitted == assignments.length;
  bool get allApproved =>
      assignments.isNotEmpty && assignments.every((a) => a.approved);

  /// معادل `r.Status is "New" or "Assigned"` وب
  bool get open => status == ItRequestStatus.created ||
      status == ItRequestStatus.assigned;

  factory ItRequestItem.fromJson(Map<String, dynamic> j) => ItRequestItem(
    id: (j['id'] as num?)?.toInt() ?? 0,
    number: (j['number'] ?? '').toString(),
    seen: j['seen'] != false,
    requesterName: (j['requesterName'] ?? '').toString(),
    requesterUserId: (j['requesterUserId'] as num?)?.toInt() ?? 0,
    systemInfoId: (j['systemInfoId'] as num?)?.toInt(),
    systemLabel: _s(j['systemLabel']),
    requestType: (j['requestType'] ?? ItRequestType.hardware).toString(),
    title: (j['title'] ?? '').toString(),
    description: (j['description'] ?? '').toString(),
    status: (j['status'] ?? ItRequestStatus.created).toString(),
    isExternal: j['isExternal'] == true,
    sourceCompanyId: (j['sourceCompanyId'] as num?)?.toInt(),
    companyName: _s(j['companyName']),
    companyCode: _s(j['companyCode']),
    requesterPhone: _s(j['requesterPhone']),
    requesterEmail: _s(j['requesterEmail']),
    managerNote: _s(j['managerNote']),
    finalResponse: _s(j['finalResponse']),
    createdAt: _d(j['createdAt']),
    assignedAt: _d(j['assignedAt']),
    approvedAt: _d(j['approvedAt']),
    completedAt: _d(j['completedAt']),
    attachmentCount: (j['attachmentCount'] as num?)?.toInt() ?? 0,
    assignments: (j['assignments'] as List? ?? [])
        .whereType<Map>()
        .map((e) => ItAssignment.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

/// پاسخ صفحه‌بندی‌شدهٔ `{ total, items }` (قرارداد Paging سرور)
class Paged<T> {
  const Paged({this.total = 0, this.items = const []});
  final int total;
  final List<T> items;
}

/// دسترسی کاربر جاری — آینهٔ `GET api/itrequests/my-access`
class ItAccess {
  const ItAccess({
    this.userId = 0,
    this.canCreate = false,
    this.isExpert = false,
    this.isManager = false,
  });

  final int userId;
  final bool canCreate;
  final bool isExpert;
  final bool isManager;

  factory ItAccess.fromJson(Map<String, dynamic> j) => ItAccess(
    userId: (j['userId'] as num?)?.toInt() ?? 0,
    canCreate: j['canCreate'] == true,
    isExpert: j['isExpert'] == true,
    isManager: j['isManager'] == true,
  );
}

/// گزینهٔ سیستم برای انتخاب در فرم — `GET api/itrequests/systems`
class ItSystemOption {
  const ItSystemOption({
    this.id = 0,
    this.label = '',
    this.ip = '',
    this.userName = '',
    this.departmentName = '',
  });

  final int id;
  final String label;
  final String ip;
  final String userName;
  final String departmentName;

  /// معادل `SysLabel` وب: «label — userName — department» و در نهایت آی‌پی
  String get display {
    final parts = <String>[
      if (label.trim().isNotEmpty) label.trim(),
      if (userName.trim().isNotEmpty) userName.trim(),
      if (departmentName.trim().isNotEmpty) departmentName.trim(),
    ];
    if (parts.isEmpty) return ip.trim().isEmpty ? 'سیستم #$id' : ip;
    return parts.join(' — ');
  }

  factory ItSystemOption.fromJson(Map<String, dynamic> j) => ItSystemOption(
    id: (j['id'] as num?)?.toInt() ?? 0,
    label: (j['label'] ?? '').toString(),
    ip: (j['ip'] ?? '').toString(),
    userName: (j['userName'] ?? '').toString(),
    departmentName: (j['departmentName'] ?? '').toString(),
  );
}

/// کارشناس قابل ارجاع — `GET api/itrequests/experts`
class ItExpert {
  const ItExpert({this.id = 0, this.username = ''});
  final int id;
  final String username;

  factory ItExpert.fromJson(Map<String, dynamic> j) => ItExpert(
    id: (j['id'] as num?)?.toInt() ?? 0,
    username: (j['username'] ?? '').toString(),
  );
}

/// یک ردیف آرشیو — `GET api/itrequests/{id}/logs`
class ItLogRow {
  const ItLogRow({
    this.id = 0,
    this.actorName = '',
    this.actorRole = 'System',
    this.action = '',
    this.text,
    this.createdAt,
  });

  final int id;
  final String actorName;
  final String actorRole;
  final String action;
  final String? text;
  final DateTime? createdAt;

  /// همان `RoleFa` وب
  String get roleTitle => switch (actorRole) {
    'Manager' => 'مدیر',
    'Expert' => 'کارشناس',
    'System' => 'سیستم',
    _ => 'درخواست‌دهنده',
  };

  /// همان `ActionFa` وب
  String get actionTitle => switch (action) {
    'Created' => 'ثبت درخواست',
    'Assigned' => 'ارجاع',
    'Report' => 'ثبت گزارش',
    'Approved' => 'تایید گزارش',
    'Rejected' => 'رد گزارش',
    'Finalized' => 'پاسخ نهایی',
    'Completed' => 'تکمیل',
    _ => action,
  };

  factory ItLogRow.fromJson(Map<String, dynamic> j) => ItLogRow(
    id: (j['id'] as num?)?.toInt() ?? 0,
    actorName: (j['actorName'] ?? '').toString(),
    actorRole: (j['actorRole'] ?? 'System').toString(),
    action: (j['action'] ?? '').toString(),
    text: _s(j['text']),
    createdAt: _d(j['createdAt']),
  );
}

/// پیوست — `GET api/itrequests/{id}/attachments`
class ItAttachment {
  const ItAttachment({
    this.id = 0,
    this.fileName = '',
    this.contentType = '',
    this.uploaderRole = 'Requester',
    this.uploaderName = '',
    this.uploadedAt,
    this.size = 0,
  });

  final int id;
  final String fileName;
  final String contentType;
  final String uploaderRole;
  final String uploaderName;
  final DateTime? uploadedAt;
  final int size;

  /// `RoleFa` وب
  String get roleTitle => switch (uploaderRole) {
    'Manager' => 'مدیر',
    'Expert' => 'کارشناس',
    'System' => 'سیستم',
    _ => 'درخواست‌دهنده',
  };

  String get sizeText {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory ItAttachment.fromJson(Map<String, dynamic> j) => ItAttachment(
    id: (j['id'] as num?)?.toInt() ?? 0,
    fileName: (j['fileName'] ?? '').toString(),
    contentType: (j['contentType'] ?? '').toString(),
    uploaderRole: (j['uploaderRole'] ?? 'Requester').toString(),
    uploaderName: (j['uploaderName'] ?? '').toString(),
    uploadedAt: _d(j['uploadedAt']),
    size: (j['size'] as num?)?.toInt() ?? 0,
  );
}

/// شرکت راه‌دور — `GET api/itrequests/client-companies`
class ItClientCompany {
  const ItClientCompany({
    this.id = 0,
    this.code = '',
    this.name = '',
    this.phone,
    this.isActive = true,
    this.hourlyLimit = 60,
    this.note,
    this.apiKeyHint,
    this.createdAt,
    this.keyRotatedAt,
    this.requestCount = 0,
    this.openCount = 0,
  });

  final int id;
  final String code;
  final String name;
  final String? phone;
  final bool isActive;
  final int hourlyLimit;
  final String? note;
  final String? apiKeyHint;
  final DateTime? createdAt;
  final DateTime? keyRotatedAt;
  final int requestCount;
  final int openCount;

  factory ItClientCompany.fromJson(Map<String, dynamic> j) => ItClientCompany(
    id: (j['id'] as num?)?.toInt() ?? 0,
    code: (j['code'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    phone: _s(j['phone']),
    isActive: j['isActive'] != false,
    hourlyLimit: (j['hourlyLimit'] as num?)?.toInt() ?? 60,
    note: _s(j['note']),
    apiKeyHint: _s(j['apiKeyHint']),
    createdAt: _d(j['createdAt']),
    keyRotatedAt: _d(j['keyRotatedAt']),
    requestCount: (j['requestCount'] as num?)?.toInt() ?? 0,
    openCount: (j['openCount'] as num?)?.toInt() ?? 0,
  );
}

DateTime? _d(dynamic v) {
  final s = v?.toString();
  if (s == null || s.isEmpty || s == 'null') return null;
  return DateTime.tryParse(s)?.toLocal();
}

String? _s(dynamic v) {
  final s = v?.toString();
  return (s == null || s.isEmpty || s == 'null') ? null : s;
}
