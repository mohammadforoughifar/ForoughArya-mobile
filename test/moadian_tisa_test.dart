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
import 'package:forough_mobile/features/home/data/home_repository.dart';
import 'package:forough_mobile/features/moadian/data/moadian_calc.dart';
import 'package:forough_mobile/features/moadian/data/moadian_perms.dart';
import 'package:forough_mobile/features/moadian/data/moadian_repository.dart';
import 'package:forough_mobile/features/moadian/models/moadian_models.dart';
import 'package:forough_mobile/features/moadian/presentation/moadian_home_page.dart';
import 'package:forough_mobile/features/moadian/presentation/moadian_invoice_detail_page.dart';
import 'package:forough_mobile/features/moadian/presentation/moadian_invoice_form_page.dart';
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

class _MoadianFakeAdapter implements HttpClientAdapter {
  final List<RequestOptions> captured = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured.add(options);
    final p = options.path;
    Map<String, dynamic> envelope(dynamic data, {int status = 200, bool ok = true, String msg = 'OK'}) => {
      'data': data,
      'status': status,
      'success': ok,
      'message': msg,
    };

    Object body;
    if (p.contains('Moadian/GetCpInfos')) {
      body = envelope([
        {
          'cpInfoId': 11,
          'companyId': 1,
          'persianName': 'شرکت مهندسی فروغ آریا',
          'englishName': 'Forough Arya Co',
          'nationalId': '10101234567',
          'economicNumber': '411123456789',
          'type': 'حقوقی',
          'postalCode': '1415563111',
        },
      ]);
    } else if (p.contains('Moadian/GetFiscalYears')) {
      body = envelope([
        {
          'id': 3,
          'cpInfoId': 11,
          'title': 'سال مالی ۱۴۰۵',
          'startDate': '2026-03-21T00:00:00',
          'endDate': '2027-03-20T23:59:59',
          'isActive': true,
        },
      ]);
    } else if (p.contains('Moadian/GetConnectForCpInfo')) {
      body = envelope({
        'id': 5,
        'cpinfoid': 11,
        'webServiceAddress': 'https://tp.tax.gov.ir/req/api',
        'taxMemoryID': 'A12BCD',
        'filePrivatekey': {
          'fileName': 'private_key.pem',
          'fileSize': 1704,
          'fileType': 'application/x-pem-file',
          'fileContent': 'TUlJRXY=',
        },
      });
    } else if (p.contains('Moadian/GetAllCostomer')) {
      body = envelope([
        {
          'costomerID': 21,
          'cpInfoId': 11,
          'type': 'حقوقی',
          'name': 'شرکت توسعه صنایع پارس',
          'nationalID': '10861234560',
          'economicNumber': '411987654321',
          'postalCode': '1587511111',
          'phone': '02188990011',
        },
      ]);
    } else if (p.contains('Moadian/GetGoodOrServiceForComboAsync')) {
      body = envelope([
        {
          'goodsOrServicesID': 301,
          'cpInfoId': 11,
          'name': 'سرور رک‌مونت صنعتی',
          'uniqueIdentifier': '2901234567890',
          'price': 25000000,
          'valueAddedPercentage': 10,
          'unitOfMeasurement': 'عدد / فقره',
        },
      ]);
    } else if (p.contains('Moadian/GetGoodOrService')) {
      body = envelope({
        'items': [
          {
            'goodsOrServicesID': 301,
            'cpInfoId': 11,
            'name': 'سرور رک‌مونت صنعتی',
            'uniqueIdentifier': '2901234567890',
            'price': 25000000,
            'valueAddedPercentage': 10,
            'unitOfMeasurement': 'عدد / فقره',
          },
        ],
        'totalCount': 1,
        'page': 1,
        'pageSize': 15,
      });
    } else if (p.contains('Moadian/GetAllUnitOfMeasurementAsync')) {
      body = envelope({
        'items': [
          {
            'unitOfMeasurementID': 1,
            'cpInfoId': 11,
            'name': 'عدد / فقره',
            'code': '164',
          },
        ],
        'totalCount': 1,
        'page': 1,
        'pageSize': 20,
      });
    } else if (p.contains('Moadian/GetUnitOfMeasurementForComboAsync')) {
      body = envelope([
        {
          'unitOfMeasurementID': 1,
          'cpInfoId': 11,
          'name': 'عدد / فقره',
          'code': '164',
        },
      ]);
    } else if (p.contains('Moadian/NextInvoiceNumber')) {
      body = envelope(1405);
    } else if (p.contains('Moadian/GetAllInvoice')) {
      body = envelope({
        'invoices': {
          'items': [
            {
              'invoiceID': 901,
              'id': 901,
              'numberInvoice': 1404,
              'cpInfoId': 11,
              'persianName': 'شرکت مهندسی فروغ آریا',
              'customerID': 21,
              'customerName': 'شرکت توسعه صنایع پارس',
              'typePattern': 'نوع اول',
              'paymentType': 'نقدی',
              'dateOrder': '2026-11-20T00:00:00',
              'totalMoney': 27500000,
              'statusSentToSystemInt': '4',
              'referenceId': 'ref-uuid-901',
              'taxNumber': 'A12BCD051F200000000901',
              'subject': 'اصلی',
              'showButtons': true,
            },
            {
              'invoiceID': 902,
              'id': 902,
              'numberInvoice': 1405,
              'cpInfoId': 11,
              'persianName': 'شرکت مهندسی فروغ آریا',
              'customerID': 21,
              'customerName': 'شرکت توسعه صنایع پارس',
              'typePattern': 'نوع اول',
              'paymentType': 'نقدی',
              'dateOrder': '2026-11-21T00:00:00',
              'totalMoney': 11000000,
              'statusSentToSystemInt': '0',
              'subject': 'اصلی',
              'showButtons': true,
            },
          ],
          'totalCount': 2,
          'page': 1,
          'pageSize': 15,
        },
        'labels': {
          'lblAll': '2',
          'lblNotSentToSystem': '1',
          'lblSentToSystem': '1',
          'lblInquiry': '0',
          'lblLackOfResponsiveness': '1',
          'lblError': '0',
        },
      });
    } else if (p.contains('Moadian/GetInvoiceByIdAsync')) {
      body = envelope({
        'invoiceID': 901,
        'id': 901,
        'numberInvoice': 1404,
        'cpInfoId': 11,
        'persianName': 'شرکت مهندسی فروغ آریا',
        'sellerNationalId': '10101234567',
        'sellerEconomicNo': '411123456789',
        'customerID': 21,
        'customerName': 'شرکت توسعه صنایع پارس',
        'buyerNationalId': '10861234560',
        'buyerEconomicNo': '411987654321',
        'fiscalYearID': '3',
        'fiscalYearName': 'سال مالی ۱۴۰۵',
        'typePattern': 'نوع اول',
        'paymentType': 'نقدی',
        'dateOrder': '2026-11-20T00:00:00',
        'totalMoney': 27500000,
        'statusSentToSystemInt': '4',
        'referenceId': 'ref-uuid-901',
        'taxNumber': 'A12BCD051F200000000901',
        'subject': 'اصلی',
        'showButtons': true,
        'invoiceItems': [
          {
            'invoiceItemID': 1,
            'goodsOrServicesID': 301,
            'name': 'سرور رک‌مونت صنعتی',
            'uniqueIdentifier': '2901234567890',
            'count': 1,
            'priceUnit': 25000000,
            'discount': 0,
            'valueAddedPercentage': 10,
            'unitOfMeasurement': 'عدد / فقره',
          },
        ],
      });
    } else if (p.contains('Moadian/EslahiInvoiceAsync')) {
      // شبیه‌سازی دقیق باگ سرور در کد ۵۰۰ با Success=true تا محافظ کلاینت تست شود!
      body = {
        'data': null,
        'status': 500,
        'success': true,
        'message': 'خطای سرور در ارسال اصلاحیه',
      };
    } else {
      body = envelope({'ok': true});
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

Widget _wrapWithApp(AuthController auth, ApiClient api, Widget child) {
  return MultiProvider(
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
}

Future<void> _settle(WidgetTester tester, {int frames = 10}) async {
  await tester.pump();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  group('MoadianCalc و MoadianPerms — منطق مالیاتی و وضعیت‌ها', () {
    test('محاسبه دقیق ارزش افزوده بدون اعشار (Truncate) و جمع نهایی', () {
      final item = MoadianInvoiceItem(
        count: 3,
        priceUnit: 333333,
        discount: 1000,
        valueAddedPercentage: 9,
      );
      expect(MoadianCalc.lineGross(item), 999999);
      expect(MoadianCalc.lineNet(item), 998999);
      // 998999 * 9 / 100 = 89909.91 → Truncate = 89909
      expect(MoadianCalc.lineVat(item), 89909);
      expect(MoadianCalc.lineTotal(item), 998999 + 89909);
    });

    test('تفکیک شماره مالیاتی اصلی و مرجع در اسناد اصلاحی/ابطالی/برگشت', () {
      final orig = MoadianInvoice(
        id: 1,
        subject: 'اصلی',
        taxNumber: 'A12BCD051F200000000001',
      );
      expect(MoadianCalc.primaryTaxNumber(orig), 'A12BCD051F200000000001');
      expect(MoadianCalc.referenceTaxNumber(orig), isEmpty);

      final eslahi = MoadianInvoice(
        id: 2,
        subject: 'اصلاحی',
        taxNumber: 'A12BCD051F200000000001',
        newTaxNumber: 'A12BCD051F200000000002',
      );
      expect(MoadianCalc.primaryTaxNumber(eslahi), 'A12BCD051F200000000002');
      expect(MoadianCalc.referenceTaxNumber(eslahi), 'A12BCD051F200000000001');
    });

    test('ماتریس مجوز عملیات روی کدهای وضعیت ۰ تا ۱۱', () {
      expect(MoadianPerms.canSend('0', true), isTrue);
      expect(MoadianPerms.canSend('5', true), isTrue);
      expect(MoadianPerms.canSend('3', true), isFalse);
      expect(MoadianPerms.canDelete('0', true), isTrue);
      expect(MoadianPerms.canDelete('5', true), isFalse);
      expect(MoadianPerms.canInquiry('1', 'ref-1'), isTrue);
      expect(MoadianPerms.canInquiry('4', ''), isFalse);
      expect(MoadianPerms.canReactManually('4', 'ref-1'), isTrue);
      expect(MoadianPerms.canReference('7', 'ref-1'), isTrue);
      expect(MoadianPerms.canEbtal('2', 'ref-1'), isTrue);
    });

    test('مودیان تیسا در گرید ماژول‌های صفحه اصلی فعال است (بدون به‌زودی)', () {
      final tiles = buildModuleTiles(openTabs: const {1, 2, 3, 4});
      final moadian = tiles.firstWhere((m) => m.id == 'moadian');
      expect(moadian.name, 'مودیان تیسا');
      expect(moadian.badge, isNull);
      expect(moadian.onTapName, 'moadian');
    });
  });

  group('MoadianRepository — هدر X-Moadian-CpInfo و گارد باگ سرور', () {
    test('ارسال هدر X-Moadian-CpInfo و تشخیص خطای Status=500 حتی با Success=true', () async {
      final storage = _MemStorage();
      final adapter = _MoadianFakeAdapter();
      final api = ApiClient(storage)..dio.httpClientAdapter = adapter;
      final repo = MoadianRepository(api, storage);

      final page = await repo.getInvoices(cpInfoId: 11);
      expect(page.invoices.items.length, 2);
      expect(page.labels.all, 2);
      expect(page.labels.notSent, 1);
      expect(
        adapter.captured.last.headers['X-Moadian-CpInfo'],
        '11',
      );

      final buggyRes = await repo.eslahiInvoice(
        MoadianInvoice(id: 901, cpInfoId: 11),
      );
      expect(buggyRes.status, 500);
      expect(buggyRes.success, isFalse);
    });
  });

  group('تست ویجت ۳۶۰ پیکسل RTL — بدون سرریز در همه تب‌ها و صفحات', () {
    testWidgets('پوسته مودیان تیسا (۴ تب)، فرم صدور و صفحه جزئیات در عرض ۳۶۰ بدون خطا رندر می‌شوند', (tester) async {
      tester.view.physicalSize = const Size(360, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final storage = _MemStorage();
      await storage.write(
        key: 'auth_session',
        value: jsonEncode(
          const AuthSession(
            userId: 1,
            token: 'tok',
            username: 'admin',
            role: 'Admin',
            displayName: 'مدیر سیستم',
            permissions: ['*'],
          ).toJson(),
        ),
      );
      final api = ApiClient(storage)
        ..dio.httpClientAdapter = _MoadianFakeAdapter();
      final auth = AuthController(api, storage);
      await auth.initialize();

      // ۱. پوسته اصلی مودیان تیسا و گردش در هر ۴ تب
      await tester.pumpWidget(_wrapWithApp(auth, api, const MoadianHomePage()));
      await _settle(tester);

      expect(find.textContaining('مودیان تیسا'), findsWidgets);
      expect(find.textContaining('شرکت مهندسی فروغ آریا'), findsWidgets);
      expect(tester.takeException(), isNull);

      // تب ۲: صورتحساب‌ها
      await tester.tap(find.text('صورتحساب‌ها'));
      await _settle(tester);
      expect(find.textContaining('فاکتور #'), findsWidgets);
      expect(tester.takeException(), isNull);

      // تب ۳: اطلاعات پایه (و گردش در هر ۵ زیربخش)
      await tester.tap(find.text('اطلاعات پایه'));
      await _settle(tester);
      expect(find.textContaining('پرونده‌های شرکت مودیان'), findsOneWidget);

      final connChip = find.widgetWithText(ChoiceChip, 'اتصال و کلید');
      await tester.ensureVisible(connChip);
      await tester.tap(connChip);
      await _settle(tester);
      expect(find.textContaining('حافظه مالیاتی'), findsWidgets);
      expect(tester.takeException(), isNull);

      final goodsChip = find.widgetWithText(ChoiceChip, 'کالا و خدمات');
      await tester.ensureVisible(goodsChip);
      await tester.tap(goodsChip);
      await _settle(tester);
      expect(find.textContaining('سرور رک‌مونت صنعتی'), findsWidgets);
      expect(tester.takeException(), isNull);

      final custChip = find.widgetWithText(ChoiceChip, 'مشتریان');
      await tester.ensureVisible(custChip);
      await tester.tap(custChip);
      await _settle(tester);
      expect(find.textContaining('شرکت توسعه صنایع پارس'), findsWidgets);
      expect(tester.takeException(), isNull);

      final unitChip = find.widgetWithText(ChoiceChip, 'واحد سنجش');
      await tester.ensureVisible(unitChip);
      await tester.tap(unitChip);
      await _settle(tester);
      expect(find.textContaining('۱۶۴'), findsWidgets);
      expect(tester.takeException(), isNull);

      // تب ۴: راهنما و عیب‌یاب
      await tester.tap(find.text('راهنما'));
      await _settle(tester);
      expect(find.textContaining('راهنمای جامع'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // ۲. فرم صدور صورتحساب جدید در عرض ۳۶۰
      await tester.pumpWidget(
        _wrapWithApp(
          auth,
          api,
          const MoadianInvoiceFormPage(
            mode: MoadianFormMode.create,
            initialCpInfoId: 11,
          ),
        ),
      );
      await _settle(tester);
      expect(find.textContaining('صدور صورتحساب جدید'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // ۳. صفحه جزئیات و کنسول عملیات در عرض ۳۶۰
      await tester.pumpWidget(
        _wrapWithApp(
          auth,
          api,
          const MoadianInvoiceDetailPage(invoiceId: 901, cpInfoId: 11),
        ),
      );
      await _settle(tester);
      expect(find.textContaining('A12BCD051F200000000901'), findsOneWidget);
      expect(find.textContaining('ثبت واکنش خریدار'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
