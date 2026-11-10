// ============================================================
//  کشف خودکار مسیرهای چت روی سرور
//
//  مسئله: پیام‌رسان وب شما چت را روی یک کنترلر/Hub مشخص سرو می‌کند
//  ولی نام دقیق آن را نمی‌دانیم. این فایل چند نام رایج را امتحان
//  می‌کند و اولین مسیری که جواب دهد را در حافظه نگه می‌دارد.
//  کاربر هم می‌تواند در تنظیمات پیام‌رسان، مسیر را دستی وارد کند.
// ============================================================

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import 'chat_source_probe.dart';

class ChatEndpoints {
  ChatEndpoints(this._api, this._storage);

  final ApiClient _api;
  final FlutterSecureStorage _storage;

  static const _kApiBase = 'chat_api_base'; // مثل /api/chatmessage
  static const _kHubPath = 'chat_hub_path'; // مثل /chatHub
  static const _kKind = 'chat_api_kind'; // rest | hub
  static const _kServer = 'chat_server_url'; // سرور مستقل پیام‌رسان

  /// سرور پیام‌رسان — جدا از سرور اتوماسیون.
  /// کاربر این آدرس را داده است: https://94.183.59.57:4457/chat
  static const defaultServer = 'https://94.183.59.57:4457';
  static const defaultChatPath = '/chat';

  Future<String> savedServer() async {
    final v = await _storage.read(key: _kServer);
    if (v != null && v.trim().isNotEmpty) return v.trim();
    return defaultServer;
  }

  Future<void> saveServer(String value) async {
    var v = value.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    await _storage.write(key: _kServer, value: v);
  }

