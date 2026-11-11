// ============================================================
//  مدل‌های «آرشیو اسناد و مدارک» — فاز ۹-ح (بخش ۱: کاوشگر و کارتابل)
//  منبع: Inventory.Shared/Dtos/DocArchiveDtos.cs + DocEvolutionDtos.cs
//        Inventory.Api/Controllers/DocArchive/*
//        Inventory.Client/Pages/DocArchive/{DocArchiveExplorer,DocCartable,DocumentFormModal}.razor
//
//  سطوح دسترسی (DocAccessLevelDto): 0 ندارد · 1 مشاهده · 2 خواندن · 3 نوشتن · 4 کامل
//  وضعیت نسخه (DocVersionStatusDto): 0 پیش‌نویس · 1 در گردش · 2 تایید‌شده · 3 رد‌شده · 4 بایگانی
// ============================================================

import '../../../core/utils/fa.dart';

int _i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
int? _ni(Object? v) {
  if (v == null) return null;
  final n = v is num ? v.toInt() : int.tryParse('$v');
  return n;
}
bool _b(Object? v) => v == true || v == 1 || '$v'.toLowerCase() == 'true';
String _s(Object? v) => v == null ? '' : '$v';
String? _ns(Object? v) {
  final s = _s(v).trim();
  return s.isEmpty ? null : s;
}
DateTime? _d(Object? v) => Fa.parseServerDate(v);
List<Map<String, dynamic>> _rows(Object? v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];

// ============================================================
//  سطح دسترسی — همان متن‌های وب
// ============================================================

class DocLevel {
  static const none = 0;
  static const view = 1;
  static const read = 2;
  static const write = 3;
  static const full = 4;

  static String name(int level) => switch (level) {
    1 => 'مشاهده',
    2 => 'خواندن',
    3 => 'نوشتن',
    4 => 'کامل',
    _ => 'ندارد',
  };

  static const List<MapEntry<int, String>> options = [
    MapEntry(1, 'مشاهده'),
    MapEntry(2, 'خواندن'),
    MapEntry(3, 'نوشتن'),
    MapEntry(4, 'کامل'),
  ];
}

// ============================================================
//  وضعیت نسخه
// ============================================================

class DocVersionStatus {
  static const draft = 0;
  static const inReview = 1;
  static const approved = 2;
  static const rejected = 3;
  static const archived = 4;

  /// متن‌های صفحهٔ کاوشگر — «در گردش (فریز)»
  static String nameExplorer(int s) => switch (s) {
    0 => 'پیش‌نویس',
    1 => 'در گردش (فریز)',
    2 => 'تایید شده',
    3 => 'رد شده',
    _ => 'بایگانی',
  };

  /// متن‌های صفحهٔ جزئیات مدرک — «در گردش»
  static String nameView(int s) => switch (s) {
    0 => 'پیش‌نویس',
    1 => 'در گردش',
    2 => 'تایید شده',
    3 => 'رد شده',
    _ => 'بایگانی',
  };
}

// ============================================================
//  پوشه — DocFolderDto
// ============================================================

class DocFolder {
  const DocFolder({
    this.id = 0,
    this.parentId,
    this.name = '',
    this.description,
    this.isPublic = false,
    this.publicCanDownload = false,
    this.createdByName = '',
    this.createdAt,
    this.isActive = true,
    this.documentCount = 0,
    this.myLevel = 0,
    this.myCanDownload = false,
  });

  final int id;
  final int? parentId;
  final String name;
  final String? description;
  final bool isPublic;
  final bool publicCanDownload;
  final String createdByName;
  final DateTime? createdAt;
  final bool isActive;
  final int documentCount;
  final int myLevel;
  final bool myCanDownload;

  factory DocFolder.fromJson(Map<String, dynamic> j) => DocFolder(
    id: _i(j['id']),
    parentId: _ni(j['parentId']),
    name: _s(j['name']),
    description: _ns(j['description']),
    isPublic: _b(j['isPublic']),
    publicCanDownload: _b(j['publicCanDownload']),
    createdByName: _s(j['createdByName']),
    createdAt: _d(j['createdAt']),
    isActive: j['isActive'] == null ? true : _b(j['isActive']),
    documentCount: _i(j['documentCount']),
    myLevel: _i(j['myLevel']),
    myCanDownload: _b(j['myCanDownload']),
  );

  String get levelName => DocLevel.name(myLevel);
  bool get canWrite => myLevel >= DocLevel.write;
  String get titleWithLevel => '$name ($levelName)';
}

