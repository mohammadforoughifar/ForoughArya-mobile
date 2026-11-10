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

  String get initials {
    final parts = title.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '؟';
    if (parts.length == 1) {
      return parts.first.characters.first;
    }
    return '${parts.first.characters.first}${parts[1].characters.first}';
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
  );
}

enum ChatStatus { sending, sent, delivered, read, failed }
