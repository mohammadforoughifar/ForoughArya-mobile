// ============================================================
//  ریپازیتوری پیام‌رسان
//
//  ⚠️ چرا بازنویسی شد: مسیرهای «/api/chat/...» در بک‌اند این پروژه
//  وجود ندارند؛ به همین دلیل پیام‌رسان هیچ داده‌ای نمی‌گرفت و ارسال
//  هم شکست می‌خورد. حالا پیام‌رسان روی همان زیرساختِ سالم و تست‌شدهٔ
//  خودِ اپ سوار است:
//
//    گفت‌وگوها  →  api/email/inbox  (هر فرستنده = یک گفت‌وگو)
//    تاریخچه   →  inbox + sent  (همان رشتهٔ مکالمه)
//    ارسال متن  →  api/email/send
//    ارسال ویس  →  api/email/send با پیوست صوتی m4a
//    همکاران    →  فرستندگان inbox (+ اعضای صورت‌جلسه)
//
//  اگر بعداً سرور کنترلر اختصاصی چت گرفت، فقط [useChatApi] را true کنید.
// ============================================================

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../office_automation/data/email_repository.dart';
import '../../office_automation/models/email_models.dart';
import '../models/chat_models.dart';

class ChatRepository {
  ChatRepository(this._api) : _email = EmailRepository(_api);

  final ApiClient _api;
  final EmailRepository _email;

  /// وقتی کنترلر `/api/chat` روی سرور اضافه شد → true
  static const bool useChatApi = false;

  /// حساب ایمیل سازمانی فعال (برای ارسال لازم است)
  Future<int> _accountId({bool personal = false}) async {
    final accounts = personal
        ? (await _email.accounts()).where((a) => !a.isDabirkhane).toList()
        : await _email.accounts();
    final active = accounts.where((a) => a.isActive).toList();
    final list = active.isNotEmpty ? active : accounts;
    if (list.isEmpty) {
      throw Exception(
        'حساب ایمیل سازمانی تنظیم نشده است. در ماژول ایمیل، حساب را اضافه کنید.',
      );
    }
    return list.first.id;
  }

  // ------------------------------------------------------------
  //  فهرست گفت‌وگوها — از صندوق دریافتی ایمیل
  // ------------------------------------------------------------
  Future<List<ChatThread>> threads() async {
    if (useChatApi) {
      final r = await _api.get<dynamic>('/api/chat/threads');
      if (r.data is List) {
        return (r.data as List)
            .whereType<Map>()
            .map((e) => ChatThread.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    }

    final result = await _email.inbox(pageSize: 60);
    final bySender = <String, ChatThread>{};
    for (final m in result.items) {
      final name = _peerName(m);
      if (name.isEmpty) continue;
      final prev = bySender[name];
      final at = m.date;
      if (prev == null) {
        bySender[name] = ChatThread(
          id: m.id,
          title: name,
          lastMessage: _snippet(m),
          lastAt: at,
          unread: m.isRead ? 0 : 1,
        );
      } else {
        final newer = at != null && (prev.lastAt == null || at.isAfter(prev.lastAt!));
        bySender[name] = ChatThread(
          id: newer ? m.id : prev.id,
          title: name,
          lastMessage: newer ? _snippet(m) : prev.lastMessage,
          lastAt: newer ? at : prev.lastAt,
          unread: prev.unread + (m.isRead ? 0 : 1),
        );
      }
    }
    final list = bySender.values.toList()
      ..sort((a, b) {
        final x = a.lastAt, y = b.lastAt;
        if (x == null && y == null) return 0;
        if (x == null) return 1;
        if (y == null) return -1;
        return y.compareTo(x);
      });
    return list;
  }

  /// پیام‌های یک گفت‌وگو (دریافتی + ارسالی همان شخص)
  Future<List<ChatMessage>> messages(
    int threadId, {
    int? myUserId,
    int take = 100,
    String? peerName,
  }) async {
    if (useChatApi) {
      final r = await _api.get<dynamic>(
        '/api/chat/$threadId/messages',
        query: {'take': take},
      );
      if (r.data is List) {
        return (r.data as List)
            .whereType<Map>()
            .map(
              (e) => ChatMessage.fromJson(
                Map<String, dynamic>.from(e),
                myUserId: myUserId,
              ),
            )
            .toList();
      }
    }

    final out = <ChatMessage>[];
    try {
      final inbox = await _email.inbox(pageSize: 60);
      for (final m in inbox.items) {
        if (peerName != null && peerName.isNotEmpty && _peerName(m) != peerName) {
          continue;
        }
        out.add(
          ChatMessage(
            id: m.id,
            kind: ChatKind.text,
            text: m.subject,
            mine: false,
            at: m.date,
            senderName: _peerName(m),
            attachmentName: m.hasAttachment ? 'پیوست' : null,
          ),
        );
      }
    } catch (_) {}

    try {
      final sent = await _email.sent(pageSize: 40);
      for (final m in sent.items) {
        if (peerName != null &&
            peerName.isNotEmpty &&
            !m.fromOrTo.contains(peerName)) {
          continue;
        }
        out.add(
          ChatMessage(
            id: -m.id,
            kind: ChatKind.text,
            text: m.subject,
            mine: true,
            at: m.date,
          ),
        );
      }
    } catch (_) {}

    out.sort((a, b) {
      final x = a.at, y = b.at;
      if (x == null && y == null) return 0;
      if (x == null) return -1;
      if (y == null) return 1;
      return x.compareTo(y);
    });
    return out;
  }

  // ------------------------------------------------------------
  //  ارسال
  // ------------------------------------------------------------
  Future<void> sendText(int threadId, String text, {String? to}) async {
    if (useChatApi) {
      await _api.post<dynamic>('/api/chat/$threadId/messages', {
        'text': text,
        'kind': 'text',
      });
      return;
    }
    final target = (to ?? '').trim();
    if (target.isEmpty) {
      throw Exception('گیرندهٔ گفت‌وگو مشخص نیست.');
    }
    final accountId = await _accountId();
    await _email.send(
      emailAccountId: accountId,
      to: target,
      subject: text.length > 60 ? '${text.substring(0, 60)}…' : text,
      body: text,
    );
  }

  Future<String?> sendVoice(
    int threadId,
    File file, {
    required int durationSec,
    String? to,
  }) async {
    if (useChatApi) {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.uri.pathSegments.last,
        ),
        'duration': durationSec,
      });
      try {
        await _api.postForm<dynamic>('/api/chat/voice', form);
      } catch (_) {}
      await _api.postForm<dynamic>(
        '/api/chat/$threadId/messages',
        FormData.fromMap({
          'kind': 'voice',
          'duration': durationSec,
          'file': await MultipartFile.fromFile(
            file.path,
            filename: file.uri.pathSegments.last,
          ),
        }),
      );
      return null;
    }

