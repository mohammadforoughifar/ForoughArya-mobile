// ============================================================
//  تست جامع تطابق ۱۰۰٪ دسترسی‌ها (RBAC) با نسخهٔ وب TotallCollectionSoftware
//  پوشش‌دهندهٔ:
//    • AuthSession (`isUnrestrictedAdmin`، `hasDirect`، `canSee` مطابق `ModuleAccess.cs`)
//    • WebAccess (`NavMenu.razor`، `RootLanding.razor`، `WidgetCatalog.cs`)
//    • ShopPerms (`ShopAccess.cs`، تفکیک `Dashboards.Financial` از `Shop.Dashboard.View`)
//    • MoadianPerms (`MoadianPermissionFilter.cs`)
//    • HomeShell (تب‌های پویا + پوستهٔ اختصاصی Referrer)
//    • HomePage / OfficeAutomationPage / EmailPage / MinutesListPage در عرض ۳۶۰px RTL
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/app/home_shell.dart';
import 'package:forough_mobile/core/auth/auth_controller.dart';
import 'package:forough_mobile/core/auth/auth_session.dart';
import 'package:forough_mobile/core/auth/web_access.dart';
import 'package:forough_mobile/core/network/api_client.dart';
import 'package:forough_mobile/features/home/data/home_repository.dart';
import 'package:forough_mobile/features/home/presentation/home_page.dart';
import 'package:forough_mobile/features/it_assets/data/it_perms.dart';
import 'package:forough_mobile/features/misc/presentation/minutes_list_page.dart';
import 'package:forough_mobile/features/moadian/data/moadian_perms.dart';
import 'package:forough_mobile/features/office_automation/data/email_draft_store.dart';
import 'package:forough_mobile/features/office_automation/data/email_repository.dart';
import 'package:forough_mobile/features/office_automation/presentation/email_page.dart';
import 'package:forough_mobile/features/office_automation/presentation/office_home_page.dart';
import 'package:forough_mobile/features/shop/data/shop_perms.dart';
import 'package:provider/provider.dart';

class _MemStorage extends FlutterSecureStorage {
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

class _StubAdapter implements HttpClientAdapter {
  final List<String> requestedPaths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPaths.add(options.path);
    final p = options.path;
    Object body = const <String, dynamic>{};

