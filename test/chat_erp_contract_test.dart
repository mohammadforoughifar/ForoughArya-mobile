// ============================================================
//  تست قرارداد واقعی چت سازمانی
//  منبع: TotallCollectionSoftware → ChatController.cs (Route api/chat)
//  هر مسیر باید دقیقاً همان چیزی باشد که سرور سرو می‌کند.
// ============================================================

import 'dart:convert';
import 'dart:io' as java_io;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/network/api_client.dart';
import 'package:forough_mobile/features/messenger/data/chat_erp_api.dart';

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

class _Rec implements HttpClientAdapter {
  final List<String> calls = [];
  final List<Object?> bodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final uri = options.uri;
    final host = uri.host.isEmpty ? '' : 'https://${uri.host}';
    calls.add(
      '${options.method} $host${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}'
          .replaceFirst('https://office.forough.ir', ''),
    );
    bodies.add(options.data);

    Object body = {};
    final p = options.uri.path;
    if (p.endsWith('/api/chat/conversations')) {
      body = {
        'total': 1,
        'items': [
          {
            'id': 9,
            'title': 'گروه پشتیبانی',
            'type': 2,
            'unreadCount': 4,
            'lastMessageSnippet': 'سلام',
            'lastMessageAt': '2026-11-10T09:30:00Z',
            'isPinned': false,
            'isMuted': true,
          },
        ],
      };
    } else if (p.endsWith('/conversations/9/messages')) {
      body = [
        {
          'id': 30,
          'conversationId': 9,
          'senderUserId': 4,
          'senderName': 'مریم احمدی',
          'text': 'سلام، فایل را فرستادم',
          'messageType': 1,
          'createdAt': '2026-11-10T09:00:00Z',
        },
        {
          'id': 31,
          'conversationId': 9,
          'senderUserId': 5,
          'senderName': 'من',
          'text': 'ممنون',
          'messageType': 1,
          'isOutgoing': true,
          'createdAt': '2026-11-10T09:01:00Z',
        },
      ];
    } else if (p.endsWith('/api/chat/users')) {
      body = [
        {
          'id': 4,
          'username': 'maryam',
          'displayName': 'مریم احمدی',
          'department': 'فنی',
          'isOnline': true,
        },
      ];
    } else if (p.endsWith('/api/chat/summary')) {
      body = {'totalUnreadMessages': 7, 'unreadConversationsCount': 2};
    } else if (p.endsWith('/conversations/direct')) {
      body = {
        'id': 11,
        'title': '',
        'type': 1,
        'directPeerUserId': 4,
        'directPeerName': 'مریم احمدی',
      };
    } else if (p.endsWith('/api/chat/conversations/9/attachments')) {
      body = {
        'id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        'fileUrl': '/api/chat/attachments/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/download',
        'fileName': 'voice.m4a',
        'fileSizeBytes': 1234,
        'fileContentType': 'audio/mp4',
        'messageType': 4,
      };
    } else if (p.contains('/messages') && options.method == 'POST') {
      body = {
        'id': 40,
        'conversationId': 9,
        'senderUserId': 5,
        'text': 'تست',
        'messageType': 1,
        'createdAt': '2026-11-10T10:00:00Z',
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

void main() {
  late ApiClient api;
  late _Rec rec;
  late ChatErpApi chat;

  setUp(() async {
    api = ApiClient(_Storage());
    await api.setBaseUrl('https://office.forough.ir');
    rec = _Rec();
    api.dio.httpClientAdapter = rec;
    chat = ChatErpApi(api);
  });

  test('مسیر گفت‌وگوها همان api/chat/conversations است', () async {
    final list = await chat.conversations();
    expect(rec.calls.first, startsWith('GET /api/chat/conversations'));
    // take/skip برای صفحه‌بندی سرور فرستاده می‌شود
    expect(rec.calls.first, contains('take=60'));
    expect(list.single.title, 'گروه پشتیبانی');
    expect(list.single.unread, 4);
    expect(list.single.isGroup, isTrue);
    expect(list.single.muted, isTrue);
  });

  test('پیام‌ها از conversations/{id}/messages خوانده و قدیم→جدید مرتب می‌شوند', () async {
    final msgs = await chat.messages(9, myUserId: 5);
    expect(rec.calls.single, startsWith('GET /api/chat/conversations/9/messages'));
    expect(msgs.length, 2);
    expect(msgs.first.id, 30);
    expect(msgs.first.mine, isFalse);
    expect(msgs.last.mine, isTrue, reason: 'isOutgoing=true یعنی پیام من');
  });

  test('ارسال پیام به conversations/{id}/messages با messageType عددی', () async {
    await chat.sendMessage(9, text: 'تست');
    final call = rec.calls.single;
    expect(call, startsWith('POST /api/chat/conversations/9/messages'));
    final body = rec.bodies.single as Map;
    expect(body['text'], 'تست');
    expect(body['messageType'], ChatMessageType.text);
    expect(body['conversationId'], 9);
  });

  test('شروع چت خصوصی → POST conversations/direct با targetUserId', () async {
    final conv = await chat.createDirect(4);
    expect(rec.calls.single, startsWith('POST /api/chat/conversations/direct'));
    expect((rec.bodies.single as Map)['targetUserId'], 4);
    expect(conv?.title, 'مریم احمدی');
    expect(conv?.peerUserId, 4);
  });

  test('کاربران از api/chat/users و خلاصه از api/chat/summary', () async {
    final users = await chat.users();
    expect(rec.calls.first, startsWith('GET /api/chat/users'));
    expect(users.single.name, 'مریم احمدی');
    expect(users.single.isOnline, isTrue);

    final s = await chat.summary();
    expect(rec.calls.last, endsWith('/api/chat/summary'));
    expect(s.totalUnreadMessages, 7);
    expect(s.unreadConversationsCount, 2);
  });

  test('آپلود پیوست مسیر attachments دارد و fileUrl نسبی می‌ماند', () async {
    final f = await _tempFile('voice.m4a', const [1, 2, 3]);
    final up = await chat.uploadAttachment(9, f);
    expect(
      rec.calls.single,
      startsWith('POST /api/chat/conversations/9/attachments'),
    );
    expect(up.fileUrl, startsWith('/api/chat/attachments/'));
    expect(up.messageType, ChatMessageType.audio);
    // آدرس کامل برای پخش روی همان سرور ساخته می‌شود
    expect(
      chat.fileUrl(up.fileUrl),
      'https://office.forough.ir/api/chat/attachments/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/download',
    );
  });

  test('علامت خوانده‌شدن و پین/بی‌صدا مسیرهای درست دارند', () async {
    await chat.markRead(9, lastReadMessageId: 31);
    await chat.togglePinConversation(9);
    await chat.toggleMuteConversation(9);
    expect(rec.calls[0], startsWith('POST /api/chat/conversations/9/read'));
    expect((rec.bodies[0] as Map)['lastReadMessageId'], 31);
    expect(rec.calls[1], startsWith('POST /api/chat/conversations/9/pin'));
    expect(rec.calls[2], startsWith('POST /api/chat/conversations/9/mute'));
  });

  test('base کامل (سرور جدا) هم پشتیبانی می‌شود', () async {
    chat.base = 'https://94.183.59.57:4456/api/chat';
    await chat.conversations();
    expect(rec.calls.single, contains('/api/chat/conversations'));
    expect(rec.calls.single, contains('94.183.59.57'));
  });
}

Future<java_io.File> _tempFile(String name, List<int> bytes) async {
  final dir = await java_io.Directory.systemTemp.createTemp('chattest');
  final f = java_io.File('${dir.path}/$name');
  await f.writeAsBytes(bytes);
  return f;
}
