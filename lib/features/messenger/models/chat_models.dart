// ============================================================
//  مدل‌های پیام‌رسان سازمانی
//  نگاشت با کلیدهای camelCase و PascalCase (مثل بقیهٔ ماژول‌ها)
// ============================================================

import 'package:flutter/material.dart';

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
DateTime? _d(dynamic v) =>
    DateTime.tryParse(v?.toString() ?? '')?.toLocal();

/// یک گفت‌وگو (چت یک‌به‌یک یا گروه)
class ChatThread {
  const ChatThread({
    required this.id,
    required this.title,
    this.userId,
    this.isGroup = false,
    this.lastMessage,
    this.lastAt,
    this.unread = 0,
    this.online = false,
    this.avatarColor = const Color(0xff2547a8),
    this.type = 1,
    this.lastSender,
    this.pinned = false,
    this.muted = false,
    this.peerUserId,
  });

  final int id;
  final String title;
  final int? userId;
  final bool isGroup;
  final String? lastMessage;
  final DateTime? lastAt;
  final int unread;
  final bool online;
  final Color avatarColor;

  /// نوع گفت‌وگو در سرور (۱ خصوصی، ۲ گروه، ۳ کانال)
  final int type;

  /// آخرین پیام از طرف چه کسی بوده (سرور می‌دهد)
  final String? lastSender;

  /// پیام سنجاق‌شده/سنجاق‌شدن گفت‌وگو
  final bool pinned;
  final bool muted;

  /// شناسهٔ همتای خصوصی (برای باز کردن چت جدید)
  final int? peerUserId;

  String get initials {
    final parts = title.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '؟';
    if (parts.length == 1) {
      return parts.first.characters.first;
    }
    return '${parts.first.characters.first}${parts[1].characters.first}';
  }

  /// ساخت از DTO واقعی سرور (ChatConversationDto)
  factory ChatThread.fromErp(Map<String, dynamic> j) {
    final type = (j['type'] as num?)?.toInt() ?? 1;
    final peerName = (j['directPeerName'] ?? '').toString().trim();
    final groupTitle = (j['title'] ?? '').toString().trim();
    final title = type == 1 && peerName.isNotEmpty
        ? peerName
        : (groupTitle.isNotEmpty ? groupTitle : 'گفت‌وگو');
    return ChatThread(
      id: (j['id'] as num?)?.toInt() ?? 0,
      title: title,
      userId: (j['directPeerUserId'] as num?)?.toInt(),
      peerUserId: (j['directPeerUserId'] as num?)?.toInt(),
      isGroup: type != 1,
      type: type,
      lastMessage: (j['lastMessageSnippet'] ?? j['pinnedMessageSnippet'])
          ?.toString(),
      lastSender: j['lastMessageSenderName']?.toString(),
      lastAt: DateTime.tryParse(
        (j['lastMessageAt'] ?? j['createdAt'] ?? '').toString(),
      )?.toLocal(),
      unread: (j['unreadCount'] as num?)?.toInt() ?? 0,
      online: j['directPeerIsOnline'] == true,
      pinned: j['isPinned'] == true,
      muted: j['isMuted'] == true,
    );
  }

  factory ChatThread.fromJson(Map<String, dynamic> j) {
    final name =
        j['title'] ?? j['Title'] ?? j['name'] ?? j['Name'] ?? j['peerName'] ??
            j['fullName'] ?? 'گفت‌وگو';
    return ChatThread(
      id: _i(j['id'] ?? j['Id'] ?? j['peerUserId'] ?? j['UserId']),
      title: name.toString(),
      userId: (j['peerUserId'] ?? j['UserId'] ?? j['userId'] as num?)?.toInt(),
      isGroup: (j['isGroup'] ?? j['IsGroup']) == true,
      lastMessage: (j['lastMessage'] ?? j['LastMessage'] ?? j['body'])
          ?.toString(),
      lastAt: _d(j['lastAt'] ?? j['LastAt'] ?? j['lastMessageAt'] ?? j['createdAt']),
      unread: _i(j['unread'] ?? j['UnreadCount'] ?? j['unreadCount']),
      online: (j['online'] ?? j['isOnline']) == true,
    );
  }
}

/// نوع محتوای یک پیام
enum ChatKind { text, voice, image, file, system }

