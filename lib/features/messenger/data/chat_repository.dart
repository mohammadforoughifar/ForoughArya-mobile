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
import '../models/chat_models.dart';
import 'chat_endpoints.dart';
import 'chat_rest_api.dart';

class ChatRepository {
  ChatRepository(this._api, {FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage() {
    _endpoints = ChatEndpoints(_api, _storage);
    _rest = ChatRestApi(_api, _endpoints);
  }

  final ApiClient _api;
  final FlutterSecureStorage _storage;
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
    if (_resolvedBase == null) {
      // حتی اگر کاوش جواب نداد، همان سرور پیام‌رسان را امتحان می‌کنیم
      // تا خطای واقعی (۴۰۱/۴۰۴/شبکه) به کاربر نشان داده شود.
      final server = await _endpoints.savedServer();
      _resolvedBase = ChatEndpoints.fullUrl(
        server,
        ChatEndpoints.defaultChatPath,
      );
    }
    return _resolvedBase;
  }

  /// آدرس سرور پیام‌رسان (برای نمایش در تنظیمات)
  Future<String> serverUrl() => _endpoints.savedServer();

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
    // هیچ fallbackی به ایمیل وجود ندارد — پیام‌رسان باید همان چت وب باشد
    lastSource = 'none';
    throw Exception(
      'اتصال به سرور پیام‌رسان برقرار نشد. آدرس سرور و مسیر API چت را در '
      '«تنظیمات اتصال» بررسی یا با دکمهٔ شناسایی خودکار پیدا کنید.',
    );
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
        '$base/$threadId/messages',
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

    lastSource = 'none';
    throw Exception('تاریخچهٔ گفت‌وگو از سرور پیام‌رسان دریافت نشد.');
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
      await _api.post<dynamic>('$base/$threadId/messages', {
        'text': text,
        'kind': 'text',
      });
      return;
    } catch (_) {}
    throw Exception(
      'پیام ارسال نشد: مسیر API چت روی سرور پیام‌رسان پیدا نشد. '
      'در «تنظیمات اتصال» مسیر را مشخص کنید.',
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
    throw Exception(
      'ویس ارسال نشد: مسیر API چت روی سرور پیدا نشد. در «تنظیمات اتصال» '
      'مسیر را مشخص کنید.',
    );
  }

  Future<List<ChatThread>> contacts() async {
    final base = await resolve();
    if (base != null) {
      final c = await _rest.contacts(base);
      if (c.isNotEmpty) return c;
    }
    return const <ChatThread>[];
  }

  Future<int> startThread(int userId) async {
    final base = await resolve();
    if (base != null) {
      final id = await _rest.startThread(base, userId);
      if (id > 0) return id;
    }
    return userId;
  }

}
