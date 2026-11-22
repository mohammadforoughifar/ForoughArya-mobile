// ============================================================
//  تست «میز کار حرفه‌ای فروغ آریا» و هم‌ترازی نام ماژول‌ها با وب
//  با آداپتور جعلی dio، endpoint‌های واقعی بک‌اند شبیه‌سازی می‌شوند
//  و مسیر واقعی بارگذاری → رندر میز کار → کارتابل → تغییر شرکت → کاروسل →
//  ناوبری به ماژول‌ها اجرا و بررسی می‌شود.
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/app/home_shell.dart';
import 'package:forough_mobile/core/auth/auth_controller.dart';
import 'package:forough_mobile/core/network/api_client.dart';
import 'package:forough_mobile/core/utils/fa.dart';
import 'package:forough_mobile/features/home/data/home_repository.dart';
import 'package:forough_mobile/features/home/models/home_models.dart';
import 'package:forough_mobile/features/home/presentation/home_page.dart';
import 'package:forough_mobile/features/office_automation/data/email_draft_store.dart';
import 'package:forough_mobile/features/office_automation/data/email_repository.dart';
import 'package:forough_mobile/features/office_automation/data/office_repository.dart';
import 'package:forough_mobile/features/work_orders/data/work_order_repository.dart';
import 'package:provider/provider.dart';

