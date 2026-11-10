// ============================================================
//  ریپازیتوری پیام‌رسان
//
//  مسیر اصلی = قرارداد واقعی سرور (از سورس TotallCollectionSoftware):
//      REST  → {server}/api/chat/...     (ChatController.cs)
//      Hub   → {server}/hubs/chat        (ChatHub.cs / SignalR)
//
//  اگر کاربر در «تنظیمات اتصال» آدرس/مسیر دیگری داده باشد، همان اول
//  امتحان می‌شود و بعد قرارداد اصلی. هیچ fallbackی به ایمیل وجود ندارد.
// ============================================================

import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../models/chat_models.dart';
import 'chat_endpoints.dart';
import 'chat_erp_api.dart';
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

  /// منبعی که در آخرین درخواست استفاده شد: erp | chat | none
  String lastSource = 'none';

  /// شناسهٔ کاربر جاری (برای تشخیص «پیام من») — از توکن/پروفایل ست می‌شود.
  int? myUserId;

  ChatEndpoints get endpoints => _endpoints;
  ApiClient get api => _api;
  String? get resolvedBase => _resolvedBase;

  /// کلاینت قرارداد واقعی؛ آدرس پایه‌اش با [resolve] تعیین می‌شود.
  ChatErpApi get erp =>
      ChatErpApi(_api, base: _erpBase ?? ChatEndpoints.erpBase);

  String? _erpBase;

  /// آدرس مسیرهای api/chat — یا کامل (سرور پیام‌رسان) یا نسبی روی سرور اصلی
  Future<String> _resolveErpBase() async {
    if (_erpBase != null) return _erpBase!;
    final saved = await _endpoints.savedErpBase();
    if (saved != null && saved.trim().isNotEmpty) {
      _erpBase = saved.trim();
      return _erpBase!;
    }
    // پیش‌فرض: همان سرور اصلی اپ (office.forough.ir) — مسیر نسبی
    _erpBase = ChatEndpoints.erpBase;
    return _erpBase!;
  }

  /// مسیر چت را تعیین می‌کند (از تنظیمات یا قرارداد اصلی)
  Future<String?> resolve() async {
    if (_resolvedBase != null) return _resolvedBase;
    final erpBase = await _resolveErpBase();
    if (!_discoveryDone) {
      _discoveryDone = true;
      // اگر مسیر دستی ذخیره شده، همان را نگه می‌داریم؛ وگرنه قرارداد اصلی.
      final saved = await _endpoints.savedApiBase();
      if (saved != null && saved.trim().isNotEmpty) {
        _resolvedBase = saved.trim();
        return _resolvedBase;
      }
    }
    _resolvedBase = erpBase;
    return _resolvedBase;
  }

  /// تنظیم دستی مسیر چت (از صفحهٔ تنظیمات)
  Future<void> setChatBase(String base) async {
    await _endpoints.saveApiBase(base);
    _resolvedBase = base.trim();
    _erpBase = base.trim();
    _discoveryDone = true;
  }

  /// تنظیم آدرس کامل سرور پیام‌رسان (مثلاً https://94.183.59.57:4456)
  Future<void> setServer(String server) async {
    await _endpoints.saveServer(server);
    final url = ChatEndpoints.fullUrl(server, '/api/chat');
    await _endpoints.saveApiBase(url);
    _erpBase = url;
    _resolvedBase = url;
    _discoveryDone = true;
  }

  /// بررسی سلامت اتصال به چت (JSON واقعی، نه صفحهٔ HTML)
  Future<bool> ping() async {
    final base = await resolve();
    if (base == null) return false;
    try {
      await erp.conversations(take: 1);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------
  //  گفت‌وگوها
  // ------------------------------------------------------------
  Future<List<ChatThread>> threads({String? search}) async {
    await _resolveErpBase();
    // ۱) قرارداد واقعی سرور
    try {
      final list = await erp.conversations(search: search);
      lastSource = 'erp';
      return list;
    } catch (e) {
      final first = e;
      // ۲) مسیر دستی/کشف‌شدهٔ قبلی (سازگاری با نصب‌های قدیمی)
      final base = await resolve();
      if (base != null && base != _erpBase) {
        final t = await _rest.threads(base);
        if (t.isNotEmpty) {
          lastSource = 'chat';
          return t;
        }
      }
      lastSource = 'none';
      throw Exception(
        e is ApiException ? e.message : 'گفت‌وگوها از سرور پیام‌رسان دریافت نشد.',
      );
    }
  }

  Future<List<ChatMessage>> messages(
    int threadId, {
    int? myUserId,
    int take = 50,
    String? peerName,
  }) async {
    await _resolveErpBase();
    final uid = myUserId ?? this.myUserId;
    try {
      final list = await erp.messages(threadId, pageSize: take, myUserId: uid);
      lastSource = 'erp';
      return list;
    } catch (e) {
      throw Exception(
        e is ApiException ? e.message : 'تاریخچهٔ گفت‌وگو دریافت نشد.',
      );
    }
  }

  // ------------------------------------------------------------
  //  ارسال
  // ------------------------------------------------------------
  Future<void> sendText(int threadId, String text, {String? to}) async {
    await _resolveErpBase();
    try {
      await erp.sendMessage(threadId, text: text);
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<String?> sendVoice(
    int threadId,
    File file, {
    required int durationSec,
    String? to,
  }) async {
    await _resolveErpBase();
    try {
      await erp.sendVoice(threadId, file, durationSec: durationSec);
      return file.path;
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  /// ارسال فایل/تصویر
  Future<void> sendFile(int threadId, File file) async {
    await _resolveErpBase();
    try {
      final up = await erp.uploadAttachment(threadId, file);
      await erp.sendMessage(
        threadId,
        messageType: up.messageType,
        fileUrl: up.fileUrl,
        fileName: up.fileName,
        fileSizeBytes: up.fileSizeBytes,
        fileContentType: up.fileContentType,
      );
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> markRead(int threadId, {int? lastReadMessageId}) async {
    await _resolveErpBase();
    try {
      await erp.markRead(threadId, lastReadMessageId: lastReadMessageId);
    } catch (_) {
      // خواندن اجباری نیست؛ نباید صفحه را خراب کند
    }
  }

  // ------------------------------------------------------------
  //  مخاطبین و شروع گفت‌وگو
  // ------------------------------------------------------------
  Future<List<ChatUser>> users({String? search}) async {
    await _resolveErpBase();
    try {
      return await erp.users(search: search);
    } catch (_) {
      return const [];
    }
  }

  Future<List<ChatThread>> contacts({String? search}) async {
    final list = await users(search: search);
    return list
        .map(
          (u) => ChatThread(
            id: u.existingConversationId ?? uidPlaceholder(u.id),
            title: u.name,
            userId: u.id,
            peerUserId: u.id,
            online: u.isOnline,
            type: 1,
          ),
        )
        .toList();
  }

  /// گفت‌وگوی خصوصی با کاربر را می‌سازد/برمی‌گرداند
  Future<ChatThread?> startChat(int targetUserId) async {
    await _resolveErpBase();
    try {
      final conv = await erp.createDirect(targetUserId);
      lastSource = 'erp';
      return conv;
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<int> startThread(int userId) async {
    final conv = await startChat(userId);
    return conv?.id ?? 0;
  }

  /// برای مخاطبینی که گفت‌وگو ندارند، شناسهٔ منفی موقت تا با شناسهٔ گفت‌وگو قاطی نشود
  int uidPlaceholder(int userId) => -userId;
}
