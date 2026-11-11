// ============================================================
//  ماژول اتوماسیون اداری — مدل‌های مشترک
//  نگاشت مستقیم DTOهای بک‌اند (Inventory.Shared.Dtos) به Dart
//  منبع: TotallCollectionSoftware/src/Inventory.Shared/Dtos/LetterDtos.cs
//         TotallCollectionSoftware/src/Inventory.Shared/Dtos/OutgoingLetterDtos.cs
// ============================================================

/// خواندن امن از Map با کلیدهای مختلف (سرور گاهی PascalCase می‌فرستد).
Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

dynamic pick(Map<String, dynamic> j, List<String> keys) {
  for (final k in keys) {
    if (j.containsKey(k) && j[k] != null) return j[k];
  }
  // جست‌وجوی حساس‌نبودن به بزرگی/کوچکی حرف اول
  final lower = {for (final e in j.entries) e.key.toLowerCase(): e.value};
  for (final k in keys) {
    final v = lower[k.toLowerCase()];
    if (v != null) return v;
  }
  return null;
}

String pickStr(Map<String, dynamic> j, List<String> keys, [String def = '']) =>
    pick(j, keys)?.toString() ?? def;

String? pickStrN(Map<String, dynamic> j, List<String> keys) {
  final v = pick(j, keys)?.toString();
  return (v == null || v.isEmpty) ? null : v;
}

int pickInt(Map<String, dynamic> j, List<String> keys, [int def = 0]) {
  final v = pick(j, keys);
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? def;
}

int? pickIntN(Map<String, dynamic> j, List<String> keys) {
  final v = pick(j, keys);
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '');
}

bool pickBool(Map<String, dynamic> j, List<String> keys, [bool def = false]) {
  final v = pick(j, keys);
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v?.toString().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return def;
}

DateTime? pickDate(Map<String, dynamic> j, List<String> keys) {
  final v = pick(j, keys)?.toString();
  return (v == null || v.isEmpty) ? null : DateTime.tryParse(v);
}

List<T> pickList<T>(
  Map<String, dynamic> j,
  List<String> keys,
  T Function(Map<String, dynamic>) build,
) {
  final raw = pick(j, keys);
  if (raw is! List) return <T>[];
  return raw.whereType<Map>().map((e) => build(asMap(e))).toList();
}

/// پاسخ صفحه‌بندی‌شدهٔ سرور.
/// قرارداد بک‌اند (Services/Paging.cs):
///  • بدون skip/take → آرایهٔ ساده
///  • با skip/take   → { total, items }
///  • مسیرهای قدیمی  → { items, totalCount, page, pageSize }
class Paged<T> {
  const Paged({
    required this.items,
    this.totalCount = 0,
    this.page = 1,
    this.pageSize = 20,
  });

  final List<T> items;
  final int totalCount;
  final int page;
  final int pageSize;

  int get pageCount =>
      pageSize <= 0 ? 1 : (totalCount / pageSize).ceil().clamp(1, 99999);
  bool get hasNext => page < pageCount;

  factory Paged.fromJson(
    dynamic data,
    T Function(Map<String, dynamic>) build,
  ) {
    if (data is List) {
      final items = data.whereType<Map>().map((e) => build(asMap(e))).toList();
      return Paged<T>(items: items, totalCount: items.length, pageSize: items.isEmpty ? 20 : items.length);
    }
    final j = asMap(data);
    final rawItems = pick(j, ['items', 'Items', 'data']);
    final items = rawItems is List
        ? rawItems.whereType<Map>().map((e) => build(asMap(e))).toList()
        : <T>[];
    return Paged<T>(
      items: items,
      totalCount: pickInt(j, ['totalCount', 'TotalCount', 'total', 'Total', 'count']),
      page: pickInt(j, ['page', 'Page'], 1),
      pageSize: pickInt(j, ['pageSize', 'PageSize'], 20),
    );
  }
}

