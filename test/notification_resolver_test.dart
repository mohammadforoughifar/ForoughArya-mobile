// ============================================================
//  تست: کلیک روی اعلان باید «همان سند» را پیدا کند، نه صفحهٔ ماژول.
//  سه ماژول: دستور کار، صورت‌جلسه، نامه (اتوماسیون)
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/network/api_client.dart';
import 'package:forough_mobile/features/home/data/notification_target.dart';
import 'package:forough_mobile/features/home/models/home_models.dart';

class _Storage extends FlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => null;
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
  }) async {}
  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {}
}

/// سرور جعلیِ سه ماژول
class _Server implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final p = options.path;
    final q = options.uri.query;
    Object body = {};
    if (p.contains('/api/workorders/')) {
      body = {
        'items': [
          {'id': 91, 'number': 'WO-1404-77', 'title': 'تعمیر دستگاه برش'},
          {'id': 92, 'number': 'WO-1404-78', 'title': 'سرویس سرور'},
        ],
        'totalCount': 2,
      };
    } else if (p.endsWith('/api/meeting-minutes')) {
      body = {
        'items': [
          {'id': 55, 'title': 'صورت‌جلسهٔ جلسهٔ فنی'},
          {'id': 56, 'title': 'صورت‌جلسهٔ بازرگانی'},
        ],
        'total': 2,
      };
    } else if (p.contains('/api/letters/inbox')) {
      body = {
        'items': [
          {
            'letterId': 301,
            'letterNumber': '1404/2187',
            'title': 'بازبینی قرارداد توسعه',
            'erjaId': 88,
          },
          {
            'letterId': 302,
            'letterNumber': '1404/2190',
            'title': 'درخواست خرید',
            'erjaId': 89,
          },
        ],
        'totalCount': 2,
      };
    } else if (q.contains('search=')) {
      body = {'items': [], 'totalCount': 0};
    }
    return ResponseBody.fromString(
      jsonEncode(body),
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
  late NotificationResolver resolver;

  setUp(() {
    final api = ApiClient(_Storage());
    api.dio.httpClientAdapter = _Server();
    resolver = NotificationResolver(api);
  });

  test('اعلان دستور کار با شماره، همان دستور کار را پیدا می‌کند', () async {
    final n = NotificationItem.fromJson({
      'id': 1,
      'title': 'ارجاع دستور کار WO-1404-78 به شما',
      'formName': 'دستور کار',
    });
    final t = await resolver.resolve(n);
    expect(t.kind, 'wo');
    expect(t.id, 92);
  });

  test('اعلان صورت‌جلسه با عنوان، همان صورت‌جلسه را پیدا می‌کند', () async {
    final n = NotificationItem.fromJson({
      'id': 2,
      'title': 'صورت‌جلسهٔ بازرگانی برای امضا',
    });
    final t = await resolver.resolve(n);
    expect(t.kind, 'minutes');
    expect(t.id, 56);
  });

  test('اعلان ارجاع نامه، همان نامه و ارجاع را پیدا می‌کند', () async {
    final n = NotificationItem.fromJson({
      'id': 3,
      'title': 'ارجاع نامهٔ 1404/2187 به کارتابل شما',
      'formName': 'کارتابل نامهٔ داخلی',
    });
    final t = await resolver.resolve(n);
    expect(t.kind, 'letter');
    expect(t.id, 301);
    expect(t.erjaId, 88);
    expect(t.letterKind?.name, 'inner');
  });

  test('اگر شناسهٔ مستقیم در اعلان باشد، همان استفاده می‌شود', () async {
    final n = NotificationItem.fromJson({
      'id': 4,
      'title': 'دستور کار جدید',
      'workOrderId': 1234,
    });
    final t = await resolver.resolve(n);
    expect(t.id, 1234);
  });

  test('صورت‌جلسه با شناسهٔ مستقیم', () async {
    final n = NotificationItem.fromJson({
      'id': 5,
      'title': 'صورت‌جلسه',
      'minutesId': 777,
    });
    final t = await resolver.resolve(n);
    expect(t.kind, 'minutes');
    expect(t.id, 777);
  });
}
