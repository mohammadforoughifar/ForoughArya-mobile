import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../core/auth/auth_controller.dart';
import '../core/network/api_client.dart';
import '../core/notifications/notification_launcher.dart';
import '../core/notifications/push_service.dart';
import '../features/messenger/data/upload_queue.dart';
import '../features/auth/login_page.dart';
import 'home_shell.dart';
class ForoughApp extends StatelessWidget {
  const ForoughApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xff2547a8);
    return MaterialApp(
      title: 'فروغ آریا',
      // برای باز کردن سند از روی اعلانِ گوشی (بیرون از درخت ویجت‌ها)
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      // ⚠️ حیاتی: بدون این دو delegate، MaterialLocalizations ساخته نمی‌شود و
      // هر TextField/DatePicker در بیلد release به کادر خاکستری تبدیل می‌شود.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Vazirmatn',
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfff4f7fb),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
        cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xffdce3ee)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: Consumer<AuthController>(
        builder: (context, auth, _) {
          if (auth.initializing) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!auth.isLoggedIn) {
            PushService.instance.stop();
            NotificationLauncher.instance.detach();
            return const LoginPage();
          }
          // نوتیفیکیشن واقعی گوشی — تا وقتی کاربر لاگین است فعال می‌ماند
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final api = context.read<ApiClient>();
            // مقصد کلیک روی اعلان‌ها را وصل کن (صفِ کلیک‌های زودرس هم باز می‌شود)
            NotificationLauncher.instance.attach(api);
            // صف ارسال پیوست‌ها به عمر اپ بسته است، نه به صفحهٔ چت
            UploadQueue.instance.attach(api);
            PushService.instance.start(
              ApiClientPushAdapter(api),
              const FlutterSecureStorage(),
            );
          });
          return const HomeShell();
        },
      ),
    );
  }
}