/// مسیر کامل پوشه‌ها — «والد / فرزند» (مثل `FolderPath` وب)
List<DocFolder> folderPath(List<DocFolder> all, int id) {
  final byId = {for (final f in all) f.id: f};
  final out = <DocFolder>[];
  var cur = byId[id];
  var guard = 0;
  while (cur != null && guard++ < 32) {
    out.insert(0, cur);
    cur = cur.parentId == null ? null : byId[cur.parentId!];
  }
  return out;
}

String folderPathText(List<DocFolder> all, int id) =>
    folderPath(all, id).map((f) => f.name).join(' / ');

// ============================================================
//  برچسب — DocTagDto
// ============================================================

class DocTag {
  const DocTag({
    this.id = 0,
    this.name = '',
    this.color = '#4f46e5',
    this.description,
    this.createdAt,
    this.documentCount = 0,
  });
  final int id;
  final String name;
  final String color;
  final String? description;
  final DateTime? createdAt;
  final int documentCount;

  factory DocTag.fromJson(Map<String, dynamic> j) => DocTag(
    id: _i(j['id']),
    name: _s(j['name']),
    color: _s(j['color']).isEmpty ? '#4f46e5' : _s(j['color']),
    description: _ns(j['description']),
    createdAt: _d(j['createdAt']),
    documentCount: _i(j['documentCount']),
  );
}

// ============================================================
//  مدرک — ردیف فهرست (DocumentListDto)
// ============================================================

class DocRow {
  const DocRow({
    this.id = 0,
    this.folderId = 0,
    this.folderName = '',
    this.title = '',
    this.code = '',
    this.customerCode,
    this.expireDate,
    this.isExpired = false,
    this.daysToExpire,
    this.isExpiringSoon = false,
    this.allowMultipleActiveVersions = false,
    this.isPublic = false,
    this.requireDownloadConfirm = false,
    this.watermarkPreview = false,
    this.createdByName = '',
    this.createdAt,
    this.isActive = true,
    this.deactivatedAt,
    this.deactivatedByName,
    this.deactivateReason,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedByName,
    this.versionCount = 0,
    this.activeVersionNo = 0,
    this.lastVersionStatus = 0,
    this.linkCount = 0,
    this.myLevel = 0,
    this.myCanDownload = false,
    this.tags = const [],
    this.hasIndexedContent = false,
    this.contentSnippet,
    this.matchedAttachmentFileName,
    this.matchedSourceType,
  });

  final int id;
  final int folderId;
  final String folderName;
  final String title;
  final String code;
  final String? customerCode;
  final DateTime? expireDate;
  final bool isExpired;
  final int? daysToExpire;
  final bool isExpiringSoon;
  final bool allowMultipleActiveVersions;
  final bool isPublic;
  final bool requireDownloadConfirm;
  final bool watermarkPreview;
  final String createdByName;
  final DateTime? createdAt;
  final bool isActive;
  final DateTime? deactivatedAt;
  final String? deactivatedByName;
  final String? deactivateReason;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? deletedByName;
  final int versionCount;
  final int activeVersionNo;
  final int lastVersionStatus;
  final int linkCount;
  final int myLevel;
  final bool myCanDownload;
  final List<DocTag> tags;
  final bool hasIndexedContent;
  final String? contentSnippet;
  final String? matchedAttachmentFileName;
  final String? matchedSourceType;

  factory DocRow.fromJson(Map<String, dynamic> j) => DocRow(
    id: _i(j['id']),
    folderId: _i(j['folderId']),
    folderName: _s(j['folderName']),
    title: _s(j['title']),
    code: _s(j['code']),
    customerCode: _ns(j['customerCode']),
    expireDate: _d(j['expireDate']),
    isExpired: _b(j['isExpired']),
    daysToExpire: _ni(j['daysToExpire']),
    isExpiringSoon: _b(j['isExpiringSoon']),
    allowMultipleActiveVersions: _b(j['allowMultipleActiveVersions']),
    isPublic: _b(j['isPublic']),
    requireDownloadConfirm: _b(j['requireDownloadConfirm']),
    watermarkPreview: _b(j['watermarkPreview']),
    createdByName: _s(j['createdByName']),
    createdAt: _d(j['createdAt']),
    isActive: j['isActive'] == null ? true : _b(j['isActive']),
    deactivatedAt: _d(j['deactivatedAt']),
    deactivatedByName: _ns(j['deactivatedByName']),
    deactivateReason: _ns(j['deactivateReason']),
    isDeleted: _b(j['isDeleted']),
    deletedAt: _d(j['deletedAt']),
    deletedByName: _ns(j['deletedByName']),
    versionCount: _i(j['versionCount']),
    activeVersionNo: _i(j['activeVersionNo']),
    lastVersionStatus: _i(j['lastVersionStatus']),
    linkCount: _i(j['linkCount']),
    myLevel: _i(j['myLevel']),
    myCanDownload: _b(j['myCanDownload']),
    tags: _rows(j['tags']).map(DocTag.fromJson).toList(),
    hasIndexedContent: _b(j['hasIndexedContent']),
    contentSnippet: _ns(j['contentSnippet']),
    matchedAttachmentFileName: _ns(j['matchedAttachmentFileName']),
    matchedSourceType: _ns(j['matchedSourceType']),
  );