/// گیرنده (کاربر/سمت) — معادل LetterReciverDto
class LetterRecipient {
  const LetterRecipient({
    required this.userId,
    required this.fullName,
    this.sematId,
    this.sematTitle,
    this.positions = const [],
  });

  final int userId;
  final String fullName;
  final int? sematId;
  final String? sematTitle;
  final List<String> positions;

  String get label => fullName.isEmpty ? 'کاربر $userId' : fullName;

  factory LetterRecipient.fromJson(Map<String, dynamic> j) => LetterRecipient(
    userId: pickInt(j, ['userId', 'UserId', 'id', 'Id']),
    fullName: pickStr(j, ['fullName', 'FullName', 'name', 'Name', 'displayName']),
    sematId: pickIntN(j, ['sematId', 'SematId']),
    sematTitle: pickStrN(j, ['sematTitle', 'SematTitle']),
    positions: (pick(j, ['positions', 'Positions']) as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
  );

  @override
  bool operator ==(Object other) =>
      other is LetterRecipient && other.userId == userId;
  @override
  int get hashCode => userId;
}

/// گروه گیرندگان — معادل LetterGroupDto
class LetterGroup {
  const LetterGroup({
    required this.groupId,
    required this.name,
    this.memberCount = 0,
    this.active = true,
    this.members = const [],
  });

  final int groupId;
  final String name;
  final int memberCount;
  final bool active;
  final List<LetterRecipient> members;

  factory LetterGroup.fromJson(Map<String, dynamic> j) => LetterGroup(
    groupId: pickInt(j, ['groupId', 'GroupId', 'id', 'Id']),
    name: pickStr(j, ['nameGroup', 'NameGroup', 'name', 'Name']),
    memberCount: pickInt(j, ['memberCount', 'MemberCount']),
    active: pickBool(j, ['condition', 'Condition'], true),
    members: pickList(j, ['members', 'Members'], LetterRecipient.fromJson),
  );
}

/// عملگر ارجاع («جهت اطلاع»، «جهت اقدام»، ...) — معادل Amalgar
class Amalgar {
  const Amalgar({required this.id, required this.title, this.requiresSign = false});

  final int id;
  final String title;
  final bool requiresSign;

  factory Amalgar.fromJson(Map<String, dynamic> j) => Amalgar(
    id: pickInt(j, ['amalgarId', 'AmalgarId', 'id', 'Id']),
    title: pickStr(j, ['title', 'Title'], 'جهت اطلاع'),
    requiresSign: pickStr(j, ['taeedEmza', 'TaeedEmza']).isNotEmpty,
  );
}

/// گره درخت گردش نامه — معادل ErjaTreeNodeDto
class GardeshNode {
  const GardeshNode({
    required this.erjaId,
    required this.sender,
    required this.receiver,
    required this.type,
    required this.matnErja,
    required this.isRead,
    required this.date,
    this.amalgarTitle,
    this.typeTaeed = 0,
    this.answer = '',
    this.dateRead,
    this.dateAnswer,
    this.deadline,
    this.showForAll = false,
    this.children = const [],
  });

  final int erjaId;
  final String sender;
  final String receiver;
  final String type;
  final String matnErja;
  final bool isRead;
  final DateTime? date;
  final String? amalgarTitle;
  final int typeTaeed;
  final String answer;
  final DateTime? dateRead;
  final DateTime? dateAnswer;
  final DateTime? deadline;
  final bool showForAll;
  final List<GardeshNode> children;

