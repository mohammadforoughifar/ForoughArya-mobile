// ============================================================
//  تست صفحهٔ اصلی
//  با آداپتور جعلی dio، endpoint‌های واقعی بک‌اند شبیه‌سازی می‌شوند
//  و مسیر واقعی بارگذاری → رندر → تغییر شرکت → کاروسل اجرا می‌شود.
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/auth/auth_controller.dart';
import 'package:forough_mobile/core/network/api_client.dart';
import 'package:forough_mobile/core/utils/fa.dart';
import 'package:forough_mobile/app/home_shell.dart';
import 'package:forough_mobile/features/home/data/home_repository.dart';
import 'package:forough_mobile/features/office_automation/data/email_draft_store.dart';
import 'package:forough_mobile/features/office_automation/data/email_repository.dart';
import 'package:forough_mobile/features/office_automation/data/office_repository.dart';
import 'package:forough_mobile/features/work_orders/data/work_order_repository.dart';
import 'package:forough_mobile/features/home/models/home_models.dart';
import 'package:forough_mobile/features/home/presentation/home_page.dart';
import 'package:provider/provider.dart';

/// پاسخ‌های canned برای مسیرهای واقعی بک‌اند.
class _FakeAdapter implements HttpClientAdapter {
  int companyCalls = 0;
  int widgetCalls = 0;
  int unreadCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final p = options.path;
    Object body;
    if (p.contains('/api/company-context')) {
      companyCalls++;
      body = {
        'activeCompanyId': 1001,
        'companies': [
          {
            'id': 1001,
            'name': 'شرکت فروغ آریا',
            'code': '1001',
            'isActive': true,
          },
          {
            'id': 1002,
            'name': 'شرکت حمل‌ونقل آریا',
            'code': '1002',
            'isActive': true,
          },
          {'id': 1007, 'name': 'بن‌سازه', 'code': '1007', 'isActive': false},
        ],
      };
    } else if (p.contains('/api/my-dashboards/widget-data/')) {
      // باید قبل از بررسی عمومیِ /api/my-dashboards بیاید
      widgetCalls++;
      final key = p.split('/').last.split('?').first;
      body = {
        'key': key,
        'kind': 0,
        'title': 'ویجت $key',
        'value': 842,
        'unit': 'میلیون ریال',
        'deltaText': '+۱۲٪ نسبت به دیروز',
        'deltaUp': true,
        'rows': [
          {'cells': ['تعداد فاکتور', '۳۷', 'سند']},
          {'cells': ['برترین طرف حساب', 'سپهر', '']},
          {'cells': ['زیر نقطه سفارش', '۶', 'قلم']},
        ],
        'series': [
          {'name': 's', 'labels': ['1'], 'values': [1, 2, 3, 4, 5, 6, 7]},
        ],
      };
    } else if (p.contains('/api/notifications/unread-count')) {
      unreadCalls++;
      body = {'count': 7};
    } else if (p.contains('/api/notifications')) {
      body = [
        {
          'id': 1,
          'title': 'ارجاع نامهٔ ۱۴۰۴/۲۱۸۷ به شما',
          'body': 'نامه به کارتابل شما ارجاع شد.',
          'fromName': 'مدیریت بازرگانی',
          'formName': 'کارتابل نامه داخلی',
          'link': '/',
          'isRead': false,
          'createdAt': '2026-11-09T08:00:00',
        },
      ];
    } else if (p.contains('/stats') || p.contains('/counts')) {
      body = {'inbox': 4, 'sent': 3, 'unread': 2, 'open': 5};
    } else {
      body = {};
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// حافظهٔ جعلی برای FlutterSecureStorage (در تست پلاگین ثبت نیست).
FlutterSecureStorage fakeStorage() => _FakeStorage();

class _FakeStorage extends FlutterSecureStorage {
  final Map<String, String> _m = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _m.remove(key);
    } else {
      _m[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _m[key];

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _m.remove(key);

  @override
  Future<Map<String, String>> readAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => Map.of(_m);

  @override
  Future<bool> containsKey({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _m.containsKey(key);

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _m.clear();
}

/// انیمیشن هالهٔ نبضی زنگوله بی‌پایان است، پس `pumpAndSettle` هرگز
/// settle نمی‌شود؛ به‌جایش تعداد ثابتی فریم جلو می‌رویم.
Future<void> _settle(WidgetTester tester, {int frames = 14}) async {
  await tester.pump();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<({ApiClient api, _FakeAdapter adapter})> _pumpHome(
  WidgetTester tester,
) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final adapter = _FakeAdapter();
  final api = ApiClient(_FakeStorage());
  api.dio.httpClientAdapter = adapter;
  final auth = AuthController(api, _FakeStorage());

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: auth),
        Provider<ApiClient>.value(value: api),
      ],
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: HomePage(onOpenTab: (_) {}),
        ),
      ),
    ),
  );
  await _settle(tester);
  return (api: api, adapter: adapter);
}