    if (p.contains('/api/company-context')) {
      body = {
        'activeCompanyId': 1,
        'companies': [
          {'id': 1, 'name': 'شرکت مهندسی فروغ آریا', 'isActive': true},
        ],
      };
    } else if (p.contains('/api/notifications/unread-count')) {
      body = {'count': 0};
    } else if (p.contains('/api/notifications/page')) {
      body = {
        'items': <dynamic>[],
        'total': 0,
        'unread': 0,
        'filteredTotal': 0,
        'mainTotal': 0,
        'mainUnread': 0,
        'subTotal': 0,
        'subUnread': 0,
        'hasMore': false,
      };
    } else if (p.contains('/api/cartable/me')) {
      body = {'items': <dynamic>[]};
    } else if (p.contains('/api/my/dashboard')) {
      body = {
        'referrerName': 'مهندس رضایی',
        'companyName': 'فروغ آریا',
        'walletBalance': 4500000,
        'totalCommission': 12000000,
        'totalPaid': 7500000,
        'monthCommission': 2500000,
        'orderCount': 4,
        'goodsCommissionPercent': 10,
        'serviceCommissionPercent': 5,
        'recentSales': <dynamic>[],
        'recentPayments': <dynamic>[],
      };
    } else if (p.contains('/api/minutes') ||
        p.contains('/api/email') ||
        p.contains('/api/letters') ||
        p.contains('/api/my/payments') ||
        p.contains('/api/my/products')) {
      body = <dynamic>[];
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

Future<({AuthController auth, ApiClient api, _StubAdapter adapter})>
_makeSessionEnv(AuthSession session) async {
  final storage = _MemStorage();
  await storage.write(
    key: 'auth_session',
    value: jsonEncode(session.toJson()),
  );
  await storage.write(key: 'auth_token', value: session.token);
  final adapter = _StubAdapter();
  final api = ApiClient(storage)..dio.httpClientAdapter = adapter;
  final auth = AuthController(api, storage);
  await auth.initialize();
  return (auth: auth, api: api, adapter: adapter);
}

Widget _wrap(AuthController auth, ApiClient api, Widget child) {
  final storage = _MemStorage();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>.value(value: auth),
      Provider<ApiClient>.value(value: api),
      Provider<EmailRepository>.value(value: EmailRepository(api)),
      Provider<EmailDraftStore>.value(value: EmailDraftStore(storage)),
    ],
    child: MaterialApp(
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    ),
  );
}

Future<void> _pumpFrames(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  group('AuthSession & ModuleAccess.CanSee — تطابق دقیق با وب', () {
    test('کاربر عادی با مجوز خالی هیچ ماژول، ویجت یا داشبوردی نمی‌بیند', () {
      const s = AuthSession(
        userId: 10,
        token: 't',
        username: 'empty_user',
        role: 'User',
        displayName: 'کاربر بدون مجوز',
        permissions: [],
      );
      final access = WebAccess(s);
      expect(s.isUnrestrictedAdmin, isFalse);
      expect(access.canSeeMyCartable, isFalse);
      expect(access.canSeeMyDashboards, isFalse);
      expect(access.canSeeFinancialDashboard, isFalse);
      expect(access.canSeeShopGroup, isFalse);
      expect(access.canSeeMoadianGroup, isFalse);
      expect(access.canSeeErp, isFalse);
      expect(access.canSeeHrMain, isFalse);
      expect(access.canSeeHrForough, isFalse);
      expect(access.canSeeHrBonsaze, isFalse);
      expect(buildKpiCards(access: access), isEmpty);
      expect(buildModuleTiles(openTabs: const {}, access: access), isEmpty);
    });

    test('مدیر دارای نقش RBAC محدود، مقید به مجوزهای واقعی نقش است (IsLegacyAdmin=false)', () {
      const restrictedAdmin = AuthSession(
        userId: 2,
        token: 't',
        username: 'scoped_admin',
        role: 'Admin',
        displayName: 'مدیر محدود',
        roleNames: ['حسابدار فروش'],
        permissions: ['Shop.Sale.View'],
      );
      expect(restrictedAdmin.isAdmin, isTrue);
      expect(restrictedAdmin.isUnrestrictedAdmin, isFalse);

      final shop = ShopPerms(restrictedAdmin);
      expect(shop.canSeeFinancialDashboard, isFalse);
      expect(shop.canSeeOperationalDashboard, isFalse);
      expect(shop.canSeeSale, isTrue);
      expect(shop.canManageSale, isFalse);
      expect(shop.canSeeProducts, isFalse);

      // در مودیان، ایجاد صورتحساب فقط با Moadian.Invoice.Create یا مدیر legacy باز است
      expect(MoadianPerms.can(restrictedAdmin, MoadianPerms.view), isTrue);
      expect(
        MoadianPerms.can(restrictedAdmin, MoadianPerms.invoiceCreate),
        isFalse,
      );
    });

    test('ModuleAccess.CanSee فقط برای ۶ ماژول استثنا از HasModule استفاده می‌کند', () {
      const s = AuthSession(
        userId: 3,
        token: 't',
        username: 'u3',
        role: 'User',
        displayName: 'کاربر ۳',
        permissions: ['Products.Manage', 'ItRequests.Create'],
      );
      // Products جزو ۶ ماژول PerSectionModules نیست → صرف داشتن Manage بدون Read مجوز مشاهده نمی‌دهد
      expect(s.canSee('Products'), isFalse);
      // ItRequests جزو PerSectionModules است → ItRequests.Create مشاهدهٔ ماژول را باز می‌کند
      expect(s.canSee('ItRequests'), isTrue);
      expect(ItPerms(s).canSeeItRequests, isTrue);
    });
  });

  group('WebAccess — تفکیک داشبوردها، ویجت‌های KPI و زیرسیستم‌ها', () {
    test('داشبورد مالی فقط با Dashboards.Financial باز می‌شود نه Shop.Dashboard.View', () {
      const opsOnly = AuthSession(
        userId: 4,
        token: 't',
        username: 'ops',
        role: 'User',
        displayName: 'اپراتور فروشگاه',
        permissions: ['Shop.Dashboard.View'],
      );
      const finOnly = AuthSession(
        userId: 5,
        token: 't',
        username: 'fin',
        role: 'User',
        displayName: 'مدیر مالی',
        permissions: ['Dashboards.Financial'],
      );

      expect(ShopPerms(opsOnly).canSeeOperationalDashboard, isTrue);
      expect(ShopPerms(opsOnly).canSeeFinancialDashboard, isFalse);
      expect(WebAccess(opsOnly).canSeeFinancialDashboard, isFalse);

      expect(ShopPerms(finOnly).canSeeFinancialDashboard, isTrue);
      expect(ShopPerms(finOnly).canSeeOperationalDashboard, isFalse);
      expect(WebAccess(finOnly).canSeeFinancialDashboard, isTrue);
      expect(WebAccess(finOnly).canSeeShopGroup, isTrue);
    });

    test('ویجت‌های KPI هم MyDashboards.View می‌خواهند و هم دسترسی ماژول مربوطه', () {
      const withoutMyDash = AuthSession(
        userId: 6,
        token: 't',
        username: 'u6',
        role: 'User',
        displayName: 'کاربر ۶',
        permissions: ['FacInvoices.Read', 'WorkOrders.View'],
      );
      expect(WebAccess(withoutMyDash).canSeeWidget('fac-sales-today'), isFalse);
      expect(buildKpiCards(access: WebAccess(withoutMyDash)), isEmpty);

      const withScopedMyDash = AuthSession(
        userId: 7,
        token: 't',
        username: 'u7',
        role: 'User',
        displayName: 'کاربر ۷',
        permissions: ['MyDashboards.View', 'WorkOrders.View'],
      );
      final kpis = buildKpiCards(access: WebAccess(withScopedMyDash));
      expect(kpis.map((k) => k.widgetKey).toList(), ['wo-open']);
    });

    test('زیرسیستم‌های منابع انسانی (اصلی، فروغ آریا، بن‌سازه) دقیقاً منطبق بر NavMenu هستند', () {
      const bonsazeUser = AuthSession(
        userId: 8,
        token: 't',
        username: 'radis',
        role: 'User',
        displayName: 'کارشناس بن‌سازه',
        permissions: ['RadisHr.Personnel.View'],
      );
      final a = WebAccess(bonsazeUser);
      expect(a.canSeeHrBonsaze, isTrue);
      expect(a.canSeeHrMain, isFalse);
      expect(a.canSeeHrForough, isFalse);
    });
  });

  group('تست ویجت ۳۶۰px RTL — پوسته، میز کار و صفحات عملیاتی با دسترسی محدود', () {
    testWidgets('کاربر فقط دارای Dashboards.Financial کارت قهرمان داشبورد مالی را می‌بیند و کارتابل مخفی است', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final env = await _makeSessionEnv(
        const AuthSession(
          userId: 11,
          token: 'tok-fin',
          username: 'fin_exec',
          role: 'User',
          displayName: 'معاون مالی',
          roleNames: ['معاون مالی'],
          permissions: ['Dashboards.Financial'],
        ),
      );

      await tester.pumpWidget(
        _wrap(env.auth, env.api, HomePage(onOpenTab: (_) {})),
      );
      await _pumpFrames(tester);

      // کارتابل یکپارچه نباید رندر یا فراخوانی شود
      expect(find.text('کارتابل یکپارچه و میز اقدام'), findsNothing);
      expect(
        env.adapter.requestedPaths.any((p) => p.contains('/api/cartable/me')),
        isFalse,
      );

      // کارت قهرمان داشبورد مالی و کاشی داشبورد مالی باید دیده شوند
      expect(find.text('داشبورد مالی و مدیریتی فروشگاه'), findsOneWidget);
      expect(find.text('داشبورد مالی'), findsWidgets);
      // کاشی‌های غیرمجاز نباید دیده شوند
      expect(find.text('دستورکار رایکا'), findsNothing);
      expect(find.text('اتوماسیون اداری توکا'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('HomeShell برای نقش Referrer دقیقاً ۴ تب پنل معرف را نشان می‌دهد', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final env = await _makeSessionEnv(
        const AuthSession(
          userId: 12,
          token: 'tok-ref',
          username: 'ref_1',
          role: 'Referrer',
          displayName: 'مهندس رضایی',
          referrerId: 5,
          permissions: [
            'ReferrerPanel.MyWallet',
            'ReferrerPanel.MyProducts',
            'ReferrerPanel.MyCard',
          ],
        ),
      );

      await tester.pumpWidget(_wrap(env.auth, env.api, const HomeShell()));
      await _pumpFrames(tester);

      expect(find.text('داشبورد من'), findsOneWidget);
      expect(find.text('کیف پول'), findsOneWidget);
      expect(find.text('کالاهای موجود'), findsOneWidget);
      expect(find.text('کارت من'), findsOneWidget);
      expect(find.text('دستورکار رایکا'), findsNothing);
      expect(find.text('اتوماسیون توکا'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('گیت دکمه‌های ایجاد و تب‌ها در اتوماسیون، ایمیل و صورتجلسه برای کاربر فقط-مشاهده', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final env = await _makeSessionEnv(
        const AuthSession(
          userId: 13,
          token: 'tok-view',
          username: 'viewer',
          role: 'User',
          displayName: 'کارشناس مشاهده‌گر',
          permissions: [
            'InnerLetters.View',
            'Email.View',
            'MeetingMinutes.View',
          ],
        ),
      );

      // ۱) اتوماسیون اداری: فقط تب داخلی مجاز است؛ صادره/وارده و دکمهٔ نامهٔ جدید پنهان‌اند
      await tester.pumpWidget(
        _wrap(env.auth, env.api, const OfficeAutomationPage()),
      );
      await _pumpFrames(tester);
      expect(find.text('داخلی'), findsWidgets);
      expect(find.text('صادره'), findsNothing);
      expect(find.text('وارده'), findsNothing);
      expect(find.text('نامهٔ جدید'), findsNothing);
      expect(tester.takeException(), isNull);

      // ۲) ایمیل سازمانی: بدون Email.Personal و Email.Create سوئیچ شخصی و دکمهٔ ایمیل جدید پنهان‌اند
      await tester.pumpWidget(_wrap(env.auth, env.api, const EmailPage()));
      await _pumpFrames(tester);
      expect(find.text('شخصی'), findsNothing);
      expect(find.text('ایمیل جدید'), findsNothing);
      expect(tester.takeException(), isNull);

      // ۳) صورتجلسه: بدون MeetingMinutes.Create دکمهٔ ثبت صورتجلسه پنهان است
      await tester.pumpWidget(
        _wrap(env.auth, env.api, const MinutesListPage()),
      );
      await _pumpFrames(tester);
      expect(find.text('ثبت صورتجلسه'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