  String get levelName => DocLevel.name(myLevel);
  String get folderCell => folderName.trim().isEmpty ? '—' : folderName;
  String get customerCodeCell =>
      (customerCode ?? '').trim().isEmpty ? '—' : customerCode!;

  /// «N روز» / «M روز گذشته» / «امروز» — عیناً `ExpiryText` وب
  String get expiryText {
    final n = daysToExpire;
    if (n == null) return '';
    if (n < 0) return '${Fa.digits(-n)} روز گذشته';
    if (n == 0) return 'امروز';
    return '${Fa.digits(n)} روز';
  }

  String get versionsText =>
      versionCount <= 0 ? '—' : '${Fa.digits(versionCount)} نسخه';

  /// «v۳» نسخهٔ فعال — یا «—»
  String get activeVersionText =>
      activeVersionNo <= 0 ? '—' : 'v${Fa.digits(activeVersionNo)}';
}

/// صفحهٔ فهرست — `Paging.Result` سرور: {total, items, page, pageSize, ...}
class DocPage<T> {
  const DocPage({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.pageSize = 20,
  });
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  bool get hasNext => page * pageSize < total;

  static DocPage<DocRow> documents(Map<String, dynamic> j) => DocPage<DocRow>(
    items: _rows(j['items']).map(DocRow.fromJson).toList(),
    total: _i(j['total']),
    page: _i(j['page']) == 0 ? 1 : _i(j['page']),
    pageSize: _i(j['pageSize']) == 0 ? 20 : _i(j['pageSize']),
  );

  static DocPage<DocFolder> folders(Map<String, dynamic> j) =>
      DocPage<DocFolder>(
        items: _rows(j['items']).map(DocFolder.fromJson).toList(),
        total: _i(j['total']),
        page: _i(j['page']) == 0 ? 1 : _i(j['page']),
        pageSize: _i(j['pageSize']) == 0 ? 20 : _i(j['pageSize']),
      );

  static DocPage<DocCartableItem> cartable(Map<String, dynamic> j) =>
      DocPage<DocCartableItem>(
        items: _rows(j['items']).map(DocCartableItem.fromJson).toList(),
        total: _i(j['total']),
        page: _i(j['page']) == 0 ? 1 : _i(j['page']),
        pageSize: _i(j['pageSize']) == 0 ? 20 : _i(j['pageSize']),
      );
}

// ============================================================
//  آمار آرشیو — DocArchiveStatsDto (`GET api/doc-archive/stats`)
// ============================================================

class DocArchiveStats {
  const DocArchiveStats({
    this.inactive = 0,
    this.deleted = 0,
    this.expired = 0,
    this.expiring = 0,
  });
  final int inactive;
  final int deleted;
  final int expired;
  final int expiring;

  factory DocArchiveStats.fromJson(Map<String, dynamic> j) => DocArchiveStats(
    inactive: _i(j['inactive']),
    deleted: _i(j['deleted']),
    expired: _i(j['expired']),
    expiring: _i(j['expiring']),
  );
}

// ============================================================
//  ستاره‌دار و اخیراً دیده‌شده
// ============================================================

class DocFavorite {
  const DocFavorite({
    this.documentId = 0,
    this.code = '',
    this.title = '',
    this.folderId = 0,
    this.folderName = '',
    this.favoritedAt,
    this.isFavorite = true,
  });
  final int documentId;
  final String code;
  final String title;
  final int folderId;
  final String folderName;
  final DateTime? favoritedAt;
  final bool isFavorite;

  factory DocFavorite.fromJson(Map<String, dynamic> j) => DocFavorite(
    documentId: _i(j['documentId']),
    code: _s(j['code']),
    title: _s(j['title']),
    folderId: _i(j['folderId']),
    folderName: _s(j['folderName']),
    favoritedAt: _d(j['favoritedAt']),
    isFavorite: j['isFavorite'] == null ? true : _b(j['isFavorite']),
  );

  String get folderCell => folderName.trim().isEmpty ? '—' : folderName;
}

class DocRecent {
  const DocRecent({
    this.documentId = 0,
    this.code = '',
    this.title = '',
    this.folderId = 0,
    this.folderName = '',
    this.viewedAt,
    this.action = 'View',
  });
  final int documentId;
  final String code;
  final String title;
  final int folderId;
  final String folderName;
  final DateTime? viewedAt;
  final String action;

