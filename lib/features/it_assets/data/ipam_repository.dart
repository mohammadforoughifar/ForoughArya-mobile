// ============================================================
//  لایهٔ دادهٔ «مدیریت آی‌پی» (IPAM) — فاز ۹-د
//  اندپوینت‌ها عیناً از `Inventory.Api/Controllers/ItAssets/IpamController.cs`
//  (Route: api/ipam)
//    GET  companies · subnets?companyId
//    POST subnets · PUT subnets/{id} · DELETE subnets/{id}
//    GET  subnets/{id}/map · POST subnets/{id}/scan · GET subnets/{id}/scan
//    POST subnets/{id}/probe · PUT subnets/{id}/reserve · DELETE subnets/{id}/reserve?ip=
// ============================================================

import '../../../core/network/api_client.dart';
import '../models/ipam_models.dart';

class IpamRepository {
  IpamRepository(this._api);

  final ApiClient _api;

  static const _base = '/api/ipam';

  Future<List<IpamCompanyRow>> companies() async {
    final r = await _api.get<dynamic>('$_base/companies');
    final d = r.data;
    return (d is List ? d : const [])
        .whereType<Map>()
        .map((e) => IpamCompanyRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<IpSubnetRow>> subnets(int companyId) async {
    final r = await _api.get<dynamic>(
      '$_base/subnets',
      query: {'companyId': companyId},
    );
    final d = r.data;
    return (d is List ? d : const [])
        .whereType<Map>()
        .map((e) => IpSubnetRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<IpamMap> map(int subnetId) async {
    final r = await _api.get<dynamic>('$_base/subnets/$subnetId/map');
    final d = r.data;
    if (d is Map) return IpamMap.fromJson(Map<String, dynamic>.from(d));
    throw Exception('نقشهٔ رنج خوانده نشد.');
  }

  Future<int> createSubnet(IpSubnetSaveRequest req) async {
    final r = await _api.post<dynamic>('$_base/subnets', req.toJson());
    final d = r.data;
    if (d is Map && d['id'] != null) return (d['id'] as num).toInt();
    return 0;
  }

  Future<void> updateSubnet(int id, IpSubnetSaveRequest req) =>
      _api.put<dynamic>('$_base/subnets/$id', req.toJson());

  Future<void> deleteSubnet(int id) =>
      _api.delete<dynamic>('$_base/subnets/$id');

  /// شروع اسکن — پاسخ `{ started, scan }`
  Future<bool> startScan(int id) async {
    final r = await _api.post<dynamic>('$_base/subnets/$id/scan');
    final d = r.data;
    if (d is Map) return d['started'] == true;
    return false;
  }

  Future<IpamScanStatus?> scanStatus(int id) async {
    try {
      final r = await _api.get<dynamic>('$_base/subnets/$id/scan');
      final d = r.data;
      if (d is Map) return IpamScanStatus.fromJson(Map<String, dynamic>.from(d));
    } catch (_) {}
    return null;
  }

  Future<IpProbeResult> probe(int id, String ip) async {
    final r = await _api.post<dynamic>(
      '$_base/subnets/$id/probe',
      {'ip': ip},
    );
    final d = r.data;
    return d is Map
        ? IpProbeResult.fromJson(Map<String, dynamic>.from(d))
        : const IpProbeResult();
  }

  Future<void> reserve(int id, IpReserveRequest req) =>
      _api.put<dynamic>('$_base/subnets/$id/reserve', req.toJson());

  Future<void> unreserve(int id, String ip) => _api.delete<dynamic>(
    '$_base/subnets/$id/reserve?ip=${Uri.encodeQueryComponent(ip)}',
  );
}
