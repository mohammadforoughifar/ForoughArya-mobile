// ============================================================
//  تست جامع «داشبورد مالی فروشگاه» و «داشبورد معرف» در اندروید
//  هم‌تراز با `tests/ShopFinancialDashboard/test_financial_dashboard.py`:
//    ۱) رندر کامل فروش/سود دوره‌ای، ۳ نمودار، بدهکاران، چک‌های دریافتی و صادره،
//       خلاصهٔ انبار، فعالیت‌های اخیر و نقطه سفارش بدون سرریز در عرض ۳۶۰px RTL
//    ۲) خطای ۴۰۳ در یکی از بخش‌های جانبی (`/api/reorder`) سایر بخش‌ها را پنهان نمی‌کند
//       و بنر هشدار «اطلاعات داشبورد کامل بارگذاری نشده است» را نشان می‌دهد
//    ۳) عملیات «وصول شد» و «برگشت» فقط برای چک‌های `source == Invoice` به
//       `/api/dashboard/cheques/{id}/{clear|bounce}` ارسال می‌شوند و چک خزانه ایمن می‌ماند
//    ۴) تسویه نسیه بدهکار به `POST /api/dashboard/credits/{id}/settle?amount=...` می‌رود
//    ۵) عدم مجوز `Dashboards.Financial` پیام عدم دسترسی نشان می‌دهد
//    ۶) حالت نقش `Referrer` داده‌های `/api/my/dashboard` را بدون خطا رندر می‌کند
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/auth/auth_controller.dart';
import 'package:forough_mobile/core/auth/auth_session.dart';
import 'package:forough_mobile/core/network/api_client.dart';
import 'package:forough_mobile/features/shop/presentation/financial_dashboard_page.dart';
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

class _FinancialMockAdapter implements HttpClientAdapter {
  _FinancialMockAdapter({this.failReorder = false});

  final bool failReorder;
  final List<RequestOptions> captured = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured.add(options);
    final p = options.uri.path;

