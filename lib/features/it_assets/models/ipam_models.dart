// ============================================================
//  مدل‌های «مدیریت آی‌پی» (IPAM) — فاز ۹-د
//  منبع: `Inventory.Api/Controllers/ItAssets/IpamController.cs` (Route: api/ipam)
//        و `Inventory.Client/Pages/ItAssets/IpManagement.razor` (/ip-management)
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
//  انواع رزرو دستی — عیناً `ReservedTypes` وب
// ============================================================

const List<MapEntry<String, String>> kReservedTypes = [
  MapEntry('Server', 'سرور'),
  MapEntry('Switch', 'سوییچ'),
  MapEntry('Router', 'روتر/میکروتیک'),
  MapEntry('Firewall', 'فایروال'),
  MapEntry('AccessPoint', 'اکسس‌پوینت'),
  MapEntry('Printer', 'پرینتر'),
  MapEntry('Camera', 'دوربین'),
  MapEntry('Pc', 'کامپیوتر'),
  MapEntry('Phone', 'تلفن VoIP'),
  MapEntry('Other', 'سایر'),
];

String reservedTypeFa(String? type) {
  for (final e in kReservedTypes) {
    if (e.key == type) return e.value;
  }
  return '';
}

/// گزینه‌های «اسکن خودکار» — همان `AutoScanOptions` وب
const List<MapEntry<int, String>> kAutoScanOptions = [
  MapEntry(0, 'خاموش (فقط دستی)'),
  MapEntry(15, 'هر ۱۵ دقیقه'),
  MapEntry(30, 'هر ۳۰ دقیقه'),
  MapEntry(60, 'هر ساعت'),
  MapEntry(180, 'هر ۳ ساعت'),
  MapEntry(720, 'هر ۱۲ ساعت'),
  MapEntry(1440, 'روزی یک بار'),
];

/// `MethodFa()` — روش تشخیص روشن بودن
String probeMethodFa(String? m) => switch (m) {
  'ping' => 'پینگ',
  'tcp' => 'پورت باز',
  'arp' => 'ARP — پینگ بسته است',
  _ => '—',
};

/// عنوان فارسی منبع ثبت — `SourceTitle` سرور
String ipSourceFa(String source) => switch (source) {
  'System' => 'شناسنامه سیستم',
  'OfficeMachine' => 'ماشین اداری',
  'Camera' => 'دوربین',
  'Nvr' => 'NVR',
  'Vault' => 'گاوصندوق رمزها',
  'Reserved' => 'رزرو دستی',
  _ => source,
};

// ============================================================
//  رنج‌ها
// ============================================================

class IpamCompanyRow {
  const IpamCompanyRow({this.id = 0, this.name = '', this.count = 0});
  final int id;
  final String name;
  final int count;

  factory IpamCompanyRow.fromJson(Map<String, dynamic> j) => IpamCompanyRow(
    id: _i(j['id']),
    name: _s(j['name']),
    count: _i(j['count']),
  );
}

/// `GET api/ipam/subnets?companyId=`
class IpSubnetRow {
  const IpSubnetRow({
    this.id = 0,
    this.companyId = 0,
    this.name = '',
    this.cidr = '',
    this.prefix = 0,
    this.gateway,
    this.vlan,
    this.location,
    this.dhcpRange,
    this.autoScanMinutes = 0,
    this.lastScanAt,
    this.total = 0,
    this.registered = 0,
    this.unregistered = 0,
    this.free = 0,
    this.scanning = false,
  });

  final int id;
  final int companyId;
  final String name;
  final String cidr;
  final int prefix;
  final String? gateway;
  final int? vlan;
  final String? location;
  final String? dhcpRange;
  final int autoScanMinutes;
  final DateTime? lastScanAt;
  final int total;
  final int registered;
  final int unregistered;
  final int free;
  final bool scanning;