  factory GardeshNode.fromJson(Map<String, dynamic> j) => GardeshNode(
    erjaId: pickInt(j, ['erjaId', 'ErjaId']),
    sender: pickStr(j, ['sender', 'Sender', 'senderName', 'SenderName']),
    receiver: pickStr(j, ['reciver', 'Reciver', 'receiverName', 'ReceiverName']),
    type: pickStr(j, ['type', 'Type'], 'گیرنده'),
    matnErja: pickStr(j, ['matnErja', 'MatnErja']),
    isRead: pickBool(j, ['isRead', 'IsRead']),
    date: pickDate(j, ['date', 'Date']),
    amalgarTitle: pickStrN(j, ['amalgarTitle', 'AmalgarTitle']),
    typeTaeed: pickInt(j, ['typeTaeed', 'TypeTaeed']),
    answer: pickStr(j, ['answer', 'Answer', 'matnPasokh', 'MatnPasokh']),
    dateRead: pickDate(j, ['dateRead', 'DateRead']),
    dateAnswer: pickDate(j, ['dateAnswer', 'DateAnswer', 'datePasokh']),
    deadline: pickDate(j, ['mohlatPasokh', 'MohlatPasokh', 'deadlineAnswer']),
    showForAll: pickBool(j, ['showForAll', 'ShowForAll']),
    children: pickList(j, ['children', 'Children'], GardeshNode.fromJson),
  );
}

/// نامهٔ مرتبط — عطف (2) / پیرو (1)
class RelatedLetter {
  const RelatedLetter({
    required this.kind,
    required this.letterId,
    this.number = '',
    this.title = '',
    this.isSent = true,
  });

  /// 1 = پیرو، 2 = عطف
  final int kind;
  final int letterId;
  final String number;
  final String title;

  /// true = نامهٔ ارسالیِ کاربر جاری، false = دریافتی
  final bool isSent;

  String get kindLabel => kind == 2 ? 'عطف' : 'پیرو';

  factory RelatedLetter.fromJson(Map<String, dynamic> j) => RelatedLetter(
    kind: pickInt(j, ['related', 'Related'], 1),
    letterId: pickInt(j, ['relateLetterId', 'RelateLetterId', 'id', 'Id']),
    number: pickStr(j, ['relateLetterNumber', 'RelateLetterNumber']),
    title: pickStr(j, ['relateLetterTitle', 'RelateLetterTitle']),
    isSent: pickBool(j, ['isSent', 'IsSent'], true),
  );

  Map<String, dynamic> toJson() => {
    'related': kind,
    'relateLetterId': letterId,
    'relateLetterNumber': number,
    'relateLetterTitle': title,
    'isSent': isSent,
  };
}

/// پیوست نامه — معادل LetterAttachmentDto
class LetterAttachment {
  const LetterAttachment({
    required this.id,
    required this.fileName,
    this.contentType = '',
    this.size = 0,
    this.uploaderName = '',
    this.uploadedAt,
  });

  final int id;
  final String fileName;
  final String contentType;
  final int size;
  final String uploaderName;
  final DateTime? uploadedAt;

  factory LetterAttachment.fromJson(Map<String, dynamic> j) => LetterAttachment(
    id: pickInt(j, ['id', 'Id', 'attachmentId', 'AttachmentId']),
    fileName: pickStr(j, ['fileName', 'FileName'], 'فایل'),
    contentType: pickStr(j, ['contentType', 'ContentType']),
    size: pickInt(j, ['size', 'Size', 'fileSize', 'FileSize']),
    uploaderName: pickStr(j, ['uploaderName', 'UploaderName']),
    uploadedAt: pickDate(j, ['uploadedAt', 'UploadedAt', 'uploadDate']),
  );
}

/// گره درخت بایگانی — معادل BayeganiNodeDto
class ArchiveNode {
  const ArchiveNode({
    required this.id,
    required this.title,
    required this.parentId,
    required this.isFolder,
    this.erjaId,
    this.letterId,
    this.letterNumber,
    this.sender,
    this.date,
    this.foriat,
    this.mahramanegi,
    this.hasAttachment = false,
    this.sourceType = 1,
    this.receiverOrganization,
    this.sadereNumber,
    this.sendMethod,
    this.children = const [],
  });

  final int id;
  final String title;
  final int parentId;
  final bool isFolder;

