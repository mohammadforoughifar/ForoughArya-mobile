// ============================================================
//  کلاینت چت سازمانی — مطابق قرارداد واقعی سرور
//
//  منبع: TotallCollectionSoftware
//    src/Inventory.Api/Controllers/System/ChatController.cs  → Route: api/chat
//    src/Inventory.Api/Hubs/System/ChatHub.cs                → /hubs/chat
//    src/Inventory.Shared/Dtos/ChatDtos.cs
//
//  فهرست دقیق مسیرها (همه با Authorization: Bearer):
//    GET    /api/chat/conversations?search&type&onlyUnread&skip&take
//    GET    /api/chat/conversations/{id}
//    POST   /api/chat/conversations/direct        { targetUserId }
//    POST   /api/chat/conversations/group         { title, memberUserIds... }
//    GET    /api/chat/conversations/{id}/messages?beforeId&pageSize&search
//    POST   /api/chat/conversations/{id}/messages { text, messageType, fileUrl… }
//    POST   /api/chat/conversations/{id}/read     { lastReadMessageId }
//    POST   /api/chat/conversations/{id}/pin
//    POST   /api/chat/conversations/{id}/mute
//    GET    /api/chat/conversations/{id}/members
//    GET    /api/chat/users?search
//    GET    /api/chat/summary
//    POST   /api/chat/conversations/{id}/attachments   (multipart, فیلد file)
//    PUT    /api/chat/messages/{id}                { newText }
//    DELETE /api/chat/messages/{id}
//    POST   /api/chat/messages/{id}/react          { emoji }
//    POST   /api/chat/messages/{id}/pin
//
//  نکتهٔ مهم: پاسخ فهرست‌ها یا «آرایه» است یا «{ total, items }» (وقتی
//  skip/take فرستاده شود) — هر دو پوشش داده شده‌اند.
// ============================================================

import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/chat_models.dart';

/// نوع گفت‌وگو مطابق enum سرور (ChatTypeDto)
class ChatType {
  static const direct = 1;
  static const group = 2;
  static const channel = 3;
}

/// نوع پیام مطابق enum سرور (ChatMessageTypeDto) — سرور عدد می‌فرستد
class ChatMessageType {
  static const text = 1;
  static const image = 2;
  static const file = 3;
  static const audio = 4;
  static const video = 5;
  static const system = 6;
  static const erpShare = 7;
}

class ChatErpApi {
  ChatErpApi(this._api, {String base = '/api/chat'}) : _base = base;

  final ApiClient _api;

  /// مسیر پایهٔ چت؛ یا نسبی (`/api/chat`) یا کامل (`https://host/api/chat`).
  String _base;

  String get base => _base;
  set base(String v) => _base = v;

  String _u(String suffix) => '$_base$suffix';

