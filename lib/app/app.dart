import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth/auth_controller.dart';
import '../features/auth/login_page.dart';
import '../features/work_orders/presentation/work_orders_page.dart';

class ForoughApp extends StatelessWidget {
  const ForoughApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xff2547a8);
    return MaterialApp(
      title: 'فروغ آریا',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
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
          return auth.isLoggedIn ? const WorkOrdersPage() : const LoginPage();
        },
      ),
    );
  }
}
