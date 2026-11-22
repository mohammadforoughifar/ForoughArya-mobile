import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../models/moadian_models.dart';

/// کلاینت کامل API برای زیرسیستم «مودیان تیسا» — ۱۰۰٪ منطبق بر `MoadianController.cs` و `MoadianService.cs` وب.
class MoadianRepository {
  MoadianRepository(this._api, [FlutterSecureStorage? storage])
    : _storage = storage ?? _api.storage;

  final ApiClient _api;
  final FlutterSecureStorage _storage;

  Options _opts([int? cpInfoId]) => Options(
    headers: {
      if (cpInfoId != null && cpInfoId > 0)
        'X-Moadian-CpInfo': cpInfoId.toString(),
    },
  );

  /// نرمال‌سازی پاسخ `ApiModel` سرور (شامل محافظت در برابر باگ سرور که روی `Status=500` در اصلاحی/ابطالی `Success=true` می‌فرستد).
  MoadianApiResult _unwrap(dynamic raw) {
    final parsed = MoadianApiResult.fromJson(raw);
    if (parsed.status >= 400 && parsed.success) {
      return MoadianApiResult(
        success: false,
        status: parsed.status,
        message: parsed.message ?? 'خطا در ارتباط با سامانه مودیان.',
        data: parsed.data,
        deliveryUncertain: parsed.deliveryUncertain,
        requestJson: parsed.requestJson,
        responseJson: parsed.responseJson,
      );
    }
    return parsed;
  }

  T _must<T>(MoadianApiResult r, T Function(dynamic data) convert, String what) {
    if (!r.success) {
      throw ApiException(
        r.message?.trim().isNotEmpty == true
            ? r.message!
            : '$what ناموفق بود (کد ${r.status}).',
        r.status,
      );
    }
    return convert(r.data);
  }

  // ==================== ذخیره و بازیابی شرکت فعال مودیان ====================

  static final Map<int, int> _memActiveCpInfo = {};

  Future<int?> loadSavedCpInfoId() async {
    final cid = _api.companyId ?? 0;
    final mem = _memActiveCpInfo[cid];
    if (mem != null && mem > 0) return mem;
    try {
      final raw = await _storage.read(key: 'moadian_active_cpinfo_$cid');
      final parsed = raw == null ? null : int.tryParse(raw);
      if (parsed != null && parsed > 0) {
        _memActiveCpInfo[cid] = parsed;
      }
      return parsed;
    } catch (_) {
      return mem;
    }
  }

  Future<void> saveActiveCpInfoId(int cpInfoId) async {
    final cid = _api.companyId ?? 0;
    if (cpInfoId <= 0) {
      _memActiveCpInfo.remove(cid);
    } else {
      _memActiveCpInfo[cid] = cpInfoId;
    }
    try {
      if (cpInfoId <= 0) {
        await _storage.delete(key: 'moadian_active_cpinfo_$cid');
      } else {
        await _storage.write(
          key: 'moadian_active_cpinfo_$cid',
          value: cpInfoId.toString(),
        );
      }
    } catch (_) {}
  }

  // ==================== ۱. شرکت‌ها و سال مالی ====================

