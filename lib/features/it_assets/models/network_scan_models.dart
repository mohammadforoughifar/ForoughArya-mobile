// ============================================================
//  مدل‌های «اسکن شبکه» — فاز ۹-ز
//  منبع: `Inventory.Api/Controllers/Cctv/NetworkScanController.cs` (api/NetworkScan)
//        `Inventory.Api/Controllers/Cctv/CctvScanController.cs`    (api/CctvScan)
//        `Inventory.Client/Pages/ItAssets/NetworkScan.razor` (/network-scan)
//
//  ۱) اسکن سیستم‌های شبکه به شکل Job:  POST start → { jobId, targetCount, range, localIp }
//     و GET status/{jobId} → پیشرفت + میزبان‌های یافته‌شده
//  ۲) اسکن دوربین/NVR: GET api/CctvScan → دستگاه‌های CCTV با امتیاز اطمینان
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

List<Map<String, dynamic>> _rows(Object? v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];

// ============================================================
//  انتخاب رنج
// ============================================================

enum ScanRangeMode { auto, manual }

const List<MapEntry<ScanRangeMode, String>> kScanRangeModes = [
  MapEntry(ScanRangeMode.auto, 'خودکار — شبکه‌ی خودم'),
  MapEntry(ScanRangeMode.manual, 'دستی — خودم می‌نویسم'),
];

/// متن راهنمای زیر فیلد رنج دستی — عیناً وب
const String kScanRangeHint =
    'فرمت‌ها: پیشوند /24 — یا CIDR — یا بازه‌ی شروع-پایان';

const String kScanRangePlaceholder =
    'مثال: 192.168.1 یا 192.168.1.0/24 یا 192.168.1.1-192.168.1.254';

/// پاسخ `POST api/NetworkScan/start`
class ScanStartResult {
  const ScanStartResult({
    this.jobId = '',
    this.targetCount = 0,
    this.range = '',
    this.localIp = '',
  });
  final String jobId;
  final int targetCount;
  final String range;
  final String localIp;

  factory ScanStartResult.fromJson(Map<String, dynamic> j) => ScanStartResult(
    jobId: _s(j['jobId']),
    targetCount: _i(j['targetCount']),
    range: _s(j['range']),
    localIp: _s(j['localIp']),
  );
}

/// یک میزبان پیدا‌شده — `ScanHost`
class ScanHost {
  const ScanHost({
    this.ip = '',
    this.hostname = '',
    this.mac = '',
    this.systemInfoId,
    this.method = 'ping',
  });
  final String ip;
  final String hostname;
  final String mac;
  final int? systemInfoId;
  final String method;

  factory ScanHost.fromJson(Map<String, dynamic> j) => ScanHost(
    ip: _s(j['ip']),
    hostname: _s(j['hostname']),
    mac: _s(j['mac']),
    systemInfoId: _ni(j['systemInfoId']),
    method: _s(j['method']).isEmpty ? 'ping' : _s(j['method']),
  );

  bool get isTcp => method == 'tcp';
  String get methodLabel => isTcp ? 'TCP' : 'پینگ';
  String get hostnameCell => hostname.trim().isEmpty ? '—' : hostname;
  String get macCell => mac.trim().isEmpty ? '—' : mac;
  bool get isRegistered => (systemInfoId ?? 0) > 0;
  String get registeredLabel => 'ثبت‌شده (#${systemInfoId ?? 0})';
}

/// وضعیت اسکن — `ScanStatus`
class ScanStatus {
  const ScanStatus({
    this.running = false,
    this.progress = 0,
    this.scanned = 0,
    this.targetCount = 0,
    this.foundCount = 0,
    this.range = '',
    this.localIp = '',
    this.adapter = '',
    this.elapsedMs = 0,
    this.error,
    this.hosts = const [],
  });
  final bool running;
  final int progress;
  final int scanned;
  final int targetCount;
  final int foundCount;
  final String range;
  final String localIp;
  final String adapter;
  final int elapsedMs;
  final String? error;
  final List<ScanHost> hosts;

  factory ScanStatus.fromJson(Map<String, dynamic> j) => ScanStatus(
    running: _b(j['running']),
    progress: _i(j['progress']),
    scanned: _i(j['scanned']),
    targetCount: _i(j['targetCount']),
    foundCount: _i(j['foundCount']),
    range: _s(j['range']),
    localIp: _s(j['localIp']),
    adapter: _s(j['adapter']),
    elapsedMs: _i(j['elapsedMs']),
    error: _ns(j['error']),
    hosts: _rows(j['hosts']).map(ScanHost.fromJson).toList(),
  );

