// ============================================================
//  لایهٔ دادهٔ «آرشیو اسناد و مدارک» — فاز ۹-ح (بخش ۱)
//  اندپوینت‌ها عیناً از کنترلرهای وب (پیشوند `api/doc-archive`):
//    GET    documents?folderId&search&status&expiry&expiringDays&skip&take
//    GET    documents/{id}         · POST documents · PUT documents/{id} · DELETE documents/{id}
//    GET    folders                · POST folders    · PUT folders/{id}
//    GET    lookups                · GET  stats      · GET  expiry-summary
//    GET    cartable?includeDone   · PUT  cartable/{id}/done
//    POST   favorites/{documentId}/toggle · GET favorites · GET recently-viewed
//    GET    tags                   · POST tags       · PUT tags/{id} · DELETE tags/{id}
// ============================================================

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/doc_archive_models.dart';

class DocArchiveRepository {
  DocArchiveRepository(this._api);

  final ApiClient _api;
  static const _root = '/api/doc-archive';

  // ---------------- مدارک ----------------

  Future<DocPage<DocRow>> documents({
    int? folderId,
    String? search,
    String status = 'active',
    String? expiry,
    int expiringDays = 60,
    int skip = 0,
    int? take,
  }) async {
    final r = await _api.get<dynamic>(
      '$_root/documents',
      query: {
        if (folderId != null && folderId > 0) 'folderId': folderId,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'status': status,
        if (expiry != null) 'expiry': expiry,
        'expiringDays': expiringDays,
        'skip': skip,
        if (take != null) 'take': take,
      },
    );
    final d = r.data;
    return d is Map
        ? DocPage.documents(Map<String, dynamic>.from(d))
        : const DocPage<DocRow>();
  }

  Future<DocRow?> document(int id) async {
    final r = await _api.get<dynamic>('$_root/documents/$id');
    final d = r.data;
    if (d is! Map) return null;
    final m = Map<String, dynamic>.from(d);
    // جزئیات، همان فیلدهای فهرست را دارد به‌علاوهٔ نسخه‌ها/لاگ/دسترسی
    return DocRow.fromJson(m);
  }

