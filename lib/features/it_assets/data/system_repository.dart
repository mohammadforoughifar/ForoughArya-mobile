// ============================================================
//  لایهٔ دادهٔ «سیستم‌های ثبت‌شده / شناسنامه / ثبت دستی / کاربران سیستم» — فاز ۹-ج
//  اندپوینت‌ها عیناً از:
//    • `Inventory.Api/Controllers/ItAssets/SystemInfoController.cs` → api/SystemInfo
//    • `Inventory.Api/Controllers/System/SystemUsersController.cs`  → api/SystemUsers
//    • api/SystemCompanies · api/SystemDepartments · api/SystemOrganizations
//  (وب همین مسیرها را با `/api/SystemInfo/...` صدا می‌زند؛ مسیرها در ASP.NET
//   غیرحساس به بزرگی/کوچکی حرف‌اند.)
// ============================================================

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show Uint8List;

import '../../../core/network/api_client.dart';
import '../models/system_models.dart';

class SystemRepository {
  SystemRepository(this._api);

  final ApiClient _api;

  static const _base = '/api/SystemInfo';
  static const _users = '/api/SystemUsers';

  // ---------------- سیستم‌ها ----------------

  /// فهرست کامل — وب `GET /api/SystemInfo` را بدون paging صدا می‌زند و
  /// همه را یک‌جا بارگذاری می‌کند (همان رفتار، برای نمودارها و گروه‌بندی شرکت).
  Future<List<SystemInfoItem>> systems() async {
    final r = await _api.get<dynamic>(_base);
    return asRows(r.data).map(SystemInfoItem.fromJson).toList()
      ..sort((a, b) {
        final ad = a.receivedAt?.millisecondsSinceEpoch ?? 0;
        final bd = b.receivedAt?.millisecondsSinceEpoch ?? 0;
        return bd.compareTo(ad);
      });
  }

