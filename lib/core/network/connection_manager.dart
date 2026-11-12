// ============================================================
//  مدیریت چند اتصال (چند سرور / چند آدرس برای هر سرور)
//
//  • «پروفایل اتصال» = یک سازمان/شرکتی که اپ در آن نصب است (مثلاً
//    «دفتر مرکزی» یا «کارخانه»). هر پروفایل نشست ورود جداگانهٔ خودش را دارد.
//  • هر پروفایل چند «آدرس» دارد (مثلاً شبکهٔ داخلی 192.168.x.x ، اینترنت،
//    VPN). ترتیب آدرس‌ها = اولویت.
//  • اگر شبکهٔ گوشی عوض شود و آدرس فعلی در دسترس نباشد، اپ خودکار آدرس
//    بعدیِ همان پروفایل را امتحان می‌کند و درخواست را دوباره می‌فرستد.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// یک آدرس سرور (مثلاً «شبکهٔ داخلی» → http://192.168.1.10:5100)
class ServerEndpoint {
  ServerEndpoint({required this.id, required this.label, required this.url});

  factory ServerEndpoint.fromJson(Map<String, dynamic> j) => ServerEndpoint(
    id: j['id']?.toString() ?? newConnectionId(),
    label: j['label']?.toString() ?? '',
    url: normalizeServerUrl(j['url']?.toString() ?? ''),
  );

  final String id;
  String label;
  String url;

  String get displayLabel => label.trim().isEmpty ? url : label.trim();

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'url': url};

  ServerEndpoint copy() => ServerEndpoint(id: id, label: label, url: url);
}

/// یک سازمان/شرکت با چند آدرس جایگزین
class ConnectionProfile {
  ConnectionProfile({
    required this.id,
    required this.name,
    required this.endpoints,
    this.autoSwitch = true,
  });

  factory ConnectionProfile.fromJson(Map<String, dynamic> j) =>
      ConnectionProfile(
        id: j['id']?.toString() ?? newConnectionId(),
        name: j['name']?.toString() ?? '',
        autoSwitch: j['autoSwitch'] != false,
        endpoints: (j['endpoints'] as List? ?? [])
            .whereType<Map>()
            .map((e) => ServerEndpoint.fromJson(Map<String, dynamic>.from(e)))
            .where((e) => e.url.isNotEmpty)
            .toList(),
      );

  final String id;
  String name;

  /// سوییچ خودکار بین آدرس‌ها وقتی آدرس فعلی قطع است
  bool autoSwitch;
  List<ServerEndpoint> endpoints;

  String get displayName => name.trim().isEmpty ? 'سرور بدون نام' : name.trim();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'autoSwitch': autoSwitch,
    'endpoints': endpoints.map((e) => e.toJson()).toList(),
  };

  ConnectionProfile copy() => ConnectionProfile(
    id: id,
    name: name,
    autoSwitch: autoSwitch,
    endpoints: endpoints.map((e) => e.copy()).toList(),
  );
}

enum ProbeState { unknown, checking, ok, fail }

class ProbeResult {
  const ProbeResult(this.state, [this.ms]);
  final ProbeState state;
  final int? ms;
}

String newConnectionId() {
  final r = Random();
  return DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
      r.nextInt(1 << 20).toRadixString(36);
}

/// یکدست‌سازی آدرس: حذف «/» انتهایی و افزودن اسکیم.
/// آدرس‌های IP/محلی بدون اسکیم → http ، دامنه‌ها → https
String normalizeServerUrl(String value) {
  var url = value.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  if (url.isEmpty) return '';
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    final host = url.split(RegExp(r'[/:]')).first.toLowerCase();
    final local = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(host) ||
        host == 'localhost' ||
        !host.contains('.') ||
        host.endsWith('.local') ||
        host.endsWith('.lan');
    url = '${local ? 'http' : 'https'}://$url';
  }
  return url;
}

/// اعتبارسنجی آدرس برای فرم‌ها (null یعنی معتبر)
String? validateServerUrl(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'آدرس را وارد کنید.';
  final uri = Uri.tryParse(normalizeServerUrl(v));
  if (uri == null || uri.host.isEmpty) return 'آدرس معتبر نیست.';
  return null;
}