  Future<List<MoadianCpInfo>> getCpInfos({int? companyId}) async {
    final cid = companyId ?? _api.companyId;
    final r = await _api.get<dynamic>(
      'Moadian/GetCpInfos',
      query: {if (cid != null && cid > 0) 'companyId': cid},
    );
    return _must(_unwrap(r.data), (d) {
      if (d is! List) return const <MoadianCpInfo>[];
      return d
          .whereType<Map>()
          .map((e) => MoadianCpInfo.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }, 'دریافت فهرست شرکت‌های مودیان');
  }

  Future<MoadianApiResult> saveCpInfo(MoadianCpInfo info) async {
    final cid = info.companyId ?? _api.companyId;
    final payload = MoadianCpInfo(
      cpInfoId: info.cpInfoId,
      companyId: cid,
      persianName: info.persianName,
      englishName: info.englishName,
      nationalId: info.nationalId,
      economicNumber: info.economicNumber,
      type: info.type,
      postalCode: info.postalCode,
    ).toJson();
    final r = await _api.request<dynamic>(
      'POST',
      'Moadian/SaveCpInfo',
      data: payload,
      options: _opts(info.cpInfoId),
    );
    return _unwrap(r.data);
  }

  Future<MoadianApiResult> deleteCpInfo(int id) async {
    final r = await _api.delete<dynamic>('Moadian/DeleteCpInfo/$id');
    return _unwrap(r.data);
  }

  Future<List<MoadianFiscalYear>> getFiscalYears(int cpInfoId) async {
    final r = await _api.get<dynamic>(
      'Moadian/GetFiscalYears/$cpInfoId',
      options: _opts(cpInfoId),
    );
    return _must(_unwrap(r.data), (d) {
      if (d is! List) return const <MoadianFiscalYear>[];
      return d
          .whereType<Map>()
          .map((e) => MoadianFiscalYear.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }, 'دریافت سال‌های مالی');
  }

  Future<MoadianApiResult> saveFiscalYear(MoadianFiscalYear fy) async {
    final r = await _api.request<dynamic>(
      'POST',
      'Moadian/SaveFiscalYear',
      data: fy.toJson(),
      options: _opts(fy.cpInfoId),
    );
    return _unwrap(r.data);
  }

  // ==================== ۲. اتصال به سامانه مودیان ====================

  Future<MoadianConnection?> getConnection(int cpInfoId) async {
    final r = await _api.get<dynamic>(
      'Moadian/GetConnectForCpInfo/$cpInfoId',
      options: _opts(cpInfoId),
    );
    final res = _unwrap(r.data);
    if (!res.success) {
      throw ApiException(
        res.message ?? 'خطا در دریافت تنظیمات اتصال.',
        res.status,
      );
    }
    if (res.data is Map) {
      return MoadianConnection.fromJson(Map<String, dynamic>.from(res.data));
    }
    return null;
  }

  Future<MoadianApiResult> saveConnection(MoadianConnection conn) async {
    final r = await _api.request<dynamic>(
      'POST',
      'Moadian/ConnectionApiAsync',
      data: conn.toJson(),
      options: _opts(conn.cpInfoId),
    );
    return _unwrap(r.data);
  }

  Future<MoadianApiResult> testConnection(MoadianConnection conn) async {
    final r = await _api.request<dynamic>(
      'POST',
      'Moadian/GetIsConnectToMoadian',
      data: conn.toJson(),
      options: _opts(conn.cpInfoId),
    );
    return _unwrap(r.data);
  }

  // ==================== ۳. مشتریان، کالاها و واحدهای سنجش ====================

  Future<List<MoadianCustomer>> getCustomers(int cpInfoId) async {
    final r = await _api.get<dynamic>(
      'Moadian/GetAllCostomer',
      query: {'cpinfoid': cpInfoId},
      options: _opts(cpInfoId),
    );
    return _must(_unwrap(r.data), (d) {
      if (d is! List) return const <MoadianCustomer>[];
      return d
          .whereType<Map>()
          .map((e) => MoadianCustomer.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }, 'دریافت فهرست مشتریان');
  }

  Future<MoadianApiResult> insertCustomer(MoadianCustomer c) async {
    final r = await _api.request<dynamic>(
      'POST',
      'Moadian/InsertCustomerAsync',
      data: c.toJson(),
      options: _opts(c.cpInfoId),
    );
    return _unwrap(r.data);
  }

  Future<MoadianApiResult> updateCustomer(MoadianCustomer c) async {
    final r = await _api.request<dynamic>(
      'PUT',
      'Moadian/UpdateCustomer',
      data: c.toJson(),
      options: _opts(c.cpInfoId),
    );
    return _unwrap(r.data);
  }

  Future<MoadianPagedList<MoadianGood>> getGoods({
    required int cpInfoId,
    String search = '',
    int page = 1,
    int pageSize = 15,
  }) async {
    final r = await _api.get<dynamic>(
      'Moadian/GetGoodOrService',
      query: {
        'cpinfoId': cpInfoId,
        'searchTerm': search,
        'page': page,
        'pageSize': pageSize,
      },
      options: _opts(cpInfoId),
    );
    return _must(_unwrap(r.data), (d) {
      if (d is Map) {
        return MoadianPagedList.fromJson(
          Map<String, dynamic>.from(d),
          MoadianGood.fromJson,
        );
      }
      return MoadianPagedList.empty();
    }, 'دریافت فهرست کالا و خدمات');
  }

  Future<List<MoadianGood>> getGoodsCombo(int cpInfoId) async {
    final r = await _api.get<dynamic>(
      'Moadian/GetGoodOrServiceForComboAsync',
      query: {'cpinfoid': cpInfoId},
      options: _opts(cpInfoId),
    );
    return _must(_unwrap(r.data), (d) {
      if (d is! List) return const <MoadianGood>[];
      return d
          .whereType<Map>()
          .map((e) => MoadianGood.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }, 'دریافت فهرست کالاها');
  }

  Future<MoadianApiResult> insertGood(MoadianGood g) async {
    final r = await _api.request<dynamic>(
      'POST',
      'Moadian/InsertGoodOrServiceAsync',
      data: g.toJson(),
      options: _opts(g.cpInfoId),
    );
    return _unwrap(r.data);
  }

  Future<MoadianApiResult> updateGood(MoadianGood g) async {
    final r = await _api.request<dynamic>(
      'PUT',
      'Moadian/UpdateGoodOrService',
      data: g.toJson(),
      options: _opts(g.cpInfoId),
    );
    return _unwrap(r.data);
  }

  Future<MoadianPagedList<MoadianUnit>> getUnits({
    required int cpInfoId,
    String search = '',
    int page = 1,
    int pageSize = 20,
  }) async {
    final r = await _api.get<dynamic>(
      'Moadian/GetAllUnitOfMeasurementAsync',
      query: {
        'cpinfoid': cpInfoId,
        'searchTerm': search,
        'page': page,
        'pageSize': pageSize,
      },
      options: _opts(cpInfoId),
    );
    return _must(_unwrap(r.data), (d) {
      if (d is Map) {
        return MoadianPagedList.fromJson(
          Map<String, dynamic>.from(d),
          MoadianUnit.fromJson,
        );
      }
      return MoadianPagedList.empty();
    }, 'دریافت واحدهای سنجش');
  }

  Future<List<MoadianUnit>> getUnitsCombo(int cpInfoId) async {
    final r = await _api.get<dynamic>(
      'Moadian/GetUnitOfMeasurementForComboAsync',
      query: {'cpinfoid': cpInfoId},
      options: _opts(cpInfoId),
    );
    return _must(_unwrap(r.data), (d) {
      if (d is! List) return const <MoadianUnit>[];
      return d
          .whereType<Map>()
          .map((e) => MoadianUnit.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }, 'دریافت واحدهای سنجش');
  }

  Future<MoadianApiResult> insertUnit(MoadianUnit u) async {
    final r = await _api.request<dynamic>(
      'POST',
      'Moadian/InsertUnitOfMeasurementAsync',
      data: u.toJson(),
      options: _opts(u.cpInfoId),
    );
    return _unwrap(r.data);
  }

  Future<MoadianApiResult> updateUnit(MoadianUnit u) async {
    final r = await _api.request<dynamic>(
      'PUT',
      'Moadian/UpdateUnitOfMeasurementAsync',
      data: u.toJson(),
      options: _opts(u.cpInfoId),
    );
    return _unwrap(r.data);
  }

  Future<MoadianApiResult> deleteUnit(int unitId, {int? cpInfoId}) async {
    final r = await _api.request<dynamic>(
      'DELETE',
      'Moadian/$unitId',
      options: _opts(cpInfoId),
    );
    return _unwrap(r.data);
  }

  // ==================== ۴. چرخهٔ کامل صورتحساب الکترونیکی ====================

  Future<int?> nextInvoiceNumber(int cpInfoId) async {
    final r = await _api.get<dynamic>(
      'Moadian/NextInvoiceNumber',
      query: {'cpinfoId': cpInfoId},
      options: _opts(cpInfoId),
    );
    final res = _unwrap(r.data);
    if (!res.success || res.data == null) return null;
    if (res.data is num) return (res.data as num).toInt();
    return int.tryParse(res.data.toString());
  }

  Future<MoadianInvoicePageResult> getInvoices({
    required int cpInfoId,
    String operation = 'همه',
    DateTime? firstDate,
    DateTime? endDate,
    String search = '',
    int page = 1,
    int pageSize = 15,
  }) async {
    String fmtDt(DateTime d, {bool endOfDay = false}) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')} '
        '${endOfDay ? '23:59:59' : '00:00:00'}';

    final hasRange = firstDate != null && endDate != null;
    final r = await _api.get<dynamic>(
      'Moadian/GetAllInvoice',
      query: {
        'operation': operation,
        'CpinfoId': cpInfoId,
        'firstDate': hasRange ? fmtDt(firstDate) : '',
        'endDate': hasRange ? fmtDt(endDate, endOfDay: true) : '',
        'searchTerm': search,
        'page': page,
        'pageSize': pageSize,
      },
      options: _opts(cpInfoId),
    );
    return _must(_unwrap(r.data), (d) {
      if (d is! Map) {
        return MoadianInvoicePageResult(
          invoices: MoadianPagedList.empty(),
          labels: const MoadianInvoiceLabels(),
        );
      }
      final m = Map<String, dynamic>.from(d);
      final invMap = (m['invoices'] ?? m['Invoices']);
      final lblMap = (m['labels'] ?? m['Labels']);
      return MoadianInvoicePageResult(
        invoices: invMap is Map
            ? MoadianPagedList.fromJson(
                Map<String, dynamic>.from(invMap),
                MoadianInvoice.fromJson,
              )
            : MoadianPagedList.empty(),
        labels: lblMap is Map
            ? MoadianInvoiceLabels.fromJson(Map<String, dynamic>.from(lblMap))
            : const MoadianInvoiceLabels(),
      );
    }, 'دریافت فهرست صورتحساب‌ها');
  }

  Future<MoadianInvoice> getInvoice(int id, {int? cpInfoId}) async {
    final r = await _api.get<dynamic>(
      'Moadian/GetInvoiceByIdAsync/$id',
      options: _opts(cpInfoId),
    );
    return _must(_unwrap(r.data), (d) {
      if (d is Map) {
        return MoadianInvoice.fromJson(Map<String, dynamic>.from(d));
      }
      throw ApiException('جزئیات صورتحساب یافت نشد.', 404);
    }, 'دریافت جزئیات صورتحساب');
  }

  Future<MoadianApiResult> saveInvoice(MoadianInvoice invoice) async {
    final r = await _api.request<dynamic>(
      'POST',
      'Moadian/AddInvoice',
      data: invoice.toJson(),
      options: _opts(invoice.cpInfoId),
    );
    return _unwrap(r.data);
  }

  Future<MoadianApiResult> previewSendInvoice(MoadianInvoice invoice) async {
    final r = await _api.request<dynamic>(
      'POST',
      'Moadian/PreviewSendInvoiceAsync',
      data: invoice.toJson(overrideSubject: 'ارسال به سامانه'),
      options: _opts(invoice.cpInfoId),
    );
    return _unwrap(r.data);
  }

  Future<MoadianApiResult> sendInvoice(MoadianInvoice invoice) async {
    final r = await _api.request<dynamic>(
      'POST',
      'Moadian/SendInvoiceAsync',
      data: invoice.toJson(overrideSubject: 'ارسال به سامانه'),
      options: _opts(invoice.cpInfoId),
    );
    return _unwrap(r.data);
  }

  Future<MoadianApiResult> sendSalesReturn(MoadianInvoice invoice) async {
    final r = await _api.request<dynamic>(
      'POST',
      'Moadian/SendInvoiceAsync',
      data: invoice.toJson(overrideSubject: 'برگشت از فروش'),
      options: _opts(invoice.cpInfoId),
    );
    return _unwrap(r.data);
  }

  Future<MoadianApiResult> eslahiInvoice(MoadianInvoice invoice) async {
    final r = await _api.request<dynamic>(
      'POST',
      'Moadian/EslahiInvoiceAsync',
      data: invoice.toJson(overrideSubject: 'اصلاحی'),
      options: _opts(invoice.cpInfoId),
    );
    return _unwrap(r.data);
  }

  Future<MoadianApiResult> ebtalInvoice(MoadianInvoice invoice) async {
    final r = await _api.request<dynamic>(
      'POST',
      'Moadian/EbtalInvoiceAsync',
      data: invoice.toJson(overrideSubject: 'ابطالی'),
      options: _opts(invoice.cpInfoId),
    );
    return _unwrap(r.data);
  }

  Future<MoadianApiResult> estelamInvoice({
    required String referenceId,
    required int invoiceId,
    DateTime? dateOrder,
    int? cpInfoId,
  }) async {
    final d = dateOrder ?? DateTime.now();
    final dateStr =
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final r = await _api.get<dynamic>(
      'Moadian/EstelamInvoiceAsync',
      query: {
        'ReferenceId': referenceId,
        'InvoiceId': invoiceId,
        'dateorder': dateStr,
      },
      options: _opts(cpInfoId),
    );
    return _unwrap(r.data);
  }

  Future<MoadianApiResult> setInvoiceStatus({
    required int invoiceId,
    required String targetStatus,
    int? cpInfoId,
  }) async {
    final r = await _api.request<dynamic>(
      'POST',
      'Moadian/SetInvoiceStatusAsync',
      query: {'invoiceId': invoiceId, 'targetStatus': targetStatus},
      options: _opts(cpInfoId),
    );
    return _unwrap(r.data);
  }

  Future<MoadianErrorInfo> getInvoiceErrors(
    String referenceId, {
    int? cpInfoId,
  }) async {
    final r = await _api.get<dynamic>(
      'Moadian/ErrorInvoiceAsync',
      query: {'ReferenceId': referenceId},
      options: _opts(cpInfoId),
    );
    final res = _unwrap(r.data);
    if (res.data is Map) {
      return MoadianErrorInfo.fromJson(res.data);
    }
    return MoadianErrorInfo(message: res.message);
  }

  Future<MoadianApiResult> deleteInvoice(int invoiceId, {int? cpInfoId}) async {
    final r = await _api.request<dynamic>(
      'DELETE',
      'Moadian/Invoice/$invoiceId',
      options: _opts(cpInfoId),
    );
    return _unwrap(r.data);
  }

  // ==================== ۵. عیب‌یاب اسکیما و کوئری‌های مودیان ====================

  Future<MoadianApiResult> diagnoseSchema() async {
    final r = await _api.get<dynamic>('Moadian/Diagnose');
    return _unwrap(r.data);
  }

  Future<MoadianApiResult> diagnoseLists(int cpInfoId) async {
    final r = await _api.get<dynamic>(
      'Moadian/DiagnoseLists',
      query: {'cpinfoId': cpInfoId},
      options: _opts(cpInfoId),
    );
    return _unwrap(r.data);
  }
}