  /// پاسخ‌ها گاهی آرایه و گاهی { total, items } هستند.
  static List<Map<String, dynamic>> rows(dynamic d) {
    if (d is List) {
      return d.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    if (d is Map) {
      for (final k in const ['items', 'Items', 'data', 'Data', 'result']) {
        final v = d[k];
        if (v is List) {
          return v.whereType<Map>().map(Map<String, dynamic>.from).toList();
        }
      }
    }
    return const [];
  }

  // ------------------------------------------------------------
  //  گفت‌وگوها
  // ------------------------------------------------------------
  Future<List<ChatThread>> conversations({
    String? search,
    int? type,
    bool onlyUnread = false,
    int skip = 0,
    int take = 60,
  }) async {
    final r = await _api.get<dynamic>(
      _u('/conversations'),
      query: {
        'skip': skip,
        'take': take,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (type != null) 'type': type,
        if (onlyUnread) 'onlyUnread': true,
      },
    );
    return rows(r.data).map(ChatThread.fromErp).toList();
  }

  Future<ChatThread?> conversation(int id) async {
    final r = await _api.get<dynamic>(_u('/conversations/$id'));
    final d = r.data;
    if (d is! Map) return null;
    return ChatThread.fromErp(Map<String, dynamic>.from(d));
  }

  /// شروع/گرفتن گفت‌وگوی خصوصی با کاربر هدف
  Future<ChatThread?> createDirect(int targetUserId) async {
    final r = await _api.post<dynamic>(_u('/conversations/direct'), {
      'targetUserId': targetUserId,
    });
    final d = r.data;
    if (d is! Map) return null;
    return ChatThread.fromErp(Map<String, dynamic>.from(d));
  }

  Future<ChatThread?> createGroup({
    required String title,
    String? description,
    required List<int> memberUserIds,
  }) async {
    final r = await _api.post<dynamic>(_u('/conversations/group'), {
      'title': title,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      'type': ChatType.group,
      'memberUserIds': memberUserIds,
    });
    final d = r.data;
    if (d is! Map) return null;
    return ChatThread.fromErp(Map<String, dynamic>.from(d));
  }

  // ------------------------------------------------------------
  //  پیام‌ها
  // ------------------------------------------------------------
  Future<List<ChatMessage>> messages(
    int conversationId, {
    int? beforeId,
    int pageSize = 50,
    String? search,
    int? myUserId,
  }) async {
    final r = await _api.get<dynamic>(
      _u('/conversations/$conversationId/messages'),
      query: {
        'pageSize': pageSize,
        if (beforeId != null) 'beforeId': beforeId,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    final list = rows(r.data)
        .map((e) => ChatMessage.fromErp(e, myUserId: myUserId))
        .map((m) => m.withUrls(fileUrl))
        .toList();
    // سرور جدیدترین‌ها را اول می‌دهد؛ برای نمایش از قدیم به جدید برمی‌گردانیم.
    list.sort((a, b) => a.id.compareTo(b.id));
    return list;
  }

  /// ارسال پیام متنی/فایل/ویس
  Future<ChatMessage?> sendMessage(
    int conversationId, {
    String? text,
    int messageType = ChatMessageType.text,
    String? fileUrl,
    String? fileName,
    int? fileSizeBytes,
    String? fileContentType,
    int? replyToMessageId,
  }) async {
    final r = await _api.post<dynamic>(
      _u('/conversations/$conversationId/messages'),
      {
        'conversationId': conversationId,
        if (text != null && text.isNotEmpty) 'text': text,
        'messageType': messageType,
        if (fileUrl != null) 'fileUrl': fileUrl,
        if (fileName != null) 'fileName': fileName,
        if (fileSizeBytes != null) 'fileSizeBytes': fileSizeBytes,
        if (fileContentType != null) 'fileContentType': fileContentType,
        if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      },
    );
    final d = r.data;
    if (d is! Map) return null;
    return ChatMessage.fromErp(Map<String, dynamic>.from(d));
  }

  /// آپلود پیوست با گزارش درصد پیشرفت (برای نمایش «در حال ارسال ۴۵٪»)
  Future<ChatUpload> uploadAttachmentWithProgress(
    int conversationId,
    File file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final name = file.uri.pathSegments.last;
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: name),
    });
    final r = await _api.postForm<dynamic>(
      _u('/conversations/$conversationId/attachments'),
      form,
      onSendProgress: onProgress,
    );
    return _uploadFromResponse(r.data, name);
  }

