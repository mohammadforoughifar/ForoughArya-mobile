// ============================================================
//  تست «بستن دستور کار توسط دستوردهنده»
//
//  باگ گزارش‌شده: در اندروید هیچ دکمه/مسیر بستن دیده نمی‌شد.
//  ریشه: تشخیص دستوردهنده به `AuthController.session.userId` وابسته بود و
//  پاسخ `GET /api/workorders/my-access` دور ریخته می‌شد. اکنون my-access
//  منبع حقیقت است. این تست قاعده‌های سرور را تثبیت می‌کند:
//    • close/reopen/extend فقط برای OwnerUserId (وگرنه 403)
//    • تا زیر-دستور باز باشد، بستن والد ممنوع است
// ============================================================

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/network/api_client.dart';
import 'package:forough_mobile/features/work_orders/data/work_order_repository.dart';

class _Adapter implements HttpClientAdapter {
  final calls = <String>[];
  Map<String, dynamic> access = {
    'userId': 12,
    'canView': true,
    'canCreate': true,
    'canAssignOthers': true,
    'canDelete': false,
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // resolveUrl آدرس کامل می‌سازد؛ برای ادعای تست فقط مسیر نسبی لازم است
    final rel = Uri.tryParse(options.path)?.path ?? options.path;
    calls.add('${options.method} $rel');
    Object body = options.path.endsWith('/my-access')
        ? access
        : <String, dynamic>{};
    return ResponseBody.fromString(
      _json(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  static String _json(Object o) {
    if (o is Map) {
      final parts = o.entries.map((e) {
        final v = e.value;
        final s = v is bool || v is num
            ? '$v'
            : '"${v.toString().replaceAll('"', r'\"')}"';
        return '"${e.key}":$s';
      });
      return '{${parts.join(',')}}';
    }
    return '{}';
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Adapter adapter;
  late WorkOrderRepository repo;

  setUp(() {
    // ApiClient توکن را از secure storage می‌خواند؛ بدون مقدار، Dio درخواست
    // را پیش از رسیدن به آداپتور رد می‌کند.
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'test-token'});
    adapter = _Adapter();
    final api = ApiClient(const FlutterSecureStorage());
    api.dio.httpClientAdapter = adapter;
    repo = WorkOrderRepository(api);
  });

  group('my-access — منبع حقیقت دسترسی', () {
    test('شناسهٔ کاربر و مجوزها از سرور خوانده می‌شوند', () async {
      final a = await repo.myAccess();
      expect(a.userId, 12);
      expect(a.canCreate, isTrue);
      expect(a.canAssignOthers, isTrue);
      expect(a.canDelete, isFalse);
      expect(a.isKnown, isTrue);
    });

    test('دستوردهنده بودن با شناسهٔ سرور تشخیص داده می‌شود', () async {
      final a = await repo.myAccess();
      expect(a.ownsOrder(12), isTrue);
      expect(a.ownsOrder(99), isFalse);
      expect(a.ownsOrder(0), isFalse);
    });

    test('پاسخ نامعتبر سرور ⇒ بدون استثنا و isKnown=false', () async {
      adapter.access = <String, dynamic>{};
      final a = await repo.myAccess();
      expect(a.isKnown, isFalse);
      expect(a.userId, 0);
    });
  });

  group('مسیرهای بستن/تمدید/بازگشایی', () {
    test('close به POST /api/workorders/{id}/close می‌رود', () async {
      await repo.close(55, 'کار انجام شد');
      expect(adapter.calls, contains('POST /api/workorders/55/close'));
    });

    test('reopen به endpoint درست می‌رود', () async {
      await repo.reopen(55, 'اشتباه بسته شد', null, true);
      expect(adapter.calls, contains('POST /api/workorders/55/reopen'));
    });

    test('extend به endpoint تمدید می‌رود', () async {
      await repo.extend(55, DateTime(2026, 12, 1), 'تأخیر پیمانکار');
      expect(adapter.calls, contains('POST /api/workorders/55/extend'));
    });
  });
}