  /// تک‌سیستم — `GET /api/SystemInfo/{id}` (اگر ۴۰۴ داد null)
  Future<SystemInfoItem?> system(int id) async {
    try {
      final r = await _api.get<dynamic>('$_base/$id');
      final d = r.data;
      if (d is Map && (d['id'] != null || d['agentId'] != null)) {
        return SystemInfoItem.fromJson(asMap(d));
      }
      return null;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// قطعات سخت‌افزاری — `GET /api/SystemInfo/{id}/components`
  Future<SystemComponents?> components(int id) async {
    try {
      final r = await _api.get<dynamic>('$_base/$id/components');
      final d = r.data;
      if (d is! Map) return null;
      final c = SystemComponents.fromJson(asMap(d));
      return c.hasAny ? c : null;
    } catch (_) {
      return null;
    }
  }

  /// امتیاز سلامت — `GET /api/SystemInfo/health/{id}`
  Future<SystemHealth?> health(int id) async {
    try {
      final r = await _api.get<dynamic>('$_base/health/$id');
      final d = r.data;
      if (d is Map && d['score'] != null) return SystemHealth.fromJson(asMap(d));
      return null;
    } catch (_) {
      return null;
    }
  }

  /// تغییرات در انتظار تایید — `GET /api/SystemInfo/changes/{id}`
  Future<PendingChanges> changes(int id) async {
    try {
      final r = await _api.get<dynamic>('$_base/changes/$id');
      final d = r.data;
      if (d is Map) return PendingChanges.fromJson(asMap(d));
    } catch (_) {}
    return const PendingChanges();
  }

  /// تایید و جایگزینی اطلاعات جدید — `POST /api/SystemInfo/apply/{id}`
  Future<void> applyChanges(int id) =>
      _api.post<dynamic>('$_base/apply/$id');

  /// رد کردن تغییرات — `POST /api/SystemInfo/discard/{id}`
  Future<void> discardChanges(int id) =>
      _api.post<dynamic>('$_base/discard/$id');

  /// تاریخچهٔ تغییرات — `GET /api/SystemInfo/history/{id}`
  Future<List<SystemHistoryEntry>> history(int id) async {
    try {
      final r = await _api.get<dynamic>('$_base/history/$id');
      return asRows(r.data).map(SystemHistoryEntry.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  /// تأیید سیستم — `POST /api/SystemInfo/approve/{id}`
  Future<void> approve(int id) => _api.post<dynamic>('$_base/approve/$id');

  /// حذف رکورد سیستم — `DELETE /api/SystemInfo/{id}`
  Future<void> delete(int id) => _api.delete<dynamic>('$_base/$id');

  /// ثبت دستی — `POST /api/SystemInfo/manual`
  Future<void> createManual(ManualSystemRequest req) =>
      _api.post<dynamic>('$_base/manual', req.toJson());

  /// شناسنامه PDF — `GET /api/SystemInfo/{id}/pdf` → `System-Identity-{id}.pdf`
  Future<Uint8List> pdf(int id) => _api.getBytes('$_base/$id/pdf');

  // ---------------- کاربر سیستم ----------------

  /// اختصاص کاربر — `POST /api/SystemInfo/assign-user`
  Future<void> assignUser({required int systemInfoId, required int userId}) =>
      _api.post<dynamic>('$_base/assign-user', {
        'systemInfoId': systemInfoId,
        'userId': userId,
      });

  /// تاریخچهٔ کاربران سیستم — `GET /api/SystemInfo/user-history/{id}`
  Future<List<SystemUserHistoryRow>> userHistory(int id) async {
    try {
      final r = await _api.get<dynamic>('$_base/user-history/$id');
      return asRows(r.data).map(SystemUserHistoryRow.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  // ---------------- تحویل دیجیتال ----------------

  /// ثبت تحویل با امضا — `POST /api/SystemInfo/handover/{id}`
  Future<void> handover({
    required int id,
    required String fromUserName,
    required int toUserId,
    required String toUserName,
    required List<HandoverCheck> checklist,
    required String signatureDataUrl,
    String? note,
  }) => _api.post<dynamic>('$_base/handover/$id', {
    'fromUserName': fromUserName,
    'toUserId': toUserId,
    'toUserName': toUserName,
    'checklist': [
      for (final c in checklist) {'key': c.key, 'fa': c.fa, 'checked': c.checked},
    ],
    'signatureDataUrl': signatureDataUrl,
    'note': note,
  });

  /// فهرست تحویل‌ها — `GET /api/SystemInfo/handovers/{id}`
  Future<List<SystemHandover>> handovers(int id) async {
    try {
      final r = await _api.get<dynamic>('$_base/handovers/$id');
      return asRows(r.data).map(SystemHandover.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  // ---------------- دستور از راه دور ----------------

  /// ارسال دستور — `POST /api/SystemInfo/commands/{id}` (`Reboot|Shutdown|Lock`)
  Future<void> sendCommand({
    required int id,
    required String action,
    required String byUserName,
  }) => _api.post<dynamic>('$_base/commands/$id', {
    'action': action,
    'byUserName': byUserName,
  });

  /// فهرست دستورها — `GET /api/SystemInfo/commands/{id}`
  Future<List<RemoteCommandRow>> commands(int id) async {
    try {
      final r = await _api.get<dynamic>('$_base/commands/$id');
      return asRows(r.data).map(RemoteCommandRow.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  // ---------------- پایه‌ها ----------------

  Future<List<SystemUserRow>> users() async {
    final r = await _api.get<dynamic>(_users);
    return asRows(r.data).map(SystemUserRow.fromJson).toList();
  }

  Future<List<SystemCompanyRow>> companies() async {
    try {
      final r = await _api.get<dynamic>('/api/SystemCompanies');
      return asRows(r.data).map(SystemCompanyRow.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<SystemDepartmentRow>> departments() async {
    try {
      final r = await _api.get<dynamic>('/api/SystemDepartments');
      return asRows(r.data).map(SystemDepartmentRow.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<SystemOrganizationRow>> organizations({int? companyId}) async {
    try {
      final r = await _api.get<dynamic>(
        '/api/SystemOrganizations',
        query: {
          if (companyId != null && companyId > 0) 'companyId': companyId,
        },
      );
      return asRows(r.data).map(SystemOrganizationRow.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  /// افزودن/ویرایش کاربر — وب: `POST /api/SystemUsers` و `PUT /api/SystemUsers/{id}`
  Future<int> saveUser(SystemUserRow u) async {
    if (u.id > 0) {
      await _api.put<dynamic>('$_users/${u.id}', u.toPayload());
      return u.id;
    }
    final r = await _api.post<dynamic>(_users, u.toPayload());
    final d = r.data;
    if (d is Map && d['id'] != null) return (d['id'] as num).toInt();
    return 0;
  }

  Future<void> deleteUser(int id) => _api.delete<dynamic>('$_users/$id');

  /// آپلود عکس کاربر — وب: `POST /api/SystemUsers/photo/{id}` با فرم‌فیلد `file`
  Future<void> uploadUserPhoto({
    required int userId,
    required String fileName,
    required List<int> bytes,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    await _api.postForm<dynamic>('$_users/photo/$userId', form);
  }

  /// آدرس عکس کاربر (برای نمایش) — `GET /api/SystemUsers/photo/{id}`
  String photoUrl(int userId) {
    final base = _api.baseUrl.trim();
    final clean = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    return '$clean/api/SystemUsers/photo/$userId';
  }
}
