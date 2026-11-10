// ============================================================
//  پوستهٔ اصلی اپ — ناوبری بین ماژول‌ها
//
//  رفتار دکمهٔ «بک» گوشی (درخواست کاربر):
//    ۱) داخل هر ماژول → به تب «خانه» برمی‌گردد (اپ بسته نمی‌شود)
//    ۲) در تب خانه     → می‌پرسد «از برنامه خارج می‌شوید؟»
//       - تأیید → خروج
//       - انصراف → در همان صفحه می‌ماند
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/home/presentation/home_page.dart';
import '../features/messenger/presentation/messenger_page.dart';
import '../features/office_automation/presentation/email_page.dart';
import '../features/office_automation/presentation/office_home_page.dart';
import '../features/work_orders/presentation/work_orders_page.dart';
import 'widgets/glass_nav_bar.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialIndex;

  void _go(int i) {
    if (_index == i) return;
    setState(() => _index = i);
  }

  /// دیالوگ خروج — فقط با تأیید کاربر اپ بسته می‌شود.
  Future<bool> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'خروج از برنامه',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text('برنامه را ببندم؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('بله، ببند'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // در ریشه اجازهٔ خروج فوری را نمی‌دهیم؛ اول می‌پرسیم.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // داخل ماژول → برگرد به خانه
        if (_index != 0) {
          setState(() => _index = 0);
          return;
        }
        // در خانه → تأیید خروج
        if (await _confirmExit()) {
          if (!mounted) return;
          // canPop=false است؛ با سیستمنویگیتور خارج می‌شویم
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        // انتقال نرم بین تب‌ها: محو + بالا آمدن ملایم
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.025),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey<int>(_index),
            child: IndexedStack(
              index: _index,
              children: [
                HomePage(onOpenTab: _go),
                const WorkOrdersPage(),
                const OfficeAutomationPage(),
                const EmailPage(),
                const MessengerPage(),
              ],
            ),
          ),
        ),
        extendBody: true,
        // نوار ناوبری شیشه‌ای شناور با پیل کشویی
        bottomNavigationBar: GlassNavBar(
          index: _index,
          accent: const Color(0xff2547a8),
          tint: const Color(0xff0d7d8c),
          onSelected: _go,
          items: const [
            NavItem(
              label: 'خانه',
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
            ),
            NavItem(
              label: 'دستور کار',
              icon: Icons.assignment_outlined,
              activeIcon: Icons.assignment_rounded,
            ),
            NavItem(
              label: 'اتوماسیون',
              icon: Icons.account_balance_outlined,
              activeIcon: Icons.account_balance_rounded,
            ),
            NavItem(
              label: 'ایمیل',
              icon: Icons.alternate_email_rounded,
              activeIcon: Icons.mark_email_unread_rounded,
            ),
            NavItem(
              label: 'پیام‌رسان',
              icon: Icons.forum_outlined,
              activeIcon: Icons.forum_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
