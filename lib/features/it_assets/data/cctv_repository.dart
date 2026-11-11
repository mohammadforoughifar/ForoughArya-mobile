// ============================================================
//  لایهٔ دادهٔ «دوربین‌های مداربسته» و «NVR/DVR» — فاز ۹-و
//  اندپوینت‌ها عیناً از کنترلرهای وب:
//    GET    api/CctvCameras?q&skip&take      · GET {id}
//    POST   api/CctvCameras                  · PUT {id} · DELETE {id}
//    GET    api/CctvCameras/import-template  → فایل xlsx قالب
//    GET    api/CctvCameras/export?q         → فایل xlsx خروجی
//    POST   api/CctvCameras/import-excel     (multipart: file)
//    GET    api/CctvNvrs?q&skip&take         · GET {id} · GET {id}/cameras
//    POST   api/CctvNvrs                     · PUT {id} · DELETE {id}
//  نکته: پاسخ فهرست‌ها بدون صفحه‌بندی «آرایه» و با skip/take
//        «{ total, items }» است (Paging.ResultAsync).
// ============================================================

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/cctv_models.dart';

class CctvRepository {
  CctvRepository(this._api);

  final ApiClient _api;

  static const _cameras = '/api/CctvCameras';
  static const _nvrs = '/api/CctvNvrs';

  /// استخراج فهرست از پاسخ ساده یا صفحه‌بندی‌شدهٔ سرور
  static List<Map<String, dynamic>> _listOf(dynamic d) {
    if (d is List) {
      return d
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (d is Map && d['items'] is List) {
      return (d['items'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  // ---------------- دوربین‌ها ----------------

  Future<List<CctvCameraRow>> cameras({String? q}) async {
    final r = await _api.get<dynamic>(
      _cameras,
      query: {
        if ((q ?? '').trim().isNotEmpty) 'q': q!.trim(),
      },
    );
    return _listOf(r.data).map(CctvCameraRow.fromJson).toList();
  }

  Future<void> saveCamera(CctvCameraForm f) async {
    if (f.id > 0) {
      await _api.put<dynamic>('$_cameras/${f.id}', f.toJson());
    } else {
      await _api.post<dynamic>(_cameras, f.toJson());
    }
  }

  Future<void> deleteCamera(int id) => _api.delete<dynamic>('$_cameras/$id');

  /// قالب اکسل ورود گروهی — همان فایل `CctvCameras-Template.xlsx`
  Future<List<int>> cameraTemplate() =>
      _api.getBytes('$_cameras/import-template');

  /// خروجی اکسل دوربین‌ها
  Future<List<int>> cameraExport({String? q}) => _api.getBytes(
    '$_cameras/export',
    query: {if ((q ?? '').trim().isNotEmpty) 'q': q!.trim()},
  );

  /// ورود گروهی از اکسل — پاسخ `{ inserted, skipped, errors[] }`
  Future<CctvImportResult> importCameras(
    List<int> bytes,
    String fileName,
  ) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    final r = await _api.postForm<dynamic>('$_cameras/import-excel', form);
    final d = r.data;
    return d is Map
        ? CctvImportResult.fromJson(Map<String, dynamic>.from(d))
        : const CctvImportResult();
  }

  // ---------------- دستگاه‌های NVR ----------------

  Future<List<CctvNvrRow>> nvrs({String? q}) async {
    final r = await _api.get<dynamic>(
      _nvrs,
      query: {
        if ((q ?? '').trim().isNotEmpty) 'q': q!.trim(),
      },
    );
    return _listOf(r.data).map(CctvNvrRow.fromJson).toList();
  }

  Future<void> saveNvr(CctvNvrForm f) async {
    if (f.id > 0) {
      await _api.put<dynamic>('$_nvrs/${f.id}', f.toJson());
    } else {
      await _api.post<dynamic>(_nvrs, f.toJson());
    }
  }

  Future<void> deleteNvr(int id) => _api.delete<dynamic>('$_nvrs/$id');

  /// دوربین‌های متصل به یک NVR — `GET api/CctvNvrs/{id}/cameras`
  Future<List<CctvCameraRow>> nvrCameras(int id) async {
    final r = await _api.get<dynamic>('$_nvrs/$id/cameras');
    return _listOf(r.data).map(CctvCameraRow.fromJson).toList();
  }
}
