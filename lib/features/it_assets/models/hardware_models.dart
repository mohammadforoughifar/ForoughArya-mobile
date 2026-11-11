// ============================================================
//  مدل‌های «مدیریت سخت‌افزار» — فاز ۹-الف
//  منابع (عیناً، بدون فیلد اضافه):
//    Inventory.Api/Hubs/System/HardwareMonitor.cs → HardwareStats / HardwareDeviceStatus
//    Inventory.Api/Controllers/ItAssets/ItRequestsController.cs → GET api/itrequests/stats
// ============================================================

/// یک دستگاه پایش‌شده (سیستم / دوربین / NVR) — آینهٔ `HardwareDeviceStatus`
class HardwareDevice {
  const HardwareDevice({
    this.kind = '',
    this.id = 0,
    this.name = '',
    this.ip = '',
    this.extra = '',
    this.online,
    this.health,
  });

  /// system | camera | nvr
  final String kind;
  final int id;
  final String name;
  final String ip;

  /// محل استقرار / وضعیت تایید
  final String extra;

  /// null = بدون IP قابل بررسی
  final bool? online;

  /// امتیاز سلامت ۰ تا ۱۰۰ (فقط سیستم‌ها)
  final int? health;

  String get ipText => ip.trim().isEmpty ? 'بدون IP' : ip;

  factory HardwareDevice.fromJson(Map<String, dynamic> j) => HardwareDevice(
    kind: (j['kind'] ?? '').toString(),
    id: (j['id'] as num?)?.toInt() ?? 0,
    name: (j['name'] ?? '').toString(),
    ip: (j['ip'] ?? '').toString(),
    extra: (j['extra'] ?? '').toString(),
    online: j['online'] is bool ? j['online'] as bool : null,
    health: (j['health'] as num?)?.toInt(),
  );
}

/// آمار کامل داشبورد سخت‌افزار — آینهٔ `HardwareStats`
class HardwareStats {
  const HardwareStats({
    this.sweeping = false,
    this.lastSweepAt,
    this.systemsTotal = 0,
    this.systemsApproved = 0,
    this.systemsPending = 0,
    this.systemsAvgHealth,
    this.camerasTotal = 0,
    this.camerasActiveFlag = 0,
    this.nvrsTotal = 0,
    this.nvrsActiveFlag = 0,
    this.devices = const [],
  });

  final bool sweeping;
  final DateTime? lastSweepAt;
  final int systemsTotal;
  final int systemsApproved;
  final int systemsPending;
  final int? systemsAvgHealth;
  final int camerasTotal;
  final int camerasActiveFlag;
  final int nvrsTotal;
  final int nvrsActiveFlag;
  final List<HardwareDevice> devices;

  List<HardwareDevice> ofKind(String kind) =>
      devices.where((d) => d.kind == kind).toList();

  List<HardwareDevice> get systems => ofKind('system');
  List<HardwareDevice> get cameras => ofKind('camera');
  List<HardwareDevice> get nvrs => ofKind('nvr');

  /// «دوربین‌های غیرفعال (ثبت)» — همان محاسبهٔ وب
  int get camerasInactive => camerasTotal - camerasActiveFlag;