    final target = (to ?? '').trim();
    if (target.isEmpty) {
      throw Exception('گیرندهٔ گفت‌وگو مشخص نیست.');
    }
    final accountId = await _accountId();
    final bytes = await file.readAsBytes();
    if (bytes.length < 512) {
      throw Exception('فایل صوتی خالی است. دوباره ضبط کنید.');
    }
    await _email.send(
      emailAccountId: accountId,
      to: target,
      subject: 'پیام صوتی ${durationSec} ثانیه',
      body: 'پیام صوتی — مدت ${durationSec} ثانیه (پیوست m4a)',
      attachments: [
        (
          name: file.uri.pathSegments.last,
          bytes: Uint8List.fromList(bytes),
          mimeType: 'audio/mp4',
        ),
      ],
    );
    return file.path;
  }

  // ------------------------------------------------------------
  //  همکاران
  // ------------------------------------------------------------
  Future<List<ChatThread>> contacts() async {
    if (useChatApi) {
      final r = await _api.get<dynamic>('/api/chat/users', query: {'take': 200});
      if (r.data is List) {
        return (r.data as List).whereType<Map>().map((e) {
          final m = Map<String, dynamic>.from(e);
          final id = (m['id'] ?? m['userId'] ?? m['Id']) as num?;
          final name =
              (m['fullName'] ?? m['name'] ?? m['displayName'] ?? m['username'] ?? '')
                  .toString();
          return ChatThread(
            id: id?.toInt() ?? 0,
            title: name.isEmpty ? 'کاربر' : name,
            userId: id?.toInt(),
          );
        }).toList();
      }
    }

    final names = <String>{};
    try {
      final inbox = await _email.inbox(pageSize: 100);
      for (final m in inbox.items) {
        final n = _peerName(m);
        if (n.isNotEmpty) names.add(n);
      }
    } catch (_) {}
    // آدرس‌ها هم به‌عنوان گزینه (برای ارسال به ایمیل واقعی)
    try {
      final sent = await _email.sent(pageSize: 60);
      for (final m in sent.items) {
        final a = m.fromOrTo.trim();
        if (a.isNotEmpty) names.add(a);
      }
    } catch (_) {}
    final list = names
        .map((n) => ChatThread(id: n.hashCode.abs() % 100000, title: n))
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    return list;
  }

  Future<int> startThread(int userId) async => userId;

  // ------------------------------------------------------------
  //  کمکی‌ها
  // ------------------------------------------------------------
  String _peerName(EmailMessage m) {
    final from = m.fromOrTo.trim();
    if (from.isEmpty) return '';
    // اگر به شکل «نام <mail@x>» بود، نام نمایشی را برمی‌داریم
    final angle = RegExp(r'^(.*)<(.+)>$').firstMatch(from);
    if (angle != null) {
      final name = angle.group(1)!.trim().replaceAll('"', '');
      return name.isNotEmpty ? name : angle.group(2)!.trim();
    }
    return from;
  }

  String _snippet(EmailMessage m) {
    final body = m.subject.replaceAll(RegExp(r'\s+'), ' ').trim();
    return body.length > 90 ? '${body.substring(0, 90)}…' : body;
  }
}
