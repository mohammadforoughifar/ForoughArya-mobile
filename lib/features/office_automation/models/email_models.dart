// ============================================================
//  مدل‌های ماژول پست الکترونیک (سازمانی و شخصی)
//  نگاشت دقیق DTOهای سرور (EmailDtos.cs / EmailController.cs)
// ============================================================

import '../../../core/utils/fa.dart';
import 'office_common.dart';

/// نام کارتابل‌های سرور (حساس به مقدار در مسیرهای API)
abstract final class EmailBox {
  static const inbox = 'Inbox';
  static const sent = 'Sent';
  static const junk = 'Junk';

  static String normalize(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    if (s == 'sent') return sent;
    if (s == 'junk' || s == 'spam') return junk;
    return inbox;
  }
}

/// چهار کارتابل یکپارچه مشابه اتوماسیون اداری
enum EmailTab { inbox, sent, archive, draft }

extension EmailTabX on EmailTab {
  String get label => switch (this) {
    EmailTab.inbox => 'دریافتی',
    EmailTab.sent => 'ارسالی',
    EmailTab.archive => 'بایگانی',
    EmailTab.draft => 'پیش‌نویس',
  };

  String get key => name;
}

/// حساب ایمیل ثبت‌شده در سرور (`EmailAccountDto`)
class EmailAccount {
  const EmailAccount({
    required this.id,
    required this.address,
    this.displayName = '',
    this.isDabirkhane = false,
    this.isActive = true,
    this.messageCount = 0,
    this.lastSync,
    this.smtp = '',
    this.smtpPort = 587,
    this.smtpSsl = true,
    this.imap = '',
    this.imapPort = 993,
    this.imapSsl = true,
    this.username = '',
  });

  final int id;
  final String address;
  final String displayName;
  final bool isDabirkhane;
  final bool isActive;
  final int messageCount;
  final DateTime? lastSync;
  final String smtp;
  final int smtpPort;
  final bool smtpSsl;
  final String imap;
  final int imapPort;
  final bool imapSsl;
  final String username;

  String get title => displayName.trim().isNotEmpty ? displayName.trim() : address;

  factory EmailAccount.fromJson(Map<String, dynamic> raw) {
    final j = asMap(raw);
    final addr = pickStr(j, ['emailAddress', 'EmailAddress', 'address']);
    return EmailAccount(
      id: pickInt(j, ['emailId', 'EmailId', 'id', 'Id']),
      address: addr,
      displayName: pickStr(j, ['displayName', 'DisplayName', 'title', 'Title']),
      isDabirkhane: pickBool(j, ['isDabirkhane', 'IsDabirkhane']),
      isActive: pickBool(j, ['isActive', 'IsActive'], true),
      messageCount: pickInt(j, ['messageCount', 'MessageCount']),
      lastSync: pickDate(j, ['lastSync', 'LastSync', 'lastSyncAt']),
      smtp: pickStr(j, ['smtp', 'Smtp', 'smtpHost', 'SmtpHost']),
      smtpPort: pickInt(j, ['smtpPort', 'SmtpPort'], 587),
      smtpSsl: pickBool(j, ['smtpSsl', 'SmtpSsl', 'useSsl'], true),
      imap: pickStr(j, ['imap', 'Imap', 'imapHost', 'ImapHost']),
      imapPort: pickInt(j, ['imapPort', 'ImapPort'], 993),
      imapSsl: pickBool(j, ['imapSsl', 'ImapSsl'], true),
      username: pickStr(j, ['username', 'Username', 'userName'], addr),
    );
  }

  Map<String, dynamic> toSavePayload({String? password}) => {
    if (id > 0) 'emailId': id,
    'emailAddress': address.trim(),
    'displayName': displayName.trim(),
    'isDabirkhane': isDabirkhane,
    'isActive': isActive,
    'smtp': smtp.trim(),
    'smtpPort': smtpPort,
    'smtpSsl': smtpSsl,
    'imap': imap.trim(),
    'imapPort': imapPort,
    'imapSsl': imapSsl,
    'username': username.trim().isEmpty ? address.trim() : username.trim(),
    if (password != null && password.isNotEmpty) 'password': password,
  };
}

