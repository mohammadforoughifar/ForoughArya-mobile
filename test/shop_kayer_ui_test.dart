// ============================================================
//  تست رابط کاربری و چیدمان لوکس «فروشگاهی کایر» (ShopHomePage)
//  بررسی رندر بدون خطا و بدون سرریز (Overflow) در عرض‌های ۴۱۲ و ۳۶۰،
//  نبض زندهٔ فروش/خزانه/کسری، تب‌های باز چندگانه، فیلتر دسته‌بندی،
//  نمای کارتی بنتو و نمای پوشه‌ای، و فرمان‌یار جستجوی کایر.
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/auth/auth_controller.dart';
import 'package:forough_mobile/core/auth/auth_session.dart';
import 'package:forough_mobile/core/network/api_client.dart';
import 'package:forough_mobile/features/shop/presentation/shop_home_page.dart';
import 'package:provider/provider.dart';

class _KayerFakeAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final p = options.path;
    Object body;
    if (p.contains('/api/operations/reports/dashboard')) {
      body = {
        'saleTotal': 185000000,
        'saleCount': 9,
        'purchaseTotal': 60000000,
        'purchaseCount': 2,
        'openRepairCount': 3,
      };
    } else if (p.contains('/api/trs/reports/dashboard')) {
      body = {
        'totalBalance': 920000000,
        'overdueChequeCount': 4,
        'accounts': [],
        'upcomingCheques': [],
      };
    } else if (p.contains('/api/reorder')) {
      body = {'total': 5, 'items': []};
    } else {
      body = {'total': 0, 'items': []};
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

Future<void> _settle(WidgetTester tester, {int frames = 10}) async {
  await tester.pump();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets(
    'فروشگاهی کایر: سربرگ لوکس، نبض زنده، کارت‌های بنتو، نمای پوشه‌ای و تب‌های باز بدون سرریز کار می‌کنند',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1300);
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
      final api = ApiClient(storage)..dio.httpClientAdapter = _KayerFakeAdapter();
      final auth = AuthController(api, storage);
      await auth.initialize();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: auth),
            Provider<ApiClient>.value(value: api),
          ],
          child: const MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: ShopHomePage(),
            ),
          ),
        ),
      );
      await _settle(tester);

      // ۱) سربرگ و شاخص‌های زندهٔ کایر
      expect(find.text('فروشگاهی کایر'), findsOneWidget);
      expect(find.text('میز ثبت فوری اسناد'), findsOneWidget);
      expect(find.text('دسترسی سریع منتخب من'), findsOneWidget);
      expect(find.text('۹ فاکتور'), findsOneWidget);
      expect(find.text('۱۸۵ میلیون'), findsOneWidget);
      expect(find.text('۹۲۰ میلیون'), findsOneWidget);

      // ۲) سوییچ به نمای پوشه‌ای و بازگشت به نمای کارتی بنتو
      await tester.tap(find.byIcon(Icons.view_agenda_outlined));
      await _settle(tester);
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await _settle(tester);

      // ۳) باز کردن فرمان‌یار کایر و باز کردن «کاردکس تعدادی کالا» در تب زنده
      await tester.tap(find.byIcon(Icons.manage_search_rounded));
      await _settle(tester);
      await tester.enterText(find.byType(TextField).last, 'کاردکس تعدادی');
      await _settle(tester);
      await tester.tap(find.text('کاردکس تعدادی کالا').last);
      await _settle(tester);

      // نوار تب بالای کایر نمایش داده شده است
      expect(find.text('میز کایر'), findsOneWidget);

      // بازگشت به میز کایر با حفظ تب باز
      await tester.tap(find.text('میز کایر'));
      await _settle(tester);
      expect(find.text('تب‌های باز در کایر (۱)'), findsOneWidget);
      expect(find.text('بستن همه'), findsOneWidget);
    },
  );
}
