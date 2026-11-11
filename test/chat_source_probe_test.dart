// ============================================================
//  تست: مسیری که ۲۰۰ می‌دهد ولی HTML است نباید «اتصال موفق» حساب شود
//  (باگ واقعی: /chat روی سرور پیام‌رسان ۲۰۰ داد، اپ گفت «اتصال برقرار شد»
//   ولی هیچ چتی بالا نیامد چون پاسخ صفحهٔ وب بود نه JSON)
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/network/api_client.dart';
import 'package:forough_mobile/features/messenger/data/chat_source_probe.dart';

class _Storage extends FlutterSecureStorage {
  final Map<String, String> m = {};
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
}

/// شبیه‌ساز سرور: هر آدرس یک پاسخ متفاوت
class _Router implements HttpClientAdapter {
  _Router(this.routes);
  final Map<String, (int, String)> routes; // url → (status, body)
  final List<String> hits = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri.toString();
    hits.add(url);
    final r = routes[url];
    if (r == null) return ResponseBody.fromString('nf', 404);
    final isJson = r.$2.trimLeft().startsWith('{') || r.$2.trimLeft().startsWith('[');
    return ResponseBody.fromString(
      r.$2,
      r.$1,
      headers: {
        Headers.contentTypeHeader: [
          isJson ? 'application/json' : 'text/html; charset=utf-8',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const server = 'https://94.183.59.57:4456';

  test('HTML با کد ۲۰۰ به‌عنوان دادهٔ چت پذیرفته نمی‌شود', () async {
    final api = ApiClient(_Storage());
    api.dio.httpClientAdapter = _Router({
      '$server/chat': (200, '<!DOCTYPE html><html><body><app-root></app-root></body></html>'),
    });
    final probe = await ChatSourceProbe(api).probeUrl('$server/chat');
    expect(probe.status, 200);
    expect(probe.kind, SourceKind.html);
    expect(probe.usable, isFalse);
    expect(probe.label.contains('HTML'), isTrue);
  });

  test('مسیر JSON واقعی به‌عنوان چت شناسایی می‌شود', () async {
    final api = ApiClient(_Storage());
    api.dio.httpClientAdapter = _Router({
      '$server/chat/api/chat/threads': (
        200,
        jsonEncode([
          {'id': 1, 'title': 'علی رضایی', 'lastMessage': 'سلام', 'unreadCount': 2},
        ]),
      ),
    });
    final probe = await ChatSourceProbe(api).probeUrl('$server/chat/api/chat/threads');
    expect(probe.kind, SourceKind.threads);
    expect(probe.count, 1);
    expect(probe.usable, isTrue);
  });

  test('فهرست کاربران هم قابل استفاده است', () async {
    final api = ApiClient(_Storage());
    api.dio.httpClientAdapter = _Router({
      '$server/api/users': (
        200,
        jsonEncode({'items': [{'id': 7, 'fullName': 'مریم احمدی', 'userName': 'maryam'}]}),
      ),
    });
    final probe = await ChatSourceProbe(api).probeUrl('$server/api/users');
    expect(probe.kind, SourceKind.users);
    expect(probe.usable, isTrue);
  });

  test('هر مسیر پیشنهادی روی همان سرور پیام‌رسان ساخته می‌شود', () {
    final list = ChatSourceProbe.candidates(server);
    expect(list, isNotEmpty);
    expect(list.every((u) => u.startsWith(server)), isTrue);
    expect(list.any((u) => u.endsWith('/chat')), isTrue);
    expect(list.any((u) => u.contains('swagger')), isTrue);
  });
}