/// آیتم فهرست ایمیل‌ها (`EmailListItemDto`)
class EmailMessage {
  const EmailMessage({
    required this.id,
    required this.box,
    required this.accountId,
    required this.accountAddress,
    required this.fromOrTo,
    required this.subject,
    required this.date,
    this.isRead = true,
    this.isNeshan = false,
    this.hasAttachment = false,
    this.folderId = 0,
    this.folderTitle,
    this.isSpam = false,
  });

  final int id;
  final String box;
  final int accountId;
  final String accountAddress;
  final String fromOrTo;
  final String subject;
  final DateTime? date;
  final bool isRead;
  final bool isNeshan;
  final bool hasAttachment;
  final int folderId;
  final String? folderTitle;
  final bool isSpam;

  bool get isArchived => folderId > 0 || (folderTitle != null && folderTitle!.isNotEmpty);

  EmailMessage copyWith({
    bool? isRead,
    bool? isNeshan,
    int? folderId,
    String? folderTitle,
    bool? isSpam,
  }) => EmailMessage(
    id: id,
    box: box,
    accountId: accountId,
    accountAddress: accountAddress,
    fromOrTo: fromOrTo,
    subject: subject,
    date: date,
    isRead: isRead ?? this.isRead,
    isNeshan: isNeshan ?? this.isNeshan,
    hasAttachment: hasAttachment,
    folderId: folderId ?? this.folderId,
    folderTitle: folderTitle ?? this.folderTitle,
    isSpam: isSpam ?? this.isSpam,
  );

  factory EmailMessage.fromJson(Map<String, dynamic> raw) {
    final j = asMap(raw);
    final rawSub = pickStr(j, ['subject', 'Subject']).trim();
    final inFolderVal = pick(j, ['isInFolder', 'IsInFolder', 'folderId', 'FolderId']);
    final folderId = switch (inFolderVal) {
      final num n => n.toInt(),
      final bool b => b ? 1 : 0,
      final String s => int.tryParse(s) ?? (s.toLowerCase() == 'true' ? 1 : 0),
      _ => 0,
    };
    return EmailMessage(
      id: pickInt(j, ['id', 'Id', 'messageId', 'MessageId']),
      box: EmailBox.normalize(pickStrN(j, ['box', 'Box'])),
      accountId: pickInt(j, ['emailId', 'EmailId', 'accountId']),
      accountAddress: pickStr(j, ['accountAddress', 'AccountAddress', 'emailAddress']),
      fromOrTo: pickStr(j, ['fromOrTo', 'FromOrTo', 'from', 'From', 'to', 'To']),
      subject: rawSub.isEmpty ? '(بدون موضوع)' : rawSub,
      date: pickDate(j, ['date', 'Date', 'sentAt', 'receivedAt']),
      isRead: pickBool(j, ['isRead', 'IsRead'], true),
      isNeshan: pickBool(j, ['isNeshan', 'IsNeshan', 'starred', 'isStarred']),
      hasAttachment: pickBool(j, ['isAttachment', 'IsAttachment', 'hasAttachment']),
      folderId: folderId,
      folderTitle: pickStrN(j, ['folderTitle', 'FolderTitle']),
      isSpam: pickBool(j, ['isSpam', 'IsSpam']),
    );
  }
}

/// پاسخ صفحه‌بندی‌شدهٔ ایمیل‌ها (`EmailListPageDto`)
class EmailListResult {
  const EmailListResult({
    required this.items,
    required this.totalCount,
    this.unreadCount = 0,
    this.spamCount = 0,
    this.page = 1,
    this.pageSize = 25,
  });

  final List<EmailMessage> items;
  final int totalCount;
  final int unreadCount;
  final int spamCount;
  final int page;
  final int pageSize;

  bool get hasNext => page * pageSize < totalCount;

