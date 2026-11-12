import 'dart:async';

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

class ForoughApp extends StatefulWidget {
  const ForoughApp({super.key});

  @override
  State<ForoughApp> createState() => _ForoughAppState();
}

class _ForoughAppState extends State<ForoughApp> with WidgetsBindingObserver {
  /// وقتی اپ از پس‌زمینه برمی‌گردد، تایمر بررسی اعلان‌ها در پس‌زمینه متوقف
  /// بوده است؛ یک بررسی فوری + راه‌اندازی دوبارهٔ تایمر لازم است. بدون این،
  /// اعلان‌های دورهٔ پس‌زمینه «هستند ولی نمایش داده نمی‌شوند».
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // شبکه ممکن است عوض شده باشد (وای‌فای شرکت ↔ اینترنت همراه)
      final auth = context.read<AuthController>();
      if (auth.isLoggedIn) unawaited(auth.connections.recheck());
      PushService.instance.resumePolling();
      // اگر سیستم سرویس بومی را کشته بود (باتری/ری‌استارت)، دوباره روشن شود
      PushService.instance.ensureForeground();
    }
  }

  final _messenger = GlobalKey<ScaffoldMessengerState>();
  ValueNotifier<String?>? _switchNotice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // اطلاع‌رسانی کوتاه وقتی اتصال خودکار به آدرس دیگری سوییچ شد
    _switchNotice = context.read<AuthController>().connections.lastAutoSwitch
      ..addListener(_showSwitchNotice);
  }

  void _showSwitchNotice() {
    final msg = _switchNotice?.value;
    if (msg == null) return;
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(msg)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  void dispose() {
    _switchNotice?.removeListener(_showSwitchNotice);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xff2547a8);
    return MaterialApp(
      title: 'فروغ آریا',
      // برای باز کردن سند از روی اعلانِ گوشی (بیرون از درخت ویجت‌ها)
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: _messenger,
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
          // با تعویض سرور، کل صفحات از نو ساخته شوند (دادهٔ سرور قبلی نماند)
          return KeyedSubtree(
            key: ValueKey('server-${auth.serverGeneration}'),
            child: const HomeShell(),
          );
        },
      ),
    );
  }
}
