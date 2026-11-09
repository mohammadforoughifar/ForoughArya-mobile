import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/api_client.dart';
import 'auth_session.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._api, this._storage) {
    _api.onUnauthorized = () {
      if (_session != null) logout();
    };
  }
  final ApiClient _api;
  final FlutterSecureStorage _storage;
  AuthSession? _session;
  bool initializing = true;
  bool busy = false;
  String? error;

  AuthSession? get session => _session;
  bool get isLoggedIn => _session != null;

  Future<void> initialize() async {
    await _api.restoreBaseUrl();
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

  Future<void> logout({bool notify = true}) async {
    _session = null;
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'auth_session');
    await _api.setCompanyId(null);
    if (notify) notifyListeners();
  }
}