  /// «کل اسکن: X ثانیه» با یک رقم اعشار — مثل `ToString("0.#")` وب
  String get elapsedFa => (elapsedMs / 1000.0).toStringAsFixed(1);

  bool get finished => !running;
  bool get isEmptyAndDone =>
      !running && hosts.isEmpty && (error ?? '').isEmpty;
}

// ============================================================
//  اسکن دوربین و NVR — `CctvScanResult`
// ============================================================

class CctvScanDevice {
  const CctvScanDevice({
    this.ip = '',
    this.kind = 'unknown',
    this.vendor = '',
    this.openPorts = const [],
    this.rtspServer = '',
    this.httpTitle = '',
    this.onvif = false,
    this.onvifInfo = '',
    this.mac = '',
    this.macVendor = '',
    this.confidence = 'low',
  });

  final String ip;

  /// camera | nvr | unknown
  final String kind;
  final String vendor;
  final List<int> openPorts;
  final String rtspServer;
  final String httpTitle;
  final bool onvif;
  final String onvifInfo;
  final String mac;
  final String macVendor;

  /// high | medium | low
  final String confidence;

  factory CctvScanDevice.fromJson(Map<String, dynamic> j) {
    final ports = j['openPorts'];
    return CctvScanDevice(
      ip: _s(j['ip']),
      kind: _s(j['kind']).isEmpty ? 'unknown' : _s(j['kind']),
      vendor: _s(j['vendor']),
      openPorts: ports is List
          ? ports.map((p) => _i(p)).where((p) => p > 0).toList()
          : const [],
      rtspServer: _s(j['rtspServer']),
      httpTitle: _s(j['httpTitle']),
      onvif: _b(j['onvif']),
      onvifInfo: _s(j['onvifInfo']),
      mac: _s(j['mac']),
      macVendor: _s(j['macVendor']),
      confidence: _s(j['confidence']).isEmpty ? 'low' : _s(j['confidence']),
    );
  }

  /// برچسب نوع دستگاه — عیناً سه حالت وب
  String get kindLabel => switch (kind) {
    'camera' => '📷 دوربین',
    'nvr' => '📼 NVR/DVR',
    _ => 'نامشخص',
  };

  /// برچسب اطمینان تشخیص — «بالا / متوسط / نیاز به بررسی»
  String get confidenceLabel => switch (confidence) {
    'high' => 'بالا',
    'medium' => 'متوسط',
    _ => 'نیاز به بررسی',
  };

  String get vendorCell => vendor.isEmpty ? '—' : vendor;
  String get rtspCell => rtspServer.isEmpty ? '—' : rtspServer;

  /// «پورت‌های باز» با «،» — همان `string.Join("،", ...)` وب
  String get portsCell => openPorts.isEmpty
      ? '—'
      : openPorts.map((p) => '$p').join('، ');

  /// «MAC (MACVendor)» یا «—»
  String get macCell {
    final base = mac.isEmpty ? '—' : mac;
    return macVendor.isEmpty ? base : '$base ($macVendor)';
  }
}

class CctvScanResult {
  const CctvScanResult({
    this.localIp = '',
    this.subnet = '',
    this.scannedCount = 0,
    this.elapsedMs = 0,
    this.devices = const [],
  });
  final String localIp;
  final String subnet;
  final int scannedCount;
  final int elapsedMs;
  final List<CctvScanDevice> devices;

  factory CctvScanResult.fromJson(Map<String, dynamic> j) => CctvScanResult(
    localIp: _s(j['localIp']),
    subnet: _s(j['subnet']),
    scannedCount: _i(j['scannedCount']),
    elapsedMs: _i(j['elapsedMs']),
    devices: _rows(j['devices']).map(CctvScanDevice.fromJson).toList(),
  );

  /// «X آدرس بررسی شد در Y ثانیه» — مثل `ToString("0.#")` وب
  String get summaryFa =>
      '$scannedCount آدرس بررسی شد در ${(elapsedMs / 1000.0).toStringAsFixed(1)} ثانیه';

  bool get isEmpty => devices.isEmpty;
}
