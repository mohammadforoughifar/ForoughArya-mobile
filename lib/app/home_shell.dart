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

import '../core/utils/fa.dart';
import '../features/home/presentation/home_page.dart';
import '../features/messenger/data/upload_queue.dart';
import '../features/messenger/presentation/messenger_page.dart';
import '../features/messenger/presentation/messenger_style.dart';
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
          child: Stack(
            children: [
              KeyedSubtree(
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
              // نوار زندهٔ ارسال پیوست‌ها — بیرون از صفحهٔ چت هم دیده می‌شود
              const Positioned(
                left: 10,
                right: 10,
                bottom: 86,
                child: _UploadsBanner(),
              ),
            ],
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

/// نوار کوچک بالای نوار پایین: «در حال ارسال فایل… ۴۵٪»
/// با StreamBuilder به صف پس‌زمینه وصل است، پس با خروج از چت هم می‌ماند.
class _UploadsBanner extends StatelessWidget {
  const _UploadsBanner();

  @override
  Widget build(BuildContext context) => StreamBuilder<List<UploadTask>>(
    stream: UploadQueue.instance.changes,
    initialData: UploadQueue.instance.tasks,
    builder: (context, _) {
      final active = UploadQueue.instance.active;
      final failed = UploadQueue.instance.tasks
          .where((t) => t.state == UploadState.failed)
          .toList();
      if (active.isEmpty && failed.isEmpty) return const SizedBox.shrink();
      final tasks = active.isNotEmpty ? active : failed;
      final t = tasks.first;
      final uploading = active.isNotEmpty;
      final p = t.progress;
      return Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: MessengerColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: MessengerColors.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    uploading
                        ? Icons.cloud_upload_outlined
                        : Icons.error_outline_rounded,
                    size: 17,
                    color: uploading
                        ? MessengerColors.brand
                        : MessengerColors.danger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      uploading
                          ? '${t.fileName} — در حال ارسال '
                                '${Fa.digits((p * 100).round())}٪'
                          : 'ارسال ${t.fileName} ناموفق بود',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: MessengerColors.ink,
                      ),
                    ),
                  ),
                  if (!uploading)
                    TextButton(
                      onPressed: () => UploadQueue.instance.retry(t),
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'تلاش دوباره',
                        style: TextStyle(fontSize: 10.5),
                      ),
                    ),
                  if (active.length > 1)
                    Text(
                      '+${Fa.digits(active.length - 1)}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: MessengerColors.inkSoft,
                      ),
                    ),
                ],
              ),
              if (uploading)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 2, right: 2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      value: p == 0 ? null : p,
                      minHeight: 3,
                      backgroundColor: MessengerColors.line,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
