// ============================================================
//  کشف خودکار مسیرهای چت روی سرور
//
//  مسئله: پیام‌رسان وب شما چت را روی یک کنترلر/Hub مشخص سرو می‌کند
//  ولی نام دقیق آن را نمی‌دانیم. این فایل چند نام رایج را امتحان
//  می‌کند و اولین مسیری که جواب دهد را در حافظه نگه می‌دارد.
//  کاربر هم می‌تواند در تنظیمات پیام‌رسان، مسیر را دستی وارد کند.
// ============================================================

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';

class ChatEndpoints {
  ChatEndpoints(this._api, this._storage);

  final ApiClient _api;
  final FlutterSecureStorage _storage;

  static const _kApiBase = 'chat_api_base'; // مثل /api/chatmessage
  static const _kHubPath = 'chat_hub_path'; // مثل /chatHub
  static const _kKind = 'chat_api_kind'; // rest | hub

  /// نام‌های رایجِ کنترلر چت در بک‌اندهای .NET
  static const apiCandidates = <String>[
    '/api/chatmessage',
    '/api/chatmessages',
    '/api/chat',
    '/api/messages',
    '/api/messenger',
    '/api/chat/messages',
    '/api/internalchat',
    '/api/im',
    '/api/conversations',
  ];

  /// مسیرهای رایج Hub
  static const hubCandidates = <String>[
    '/chatHub',
    '/hubs/chat',
    '/chat',
    '/messageHub',
    '/hubs/message',
    '/notificationHub',
  ];

  /// مسیرهای زیرمجموعه برای گرفتن «فهرست گفت‌وگوها»
  static const listSuffixes = <String>[
    '/threads',
    '/conversations',
    '/list',
    '/chats',
    '/inbox',
    '',
  ];

  Future<String?> savedApiBase() => _storage.read(key: _kApiBase);
  Future<String?> savedHubPath() => _storage.read(key: _kHubPath);
  Future<String?> savedKind() => _storage.read(key: _kKind);

  Future<void> saveApiBase(String value) =>
      _storage.write(key: _kApiBase, value: value.trim());
  Future<void> saveHubPath(String value) =>
      _storage.write(key: _kHubPath, value: value.trim());
  Future<void> saveKind(String value) =>
      _storage.write(key: _kKind, value: value.trim());

  /// نتیجهٔ کشف: مسیری که واقعاً جواب داده + نمونهٔ پاسخ
  Future<Discovery?> discover({bool force = false}) async {
    if (!force) {
      final base = await savedApiBase();
      if (base != null && base.isNotEmpty) {
        return Discovery(base: base, kind: 'rest');
      }
    }

    // ۱) از فهرست مسیرهای swagger سرور استفاده کن (اگر باز باشد)
    final fromSwagger = await _fromSwagger();
    if (fromSwagger != null) {
      await saveApiBase(fromSwagger);
      await saveKind('rest');
      return Discovery(base: fromSwagger, kind: 'rest');
    }

    // ۲) حدس‌های رایج
    for (final base in apiCandidates) {
      for (final suffix in listSuffixes) {
        final path = '$base$suffix';
        try {
          final r = await _api.get<dynamic>(path, query: {'take': 5});
          final d = r.data;
          final ok = d is List || (d is Map && (d['items'] ?? d['Items']) is List);
          if (ok) {
            await saveApiBase(base);
            await saveKind('rest');
            return Discovery(base: base, kind: 'rest', probePath: path);
          }
        } catch (_) {
          // این مسیر نیست؛ بعدی
        }
      }
    }
    return null;
  }

  /// خواندن swagger و برداشتن اولین مسیر مرتبط با چت
  Future<String?> _fromSwagger() async {
    for (final doc in const ['/swagger/v1/swagger.json', '/swagger.json']) {
      try {
        final r = await _api.get<dynamic>(doc);
        final paths = (r.data is Map) ? (r.data['paths'] as Map?) : null;
        if (paths == null) continue;
        for (final key in paths.keys) {
          final p = key.toString().toLowerCase();
          if (p.contains('chat') || p.contains('message') || p.contains('conversation')) {
            // /api/chatmessage/{id} → /api/chatmessage
            final segs = key.toString().split('/');
            final base = segs.takeWhile((s) => !s.contains('{')).join('/');
            if (base.isNotEmpty && base.split('/').length >= 2) return base;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// تبدیل آدرس کامل واردشده به مسیر نسبی روی همان سرور
  static String normalizeBase(String input, String baseUrl) {
    var v = input.trim();
    if (v.isEmpty) return '';
    // اگر آدرس کامل بود، دامنه را حذف کن
    final m = RegExp(r'^https?://[^/]+(/.*)?$').firstMatch(v);
    if (m != null) {
      v = m.group(1) ?? '/';
    }
    if (!v.startsWith('/')) v = '/$v';
    v = v.replaceAll(RegExp(r'/+$'), '');
    return v;
  }

  /// آدرس کامل hub برای SignalR
  Future<String?> hubUrl() async {
    final p = await savedHubPath();
    if (p != null && p.isNotEmpty) {
      return '${_api.baseUrl.replaceAll(RegExp(r"https?://"), "wss://")}$p';
    }
    return null;
  }
}

class Discovery {
  Discovery({required this.base, required this.kind, this.probePath});
  final String base;
  final String kind;
  final String? probePath;
}