/// یک پیام در گفت‌وگو
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.kind,
    this.text,
    this.mine = false,
    this.at,
    this.senderName,
    this.durationSec = 0,
    this.audioUrl,
    this.localPath,
    this.status = ChatStatus.sent,
    this.attachmentName,
    this.messageType = 1,
    this.fileUrl,
    this.senderId,
    this.durationMs = 0,
  });

  final int id;
  final ChatKind kind;
  final String? text;
  final bool mine;
  final DateTime? at;
  final String? senderName;

  /// طول ویس به ثانیه
  final int durationSec;

  /// آدرس فایل ویس روی سرور
  final String? audioUrl;

  /// مسیر فایل ضبط‌شده روی گوشی (قبل از آپلود)
  final String? localPath;

  final ChatStatus status;
  final String? attachmentName;

  /// نوع پیام در سرور: ۱ متن، ۲ تصویر، ۳ فایل، ۴ صدا، ۵ ویدیو، ۶ سیستم
  final int messageType;

  /// آدرس نسبی فایل روی سرور (برای دانلود/پخش)
  final String? fileUrl;

  final int? senderId;

  /// طول ویس بر حسب میلی‌ثانیه (اگر سرور بدهد)
  final int durationMs;

  String get durationLabel {
    final m = durationSec ~/ 60;
    final s = durationSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  factory ChatMessage.fromJson(Map<String, dynamic> j, {int? myUserId}) {
    final type = (j['kind'] ?? j['type'] ?? j['Type'] ?? j['messageType'] ?? '')
        .toString()
        .toLowerCase();
    final kind = type.contains('voice') || type.contains('audio')
        ? ChatKind.voice
        : type.contains('image') || type.contains('photo')
        ? ChatKind.image
        : type.contains('file') || type.contains('doc')
        ? ChatKind.file
        : type.contains('system')
        ? ChatKind.system
        : ChatKind.text;
    final senderId = (j['senderUserId'] ?? j['SenderUserId'] ?? j['userId'] as num?)
        ?.toInt();
    return ChatMessage(
      id: _i(j['id'] ?? j['Id']),
      kind: kind,
      text: (j['text'] ?? j['Text'] ?? j['body'] ?? j['Body'] ?? j['caption'])
          ?.toString(),
      mine: myUserId != null
          ? senderId == myUserId
          : (j['mine'] ?? j['isMine']) == true,
      at: _d(j['at'] ?? j['createdAt'] ?? j['CreatedAt'] ?? j['sentAt']),
      senderName: (j['senderName'] ?? j['SenderName'] ?? j['fromName'])
          ?.toString(),
      durationSec: _i(j['duration'] ?? j['DurationSec'] ?? j['seconds']),
      audioUrl: (j['url'] ?? j['audioUrl'] ?? j['fileUrl'] ?? j['attachmentUrl'])
          ?.toString(),
      attachmentName: (j['fileName'] ?? j['AttachmentName'])?.toString(),
      status: ChatStatus.sent,
    );
  }

  /// ساخت از DTO واقعی سرور (ChatMessageDto)
  factory ChatMessage.fromErp(Map<String, dynamic> j, {int? myUserId}) {
    final type = (j['messageType'] as num?)?.toInt() ?? 1;
    final kind = switch (type) {
      2 => ChatKind.image,
      3 => ChatKind.file,
      4 => ChatKind.voice,
      5 => ChatKind.file,
      6 => ChatKind.system,
      _ => ChatKind.text,
    };
    final senderId = (j['senderUserId'] as num?)?.toInt();
    return ChatMessage(
      id: (j['id'] as num?)?.toInt() ?? 0,
      kind: kind,
      text: j['text']?.toString(),
      mine: senderId != null && myUserId != null
          ? senderId == myUserId
          : j['isOutgoing'] == true,
      at: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal(),
      senderName: j['senderName']?.toString(),
      senderId: senderId,
      messageType: type,
      fileUrl: j['fileUrl']?.toString(),
      audioUrl: type == 4 ? j['fileUrl']?.toString() : null,
      attachmentName: j['fileName']?.toString(),
      status: j['isOutgoing'] == true
          ? (j['isReadByPeer'] == true ? ChatStatus.read : ChatStatus.sent)
          : ChatStatus.sent,
    );
  }

  /// همهٔ آدرس‌های فایل را با یک تابع (ساخت آدرس کامل) بازنویسی می‌کند.
  ChatMessage withUrls(String Function(String) absolute) => ChatMessage(
    id: id,
    kind: kind,
    text: text,
    mine: mine,
    at: at,
    senderName: senderName,
    durationSec: durationSec,
    audioUrl: audioUrl == null ? null : absolute(audioUrl!),
    localPath: localPath,
    status: status,
    attachmentName: attachmentName,
    messageType: messageType,
    fileUrl: fileUrl == null ? null : absolute(fileUrl!),
    senderId: senderId,
    durationMs: durationMs,
  );

  ChatMessage copyWith({ChatStatus? status}) => ChatMessage(
    id: id,
    kind: kind,
    text: text,
    mine: mine,
    at: at,
    senderName: senderName,
    durationSec: durationSec,
    audioUrl: audioUrl,
    localPath: localPath,
    status: status ?? this.status,
    attachmentName: attachmentName,
    messageType: messageType,
    fileUrl: fileUrl,
    senderId: senderId,
    durationMs: durationMs,
  );
}

enum ChatStatus { sending, sent, delivered, read, failed }
