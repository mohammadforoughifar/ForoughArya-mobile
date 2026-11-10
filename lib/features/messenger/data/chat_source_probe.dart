// ============================================================
//  تحلیل «منابع داده» پیام‌رسان
//
//  مسئله: بعضی مسیرها ۲۰۰ برمی‌گردانند ولی HTML صفحهٔ وب‌اند (نه JSON).
//  نسخهٔ قبلی فقط کد وضعیت را نگاه می‌کرد و می‌گفت «اتصال برقرار شد»،
//  در حالی که هیچ چتی خوانده نمی‌شد. این فایل هر مسیر را باز می‌کند و
//  مشخص می‌کند: JSON است؟ چه نوعی (لیست گفت‌وگو / کاربر / پیام)؟
//  چند رکورد دارد؟ اگر HTML بود چه خبر است؟ و برای ادمین، آدرس
//  swagger را هم گزارش می‌کند تا مسیر دقیق مشخص شود.
// ============================================================

import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'chat_endpoints.dart';

/// نوع محتوایی که از یک آدرس برگشت
enum SourceKind {
  /// فهرست گفت‌وگوها (قابل استفادهٔ مستقیم)
  threads,

  /// فهرست کاربران/مخاطبین (برای ساخت گفت‌وگو)
  users,

  /// فهرست پیام‌های یک گفت‌وگو
  messages,

  /// JSON است ولی ساختارش ناشناخته
  jsonUnknown,

  /// صفحهٔ HTML وب (SPA) — دادهٔ چت نیست
  html,

  /// خطای HTTP / شبکه
  error,
}

class SourceProbe {
  SourceProbe({
    required this.url,
    required this.status,
    required this.kind,
    this.count = 0,
    this.note,
    this.sample = '',
  });

  final String url;
  final int? status;
  final SourceKind kind;
  final int count;
  final String? note;

  /// اولین بخش پاسخ (برای نمایش/کپی) — حداکثر ۱۲۰ کاراکتر
  final String sample;

  bool get usable =>
      kind == SourceKind.threads ||
      kind == SourceKind.users ||
      kind == SourceKind.messages;

  String get label {
    final icon = switch (kind) {
      SourceKind.threads => '✅ چت',
      SourceKind.users => '✅ کاربر',
      SourceKind.messages => '✅ پیام',
      SourceKind.jsonUnknown => '⚠️ JSON ناشناخته',
      SourceKind.html => '❌ صفحهٔ وب (HTML)',
      SourceKind.error => '❌ خطا',
    };
    final n = count > 0 ? ' · $count' : '';
    return '$url → ${status ?? "—"} $icon$n';
  }
}

class ChatSourceProbe {
  ChatSourceProbe(this._api);

  final ApiClient _api;

  /// آخرین نتایج تحلیل — برای نمایش در تنظیمات
  final List<SourceProbe> results = [];

  /// مسیرهای پیشنهادی روی سروری که کاربر داده است.
  static List<String> candidates(String server) {
    final base = server.trim().replaceAll(RegExp(r'/+$'), '');
    final out = <String>[];
    for (final p in const [
      '/chat',
      '/chat/api',
      '/chat/api/chat',
      '/chat/api/chatmessage',
      '/chat/swagger/v1/swagger.json',
      '/chat/hub',
      '/api/chat',
      '/api/chatmessage',
      '/api/messages',
      '/api/conversations',
      '/api/users',
      '/swagger/v1/swagger.json',
      '/swagger.json',
    ]) {
      final u = ChatEndpoints.fullUrl(base, p);
      if (!out.contains(u)) out.add(u);
    }
    return out;
  }

  /// همهٔ مسیرها را می‌زند و نوع پاسخ هرکدام را مشخص می‌کند.
  Future<List<SourceProbe>> run(String server) async {
    results.clear();
    for (final url in candidates(server)) {
      results.add(await probeUrl(url));
    }
    return results;
  }