    if (failReorder && p.contains('/api/reorder')) {
      return ResponseBody.fromString(
        jsonEncode({'message': 'عدم مجوز نقطه سفارش'}),
        403,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    Object body = const <String, dynamic>{'ok': true};

    if (p == '/api/dashboard/admin') {
      body = {
        'pendingReceivedChequesCount': 4,
        'pendingIssuedChequesCount': 2,
        'salesToday': 85000000,
        'salesWeek': 420000000,
        'salesMonth': 1680000000,
        'salesQuarter': 4950000000,
        'profitToday': 18500000,
        'profitWeek': 91000000,
        'profitMonth': 340000000,
        'profitQuarter': 980000000,
        'payCash': 2100000000,
        'payCredit': 850000000,
        'payCheque': 1400000000,
        'payInstallment': 600000000,
        'monthlyTrend': [
          {'label': 'خرداد', 'sales': 700000000, 'profit': 140000000},
          {'label': 'تیر', 'sales': 890000000, 'profit': 175000000},
          {'label': 'مرداد', 'sales': 950000000, 'profit': 210000000},
          {'label': 'شهریور', 'sales': 1120000000, 'profit': 245000000},
        ],
        'dailyTrend': [
          {'label': '۱۴۰۵/۰۸/۰۱', 'sales': 45000000, 'profit': 9000000},
          {'label': '۱۴۰۵/۰۸/۱۵', 'sales': 72000000, 'profit': 15000000},
          {'label': '۱۴۰۵/۰۸/۳۰', 'sales': 85000000, 'profit': 18500000},
        ],
        'overdueDebtors': [
          {
            'partyId': 31,
            'partyName': 'شرکت پارس الکتریک',
            'mobile': '09121112233',
            'number': 'F-1405',
            'transactionId': 501,
            'kind': 'نسیه',
            'amount': 32000000,
            'dueDate': '2026-11-15T00:00:00',
            'daysOverdue': 6,
          },
        ],
        'todayCheques': [
          {
            'source': 'Invoice',
            'chequeId': 701,
            'number': '998877',
            'bankName': 'بانک ملت',
            'partyName': 'بازرگانی امید',
            'orderNumber': 'S-204',
            'amount': 54000000,
            'dueDate': '2026-11-18T00:00:00',
            'status': 0,
          },
          {
            'source': 'Treasury',
            'chequeId': 888,
            'number': '112233',
            'bankName': 'بانک صادرات',
            'partyName': 'پخش البرز',
            'orderNumber': '',
            'amount': 21000000,
            'dueDate': '2026-11-20T00:00:00',
            'status': 0,
          },
        ],
        'issuedCheques': [
          {
            'source': 'Invoice',
            'chequeId': 901,
            'number': '554433',
            'bankName': 'بانک تجارت',
            'partyName': 'تأمین‌کننده نوین',
            'orderNumber': 'P-88',
            'amount': 67000000,
            'dueDate': '2026-11-19T00:00:00',
            'status': 0,
          },
        ],
      };
    } else if (p == '/api/dashboard') {
      body = {
        'productCount': 142,
        'warehouseCount': 3,
        'customerCount': 89,
        'supplierCount': 24,
        'belowReorderCount': 2,
        'inventoryValue': 9450000000,
        'todaySales': 85000000,
        'todayPurchases': 30000000,
        'monthSales': 1680000000,
        'monthPurchases': 920000000,
      };
    } else if (p == '/api/dashboard/recent') {
      body = [
        {
          'date': '2026-11-21T09:30:00',
          'type': 'Sale',
          'number': 'S-210',
          'partyName': 'فروشگاه بهاران',
          'amount': 19500000,
        },
      ];
    } else if (p == '/api/reorder') {
      body = {
        'total': 1,
        'items': [
          {
            'productId': 12,
            'productCode': 'K-102',
            'productName': 'مودم فیبر نوری دو بانده',
            'unit': 'عدد',
            'reorderPoint': 10,
            'totalStock': 3,
            'shortage': 7,
          },
        ],
      };
    } else if (p == '/api/my/dashboard') {
      body = {
        'referrerName': 'مهندس کریمی',
        'companyName': 'شرکت مهندسی فروغ آریا',
        'walletBalance': 14500000,
        'totalCommission': 42000000,
        'totalPaid': 27500000,
        'monthCommission': 8900000,
        'orderCount': 9,
        'goodsCommissionPercent': 12,
        'serviceCommissionPercent': 8,
        'recentSales': [
          {
            'number': 'S-301',
            'date': '2026-11-20T00:00:00',
            'customerName': 'شرکت سپهر داده',
            'amount': 110000000,
            'commission': 3200000,
          },
        ],
        'recentPayments': [
          {
            'number': 'PAY-18',
            'date': '2026-11-18T00:00:00',
            'amount': 5000000,
          },
        ],
      };
    } else if (p.contains('/api/trs-cheques') || p.contains('/api/expenses')) {
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

Future<({AuthController auth, ApiClient api, _FinancialMockAdapter adapter})>
_setup(AuthSession session, {bool failReorder = false}) async {
  final storage = _MemStorage();
  await storage.write(
    key: 'auth_session',
    value: jsonEncode(session.toJson()),
  );
  await storage.write(key: 'auth_token', value: session.token);
  final adapter = _FinancialMockAdapter(failReorder: failReorder);
  final api = ApiClient(storage)..dio.httpClientAdapter = adapter;
  final auth = AuthController(api, storage);
  await auth.initialize();
  return (auth: auth, api: api, adapter: adapter);
}

Widget _wrap(AuthController auth, ApiClient api, Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AuthController>.value(value: auth),
    Provider<ApiClient>.value(value: api),
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

Future<void> _settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  testWidgets(
    'داشبورد مالی در عرض ۳۶۰px تمام بخش‌ها، نمودارها، وصول/برگشت چک و تسویه نسیه را بدون سرریز اجرا می‌کند',
    (tester) async {
      tester.view.physicalSize = const Size(360, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final env = await _setup(
        const AuthSession(
          userId: 1,
          token: 'tok-fin',
          username: 'fin',
          role: 'User',
          displayName: 'مدیر مالی',
          permissions: ['Dashboards.Financial', 'Shop.Installments.View'],
        ),
      );

      await tester.pumpWidget(
        _wrap(env.auth, env.api, const FinancialDashboardPage()),
      );
      await _settle(tester);

      // بخش ۱ و ۲: فروش و سود دوره‌ای
      expect(find.text('داشبورد مالی و مدیریتی'), findsOneWidget);
      expect(find.text('فروش امروز'), findsWidgets);
      expect(find.text('فروش هفته (از شنبه)'), findsOneWidget);
      expect(find.text('سود امروز'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // اسکرول به نمودارها و بدهکاران
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('فروش و سود ۶ ماه اخیر'),
        220,
        scrollable: list,
      );
      await _settle(tester, 4);
      expect(find.text('فروش و سود ۶ ماه اخیر'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.text('بدهکاران سررسیدشده'),
        220,
        scrollable: list,
      );
      await _settle(tester, 4);
      expect(find.text('بدهکاران سررسیدشده'), findsOneWidget);
      expect(find.text('شرکت پارس الکتریک'), findsOneWidget);

      // تست تسویه نسیه بدهکار (`POST /api/dashboard/credits/501/settle`)
      await tester.scrollUntilVisible(
        find.text('تسویه نسیه'),
        150,
        scrollable: list,
      );
      await tester.tap(find.text('تسویه نسیه'));
      await _settle(tester, 5);
      await tester.tap(find.text('ثبت تسویه'));
      await _settle(tester, 8);
      expect(
        env.adapter.captured.any(
          (r) =>
              r.method == 'POST' &&
              r.uri.path == '/api/dashboard/credits/501/settle' &&
              r.uri.queryParameters['amount'] == '32000000.0',
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);

      // اسکرول به چک‌های دریافتی
      final listAfterReload = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('وصول شد'),
        220,
        scrollable: listAfterReload,
      );
      await _settle(tester, 5);
      expect(find.textContaining('بازرگانی امید'), findsOneWidget);
      expect(find.textContaining('پخش البرز'), findsOneWidget);

      // چک فاکتور (`chequeId: 701`) → دکمه «وصول شد» به `/api/dashboard/cheques/701/clear` می‌رود
      await tester.tap(find.text('وصول شد'));
      await _settle(tester, 6);
      expect(
        env.adapter.captured.any(
          (r) =>
              r.method == 'POST' &&
              r.uri.path == '/api/dashboard/cheques/701/clear',
        ),
        isTrue,
      );

      // چک فاکتور (`chequeId: 701`) → دکمه «برگشت» مدال ثبت برگشت چک باز می‌کند
      await tester.tap(find.text('برگشت'));
      await _settle(tester, 5);
      expect(find.text('ثبت برگشت چک'), findsOneWidget);
      await tester.tap(find.text('ثبت قطعی برگشت چک'));
      await _settle(tester, 6);
      expect(
        env.adapter.captured.any(
          (r) =>
              r.method == 'POST' &&
              r.uri.path == '/api/dashboard/cheques/701/bounce' &&
              r.uri.queryParameters['reason'] == 'عدم موجودی کافی',
        ),
        isTrue,
      );

      // چک خزانه (`source: Treasury`, `chequeId: 888`) → دکمه «مدیریت چک» هرگز clear فاکتور را صدا نمی‌زند!
      expect(
        env.adapter.captured.any(
          (r) => r.uri.path.contains('/api/dashboard/cheques/888/'),
        ),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'مقاومت در برابر خطای جزئی و کنترل عدم دسترسی Dashboards.Financial و حالت معرف',
    (tester) async {
      tester.view.physicalSize = const Size(360, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // ۱) خطای ۴۰۳ در `/api/reorder` بنر هشدار نشان می‌دهد ولی فروش و چک‌ها رندر می‌شوند
      final partialEnv = await _setup(
        const AuthSession(
          userId: 2,
          token: 'tok-2',
          username: 'fin2',
          role: 'User',
          displayName: 'کارشناس مالی',
          permissions: ['Dashboards.Financial'],
        ),
        failReorder: true,
      );
      await tester.pumpWidget(
        _wrap(partialEnv.auth, partialEnv.api, const FinancialDashboardPage()),
      );
      await _settle(tester);
      expect(
        find.textContaining('اطلاعات داشبورد کامل بارگذاری نشده است'),
        findsOneWidget,
      );
      expect(find.text('فروش امروز'), findsWidgets);
      expect(tester.takeException(), isNull);

      // ۲) کاربر بدون Dashboards.Financial پیام عدم دسترسی می‌بیند
      final deniedEnv = await _setup(
        const AuthSession(
          userId: 3,
          token: 'tok-3',
          username: 'ops',
          role: 'User',
          displayName: 'اپراتور',
          permissions: ['Shop.Dashboard.View'],
        ),
      );
      await tester.pumpWidget(
        _wrap(deniedEnv.auth, deniedEnv.api, const FinancialDashboardPage()),
      );
      await _settle(tester);
      expect(
        find.textContaining('شما به «داشبورد مالی» دسترسی ندارید'),
        findsOneWidget,
      );
      expect(
        deniedEnv.adapter.captured.any(
          (r) => r.uri.path == '/api/dashboard/admin',
        ),
        isFalse,
      );

      // ۳) حالت نقش Referrer
      final refEnv = await _setup(
        const AuthSession(
          userId: 4,
          token: 'tok-ref',
          username: 'ref',
          role: 'Referrer',
          displayName: 'مهندس کریمی',
          referrerId: 9,
          permissions: ['ReferrerPanel.MyWallet'],
        ),
      );
      await tester.pumpWidget(
        _wrap(refEnv.auth, refEnv.api, const FinancialDashboardPage()),
      );
      await _settle(tester);
      expect(find.textContaining('سلام، مهندس کریمی'), findsOneWidget);
      expect(find.text('مانده کیف پول'), findsOneWidget);
      expect(find.text('پورسانت ماه جاری'), findsOneWidget);
      expect(find.text('شرکت سپهر داده'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
