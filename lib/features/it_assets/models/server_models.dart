// ============================================================
//  مدل‌های «مدیریت سرورها» — فاز ۹-د
//  منبع: `Inventory.Api/Controllers/ItAssets/ServersController.cs` (Route: api/servers)
//        و `Inventory.Client/Pages/ItAssets/ServerManagement.razor` (/servers)
//  نام فیلدها عیناً کلیدهای JSON سرور است.
// ============================================================

int _i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
int? _ni(Object? v) {
  if (v == null) return null;
  final n = v is num ? v.toInt() : int.tryParse('$v');
  return (n == null || n <= 0) ? null : n;
}

bool _b(Object? v) => v == true || v == 1 || '$v'.toLowerCase() == 'true';
String _s(Object? v) => v == null ? '' : '$v';
String? _ns(Object? v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

DateTime? _dt(Object? v) {
  final s = _ns(v);
  if (s == null) return null;
  return DateTime.tryParse(s);
}

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _rows(Object? v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];

// ============================================================
//  متن‌های فارسی — عیناً توابع کمکی صفحهٔ وب
// ============================================================

class ServerHealth {
  /// `HealthTitle()`
  static String title(String? status) => switch ((status ?? '').toUpperCase()) {
    'OK' => 'سالم',
    'WARNING' => 'هشدار',
    'CRITICAL' => 'بحرانی',
    _ => 'بررسی نشده',
  };

  /// `IsHealthy()`
  static bool isHealthy(String? status) =>
      (status ?? '').toLowerCase() == 'ok';

  /// `IsProblem()`
  static bool isProblem(String? status) {
    final s = (status ?? '').toLowerCase();
    return s == 'warning' || s == 'critical';
  }

  /// `HealthClass()` — کلاس بوت‌استرپ وب → معادل رنگی موبایل
  static int colorValue(String? status) {
    if (isHealthy(status)) return 0xff1a7f37;
    if (isProblem(status)) return 0xffd13438;
    final s = (status ?? '').toLowerCase();
    if (s == 'unknown' || s.isEmpty) return 0xff64748b;
    return 0xffd97706;
  }
}

/// `CriticalityTitle()`
String criticalityTitle(String? value) => switch (value) {
  'Low' => 'کم',
  'High' => 'زیاد',
  'Critical' => 'بحرانی',
  _ => 'عادی',
};

/// `StatusTitle()`
String serverStatusTitle(String? value) => switch (value) {
  'Maintenance' => 'تعمیرات',
  'Standby' => 'رزرو',
  'Retired' => 'بازنشسته',
  _ => 'فعال',
};

const List<MapEntry<String, String>> kCriticalities = [
  MapEntry('Low', 'کم'),
  MapEntry('Normal', 'عادی'),
  MapEntry('High', 'زیاد'),
  MapEntry('Critical', 'بحرانی'),
];

const List<MapEntry<String, String>> kServerStatuses = [
  MapEntry('Active', 'فعال'),
  MapEntry('Maintenance', 'در تعمیرات'),
  MapEntry('Standby', 'رزرو'),
  MapEntry('Retired', 'بازنشسته'),
];

/// `ComponentTypeTitle()`
String componentTypeTitle(String? value) => switch (value) {
  'PowerSupply' => 'پاور',
  'Fan' => 'فن',
  'Temperature' => 'دما',
  'Memory' => 'حافظه',
  'Processor' => 'پردازنده',
  'Storage' => 'کنترلر ذخیره‌سازی',
  'Disk' => 'دیسک',
  'Chassis' => 'شاسی',
  _ => (value ?? '').isEmpty ? 'قطعه' : value!,
};

/// `AlertCategoryTitle()`
String alertCategoryTitle(String? value) => switch (value) {
  'Connection' => 'ارتباط iLO',
  'HardwareEvent' => 'رخداد iLO',
  _ => 'سلامت سخت‌افزار',
};

/// زمان نسبی — `Ago()` صفحهٔ مدیریت آی‌پی (برای سرورها هم قابل استفاده)
String agoFa(DateTime? at, {DateTime? now}) {
  if (at == null) return '—';
  final n = now ?? DateTime.now();
  var d = n.difference(at);
  if (d.isNegative) d = Duration.zero;
  if (d.inMinutes < 1) return 'همین الان';
  if (d.inMinutes < 60) return '${d.inMinutes} دقیقه پیش';
  if (d.inHours < 24) return '${d.inHours} ساعت پیش';
  if (d.inDays < 30) return '${d.inDays} روز پیش';
  return '';
}

// ============================================================
//  ردیف‌های پایه
// ============================================================

class ServerCompanyRow {
  const ServerCompanyRow({this.id = 0, this.name = '', this.count = 0});
  final int id;
  final String name;
  final int count;

  factory ServerCompanyRow.fromJson(Map<String, dynamic> j) => ServerCompanyRow(
    id: _i(j['id']),
    name: _s(j['name']),
    count: _i(j['count']),
  );
}

/// `GET api/servers/credentials?companyId=`
class ServerCredentialRow {
  const ServerCredentialRow({
    this.id = 0,
    this.title = '',
    this.host,
    this.port,
    this.username,
    this.hasPassword = false,
  });
  final int id;
  final String title;
  final String? host;
  final int? port;
  final String? username;
  final bool hasPassword;

  factory ServerCredentialRow.fromJson(Map<String, dynamic> j) =>
      ServerCredentialRow(
        id: _i(j['id']),
        title: _s(j['title']),
        host: _ns(j['host']),
        port: _ni(j['port']),
        username: _ns(j['username']),
        hasPassword: _b(j['hasPassword']),
      );

  /// متن گزینه — عیناً وب: «عنوان (کاربری)» و اگر رمز ندارد «— بدون رمز»
  String get optionLabel =>
      '$title (${username ?? '—'})${hasPassword ? '' : ' — بدون رمز'}';
}

/// `GET api/servers/responsibles?companyId=`
class ServerResponsibleRow {
  const ServerResponsibleRow({
    this.id = 0,
    this.name = '',
    this.username = '',
  });
  final int id;
  final String name;
  final String username;

  factory ServerResponsibleRow.fromJson(Map<String, dynamic> j) =>
      ServerResponsibleRow(
        id: _i(j['id']),
        name: _s(j['name']),
        username: _s(j['username']),
      );

  String get optionLabel => '$name ($username)';
}

// ============================================================
//  سرور — `GET api/servers?companyId=&q=`
// ============================================================

class ServerRow {
  const ServerRow({
    this.id = 0,
    this.companyId = 0,
    this.name = '',
    this.manufacturer,
    this.model,
    this.serialNumber,
    this.assetTag,
    this.iloAddress = '',
    this.iloPort = 443,
    this.credentialId,
    this.iloVersion,
    this.role,
    this.environment,
    this.certPinned = false,
    this.iloCertThumbprint,
    this.iloCertNotAfter,
    this.iloCertTrustedAt,
    this.iloCertTrustedByName,
    this.criticality = 'Normal',
    this.status = 'Active',
    this.rack,
    this.rackUnit,
    this.operatingSystem,
    this.warrantyEndDate,
    this.notes,
    this.monitoringEnabled = false,
    this.monitoringIntervalMinutes = 15,
    this.lastAutomaticPollAt,
    this.responsibleUserId,
    this.responsibleName,
    this.alertNotificationsEnabled = false,
    this.maintenanceUntil,
    this.maintenanceNote,
    this.lastHealthCheckAt,
    this.lastHealthStatus,
    this.lastPowerState,
    this.lastHealthMessage,
    this.lastConnectionError,
    this.lastInventoryAt,
    this.createdAt,
    this.updatedAt,
    this.updatedByName,
    this.openAlertCount = 0,
  });

  final int id;
  final int companyId;
  final String name;
  final String? manufacturer;
  final String? model;
  final String? serialNumber;
  final String? assetTag;
  final String iloAddress;
  final int iloPort;
  final int? credentialId;
  final String? iloVersion;
  final String? role;
  final String? environment;
  final bool certPinned;
  final String? iloCertThumbprint;
  final DateTime? iloCertNotAfter;
  final DateTime? iloCertTrustedAt;
  final String? iloCertTrustedByName;
  final String criticality;
  final String status;
  final String? rack;
  final int? rackUnit;
  final String? operatingSystem;
  final DateTime? warrantyEndDate;
  final String? notes;
  final bool monitoringEnabled;
  final int monitoringIntervalMinutes;
  final DateTime? lastAutomaticPollAt;
  final int? responsibleUserId;
  final String? responsibleName;
  final bool alertNotificationsEnabled;
  final DateTime? maintenanceUntil;
  final String? maintenanceNote;
  final DateTime? lastHealthCheckAt;
  final String? lastHealthStatus;
  final String? lastPowerState;
  final String? lastHealthMessage;
  final String? lastConnectionError;
  final DateTime? lastInventoryAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? updatedByName;
  final int openAlertCount;

  factory ServerRow.fromJson(Map<String, dynamic> j) => ServerRow(
    id: _i(j['id']),
    companyId: _i(j['companyId']),
    name: _s(j['name']),
    manufacturer: _ns(j['manufacturer']),
    model: _ns(j['model']),
    serialNumber: _ns(j['serialNumber']),
    assetTag: _ns(j['assetTag']),
    iloAddress: _s(j['iloAddress']),
    iloPort: j['iloPort'] == null ? 443 : _i(j['iloPort']),
    credentialId: _ni(j['credentialId']),
    iloVersion: _ns(j['iloVersion']),
    role: _ns(j['role']),
    environment: _ns(j['environment']),
    certPinned: _b(j['certPinned']),
    iloCertThumbprint: _ns(j['iloCertThumbprint']),
    iloCertNotAfter: _dt(j['iloCertNotAfter']),
    iloCertTrustedAt: _dt(j['iloCertTrustedAt']),
    iloCertTrustedByName: _ns(j['iloCertTrustedByName']),
    criticality: _s(j['criticality']).isEmpty ? 'Normal' : _s(j['criticality']),
    status: _s(j['status']).isEmpty ? 'Active' : _s(j['status']),
    rack: _ns(j['rack']),
    rackUnit: _ni(j['rackUnit']),
    operatingSystem: _ns(j['operatingSystem']),
    warrantyEndDate: _dt(j['warrantyEndDate']),
    notes: _ns(j['notes']),
    monitoringEnabled: _b(j['monitoringEnabled']),
    monitoringIntervalMinutes: j['monitoringIntervalMinutes'] == null
        ? 15
        : _i(j['monitoringIntervalMinutes']),
    lastAutomaticPollAt: _dt(j['lastAutomaticPollAt']),
    responsibleUserId: _ni(j['responsibleUserId']),
    responsibleName: _ns(j['responsibleName']),
    alertNotificationsEnabled: _b(j['alertNotificationsEnabled']),
    maintenanceUntil: _dt(j['maintenanceUntil']),
    maintenanceNote: _ns(j['maintenanceNote']),
    lastHealthCheckAt: _dt(j['lastHealthCheckAt']),
    lastHealthStatus: _ns(j['lastHealthStatus']),
    lastPowerState: _ns(j['lastPowerState']),
    lastHealthMessage: _ns(j['lastHealthMessage']),
    lastConnectionError: _ns(j['lastConnectionError']),
    lastInventoryAt: _dt(j['lastInventoryAt']),
    createdAt: _dt(j['createdAt']),
    updatedAt: _dt(j['updatedAt']),
    updatedByName: _ns(j['updatedByName']),
    openAlertCount: _i(j['openAlertCount']),
  );

  /// `RackTitle()`
  String get rackTitle =>
      (rack ?? '').isEmpty ? 'بدون رک' : '$rack${(rackUnit ?? 0) > 0 ? ' / U$rackUnit' : ''}';

  String get iloLabel => '$iloAddress:$iloPort';
  String get modelCell => (model ?? '').isEmpty ? '—' : model!;
  String get serialCell => (serialNumber ?? '').isEmpty ? 'بدون سریال' : serialNumber!;

  bool get inMaintenance =>
      maintenanceUntil != null && maintenanceUntil!.isAfter(DateTime.now());

  /// متن زیر نام — «HPE · عادی · فعال»
  String get subtitleLine =>
      '${(manufacturer ?? '').isEmpty ? '—' : manufacturer} · '
      '${criticalityTitle(criticality)} · ${serverStatusTitle(status)}';
}

// ============================================================
//  هشدار سرور — `GET api/servers/alerts?companyId=`
// ============================================================

class ServerAlertRow {
  const ServerAlertRow({
    this.id = 0,
    this.managedServerId = 0,
    this.serverName = '',
    this.model,
    this.category = '',
    this.severity = '',
    this.message = '',
    this.status = '',
    this.workOrderId,
    this.openedAt,
    this.lastSeenAt,
    this.acknowledgedAt,
    this.acknowledgedByName,
    this.resolvedAt,
  });

  final int id;
  final int managedServerId;
  final String serverName;
  final String? model;
  final String category;
  final String severity;
  final String message;
  final String status;
  final int? workOrderId;
  final DateTime? openedAt;
  final DateTime? lastSeenAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgedByName;
  final DateTime? resolvedAt;

  factory ServerAlertRow.fromJson(Map<String, dynamic> j) => ServerAlertRow(
    id: _i(j['id']),
    managedServerId: _i(j['managedServerId']),
    serverName: _s(j['serverName']),
    model: _ns(j['model']),
    category: _s(j['category']),
    severity: _s(j['severity']),
    message: _s(j['message']),
    status: _s(j['status']),
    workOrderId: _ni(j['workOrderId']),
    openedAt: _dt(j['openedAt']),
    lastSeenAt: _dt(j['lastSeenAt']),
    acknowledgedAt: _dt(j['acknowledgedAt']),
    acknowledgedByName: _ns(j['acknowledgedByName']),
    resolvedAt: _dt(j['resolvedAt']),
  );

  String get categoryFa => alertCategoryTitle(category);
  bool get isCritical => severity == 'Critical';

  /// ستون وضعیت وب: «تأیید: نام» یا «باز»
  String get statusFa => status == 'Acknowledged'
      ? 'تأیید: ${(acknowledgedByName ?? '').isEmpty ? '—' : acknowledgedByName}'
      : status == 'Resolved'
      ? 'رفع شده'
      : 'باز';

  String get statusColorKey =>
      status == 'Resolved' ? 'resolved' : status == 'Acknowledged' ? 'ack' : 'open';
}

// ============================================================
//  سخت‌افزار سرور — `GET api/servers/{id}/hardware`
// ============================================================

class ServerHardwareComponent {
  const ServerHardwareComponent({
    this.componentType = '',
    this.name = '',
    this.health = 'Unknown',
    this.state,
    this.reading,
    this.model,
    this.serialNumber,
  });
  final String componentType;
  final String name;
  final String health;
  final String? state;
  final String? reading;
  final String? model;
  final String? serialNumber;

  factory ServerHardwareComponent.fromJson(Map<String, dynamic> j) =>
      ServerHardwareComponent(
        componentType: _s(j['componentType']),
        name: _s(j['name']),
        health: _s(j['health']).isEmpty ? 'Unknown' : _s(j['health']),
        state: _ns(j['state']),
        reading: _ns(j['reading']),
        model: _ns(j['model']),
        serialNumber: _ns(j['serialNumber']),
      );

  String get typeFa => componentTypeTitle(componentType);
  String get valueCell => reading ?? state ?? '—';
  String get modelCell =>
      '${model ?? '—'}${(serialNumber ?? '').isEmpty ? '' : ' · $serialNumber'}';
}

class ServerHardwareEvent {
  const ServerHardwareEvent({
    this.severity = 'Unknown',
    this.message = '',
    this.origin,
    this.occurredAt,
    this.lastSeenAt,
  });
  final String severity;
  final String message;
  final String? origin;
  final DateTime? occurredAt;
  final DateTime? lastSeenAt;

  factory ServerHardwareEvent.fromJson(Map<String, dynamic> j) =>
      ServerHardwareEvent(
        severity: _s(j['severity']).isEmpty ? 'Unknown' : _s(j['severity']),
        message: _s(j['message']),
        origin: _ns(j['origin']),
        occurredAt: _dt(j['occurredAt']),
        lastSeenAt: _dt(j['lastSeenAt']),
      );

  DateTime? get at => occurredAt ?? lastSeenAt;
}

class ServerHardware {
  const ServerHardware({
    this.capturedAt,
    this.components = const [],
    this.events = const [],
  });
  final DateTime? capturedAt;
  final List<ServerHardwareComponent> components;
  final List<ServerHardwareEvent> events;

  factory ServerHardware.fromJson(Map<String, dynamic> j) => ServerHardware(
    capturedAt: _dt(j['capturedAt']),
    components: _rows(j['components'])
        .map(ServerHardwareComponent.fromJson)
        .toList(),
    events: _rows(j['events']).map(ServerHardwareEvent.fromJson).toList(),
  );

  bool get isEmpty => components.isEmpty && events.isEmpty;

  int countHealth(String value) => components
      .where((c) => c.health.toLowerCase() == value.toLowerCase())
      .length;
}

// ============================================================
//  گواهی iLO — `GET api/servers/{id}/certificate`
// ============================================================

class IloCertificate {
  const IloCertificate({
    this.thumbprint = '',
    this.subject = '',
    this.issuer = '',
    this.notBefore,
    this.notAfter,
    this.systemTrusted = false,
    this.selfSigned = false,
  });
  final String thumbprint;
  final String subject;
  final String issuer;
  final DateTime? notBefore;
  final DateTime? notAfter;
  final bool systemTrusted;
  final bool selfSigned;

  factory IloCertificate.fromJson(Map<String, dynamic> j) => IloCertificate(
    thumbprint: _s(j['thumbprint']),
    subject: _s(j['subject']),
    issuer: _s(j['issuer']),
    notBefore: _dt(j['notBefore']),
    notAfter: _dt(j['notAfter']),
    systemTrusted: _b(j['systemTrusted']),
    selfSigned: _b(j['selfSigned']),
  );

  bool get expired => notAfter != null && notAfter!.isBefore(DateTime.now());

  /// اثر انگشت با «:» هر دو کاراکتر — همان `Fingerprint()` وب
  String get fingerprint {
    final t = thumbprint.replaceAll(':', '').toUpperCase();
    final out = <String>[];
    for (var i = 0; i < t.length; i += 2) {
      out.add(t.substring(i, i + 2 > t.length ? t.length : i + 2));
    }
    return out.join(':');
  }
}

class IloPinnedCertificate {
  const IloPinnedCertificate({
    this.thumbprint = '',
    this.subject,
    this.notAfter,
    this.trustedAt,
    this.trustedByName,
  });
  final String thumbprint;
  final String? subject;
  final DateTime? notAfter;
  final DateTime? trustedAt;
  final String? trustedByName;

  factory IloPinnedCertificate.fromJson(Map<String, dynamic> j) =>
      IloPinnedCertificate(
        thumbprint: _s(j['thumbprint']),
        subject: _ns(j['subject']),
        notAfter: _dt(j['notAfter']),
        trustedAt: _dt(j['trustedAt']),
        trustedByName: _ns(j['trustedByName']),
      );

  String get fingerprint {
    final t = thumbprint.replaceAll(':', '').toUpperCase();
    final out = <String>[];
    for (var i = 0; i < t.length; i += 2) {
      out.add(t.substring(i, i + 2 > t.length ? t.length : i + 2));
    }
    return out.join(':');
  }
}

class IloCertificateCheck {
  const IloCertificateCheck({
    this.certificate,
    this.error,
    this.pinned,
    this.matchesPin = false,
    this.canTrust = false,
  });
  final IloCertificate? certificate;
  final String? error;
  final IloPinnedCertificate? pinned;
  final bool matchesPin;
  final bool canTrust;

  factory IloCertificateCheck.fromJson(Map<String, dynamic> j) {
    final c = j['certificate'];
    final p = j['pinned'];
    return IloCertificateCheck(
      certificate: c is Map ? IloCertificate.fromJson(_map(c)) : null,
      error: _ns(j['error']),
      pinned: p is Map ? IloPinnedCertificate.fromJson(_map(p)) : null,
      matchesPin: _b(j['matchesPin']),
      canTrust: _b(j['canTrust']),
    );
  }
}

// ============================================================
//  فرم ثبت/ویرایش سرور — همان `SaveDto` کنترلر
// ============================================================

class ServerSaveRequest {
  const ServerSaveRequest({
    this.companyId = 0,
    this.name = '',
    this.manufacturer = 'HPE',
    this.model,
    this.serialNumber,
    this.assetTag,
    this.iloAddress = '',
    this.iloPort = 443,
    this.credentialId,
    this.role,
    this.environment,
    this.criticality = 'Normal',
    this.status = 'Active',
    this.rack,
    this.rackUnit,
    this.operatingSystem,
    this.warrantyEndDate,
    this.notes,
    this.monitoringEnabled = false,
    this.monitoringIntervalMinutes = 15,
    this.responsibleUserId,
    this.alertNotificationsEnabled = false,
    this.maintenanceUntil,
    this.maintenanceNote,
  });

  final int companyId;
  final String name;
  final String manufacturer;
  final String? model;
  final String? serialNumber;
  final String? assetTag;
  final String iloAddress;
  final int iloPort;
  final int? credentialId;
  final String? role;
  final String? environment;
  final String criticality;
  final String status;
  final String? rack;
  final int? rackUnit;
  final String? operatingSystem;
  final DateTime? warrantyEndDate;
  final String? notes;
  final bool monitoringEnabled;
  final int monitoringIntervalMinutes;
  final int? responsibleUserId;
  final bool alertNotificationsEnabled;
  final DateTime? maintenanceUntil;
  final String? maintenanceNote;

  Map<String, dynamic> toJson() => {
    'companyId': companyId,
    'name': name,
    'manufacturer': manufacturer,
    'model': model,
    'serialNumber': serialNumber,
    'assetTag': assetTag,
    'iloAddress': iloAddress,
    'iloPort': iloPort,
    'credentialId': credentialId,
    'role': role,
    'environment': environment,
    'criticality': criticality,
    'status': status,
    'rack': rack,
    'rackUnit': rackUnit,
    'operatingSystem': operatingSystem,
    'warrantyEndDate': warrantyEndDate?.toIso8601String(),
    'notes': notes,
    'monitoringEnabled': monitoringEnabled,
    'monitoringIntervalMinutes': monitoringIntervalMinutes,
    'responsibleUserId': responsibleUserId,
    'alertNotificationsEnabled': alertNotificationsEnabled,
    'maintenanceUntil': maintenanceUntil?.toIso8601String(),
    'maintenanceNote': maintenanceNote,
  };
}

/// اعتبارسنجی سمت کلاینت — همان ترتیب و همان متن‌های `ValidateAsync()` سرور
String? validateServerForm(ServerSaveRequest d) {
  if (d.name.trim().isEmpty) {
    return 'نام سرور را وارد کنید.';
  }
  if (d.iloAddress.trim().isEmpty) {
    return 'آدرس iLO را وارد کنید.';
  }
  if (d.iloAddress.trim().toLowerCase().startsWith('http://')) {
    return 'برای امنیت، آدرس iLO باید با HTTPS باشد.';
  }
  if (d.iloPort < 1 || d.iloPort > 65535) {
    return 'پورت iLO باید بین ۱ تا ۶۵۵۳۵ باشد.';
  }
  if (!['Low', 'Normal', 'High', 'Critical'].contains(d.criticality)) {
    return 'درجهٔ اهمیت نامعتبر است.';
  }
  if (!['Active', 'Maintenance', 'Standby', 'Retired'].contains(d.status)) {
    return 'وضعیت چرخهٔ عمر نامعتبر است.';
  }
  if (d.rackUnit != null && (d.rackUnit! < 1 || d.rackUnit! > 100)) {
    return 'شمارهٔ U رک باید بین ۱ تا ۱۰۰ باشد.';
  }
  if (d.monitoringIntervalMinutes < 5 || d.monitoringIntervalMinutes > 1440) {
    return 'فاصلهٔ پایش باید بین ۵ تا ۱۴۴۰ دقیقه باشد.';
  }
  if (d.monitoringEnabled && (d.credentialId == null || d.credentialId! <= 0)) {
    return 'برای فعال‌سازی پایش خودکار، Credential iLO را انتخاب کنید.';
  }
  if (d.alertNotificationsEnabled &&
      (d.responsibleUserId == null || d.responsibleUserId! <= 0)) {
    return 'برای فعال‌سازی اعلان هشدار، مسئول سرور را انتخاب کنید.';
  }
  if ((d.maintenanceNote ?? '').length > 500) {
    return 'توضیح تعمیرات حداکثر ۵۰۰ کاراکتر است.';
  }
  return null;
}

/// گزینه‌های «فاصلهٔ پایش» — وب: input عددی ۵ تا ۱۴۴۰
const List<int> kMonitoringIntervals = [5, 10, 15, 30, 60, 120, 240, 720, 1440];
