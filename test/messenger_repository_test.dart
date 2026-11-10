// ============================================================
//  تست پیام‌رسان روی زیرساخت واقعی: گفت‌وگوها از inbox ایمیل ساخته
//  می‌شوند (هر فرستنده یک گفت‌وگو) و نام نمایشی درست استخراج می‌شود.
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart' as ft;
import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/network/api_client.dart';
import 'package:forough_mobile/features/messenger/data/chat_repository.dart';

class _Storage extends FlutterSecureStorage {
  final Map<String, String> _m = {};
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _m[key];
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
    if (value != null) _m[key] = value;
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
  }) async => _m.remove(key);
}

/// حافظهٔ جعلی: بدون کشف خودکار (تست روی fallback ایمیل تمرکز دارد)
class _FixedStorage extends FlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => key == 'chat_api_base' ? '/__none__' : null;

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

class _Adapter implements HttpClientAdapter {
  final List<String> paths = [];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    Object body;
    if (options.path.contains('api/email/inbox')) {
      body = {
        'totalCount': 3,
        'items': [
          {
            'id': 11,
            'box': 'Inbox',
            'fromOrTo': 'علی رضایی <ali@forough.ir>',
            'subject': 'سلام، گزارش را فرستادم',
            'date': '2026-11-09T09:00:00',
            'isRead': false,
          },
          {
            'id': 12,
            'box': 'Inbox',
            'fromOrTo': 'علی رضایی <ali@forough.ir>',
            'subject': 'پیام دوم',
            'date': '2026-11-09T10:00:00',
            'isRead': false,
          },
          {
            'id': 13,
            'box': 'Inbox',
            'fromOrTo': 'مریم کاظمی <maryam@forough.ir>',
            'subject': 'جلسه فردا',
            'date': '2026-11-08T08:00:00',
            'isRead': true,
          },
        ],
      };
    } else if (options.path.contains('api/email/sent')) {
      body = {'totalCount': 0, 'items': []};
    } else {
      body = {};
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
  ft.TestWidgetsFlutterBinding.ensureInitialized();

  test('هر فرستندهٔ ایمیل یک گفت‌وگو می‌شود و آخرین پیام انتخاب می‌شود', () async {
    final api = ApiClient(_Storage());
    api.dio.httpClientAdapter = _Adapter();
    final repo = ChatRepository(api, storage: _FixedStorage());

    final threads = await repo.threads();
    expect(threads.length, 2);

    final ali = threads.firstWhere((t) => t.title == 'علی رضایی');
    expect(ali.lastMessage, 'پیام دوم');
    expect(ali.unread, 2);

    final maryam = threads.firstWhere((t) => t.title == 'مریم کاظمی');
    expect(maryam.unread, 0);

    // جدیدترین گفت‌وگو اول فهرست است
    expect(threads.first.title, 'علی رضایی');
  });

  test('پیام‌های یک گفت‌وگو فقط برای همان شخص فیلتر می‌شوند', () async {
    final api = ApiClient(_Storage());
    api.dio.httpClientAdapter = _Adapter();
    final repo = ChatRepository(api, storage: _FixedStorage());

    final msgs = await repo.messages(11, peerName: 'علی رضایی');
    expect(msgs.length, 2);
    expect(msgs.every((m) => !m.mine), true);
    expect(msgs.first.text, 'سلام، گزارش را فرستادم');
  });

  test('وقتی مسیر چت کشف نشود، fallback روی ایمیل سازمانی است', () async {
    final adapters = _Adapter();
    final api = ApiClient(_Storage());
    api.dio.httpClientAdapter = adapters;
    final repo = ChatRepository(api, storage: _FixedStorage());
    await repo.threads();
    expect(repo.lastSource, 'email');
    expect(adapters.paths.any((p) => p.contains('api/email/inbox')), true);
  });

  test('مسیر دستی چت اولویت دارد و آخرین منبع chat می‌شود', () async {
    final adapters = _RoutingAdapter();
    final api = ApiClient(_Storage());
    api.dio.httpClientAdapter = adapters;
    final repo = ChatRepository(api, storage: _FixedStorage());
    await repo.setChatBase('/api/chatmessage');
    final threads = await repo.threads();
    expect(repo.lastSource, 'chat');
    expect(threads.length, 2);
    expect(threads.first.title, 'گفت‌وگوی تست');
  });
}

/// آداپتوری که فقط مسیر چت را جواب می‌دهد (شبیه پیام‌رسان وب)
class _RoutingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object body = {};
    if (options.path.contains('/api/chatmessage/threads')) {
      body = {
        'items': [
          {
            'id': 1,
            'title': 'گفت‌وگوی تست',
            'unreadCount': 2,
            'lastMessage': 'سلام',
          },
          {'id': 2, 'title': 'گفت‌وگوی دوم', 'unreadCount': 0},
        ],
      };
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
