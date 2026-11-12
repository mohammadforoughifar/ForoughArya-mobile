// ============================================================
//  چند سرور / چند آدرس + سوییچ خودکار با تغییر شبکه
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:forough_mobile/core/auth/auth_controller.dart';
import 'package:forough_mobile/core/network/api_client.dart';
import 'package:forough_mobile/core/network/connection_manager.dart';

/// شبکهٔ شبیه‌سازی‌شده: میزبان‌های [down] در دسترس نیستند
class _Network implements HttpClientAdapter {
  final Set<String> down = {};
  final List<String> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.method} ${options.uri}');
    if (down.contains(options.uri.host)) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'unreachable',
      );
    }
    if (options.uri.path == '/api/auth/login') {
      final body = options.data is String
          ? jsonDecode(options.data as String)
          : options.data;
      return ResponseBody.fromString(
        jsonEncode({
          'userId': 1,
          'token': 'tok-${options.uri.host}-${(body as Map)['username']}',
          'username': body['username'],
          'role': 'User',
          'displayName': body['username'],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.uri.path == '/api/company-context') {
      return ResponseBody.fromString('{"activeCompanyId": 3}', 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });
    }
    return ResponseBody.fromString(
      jsonEncode({'host': options.uri.host}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ConnectionProfile _office() => ConnectionProfile(
  id: 'office',
  name: 'دفتر مرکزی',
  endpoints: [
    ServerEndpoint(id: 'lan', label: 'شبکهٔ داخلی', url: 'http://lan.office'),
    ServerEndpoint(id: 'wan', label: 'اینترنت', url: 'https://wan.office.ir'),
  ],
);

ConnectionProfile _factory() => ConnectionProfile(
  id: 'factory',
  name: 'کارخانه',
  endpoints: [
    ServerEndpoint(id: 'f1', label: 'اینترنت', url: 'https://factory.ir'),
  ],
);

void main() {
  late _Network net;
  late ApiClient api;
  late AuthController auth;
  const storage = FlutterSecureStorage();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    net = _Network();
    api = ApiClient(storage);
    api.dio.httpClientAdapter = net;
    final probeDio = Dio(BaseOptions(validateStatus: (_) => true))
      ..httpClientAdapter = net;
    auth = AuthController(
      api,
      storage,
      connections: ConnectionManager(storage, probeDio: probeDio),
    );
    await auth.initialize();
  });

  test('یکدست‌سازی آدرس: IP → http و دامنه → https', () {
    expect(normalizeServerUrl('192.168.1.10:5100/'), 'http://192.168.1.10:5100');
    expect(normalizeServerUrl('office.example.com'), 'https://office.example.com');
    expect(normalizeServerUrl('http://a.b//'), 'http://a.b');
    expect(validateServerUrl(''), isNotNull);
    expect(validateServerUrl('10.0.0.5'), isNull);
  });

  test('آدرس تکیِ نسخهٔ قبل به یک پروفایل منتقل می‌شود', () async {
    FlutterSecureStorage.setMockInitialValues({
      'api_base_url': 'https://old.server.ir',
    });
    final cm = ConnectionManager(storage);
    await cm.load();
    expect(cm.profiles, hasLength(1));
    expect(cm.activeUrl, 'https://old.server.ir');
  });

  test('قطع شبکهٔ داخلی → سوییچ خودکار به اینترنت و تکرار درخواست', () async {
    await auth.connections.upsertProfile(_office());
    expect(api.baseUrl, 'http://lan.office');

    net.down.add('lan.office'); // از وای‌فای شرکت خارج شدیم
    final r = await api.get<Map<String, dynamic>>('/api/work-orders');
    expect(r.data!['host'], 'wan.office.ir');
    expect(api.baseUrl, 'https://wan.office.ir');
    expect(auth.connections.activeEndpoint!.id, 'wan');
    expect(auth.connections.lastAutoSwitch.value, contains('اینترنت'));
    expect(await storage.read(key: 'api_base_url'), 'https://wan.office.ir');
  });

  test('برگشت به شبکهٔ داخلی → recheck آدرس با اولویت بالاتر را برمی‌گزیند', () async {
    await auth.connections.upsertProfile(_office());
    await auth.connections.selectEndpoint('wan');
    await auth.connections.recheck();
    expect(api.baseUrl, 'http://lan.office');
  });

  test('سوییچ خودکار خاموش → خطا به کاربر برمی‌گردد', () async {
    await auth.connections.upsertProfile(_office()..autoSwitch = false);
    net.down.add('lan.office');
    expect(
      () => api.get<dynamic>('/api/work-orders'),
      throwsA(isA<ApiException>()),
    );
  });

  test('هیچ آدرسی در دسترس نیست → خطای اتصال', () async {
    await auth.connections.upsertProfile(_office());
    net.down.addAll(['lan.office', 'wan.office.ir']);
    await expectLater(
      api.get<dynamic>('/api/work-orders'),
      throwsA(isA<ApiException>()),
    );
  });

  test('تعویض سرور: نشست هر سرور جدا نگه داشته و برگردانده می‌شود', () async {
    await auth.connections.upsertProfile(_office());
    await auth.connections.upsertProfile(_factory());
    expect(auth.connections.activeProfileId, 'office');

    expect(await auth.login('ali', 'x'), isTrue);
    expect(auth.session!.token, 'tok-lan.office-ali');

    // سرور دوم: هنوز وارد نشده‌ایم
    await auth.switchProfile('factory');
    expect(api.baseUrl, 'https://factory.ir');
    expect(auth.isLoggedIn, isFalse);
    expect(await storage.read(key: 'auth_token'), isNull);

    expect(await auth.login('reza', 'y'), isTrue);
    expect(auth.session!.token, 'tok-factory.ir-reza');

    // برگشت به دفتر مرکزی بدون ورود دوباره
    await auth.switchProfile('office');
    expect(auth.isLoggedIn, isTrue);
    expect(auth.session!.username, 'ali');
    expect(await storage.read(key: 'auth_token'), 'tok-lan.office-ali');
    expect(api.baseUrl, 'http://lan.office');

    // و دوباره کارخانه
    await auth.switchProfile('factory');
    expect(auth.session!.username, 'reza');
  });

  test('سرور فعال حذف نمی‌شود؛ سرور غیرفعال حذف می‌شود', () async {
    await auth.connections.upsertProfile(_office());
    await auth.connections.upsertProfile(_factory());
    expect(await auth.connections.deleteProfile('office'), isFalse);
    expect(await auth.connections.deleteProfile('factory'), isTrue);
    expect(auth.connections.profiles, hasLength(1));
  });
}
