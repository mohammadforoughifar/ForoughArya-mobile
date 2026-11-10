// ============================================================
//  ریپازیتوری پیام‌رسان — سه‌لایه با fallback
//
//    ۱) چت واقعی سرور (همان پیام‌رسان وب): مسیر با «کشف خودکار» پیدا
//       می‌شود یا کاربر در تنظیمات پیام‌رسان وارد می‌کند.
//    ۲) اگر کشف نشد → همان مسیرهای حدسی قبلی (/api/chat/...)
//    ۳) اگر هیچ‌کدام → ایمیل سازمانی (تضمین‌شده چون در اپ کار می‌کند)
//
//  نتیجه: پیام‌رسان هرگز «بی‌داده» نمی‌ماند و پیام خطا هم دقیق است.
// ============================================================

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../../office_automation/data/email_repository.dart';
import '../../office_automation/models/email_models.dart';
import '../models/chat_models.dart';
import 'chat_endpoints.dart';
import 'chat_rest_api.dart';

class ChatRepository {
  ChatRepository(this._api, {FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(),
      _email = EmailRepository(_api) {
    _endpoints = ChatEndpoints(_api, _storage);
    _rest = ChatRestApi(_api, _endpoints);
  }

  final ApiClient _api;
  final FlutterSecureStorage _storage;
  final EmailRepository _email;
  late final ChatEndpoints _endpoints;
  late final ChatRestApi _rest;

  String? _resolvedBase;
  bool _discoveryDone = false;

  /// منبعی که در آخرین درخواست استفاده شد: chat | email | none
  String lastSource = 'none';

  ChatEndpoints get endpoints => _endpoints;
  String? get resolvedBase => _resolvedBase;

  /// مسیر چت را پیدا (یا از تنظیمات بخوان)
  Future<String?> resolve() async {
    if (_resolvedBase != null) return _resolvedBase;
    if (_discoveryDone) return null;
    _discoveryDone = true;
    final d = await _endpoints.discover();
    _resolvedBase = d?.base;
    return _resolvedBase;
  }

  /// تنظیم دستی مسیر چت از سوی کاربر/مدیر
  Future<void> setChatBase(String base) async {
    await _endpoints.saveApiBase(base);
    _resolvedBase = base.trim();
    _discoveryDone = true;
  }

  /// بررسی سلامت مسیر فعلی — برای نمایش وضعیت در تنظیمات
  Future<bool> ping() async {
    final base = await resolve();
    if (base == null) return false;
    try {
      await _api.get<dynamic>('$base/threads', query: {'take': 1});
      return true;
    } catch (_) {
      try {
        await _api.get<dynamic>(base, query: {'take': 1});
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  // ------------------------------------------------------------
  //  گفت‌وگوها
  // ------------------------------------------------------------
  Future<List<ChatThread>> threads() async {
    final base = await resolve();
    if (base != null) {
      final t = await _rest.threads(base);
      if (t.isNotEmpty) {
        lastSource = 'chat';
        return t;
      }
    }
    // مسیر حدسی قدیمی
    try {
      final r = await _api.get<dynamic>('/api/chat/threads');
      if (r.data is List) {
        final list = (r.data as List)
            .whereType<Map>()
            .map((e) => ChatThread.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        if (list.isNotEmpty) {
          lastSource = 'chat';
          return list;
        }
      }
    } catch (_) {}

    // fallback: صندوق ایمیل سازمانی
    lastSource = 'email';
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
          lastMessage: m.subject,
          lastAt: at,
          unread: m.isRead ? 0 : 1,
        );
      } else {
        final newer = at != null && (prev.lastAt == null || at.isAfter(prev.lastAt!));
        bySender[name] = ChatThread(
          id: newer ? m.id : prev.id,
          title: name,
          lastMessage: newer ? m.subject : prev.lastMessage,
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

  Future<List<ChatMessage>> messages(
    int threadId, {
    int? myUserId,
    int take = 100,
    String? peerName,
  }) async {
    final base = await resolve();
    if (base != null) {
      final m = await _rest.messages(base, threadId, myUserId: myUserId);
      if (m.isNotEmpty) {
        lastSource = 'chat';
        return m;
      }
    }
    try {
      final r = await _api.get<dynamic>(
        '/api/chat/$threadId/messages',
        query: {'take': take},
      );
      if (r.data is List) {
        final list = (r.data as List)
            .whereType<Map>()
            .map(
              (e) => ChatMessage.fromJson(
                Map<String, dynamic>.from(e),
                myUserId: myUserId,
              ),
            )
            .toList();
        if (list.isNotEmpty) {
          lastSource = 'chat';
          return list;
        }
      }
    } catch (_) {}

    lastSource = 'email';
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
    final base = await resolve();
    if (base != null) {
      await _rest.sendText(base, threadId, text);
      return;
    }
    try {
      await _api.post<dynamic>('/api/chat/$threadId/messages', {
        'text': text,
        'kind': 'text',
      });
      return;
    } catch (_) {}
    // آخرین راه: ایمیل سازمانی
    final accountId = await _accountId();
    final target = (to ?? '').trim();
    if (target.isEmpty) throw Exception('گیرندهٔ گفت‌وگو مشخص نیست.');
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
    final base = await resolve();
    if (base != null) {
      await _rest.sendVoice(base, threadId, file, durationSec: durationSec);
      return file.path;
    }
    final accountId = await _accountId();
    final target = (to ?? '').trim();
    if (target.isEmpty) throw Exception('گیرندهٔ گفت‌وگو مشخص نیست.');
    final bytes = await file.readAsBytes();
    await _email.send(
      emailAccountId: accountId,
      to: target,
      subject: 'پیام صوتی ${durationSec} ثانیه',
      body: 'پیام صوتی — مدت ${durationSec} ثانیه',
      attachments: [
        (
          name: file.uri.pathSegments.last,
          bytes: bytes,
          mimeType: 'audio/mp4',
        ),
      ],
    );
    return file.path;
  }

  Future<List<ChatThread>> contacts() async {
    final base = await resolve();
    if (base != null) {
      final c = await _rest.contacts(base);
      if (c.isNotEmpty) return c;
    }
    final names = <String>{};
    try {
      final inbox = await _email.inbox(pageSize: 100);
      for (final m in inbox.items) {
        final n = _peerName(m);
        if (n.isNotEmpty) names.add(n);
      }
    } catch (_) {}
    try {
      final sent = await _email.sent(pageSize: 60);
      for (final m in sent.items) {
        if (m.fromOrTo.trim().isNotEmpty) names.add(m.fromOrTo.trim());
      }
    } catch (_) {}
    final list = names
        .map((n) => ChatThread(id: n.hashCode.abs() % 100000, title: n))
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    return list;
  }

  Future<int> startThread(int userId) async {
    final base = await resolve();
    if (base != null) {
      final id = await _rest.startThread(base, userId);
      if (id > 0) return id;
    }
    return userId;
  }

  Future<int> _accountId() async {
    final accounts = await _email.accounts();
    final active = accounts.where((a) => a.isActive).toList();
    final list = active.isNotEmpty ? active : accounts;
    if (list.isEmpty) {
      throw Exception(
        'هیچ حساب ایمیل سازمانی تنظیم نشده است. در ماژول ایمیل حساب را اضافه کنید.',
      );
    }
    return list.first.id;
  }

  String _peerName(EmailMessage m) {
    final from = m.fromOrTo.trim();
    if (from.isEmpty) return '';
    final angle = RegExp(r'^(.*)<(.+)>$').firstMatch(from);
    if (angle != null) {
      final name = angle.group(1)!.trim().replaceAll('"', '');
      return name.isNotEmpty ? name : angle.group(2)!.trim();
    }
    return from;
  }
}