  factory DocRecent.fromJson(Map<String, dynamic> j) => DocRecent(
    documentId: _i(j['documentId']),
    code: _s(j['code']),
    title: _s(j['title']),
    folderId: _i(j['folderId']),
    folderName: _s(j['folderName']),
    viewedAt: _d(j['viewedAt']),
    action: _s(j['action']).isEmpty ? 'View' : _s(j['action']),
  );

  String get folderCell => folderName.trim().isEmpty ? '—' : folderName;
}

// ============================================================
//  کارتابل آرشیو — DocCartableItemDto
// ============================================================

class DocCartableItem {
  const DocCartableItem({
    this.id = 0,
    this.kind = '',
    this.documentId = 0,
    this.versionId,
    this.documentCode = '',
    this.documentTitle = '',
    this.versionNo = 0,
    this.sourceDocumentCode,
    this.title = '',
    this.status = 0,
    this.createdAt,
  });
  final int id;
  final String kind;
  final int documentId;
  final int? versionId;
  final String documentCode;
  final String documentTitle;
  final int versionNo;
  final String? sourceDocumentCode;
  final String title;
  final int status;
  final DateTime? createdAt;

  factory DocCartableItem.fromJson(Map<String, dynamic> j) => DocCartableItem(
    id: _i(j['id']),
    kind: _s(j['kind']),
    documentId: _i(j['documentId']),
    versionId: _ni(j['versionId']),
    documentCode: _s(j['documentCode']),
    documentTitle: _s(j['documentTitle']),
    versionNo: _i(j['versionNo']),
    sourceDocumentCode: _ns(j['sourceDocumentCode']),
    title: _s(j['title']),
    status: _i(j['status']),
    createdAt: _d(j['createdAt']),
  );

  /// نوع کار — همان چهار برچسب وب
  String get kindLabel => switch (kind) {
    'Approval' => 'تایید ورژن',
    'RelatedUpdate' => 'به‌روزرسانی مرتبط',
    'ExpiryAlert' => 'هشدار انقضا',
    _ => 'اعلان ورژن',
  };

  /// 0 در انتظار · 1 انجام شد · بقیه رد شد
  String get statusLabel => switch (status) {
    0 => 'در انتظار',
    1 => 'انجام شد',
    _ => 'رد شد',
  };

  bool get isPending => status == 0;

  /// فقط کارهای غیرتاییدی را می‌توان دستی بست (مثل وب)
  bool get canClose => status == 0 && kind != 'Approval';

  String get versionText =>
      versionNo <= 0 ? '—' : 'v${Fa.digits(versionNo)}';
}

// ============================================================
//  داده‌های کمکی — DocArchiveLookups
// ============================================================

class DocLookup {
  const DocLookup({this.id = 0, this.name = '', this.avatarUrl, this.infoText});
  final int id;
  final String name;
  final String? avatarUrl;
  final String? infoText;

  factory DocLookup.fromJson(Map<String, dynamic> j) => DocLookup(
    id: _i(j['id']),
    name: _s(j['name']),
    avatarUrl: _ns(j['avatarUrl']),
    infoText: _ns(j['infoText']),
  );
}

class DocLookups {
  const DocLookups({
    this.users = const [],
    this.documents = const [],
    this.roles = const [],
    this.codeNumberingEnabled = false,
  });
  final List<DocLookup> users;
  final List<DocLookup> documents;
  final List<DocLookup> roles;
  final bool codeNumberingEnabled;

  factory DocLookups.fromJson(Map<String, dynamic> j) => DocLookups(
    users: _rows(j['users']).map(DocLookup.fromJson).toList(),
    documents: _rows(j['documents']).map(DocLookup.fromJson).toList(),
    roles: _rows(j['roles']).map(DocLookup.fromJson).toList(),
    codeNumberingEnabled: _b(j['codeNumberingEnabled']),
  );
}

// ============================================================
//  ورودی‌های فرم مدرک — برای ثبت/ویرایش
// ============================================================

class DocSaveInput {
  const DocSaveInput({
    this.id = 0,
    this.folderId = 0,
    this.title = '',
    this.code = '',
    this.customerCode,
    this.description,
    this.expireDate,
    this.allowMultipleActiveVersions = false,
    this.firstVersionActive = false,
    this.isPublic = false,
    this.publicCanDownload = false,
    this.requireDownloadConfirm = false,
    this.watermarkPreview = false,
    this.tagIds = const [],
    this.approvers = const [],
    this.linkedDocumentIds = const [],
  });

