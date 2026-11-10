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
        body: IndexedStack(
          index: _index,
          children: [
            HomePage(onOpenTab: _go),
            const WorkOrdersPage(),
            const OfficeAutomationPage(),
            const EmailPage(),
            const MessengerPage(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _go,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'خانه',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'دستور کار',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_outlined),
              selectedIcon: Icon(Icons.account_balance),
              label: 'اتوماسیون',
            ),
            NavigationDestination(
              icon: Icon(Icons.alternate_email),
              selectedIcon: Icon(Icons.mark_email_unread),
              label: 'ایمیل',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum_rounded),
              label: 'پیام‌رسان',
            ),
          ],
        ),
      ),
    );
  }
}