  factory IpSubnetRow.fromJson(Map<String, dynamic> j) => IpSubnetRow(
    id: _i(j['id']),
    companyId: _i(j['companyId']),
    name: _s(j['name']),
    cidr: _s(j['cidr']),
    prefix: _i(j['prefix']),
    gateway: _ns(j['gateway']),
    vlan: _ni(j['vlan']),
    location: _ns(j['location']),
    dhcpRange: _ns(j['dhcpRange']),
    autoScanMinutes: _i(j['autoScanMinutes']),
    lastScanAt: _dt(j['lastScanAt']),
    total: _i(j['total']),
    registered: _i(j['registered']),
    unregistered: _i(j['unregistered']),
    free: _i(j['free']),
    scanning: _b(j['scanning']),
  );

  double get regPct => pctOf(registered, total);
  double get unregPct => pctOf(unregistered, total);
}

/// `Pct()` وب — با یک رقم اعشار
double pctOf(int part, int total) =>
    total <= 0 ? 0 : double.parse((part * 100.0 / total).toStringAsFixed(1));

/// رنج کامل — `map.subnet`
class IpSubnetInfo {
  const IpSubnetInfo({
    this.id = 0,
    this.companyId = 0,
    this.name = '',
    this.cidr = '',
    this.networkNum = 0,
    this.prefix = 0,
    this.gateway,
    this.vlan,
    this.dnsServers,
    this.dhcpRange,
    this.location,
    this.description,
    this.autoScanMinutes = 0,
    this.lastScanAt,
    this.lastScanAliveCount = 0,
    this.lastScanDurationMs = 0,
    this.updatedAt,
    this.updatedByName,
    this.broadcast = '',
    this.mask = '',
  });

  final int id;
  final int companyId;
  final String name;
  final String cidr;
  final int networkNum;
  final int prefix;
  final String? gateway;
  final int? vlan;
  final String? dnsServers;
  final String? dhcpRange;
  final String? location;
  final String? description;
  final int autoScanMinutes;
  final DateTime? lastScanAt;
  final int lastScanAliveCount;
  final int lastScanDurationMs;
  final DateTime? updatedAt;
  final String? updatedByName;
  final String broadcast;
  final String mask;

  factory IpSubnetInfo.fromJson(Map<String, dynamic> j) => IpSubnetInfo(
    id: _i(j['id']),
    companyId: _i(j['companyId']),
    name: _s(j['name']),
    cidr: _s(j['cidr']),
    networkNum: _i(j['networkNum']),
    prefix: _i(j['prefix']),
    gateway: _ns(j['gateway']),
    vlan: _ni(j['vlan']),
    dnsServers: _ns(j['dnsServers']),
    dhcpRange: _ns(j['dhcpRange']),
    location: _ns(j['location']),
    description: _ns(j['description']),
    autoScanMinutes: _i(j['autoScanMinutes']),
    lastScanAt: _dt(j['lastScanAt']),
    lastScanAliveCount: _i(j['lastScanAliveCount']),
    lastScanDurationMs: _i(j['lastScanDurationMs']),
    updatedAt: _dt(j['updatedAt']),
    updatedByName: _ns(j['updatedByName']),
    broadcast: _s(j['broadcast']),
    mask: _s(j['mask']),
  );

  bool get neverScanned => lastScanAt == null;
  String get durationFa => (lastScanDurationMs / 1000).toStringAsFixed(1);
}

/// آمار نقشه
class IpamStats {
  const IpamStats({
    this.total = 0,
    this.registered = 0,
    this.registeredOnline = 0,
    this.registeredOffline = 0,
    this.unregistered = 0,
    this.free = 0,
  });
  final int total;
  final int registered;
  final int registeredOnline;
  final int registeredOffline;
  final int unregistered;
  final int free;

  factory IpamStats.fromJson(Map<String, dynamic> j) => IpamStats(
    total: _i(j['total']),
    registered: _i(j['registered']),
    registeredOnline: _i(j['registeredOnline']),
    registeredOffline: _i(j['registeredOffline']),
    unregistered: _i(j['unregistered']),
    free: _i(j['free']),
  );

  double get usedPct => pctOf(registered + unregistered, total);
}