  final int id;
  final int folderId;
  final String title;
  final String code;
  final String? customerCode;
  final String? description;
  final DateTime? expireDate;
  final bool allowMultipleActiveVersions;
  final bool firstVersionActive;
  final bool isPublic;
  final bool publicCanDownload;
  final bool requireDownloadConfirm;
  final bool watermarkPreview;
  final List<int> tagIds;

  /// ترتیب افراد گردش = ترتیب انتخاب
  final List<int> approvers;
  final List<int> linkedDocumentIds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'folderId': folderId,
    'title': title.trim(),
    'code': code.trim(),
    'customerCode': (customerCode ?? '').trim(),
    'description': (description ?? '').trim(),
    'expireDate': expireDate?.toIso8601String(),
    'allowMultipleActiveVersions': allowMultipleActiveVersions,
    'firstVersionActive': firstVersionActive,
    'isPublic': isPublic,
    'publicCanDownload': isPublic && publicCanDownload,
    'requireDownloadConfirm': requireDownloadConfirm,
    'watermarkPreview': watermarkPreview,
    'tagIds': tagIds,
    'approvers': [
      for (var i = 0; i < approvers.length; i++)
        {'userId': approvers[i], 'userName': '', 'order': i, 'status': 0},
    ],
    'linkedDocumentIds': linkedDocumentIds,
  };
}

/// اعتبارسنجی فرم مدرک — با همان ترتیب و همان پیام‌های وب
String? validateDocForm({
  required String title,
  required String code,
  required bool numberingEnabled,
  required bool isNew,
  required int folderId,
}) {
  if (title.trim().isEmpty) return 'عنوان مدرک اجباری است.';
  if (code.trim().isEmpty && !(isNew && numberingEnabled)) {
    return 'کد مدرک اجباری است.';
  }
  if (folderId <= 0) return 'پوشه مدرک را انتخاب کنید.';
  return null;
}

// ============================================================
//  فاز ۹-ط — عملیات گروهی، سطل بازیافت، پوشه و برچسب
//  منبع: DocBulkController.cs، DocFoldersController.cs، DocTagsController.cs،
//        و مودال‌های DocArchiveExplorer.razor
// ============================================================

/// نتیجهٔ عملیات گروهی — `DocBulkResultDto`
class DocBulkResult {
  const DocBulkResult({
    this.requested = 0,
    this.succeeded = 0,
    this.failed = 0,
    this.errors = const [],
    this.message = '',
  });
  final int requested;
  final int succeeded;
  final int failed;
  final List<String> errors;
  final String message;

  factory DocBulkResult.fromJson(Map<String, dynamic> j) {
    final raw = j['errors'];
    return DocBulkResult(
      requested: _i(j['requested']),
      succeeded: _i(j['succeeded']),
      failed: _i(j['failed']),
      errors: raw is List ? raw.map((e) => _s(e)).toList() : const [],
      message: _s(j['message']),
    );
  }

  /// پیام نهایی برای نمایش — همان قاعدهٔ وب (پیام + سه خطای اول)
  String get display {
    final base = message.trim().isEmpty
        ? '$succeeded از $requested مورد انجام شد.'
        : message;
    if (errors.isEmpty) return base;
    return '$base\n${errors.take(3).join('\n')}';
  }
}

/// حالت برچسب گروهی — همان دو گزینهٔ وب
enum DocBulkTagMode { append, replace }

const List<MapEntry<DocBulkTagMode, String>> kDocBulkTagModes = [
  MapEntry(DocBulkTagMode.append, 'افزودن'),
  MapEntry(DocBulkTagMode.replace, 'جایگزینی'),
];

/// متن هشدار مودال «انتقال گروهی به پوشه»
const String kBulkMoveWarning =
    'فقط مدارکی که روی آن‌ها دسترسی نوشتن دارید منتقل می‌شوند؛ بقیه رد می‌شوند.';

/// متن هشدار مودال «حذف قطعی»
const String kPurgeWarning =
    'این عملیات برگشت‌ناپذیر است. مدرک به‌همراه کلیه ورژن‌ها، پیوست‌ها، دسترسی‌ها و تاریخچه به‌صورت قطعی از دیتابیس پاک خواهد شد.';

/// عبارت تایید حذف قطعی — عیناً وب
const String kPurgePhrase = 'حذف قطعی';

/// متن تایید حذف گروهی به سطل
String bulkDeleteConfirmText(int count) =>
    'آیا $count مدرک انتخاب‌شده به سطل بازیافت منتقل شود؟';

/// رنگ‌های پیشنهادی برچسب — همان نمونهٔ فرم وب (`#4f46e5` پیش‌فرض)
const List<String> kTagPalette = [
  '#4f46e5',
  '#0ea5e9',
  '#0f766e',
  '#16a34a',
  '#ca8a04',
  '#ea580c',
  '#dc2626',
  '#be185d',
  '#7c3aed',
  '#475569',
];

