// ============================================================
//  کلاینت REST چت روی مسیرِ کشف‌شده
//  مسیر پایه از ChatEndpoints می‌آید؛ بقیهٔ مسیرها نسبت به آن ساخته
//  می‌شوند و چند حالت رایج پاسخ پوشش داده می‌شود.
// ============================================================

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/chat_models.dart';
import 'chat_endpoints.dart';

class ChatRestApi {
  ChatRestApi(this._api, this._endpoints);

  final ApiClient _api;
  final ChatEndpoints _endpoints;

  List<Map<String, dynamic>> _rows(dynamic d) {
    if (d is List) {
      return d.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    if (d is Map) {
      for (final k in const ['items', 'Items', 'data', 'Data', 'result', 'rows']) {
        final v = d[k];
        if (v is List) {
          return v.whereType<Map>().map(Map<String, dynamic>.from).toList();
        }
      }
    }
    return const [];
  }

  Future<List<ChatThread>> threads(String base) async {
    for (final suffix in const ['/threads', '/conversations', '/list', '', '/chats']) {
      try {
        final r = await _api.get<dynamic>('$base$suffix', query: {'take': 60});
        final rows = _rows(r.data);
        if (rows.isEmpty && r.data is! List) continue;
        return rows.map(ChatThread.fromJson).toList();
      } catch (_) {}
    }
    return const [];
  }

  Future<List<ChatMessage>> messages(
    String base,
    int threadId, {
    int? myUserId,
  }) async {
    for (final suffix in <String>[
      '/$threadId/messages',
      '/messages?threadId=$threadId',
      '/$threadId',
      '/get?threadId=$threadId',
    ]) {
      try {
        final r = await _api.get<dynamic>(
          '$base$suffix'.split('?').first,
          query: suffix.contains('?')
              ? {suffix.split('?')[1].split('=')[0]: threadId}
              : {'take': 100},
        );
        final rows = _rows(r.data);
        if (rows.isEmpty && r.data is! List) continue;
        return rows
            .map((e) => ChatMessage.fromJson(e, myUserId: myUserId))
            .toList();
      } catch (_) {}
    }
    return const [];
  }

  Future<void> sendText(String base, int threadId, String text) async {
    final body = <String, dynamic>{
      'threadId': threadId,
      'conversationId': threadId,
      'text': text,
      'body': text,
      'kind': 'text',
      'messageType': 'text',
    };
    Object? lastError;
    for (final path in ['/send', '/$threadId/messages', '/messages', '/']) {
      try {
        await _api.post<dynamic>('$base$path'.replaceAll('/$base/', '/'), body);
        return;
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception(lastError ?? 'ارسال نشد');
  }

  Future<void> sendVoice(
    String base,
    int threadId,
    File file, {
    required int durationSec,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw Exception('فایل صوتی خالی است.');
    final form = FormData.fromMap({
      'threadId': threadId,
      'conversationId': threadId,
      'duration': durationSec,
      'kind': 'voice',
      'messageType': 'voice',
      'file': MultipartFile.fromBytes(
        Uint8List.fromList(bytes),
        filename: file.uri.pathSegments.last,
        contentType: DioMediaType('audio', 'mp4'),
      ),
    });
    for (final path in ['/send', '/voice', '/$threadId/messages', '/upload']) {
      try {
        await _api.postForm<dynamic>('$base$path', form);
        return;
      } catch (_) {}
    }
    throw Exception('ارسال ویس نشد');
  }

  Future<List<ChatThread>> contacts(String base) async {
    for (final suffix in const ['/users', '/contacts', '/participants']) {
      try {
        final r = await _api.get<dynamic>('$base$suffix', query: {'take': 200});
        final rows = _rows(r.data);
        if (rows.isEmpty) continue;
        return rows.map((e) {
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
      } catch (_) {}
    }
    return const [];
  }

  Future<int> startThread(String base, int userId) async {
    for (final path in const ['/threads', '/conversations', '/start']) {
      try {
        final r = await _api.post<dynamic>('$base$path', {'userId': userId});
        final d = r.data;
        if (d is Map) {
          final id = (d['id'] ?? d['threadId'] ?? d['conversationId']) as num?;
          if (id != null) return id.toInt();
        }
        if (d is num) return d.toInt();
      } catch (_) {}
    }
    return 0;
  }
}