  /// آپلود پیوست (سقف ۵۰ مگابایت) → خروجی شامل fileUrl برای ارسال پیام
  Future<ChatUpload> uploadAttachment(int conversationId, File file) async {
    final name = file.uri.pathSegments.last;
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: name),
    });
    final r = await _api.postForm<dynamic>(
      _u('/conversations/$conversationId/attachments'),
      form,
    );
    return _uploadFromResponse(r.data, name);
  }

  ChatUpload _uploadFromResponse(dynamic d, String fallbackName) {
    if (d is! Map) throw Exception('پاسخ آپلود نامعتبر بود.');
    final m = Map<String, dynamic>.from(d);
    return ChatUpload(
      id: (m['id'] ?? '').toString(),
      fileUrl: (m['fileUrl'] ?? '').toString(),
      fileName: (m['fileName'] ?? fallbackName).toString(),
      fileSizeBytes: (m['fileSizeBytes'] as num?)?.toInt() ?? 0,
      fileContentType: (m['fileContentType'] ?? 'application/octet-stream')
          .toString(),
      messageType: (m['messageType'] as num?)?.toInt() ?? ChatMessageType.file,
    );
  }

  /// ارسال ویس: آپلود سپس پیام از نوع audio
  Future<ChatMessage?> sendVoice(
    int conversationId,
    File file, {
    int durationSec = 0,
  }) async {
    final up = await uploadAttachment(conversationId, file);
    return sendMessage(
      conversationId,
      messageType: ChatMessageType.audio,
      fileUrl: up.fileUrl,
      fileName: up.fileName,
      fileSizeBytes: up.fileSizeBytes,
      fileContentType: up.fileContentType,
    );
  }

  Future<void> markRead(int conversationId, {int? lastReadMessageId}) =>
      _api.post<dynamic>(_u('/conversations/$conversationId/read'), {
        if (lastReadMessageId != null) 'lastReadMessageId': lastReadMessageId,
      });

  Future<void> togglePinConversation(int id) =>
      _api.post<dynamic>(_u('/conversations/$id/pin'));

  Future<void> toggleMuteConversation(int id) =>
      _api.post<dynamic>(_u('/conversations/$id/mute'));

  Future<void> deleteMessage(int id) =>
      _api.delete<dynamic>(_u('/messages/$id'));

  Future<void> editMessage(int id, String newText) =>
      _api.put<dynamic>(_u('/messages/$id'), {'newText': newText});

  Future<void> react(int messageId, String emoji) =>
      _api.post<dynamic>(_u('/messages/$messageId/react'), {'emoji': emoji});

  // ------------------------------------------------------------
  //  کاربران و خلاصه
  // ------------------------------------------------------------
  Future<List<ChatUser>> users({String? search, int take = 200}) async {
    final r = await _api.get<dynamic>(
      _u('/users'),
      query: {
        'take': take,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return rows(r.data).map(ChatUser.fromJson).toList();
  }

  Future<ChatSummary> summary() async {
    final r = await _api.get<dynamic>(_u('/summary'));
    final d = r.data;
    if (d is! Map) return const ChatSummary();
    return ChatSummary.fromJson(Map<String, dynamic>.from(d));
  }

  /// آدرس کامل فایل پیوست (fileUrl نسبی است: /api/chat/messages/12/download)
  ///
  /// اگر مسیر چت روی سرور دیگری باشد (base کامل)، فایل هم از همان سرور
  /// خوانده می‌شود؛ وگرنه روی همان سرور اصلی اپ.
  String fileUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final rel = url.startsWith('/') ? url : '/$url';
    if (_base.startsWith('http://') || _base.startsWith('https://')) {
      final u = Uri.parse(_base);
      return '${u.scheme}://${u.authority}$rel';
    }
    return _api.resolveUrl(rel);
  }
}

class ChatUpload {
  const ChatUpload({
    required this.id,
    required this.fileUrl,
    required this.fileName,
    required this.fileSizeBytes,
    required this.fileContentType,
    required this.messageType,
  });
  final String id;
  final String fileUrl;
  final String fileName;
  final int fileSizeBytes;
  final String fileContentType;
  final int messageType;
}

/// یک کاربر نرم‌افزار برای شروع چت (ChatUserDto)
class ChatUser {
  const ChatUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.department,
    this.isOnline = false,
    this.existingConversationId,
  });

  final int id;
  final String username;
  final String displayName;
  final String? department;
  final bool isOnline;
  final int? existingConversationId;

  String get name => displayName.trim().isNotEmpty ? displayName : username;

  factory ChatUser.fromJson(Map<String, dynamic> j) => ChatUser(
    id: (j['id'] as num?)?.toInt() ?? 0,
    username: (j['username'] ?? j['userName'] ?? '').toString(),
    displayName: (j['displayName'] ?? j['fullName'] ?? '').toString(),
    department: j['department']?.toString(),
    isOnline: j['isOnline'] == true,
    existingConversationId: (j['existingConversationId'] as num?)?.toInt(),
  );
}

/// خلاصهٔ اعلان‌های چت (ChatSummaryDto)
class ChatSummary {
  const ChatSummary({
    this.totalUnreadMessages = 0,
    this.unreadConversationsCount = 0,
  });
  final int totalUnreadMessages;
  final int unreadConversationsCount;

  factory ChatSummary.fromJson(Map<String, dynamic> j) => ChatSummary(
    totalUnreadMessages: (j['totalUnreadMessages'] as num?)?.toInt() ?? 0,
    unreadConversationsCount:
        (j['unreadConversationsCount'] as num?)?.toInt() ?? 0,
  );
}
