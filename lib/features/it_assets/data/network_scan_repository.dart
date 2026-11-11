// ============================================================
//  لایهٔ دادهٔ «اسکن شبکه» — فاز ۹-ز
//  اندپوینت‌ها عیناً از کنترلرهای وب:
//    POST api/NetworkScan/start  { range }       → { jobId, targetCount, range, localIp }
//    GET  api/NetworkScan/status/{jobId}         → ScanStatus (زنده)
//    GET  api/CctvScan                           → CctvScanResult
//  نکته: پارامتر range «auto» یا متن رنج دستی است؛ خالی هم یعنی auto.
// ============================================================

import '../../../core/network/api_client.dart';
import '../models/network_scan_models.dart';

class NetworkScanRepository {
  NetworkScanRepository(this._api);

  final ApiClient _api;

  /// شروع اسکن — پیام خطای سرور عیناً برگردانده می‌شود
  Future<ScanStartResult> start(String range) async {
    final r = await _api.post<dynamic>('/api/NetworkScan/start', {
      'range': range,
    });
    final d = r.data;
    return d is Map
        ? ScanStartResult.fromJson(Map<String, dynamic>.from(d))
        : const ScanStartResult();
  }

  Future<ScanStatus> status(String jobId) async {
    final r = await _api.get<dynamic>('/api/NetworkScan/status/$jobId');
    final d = r.data;
    return d is Map
        ? ScanStatus.fromJson(Map<String, dynamic>.from(d))
        : const ScanStatus();
  }

  /// اسکن دوربین و NVR — ممکن است ۱۰ تا ۳۰ ثانیه طول بکشد
  Future<CctvScanResult> scanCctv() async {
    final r = await _api.get<dynamic>('/api/CctvScan');
    final d = r.data;
    return d is Map
        ? CctvScanResult.fromJson(Map<String, dynamic>.from(d))
        : const CctvScanResult();
  }
}