  factory EmailListResult.fromJson(dynamic raw) {
    if (raw is List) {
      final list = raw.whereType<Map>().map((e) => EmailMessage.fromJson(asMap(e))).toList();
      return EmailListResult(
        items: list,
        totalCount: list.length,
        unreadCount: list.where((m) => !m.isRead).length,
        pageSize: list.isEmpty ? 25 : list.length,
      );
    }
    final j = asMap(raw);
    final items = pickList(j, ['items', 'Items', 'data', 'Data'], EmailMessage.fromJson);
    return EmailListResult(
      items: items,
      totalCount: pickInt(j, ['totalCount', 'TotalCount', 'total', 'Total'], items.length),
      unreadCount: pickInt(j, ['unreadCount', 'UnreadCount']),
      spamCount: pickInt(j, ['spamCount', 'SpamCount']),
      page: pickInt(j, ['page', 'Page'], 1),
      pageSize: pickInt(j, ['pageSize', 'PageSize'], 25),
    );
  }
}

/// پیوست ایمیل (`EmailAttachmentDto`)
class EmailAttachment {
  const EmailAttachment({
    required this.id,
    required this.name,
    this.size = 0,
    this.contentType = '',
  });

  final int id;
  final String name;
  final int size;
  final String contentType;

  String get sizeLabel {
    if (size <= 0) return '';
    if (size < 1024) return '${Fa.digits(size)} بایت';
    if (size < 1024 * 1024) {
      final kb = (size / 1024).round();
      return '${Fa.digits(kb)} کیلوبایت';
    }
    final mb = (size / (1024 * 1024)).toStringAsFixed(1);
    return '${Fa.digits(mb)} مگابایت';
  }

  factory EmailAttachment.fromJson(Map<String, dynamic> raw) {
    final j = asMap(raw);
    final n = pickStr(j, ['realName', 'RealName', 'fileName', 'FileName', 'name', 'Name']);
    return EmailAttachment(
      id: pickInt(j, ['attachmentId', 'AttachmentId', 'id', 'Id']),
      name: n.isEmpty ? 'attachment' : n,
      size: pickInt(j, ['size', 'Size', 'fileSize', 'FileSize']),
      contentType: pickStr(j, ['contentType', 'ContentType', 'mimeType']),
    );
  }
}

/// جزئیات کامل ایمیل (`EmailMessageDetailDto`)
class EmailMessageDetail {
  const EmailMessageDetail({
    required this.id,
    required this.box,
    required this.accountId,
    required this.accountAddress,
    required this.fromOrTo,
    this.to = '',
    this.cc = '',
    required this.subject,
    required this.body,
    this.date,
    this.isRead = true,
    this.isNeshan = false,
    this.isSpam = false,
    this.folderId = 0,
    this.folderTitle,
    this.attachments = const [],
  });

  final int id;
  final String box;
  final int accountId;
  final String accountAddress;
  final String fromOrTo;
  final String to;
  final String cc;
  final String subject;
  final String body;
  final DateTime? date;
  final bool isRead;
  final bool isNeshan;
  final bool isSpam;
  final int folderId;
  final String? folderTitle;
  final List<EmailAttachment> attachments;

  String get replyAddress => extractAddress(fromOrTo);

  String get plainBody => htmlToPlain(body);