  /// تعداد نامه‌های داخل پوشه (اگر سرور بدهد)
  int get letterCount => _letterCount;
  int get _letterCount {
    var n = children.where((c) => !c.isFolder).length;
    for (final c in children.where((c) => c.isFolder)) {
      n += c.letterCount;
    }
    return n;
  }
  final int? erjaId;
  final int? letterId;
  final String? letterNumber;
  final String? sender;
  final DateTime? date;
  final String? foriat;
  final String? mahramanegi;
  final bool hasAttachment;
  final int sourceType;
  final String? receiverOrganization;
  final String? sadereNumber;
  final String? sendMethod;
  final List<ArchiveNode> children;

  factory ArchiveNode.fromJson(Map<String, dynamic> j) => ArchiveNode(
    id: pickInt(j, ['bayeganiId', 'BayeganiId', 'id', 'Id']),
    title: pickStr(j, ['title', 'Title']),
    parentId: pickInt(j, ['parentId', 'ParentId']),
    isFolder: pickBool(j, ['isFolder', 'IsFolder']),
    erjaId: pickIntN(j, ['erjaId', 'ErjaId']),
    letterId: pickIntN(j, ['letterId', 'LetterId']),
    letterNumber: pickStrN(j, ['letterNumber', 'LetterNumber']),
    sender: pickStrN(j, ['sender', 'Sender']),
    date: pickDate(j, ['date', 'Date']),
    foriat: pickStrN(j, ['foriat', 'Foriat']),
    mahramanegi: pickStrN(j, ['mahramanegi', 'Mahramanegi']),
    hasAttachment: pickBool(j, ['hasAttachment', 'HasAttachment']),
    sourceType: pickInt(j, ['sourceType', 'SourceType'], 1),
    receiverOrganization:
        pickStrN(j, ['receiverOrganization', 'ReceiverOrganization']),
    sadereNumber: pickStrN(j, ['sadereNumber', 'SadereNumber']),
    sendMethod: pickStrN(j, ['sendMethod', 'SendMethod']),
    children: pickList(j, ['children', 'Children'], ArchiveNode.fromJson),
  );
}

/// شمارنده‌های داشبورد (از /stats هر سه کارتابل جمع می‌شود)
class AutomationStats {
  const AutomationStats({
    this.inbox = 0,
    this.inboxUnread = 0,
    this.sent = 0,
    this.archive = 0,
    this.pishnevis = 0,
    this.neshan = 0,
    this.dabirkhane = 0,
    this.signingPending = 0,
  });

  final int inbox, inboxUnread, sent, archive, pishnevis, neshan;
  final int dabirkhane, signingPending;

  AutomationStats merge(InboxStats other) => AutomationStats(
    inbox: inbox + other.inbox,
    inboxUnread: inboxUnread + other.unread,
    sent: sent + other.sent,
    archive: archive + other.archive,
    pishnevis: pishnevis + other.pishnevis,
    neshan: neshan + other.neshan,
    dabirkhane: dabirkhane + other.dabirkhane,
    signingPending: signingPending + other.signingPending,
  );
}

/// آمار تفکیکی هر ماژول — برای نمایش عدد کنار هر کارتابل در داشبورد
class ModuleMailboxCounts {
  const ModuleMailboxCounts({
    this.inbox = 0,
    this.sent = 0,
    this.drafts = 0,
    this.archive = 0,
    this.signing = 0,
    this.dabirkhane = 0,
    this.unread = 0,
  });

  final int inbox, sent, drafts, archive, signing, dabirkhane, unread;

  /// شمارنده‌ای که مقدارش از سمت «آمار» نیامده قابل تشخیص نیست،
  /// پس نبودِ هر خانه یعنی صفر.
  ModuleMailboxCounts copyWith({
    int? inbox,
    int? sent,
    int? drafts,
    int? archive,
    int? signing,
    int? dabirkhane,
    int? unread,
  }) => ModuleMailboxCounts(
    inbox: inbox ?? this.inbox,
    sent: sent ?? this.sent,
    drafts: drafts ?? this.drafts,
    archive: archive ?? this.archive,
    signing: signing ?? this.signing,
    dabirkhane: dabirkhane ?? this.dabirkhane,
    unread: unread ?? this.unread,
  );

