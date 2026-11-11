import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this._storage) {
    dio = Dio(
      BaseOptions(
        baseUrl: const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://localhost:5100',
        ),
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(minutes: 2),
        sendTimeout: const Duration(minutes: 2),
        headers: const {'Accept': 'application/json'},
      ),
    );
    dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'auth_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          var cid = _companyId;
          if (cid == null) {
            final saved = await _storage.read(key: 'company_id');
            cid = saved == null ? null : int.tryParse(saved);
            _companyId = cid;
          }
          if (cid != null &&
              cid > 0 &&
              options.extra['noCompanyHeader'] != true &&
              options.headers['X-Company-Id'] == null) {
            options.headers['X-Company-Id'] = cid.toString();
          }
          handler.next(options);
        },
      ),
    );
  }

  final FlutterSecureStorage _storage;
  late final Dio dio;
  void Function()? onUnauthorized;
  int? _companyId;

  String get baseUrl => dio.options.baseUrl;
  int? get companyId => _companyId;

  Future<void> setBaseUrl(String value) async {
    var url = value.trim();
    while (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (!url.startsWith('http://') && !url.startsWith('https://'))
      url = 'https://$url';
    dio.options.baseUrl = url;
    await _storage.write(key: 'api_base_url', value: url);
  }

  Future<void> setCompanyId(int? id) async {
    if (id == null || id <= 0) {
      _companyId = null;
      await _storage.delete(key: 'company_id');
      return;
    }
    _companyId = id;
    await _storage.write(key: 'company_id', value: id.toString());
  }

  Future<void> restoreCompanyId() async {
    final saved = await _storage.read(key: 'company_id');
    _companyId = saved == null ? null : int.tryParse(saved);
  }

  /// اگر شرکت فعال هنوز مشخص نشده باشد، از `GET /api/company-context` خوانده و ذخیره می‌شود.
  Future<int?> ensureCompanyId() async {
    if (_companyId != null && _companyId! > 0) return _companyId;
    await restoreCompanyId();
    if (_companyId != null && _companyId! > 0) return _companyId;
    final r = await get<dynamic>('/api/company-context');
    final d = r.data;
    if (d is Map) {
      var active = (d['activeCompanyId'] as num?)?.toInt();
      if (active == null || active <= 0) {
        final list = d['companies'];
        if (list is List) {
          for (final item in list.whereType<Map>()) {
            if (item['isActive'] != false) {
              final cid = (item['id'] as num?)?.toInt();
              if (cid != null && cid > 0) {
                active = cid;
                break;
              }
            }
          }
        }
      }
      if (active != null && active > 0) {
        await setCompanyId(active);
        return active;
      }
    }
    return null;
  }

  Future<void> restoreBaseUrl() async {
    final saved = await _storage.read(key: 'api_base_url');
    if (saved != null && saved.isNotEmpty) dio.options.baseUrl = saved;
    await restoreCompanyId();
  }

  /// مسیر نسبی را با دامنهٔ baseUrl ترکیب می‌کند.
  ///
  /// چرا لازم است: اگر baseUrl اسکیم «https» داشته باشد و مسیر با «/»
  /// شروع شود، استاندارد URI آن را مسیر-مطلق می‌فهمد و دامنه دور زده
  /// می‌شود («https://office.ir» + «/api/x» → «https://office.irapi/x»).
  /// همین باگ باعث می‌شد پیام‌رسان به «ارتباط با سرور برقرار نشد» بخورد.
  String resolveUrl(String path, {String? baseOverride}) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final used = (baseOverride == null || baseOverride.trim().isEmpty)
        ? dio.options.baseUrl
        : baseOverride.trim();
    final base = used.replaceAll(RegExp(r'/+$'), '');
    final rel = path.replaceAll(RegExp(r'^/+'), '');
    return '$base/$rel';
  }

  static String normalizePath(String path) => path;

  Future<Response<T>> request<T>(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    Options? options,
    String? baseOverride,
  }) async {
    // درخواست به سروری جز سرور اصلی (مثل پیام‌رسان) نباید هدر شرکت را ببرد
    final foreign = path.startsWith('http') &&
        !path.startsWith(dio.options.baseUrl.trim());
    try {
      return await dio.request<T>(
        resolveUrl(path, baseOverride: baseOverride),
        data: data,
        queryParameters: query,
        options: ((options ?? Options()).copyWith(method: method))..extra = {
          ...?options?.extra,
          // سرور پیام‌رسان جدا از اتوماسیون است؛ هدر شرکت نباید برود
          if (baseOverride != null || foreign) 'noCompanyHeader': true,
        },
        onSendProgress: options?.extra?['sendProgress'] as void Function(int, int)?,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) onUnauthorized?.call();
      throw ApiException(_message(e), e.response?.statusCode);
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    String? baseOverride,
    Options? options,
  }) => request<T>(
    'GET',
    path,
    query: query,
    baseOverride: baseOverride,
    options: options,
  );
  Future<Response<T>> post<T>(
    String path, [
    dynamic data,
    Map<String, dynamic>? query,
    String? baseOverride,
  ]) => request<T>(
    'POST',
    path,
    data: data,
    query: query,
    baseOverride: baseOverride,
  );

  /// ارسال multipart (فرم + فایل) با همان تبدیل خطاهای API
  /// [onSendProgress] برای نمایش درصد آپلود فایل‌های بزرگ.
  Future<Response<T>> postForm<T>(
    String path,
    FormData data, {
    void Function(int sent, int total)? onSendProgress,
  }) => request<T>(
    'POST',
    path,
    data: data,
    options: Options(
      contentType: 'multipart/form-data',
      extra: onSendProgress == null
          ? null
          : {'sendProgress': onSendProgress},
    ),
  );

  /// دریافت فایل خام (پیوست، PDF) با همان تبدیل خطاهای API
  Future<Uint8List> getBytes(String path, {Map<String, dynamic>? query}) async {
    final r = await request<List<int>>(
      'GET',
      path,
      query: query,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(r.data ?? const <int>[]);
  }
  Future<Response<T>> put<T>(String path, [dynamic data]) =>
      request<T>('PUT', path, data: data);
  Future<Response<T>> delete<T>(String path) => request<T>('DELETE', path);

  static String _message(DioException e) {
    var d = e.response?.data;
    if (d is List<int> && d.isNotEmpty) {
      try {
        d = utf8.decode(d, allowMalformed: true);
      } catch (_) {}
    }
    if (d is Map) {
      if (d['message'] != null) return d['message'].toString();
      if (d['title'] != null) return d['title'].toString();
      if (d['errors'] is Map)
        return (d['errors'] as Map).values
            .expand((v) => v is List ? v : [v])
            .join('\n');
    }
    if (d is String && d.trim().isNotEmpty) {
      try {
        final j = jsonDecode(d);
        if (j is Map && j['message'] != null) return j['message'].toString();
      } catch (_) {}
      return d.length > 350 ? d.substring(0, 350) : d;
    }
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => 'زمان اتصال به سرور تمام شد.',
      DioExceptionType.connectionError =>
        'اتصال به سرور برقرار نشد. آدرس سرور و شبکه را بررسی کنید.',
      _ => switch (e.response?.statusCode) {
        401 => 'نشست شما منقضی شده است. دوباره وارد شوید.',
        403 => 'شما دسترسی انجام این عملیات را ندارید.',
        404 => 'موردی با این مشخصات پیدا نشد.',
        _ =>
          'خطا در ارتباط با سرور (${e.response?.statusCode ?? 'بدون پاسخ'}).',
      },
    };
  }
}
