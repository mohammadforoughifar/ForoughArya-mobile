// ============================================================
//  مدل‌های «سیستم‌های ثبت‌شده / شناسنامه / ثبت دستی / کاربران سیستم» — فاز ۹-ج
//  منبع: `Inventory.Api/Controllers/ItAssets/SystemInfoController.cs` و
//        `Inventory.Client/Pages/ItAssets/SystemInfoList.razor`، `SystemId.razor`،
//        `SystemManualCreate.razor` و `Pages/System/SystemUsers.razor`
//  همهٔ نام‌های فیلد عیناً همان کلیدهای JSON سرور هستند.
// ============================================================

int _i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
int? _ni(Object? v) {
  if (v == null) return null;
  final n = v is num ? v.toInt() : int.tryParse('$v');
  return (n == null || n <= 0) ? null : n;
}

double _d(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

bool _b(Object? v) => v == true || v == 1 || '$v'.toLowerCase() == 'true';

String _s(Object? v) => v == null ? '' : '$v';

String? _ns(Object? v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

Map<String, dynamic> asMap(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Map<String, dynamic>> asRows(Object? v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];

// ============================================================
//  سیستم ثبت‌شده — همان شکل `GET api/SystemInfo`
// ============================================================

class SystemInfoItem {
  const SystemInfoItem({
    this.id = 0,
    this.agentId = '',
    this.isApproved = false,
    this.receivedAt,
    this.userId,
    this.companyId,
    this.departmentId,
    this.pendingPayloadJson,
    this.cpu = '',
    this.totalRamGb = 0,
    this.ram,
    this.motherboard,
    this.ip = '',
    this.osName,
    this.health,
    this.detailsJson,
    this.hardDisk,
    this.graphics,
    this.monitor,
  });

  final int id;
  final String agentId;
  final bool isApproved;
  final DateTime? receivedAt;
  final int? userId;
  final int? companyId;
  final int? departmentId;
  final String? pendingPayloadJson;

  final String cpu;
  final int totalRamGb;
  final String? ram;
  final String? motherboard;
  final String ip;
  final String? osName;
  final int? health;

  // فقط در پاسخ «تک‌رکورد» (`GET api/SystemInfo/{id}`) می‌آید
  final String? detailsJson;
  final String? hardDisk;
  final String? graphics;
  final String? monitor;

  factory SystemInfoItem.fromJson(Map<String, dynamic> j) => SystemInfoItem(
    id: _i(j['id']),
    agentId: _s(j['agentId']),
    isApproved: _b(j['isApproved']),
    receivedAt: DateTime.tryParse(_s(j['receivedAt'])),
    userId: _ni(j['userId']),
    companyId: _ni(j['companyId']),
    departmentId: _ni(j['departmentId']),
    pendingPayloadJson: _ns(j['pendingPayloadJson']),
    cpu: _s(j['cpu']),
    totalRamGb: _i(j['totalRamGb']),
    ram: _ns(j['ram']),
    motherboard: _ns(j['motherboard']),
    ip: _s(j['ip']),
    osName: _ns(j['osName']),
    health: j.containsKey('health') ? _ni(j['health']) ?? (j['health'] == 0 ? 0 : null) : null,
    detailsJson: _ns(j['detailsJson']),
    hardDisk: _ns(j['hardDisk']),
    graphics: _ns(j['graphics']),
    monitor: _ns(j['monitor']),
  );

  /// آیا تغییرات معلق (در انتظار تایید) دارد؟ — `!string.IsNullOrEmpty(PendingPayloadJson)`
  bool get hasPending => (pendingPayloadJson ?? '').trim().isNotEmpty;

  /// CPU معلق از JSON — همان `PendingCpu()` وب (کلید `cpu`)
  String? get pendingCpu {
    final raw = pendingPayloadJson;
    if (raw == null || raw.trim().isEmpty) return null;
    final m = RegExp(
      r'"cpu"\s*:\s*"((?:[^"\\]|\\.)*)"',
      caseSensitive: false,
    ).firstMatch(raw);
    if (m == null) return null;
    final v = m.group(1)!;
    return v.isEmpty ? null : v.replaceAll(r'\"', '"');
  }

  /// متن ستون RAM وب: اگر TotalRamGb > 0 → «N GB» وگرنه رشتهٔ Ram
  String get ramCell => totalRamGb > 0 ? '$totalRamGb GB' : (ram ?? '').isEmpty ? '—' : ram!;

  String get cpuCell => cpu.trim().isEmpty ? '—' : cpu;
  String get motherboardCell => (motherboard ?? '').trim().isEmpty ? '—' : motherboard!;
}

// ============================================================
//  قطعات سخت‌افزاری — `GET api/SystemInfo/{id}/components`
// ============================================================

class SystemBoard {
  const SystemBoard({
    this.board = '',
    this.boardSerial = '',
    this.computerModel = '',
  });
  final String board;
  final String boardSerial;
  final String computerModel;

  factory SystemBoard.fromJson(Map<String, dynamic> j) => SystemBoard(
    board: _s(j['board']),
    boardSerial: _s(j['boardSerial']),
    computerModel: _s(j['computerModel']),
  );

  bool get isEmpty =>
      board.trim().isEmpty &&
      computerModel.trim().isEmpty &&
      boardSerial.trim().isEmpty;
}

class SystemCpuRow {
  const SystemCpuRow({
    this.name = '',
    this.cores = 0,
    this.threads = 0,
    this.clockGhz = 0,
  });
  final String name;
  final int cores;
  final int threads;
  final double clockGhz;

  factory SystemCpuRow.fromJson(Map<String, dynamic> j) => SystemCpuRow(
    name: _s(j['name']),
    cores: _i(j['cores']),
    threads: _i(j['threads']),
    clockGhz: _d(j['clockGhz']),
  );
}

class SystemRamRow {
  const SystemRamRow({
    this.slot = '',
    this.capacityGb = 0,
    this.type = '',
    this.speedMhz = 0,
    this.manufacturer = '',
    this.partNumber = '',
    this.serialNumber = '',
  });
  final String slot;
  final int capacityGb;
  final String type;
  final int speedMhz;
  final String manufacturer;
  final String partNumber;
  final String serialNumber;

  factory SystemRamRow.fromJson(Map<String, dynamic> j) => SystemRamRow(
    slot: _s(j['slot']),
    capacityGb: _i(j['capacityGb']),
    type: _s(j['type']),
    speedMhz: _i(j['speedMhz']),
    manufacturer: _s(j['manufacturer']),
    partNumber: _s(j['partNumber']),
    serialNumber: _s(j['serialNumber']),
  );
}

class SystemDiskRow {
  const SystemDiskRow({
    this.model = '',
    this.sizeGb = 0,
    this.interface = '',
    this.serialNumber = '',
    this.smartStatus,
  });
  final String model;
  final int sizeGb;
  final String interface;
  final String serialNumber;
  final String? smartStatus;

  factory SystemDiskRow.fromJson(Map<String, dynamic> j) => SystemDiskRow(
    model: _s(j['model']),
    sizeGb: _i(j['sizeGb']),
    interface: _s(j['interface']),
    serialNumber: _s(j['serialNumber']),
    smartStatus: _ns(j['smartStatus']),
  );

  /// همان شرط وب: `SmartStatus == "PredFail" || "Failed"`
  bool get smartBad => smartStatus == 'PredFail' || smartStatus == 'Failed';
}

class SystemGpuRow {
  const SystemGpuRow({this.name = '', this.resolution = ''});
  final String name;
  final String resolution;

  factory SystemGpuRow.fromJson(Map<String, dynamic> j) =>
      SystemGpuRow(name: _s(j['name']), resolution: _s(j['resolution']));
}

class SystemMonitorRow {
  const SystemMonitorRow({
    this.name = '',
    this.resolution = '',
    this.serialNumber = '',
    this.isPrimary = false,
  });
  final String name;
  final String resolution;
  final String serialNumber;
  final bool isPrimary;

  factory SystemMonitorRow.fromJson(Map<String, dynamic> j) => SystemMonitorRow(
    name: _s(j['name']),
    resolution: _s(j['resolution']),
    serialNumber: _s(j['serialNumber']),
    isPrimary: _b(j['isPrimary']),
  );
}

class SystemNetRow {
  const SystemNetRow({
    this.name = '',
    this.description = '',
    this.type = '',
    this.macAddress = '',
    this.ipv4 = '',
    this.gateway = '',
  });
  final String name;
  final String description;
  final String type;
  final String macAddress;
  final String ipv4;
  final String gateway;

  factory SystemNetRow.fromJson(Map<String, dynamic> j) => SystemNetRow(
    name: _s(j['name']),
    description: _s(j['description']),
    type: _s(j['type']),
    macAddress: _s(j['macAddress']),
    ipv4: _s(j['ipv4']),
    gateway: _s(j['gateway']),
  );

  /// همان `NetTypeName()` وب
  String get typeFa => switch (type) {
    'Wireless' => 'بی‌سیم',
    'Ethernet' => 'کابلی',
    'Loopback' => 'لوپ‌بک',
    'Virtual' => 'مجازی',
    _ => type.trim().isEmpty ? 'نامشخص' : type,
  };
}

class SystemVolumeRow {
  const SystemVolumeRow({
    this.letter = '',
    this.label = '',
    this.totalGb = 0,
    this.usedGb = 0,
  });
  final String letter;
  final String label;
  final int totalGb;
  final int usedGb;

  factory SystemVolumeRow.fromJson(Map<String, dynamic> j) => SystemVolumeRow(
    letter: _s(j['letter']),
    label: _s(j['label']),
    totalGb: _i(j['totalGb']),
    usedGb: _i(j['usedGb']),
  );

  int get usedPct =>
      totalGb > 0 ? ((usedGb * 100) / totalGb).round().clamp(0, 100) : 0;
}

class SystemComponents {
  const SystemComponents({
    this.board,
    this.cpus = const [],
    this.rams = const [],
    this.disks = const [],
    this.gpus = const [],
    this.monitors = const [],
    this.netAdapters = const [],
    this.volumes = const [],
  });

  final SystemBoard? board;
  final List<SystemCpuRow> cpus;
  final List<SystemRamRow> rams;
  final List<SystemDiskRow> disks;
  final List<SystemGpuRow> gpus;
  final List<SystemMonitorRow> monitors;
  final List<SystemNetRow> netAdapters;
  final List<SystemVolumeRow> volumes;

  factory SystemComponents.fromJson(Map<String, dynamic> j) {
    final b = j['board'];
    return SystemComponents(
      board: b is Map ? SystemBoard.fromJson(asMap(b)) : null,
      cpus: asRows(j['cpus']).map(SystemCpuRow.fromJson).toList(),
      rams: asRows(j['rams']).map(SystemRamRow.fromJson).toList(),
      disks: asRows(j['disks']).map(SystemDiskRow.fromJson).toList(),
      gpus: asRows(j['gpus']).map(SystemGpuRow.fromJson).toList(),
      monitors: asRows(j['monitors']).map(SystemMonitorRow.fromJson).toList(),
      netAdapters: asRows(j['netAdapters']).map(SystemNetRow.fromJson).toList(),
      volumes: asRows(j['volumes']).map(SystemVolumeRow.fromJson).toList(),
    );
  }

  /// همان شرط وب برای «از جدول‌ها خوانده شد»
  bool get hasAny =>
      cpus.length +
          rams.length +
          disks.length +
          gpus.length +
          monitors.length +
          netAdapters.length +
          volumes.length +
          (board != null && !board!.isEmpty ? 1 : 0) >
      0;

  int get totalRamGb => rams.fold<int>(0, (a, r) => a + r.capacityGb);
}

// ============================================================
//  امتیاز سلامت — `GET api/SystemInfo/health/{id}`
// ============================================================

class HealthCategory {
  const HealthCategory({
    this.key = '',
    this.fa = '',
    this.icon = '',
    this.score = 0,
    this.max = 0,
    this.note = '',
  });
  final String key;
  final String fa;
  final String icon;
  final int score;
  final int max;
  final String note;

  factory HealthCategory.fromJson(Map<String, dynamic> j) => HealthCategory(
    key: _s(j['key']),
    fa: _s(j['fa']),
    icon: _s(j['icon']),
    score: _i(j['score']),
    max: _i(j['max']),
    note: _s(j['note']),
  );

  int get pct => max > 0 ? ((score * 100) / max).round() : 0;

  double get ratio => max > 0 ? score / max : 0;
}

class SystemHealth {
  const SystemHealth({
    this.score = 0,
    this.grade = '',
    this.gradeFa = '',
    this.color = '',
    this.categories = const [],
  });
  final int score;
  final String grade;
  final String gradeFa;
  final String color;
  final List<HealthCategory> categories;

  factory SystemHealth.fromJson(Map<String, dynamic> j) => SystemHealth(
    score: _i(j['score']),
    grade: _s(j['grade']),
    gradeFa: _s(j['gradeFa']),
    color: _s(j['color']),
    categories: asRows(j['categories']).map(HealthCategory.fromJson).toList(),
  );

  /// ضعیف‌ترین دسته — همان `OrderBy(c => c.Score / Max).First()` وب
  HealthCategory? get worst {
    if (categories.isEmpty) return null;
    final sorted = [...categories]..sort((a, b) => a.ratio.compareTo(b.ratio));
    return sorted.first;
  }

  /// متن راهنمای ارتقا بر اساس کلید ضعیف‌ترین دسته
  String? get worstTip => worst == null ? null : SystemTip.forKey(worst!.key);
}

/// راهنمای ارتقا — عیناً `TipFor()` وب
class SystemTip {
  static String forKey(String key) => switch (key) {
    'storage' => 'آزادسازی فضا / ارتقا درایو',
    'ram' => 'ارتقا حافظه رم',
    'media' => 'جایگزینی با SSD',
    'cpu' => 'ارتقا پردازنده',
    'fresh' => 'به‌روزرسانی اطلاعات (اجرای ایجنت)',
    'status' => 'تکمیل فرآیند تایید',
    _ => 'بررسی و ارتقا',
  };
}

/// رنگ حلقهٔ گیج — همان `RingColor` کامپوننت `HealthGauge`
String healthRingColor(int? score) {
  if (score == null) return '#d5d9e6';
  if (score >= 90) return '#0ea5a4';
  if (score >= 75) return '#2ec47e';
  if (score >= 60) return '#f4a23c';
  if (score >= 40) return '#ff7043';
  return '#e0245e';
}

// ============================================================
//  تغییرات و تاریخچه
// ============================================================

class ChangeDiff {
  const ChangeDiff({
    this.field = '',
    this.oldValue,
    this.newValue,
    this.changed = false,
  });
  final String field;
  final String? oldValue;
  final String? newValue;
  final bool changed;

  factory ChangeDiff.fromJson(Map<String, dynamic> j) => ChangeDiff(
    field: _s(j['field']),
    oldValue: _ns(j['old']),
    newValue: _ns(j['new']),
    changed: _b(j['changed']),
  );
}

class PendingChanges {
  const PendingChanges({
    this.hasPending = false,
    this.pendingReceivedAt,
    this.changeCount = 0,
    this.diffs = const [],
  });
  final bool hasPending;
  final DateTime? pendingReceivedAt;
  final int changeCount;
  final List<ChangeDiff> diffs;

  factory PendingChanges.fromJson(Map<String, dynamic> j) => PendingChanges(
    hasPending: _b(j['hasPending']),
    pendingReceivedAt: DateTime.tryParse(_s(j['pendingReceivedAt'])),
    changeCount: _i(j['changeCount']),
    diffs: asRows(j['diffs']).map(ChangeDiff.fromJson).toList(),
  );
}

class SystemHistoryEntry {
  const SystemHistoryEntry({
    this.id = 0,
    this.changedAt,
    this.changeCount = 0,
    this.diffs = const [],
  });
  final int id;
  final DateTime? changedAt;
  final int changeCount;
  final List<ChangeDiff> diffs;

  factory SystemHistoryEntry.fromJson(Map<String, dynamic> j) =>
      SystemHistoryEntry(
        id: _i(j['id']),
        changedAt: DateTime.tryParse(_s(j['changedAt'])),
        changeCount: _i(j['changeCount']),
        diffs: asRows(j['diffs']).map(ChangeDiff.fromJson).toList(),
      );
}

// ============================================================
//  تاریخچهٔ کاربران سیستم — `GET api/SystemInfo/user-history/{id}`
// ============================================================

class SystemUserHistoryRow {
  const SystemUserHistoryRow({
    this.id = 0,
    this.userId,
    this.userName = '',
    this.staffNumber,
    this.companyName,
    this.fromAt,
    this.toAt,
  });
  final int id;
  final int? userId;
  final String userName;
  final String? staffNumber;
  final String? companyName;
  final DateTime? fromAt;
  final DateTime? toAt;

  factory SystemUserHistoryRow.fromJson(Map<String, dynamic> j) =>
      SystemUserHistoryRow(
        id: _i(j['id']),
        userId: _ni(j['userId']),
        userName: _s(j['userName']),
        staffNumber: _ns(j['staffNumber']),
        companyName: _ns(j['companyName']),
        fromAt: DateTime.tryParse(_s(j['fromAt'])),
        toAt: DateTime.tryParse(_s(j['toAt'])),
      );

  /// رکورد باز = هنوز تحویل داده نشده
  bool get isOpen => toAt == null;
}

// ============================================================
//  تحویل دیجیتال — `handover/{id}` و `handovers/{id}`
// ============================================================

class HandoverCheck {
  const HandoverCheck({this.key = '', this.fa = '', this.checked = false});
  final String key;
  final String fa;
  final bool checked;

  factory HandoverCheck.fromJson(Map<String, dynamic> j) => HandoverCheck(
    key: _s(j['key'] ?? j['Key']),
    fa: _s(j['fa'] ?? j['Fa']),
    checked: _b(j['checked'] ?? j['Checked']),
  );

  HandoverCheck copyWith({bool? checked}) =>
      HandoverCheck(key: key, fa: fa, checked: checked ?? this.checked);
}

class SystemHandover {
  const SystemHandover({
    this.id = 0,
    this.fromUserName = '',
    this.toUserId = 0,
    this.toUserName = '',
    this.createdAt,
    this.isCompleted = false,
    this.completedAt,
    this.checklist = const [],
    this.signatureDataUrl,
    this.note,
  });
  final int id;
  final String fromUserName;
  final int toUserId;
  final String toUserName;
  final DateTime? createdAt;
  final bool isCompleted;
  final DateTime? completedAt;
  final List<HandoverCheck> checklist;
  final String? signatureDataUrl;
  final String? note;

  factory SystemHandover.fromJson(Map<String, dynamic> j) => SystemHandover(
    id: _i(j['id']),
    fromUserName: _s(j['fromUserName']),
    toUserId: _i(j['toUserId']),
    toUserName: _s(j['toUserName']),
    createdAt: DateTime.tryParse(_s(j['createdAt'])),
    isCompleted: _b(j['isCompleted']),
    completedAt: DateTime.tryParse(_s(j['completedAt'])),
    checklist: asRows(j['checklist']).map(HandoverCheck.fromJson).toList(),
    signatureDataUrl: _ns(j['signatureDataUrl']),
    note: _ns(j['note']),
  );
}

/// چک‌لیست پیش‌فرض تحویل — عیناً `handoverItems` در `SystemId.razor`
const List<HandoverCheck> kHandoverChecklist = [
  HandoverCheck(key: 'body', fa: 'بدنه‌ی سیستم سالم است و روشن می‌شود'),
  HandoverCheck(key: 'power', fa: 'کیبل برق و آداپتور همراه سیستم است'),
  HandoverCheck(key: 'monitor', fa: 'مانیتور و کابل‌های اتصال سالم هستند'),
  HandoverCheck(key: 'peripherals', fa: 'کیبورد، ماوس و لوازم جانبی موجود است'),
  HandoverCheck(key: 'software', fa: 'نرم‌افزارها نصب و به‌روز هستند'),
  HandoverCheck(key: 'network', fa: 'آدرس IP و اتصال شبکه تنظیم است'),
  HandoverCheck(key: 'tested', fa: 'گیرنده سیستم را تست کرده و تأیید می‌کند'),
];

// ============================================================
//  دستور از راه دور — `commands/{id}`
// ============================================================

class RemoteCommandRow {
  const RemoteCommandRow({
    this.id = 0,
    this.action = '',
    this.status = '',
    this.createdAt,
    this.byUserName,
    this.completedAt,
    this.result,
  });
  final int id;
  final String action;
  final String status;
  final DateTime? createdAt;
  final String? byUserName;
  final DateTime? completedAt;
  final String? result;

  factory RemoteCommandRow.fromJson(Map<String, dynamic> j) => RemoteCommandRow(
    id: _i(j['id']),
    action: _s(j['action']),
    status: _s(j['status']),
    createdAt: DateTime.tryParse(_s(j['createdAt'])),
    byUserName: _ns(j['byUserName']),
    completedAt: DateTime.tryParse(_s(j['completedAt'])),
    result: _ns(j['result']),
  );

  /// متن فارسی دستور — همان `CmdFa()`
  String get actionFa => switch (action) {
    'Reboot' => 'ری‌استارت سیستم',
    'Shutdown' => 'خاموش کردن سیستم',
    'Lock' => 'قفل صفحه',
    _ => action,
  };

  /// متن وضعیت — همان `CmdStatusFa()`
  String get statusFa => switch (status) {
    'Completed' => 'انجام شد',
    'Failed' => 'ناموفق',
    _ => 'در انتظار ایجنت',
  };

  String get byUserFa => (byUserName ?? '').trim().isEmpty ? '—' : byUserName!;
}

// ============================================================
//  کاربر سیستم — `GET api/SystemUsers`
// ============================================================

class SystemUserRow {
  const SystemUserRow({
    this.id = 0,
    this.firstName = '',
    this.lastName = '',
    this.staffNumber = '',
    this.phone,
    this.departmentId,
    this.companyId,
    this.organizationId,
    this.role = 'User',
    this.isActive = true,
    this.createdAt,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String staffNumber;
  final String? phone;
  final int? departmentId;
  final int? companyId;
  final int? organizationId;
  final String role;
  final bool isActive;
  final DateTime? createdAt;

  factory SystemUserRow.fromJson(Map<String, dynamic> j) => SystemUserRow(
    id: _i(j['id']),
    firstName: _s(j['firstName']),
    lastName: _s(j['lastName']),
    staffNumber: _s(j['staffNumber']),
    phone: _ns(j['phone']),
    departmentId: _ni(j['departmentId']),
    companyId: _ni(j['companyId']),
    organizationId: _ni(j['organizationId']),
    role: _s(j['role']).isEmpty ? 'User' : _s(j['role']),
    isActive: j.containsKey('isActive') ? _b(j['isActive']) : true,
    createdAt: DateTime.tryParse(_s(j['createdAt'])),
  );

  String get fullName => '$firstName $lastName'.trim();

  /// «نام خانوادگی، نام» برای فهرست‌های انتخابی — مثل وب: «نام نام‌خانوادگی (شماره پرسنلی)»
  String get lookupLabel =>
      '${fullName.isEmpty ? '—' : fullName} (${staffNumber.isEmpty ? '—' : staffNumber})';

  /// متن نقش — همان `RoleName()` صفحهٔ کاربران سیستم
  String get roleFa => switch (role) {
    'Admin' => 'مدیر',
    'Operator' => 'اپراتور',
    'Accountant' => 'حسابدار',
    'Referrer' => 'معرف',
    'HrManager' => 'مدیر منابع انسانی',
    'Employee' => 'کارمند',
    _ => 'کاربر',
  };

  /// گزینه‌های «دسته‌بندی» در فرم — عیناً همان پنج گزینهٔ وب
  static const roleOptions = <String, String>{
    'User': 'کاربر عادی (کارمند)',
    'Operator': 'اپراتور',
    'Accountant': 'حسابدار',
    'Referrer': 'معرف',
    'Admin': 'مدیر کل',
  };

  Map<String, dynamic> toPayload() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'phone': phone,
    'staffNumber': staffNumber,
    'departmentId': departmentId,
    'companyId': companyId,
    'organizationId': organizationId,
    'role': role,
    'isActive': isActive,
  };
}

class SystemCompanyRow {
  const SystemCompanyRow({
    this.id = 0,
    this.name = '',
    this.code,
    this.isActive = true,
  });
  final int id;
  final String name;
  final String? code;
  final bool isActive;

  factory SystemCompanyRow.fromJson(Map<String, dynamic> j) => SystemCompanyRow(
    id: _i(j['id']),
    name: _s(j['name']),
    code: _ns(j['code']),
    isActive: j.containsKey('isActive') ? _b(j['isActive']) : true,
  );
}

class SystemDepartmentRow {
  const SystemDepartmentRow({
    this.id = 0,
    this.name = '',
    this.companyId,
    this.isActive = true,
  });
  final int id;
  final String name;
  final int? companyId;
  final bool isActive;

  factory SystemDepartmentRow.fromJson(Map<String, dynamic> j) =>
      SystemDepartmentRow(
        id: _i(j['id']),
        name: _s(j['name']),
        companyId: _ni(j['companyId']),
        isActive: j.containsKey('isActive') ? _b(j['isActive']) : true,
      );
}

class SystemOrganizationRow {
  const SystemOrganizationRow({
    this.organizationId = 0,
    this.nameUnit = '',
    this.nameUniq = '',
    this.companyId,
    this.isActive = true,
  });
  final int organizationId;
  final String nameUnit;
  final String nameUniq;
  final int? companyId;
  final bool isActive;

  factory SystemOrganizationRow.fromJson(Map<String, dynamic> j) =>
      SystemOrganizationRow(
        organizationId: _i(j['organizationId']),
        nameUnit: _s(j['nameUnit']),
        nameUniq: _s(j['nameUniq']),
        companyId: _ni(j['companyId']),
        isActive: j.containsKey('isActive') ? _b(j['isActive']) : true,
      );

  String get label => nameUniq.isEmpty ? nameUnit : '$nameUnit ($nameUniq)';
}

// ============================================================
//  درخواست ثبت دستی — `POST api/SystemInfo/manual`
// ============================================================

class ManualSystemRequest {
  const ManualSystemRequest({
    this.agentId = '',
    this.companyId = 0,
    this.departmentId,
    this.userId,
    this.computerModel,
    this.motherboard,
    this.cpu,
    this.totalRamGb = 0,
    this.ram,
    this.hardDisk,
    this.graphics,
    this.monitor,
    this.osName,
    this.ip,
  });

  final String agentId;
  final int companyId;
  final int? departmentId;
  final int? userId;
  final String? computerModel;
  final String? motherboard;
  final String? cpu;
  final int totalRamGb;
  final String? ram;
  final String? hardDisk;
  final String? graphics;
  final String? monitor;
  final String? osName;
  final String? ip;

  Map<String, dynamic> toJson() => {
    'agentId': agentId,
    'companyId': companyId,
    'departmentId': departmentId,
    'userId': userId,
    'computerModel': computerModel,
    'motherboard': motherboard,
    'cpu': cpu,
    'totalRamGb': totalRamGb,
    'ram': ram,
    'hardDisk': hardDisk,
    'graphics': graphics,
    'monitor': monitor,
    'osName': osName,
    'ip': ip,
  };
}

// ============================================================
//  تحلیل‌های ناوگان — همان getterهای `SystemInfoList.razor`
// ============================================================

/// نرمال‌سازی نام سیستم‌عامل — عیناً `NormOs()` وب
String normOs(String? os) {
  final o = (os ?? '').trim();
  if (o.isEmpty) return 'نامشخص';
  if (o.contains('11')) return 'Windows 11';
  if (o.contains('10')) return 'Windows 10';
  return 'سایر';
}

class OsSegment {
  const OsSegment({
    this.name = '',
    this.count = 0,
    this.pct = 0,
    this.color = '',
  });
  final String name;
  final int count;
  final int pct;
  final String color;
}

/// رنگ‌های نمودار دایره‌ای — `OsColors` وب
const List<String> kOsColors = ['#0ea5a4', '#8e5cff', '#f4a23c', '#b6bccb'];

/// بخش‌های نمودار سیستم‌عامل — `OsSegments`
List<OsSegment> osSegments(List<SystemInfoItem> items) {
  final counts = <String, int>{};
  for (final it in items) {
    final k = normOs(it.osName);
    counts[k] = (counts[k] ?? 0) + 1;
  }
  final entries = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final total = items.isEmpty ? 1 : items.length;
  return [
    for (var i = 0; i < entries.length; i++)
      OsSegment(
        name: entries[i].key,
        count: entries[i].value,
        pct: ((entries[i].value * 100) / total).round(),
        color: kOsColors[i % kOsColors.length],
      ),
  ];
}

class DeptRam {
  const DeptRam({this.name = '', this.avg = 0, this.count = 0});
  final String name;
  final double avg;
  final int count;

  String get avgLabel => avg > 0 ? '${_oneDecimal(avg)} GB' : '—';

  static String _oneDecimal(double v) {
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }
}

/// میانگین رم به تفکیک دپارتمان — `RamByDept`
List<DeptRam> ramByDept(
  List<SystemInfoItem> items,
  Map<int, String> departmentNames,
) {
  final groups = <int?, List<SystemInfoItem>>{};
  for (final it in items) {
    groups.putIfAbsent(it.departmentId, () => []).add(it);
  }
  final out = <DeptRam>[];
  groups.forEach((deptId, list) {
    final withRam = list.where((x) => x.totalRamGb > 0).toList();
    final avg = withRam.isEmpty
        ? 0.0
        : double.parse(
            (withRam.fold<int>(0, (a, b) => a + b.totalRamGb) /
                    withRam.length)
                .toStringAsFixed(1),
          );
    final name = deptId == null
        ? 'بدون واحد'
        : (departmentNames[deptId] ?? 'واحد #$deptId');
    out.add(DeptRam(name: name, avg: avg, count: list.length));
  });
  out.sort((a, b) => b.avg.compareTo(a.avg));
  return out;
}

/// بزرگ‌ترین میانگین (برای عرض نوار) — `MaxDeptRam`
int maxDeptRam(List<DeptRam> rows) {
  if (rows.isEmpty) return 1;
  var m = 1;
  for (final r in rows) {
    final v = r.avg.ceil();
    if (v > m) m = v;
  }
  return m;
}

/// ۱۰ سیستم ضعیف‌تر — `Weakest10`
List<SystemInfoItem> weakest10(List<SystemInfoItem> items) {
  final withHealth = items.where((x) => x.health != null).toList()
    ..sort((a, b) {
      final c = a.health!.compareTo(b.health!);
      if (c != 0) return c;
      final ad = a.receivedAt?.millisecondsSinceEpoch ?? 0;
      final bd = b.receivedAt?.millisecondsSinceEpoch ?? 0;
      return bd.compareTo(ad);
    });
  return withHealth.take(10).toList();
}

class CompanySystemGroup {
  const CompanySystemGroup({
    this.companyId,
    this.name = '',
    this.code,
    this.items = const [],
  });
  final int? companyId;
  final String name;
  final String? code;
  final List<SystemInfoItem> items;
}

/// گروه‌بندی بر اساس شرکت — `CompanyGroups` وب
List<CompanySystemGroup> companyGroups(
  List<SystemInfoItem> items,
  List<SystemCompanyRow> companies,
) {
  final groups = <int?, List<SystemInfoItem>>{};
  for (final it in items) {
    groups.putIfAbsent(it.companyId, () => []).add(it);
  }
  final out = <CompanySystemGroup>[];
  groups.forEach((companyId, list) {
    SystemCompanyRow? company;
    if (companyId != null) {
      for (final c in companies) {
        if (c.id == companyId) {
          company = c;
          break;
        }
      }
    }
    final name = company?.name ??
        (companyId != null
            ? 'شرکت حذف‌شده / ناشناخته (#$companyId)'
            : 'بدون شرکت');
    final sorted = [...list]..sort((a, b) {
        final ad = a.receivedAt?.millisecondsSinceEpoch ?? 0;
        final bd = b.receivedAt?.millisecondsSinceEpoch ?? 0;
        return bd.compareTo(ad);
      });
    out.add(
      CompanySystemGroup(
        companyId: companyId,
        name: name,
        code: company?.code,
        items: sorted,
      ),
    );
  });
  out.sort((a, b) {
    final an = a.companyId == null ? 1 : 0;
    final bn = b.companyId == null ? 1 : 0;
    if (an != bn) return an.compareTo(bn);
    return a.name.compareTo(b.name);
  });
  return out;
}

/// متن راهنمای امتیاز سلامت — `HealthTip()`
String healthTip(int? h) => h == null ? '' : 'امتیاز سلامت: $h از ۱۰۰';