  bool get isEmpty =>
      inbox == 0 &&
      sent == 0 &&
      drafts == 0 &&
      archive == 0 &&
      signing == 0 &&
      dabirkhane == 0;

  factory ModuleMailboxCounts.fromStats(InboxStats s) => ModuleMailboxCounts(
    inbox: s.inbox,
    sent: s.sent,
    drafts: s.pishnevis,
    archive: s.archive,
    signing: s.signingPending,
    dabirkhane: s.dabirkhane,
    unread: s.unread,
  );
}

/// آمار یک کارتابل — پاسخ GET /stats
class InboxStats {
  const InboxStats({
    this.inbox = 0,
    this.unread = 0,
    this.sent = 0,
    this.archive = 0,
    this.pishnevis = 0,
    this.neshan = 0,
    this.dabirkhane = 0,
    this.signingPending = 0,
  });

  final int inbox, unread, sent, archive, pishnevis, neshan;
  final int dabirkhane, signingPending;

  factory InboxStats.fromJson(Map<String, dynamic> j) => InboxStats(
    inbox: pickInt(j, ['inbox', 'Inbox', 'inboxCount', 'recived', 'recieved']),
    unread: pickInt(j, ['unread', 'Unread', 'unreadCount', 'notRead']),
    sent: pickInt(j, ['sent', 'Sent', 'sentCount', 'outbox']),
    archive: pickInt(j, ['archive', 'Archive', 'archiveCount', 'bayegani']),
    pishnevis: pickInt(j, ['pishnevis', 'Pishnevis', 'draft', 'draftCount']),
    neshan: pickInt(j, ['neshan', 'Neshan', 'starred', 'starredCount']),
    dabirkhane: pickInt(j, ['dabirkhane', 'Dabirkhane']),
    signingPending: pickInt(j, ['signingPending', 'pendingSign', 'unsigned']),
  );
}

/// ثابت‌های دامنه — عیناً مطابق مقادیر بک‌اند
class OfficeConst {
  static const sourceInner = 1;
  static const sourceOutgoing = 2;
  static const sourceIncoming = 3;

  static const mahramanegi = ['عادی', 'محرمانه', 'سری'];
  static const foriat = ['عادی', 'فوری', 'آنی'];

  /// روش ارسال دبیرخانه — مطابق OutgoingLetter.SendMethod
  static const sendMethods = [
    'پست',
    'پست پیشتاز',
    'پیک',
    'تحویل حضوری',
    'ایمیل',
    'فکس',
    'اتوماسیون',
  ];

  /// وضعیت نامه صادره — OutgoingLetter.Status
  static const outgoingStatus = [
    'پیش‌نویس داخلی',
    'در گردش تأیید',
    'تأیید شده',
    'صادر شده',
  ];

  /// نوع ارجاع — Erja.Type
  static const erjaTypes = ['گیرنده', 'ارجاع', 'هامش'];

  /// وضعیت تأیید — Erja.TypeTaeed
  static const taeedLabels = ['بدون اقدام', 'تأیید', 'رد'];
}

/// مجوزهای RBAC — لایهٔ AuthSession.has() آن‌ها را چک می‌کند
class OfficePerm {
  static const innerRead = 'InnerLetters.Read';
  static const innerCreate = 'InnerLetters.Create';
  static const outgoingRead = 'OutgoingLetters.Read';
  static const outgoingCreate = 'OutgoingLetters.Create';
  static const outgoingSign = 'OutgoingLetters.Sign';
  static const incomingRead = 'IncomingLetters.Read';
  static const incomingCreate = 'IncomingLetters.Create';
  static const dabirkhane = 'OutgoingLetters.Dabirkhane';
}
