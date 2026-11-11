// ============================================================
//  لایهٔ دادهٔ «مدیریت سرورها» — فاز ۹-د
//  اندپوینت‌ها عیناً از `Inventory.Api/Controllers/ItAssets/ServersController.cs`
//  (Route: api/servers)
//    GET  companies · credentials?companyId · responsibles?companyId
//    GET  ?companyId&q · {id} · {id}/hardware · alerts?companyId&includeResolved&take
//    POST · PUT {id} · DELETE {id}
//    POST {id}/test · {id}/collect
//    GET  {id}/certificate · POST {id}/certificate/trust · DELETE {id}/certificate
//    POST alerts/{id}/acknowledge · alerts/{id}/resolve · alerts/{id}/work-order
// ============================================================

import '../../../core/network/api_client.dart';
import '../models/server_models.dart';

class ServerRepository {
  ServerRepository(this._api);

  final ApiClient _api;

  static const _base = '/api/servers';

  Future<List<ServerCompanyRow>> companies() async {
    final r = await _api.get<dynamic>('$_base/companies');
    final d = r.data;
    return (d is List ? d : const [])
        .whereType<Map>()
        .map((e) => ServerCompanyRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Credentialهای فعال نوع Server — «فقط برای مالک مجوز گاوصندوق»
  Future<List<ServerCredentialRow>> credentials(int companyId) async {
    final r = await _api.get<dynamic>(
      '$_base/credentials',
      query: {'companyId': companyId},
    );
    final d = r.data;
    return (d is List ? d : const [])
        .whereType<Map>()
        .map((e) => ServerCredentialRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ServerResponsibleRow>> responsibles(int companyId) async {
    final r = await _api.get<dynamic>(
      '$_base/responsibles',
      query: {'companyId': companyId},
    );
    final d = r.data;
    return (d is List ? d : const [])
        .whereType<Map>()
        .map((e) => ServerResponsibleRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ServerRow>> servers({
    required int companyId,
    String? q,
  }) async {
    final r = await _api.get<dynamic>(
      _base,
      query: {
        'companyId': companyId,
        if ((q ?? '').trim().isNotEmpty) 'q': q!.trim(),
      },
    );
    final d = r.data;
    return (d is List ? d : const [])
        .whereType<Map>()
        .map((e) => ServerRow.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<ServerRow?> server(int id) async {
    final r = await _api.get<dynamic>('$_base/$id');
    final d = r.data;
    if (d is Map) {
      final inner = d['server'];
      if (inner is Map) {
        return ServerRow.fromJson(Map<String, dynamic>.from(inner));
      }
      if (d['id'] != null) return ServerRow.fromJson(Map<String, dynamic>.from(d));
    }
    return null;
  }

  Future<ServerHardware?> hardware(int id) async {
    try {
      final r = await _api.get<dynamic>('$_base/$id/hardware');
      final d = r.data;
      if (d is Map) return ServerHardware.fromJson(Map<String, dynamic>.from(d));
    } catch (_) {}
    return null;
  }

  Future<List<ServerAlertRow>> alerts({
    required int companyId,
    bool includeResolved = false,
    int take = 100,
  }) async {
    final r = await _api.get<dynamic>(
      '$_base/alerts',
      query: {
        'companyId': companyId,
        'includeResolved': includeResolved,
        'take': take,
      },
    );
    final d = r.data;
    return (d is List ? d : const [])
        .whereType<Map>()
        .map((e) => ServerAlertRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> save({required ServerSaveRequest req, int? id}) async {
    if (id != null && id > 0) {
      await _api.put<dynamic>('$_base/$id', req.toJson());
    } else {
      await _api.post<dynamic>(_base, req.toJson());
    }
  }

  Future<void> delete(int id) => _api.delete<dynamic>('$_base/$id');

  /// تست اتصال امن Redfish — `POST {id}/test`
  Future<void> testConnection(int id) => _api.post<dynamic>('$_base/$id/test');

  /// دریافت Inventory و سلامت — `POST {id}/collect`
  Future<void> collect(int id) => _api.post<dynamic>('$_base/$id/collect');

  Future<IloCertificateCheck> certificate(int id) async {
    final r = await _api.get<dynamic>('$_base/$id/certificate');
    final d = r.data;
    return d is Map
        ? IloCertificateCheck.fromJson(Map<String, dynamic>.from(d))
        : const IloCertificateCheck(error: 'گواهی iLO خوانده نشد.');
  }

  Future<void> trustCertificate(int id, String thumbprint) =>
      _api.post<dynamic>('$_base/$id/certificate/trust', {
        'thumbprint': thumbprint,
      });

  Future<void> untrustCertificate(int id) =>
      _api.delete<dynamic>('$_base/$id/certificate');

  Future<void> acknowledgeAlert(int id) =>
      _api.post<dynamic>('$_base/alerts/$id/acknowledge');

  Future<void> resolveAlert(int id) =>
      _api.post<dynamic>('$_base/alerts/$id/resolve');

  /// ایجاد دستور کار از هشدار — پاسخ `{ id, number, existing }`
  Future<Map<String, dynamic>> createWorkOrderFromAlert(int id) async {
    final r = await _api.post<dynamic>('$_base/alerts/$id/work-order');
    final d = r.data;
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }
}
