import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/api_client.dart';
import '../network/connection_manager.dart';
import 'auth_session.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._api, this._storage, {ConnectionManager? connections})
    : connections = connections ?? ConnectionManager(_storage) {
    _api.onUnauthorized = () {
      if (_session != null) logout();
    };
    // سوییچ خودکار شبکه: درخواستِ ناموفق → آدرس جایگزینِ همان سرور
    _api.onUnreachable = this.connections.failover;
    this.connections.onApply = (url, alts) async {
      await _api.setBaseUrl(url);
      await _safeWrite('api_base_urls', alts.join('\n'));
      onServerChanged?.call(url, alts);
    };
  }
  final ApiClient _api;
  final FlutterSecureStorage _storage;

  Future<void> _safeWrite(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // نبودِ HTTPS روی وب: ذخیرهٔ امن در دسترس نیست؛ اپ را متوقف نکن
    }
  }

  Future<void> _safeDelete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  /// چند سرور / چند آدرس جایگزین
  final ConnectionManager connections;

  /// برای هم‌گام‌سازی سرویس اعلان بومی با آدرس جدید
  void Function(String url, List<String> alternatives)? onServerChanged;

  /// قبل از برگرداندن نشستِ سرور دیگر (برای توقف سرویس اعلان سرور قبلی)
  void Function()? onProfileSwitched;

  /// شمارنده‌ای که با هر تعویض سرور (پروفایل) زیاد می‌شود تا صفحات از نو
  /// ساخته شوند و دادهٔ سرور قبلی نشان داده نشود.
  int serverGeneration = 0;

  static const _sessionKeys = [
    'auth_token',
    'auth_session',
    'company_id',
    'push_last_seen_id',
  ];
  AuthSession? _session;
  bool initializing = true;
  bool busy = false;
  String? error;

  AuthSession? get session => _session;
  bool get isLoggedIn => _session != null;

  Future<void> initialize() async {
    try {
      await _api.restoreBaseUrl();
    } catch (_) {}
    try {
      await connections.load(legacyBaseUrl: _api.baseUrl == _defaultBase ? null : _api.baseUrl);
      final url = connections.activeUrl;
      if (url != null && url != _api.baseUrl) await _api.setBaseUrl(url);
    } catch (_) {}
    try {
      final raw = await _storage.read(key: 'auth_session');
      if (raw != null) {
        final value = AuthSession.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (value.token.isNotEmpty) _session = value;
      }
    } catch (_) {
      await logout(notify: false);
    } finally {
      initializing = false;
      notifyListeners();
    }
    if (_session != null) {
      // همگام‌سازی غیرمسدودکنندهٔ نقش‌ها و مجوزهای به‌روز از `/api/auth/me` (مشابه AuthService وب)
      // تا تغییر دسترسی در پنل وب بدون نیاز به خروج/ورود مجدد در اندروید اعمال شود.
      refreshSession();
    }
  }

  /// به‌روزرسانی مجوزها، نقش‌ها و مشخصات نشست از `GET /api/auth/me`.
  Future<void> refreshSession() async {
    final current = _session;
    if (current == null || current.token.isEmpty) return;
    try {
      final r = await _api.get<dynamic>('/api/auth/me');
      final data = r.data;
      if (data is! Map) return;
      final map = Map<String, dynamic>.from(data);
      if (!map.containsKey('permissions') && !map.containsKey('Permissions')) {
        return;
      }
      final fresh = AuthSession.fromJson({
        ...current.toJson(),
        ...map,
        if ((map['token']?.toString() ?? '').isEmpty) 'token': current.token,
      });
      _session = fresh;
      await _safeWrite('auth_session', jsonEncode(fresh.toJson()));
      notifyListeners();
    } catch (_) {
      // در صورت آفلاین بودن شبکه، نشست ذخیره‌شده حفظ می‌شود.
    }
  }

  Future<bool> login(String username, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final r = await _api.post<Map<String, dynamic>>('/api/auth/login', {
        'username': username.trim(),
        'password': password,
      });
      final value = AuthSession.fromJson(r.data!);
      _session = value;
      await _safeWrite('auth_token', value.token);
      await _safeWrite('auth_session', jsonEncode(value.toJson()));
      try {
        await _api.ensureCompanyId();
      } catch (_) {}
      return true;
    } on ApiException catch (e) {
      error = e.statusCode == 401
          ? 'نام کاربری یا رمز عبور اشتباه است یا حساب غیرفعال است.'
          : e.message;
      return false;
    } catch (_) {
      error = 'ورود انجام نشد. دوباره تلاش کنید.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> changePassword(String current, String replacement) async {
    await _api.post('/api/auth/change-password', {
      'currentPassword': current,
      'newPassword': replacement,
    });
  }

  static const _defaultBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5100',
  );

  /// تعویض سرور/سازمان. نشست سرور فعلی کنار گذاشته می‌شود و اگر قبلاً در
  /// سرور مقصد وارد شده باشید، بدون ورود دوباره همان نشست برمی‌گردد.
  Future<void> switchProfile(String profileId) async {
    final old = connections.activeProfileId;
    if (old == profileId) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      if (old != null) await _stashSession(old);
      for (final k in _sessionKeys) {
        await _safeDelete(k);
      }
      _session = null;
      await _api.setCompanyId(null);
      await connections.activateProfile(profileId);
      await _restoreSession(profileId);
      await _api.restoreCompanyId();
      serverGeneration++;
      onProfileSwitched?.call();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _stashSession(String profileId) async {
    final data = <String, String>{};
    for (final k in _sessionKeys) {
      try {
        final v = await _storage.read(key: k);
        if (v != null) data[k] = v;
      } catch (_) {}
    }
    if (data['auth_token']?.isNotEmpty == true) {
      await _safeWrite('conn_session_$profileId', jsonEncode(data));
    } else {
      await _safeDelete('conn_session_$profileId');
    }
  }

  Future<void> _restoreSession(String profileId) async {
    String? raw;
    try {
      raw = await _storage.read(key: 'conn_session_$profileId');
    } catch (_) {
      return;
    }
    if (raw == null || raw.isEmpty) return;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      for (final e in data.entries) {
        await _safeWrite(e.key, e.value.toString());
      }
      final s = data['auth_session']?.toString();
      if (s != null) {
        final value = AuthSession.fromJson(
          jsonDecode(s) as Map<String, dynamic>,
        );
        if (value.token.isNotEmpty) _session = value;
      }
    } catch (_) {
      await _safeDelete('conn_session_$profileId');
    }
  }

  Future<void> logout({bool notify = true}) async {
    _session = null;
    final pid = connections.activeProfileId;
    if (pid != null) await _safeDelete('conn_session_$pid');
    await _safeDelete('auth_token');
    await _safeDelete('auth_session');
    await _api.setCompanyId(null);
    if (notify) notifyListeners();
  }
}