  factory EmailMessageDetail.fromJson(Map<String, dynamic> raw) {
    final j = asMap(raw);
    final rawSub = pickStr(j, ['subject', 'Subject']).trim();
    final inFolderVal = pick(j, ['isInFolder', 'IsInFolder', 'folderId', 'FolderId']);
    final folderId = switch (inFolderVal) {
      final num n => n.toInt(),
      final bool b => b ? 1 : 0,
      final String s => int.tryParse(s) ?? 0,
      _ => 0,
    };
    return EmailMessageDetail(
      id: pickInt(j, ['id', 'Id', 'messageId', 'MessageId']),
      box: EmailBox.normalize(pickStrN(j, ['box', 'Box'])),
      accountId: pickInt(j, ['emailId', 'EmailId', 'accountId']),
      accountAddress: pickStr(j, ['accountAddress', 'AccountAddress', 'emailAddress']),
      fromOrTo: pickStr(j, ['fromOrTo', 'FromOrTo', 'from', 'From']),
      to: pickStr(j, ['to', 'To', 'recipients']),
      cc: pickStr(j, ['cc', 'Cc']),
      subject: rawSub.isEmpty ? '(بدون موضوع)' : rawSub,
      body: pickStr(j, ['body', 'Body', 'htmlBody', 'HtmlBody', 'textBody']),
      date: pickDate(j, ['date', 'Date']),
      isRead: pickBool(j, ['isRead', 'IsRead'], true),
      isNeshan: pickBool(j, ['isNeshan', 'IsNeshan']),
      isSpam: pickBool(j, ['isSpam', 'IsSpam']),
      folderId: folderId,
      folderTitle: pickStrN(j, ['folderTitle', 'FolderTitle']),
      attachments: pickList(j, ['attachments', 'Attachments'], EmailAttachment.fromJson),
    );
  }
}

/// پوشهٔ بایگانی ایمیل (`EmailFolderDto`)
class EmailFolder {
  const EmailFolder({
    required this.id,
    required this.title,
    this.count = 0,
  });

  final int id;
  final String title;
  final int count;

  factory EmailFolder.fromJson(Map<String, dynamic> raw) {
    final j = asMap(raw);
    return EmailFolder(
      id: pickInt(j, ['folderId', 'FolderId', 'id', 'Id']),
      title: pickStr(j, ['title', 'Title', 'folderTitle', 'name', 'Name']),
      count: pickInt(j, ['count', 'Count', 'messageCount']),
    );
  }
}

/// پیش‌نویس محلی ایمیل
class EmailDraft {
  const EmailDraft({
    required this.localId,
    required this.accountId,
    this.to = '',
    this.cc = '',
    this.subject = '',
    this.body = '',
    this.createdAt,
  });

  final String localId;
  final int accountId;
  final String to;
  final String cc;
  final String subject;
  final String body;
  final DateTime? createdAt;

