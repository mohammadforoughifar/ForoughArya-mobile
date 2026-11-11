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
