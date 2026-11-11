// ============================================================
//  لایهٔ دادهٔ «مدیریت سخت‌افزار» — فاز ۹-الف
//  اندپوینت‌ها عیناً از کنترلرهای وب:
//    GET  api/Dashboard/hardware-stats   (RequirePermission Dashboards.Hardware)
//    POST api/Dashboard/hardware-check   → «بررسی آغاز شد — نتیجه از طریق SignalR پخش می‌شود.»
//    GET  api/itrequests/stats           (بلوک «درخواست‌های خدمت IT — واحد»)
// ============================================================

import '../../../core/network/api_client.dart';
import '../models/hardware_models.dart';

class ItRepository {
  ItRepository(this._api);

  final ApiClient _api;

  /// آمار سخت‌افزار (آنلاین/آفلاین از آخرین پویش)
  Future<HardwareStats> hardwareStats() async {
    final r = await _api.get<dynamic>('/api/Dashboard/hardware-stats');
    final d = r.data;
    if (d is Map) return HardwareStats.fromJson(Map<String, dynamic>.from(d));
    return const HardwareStats();
  }

  /// اجرای فوری یک دور پینگ همهٔ دستگاه‌ها
  Future<String> requestHardwareCheck() async {
    final r = await _api.post<dynamic>('/api/Dashboard/hardware-check');
    final d = r.data;
    if (d is Map && d['message'] != null) return d['message'].toString();
    return 'بررسی آغاز شد — نتیجه از طریق SignalR پخش می‌شود.';
  }

  /// آمار درخواست‌های خدمت IT برای نمودار داشبورد
  Future<ItStats> itStats() async {
    final r = await _api.get<dynamic>('/api/itrequests/stats');
    final d = r.data;
    if (d is Map) return ItStats.fromJson(Map<String, dynamic>.from(d));
    return const ItStats();
  }
}
