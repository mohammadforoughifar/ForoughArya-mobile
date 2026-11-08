// ============================================================
//  پوستهٔ اصلی اپ — ناوبری بین ماژول‌ها
//  ماژول ۱: دستور کار (work orders)
//  ماژول ۲: اتوماسیون اداری (office automation)
// ============================================================

import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          WorkOrdersPage(),
          OfficeAutomationPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        height: 62,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'دستور کار',
          ),
          NavigationDestination(
            icon: Icon(Icons.mark_email_unread_outlined),
            selectedIcon: Icon(Icons.mark_email_unread),
            label: 'اتوماسیون اداری',
          ),
        ],
      ),
    );
  }
}