/// اعتبارسنجی برچسب — عیناً پیام‌های DocTagsController
String? validateTagName(String name) =>
    name.trim().isEmpty ? 'نام تگ اجباری است.' : null;

// ============================================================
//  فاز ۹-ی — نسخه‌ها، گردش تأیید، پیوست‌ها، مقایسه و جستجوی هوشمند
//  منبع: DocumentService.cs (CreateVersion/ActApproval)، ArchiveController.cs
//        (api/attachments)، DocSearchController.cs و DocSemanticController.cs
// ============================================================

/// ورودی ثبت نسخهٔ جدید — `DocVersionCreateDto`
class DocVersionInput {
  const DocVersionInput({
    required this.documentId,
    this.title,
    this.changeNote,
    this.expireDate,
    this.activateOnApprove = true,
    this.sendToFlow = true,
    this.approverUserIds = const [],
  });

  final int documentId;
  final String? title;
  final String? changeNote;
  final DateTime? expireDate;
  final bool activateOnApprove;
  final bool sendToFlow;
  final List<int> approverUserIds;

  Map<String, dynamic> toJson() => {
    'documentId': documentId,
    'title': (title ?? '').trim(),
    'changeNote': (changeNote ?? '').trim(),
    'expireDate': expireDate?.toIso8601String(),
    'activateOnApprove': activateOnApprove,
    'sendToFlow': sendToFlow,
    'approverUserIds': approverUserIds,
  };
}

/// اعتبارسنجی نسخهٔ جدید — عیناً پیام وب («شرح تغییرات را وارد کنید.»)
String? validateVersionForm({required String changeNote}) =>
    changeNote.trim().isEmpty ? 'شرح تغییرات را وارد کنید.' : null;

/// ورودی اقدام تایید/رد — `DocApprovalActionDto`
class DocApprovalInput {
  const DocApprovalInput({
    required this.versionId,
    required this.approve,
    this.comment,
  });
  final int versionId;
  final bool approve;
  final String? comment;

  Map<String, dynamic> toJson() => {
    'versionId': versionId,
    'approve': approve,
    'comment': (comment ?? '').trim(),
  };
}

/// یک پیوست — خروجی `GET api/attachments/{module}/{refId}`
class DocAttachment {
  const DocAttachment({
    this.id = 0,
    this.fileName = '',
    this.uploaderName = '',
    this.uploaderUserId = 0,
    this.uploadedAt,
    this.size = 0,
    this.contentType = '',
    this.canPreview = false,
    this.canDownload = false,
    this.canDelete = false,
    this.documentId = 0,
    this.needsConfirm = false,
    this.watermark = false,
  });

  final int id;
  final String fileName;
  final String uploaderName;
  final int uploaderUserId;
  final DateTime? uploadedAt;
  final int size;
  final String contentType;
  final bool canPreview;
  final bool canDownload;
  final bool canDelete;
  final int documentId;
  final bool needsConfirm;
  final bool watermark;

  factory DocAttachment.fromJson(Map<String, dynamic> j) => DocAttachment(
    id: _i(j['id']),
    fileName: _s(j['fileName']),
    uploaderName: _s(j['uploaderName']),
    uploaderUserId: _i(j['uploaderUserId']),
    uploadedAt: _d(j['uploadedAt']),
    size: _i(j['size']),
    contentType: _s(j['contentType']),
    canPreview: _b(j['canPreview']),
    canDownload: _b(j['canDownload']),
    canDelete: _b(j['canDelete']),
    documentId: _i(j['documentId']),
    needsConfirm: _b(j['needsConfirm']),
    watermark: _b(j['watermark']),
  );

  String get sizeFa => Fa.bytes(size);

  /// آیا تصویر است؟ (پیش‌نمایش داخل برنامه)
  bool get isImage => contentType.startsWith('image/');
  bool get isPdf => contentType == 'application/pdf';

  String get uploadedAtFa => Fa.date(uploadedAt?.toIso8601String());
}

/// حد مجاز آپلود — همان پیام سرور
const int kAttachmentMaxBytes = 10 * 1024 * 1024;
const String kAttachmentTooLarge = 'حداکثر حجم فایل ۱۰ مگابایت است.';

/// یک ردیف تفاوت در مقایسهٔ دو نسخه — `DocVersionDiffRow`
class DocDiffRow {
  const DocDiffRow({
    this.field = '',
    this.left,
    this.right,
    this.kind = 'same',
  });
  final String field;
  final String? left;
  final String? right;