/// صاحب ثبت‌شده در یکی از شناسنامه‌ها
class IpOwner {
  const IpOwner({
    this.source = '',
    this.sourceTitle = '',
    this.refId = 0,
    this.title = '',
    this.detail,
    this.link,
    this.mac,
  });
  final String source;
  final String sourceTitle;
  final int refId;
  final String title;
  final String? detail;
  final String? link;
  final String? mac;

  factory IpOwner.fromJson(Map<String, dynamic> j) => IpOwner(
    source: _s(j['source']),
    sourceTitle: _s(j['sourceTitle']).isEmpty
        ? ipSourceFa(_s(j['source']))
        : _s(j['sourceTitle']),
    refId: _i(j['refId']),
    title: _s(j['title']),
    detail: _ns(j['detail']),
    link: _ns(j['link']),
    mac: _ns(j['mac']),
  );
}

/// رزرو دستی
class IpReserved {
  const IpReserved({
    this.title,
    this.type,
    this.owner,
    this.note,
    this.updatedAt,
    this.updatedByName,
  });
  final String? title;
  final String? type;
  final String? owner;
  final String? note;
  final DateTime? updatedAt;
  final String? updatedByName;

  factory IpReserved.fromJson(Map<String, dynamic> j) => IpReserved(
    title: _ns(j['title']),
    type: _ns(j['type']),
    owner: _ns(j['owner']),
    note: _ns(j['note']),
    updatedAt: _dt(j['updatedAt']),
    updatedByName: _ns(j['updatedByName']),
  );

  String get typeFa => reservedTypeFa(type);
}

/// یک آی‌پی در نقشه
class IpHost {
  const IpHost({
    this.ip = '',
    this.num = 0,
    this.state = 'free',
    this.alive = false,
    this.lastSeenAt,
    this.firstSeenAt,
    this.lastCheckedAt,
    this.mac,
    this.hostname,
    this.method,
    this.owners = const [],
    this.conflict = false,
    this.reserved,
    this.macHint,
    this.macMismatch,
  });

  final String ip;
  final int num;
  final String state;
  final bool alive;
  final DateTime? lastSeenAt;
  final DateTime? firstSeenAt;
  final DateTime? lastCheckedAt;
  final String? mac;
  final String? hostname;
  final String? method;
  final List<IpOwner> owners;
  final bool conflict;
  final IpReserved? reserved;
  final String? macHint;
  final String? macMismatch;

  factory IpHost.fromJson(Map<String, dynamic> j) {
    final r = j['reserved'];
    return IpHost(
      ip: _s(j['ip']),
      num: _i(j['num']),
      state: _s(j['state']).isEmpty ? 'free' : _s(j['state']),
      alive: _b(j['alive']),
      lastSeenAt: _dt(j['lastSeenAt']),
      firstSeenAt: _dt(j['firstSeenAt']),
      lastCheckedAt: _dt(j['lastCheckedAt']),
      mac: _ns(j['mac']),
      hostname: _ns(j['hostname']),
      method: _ns(j['method']),
      owners: _rows(j['owners']).map(IpOwner.fromJson).toList(),
      conflict: _b(j['conflict']),
      reserved: r is Map ? IpReserved.fromJson(_map(r)) : null,
      macHint: _ns(j['macHint']),
      macMismatch: _ns(j['macMismatch']),
    );
  }

  bool get isRegistered => state == 'registered';
  bool get isUnregistered => state == 'unregistered';
  bool get isFree => state == 'free';

  /// «ثبت‌شده · روشن / ثبت‌شده · خاموش / اشغال بدون شناسنامه / خالی»
  String get stateLabel {
    if (isRegistered) return alive ? 'ثبت‌شده · روشن' : 'ثبت‌شده · خاموش';
    if (isUnregistered) return 'اشغال بدون شناسنامه';
    return 'خالی';
  }

  /// مالکان غیر از رزرو دستی — `RegistryOwners()`
  List<IpOwner> get registryOwners =>
      owners.where((o) => o.source != 'Reserved').toList();

  String get methodFa => probeMethodFa(method);
}