  /// نام‌های رایجِ کنترلر چت در بک‌اندهای .NET
  static const apiCandidates = <String>[
    // نام‌های رایج کنترلر چت در همین بک‌اند (کنار letters/email/workorders)
    '/api/chatmessage',
    '/api/chatmessages',
    '/api/chatmessagescontroller',
    '/api/chat',
    '/api/internalchat',
    '/api/instantmessage',
    '/api/message',
    '/api/messages',
    '/api/messenger',
    '/api/conversations',
    '/api/chat/messages',
    '/api/im',
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
    '/chatlist',
    '/my',
    '/list',
    '/chats',
    '/inbox',
    '/users',
    '/contacts',
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
  /// گزارش آخرین تلاش‌ها (برای صفحهٔ تنظیمات)
  final List<ProbeResult> probes = [];

  /// نتیجهٔ تحلیل منابع داده (نوع پاسخ هر مسیر: JSON چت / HTML / خطا)
  List<SourceProbe> lastSources = const [];

  Future<Discovery?> discover({bool force = false}) async {
    probes.clear();
    if (!force) {
      final base = await savedApiBase();
      if (base != null && base.isNotEmpty) {
        return Discovery(base: base, kind: 'rest');
      }
    }

    // ۰) سرور مستقل پیام‌رسان (آدرسی که کاربر داده) — اولویت اول.
    //    نکتهٔ مهم: فقط «۲۰۰ گرفتن» کافی نیست؛ بعضی مسیرها صفحهٔ HTML
    //    برمی‌گردانند و چت را بالا نمی‌آورند. پس اینجا نوع پاسخ هم
    //    بررسی می‌شود و فقط مسیرهایی پذیرفته می‌شوند که دادهٔ واقعی
    //    (فهرست گفت‌وگو/کاربر/پیام) بدهند.
    final server = await savedServer();
    final sourceProbe = ChatSourceProbe(_api);
    final analyzed = await sourceProbe.run(server);
    probes.addAll(
      analyzed.map(
        (p) => ProbeResult(
          p.url,
          status: p.status,
          ok: p.usable,
          note: p.kind == SourceKind.html
              ? 'صفحهٔ وب، نه API'
              : (p.note ?? p.kind.name),
        ),
      ),
    );
    lastSources = analyzed;
    for (final p in analyzed) {
      if (!p.usable) continue;
      await saveServer(server);
      await saveApiBase(p.url);
      await saveKind('rest');
      return Discovery(base: p.url, kind: 'rest', probePath: p.url);
    }
    // هیچ دادهٔ JSON‌ای نبود. اگر /chat دست‌کم باز است، همان را به‌عنوان
    // پایه نگه می‌داریم تا خطای دقیق به کاربر نشان داده شود.
    final chatUrl = fullUrl(server, defaultChatPath);
    if (analyzed.any((p) => p.url == chatUrl && p.status != null)) {
      await saveServer(server);
      await saveApiBase(chatUrl);
      await saveKind('rest');
      return Discovery(base: chatUrl, kind: 'rest', probePath: chatUrl);
    }

    // ۱) از فهرست مسیرهای swagger سرور استفاده کن (اگر باز باشد)
    final fromSwagger = await _fromSwagger();
    if (fromSwagger != null) {
      await saveApiBase(fromSwagger);
      await saveKind('rest');
      return Discovery(base: fromSwagger, kind: 'rest');
    }

    // ۲) حدس‌های رایج روی همان Base URL زندهٔ اپ
    for (final base in apiCandidates) {
      for (final suffix in listSuffixes) {
        final path = '$base$suffix';
        try {
          final r = await _api.get<dynamic>(path, query: {'take': 5});
          probes.add(ProbeResult(path, status: r.statusCode));
          final d = r.data;
          final ok = d is List ||
              (d is Map &&
                  ((d['items'] ??
                              d['Items'] ??
                              d['data'] ??
                              d['threads'] ??
                              d['conversations']) is
                          List));
          if (ok) {
            probes.last = ProbeResult(path, status: r.statusCode, ok: true);
            await saveApiBase(base);
            await saveKind('rest');
            return Discovery(base: base, kind: 'rest', probePath: path);
          }
        } catch (e) {
          final st = e is ApiException ? e.statusCode : null;
          probes.add(ProbeResult(path, status: st, note: st == null ? 'شبکه' : null));
        }
      }
      // بعضی کنترلرها «GET /api/chatmessage/users/{id}» می‌خواهند
      for (final suffix in const ['/all', '/getall', '/my-chats', '/chats']) {
        try {
          final r = await _api.get<dynamic>('$base$suffix');
          probes.add(ProbeResult('$base$suffix', status: r.statusCode, ok: true));
          await saveApiBase(base);
          await saveKind('rest');
          return Discovery(base: base, kind: 'rest', probePath: '$base$suffix');
        } catch (e) {
          final st = e is ApiException ? e.statusCode : null;
          probes.add(ProbeResult('$base$suffix', status: st, note: st == null ? 'شبکه' : null));
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
        // اولویت: مسیری که خودش «فهرست گفت‌وگو» است
        final keys = paths.keys.map((k) => k.toString()).toList();
        String? fallback;
        for (final key in keys) {
          final low = key.toLowerCase();
          final related = low.contains('chat') ||
              low.contains('message') ||
              low.contains('conversation') ||
              low.contains('talk');
          if (!related) continue;
          final base = key.split('{').first;
          final trimmed = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
          if (trimmed.split('/').length < 2) continue;
          if (low.contains('thread') ||
              low.contains('conversation') ||
              low.contains('chatlist')) {
            return trimmed;
          }
          fallback ??= trimmed;
        }
        if (fallback != null) return fallback;
      } catch (_) {}
    }
    return null;
  }

  /// آدرس کامل یک درخواست روی سرور پیام‌رسان.
  /// [path] می‌تواند مسیر نسبی (/chat/api/...) یا کامل باشد.
  static String fullUrl(String server, String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    var base = server.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    final rel = path.startsWith('/') ? path.substring(1) : path;
    return '$base/$rel';
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
      return _api.resolveUrl(p).replaceFirst(RegExp(r'^http'), 'ws');
    }
    return null;
  }
}

/// یک تلاش برای پیدا کردن مسیر — برای نمایش در «گزارش شناسایی»
class ProbeResult {
  ProbeResult(this.path, {this.status, this.ok = false, this.note});
  final String path;
  final int? status;
  final bool ok;
  final String? note;

  String get label =>
      '$path → ${ok ? "✅ ${status ?? 200}" : (status != null ? "❌ $status" : "❌ ${note ?? "بدون پاسخ"}")}';
}

class Discovery {
  Discovery({required this.base, required this.kind, this.probePath});
  final String base;
  final String kind;
  final String? probePath;
}
