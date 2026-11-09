// ============================================================
//  پوستهٔ اصلی اپ — ناوبری بین ماژول‌ها
//  تب ۰: خانه (صفحهٔ اصلی — گزارش روزانه، شرکت‌ها، ماژول‌ها)
//  تب ۱: دستور کار (work orders)
//  تب ۲: اتوماسیون اداری (office automation)
//  تب ۳: پست الکترونیک
// ============================================================

import 'package:flutter/material.dart';

import '../features/home/presentation/home_page.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomePage(onOpenTab: _go),
          const WorkOrdersPage(),
          const OfficeAutomationPage(),
          const EmailPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        height: 62,
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
            label: 'اتوماسیون اداری',
          ),
          NavigationDestination(
            icon: Icon(Icons.alternate_email),
            selectedIcon: Icon(Icons.mark_email_unread),
            label: 'پست الکترونیک',
          ),
        ],
      ),
    );
  }
}