/// کلیدهای ذخیره‌سازی (در سرویس پس‌زمینه هم خوانده می‌شوند)
class ConnectionKeys {
  static const profiles = 'conn_profiles';
  static const activeProfile = 'conn_active_profile';
  static const activeEndpoint = 'conn_active_endpoint';
  static const baseUrl = 'api_base_url';
}

/// آدرس‌های پروفایل فعال به ترتیب اولویت (برای سرویس پس‌زمینه / بومی).
Future<List<String>> activeProfileUrls(FlutterSecureStorage storage) async {
  try {
    final raw = await storage.read(key: ConnectionKeys.profiles);
    final active = await storage.read(key: ConnectionKeys.activeProfile);
    if (raw == null || raw.isEmpty) return const [];
    final list = (jsonDecode(raw) as List)
        .whereType<Map>()
        .map((e) => ConnectionProfile.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final p = list.where((e) => e.id == active).firstOrNull ??
        list.firstOrNull;
    return p?.endpoints.map((e) => e.url).toList() ?? const [];
  } catch (_) {
    return const [];
  }
}

/// آیا خطای Dio یعنی «سرور اصلاً در دسترس نیست» (نه خطای منطقی سرور)؟
bool isUnreachableError(DioException e) =>
    e.response == null &&
    (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout);

class ConnectionManager extends ChangeNotifier {
  ConnectionManager(this._storage, {Dio? probeDio})
    : _probeDio = probeDio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 4),
              receiveTimeout: const Duration(seconds: 5),
              sendTimeout: const Duration(seconds: 4),
              // هر پاسخی (حتی ۴۰۱/۴۰۴) یعنی سرور در دسترس است
              validateStatus: (_) => true,
              responseType: ResponseType.plain,
            ),
          );

  final FlutterSecureStorage _storage;
  final Dio _probeDio;

  List<ConnectionProfile> _profiles = [];
  String? _activeProfileId;
  String? _activeEndpointId;
  final Map<String, ProbeResult> _probes = {};

  /// وقتی آدرس فعال عوض می‌شود (ApiClient و سرویس اعلان گوش می‌دهند)
  Future<void> Function(String url, List<String> alternatives)? onApply;

  /// پیام کوتاه آخرین سوییچ خودکار (برای اسنک‌بار)
  final ValueNotifier<String?> lastAutoSwitch = ValueNotifier(null);

  bool loaded = false;

  List<ConnectionProfile> get profiles => List.unmodifiable(_profiles);
  String? get activeProfileId => _activeProfileId;

  ConnectionProfile? get activeProfile =>
      _profiles.where((p) => p.id == _activeProfileId).firstOrNull;

  ServerEndpoint? get activeEndpoint {
    final p = activeProfile;
    if (p == null || p.endpoints.isEmpty) return null;
    return p.endpoints.where((e) => e.id == _activeEndpointId).firstOrNull ??
        p.endpoints.first;
  }

  String? get activeUrl => activeEndpoint?.url;

  ProbeResult probeOf(String url) =>
      _probes[url] ?? const ProbeResult(ProbeState.unknown);

  // ------------------------------------------------------------------
  //  بارگذاری / ذخیره
  // ------------------------------------------------------------------

  /// [legacyBaseUrl]: آدرس تکیِ نسخه‌های قبلی که به پروفایل اول منتقل می‌شود.
  Future<void> load({String? legacyBaseUrl}) async {
    try {
      final raw = await _storage.read(key: ConnectionKeys.profiles);
      if (raw != null && raw.isNotEmpty) {
        _profiles = (jsonDecode(raw) as List)
            .whereType<Map>()
            .map((e) => ConnectionProfile.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {
      _profiles = [];
    }
    _activeProfileId = await _storage.read(key: ConnectionKeys.activeProfile);
    _activeEndpointId = await _storage.read(key: ConnectionKeys.activeEndpoint);

    if (_profiles.isEmpty) {
      final legacy = (legacyBaseUrl ??
              await _storage.read(key: ConnectionKeys.baseUrl) ??
              '')
          .trim();
      if (legacy.isNotEmpty) {
        final ep = ServerEndpoint(
          id: newConnectionId(),
          label: 'آدرس اصلی',
          url: normalizeServerUrl(legacy),
        );
        final p = ConnectionProfile(
          id: newConnectionId(),
          name: 'سرور من',
          endpoints: [ep],
        );
        _profiles = [p];
        _activeProfileId = p.id;
        _activeEndpointId = ep.id;
        await _save();
      }
    }
    // نسخهٔ وب که روی همان سرور سازمان نصب شده: همان آدرس صفحه = سرور
    if (_profiles.isEmpty && kIsWeb && Uri.base.scheme.startsWith('http')) {
      final ep = ServerEndpoint(
        id: newConnectionId(),
        label: 'همین سرور',
        url: Uri.base.origin,
      );
      final p = ConnectionProfile(
        id: newConnectionId(),
        name: Uri.base.host,
        endpoints: [ep],
      );
      _profiles = [p];
      _activeProfileId = p.id;
      _activeEndpointId = ep.id;
      await _save();
    }
    if (activeProfile == null && _profiles.isNotEmpty) {
      _activeProfileId = _profiles.first.id;
      _activeEndpointId = null;
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    await _storage.write(
      key: ConnectionKeys.profiles,
      value: jsonEncode(_profiles.map((p) => p.toJson()).toList()),
    );
    if (_activeProfileId == null) {
      await _storage.delete(key: ConnectionKeys.activeProfile);
    } else {
      await _storage.write(
        key: ConnectionKeys.activeProfile,
        value: _activeProfileId,
      );
    }
    final ep = activeEndpoint;
    if (ep == null) {
      await _storage.delete(key: ConnectionKeys.activeEndpoint);
    } else {
      await _storage.write(key: ConnectionKeys.activeEndpoint, value: ep.id);
    }
  }

  Future<void> _apply() async {
    final ep = activeEndpoint;
    if (ep == null) return;
    final alts = activeProfile!.endpoints.map((e) => e.url).toList();
    await onApply?.call(ep.url, alts);
  }

  // ------------------------------------------------------------------
  //  ویرایش پروفایل‌ها
  // ------------------------------------------------------------------

  /// افزودن یا جایگزینی پروفایل. اگر اولین پروفایل باشد فعال هم می‌شود.
  Future<void> upsertProfile(ConnectionProfile profile) async {
    final i = _profiles.indexWhere((p) => p.id == profile.id);
    if (i >= 0) {
      _profiles[i] = profile;
    } else {
      _profiles.add(profile);
    }
    _activeProfileId ??= profile.id;
    final isActive = profile.id == _activeProfileId;
    if (isActive &&
        !profile.endpoints.any((e) => e.id == _activeEndpointId)) {
      _activeEndpointId =
          profile.endpoints.isEmpty ? null : profile.endpoints.first.id;
    }
    await _save();
    if (isActive) await _apply();
    notifyListeners();
  }

  /// حذف پروفایل غیرفعال (پروفایل فعال باید اول عوض شود)
  Future<bool> deleteProfile(String id) async {
    if (id == _activeProfileId && _profiles.length > 1) return false;
    _profiles.removeWhere((p) => p.id == id);
    if (id == _activeProfileId) {
      _activeProfileId = null;
      _activeEndpointId = null;
    }
    await _storage.delete(key: 'conn_session_$id');
    await _save();
    notifyListeners();
    return true;
  }

  Future<void> reorderProfiles(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final p = _profiles.removeAt(oldIndex);
    _profiles.insert(newIndex, p);
    await _save();
    notifyListeners();
  }

  // ------------------------------------------------------------------
  //  انتخاب آدرس / پروفایل
  // ------------------------------------------------------------------

  /// انتخاب دستی یک آدرس در پروفایل فعال (بدون نیاز به ورود دوباره)
  Future<void> selectEndpoint(String endpointId) async {
    final p = activeProfile;
    if (p == null || !p.endpoints.any((e) => e.id == endpointId)) return;
    _activeEndpointId = endpointId;
    await _save();
    await _apply();
    notifyListeners();
  }

  /// فعال‌کردن پروفایل دیگر (نشست‌ها را AuthController جابه‌جا می‌کند).
  /// اگر [pickBest] باشد، اولین آدرس در دسترس انتخاب می‌شود.
  Future<void> activateProfile(String profileId, {bool pickBest = true}) async {
    final p = _profiles.where((e) => e.id == profileId).firstOrNull;
    if (p == null) return;
    _activeProfileId = p.id;
    _activeEndpointId = p.endpoints.isEmpty ? null : p.endpoints.first.id;
    if (pickBest && p.endpoints.length > 1) {
      final best = await findBest(p);
      if (best != null) _activeEndpointId = best.id;
    }
    await _save();
    await _apply();
    notifyListeners();
  }

  // ------------------------------------------------------------------
  //  تست اتصال و سوییچ خودکار
  // ------------------------------------------------------------------

  /// زمان پاسخ سرور به میلی‌ثانیه، یا null اگر در دسترس نبود.
  Future<int?> probe(String url) async {
    _probes[url] = const ProbeResult(ProbeState.checking);
    notifyListeners();
    final sw = Stopwatch()..start();
    int? ms;
    try {
      final r = await _probeDio.get<String>(
        '${url.replaceAll(RegExp(r'/+$'), '')}/api/company-context',
      );
      if (r.statusCode != null) ms = sw.elapsedMilliseconds;
    } catch (_) {
      ms = null;
    }
    _probes[url] = ms == null
        ? const ProbeResult(ProbeState.fail)
        : ProbeResult(ProbeState.ok, ms);
    notifyListeners();
    return ms;
  }

  /// تست همهٔ آدرس‌های یک پروفایل به‌صورت هم‌زمان.
  Future<void> probeAll([ConnectionProfile? profile]) async {
    final p = profile ?? activeProfile;
    if (p == null) return;
    await Future.wait(p.endpoints.map((e) => probe(e.url)));
  }

  /// اولین آدرس در دسترس به ترتیب اولویت (همه هم‌زمان تست می‌شوند).
  Future<ServerEndpoint?> findBest(ConnectionProfile p) async {
    if (p.endpoints.isEmpty) return null;
    final results = await Future.wait(p.endpoints.map((e) => probe(e.url)));
    for (var i = 0; i < p.endpoints.length; i++) {
      if (results[i] != null) return p.endpoints[i];
    }
    return null;
  }

  Future<String?>? _failoverInFlight;
  DateTime? _lastFailedFailover;

  /// وقتی درخواست به [failedBase] نرسید صدا زده می‌شود. اگر آدرس دیگری از
  /// همین پروفایل در دسترس باشد به آن سوییچ کرده و آدرس جدید را برمی‌گرداند.
  Future<String?> failover(String failedBase) {
    return _failoverInFlight ??= _doFailover(failedBase).whenComplete(() {
      _failoverInFlight = null;
    });
  }

  Future<String?> _doFailover(String failedBase) async {
    final p = activeProfile;
    if (p == null || !p.autoSwitch || p.endpoints.length < 2) return null;
    final failed = normalizeServerUrl(failedBase);
    // اگر چند ثانیه پیش همه را تست کردیم و هیچ‌کدام نبود، دوباره تست نکن
    if (_lastFailedFailover != null &&
        DateTime.now().difference(_lastFailedFailover!) <
            const Duration(seconds: 8)) {
      return null;
    }
    // شاید در همین فاصله سوییچ شده باشد
    if (activeUrl != null && activeUrl != failed) return activeUrl;
    final best = await findBest(p);
    if (best == null || best.url == failed) {
      if (best == null) _lastFailedFailover = DateTime.now();
      return null;
    }
    _lastFailedFailover = null;
    _activeEndpointId = best.id;
    await _save();
    await _apply();
    lastAutoSwitch.value = 'اتصال به «${best.displayLabel}» سوییچ شد';
    notifyListeners();
    return best.url;
  }

  /// بعد از برگشت اپ به صفحه: اگر آدرس با اولویت بالاتری در دسترس شد
  /// (مثلاً به وای‌فای شرکت وصل شدید) یا آدرس فعلی قطع است، سوییچ کن.
  Future<void> recheck() async {
    final p = activeProfile;
    if (p == null || !p.autoSwitch || p.endpoints.length < 2) return;
    final best = await findBest(p);
    if (best == null || best.id == activeEndpoint?.id) return;
    _activeEndpointId = best.id;
    await _save();
    await _apply();
    lastAutoSwitch.value = 'اتصال به «${best.displayLabel}» سوییچ شد';
    notifyListeners();
  }

  @override
  void dispose() {
    lastAutoSwitch.dispose();
    super.dispose();
  }
}
