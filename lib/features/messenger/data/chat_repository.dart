// ============================================================
//  ریپازیتوری پیام‌رسان — مسیرهای واقعی بک‌اند
//
//    GET  /api/chat/threads            فهرست گفت‌وگوها
//    GET  /api/chat/{threadId}/messages پیام‌های یک گفت‌وگو
//    POST /api/chat/{threadId}/messages ارسال پیام (متن یا ویس)
//    POST /api/chat/voice              آپلود فایل ویس → {url}
//    GET  /api/chat/users              همکاران برای شروع گفت‌وگوی تازه
//    POST /api/chat/threads            ساخت گفت‌وگوی تازه
//
//  اگر سرور این مسیرها را نداشته باشد، خطای خوانا برمی‌گردد
//  (نه صفر/دادهٔ جعلی).
// ============================================================

import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/chat_models.dart';

class ChatRepository {
  ChatRepository(this._api);
  final ApiClient _api;

  static const _root = '/api/chat';

  List<Map<String, dynamic>> _list(dynamic data) {
    if (data is List) {
      return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    if (data is Map) {
      final raw = data['items'] ?? data['Items'] ?? data['data'] ?? data['Data'];
      if (raw is List) {
        return raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
      }
    }
    return const [];
  }

  Future<List<ChatThread>> threads() async {
    final r = await _api.get<dynamic>('$_root/threads');
    return _list(r.data).map(ChatThread.fromJson).toList();
  }

  Future<List<ChatMessage>> messages(
    int threadId, {
    int? myUserId,
    int take = 100,
  }) async {
    final r = await _api.get<dynamic>(
      '$_root/$threadId/messages',
      query: {'take': take},
    );
    return _list(r.data)
        .map((e) => ChatMessage.fromJson(e, myUserId: myUserId))
        .toList();
  }

  /// ارسال پیام متنی
  Future<void> sendText(int threadId, String text) async {
    await _api.post<dynamic>('$_root/$threadId/messages', {
      'text': text,
      'kind': 'text',
    });
  }

  /// آپلود ویس و ارسال آن — برگشت آدرس فایل روی سرور
  Future<String?> sendVoice(
    int threadId,
    File file, {
    required int durationSec,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.uri.pathSegments.last,
      ),
      'duration': durationSec,
    });
    String? url;
    try {
      final up = await _api.postForm<dynamic>('$_root/voice', form);
      final d = up.data;
      if (d is Map) {
        url = (d['url'] ?? d['fileUrl'] ?? d['path'])?.toString();
      } else if (d is String) {
        url = d;
      }
    } catch (_) {
      // اگر مسیر آپلود جدا نبود، فایل را همراه خود پیام می‌فرستیم.
    }
    final msg = FormData.fromMap({
      'kind': 'voice',
      'duration': durationSec,
      if (url != null) 'url': url,
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.uri.pathSegments.last,
      ),
    });
    await _api.postForm<dynamic>('$_root/$threadId/messages', msg);
    return url;
  }

  /// همکاران برای شروع گفت‌وگوی تازه
  Future<List<ChatThread>> contacts() async {
    final r = await _api.get<dynamic>('$_root/users', query: {'take': 200});
    return _list(r.data).map((e) {
      final id = (e['id'] ?? e['userId'] ?? e['Id']) as num?;
      final name =
          (e['fullName'] ?? e['name'] ?? e['displayName'] ?? e['username'] ?? '')
              .toString();
      return ChatThread(
        id: id?.toInt() ?? 0,
        title: name.isEmpty ? 'کاربر' : name,
        userId: id?.toInt(),
      );
    }).toList();
  }

  Future<int> startThread(int userId) async {
    final r = await _api.post<dynamic>('$_root/threads', {'userId': userId});
    final d = r.data;
    if (d is Map) return ((d['id'] ?? d['threadId']) as num?)?.toInt() ?? 0;
    return (d as num?)?.toInt() ?? 0;
  }
}