  /// same | added | removed | changed
  final String kind;

  factory DocDiffRow.fromJson(Map<String, dynamic> j) => DocDiffRow(
    field: _s(j['field']),
    left: _ns(j['left']),
    right: _ns(j['right']),
    kind: _s(j['kind']).isEmpty ? 'same' : _s(j['kind']),
  );

  bool get isChanged => kind != 'same';
  String get leftCell => (left ?? '').isEmpty ? '—' : left!;
  String get rightCell => (right ?? '').isEmpty ? '—' : right!;

  /// برچسب فارسی تغییر — همان منطق وب
  String get kindLabel => switch (kind) {
    'added' => 'افزوده شد',
    'removed' => 'حذف شد',
    'changed' => 'تغییر کرد',
    _ => 'یکسان',
  };
}

/// نتیجهٔ مقایسهٔ دو نسخه — `DocVersionCompareDto`
class DocVersionCompare {
  const DocVersionCompare({
    this.documentId = 0,
    this.documentCode = '',
    this.documentTitle = '',
    this.fields = const [],
    this.approvers = const [],
    this.attachments = const [],
    this.between = const [],
    this.changeCount = 0,
  });
  final int documentId;
  final String documentCode;
  final String documentTitle;
  final List<DocDiffRow> fields;
  final List<DocDiffRow> approvers;
  final List<DocDiffRow> attachments;
  final List<DocLogRow> between;
  final int changeCount;

  factory DocVersionCompare.fromJson(Map<String, dynamic> j) {
    List<DocDiffRow> rows(Object? v) => v is List
        ? v
              .whereType<Map>()
              .map((e) => DocDiffRow.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : const [];
    return DocVersionCompare(
      documentId: _i(j['documentId']),
      documentCode: _s(j['documentCode']),
      documentTitle: _s(j['documentTitle']),
      fields: rows(j['fields']),
      approvers: rows(j['approvers']),
      attachments: rows(j['attachments']),
      between: DocLogRow.listFrom(j['between']),
      changeCount: _i(j['changeCount']),
    );
  }

  /// متن خلاصه — «N تفاوت»
  String get summaryFa =>
      changeCount == 0 ? 'بدون تفاوت' : '${Fa.digits(changeCount)} تفاوت';
}

/// یک نتیجهٔ جستجوی معنایی — `DocSemanticHitDto`
class DocSemanticHit {
  const DocSemanticHit({
    this.documentId = 0,
    this.code = '',
    this.title = '',
    this.folderId = 0,
    this.folderName = '',
    this.snippet = '',
    this.score = 0,
    this.myLevel = 0,
    this.tags = const [],
    this.expireDate,
  });
  final int documentId;
  final String code;
  final String title;
  final int folderId;
  final String folderName;
  final String snippet;
  final double score;
  final int myLevel;
  final List<DocTag> tags;
  final DateTime? expireDate;

  factory DocSemanticHit.fromJson(Map<String, dynamic> j) => DocSemanticHit(
    documentId: _i(j['documentId']),
    code: _s(j['code']),
    title: _s(j['title']),
    folderId: _i(j['folderId']),
    folderName: _s(j['folderName']),
    snippet: _s(j['snippet']),
    score: (j['score'] is num) ? (j['score'] as num).toDouble() : 0,
    myLevel: _i(j['myLevel']),
    tags: j['tags'] is List
        ? (j['tags'] as List)
              .whereType<Map>()
              .map((e) => DocTag.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : const [],
    expireDate: _d(j['expireDate']),
  );

  /// «0.00» — مثل `Score.ToString("0.00")` وب
  String get scoreFa => score.toStringAsFixed(2);

  String get folderCell => folderName.trim().isEmpty ? '—' : folderName;
}

/// نتیجهٔ جستجوی معنایی — `DocSemanticSearchResultDto`
class DocSemanticResult {
  const DocSemanticResult({
    this.hits = const [],
    this.semantic = false,
    this.note,
    this.totalCandidates = 0,
  });
  final List<DocSemanticHit> hits;

  /// true = بردار معنایی · false = کلیدواژه‌ای
  final bool semantic;
  final String? note;
  final int totalCandidates;

  factory DocSemanticResult.fromJson(Map<String, dynamic> j) =>
      DocSemanticResult(
        hits: j['hits'] is List
            ? (j['hits'] as List)
                  .whereType<Map>()
                  .map((e) => DocSemanticHit.fromJson(Map<String, dynamic>.from(e)))
                  .toList()
            : const [],
        semantic: _b(j['semantic']),
        note: _ns(j['note']),
        totalCandidates: _i(j['totalCandidates']),
      );