  factory HardwareStats.fromJson(Map<String, dynamic> j) => HardwareStats(
    sweeping: j['sweeping'] == true,
    lastSweepAt: DateTime.tryParse(
      (j['lastSweepAt'] ?? '').toString(),
    )?.toLocal(),
    systemsTotal: (j['systemsTotal'] as num?)?.toInt() ?? 0,
    systemsApproved: (j['systemsApproved'] as num?)?.toInt() ?? 0,
    systemsPending: (j['systemsPending'] as num?)?.toInt() ?? 0,
    systemsAvgHealth: (j['systemsAvgHealth'] as num?)?.toInt(),
    camerasTotal: (j['camerasTotal'] as num?)?.toInt() ?? 0,
    camerasActiveFlag: (j['camerasActiveFlag'] as num?)?.toInt() ?? 0,
    nvrsTotal: (j['nvrsTotal'] as num?)?.toInt() ?? 0,
    nvrsActiveFlag: (j['nvrsActiveFlag'] as num?)?.toInt() ?? 0,
    devices: (j['devices'] as List? ?? [])
        .whereType<Map>()
        .map((e) => HardwareDevice.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

/// شمارنده‌های یک گروه از دستگاه‌ها (همان `Group` وب: Sys / Cam / Nvr)
class HardwareGroupStats {
  const HardwareGroupStats({
    required this.total,
    required this.online,
    required this.offline,
    required this.noIp,
    required this.items,
  });

  final int total;
  final int online;
  final int offline;
  final int noIp;
  final List<HardwareDevice> items;

  /// درصد آنلاین برای نمودار حلقه‌ای — مثل وب
  int get onlinePercent => total <= 0 ? 0 : (online * 100 / total).floor();

  factory HardwareGroupStats.of(List<HardwareDevice> items) {
    var online = 0, offline = 0, noIp = 0;
    for (final d in items) {
      if (d.online == null) {
        noIp++;
      } else if (d.online == true) {
        online++;
      } else {
        offline++;
      }
    }
    return HardwareGroupStats(
      total: items.length,
      online: online,
      offline: offline,
      noIp: noIp,
      items: items,
    );
  }
}

/// آمار درخواست‌های خدمت IT — آینهٔ پاسخ `GET api/itrequests/stats`
class ItStats {
  const ItStats({
    this.total = 0,
    this.completed = 0,
    this.inProgress = 0,
    this.waitingManager = 0,
    this.newOnes = 0,
    this.waitingDecision = 0,
    this.waitingRequester = 0,
    this.rejected = 0,
  });

  final int total;
  final int completed;
  final int inProgress;
  final int waitingManager;
  final int newOnes;
  final int waitingDecision;
  final int waitingRequester;
  final int rejected;

  factory ItStats.fromJson(Map<String, dynamic> j) => ItStats(
    total: (j['total'] as num?)?.toInt() ?? 0,
    completed: (j['completed'] as num?)?.toInt() ?? 0,
    inProgress: (j['inProgress'] as num?)?.toInt() ?? 0,
    waitingManager: (j['waitingManager'] as num?)?.toInt() ?? 0,
    newOnes: (j['newOnes'] as num?)?.toInt() ?? 0,
    waitingDecision: (j['waitingDecision'] as num?)?.toInt() ?? 0,
    waitingRequester: (j['waitingRequester'] as num?)?.toInt() ?? 0,
    rejected: (j['rejected'] as num?)?.toInt() ?? 0,
  );
}

/// یک میلهٔ نمودار «درخواست‌های خدمت IT — واحد» — عیناً `ItBar` وب
class ItBar {
  const ItBar({
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
    this.sub,
  });

  final String label;
  final int value;

  /// ارتفاع میله ۰ تا ۱۰۰ (حداقل ۴ برای مقادیر بزرگ‌تر از صفر — مثل وب)
  final int percent;
  final int color;
  final String? sub;

  /// ترتیب و رنگ‌ها عیناً از `ItBars` در DashboardHardware.razor
  static List<ItBar> from(ItStats s) {
    final list = [s.total, s.completed, s.inProgress, s.waitingManager];
    var max = 1;
    for (final v in list) {
      if (v > max) max = v;
    }
    int pct(int v) => v > 0 ? (v * 100 / max).round().clamp(4, 100) : 0;
    return [
      ItBar(
        label: 'کل درخواست‌ها',
        value: s.total,
        percent: pct(s.total),
        color: 0xff3f8cff,
      ),
      ItBar(
        label: 'انجام‌شده',
        value: s.completed,
        percent: pct(s.completed),
        color: 0xff2ec47e,
      ),
      ItBar(
        label: 'در حال اجرا',
        value: s.inProgress,
        percent: pct(s.inProgress),
        color: 0xfff4a23c,
      ),
      ItBar(
        label: 'در انتظار مدیر واحد',
        value: s.waitingManager,
        percent: pct(s.waitingManager),
        color: 0xffe0245e,
        sub: 'جدید: ${s.newOnes} | تایید گزارش: ${s.waitingDecision}',
      ),
    ];
  }
}