  /// جزئیات خام (نسخه‌ها، لاگ، دسترسی‌ها …) برای صفحهٔ مدرک
  Future<Map<String, dynamic>> documentRaw(int id) async {
    final r = await _api.get<dynamic>('$_root/documents/$id');
    final d = r.data;
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  Future<int> createDocument(DocSaveInput input) async {
    final r = await _api.post<dynamic>('$_root/documents', input.toJson());
    final d = r.data;
    return d is Map ? (d['id'] as num?)?.toInt() ?? 0 : 0;
  }

  Future<void> updateDocument(DocSaveInput input) =>
      _api.put<dynamic>('$_root/documents/${input.id}', input.toJson());

  Future<void> deleteDocument(int id) =>
      _api.delete<dynamic>('$_root/documents/$id');

  /// بررسی زندهٔ یکتایی کد — `GET documents/check-code?code=…`
  Future<bool> codeExists(String code) async {
    final r = await _api.get<dynamic>(
      '$_root/documents/check-code',
      query: {'code': code.trim()},
    );
    final d = r.data;
    if (d is Map) {
      return d['exists'] == true || d['taken'] == true;
    }
    return d == true;
  }

  // ---------------- پوشه‌ها ----------------

  Future<DocPage<DocFolder>> folders({int skip = 0, int? take}) async {
    final r = await _api.get<dynamic>(
      '$_root/folders',
      query: {'skip': skip, if (take != null) 'take': take},
    );
    final d = r.data;
    return d is Map
        ? DocPage.folders(Map<String, dynamic>.from(d))
        : const DocPage<DocFolder>();
  }

  Future<int> createFolder({
    required String name,
    int? parentId,
    String? description,
    bool isPublic = false,
    bool publicCanDownload = false,
    List<DocPermissionInput> permissions = const [],
  }) async {
    final r = await _api.post<dynamic>('$_root/folders', {
      'name': name.trim(),
      'parentId': parentId,
      'description': (description ?? '').trim(),
      'isPublic': isPublic,
      'publicCanDownload': isPublic && publicCanDownload,
      'permissions': [for (final p in permissions) p.toJson()],
    });
    final d = r.data;
    return d is Map ? (d['id'] as num?)?.toInt() ?? 0 : 0;
  }

  Future<void> updateFolder({
    required int id,
    required String name,
    int? parentId,
    String? description,
    bool isPublic = false,
    bool publicCanDownload = false,
  }) => _api.put<dynamic>('$_root/folders/$id', {
    'id': id,
    'name': name.trim(),
    'parentId': parentId,
    'description': (description ?? '').trim(),
    'isPublic': isPublic,
    'publicCanDownload': isPublic && publicCanDownload,
  });

  Future<void> deleteFolder(int id) => _api.delete<dynamic>('$_root/folders/$id');

  // ---------------- آمار / کمکی‌ها ----------------

  Future<DocArchiveStats> stats() async {
    final r = await _api.get<dynamic>('$_root/stats');
    final d = r.data;
    return d is Map
        ? DocArchiveStats.fromJson(Map<String, dynamic>.from(d))
        : const DocArchiveStats();
  }

  Future<DocLookups> lookups() async {
    final r = await _api.get<dynamic>('$_root/lookups');
    final d = r.data;
    return d is Map
        ? DocLookups.fromJson(Map<String, dynamic>.from(d))
        : const DocLookups();
  }

  // ---------------- ستاره‌دار و اخیر ----------------

  Future<void> toggleFavorite(int documentId) =>
      _api.post<dynamic>('$_root/favorites/$documentId/toggle');

  Future<List<DocFavorite>> favorites({int skip = 0, int? take}) async {
    final r = await _api.get<dynamic>(
      '$_root/favorites',
      query: {'skip': skip, if (take != null) 'take': take},
    );
    final d = r.data;
    if (d is List) {
      return d
          .whereType<Map>()
          .map((e) => DocFavorite.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (d is Map && d['items'] is List) {
      return (d['items'] as List)
          .whereType<Map>()
          .map((e) => DocFavorite.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  Future<List<DocRecent>> recentlyViewed({int take = 10}) async {
    final r = await _api.get<dynamic>(
      '$_root/recently-viewed',
      query: {'take': take},
    );
    final d = r.data;
    final list = d is List ? d : (d is Map && d['items'] is List ? d['items'] as List : const []);
    return list
        .whereType<Map>()
        .map((e) => DocRecent.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ---------------- کارتابل ----------------

  Future<DocPage<DocCartableItem>> cartable({
    bool includeDone = false,
    int skip = 0,
    int? take,
  }) async {
    final r = await _api.get<dynamic>(
      '$_root/cartable',
      query: {
        'includeDone': includeDone,
        'skip': skip,
        if (take != null) 'take': take,
      },
    );
    final d = r.data;
    return d is Map
        ? DocPage.cartable(Map<String, dynamic>.from(d))
        : const DocPage<DocCartableItem>();
  }

  Future<void> closeCartableTask(int id) =>
      _api.put<dynamic>('$_root/cartable/$id/done');

  // ---------------- برچسب‌ها ----------------

  Future<List<DocTag>> tags() async {
    final r = await _api.get<dynamic>('$_root/tags');
    final d = r.data;
    final list = d is List ? d : (d is Map && d['items'] is List ? d['items'] as List : const []);
    return list
        .whereType<Map>()
        .map((e) => DocTag.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ---------------- فاز ۹-ط: عملیات گروهی ----------------

  Future<DocBulkResult> bulkMove({
    required List<int> ids,
    required int targetFolderId,
  }) async {
    final r = await _api.post<dynamic>('$_root/bulk/move', {
      'documentIds': ids,
      'targetFolderId': targetFolderId,
    });
    final d = r.data;
    return d is Map
        ? DocBulkResult.fromJson(Map<String, dynamic>.from(d))
        : const DocBulkResult();
  }

  Future<DocBulkResult> bulkTags({
    required List<int> ids,
    required List<int> tagIds,
    DocBulkTagMode mode = DocBulkTagMode.append,
  }) async {
    final r = await _api.post<dynamic>('$_root/bulk/tags', {
      'documentIds': ids,
      'tagIds': tagIds,
      'mode': mode == DocBulkTagMode.replace ? 'replace' : 'append',
    });
    final d = r.data;
    return d is Map
        ? DocBulkResult.fromJson(Map<String, dynamic>.from(d))
        : const DocBulkResult();
  }

  Future<DocBulkResult> bulkExpire({
    required List<int> ids,
    DateTime? expireDate,
  }) async {
    final r = await _api.post<dynamic>('$_root/bulk/expire', {
      'documentIds': ids,
      'expireDate': expireDate?.toIso8601String(),
    });
    final d = r.data;
    return d is Map
        ? DocBulkResult.fromJson(Map<String, dynamic>.from(d))
        : const DocBulkResult();
  }

  Future<DocBulkResult> bulkDelete(List<int> ids) async {
    final r = await _api.post<dynamic>('$_root/bulk/delete', ids);
    final d = r.data;
    return d is Map
        ? DocBulkResult.fromJson(Map<String, dynamic>.from(d))
        : const DocBulkResult();
  }

  // ---------------- سطل بازیافت ----------------

  /// بازگرداندن مدرک — `PUT documents/{id}/restore`
  Future<String> restoreDocument(int id) async {
    final r = await _api.put<dynamic>('$_root/documents/$id/restore');
    final d = r.data;
    return d is Map ? '${d['message'] ?? 'مدرک بازگردانده شد.'}' : 'مدرک بازگردانده شد.';
  }

  /// حذف قطعی برگشت‌ناپذیر — `DELETE documents/{id}/purge`
  Future<String> purgeDocument(int id) async {
    final r = await _api.delete<dynamic>('$_root/documents/$id/purge');
    final d = r.data;
    return d is Map ? '${d['message'] ?? 'مدرک حذف شد.'}' : 'مدرک حذف شد.';
  }

  /// خالی کردن کامل سطل — `DELETE api/doc-archive/trash`
  Future<String> emptyTrash() async {
    final r = await _api.delete<dynamic>('$_root/trash');
    final d = r.data;
    return d is Map
        ? '${d['message'] ?? 'سطل بازیافت خالی شد.'}'
        : 'سطل بازیافت خالی شد.';
  }

  // ---------------- فعال/غیرفعال مدرک ----------------

  Future<void> setDocumentActive({
    required int id,
    required bool isActive,
    String? reason,
  }) => _api.put<dynamic>('$_root/documents/$id/active', {
    'isActive': isActive,
    'reason': (reason ?? '').trim(),
  });

  // ---------------- دسترسی پوشه و مدرک ----------------

  Future<void> saveFolderPermissions(
    int id, {
    required bool isPublic,
    required bool publicCanDownload,
    required List<DocPermissionInput> items,
  }) => _api.put<dynamic>('$_root/folders/$id/permissions', {
    'isPublic': isPublic,
    'publicCanDownload': isPublic && publicCanDownload,
    'items': [for (final p in items) p.toJson()],
  });

  Future<void> saveDocumentPermissions(
    int id, {
    required bool isPublic,
    required bool publicCanDownload,
    required bool requireDownloadConfirm,
    required bool watermarkPreview,
    required List<DocPermissionInput> items,
  }) => _api.put<dynamic>('$_root/documents/$id/permissions', {
    'isPublic': isPublic,
    'publicCanDownload': isPublic && publicCanDownload,
    'requireDownloadConfirm': requireDownloadConfirm,
    'watermarkPreview': watermarkPreview,
    'items': [for (final p in items) p.toJson()],
  });

  /// دسترسی‌های یک پوشه (فقط برای دارندهٔ دسترسی کامل برمی‌گردد)
  Future<List<DocPermissionInput>> folderPermissions(int id) async {
    final r = await _api.get<dynamic>('$_root/folders/$id');
    final d = r.data;
    if (d is! Map) return const [];
    final list = d['permissions'];
    if (list is! List) return const [];
    return list.whereType<Map>().map((e) {
      final j = Map<String, dynamic>.from(e);
      return DocPermissionInput(
        userId: (j['userId'] as num?)?.toInt() ?? 0,
        roleId: (j['roleId'] as num?)?.toInt() ?? 0,
        level: (j['level'] as num?)?.toInt() ?? DocLevel.read,
        canDownload: j['canDownload'] == true,
      );
    }).toList();
  }

  /// دسترسی‌های تعریف‌شدهٔ یک مدرک — از `GET documents/{id}` (فقط برای دسترسی کامل)
  Future<List<DocPermissionInput>> documentPermissionsRaw(int id) async {
    final r = await _api.get<dynamic>('$_root/documents/$id');
    final d = r.data;
    if (d is! Map) return const [];
    final list = d['permissions'];
    if (list is! List) return const [];
    return list.whereType<Map>().map((e) {
      final j = Map<String, dynamic>.from(e);
      return DocPermissionInput(
        userId: (j['userId'] as num?)?.toInt() ?? 0,
        roleId: (j['roleId'] as num?)?.toInt() ?? 0,
        level: (j['level'] as num?)?.toInt() ?? DocLevel.read,
        canDownload: j['canDownload'] == true,
      );
    }).toList();
  }

  // ---------------- برچسب‌ها (نوشتن) ----------------

  Future<void> createTag({
    required String name,
    String color = '#4f46e5',
    String? description,
  }) => _api.post<dynamic>('$_root/tags', {
    'name': name.trim(),
    'color': color.trim().isEmpty ? '#4f46e5' : color.trim(),
    'description': (description ?? '').trim(),
  });

  Future<void> updateTag({
    required int id,
    required String name,
    String color = '#4f46e5',
    String? description,
  }) => _api.put<dynamic>('$_root/tags/$id', {
    'name': name.trim(),
    'color': color.trim().isEmpty ? '#4f46e5' : color.trim(),
    'description': (description ?? '').trim(),
  });

  Future<String> deleteTag(int id) async {
    final r = await _api.delete<dynamic>('$_root/tags/$id');
    final d = r.data;
    return d is Map
        ? '${d['message'] ?? 'تگ با موفقیت حذف شد.'}'
        : 'تگ با موفقیت حذف شد.';
  }

  // ---------------- فاز ۹-ی: نسخه، تایید، پیوست، مقایسه، جستجو ----------------

  /// ثبت نسخهٔ جدید — `POST documents/versions`
  Future<int> createVersion(DocVersionInput input) async {
    final r = await _api.post<dynamic>('$_root/documents/versions', input.toJson());
    final d = r.data;
    return d is Map ? (d['id'] as num?)?.toInt() ?? 0 : 0;
  }

  /// فعال/غیرفعال کردن یک نسخه — `PUT documents/versions/{id}/active?active=`
  Future<void> setVersionActive(int versionId, bool active) => _api.put<dynamic>(
    '$_root/documents/versions/$versionId/active?active=$active',
  );

  /// اقدام تایید/رد — `POST documents/approval`
  Future<void> submitApproval(DocApprovalInput input) =>
      _api.post<dynamic>('$_root/documents/approval', input.toJson());

  /// مقایسهٔ دو نسخه — `GET documents/{id}/compare?from&to`
  Future<DocVersionCompare> compareVersions({
    required int documentId,
    required int from,
    required int to,
  }) async {
    final r = await _api.get<dynamic>(
      '$_root/documents/$documentId/compare',
      query: {'from': from, 'to': to},
    );
    final d = r.data;
    return d is Map
        ? DocVersionCompare.fromJson(Map<String, dynamic>.from(d))
        : const DocVersionCompare();
  }

  /// لینک یک مدرک مرتبط — `POST documents/links`
  Future<void> linkDocument({
    required int documentId,
    required int linkedDocumentId,
    String? note,
  }) => _api.post<dynamic>('$_root/documents/links', {
    'documentId': documentId,
    'linkedDocumentId': linkedDocumentId,
    'note': (note ?? '').trim(),
  });

  /// حذف لینک — `DELETE documents/links?documentId&linkedDocumentId`
  Future<void> unlinkDocument({
    required int documentId,
    required int linkedDocumentId,
  }) => _api.delete<dynamic>(
    '$_root/documents/links?documentId=$documentId&linkedDocumentId=$linkedDocumentId',
  );

  // ---------------- پیوست‌های نسخه ----------------

  /// فهرست پیوست‌های یک نسخه — `GET api/attachments/DocVersion/{refId}`
  Future<List<DocAttachment>> attachments(int versionId) async {
    final r = await _api.get<dynamic>('/api/attachments/DocVersion/$versionId');
    final d = r.data;
    final list = d is List
        ? d
        : (d is Map && d['items'] is List ? d['items'] as List : const []);
    return list
        .whereType<Map>()
        .map((e) => DocAttachment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// بارگذاری پیوست روی نسخه — `POST api/attachments/DocVersion/{refId}`
  Future<void> uploadAttachment({
    required int versionId,
    required String fileName,
    required List<int> bytes,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    await _api.postForm<dynamic>(
      '/api/attachments/DocVersion/$versionId',
      form,
      onSendProgress: onProgress,
    );
  }

  /// حذف پیوست — `DELETE api/attachments/{id}`
  Future<void> deleteAttachment(int id) =>
      _api.delete<dynamic>('/api/attachments/$id');

  /// آدرس پیش‌نمایش/دانلود پیوست (توکن در هدر می‌رود؛ آدرس برای نمایش)
  String attachmentPreviewUrl(int id) =>
      _api.resolveUrl('/api/attachments/preview/$id');
  String attachmentDownloadUrl(int id) =>
      _api.resolveUrl('/api/attachments/download/$id');

  /// دریافت بایت پیوست (برای پیش‌نمایش تصویر داخل برنامه)
  Future<List<int>> attachmentBytes(int id) async {
    final r = await _api.request<List<int>>(
      'GET',
      '/api/attachments/download/$id',
      options: Options(responseType: ResponseType.bytes),
    );
    return r.data ?? const [];
  }

  // ---------------- جستجوی هوشمند ----------------

  /// جستجوی معنایی — `POST api/doc-archive/semantic-search`
  Future<DocSemanticResult> semanticSearch(DocSemanticRequest req) async {
    final r = await _api.post<dynamic>('$_root/semantic-search', req.toJson());
    final d = r.data;
    return d is Map
        ? DocSemanticResult.fromJson(Map<String, dynamic>.from(d))
        : const DocSemanticResult();
  }

  /// جستجوی پیشرفته/تمام‌متن صفحه‌بندی‌شده — `POST api/doc-archive/search-page`
  Future<DocPage<DocRow>> searchPage(DocSearchFilter filter) async {
    final r = await _api.post<dynamic>(
      '$_root/search-page',
      filter.toJson(),
    );
    final d = r.data;
    return d is Map
        ? DocPage.documents(Map<String, dynamic>.from(d))
        : const DocPage<DocRow>();
  }

}

/// یک ردیف دسترسی پوشه/مدرک — `DocPermissionDto`
class DocPermissionInput {
  const DocPermissionInput({
    this.userId = 0,
    this.roleId = 0,
    this.level = DocLevel.read,
    this.canDownload = false,
  });
  final int userId;
  final int roleId;
  final int level;
  final bool canDownload;

  bool get isRole => roleId > 0;

  Map<String, dynamic> toJson() => {
    'userId': isRole ? 0 : userId,
    'roleId': isRole ? roleId : 0,
    'level': level,
    'canDownload': canDownload,
  };
}
