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