/// وضعیت اسکن — `ScanDto`
class IpamScanStatus {
  const IpamScanStatus({
    this.running = false,
    this.progress = 0,
    this.total = 0,
    this.scanned = 0,
    this.found = 0,
    this.phase,
    this.startedBy,
    this.startedAt,
    this.finishedAt,
    this.error,
  });
  final bool running;
  final int progress;
  final int total;
  final int scanned;
  final int found;
  final String? phase;
  final String? startedBy;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? error;

  factory IpamScanStatus.fromJson(Map<String, dynamic> j) => IpamScanStatus(
    running: _b(j['running']),
    progress: _i(j['progress']),
    total: _i(j['total']),
    scanned: _i(j['scanned']),
    found: _i(j['found']),
    phase: _ns(j['phase']),
    startedBy: _ns(j['startedBy']),
    startedAt: _dt(j['startedAt']),
    finishedAt: _dt(j['finishedAt']),
    error: _ns(j['error']),
  );
}

/// پاسخ کامل `GET api/ipam/subnets/{id}/map`
class IpamMap {
  const IpamMap({
    required this.subnet,
    this.stats = const IpamStats(),
    this.hosts = const [],
    this.scan,
  });

  final IpSubnetInfo subnet;
  final IpamStats stats;
  final List<IpHost> hosts;
  final IpamScanStatus? scan;

  factory IpamMap.fromJson(Map<String, dynamic> j) => IpamMap(
    subnet: IpSubnetInfo.fromJson(_map(j['subnet'])),
    stats: IpamStats.fromJson(_map(j['stats'])),
    hosts: _rows(j['hosts']).map(IpHost.fromJson).toList(),
    scan: j['scan'] is Map ? IpamScanStatus.fromJson(_map(j['scan'])) : null,
  );

  /// تعداد مشکل‌دارها (تداخل / ناسازگاری MAC)
  int get problemCount => hosts
      .where((h) => h.conflict || (h.macMismatch ?? '').isNotEmpty)
      .length;

  Map<int, IpHost> get byNum => {for (final h in hosts) h.num: h};
}

/// نتیجهٔ `POST probe`
class IpProbeResult {
  const IpProbeResult({
    this.alive = false,
    this.method,
    this.mac,
    this.hostname,
  });
  final bool alive;
  final String? method;
  final String? mac;
  final String? hostname;

  factory IpProbeResult.fromJson(Map<String, dynamic> j) => IpProbeResult(
    alive: _b(j['alive']),
    method: _ns(j['method']),
    mac: _ns(j['mac']),
    hostname: _ns(j['hostname']),
  );

  String get methodFa => probeMethodFa(method);
}

/// فرم رنج — همان `SubnetDto`
class IpSubnetSaveRequest {
  const IpSubnetSaveRequest({
    this.companyId = 0,
    this.name = '',
    this.cidr = '',
    this.gateway,
    this.vlan,
    this.dnsServers,
    this.dhcpRange,
    this.location,
    this.description,
    this.autoScanMinutes = 0,
  });

  final int companyId;
  final String name;
  final String cidr;
  final String? gateway;
  final int? vlan;
  final String? dnsServers;
  final String? dhcpRange;
  final String? location;
  final String? description;
  final int autoScanMinutes;

  Map<String, dynamic> toJson() => {
    'companyId': companyId,
    'name': name,
    'cidr': cidr,
    'gateway': gateway,
    'vlan': vlan,
    'dnsServers': dnsServers,
    'dhcpRange': dhcpRange,
    'location': location,
    'description': description,
    'autoScanMinutes': autoScanMinutes,
  };
}

/// فرم رزرو — همان `ReserveDto`
class IpReserveRequest {
  const IpReserveRequest({
    this.ip = '',
    this.title,
    this.type,
    this.owner,
    this.note,
  });
  final String ip;
  final String? title;
  final String? type;
  final String? owner;
  final String? note;

  Map<String, dynamic> toJson() => {
    'ip': ip,
    'title': title,
    'type': type,
    'owner': owner,
    'note': note,
  };
}

// ============================================================
//  ابزارهای CIDR — معادل `IpamTools` سمت سرور برای پیش‌نمایش کلاینت
// ============================================================

