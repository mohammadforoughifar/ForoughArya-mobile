// ============================================================
//  تست: مسیرهای نسبی حتماً روی Base URL تنظیم‌شده می‌روند
//  (باگ «ارتباط با سرور برقرار نشد» در پیام‌رسان از اسلش ابتدای
//  مسیر بود که دامنهٔ ثبت‌شده در تنظیمات را دور می‌زد)
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/network/api_client.dart';

class _Storage extends FlutterSecureStorage {
  final Map<String, String> m = {};
  _Storage({Map<String, String>? init}) {
    if (init != null) m.addAll(init);
  }
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => m[key];
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) m[key] = value;
  }
  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => m.remove(key);
}

class _Recorder implements HttpClientAdapter {
  final List<String> urls = [];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    urls.add(options.uri.toString());
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('مسیر با اسلش ابتدایی هم روی Base URL ثبت‌شده می‌رود', () async {
    final api = ApiClient(_Storage());
    final rec = _Recorder();
    api.dio.httpClientAdapter = rec;
    await api.setBaseUrl('https://office.forough.ir');

    await api.get<dynamic>('/api/chatmessage/threads');
    await api.get<dynamic>('api/chatmessage/threads');
    await api.get<dynamic>('api/email/inbox');

    expect(rec.urls.length, 3);
    for (final u in rec.urls) {
      expect(u.startsWith('https://office.forough.ir/'), true, reason: u);
    }
    expect(rec.urls.first, 'https://office.forough.ir/api/chatmessage/threads');
  });

  test('آدرس کامل http دست‌نخورده می‌ماند', () async {
    final api = ApiClient(_Storage());
    final rec = _Recorder();
    api.dio.httpClientAdapter = rec;
    await api.setBaseUrl('https://office.forough.ir');
    await api.get<dynamic>('https://cdn.example.com/x');
    expect(rec.urls.single, 'https://cdn.example.com/x');
  });

  test('Base URL ذخیره‌شده در شروع بازیابی می‌شود', () async {
    final storage = _Storage(init: {'api_base_url': 'https://app.forough.ir'});
    final api = ApiClient(storage);
    final rec = _Recorder();
    api.dio.httpClientAdapter = rec;
    await api.restoreBaseUrl();
    await api.get<dynamic>('api/chatmessage/threads');
    expect(rec.urls.single.startsWith('https://app.forough.ir/'), true);
  });
}
