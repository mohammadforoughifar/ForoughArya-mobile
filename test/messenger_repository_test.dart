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
      return ResponseBody.fromString(
        jsonEncode({'message': 'مجوز پیام‌رسان را ندارید.'}),
        403,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
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

  test('خطای سرور چت شفاف به کاربر می‌رسد و منبع none می‌ماند', () async {
    final api = ApiClient(_Storage());
    api.dio.httpClientAdapter = _Adapter();
    final repo = ChatRepository(api, storage: _FixedStorage());

    await expectLater(repo.threads(), throwsA(isA<Exception>()));
    expect(repo.lastSource, 'none');
  });

  test('تاریخچه هم فقط از چت می‌آید نه ایمیل', () async {
    final api = ApiClient(_Storage());
    api.dio.httpClientAdapter = _Adapter();
    final repo = ChatRepository(api, storage: _FixedStorage());
    await expectLater(
      repo.messages(11, peerName: 'علی رضایی'),
      throwsA(isA<Exception>()),
    );
  });

  test('هیچ درخواستی به api/email زده نمی‌شود', () async {
    final adapters = _Adapter();
    final api = ApiClient(_Storage());
    api.dio.httpClientAdapter = adapters;
    final repo = ChatRepository(api, storage: _FixedStorage());
    try {
      await repo.threads();
    } catch (_) {}
    expect(adapters.paths.any((p) => p.contains('api/email')), false);
  });

  test('قرارداد واقعی سرور (api/chat/conversations) خوانده می‌شود', () async {
    final adapters = _ErpAdapter();
    final api = ApiClient(_Storage());
    api.dio.httpClientAdapter = adapters;
    final repo = ChatRepository(api, storage: _FixedStorage());
    final threads = await repo.threads();
    expect(repo.lastSource, 'erp');
    expect(threads.length, 2);
    // نام نمایشی در چت خصوصی از directPeerName گرفته می‌شود
    expect(threads.first.title, 'علی رضایی');
    expect(threads.first.unread, 3);
  });
}

/// آداپتور قرارداد واقعی سرور (ChatController.cs)
class _ErpAdapter implements HttpClientAdapter {
  final List<String> paths = [];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    Object body = {};
    if (options.path.endsWith('/api/chat/conversations')) {
      body = [
        {
          'id': 5,
          'title': 'گفت‌وگوی خصوصی',
          'type': 1,
          'unreadCount': 3,
          'directPeerUserId': 7,
          'directPeerName': 'علی رضایی',
          'lastMessageSnippet': 'سلام',
          'lastMessageAt': '2026-11-10T08:00:00Z',
          'isPinned': true,
        },
        {
          'id': 6,
          'title': 'گروه فنی',
          'type': 2,
          'unreadCount': 0,
          'lastMessageSnippet': 'جلسه فردا',
          'lastMessageAt': '2026-11-09T08:00:00Z',
        },
      ];
    } else if (options.path.contains('/messages')) {
      body = {
        'total': 1,
        'items': [
          {
            'id': 21,
            'conversationId': 5,
            'senderUserId': 7,
            'senderName': 'علی رضایی',
            'text': 'سلام',
            'messageType': 1,
            'createdAt': '2026-11-10T08:00:00Z',
          },
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
