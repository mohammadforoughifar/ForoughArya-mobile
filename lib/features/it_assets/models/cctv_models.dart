// ============================================================
//  مدل‌های «دوربین‌های مداربسته» و «دستگاه‌های NVR» — فاز ۹-و
//  منبع: `Inventory.Api/Controllers/Cctv/CctvCamerasController.cs` (api/CctvCameras)
//        `Inventory.Api/Controllers/Cctv/CctvNvrsController.cs`    (api/CctvNvrs)
//        `Inventory.Client/Pages/Cctv/CctvCameras.razor` و `CctvNvrs.razor`
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

// ============================================================
//  دوربین
// ============================================================

class CctvCameraRow {
  const CctvCameraRow({
    this.id = 0,
    this.model = '',
    this.serialNumber = '',
    this.ip,
    this.mac,
    this.location,
    this.notes,
    this.nvrId,
    this.isActive = true,
    this.createdAt,
  });

  final int id;
  final String model;
  final String serialNumber;
  final String? ip;
  final String? mac;
  final String? location;
  final String? notes;
  final int? nvrId;
  final bool isActive;
  final DateTime? createdAt;

  factory CctvCameraRow.fromJson(Map<String, dynamic> j) => CctvCameraRow(
    id: _i(j['id']),
    model: _s(j['model']),
    serialNumber: _s(j['serialNumber']),
    ip: _ns(j['ip']),
    mac: _ns(j['mac']),
    location: _ns(j['location']),
    notes: _ns(j['notes']),
    nvrId: _ni(j['nvrId']),
    isActive: j['isActive'] == null ? true : _b(j['isActive']),
    createdAt: _dt(j['createdAt']),
  );

  String get ipCell => (ip ?? '').isEmpty ? '—' : ip!;
  String get macCell => (mac ?? '').isEmpty ? '—' : mac!;
  String get locationCell => (location ?? '').isEmpty ? '—' : location!;
  String get statusCell => isActive ? 'فعال' : 'غیرفعال';

  /// جستجوی وب (`filtered`): مدل / سریال / آی‌پی / مک / محل
  bool matches(String q) {
    final t = q.toLowerCase();
    return model.toLowerCase().contains(t) ||
        serialNumber.toLowerCase().contains(t) ||
        (ip ?? '').toLowerCase().contains(t) ||
        (mac ?? '').toLowerCase().contains(t) ||
        (location ?? '').toLowerCase().contains(t);
  }
}

/// فرم دوربین — عیناً `CameraForm` وب
class CctvCameraForm {
  CctvCameraForm({
    this.id = 0,
    this.model = '',
    this.serialNumber = '',
    this.ip,
    this.mac,
    this.location = '',
    this.notes,
    this.isActive = true,
    this.nvrId,
  });

  final int id;
  final String model;
  final String serialNumber;
  final String? ip;
  final String? mac;
  final String location;
  final String? notes;
  final bool isActive;
  final int? nvrId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'model': model,
    'serialNumber': serialNumber,
    'ip': ip,
    'mac': mac,
    'location': location,
    'notes': notes,
    'nvrId': nvrId,
    'isActive': isActive,
  };

  static CctvCameraForm fromRow(CctvCameraRow r) => CctvCameraForm(
    id: r.id,
    model: r.model,
    serialNumber: r.serialNumber,
    ip: r.ip,
    mac: r.mac,
    location: r.location ?? '',
    notes: r.notes,
    isActive: r.isActive,
    nvrId: r.nvrId,
  );
}

/// اعتبارسنجی فرم دوربین — همان سه پیام `Save()` وب با همان ترتیب
String? validateCameraForm(CctvCameraForm f) {
  if (f.model.trim().isEmpty) {
    return 'مدل را وارد کنید.';
  }
  if (f.serialNumber.trim().isEmpty) {
    return 'شماره سریال را وارد کنید.';
  }
  if (f.location.trim().isEmpty) {
    return 'محل استقرار را وارد کنید.';
  }
  return null;
}

// ============================================================
//  NVR / DVR
// ============================================================

class CctvNvrRow {
  const CctvNvrRow({
    this.id = 0,
    this.model = '',
    this.serialNumber = '',
    this.ip,
    this.mac,
    this.location,
    this.notes,
    this.isActive = true,
    this.createdAt,
  });

  final int id;
  final String model;
  final String serialNumber;
  final String? ip;
  final String? mac;
  final String? location;
  final String? notes;
  final bool isActive;
  final DateTime? createdAt;

  factory CctvNvrRow.fromJson(Map<String, dynamic> j) => CctvNvrRow(
    id: _i(j['id']),
    model: _s(j['model']),
    serialNumber: _s(j['serialNumber']),
    ip: _ns(j['ip']),
    mac: _ns(j['mac']),
    location: _ns(j['location']),
    notes: _ns(j['notes']),
    isActive: j['isActive'] == null ? true : _b(j['isActive']),
    createdAt: _dt(j['createdAt']),
  );

  String get ipCell => (ip ?? '').isEmpty ? '—' : ip!;
  String get macCell => (mac ?? '').isEmpty ? '—' : mac!;
  String get locationCell => (location ?? '').isEmpty ? '—' : location!;

