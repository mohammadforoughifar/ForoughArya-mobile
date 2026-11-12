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
      await _storage.write(key: 'api_base_urls', value: alts.join('\n'));
      onServerChanged?.call(url, alts);
    };
  }
  final ApiClient _api;
  final FlutterSecureStorage _storage;

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
    await _api.restoreBaseUrl();
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
      await _storage.write(key: 'auth_token', value: value.token);
      await _storage.write(
        key: 'auth_session',
        value: jsonEncode(value.toJson()),
      );
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
        await _storage.delete(key: k);
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
      final v = await _storage.read(key: k);
      if (v != null) data[k] = v;
    }
    if (data['auth_token']?.isNotEmpty == true) {
      await _storage.write(
        key: 'conn_session_$profileId',
        value: jsonEncode(data),
      );
    } else {
      await _storage.delete(key: 'conn_session_$profileId');
    }
  }

  Future<void> _restoreSession(String profileId) async {
    final raw = await _storage.read(key: 'conn_session_$profileId');
    if (raw == null || raw.isEmpty) return;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      for (final e in data.entries) {
        await _storage.write(key: e.key, value: e.value.toString());
      }
      final s = data['auth_session']?.toString();
      if (s != null) {
        final value = AuthSession.fromJson(
          jsonDecode(s) as Map<String, dynamic>,
        );
        if (value.token.isNotEmpty) _session = value;
      }
    } catch (_) {
      await _storage.delete(key: 'conn_session_$profileId');
    }
  }

  Future<void> logout({bool notify = true}) async {
    _session = null;
    final pid = connections.activeProfileId;
    if (pid != null) await _storage.delete(key: 'conn_session_$pid');
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'auth_session');
    await _api.setCompanyId(null);
    if (notify) notifyListeners();
  }
}