class _FakeAdapter implements HttpClientAdapter {
  int companyCalls = 0;
  int widgetCalls = 0;
  int unreadCalls = 0;
  int cartableCalls = 0;

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
    } else if (p.contains('/api/cartable/me')) {
      cartableCalls++;
      body = {
        'actionableCount': 2,
        'items': [
          {
            'source': 'sales-visit',
            'kind': 'approval-pending',
            'title': '۲ سفارش ویزیتور منتظر تأیید شما',
            'subtitle': 'بررسی موجودی و سقف تخفیف',
            'link': '/sales/approvals',
            'icon': 'bi-patch-check',
            'color': '#1d4ed8',
            'priority': 2,
            'actionable': true,
            'badgeCount': 2,
          },
        ],
      };
    } else if (p.contains('/api/my-dashboards/widget-data/')) {
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
          {
            'cells': ['تعداد فاکتور', '۳۷', 'سند'],
          },
          {
            'cells': ['برترین طرف حساب', 'سپهر', ''],
          },
          {
            'cells': ['زیر نقطه سفارش', '۶', 'قلم'],
          },
        ],
        'series': [
          {
            'name': 's',
            'labels': ['1'],
            'values': [1, 2, 3, 4, 5, 6, 7],
          },
        ],
      };
    } else if (p.contains('/api/notifications/unread-count')) {
      unreadCalls++;
      body = {'count': 7};
    } else if (p.contains('/api/notifications/page')) {
      body = {
        'items': [
          {
            'id': 1,
            'title': 'ارجاع نامهٔ ۱۴۰۵/۲۱۸۷ به شما',
            'body': 'نامه به کارتابل شما ارجاع شد.',
            'fromName': 'مدیریت بازرگانی',
            'formName': 'کارتابل نامه داخلی',
            'link': '/',
            'isRead': false,
            'createdAt': '2026-11-09T08:00:00',
            'category': 'main',
          },
        ],
        'total': 1,
        'unread': 1,
        'filteredTotal': 1,
        'mainTotal': 1,
        'mainUnread': 1,
        'subTotal': 0,
        'subUnread': 0,
        'hasMore': false,
      };
    } else if (p.contains('/api/notifications')) {
      body = [
        {
          'id': 1,
          'title': 'ارجاع نامهٔ ۱۴۰۵/۲۱۸۷ به شما',
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

Future<void> _settle(WidgetTester tester, {int frames = 14}) async {
  await tester.pump();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<({ApiClient api, _FakeAdapter adapter})> _pumpHome(
  WidgetTester tester, {
  ValueChanged<int>? onOpenTab,
}) async {
  tester.view.physicalSize = const Size(412, 1400);
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
          child: HomePage(onOpenTab: onOpenTab ?? (_) {}),
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
      expect(const CompanyOption(id: 1, name: 'شرکت فروغ آریا').initials, 'فآ');
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

  group('Module Branding Parity (Web)', () {
    test('نام‌های نمایشی ماژول‌ها ۱۰۰٪ با نسخهٔ وب هم‌تراز هستند', () {
      final names = buildModuleTiles(
        openTabs: const {1, 2, 3, 4},
      ).map((m) => m.name).toList();
      expect(
        names,
        containsAll([
          'اتوماسیون اداری توکا',
          'دستورکار رایکا',
          'فروشگاهی کایر',
          'پیام رسان میها',
          'ERP فیکا',
          'مودیان تیسا',
          'مدیریت سیستم',
          'آرشیو اسناد و مدارک',
          'کارتابل آرشیو',
          'ایمیل سازمانی',
          'صورتجلسه',
        ]),
      );
    });
  });

  group('HomePage Workbench', () {
    testWidgets('سربرگ میز کار، کارتابل یکپارچه، شاخص‌ها و ماژول‌ها رندر می‌شوند', (
      tester,
    ) async {
      final r = await _pumpHome(tester);

      // سربرگ و شرکت فعال
      expect(find.text('شرکت فعال سازمان'), findsOneWidget);
      expect(find.text('شرکت فروغ آریا'), findsWidgets);
      expect(find.text('۲ شرکت مجاز'), findsOneWidget);

      // بخش‌های میز کار حرفه‌ای
      expect(find.text('عملیات سریع میز کار'), findsOneWidget);
      expect(find.text('کارتابل یکپارچه و میز اقدام'), findsOneWidget);
      expect(find.text('شاخص‌های عملکرد سازمان'), findsOneWidget);
      expect(find.text('ماژول‌های سازمان'), findsOneWidget);

      // آیتم زندهٔ کارتابل یکپارچه از /api/cartable/me
      expect(find.text('۲ سفارش ویزیتور منتظر تأیید شما'), findsOneWidget);

      // اولین کارت کاروسل با دادهٔ واقعی ویجت
      expect(find.text('فروش و فاکتور'), findsOneWidget);
      expect(find.text('۸۴۲'), findsWidgets);
      expect(find.text('+۱۲٪ نسبت به دیروز'), findsWidgets);

      // اسکرول به پایین برای مشاهدهٔ گرید ماژول‌ها با نام‌های جدید وب
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await _settle(tester);

      expect(find.text('اتوماسیون اداری توکا'), findsWidgets);
      expect(find.text('دستورکار رایکا'), findsWidgets);
      expect(find.text('فروشگاهی کایر'), findsWidgets);
      expect(find.text('پیام رسان میها'), findsWidgets);

      expect(r.adapter.companyCalls, 1);
      expect(r.adapter.cartableCalls, 1);
      expect(r.adapter.unreadCalls, 1);
      expect(r.adapter.widgetCalls, 8);
    });

    testWidgets('انتخاب شرکت دیگر، دادهٔ ویجت‌ها را دوباره می‌خواند', (
      tester,
    ) async {
      final r = await _pumpHome(tester);
      final before = r.adapter.widgetCalls;
      expect(before, 8);

      await tester.tap(find.text('شرکت فروغ آریا').first);
      await _settle(tester);
      await tester.tap(find.text('شرکت حمل‌ونقل آریا').last);
      await _settle(tester);

      expect(r.adapter.widgetCalls, before + 8);
      expect(find.text('شرکت حمل‌ونقل آریا'), findsWidgets);
    });

    testWidgets('کاشی ماژول با نام جدید وب، تب پوسته را عوض می‌کند', (
      tester,
    ) async {
      int? opened;
      await _pumpHome(tester, onOpenTab: (i) => opened = i);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await _settle(tester);

      await tester.tap(find.text('اتوماسیون اداری توکا').last);
      await _settle(tester);
      expect(opened, 2);
    });

    testWidgets('خطای شبکه بنر خطا نشان می‌دهد نه دادهٔ جعلی', (tester) async {
      tester.view.physicalSize = const Size(412, 1200);
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
      expect(find.text('۸۴۲'), findsNothing);
    });

    testWidgets(
      'جستجوی فرماندهی، شخصی‌سازی ۳ستونه، تب‌های کارتابل و تغییر بازهٔ KPI بدون خطا کار می‌کنند',
      (tester) async {
        final r = await _pumpHome(tester);

        // ۱) باز کردن پالت فرماندهی و جستجوی نام‌های جدید وب
        await tester.tap(find.byIcon(Icons.search_rounded).first);
        await _settle(tester);
        expect(find.byIcon(Icons.manage_search_rounded), findsOneWidget);

        await tester.enterText(find.byType(TextField).last, 'رایکا');
        await _settle(tester);
        expect(find.text('دستورکار رایکا'), findsWidgets);
        Navigator.of(tester.element(find.byType(TextField).last)).pop();
        await _settle(tester);

        // ۲) تغییر تب‌های کارتابل یکپارچه (منتظر اقدام -> اقدامات اصلی -> پیگیری‌ها)
        await tester.tap(find.text('اقدامات اصلی'));
        await _settle(tester);
        expect(find.text('ارجاع نامهٔ ۱۴۰۵/۲۱۸۷ به شما'), findsOneWidget);

        await tester.tap(find.text('پیگیری‌ها'));
        await _settle(tester);

        // ۳) تغییر بازهٔ زمانی شاخص‌ها به «هفته»
        await tester.tap(find.text('هفته'));
        await _settle(tester);
        expect(r.adapter.widgetCalls, greaterThanOrEqualTo(16));

        // ۴) شیت شخصی‌سازی میز کار و حالت فشردهٔ ۳ ستونی روی صفحهٔ باریک ۳۶۰px
        tester.view.physicalSize = const Size(360, 1400);
        await _settle(tester, frames: 4);
        await tester.tap(find.text('چیدمان میز کار'));
        await _settle(tester);
        expect(
          find.text('چیدمان فشردهٔ ماژول‌ها (۳ ستونی)'),
          findsOneWidget,
        );
        await tester.tap(find.text('چیدمان فشردهٔ ماژول‌ها (۳ ستونی)'));
        await _settle(tester);
        Navigator.of(
          tester.element(find.text('چیدمان فشردهٔ ماژول‌ها (۳ ستونی)')),
        ).pop();
        await _settle(tester);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await _settle(tester);
      },
    );
  });

  group('HomeShell', () {
    testWidgets('تب «میز کار» اول است و ناوبری پایین نام‌های وب را نشان می‌دهد', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 1200);
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

      expect(find.text('میز کار'), findsOneWidget);
      expect(find.text('دستورکار رایکا'), findsWidgets);
      expect(find.text('اتوماسیون توکا'), findsWidgets);
      expect(find.text('ایمیل سازمانی'), findsWidgets);
      expect(find.text('پیام رسان میها'), findsWidgets);
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