  /// تحلیل یک آدرس تکی.
  Future<SourceProbe> probeUrl(String url) async {
    try {
      final r = await _api.get<dynamic>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      return _classify(url, r.statusCode, r.data);
    } on ApiException catch (e) {
      return SourceProbe(
        url: url,
        status: e.statusCode,
        kind: SourceKind.error,
        note: e.message,
      );
    } catch (e) {
      return SourceProbe(
        url: url,
        status: null,
        kind: SourceKind.error,
        note: 'شبکه: $e',
      );
    }
  }

  SourceProbe _classify(String url, int? status, dynamic data) {
    var body = '';
    if (data is String) {
      body = data;
    } else if (data is List<int>) {
      body = utf8.decode(data, allowMalformed: true);
    } else if (data is Map || data is List) {
      final rows = _rows(data);
      return SourceProbe(
        url: url,
        status: status,
        kind: _kindOfRows(data, rows),
        count: rows.length,
        note: data is Map
            ? 'کلیدها: ${data.keys.take(7).join(" , ")}'
            : null,
        sample: _trim(jsonEncode(data), 120),
      );
    }

    final t = body.trimLeft();
    if (t.startsWith('<!DOCTYPE') ||
        t.startsWith('<html') ||
        t.contains('<app-root') ||
        t.contains('<div id="app"')) {
      return SourceProbe(
        url: url,
        status: status,
        kind: SourceKind.html,
        note: url.contains('swagger')
            ? 'صفحهٔ swagger باز نیست (به HTML ریدایرکت شد)'
            : 'این مسیر صفحهٔ وب پیام‌رسان است، نه API آن',
        sample: _trim(body, 90),
      );
    }
    if (t.startsWith('{') || t.startsWith('[')) {
      try {
        final decoded = jsonDecode(t);
        final rows = _rows(decoded);
        return SourceProbe(
          url: url,
          status: status,
          kind: _kindOfRows(decoded, rows),
          count: rows.length,
          note: decoded is Map
              ? 'کلیدها: ${decoded.keys.take(7).join(" , ")}'
              : null,
          sample: _trim(t, 120),
        );
      } catch (_) {}
    }
    return SourceProbe(
      url: url,
      status: status,
      kind: SourceKind.jsonUnknown,
      note: body.isEmpty ? 'پاسخ خالی' : 'نوع پاسخ ناشناخته',
      sample: _trim(body, 90),
    );
  }

  static List<Map<String, dynamic>> _rows(dynamic d) {
    if (d is List) {
      return d.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    if (d is Map) {
      for (final k in const [
        'items',
        'Items',
        'data',
        'Data',
        'result',
        'Result',
        'list',
        'List',
        'threads',
        'Threads',
        'conversations',
        'users',
        'Users',
        'messages',
        'Messages',
        r'$values',
      ]) {
        final v = d[k];
        if (v is List) {
          return v.whereType<Map>().map(Map<String, dynamic>.from).toList();
        }
      }
    }
    return const [];
  }

  static SourceKind _kindOfRows(
    dynamic decoded,
    List<Map<String, dynamic>> rows,
  ) {
    if (rows.isEmpty) return SourceKind.jsonUnknown;
    final keys = rows.first.keys.map((e) => e.toLowerCase()).toSet();
    bool has(List<String> names) => names.any(keys.contains);

    if (has(const [
      'lastmessage',
      'lastmessagetext',
      'unreadcount',
      'participants',
    ])) {
      return SourceKind.threads;
    }
    if (has(const [
      'senderid',
      'receiverid',
      'text',
      'body',
      'sentat',
      'message',
    ])) {
      return SourceKind.messages;
    }
    if (has(const ['username', 'fullname', 'firstname', 'lastname']) &&
        !has(const ['title', 'subject'])) {
      return SourceKind.users;
    }
    if (has(const ['title', 'subject', 'peername']) ||
        has(const ['threadid', 'conversationid'])) {
      return SourceKind.threads;
    }
    if (has(const ['id', 'name'])) return SourceKind.threads;
    return SourceKind.jsonUnknown;
  }

  static String _trim(String s, int n) {
    final one = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return one.length <= n ? one : '${one.substring(0, n)}…';
  }
}