void main() {
  group('Fa.number', () {
    test('هزارگان فارسی و اعشار فارسی', () {
      expect(Fa.number(1240000), '۱٬۲۴۰٬۰۰۰');
      expect(Fa.number(842), '۸۴۲');
      expect(Fa.number(3.5, decimals: 1), '۳٫۵');
      expect(Fa.number(0), '۰');
    });
  });

  group('CompanyOption.initials', () {
    test('کلمهٔ «شرکت» حذف و دو حرف اول دو کلمهٔ بعدی گرفته می‌شود', () {
      expect(
        const CompanyOption(id: 1, name: 'شرکت فروغ آریا').initials,
        'فآ',
      );
      expect(
        const CompanyOption(id: 2, name: 'شرکت حمل‌ونقل آریا').initials,
        'حآ',
      );
      expect(const CompanyOption(id: 3, name: 'بن‌سازه').initials, 'بن');
    });
  });

  group('CompanyContext', () {
    test('active و activeCount', () {
      const ctx = CompanyContext(
        activeCompanyId: 2,
        companies: [
          CompanyOption(id: 1, name: 'الف'),
          CompanyOption(id: 2, name: 'ب'),
          CompanyOption(id: 3, name: 'پ', isActive: false),
        ],
      );
      expect(ctx.active?.name, 'ب');
      expect(ctx.activeCount, 2);
    });
  });

  group('WidgetData.fromJson', () {
    test('سری اول نمودار به sparkline نگاشت می‌شود', () {
      final w = WidgetData.fromJson({
        'key': 'k',
        'value': 12,
        'series': [
          {'name': 'a', 'values': [1, 2, 3]},
          {'name': 'b', 'values': [9, 9, 9]},
        ],
        'rows': [
          {'cells': ['x', 'y']},
        ],
      });
      expect(w.value, 12);
      expect(w.series, [1.0, 2.0, 3.0]);
      expect(w.rows.first, ['x', 'y']);
    });
  });

  group('HomePage', () {
    testWidgets('هدر، شرکت فعال، کارت گزارش و گرید ماژول‌ها رندر می‌شوند', (
      tester,
    ) async {
      final r = await _pumpHome(tester);

      // هدر
      expect(find.text('شرکت فعال'), findsOneWidget);
      expect(find.text('شرکت فروغ آریا'), findsWidgets);
      expect(find.text('۳ شرکت فعال'), findsNothing); // یکی غیرفعال است
      expect(find.text('۲ شرکت فعال'), findsOneWidget);

      // زنگوله با شمارندهٔ واقعی از /unread-count
      expect(find.text('۷'), findsOneWidget);

      // بخش‌ها
      expect(find.text('گزارش روزانه'), findsOneWidget);
      expect(find.text('ماژول‌ها'), findsOneWidget);

      // اعلان‌ها عمداً در بدنهٔ صفحه نیستند
      expect(find.text('اعلان‌ها'), findsNothing);

      // اولین کارت کاروسل با دادهٔ واقعی ویجت
      expect(find.text('فروش و فاکتور'), findsOneWidget);
      expect(find.text('۸۴۲'), findsWidgets);
      // با viewportFraction=0.9 دو کارت هم‌زمان در درخت هستند
      // PageView همسایه‌ها را هم می‌سازد؛ مهم این است که دادهٔ واقعی
      // روی همهٔ کارت‌های ساخته‌شده نشسته باشد.
      expect(find.text('+۱۲٪ نسبت به دیروز'), findsWidgets);
      expect(find.text('تعداد فاکتور'), findsWidgets);
      expect(find.text('۳۷'), findsWidgets);
      expect(
        find.text('+۱۲٪ نسبت به دیروز').evaluate().length,
        find.text('تعداد فاکتور').evaluate().length,
      );

      // ماژول‌های قابل دسترس در تب
      expect(find.text('دستور کار'), findsWidgets);
      expect(find.text('اتوماسیون اداری'), findsWidgets);
      expect(find.text('پست الکترونیک'), findsWidgets);

      // endpoint‌های واقعی صدا زده شدند
      expect(r.adapter.companyCalls, 1);
      expect(r.adapter.unreadCalls, 1);
      expect(r.adapter.widgetCalls, 8); // ۸ کارت گزارش روزانه
    });

    testWidgets('کاروسل با سوایپ به کارت بعدی می‌رود', (tester) async {
      await _pumpHome(tester);
      final first = find.text('فروش و فاکتور');
      final second = find.text('دبیرخانه و نامه‌ها');
      expect(first, findsOneWidget);
      expect(second, findsOneWidget);

      // در RTL کارت دوم بیرون از لبهٔ چپ است
      expect(tester.getCenter(second).dx, lessThan(0));
      final firstBefore = tester.getCenter(first).dx;
      expect(firstBefore, greaterThan(100));

      await tester.drag(first, const Offset(320, 0));
      await _settle(tester);

      // کارت دوم به وسط آمد و کارت اول از دید خارج شد
      expect(tester.getCenter(second).dx, greaterThan(100));
      expect(find.text('فروش و فاکتور'), findsNothing);
    });

    testWidgets('شیت شرکت‌ها باز می‌شود و شرکت غیرفعال انتخاب‌پذیر نیست', (
      tester,
    ) async {
      await _pumpHome(tester);

      await tester.tap(find.text('شرکت فروغ آریا').last);
      await _settle(tester);

      expect(find.text('انتخاب شرکت فعال'), findsOneWidget);
      expect(find.text('شرکت حمل‌ونقل آریا'), findsWidgets);
      expect(find.text('بن‌سازه'), findsOneWidget);
      expect(find.text('غیرفعال'), findsOneWidget);

      // زدن روی شرکت غیرفعال نباید شیت را ببندد
      await tester.tap(find.text('بن‌سازه'));
      await _settle(tester);
      expect(find.text('انتخاب شرکت فعال'), findsOneWidget);
    });

    testWidgets('انتخاب شرکت دیگر، دادهٔ ویجت‌ها را دوباره می‌خواند', (
      tester,
    ) async {
      final r = await _pumpHome(tester);
      final before = r.adapter.widgetCalls;
      expect(before, 8);

      await tester.tap(find.text('شرکت فروغ آریا').last);
      await _settle(tester);
      await tester.tap(find.text('شرکت حمل‌ونقل آریا').last);
      await _settle(tester);

      // ۸ ویجت دوباره خوانده شد
      expect(r.adapter.widgetCalls, before + 8);
      // هدر به شرکت جدید عوض شد
      expect(find.text('شرکت حمل‌ونقل آریا'), findsWidgets);
    });

    testWidgets('کاشی ماژول، تب پوسته را عوض می‌کند', (tester) async {
      await _pumpHome(tester);
      int? opened;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(
              value: AuthController(
                ApiClient(_FakeStorage()),
                _FakeStorage(),
              ),
            ),
            Provider<ApiClient>.value(
              value: ApiClient(_FakeStorage())
                ..dio.httpClientAdapter = _FakeAdapter(),
            ),
          ],
          child: MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: HomePage(onOpenTab: (i) => opened = i),
            ),
          ),
        ),
      );
      await _settle(tester);

      await tester.tap(find.text('اتوماسیون اداری').last);
      await _settle(tester);
      expect(opened, 2);
    });

    testWidgets('خطای شبکه بنر خطا نشان می‌دهد نه دادهٔ جعلی', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final api = ApiClient(_FakeStorage());
      api.dio.httpClientAdapter = _FailingAdapter();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(
              value: AuthController(api, _FakeStorage()),
            ),
            Provider<ApiClient>.value(value: api),
          ],
          child: MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: HomePage(onOpenTab: (_) {}),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      expect(find.text('تلاش دوباره'), findsOneWidget);
      // عدد جعلی ساخته نشده است
      expect(find.text('۸۴۲'), findsNothing);
    });
  });

  group('HomeShell', () {
    testWidgets('تب «خانه» اول است و کاشی ماژول تب را عوض می‌کند', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final storage = _FakeStorage();
      final api = ApiClient(storage);
      api.dio.httpClientAdapter = _FakeAdapter();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(
              value: AuthController(api, storage),
            ),
            Provider<ApiClient>.value(value: api),
            Provider(create: (_) => WorkOrderRepository(api)),
            Provider(create: (_) => OfficeAutomationRepository(api)),
            Provider(create: (_) => EmailRepository(api)),
            Provider(create: (_) => EmailDraftStore(storage)),
          ],
          child: const MaterialApp(home: HomeShell()),
        ),
      );
      await _settle(tester);

      // چهار تب با «خانه» در ابتدا
      expect(find.text('خانه'), findsOneWidget);
      expect(find.text('دستور کار'), findsWidgets);
      expect(find.text('اتوماسیون اداری'), findsWidgets);
      expect(find.text('پست الکترونیک'), findsWidgets);

      // صفحهٔ اصلی بالا آمده است
      expect(find.text('گزارش روزانه'), findsOneWidget);
      expect(find.text('ماژول‌ها'), findsOneWidget);
    });
  });
}

class _FailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw DioException.connectionError(
    requestOptions: options,
    reason: 'offline',
  );

  @override
  void close({bool force = false}) {}
}
