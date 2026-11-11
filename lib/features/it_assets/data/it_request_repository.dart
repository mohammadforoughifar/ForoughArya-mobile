// ============================================================
//  لایهٔ دادهٔ «درخواست خدمت IT» — فاز ۹-ب
//  اندپوینت‌ها عیناً از `Inventory.Api/Controllers/ItAssets/ItRequestsController.cs`
//  (Route: api/itrequests) — برای مسیرهای صفحه‌بندی‌شده، ورودی `take` دارد و
//  سرور پاسخ { total, items } می‌دهد (قرارداد Paging).
// ============================================================

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/it_request_models.dart';

class ItRequestRepository {
  ItRequestRepository(this._api);

  final ApiClient _api;

  static const _base = '/api/itrequests';

  /// صفحه‌بندی کارتابل‌ها — مثل وب (PageSize = ۹)
  static const pageSize = 9;

  // ---------------- دسترسی و گزینه‌ها ----------------

  Future<ItAccess> myAccess() async {
    final r = await _api.get<dynamic>('$_base/my-access');
    final d = r.data;
    return d is Map
        ? ItAccess.fromJson(Map<String, dynamic>.from(d))
        : const ItAccess();
  }

  Future<List<ItSystemOption>> systems() async {
    final r = await _api.get<dynamic>('$_base/systems');
    return _rows(r.data).map(ItSystemOption.fromJson).toList();
  }

  Future<List<ItExpert>> experts() async {
    final r = await _api.get<dynamic>('$_base/experts');
    return _rows(r.data).map(ItExpert.fromJson).toList();
  }

  Future<List<ItClientCompany>> clientCompanies() async {
    final r = await _api.get<dynamic>('$_base/client-companies');
    return _rows(r.data).map(ItClientCompany.fromJson).toList();
  }

  // ---------------- کارتابل‌ها ----------------

  Future<Paged<ItRequestItem>> mine({int skip = 0}) async =>
      _paged('/mine', {'skip': skip, 'take': pageSize});

  Future<Paged<ItRequestItem>> expertInbox({int skip = 0}) async =>
      _paged('/expert', {'skip': skip, 'take': pageSize});

  /// کارتابل مدیر — فیلترهای عیناً مثل وب
  Future<Paged<ItRequestItem>> managerInbox({
    int skip = 0,
    bool onlyExternal = false,
    int? companyId,
    String? search,
  }) async => _paged('/manager', {
    'skip': skip,
    'take': pageSize,
    if (onlyExternal) 'onlyExternal': true,
    if (companyId != null && companyId > 0) 'companyId': companyId,
    if (search != null && search.trim().isNotEmpty) 'q2': search.trim(),
  });

  /// درخواست‌های یک سیستم — `GET by-system/{sysId}`
  Future<Paged<ItRequestItem>> bySystem(int systemId, {int skip = 0}) async =>
      _paged('/by-system/$systemId', {'skip': skip, 'take': pageSize});

  Future<Paged<ItRequestItem>> _paged(
    String path,
    Map<String, dynamic> query,
  ) async {
    final r = await _api.get<dynamic>('$_base$path', query: query);
    final d = r.data;
    if (d is Map) {
      final total = (d['total'] as num?)?.toInt() ?? 0;
      final items = (d['items'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ItRequestItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return Paged(total: total, items: items);
    }
    final items = _rows(d).map(ItRequestItem.fromJson).toList();
    return Paged(total: items.length, items: items);
  }

  // ---------------- ثبت و پیگیری ----------------

  /// ثبت درخواست داخلی — پاسخ: `{ id, number, ... }`
  Future<Map<String, dynamic>> create({
    required String requesterName,
    required String requestType,
    required String title,
    String description = '',
    int? systemInfoId,
    String? systemLabel,
  }) async {
    final r = await _api.post<dynamic>(_base, {
      'requesterName': requesterName,
      'systemInfoId': systemInfoId,
      'systemLabel': systemLabel,
      'requestType': requestType,
      'title': title,
      'description': description,
    });
    final d = r.data;
    return d is Map ? Map<String, dynamic>.from(d) : const {};
  }

  /// نشان‌دار کردن «دیده شد» برای نشانگر «جدید»
  Future<void> markSeen(int id) =>
      _api.post<dynamic>('$_base/$id/seen');

  // ---------------- گردش‌کار مدیر ----------------

  Future<void> assign(
    int id, {
    String? managerNote,
    required List<({int userId, String? instruction})> experts,
  }) => _api.post<dynamic>('$_base/$id/assign', {
    'managerNote': managerNote,
    'experts': [
      for (final e in experts) {'userId': e.userId, 'instruction': e.instruction},
    ],
  });

  /// تصمیم مدیر روی گزارش یک کارشناس
  Future<void> decide(int id, int assignmentId, {required bool approved, String? note}) =>
      _api.post<dynamic>('$_base/$id/assignments/$assignmentId/decide', {
        'approved': approved,
        'note': note,
      });

  /// پاسخ نهایی به درخواست‌کننده (فقط بعد از تایید همهٔ گزارش‌ها)
  Future<void> approve(int id, {String? finalResponse}) =>
      _api.post<dynamic>('$_base/$id/approve', {'finalResponse': finalResponse});

  /// بستن توسط خود مدیر
  Future<void> close(int id, {required String finalResponse}) =>
      _api.post<dynamic>('$_base/$id/close', {'finalResponse': finalResponse});

  /// رد درخواست
  Future<void> reject(int id, {required String reason}) =>
      _api.post<dynamic>('$_base/$id/reject', {'reason': reason});

  // ---------------- کارشناس ----------------

  Future<void> submitReport(int id, {required String report, required bool done}) =>
      _api.post<dynamic>('$_base/$id/report', {'report': report, 'done': done});

  // ---------------- درخواست‌کننده ----------------

  /// تایید و تکمیل توسط درخواست‌کننده (بعد از پاسخ مدیر)
  Future<void> complete(int id) => _api.post<dynamic>('$_base/$id/complete');

  // ---------------- آرشیو و پیوست‌ها ----------------

  Future<List<ItLogRow>> logs(int id) async {
    final r = await _api.get<dynamic>('$_base/$id/logs', query: {'take': 100});
    return _rows(r.data).map(ItLogRow.fromJson).toList();
  }

  Future<List<ItAttachment>> attachments(int id) async {
    final r = await _api.get<dynamic>(
      '$_base/$id/attachments',
      query: {'take': 100},
    );
    return _rows(r.data).map(ItAttachment.fromJson).toList();
  }

  /// آپلود پیوست — `POST {id}/attachments?role=` با فیلد `file`
  Future<void> uploadAttachment(
    int id, {
    required String fileName,
    required List<int> bytes,
    required String role,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    await _api.postForm<dynamic>('$_base/$id/attachments?role=$role', form);
  }

  /// دانلود پیوست (فایل خام)
  Future<List<int>> downloadAttachment(int attachmentId) =>
      _api.getBytes('$_base/attachments/$attachmentId/download');

  static List<Map<String, dynamic>> _rows(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }
}