  factory EmailDraft.fromJson(Map<String, dynamic> raw) {
    final j = asMap(raw);
    return EmailDraft(
      localId: pickStr(j, ['localId', 'id']),
      accountId: pickInt(j, ['accountId', 'emailId']),
      to: pickStr(j, ['to']),
      cc: pickStr(j, ['cc']),
      subject: pickStr(j, ['subject']),
      body: pickStr(j, ['body']),
      createdAt: pickDate(j, ['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'accountId': accountId,
    'to': to,
    'cc': cc,
    'subject': subject,
    'body': body,
    'createdAt': createdAt?.toIso8601String(),
  };
}

/// نتیجهٔ همگام‌سازی حساب (`SyncResultDto`)
class EmailSyncResult {
  const EmailSyncResult({this.message = '', this.newCount = 0});
  final String message;
  final int newCount;

  factory EmailSyncResult.fromJson(dynamic raw) {
    final j = asMap(raw);
    return EmailSyncResult(
      message: pickStr(j, ['message', 'Message']),
      newCount: pickInt(j, ['newCount', 'NewCount', 'added', 'count']),
    );
  }
}

/// نتیجهٔ تست اتصال SMTP/IMAP
class EmailTestResult {
  const EmailTestResult({
    required this.smtpOk,
    required this.imapOk,
    this.message = '',
  });

  final bool smtpOk;
  final bool imapOk;
  final String message;

  bool get allOk => smtpOk && imapOk;

  factory EmailTestResult.fromJson(dynamic raw) {
    final j = asMap(raw);
    return EmailTestResult(
      smtpOk: pickBool(j, ['smtpOk', 'SmtpOk']),
      imapOk: pickBool(j, ['imapOk', 'ImapOk']),
      message: pickStr(j, ['message', 'Message']),
    );
  }
}

// ============================================================
//  توابع کمکی پردازش متن و آدرس ایمیل
// ============================================================

/// آیا رشته شامل تگ HTML است؟ (خروجی ادیتور وب)
bool isHtmlLike(String raw) =>
    RegExp(r'<\s*/?\s*(p|div|br|span|b|i|u|strong|em|ul|ol|li|table|tr|td|h[1-6]|a|img|font)\b',
            caseSensitive: false)
        .hasMatch(raw);

/// تبدیل HTML ایمیل به متن تمیز و خوانای فارسی/انگلیسی
String htmlToPlain(String raw) {
  if (raw.isEmpty) return '';
  var s = raw;
  // حذف بلاک‌های style / script / head
  s = s.replaceAll(
    RegExp(r'<(style|script|head)[^>]*>[\s\S]*?</\1>', caseSensitive: false),
    '',
  );
  s = s.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
  // تگ‌های ساختاری → شکست خط یا بولت
  s = s.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '\n• ');
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(
    RegExp(r'</(p|div|tr|h[1-6]|blockquote|ul|ol|table|li)>', caseSensitive: false),
    '\n',
  );
  s = s.replaceAll(RegExp(r'</t[dh]>', caseSensitive: false), '\t');
  // حذف سایر تگ‌ها
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  // رمزگشایی موجودیت‌های رایج و عددی
  s = _decodeHtmlEntities(s);
  // یکدست‌سازی خطوط خالی
  final lines = s.split(RegExp(r'\r?\n')).map((l) => l.trimRight()).toList();
  final out = <String>[];
  var blankCount = 0;
  for (final l in lines) {
    if (l.trim().isEmpty) {
      blankCount++;
      if (blankCount <= 1 && out.isNotEmpty) out.add('');
    } else {
      blankCount = 0;
      out.add(l);
    }
  }
  return out.join('\n').trim();
}

String _decodeHtmlEntities(String input) {
  var s = input
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&zwnj;', '\u200c')
      .replaceAll('&zwj;', '\u200d')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&rlm;', '\u200f')
      .replaceAll('&lrm;', '\u200e');
  s = s.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    final code = int.tryParse(m.group(1) ?? '');
    return code != null ? String.fromCharCode(code) : m.group(0)!;
  });
  s = s.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
    final code = int.tryParse(m.group(1) ?? '', radix: 16);
    return code != null ? String.fromCharCode(code) : m.group(0)!;
  });
  return s;
}

/// استخراج آدرس ایمیل از رشته‌هایی مانند `علی رضایی <ali@test.ir>`
String extractAddress(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return '';
  final angle = RegExp(r'<([^<>@\s]+@[^<>@\s]+)>').firstMatch(t);
  if (angle != null) return angle.group(1)!.trim();
  final plain = RegExp(r'[^\s<>@,;]+@[^\s<>@,;]+').firstMatch(t);
  if (plain != null) return plain.group(0)!.trim();
  return t;
}

/// موضوع پاسخ بدون تکرار `Re:`
String replySubject(String subject) {
  final s = subject.trim();
  if (s.isEmpty) return 'Re:';
  if (RegExp(r'^re\s*:', caseSensitive: false).hasMatch(s)) return s;
  return 'Re: $s';
}

/// موضوع ارجاع بدون تکرار `Fwd:`
String forwardSubject(String subject) {
  final s = subject.trim();
  if (s.isEmpty) return 'Fwd:';
  if (RegExp(r'^(fwd|fw)\s*:', caseSensitive: false).hasMatch(s)) return s;
  return 'Fwd: $s';
}

/// ساخت متن نقل‌قول‌شده برای پاسخ/ارجاع
String quotedBody(EmailMessageDetail d) {
  final plain = d.plainBody;
  final quotedLines = plain
      .split('\n')
      .map((l) => '> $l')
      .join('\n');
  final who = d.fromOrTo.trim().isEmpty ? d.accountAddress : d.fromOrTo.trim();
  return '\n\n--- $who نوشت: ---\n$quotedLines';
}