  String get modeLabel => semantic ? 'معنایی' : 'کلیدواژه‌ای';
}

/// ورودی جستجوی معنایی — `DocSemanticSearchRequest`
class DocSemanticRequest {
  const DocSemanticRequest({
    required this.query,
    this.folderId,
    this.includeSubfolders = true,
    this.tagIds = const [],
    this.status = 'active',
    this.take = 15,
  });
  final String query;
  final int? folderId;
  final bool includeSubfolders;
  final List<int> tagIds;
  final String status;
  final int take;

  Map<String, dynamic> toJson() => {
    'query': query.trim(),
    'folderId': folderId,
    'includeSubfolders': includeSubfolders,
    'tagIds': tagIds,
    'status': status,
    'take': take,
  };
}

/// اعتبارسنجی جستجوی معنایی — همان دو پیام سرور
String? validateSemanticQuery(String q) {
  final t = q.trim();
  if (t.length < 2) return 'عبارت جستجو حداقل ۲ حرف باشد.';
  if (t.length > 500) return 'عبارت جستجو خیلی طولانی است.';
  return null;
}

/// ورودی جستجوی پیشرفته/تمام‌متن — `DocSearchFilterDto`
class DocSearchFilter {
  const DocSearchFilter({
    this.page = 1,
    this.pageSize = 25,
    this.search,
    this.contentSearch,
    this.folderId,
    this.includeSubfolders = true,
    this.status = 'active',
    this.expiryStatus = 'all',
    this.fileTypes = const [],
    this.tagIds = const [],
  });
  final int page;
  final int pageSize;
  final String? search;

  /// جستجوی تمام‌متن در محتوای فایل‌ها و OCR
  final String? contentSearch;
  final int? folderId;
  final bool includeSubfolders;
  final String status;
  final String expiryStatus;

  /// pdf | word | excel | image | text
  final List<String> fileTypes;
  final List<int> tagIds;

  Map<String, dynamic> toJson() => {
    'page': page,
    'pageSize': pageSize,
    if ((search ?? '').trim().isNotEmpty) 'search': search!.trim(),
    if ((contentSearch ?? '').trim().isNotEmpty)
      'contentSearch': contentSearch!.trim(),
    if (folderId != null && folderId! > 0) 'folderId': folderId,
    'includeSubfolders': includeSubfolders,
    'status': status,
    'expiryStatus': expiryStatus,
    'fileTypes': fileTypes,
    'tagIds': tagIds,
  };
}

/// انواع فایل جستجوی پیشرفته — همان پنج دکمهٔ وب
const List<MapEntry<String, String>> kDocFileTypes = [
  MapEntry('pdf', 'PDF'),
  MapEntry('word', 'Word'),
  MapEntry('excel', 'Excel'),
  MapEntry('image', 'تصویر'),
  MapEntry('text', 'متن'),
];

// ---- از صفحهٔ جزئیات منتقل شد تا استوریج و مدل‌ها یک‌جا باشند ----
class DocLogRow {
  const DocLogRow({
    this.id = 0,
    this.action = '',
    this.detail,
    this.userName = '',
    this.createdAt,
    this.versionId,
  });
  final int id;
  final String action;
  final String? detail;
  final String userName;
  final DateTime? createdAt;
  final int? versionId;

  static List<DocLogRow> listFrom(Object? v) {
    if (v is! List) return const [];
    return v.whereType<Map>().map((e) {
      final j = Map<String, dynamic>.from(e);
      return DocLogRow(
        id: (j['id'] as num?)?.toInt() ?? 0,
        action: j['action']?.toString() ?? '',
        detail: j['detail']?.toString(),
        userName: j['userName']?.toString() ?? '',
        createdAt: Fa.parseServerDate(j['createdAt']),
        versionId: (j['versionId'] as num?)?.toInt(),
      );
    }).toList();
  }

  /// همان نگاشت `ActionName` وب
  static String actionName(String a) => switch (a) {
    'Create' => 'ایجاد',
    'Update' => 'ویرایش',
    'NewVersion' => 'ورژن جدید',
    'Approve' => 'تایید',
    'Approved' => 'تایید نهایی',
    'Reject' => 'رد',
    'Activate' => 'فعال‌سازی ورژن',
    'Link' => 'لینک',
    'Unlink' => 'حذف لینک',
    'RelatedUpdate' => 'مدرک مرتبط',
    'Deactivate' => 'غیرفعال‌سازی',
    'Permissions' => 'دسترسی‌ها',
    'ExpiryAlert' => 'هشدار انقضا',
    'Delete' => 'حذف',
    'Restore' => 'بازگردانی',
    'Print' => 'چاپ',
    'View' => 'بازدید',
    'Read' => 'مطالعه',
    _ => a,
  };
}