/// «192.168.30.0/24» → (num, prefix) یا null
(int, int)? parseCidr(String text) {
  final t = text.trim();
  final slash = t.indexOf('/');
  if (slash < 0) return null;
  final ip = parseIpNum(t.substring(0, slash));
  final prefix = int.tryParse(t.substring(slash + 1).trim());
  if (ip == null || prefix == null) return null;
  if (prefix < 0 || prefix > 32) return null;
  final mask = prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
  return (ip & mask, prefix);
}

int? parseIpNum(String? text) {
  final t = (text ?? '').trim();
  if (t.isEmpty) return null;
  final parts = t.split('.');
  if (parts.length != 4) return null;
  var num = 0;
  for (final p in parts) {
    final v = int.tryParse(p);
    if (v == null || v < 0 || v > 255) return null;
    num = (num << 8) | v;
  }
  return num;
}

String ipFromNum(int n) =>
    '${(n >> 24) & 255}.${(n >> 16) & 255}.${(n >> 8) & 255}.${n & 255}';

/// بازهٔ میزبان‌ها — `HostRange()`
(int, int) hostRange(int networkNum, int prefix) {
  final size = 1 << (32 - prefix);
  if (prefix >= 31) return (networkNum, networkNum + size - 1);
  return (networkNum + 1, networkNum + size - 2);
}

/// راهنمای CIDR — عیناً `CidrHint` وب
String cidrHint(String cidr) {
  final parsed = parseCidr(cidr);
  if (parsed == null) return 'مثال: 192.168.30.0/24 (۲۵۴ آدرس)';
  final (net, prefix) = parsed;
  if (prefix < 22 || prefix > 30) return 'طول پیشوند باید بین /22 تا /30 باشد.';
  final size = 1 << (32 - prefix);
  return '${ipFromNum(net + 1)} تا ${ipFromNum(net + size - 2)} — '
      '${size - 2} آدرس قابل استفاده';
}

/// اعتبارسنجی فرم رنج — همان متن‌های `ValidateAsync()` سرور
String? validateSubnetForm(IpSubnetSaveRequest d) {
  if (d.name.trim().isEmpty) {
    return 'نام رنج را وارد کنید.';
  }
  final parsed = parseCidr(d.cidr);
  if (parsed == null) {
    return 'رنج CIDR نامعتبر است.';
  }
  final (net, prefix) = parsed;
  if (prefix < 22 || prefix > 30) {
    return 'طول پیشوند باید بین /22 تا /30 باشد.';
  }
  final gw = (d.gateway ?? '').trim();
  if (gw.isNotEmpty) {
    final n = parseIpNum(gw);
    if (n == null) {
      return 'آدرس گیت‌وی نامعتبر است.';
    }
    final (f, l) = hostRange(net, prefix);
    if (n < f || n > l) {
      return 'گیت‌وی باید داخل همین رنج باشد.';
    }
  }
  if (d.vlan != null && (d.vlan! < 1 || d.vlan! > 4094)) {
    return 'شمارهٔ VLAN باید بین ۱ تا ۴۰۹۴ باشد.';
  }
  if (d.autoScanMinutes != 0 &&
      (d.autoScanMinutes < 5 || d.autoScanMinutes > 1440)) {
    return 'فاصلهٔ اسکن خودکار باید بین ۵ تا ۱۴۴۰ دقیقه باشد (۰ = خاموش).';
  }
  return null;
}

/// بازهٔ DHCP — معادل `ParseRange()` وب («a-b» یا «a-200»)
(int, int) parseDhcpRange(String? range) {
  final r = (range ?? '').trim();
  if (r.isEmpty) return (0, 0);
  final parts = r.split('-');
  if (parts.length != 2) return (0, 0);
  final a = parseIpNum(parts[0].trim());
  if (a == null) return (0, 0);
  var b = parseIpNum(parts[1].trim());
  if (b == null) {
    final last = int.tryParse(parts[1].trim());
    if (last == null || last < 0 || last > 255) return (0, 0);
    b = (a & ~255) | last;
  }
  return a <= b ? (a, b) : (b, a);
}