  /// متن گزینهٔ مودال دوربین — عیناً وب:
  /// «مدل (سریال) — محل»
  String get optionLabel =>
      '$model ($serialNumber)${(location ?? '').isEmpty ? '' : ' — $location'}';

  /// جستجوی وب: مدل / سریال / آی‌پی / محل
  bool matches(String q) {
    final t = q.toLowerCase();
    return model.toLowerCase().contains(t) ||
        serialNumber.toLowerCase().contains(t) ||
        (ip ?? '').toLowerCase().contains(t) ||
        (location ?? '').toLowerCase().contains(t);
  }
}

/// فرم NVR — عیناً `NvrForm` وب
class CctvNvrForm {
  CctvNvrForm({
    this.id = 0,
    this.model = '',
    this.serialNumber = '',
    this.ip,
    this.mac,
    this.location,
    this.notes,
    this.isActive = true,
  });

  final int id;
  final String model;
  final String serialNumber;
  final String? ip;
  final String? mac;
  final String? location;
  final String? notes;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'id': id,
    'model': model,
    'serialNumber': serialNumber,
    'ip': ip,
    'mac': mac,
    'location': location,
    'notes': notes,
    'isActive': isActive,
  };

  static CctvNvrForm fromRow(CctvNvrRow r) => CctvNvrForm(
    id: r.id,
    model: r.model,
    serialNumber: r.serialNumber,
    ip: r.ip,
    mac: r.mac,
    location: r.location,
    notes: r.notes,
    isActive: r.isActive,
  );
}

/// اعتبارسنجی فرم NVR — همان دو پیام `Save()` وب با همان ترتیب
String? validateNvrForm(CctvNvrForm f) {
  if (f.model.trim().isEmpty) {
    return 'مدل را وارد کنید.';
  }
  if (f.serialNumber.trim().isEmpty) {
    return 'شماره سریال را وارد کنید.';
  }
  return null;
}

// ============================================================
//  ورود گروهی از اکسل
// ============================================================

/// پاسخ `POST api/CctvCameras/import-excel`
class CctvImportResult {
  const CctvImportResult({
    this.inserted = 0,
    this.skipped = 0,
    this.errors = const [],
  });
  final int inserted;
  final int skipped;
  final List<String> errors;

  factory CctvImportResult.fromJson(Map<String, dynamic> j) {
    final e = j['errors'];
    return CctvImportResult(
      inserted: _i(j['inserted']),
      skipped: _i(j['skipped']),
      errors: e is List ? e.map((x) => '$x').toList() : const [],
    );
  }

  /// «۱۲ دوربین ثبت شد؛ ۳ رد شد (خالی/تکراری).»
  String get summaryFa =>
      '$inserted دوربین ثبت شد؛ $skipped رد شد (خالی/تکراری).';

  bool get hasErrors => errors.isNotEmpty;
  List<String> get firstErrors => errors.take(10).toList();
}

// ============================================================
//  گروه‌بندی و فیلتر — عیناً منطق `Grouped` / `Locations` وب
// ============================================================

enum CctvGroupMode { location, nvr, none }

const List<MapEntry<CctvGroupMode, String>> kCctvGroupModes = [
  MapEntry(CctvGroupMode.location, 'گروه‌بندی: محل'),
  MapEntry(CctvGroupMode.nvr, 'گروه‌بندی: NVR'),
  MapEntry(CctvGroupMode.none, 'بدون گروه‌بندی'),
];

class CctvGroup {
  const CctvGroup({required this.key, required this.items});
  final String key;
  final List<CctvCameraRow> items;
}

/// نام NVR برای نمایش در ردیف دوربین — `NvrName()` وب («—» اگر نبود)
String cctvNvrName(List<CctvNvrRow> nvrs, int? nvrId) {
  for (final n in nvrs) {
    if (n.id == nvrId) return n.model;
  }
  return '—';
}

/// محل‌های یکتا برای فیلتر — `Locations` وب (مرتب‌شده)
List<String> cctvLocations(List<CctvCameraRow> items) {
  final set = <String>{};
  for (final c in items) {
    final l = (c.location ?? '').trim();
    if (l.isNotEmpty) set.add(l);
  }
  final list = set.toList()..sort();
  return list;
}

/// تعداد دوربین‌های یک محل — `CamerasAt()` وب
int cctvCamerasAt(List<CctvCameraRow> items, String location) =>
    items.where((c) => (c.location ?? '') == location).length;

/// گروه‌بندی — `Grouped` وب. برای حالت محل، گروه «بدون محل مشخص» ساخته می‌شود.
List<CctvGroup> groupCameras(
  List<CctvCameraRow> filtered,
  CctvGroupMode mode,
  List<CctvNvrRow> nvrs,
) {
  if (mode == CctvGroupMode.none) {
    return [CctvGroup(key: '', items: filtered)];
  }
  final map = <String, List<CctvCameraRow>>{};
  for (final c in filtered) {
    final key = mode == CctvGroupMode.nvr
        ? cctvNvrName(nvrs, c.nvrId)
        : ((c.location ?? '').trim().isEmpty
              ? 'بدون محل مشخص'
              : (c.location ?? '').trim());
    map.putIfAbsent(key, () => []).add(c);
  }
  final keys = map.keys.toList()..sort();
  return [
    for (final k in keys) CctvGroup(key: k, items: map[k]!),
  ];
}
