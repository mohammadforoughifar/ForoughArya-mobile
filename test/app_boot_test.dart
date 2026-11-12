// ============================================================
//  تست راه‌اندازی اپ — جلوگیری از بازگشت باگ «کادر خاکستری»
//  بدون MaterialLocalizations، هر TextField در بیلد release
//  به ErrorWidget خاکستری تبدیل می‌شود. این تست حضور delegateها
//  و رندر شدن فرم لاگین را تضمین می‌کند.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:forough_mobile/core/auth/auth_controller.dart';
import 'package:forough_mobile/core/network/api_client.dart';
import 'package:forough_mobile/features/auth/login_page.dart';

void main() {
  testWidgets('فرم لاگین بدون خطای رندر نمایش داده می‌شود', (tester) async {
    const storage = FlutterSecureStorage();
    final api = ApiClient(storage);
    final auth = AuthController(api, storage);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: auth.connections),
          Provider.value(value: api),
        ],
        child: MaterialApp(
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(useMaterial3: true, fontFamily: 'Vazirmatn'),
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const LoginPage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // هیچ ویجتی نباید به ErrorWidget تبدیل شده باشد (کادر خاکستری)
    expect(find.byType(ErrorWidget), findsNothing);
    expect(tester.takeException(), isNull);

    // اجزای کلیدی فرم دیده می‌شوند
    expect(find.text('ورود به فروغ آریا'), findsOneWidget);
    expect(find.text('نام کاربری'), findsOneWidget);
    expect(find.text('رمز عبور'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  test('delegateهای بومی‌سازی برای فارسی موجودند', () {
    expect(GlobalMaterialLocalizations.delegate.isSupported(const Locale('fa')), isTrue);
    expect(GlobalCupertinoLocalizations.delegate.isSupported(const Locale('fa')), isTrue);
  });
}
