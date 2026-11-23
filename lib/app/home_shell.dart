// ============================================================
//  پوستهٔ اصلی اپ — ناوبری بین ماژول‌ها منطبق بر دسترسی‌های وب
//
//  قواعد نمایش تب‌ها دقیقاً مطابق `Layout/NavMenu.razor`:
//    • نقش `Referrer` → پوستهٔ ۴ بخشی پنل معرف (داشبورد من، کیف پول، کالاهای موجود، کارت من)
//    • سایر نقش‌ها:
//        ۰) میز کار         ← همیشه فعال
//        ۱) دستورکار رایکا  ← فقط با `canSeeWorkOrders`
//        ۲) اتوماسیون توکا  ← فقط با `canSeeOfficeAutomation`
//        ۳) ایمیل سازمانی   ← فقط با `canSeeEmailAny`
//        ۴) پیام رسان میها  ← فعال برای کاربران غیر معرف
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/auth/auth_controller.dart';
import '../core/auth/web_access.dart';
import '../core/utils/fa.dart';
import '../features/home/presentation/home_page.dart';
import '../features/messenger/data/upload_queue.dart';
import '../features/messenger/presentation/messenger_page.dart';
import '../features/messenger/presentation/messenger_style.dart';
import '../features/office_automation/presentation/email_page.dart';
import '../features/office_automation/presentation/office_home_page.dart';
import '../features/shop/presentation/financial_dashboard_page.dart';
import '../features/shop/presentation/referrer_panel_pages.dart';
import '../features/work_orders/presentation/work_orders_page.dart';
import 'widgets/glass_nav_bar.dart';

class _ShellTabSpec {
  const _ShellTabSpec({
    required this.canonicalId,
    required this.item,
    required this.page,
  });

  final int canonicalId;
  final NavItem item;
  final Widget page;
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialIndex;

  void _go(int i, int maxCount) {
    final safe = i.clamp(0, maxCount - 1);
    if (_index == safe) return;
    setState(() => _index = safe);
  }

  void _goCanonical(List<_ShellTabSpec> tabs, int canonicalId) {
    final idx = tabs.indexWhere((t) => t.canonicalId == canonicalId);
    if (idx >= 0) {
      _go(idx, tabs.length);
    }
  }

  List<_ShellTabSpec> _buildTabs(WebAccess access) {
    if (access.isReferrer) {
      return [
        const _ShellTabSpec(
          canonicalId: 100,
          item: NavItem(
            label: 'داشبورد من',
            icon: Icons.speed_outlined,
            activeIcon: Icons.speed_rounded,
          ),
          page: FinancialDashboardPage(embedded: true),
        ),
        if (access.canSeeRefWallet)
          const _ShellTabSpec(
            canonicalId: 101,
            item: NavItem(
              label: 'کیف پول',
              icon: Icons.account_balance_wallet_outlined,
              activeIcon: Icons.account_balance_wallet_rounded,
            ),
            page: MyWalletPage(),
          ),
        if (access.canSeeRefProducts)
          const _ShellTabSpec(
            canonicalId: 102,
            item: NavItem(
              label: 'کالاهای موجود',
              icon: Icons.inventory_2_outlined,
              activeIcon: Icons.inventory_2_rounded,
            ),
            page: MyProductsPage(),
          ),
        if (access.canSeeRefCard)
          const _ShellTabSpec(
            canonicalId: 103,
            item: NavItem(
              label: 'کارت من',
              icon: Icons.badge_outlined,
              activeIcon: Icons.badge_rounded,
            ),
            page: MyCardPage(),
          ),
      ];
    }

    late final List<_ShellTabSpec> specs;
    specs = <_ShellTabSpec>[
      _ShellTabSpec(
        canonicalId: 0,
        item: const NavItem(
          label: 'میز کار',
          icon: Icons.space_dashboard_outlined,
          activeIcon: Icons.space_dashboard_rounded,
        ),
        page: HomePage(onOpenTab: (cid) => _goCanonical(specs, cid)),
      ),
      if (access.canSeeWorkOrders)
        const _ShellTabSpec(
          canonicalId: 1,
          item: NavItem(
            label: 'دستورکار رایکا',
            icon: Icons.assignment_outlined,
            activeIcon: Icons.assignment_rounded,
          ),
          page: WorkOrdersPage(),
        ),
      if (access.canSeeOfficeAutomation)
        const _ShellTabSpec(
          canonicalId: 2,
          item: NavItem(
            label: 'اتوماسیون توکا',
            icon: Icons.mark_email_read_outlined,
            activeIcon: Icons.mark_email_read_rounded,
          ),
          page: OfficeAutomationPage(),
        ),
      if (access.canSeeEmailAny)
        const _ShellTabSpec(
          canonicalId: 3,
          item: NavItem(
            label: 'ایمیل سازمانی',
            icon: Icons.alternate_email_rounded,
            activeIcon: Icons.mark_email_unread_rounded,
          ),
          page: EmailPage(),
        ),
      if (access.canSeeMessenger)
        const _ShellTabSpec(
          canonicalId: 4,
          item: NavItem(
            label: 'پیام رسان میها',
            icon: Icons.forum_outlined,
            activeIcon: Icons.forum_rounded,
          ),
          page: MessengerPage(),
        ),
    ];
    return specs;
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

  Future<void> _confirmReferrerLogout(AuthController auth) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'خروج از حساب کاربری',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          content: const Text('آیا مایل به خروج از پنل معرف هستید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('خروج'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await auth.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController?>(context);
    final access = WebAccess(auth?.session, unrestrictedWhenNull: true);
    final tabs = _buildTabs(access);
    final safeIndex = _index.clamp(0, tabs.length - 1);

    return PopScope(
      // در ریشه اجازهٔ خروج فوری را نمی‌دهیم؛ اول می‌پرسیم.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (safeIndex != 0) {
          setState(() => _index = 0);
          return;
        }
        if (await _confirmExit()) {
          if (!mounted) return;
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: access.isReferrer && auth != null
            ? AppBar(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xff0f172a),
                elevation: 0.5,
                title: Text(
                  auth.session?.displayName.isNotEmpty == true
                      ? 'پنل معرف — ${auth.session!.displayName}'
                      : 'پنل معرف',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                actions: [
                  IconButton(
                    tooltip: 'خروج از حساب کاربری',
                    onPressed: () => _confirmReferrerLogout(auth),
                    icon: const Icon(Icons.logout_rounded, size: 20),
                  ),
                ],
              )
            : null,
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
                key: ValueKey<String>('${tabs.length}_$safeIndex'),
                child: IndexedStack(
                  index: safeIndex,
                  children: [for (final t in tabs) t.page],
                ),
              ),
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
        bottomNavigationBar: tabs.length <= 1
            ? null
            : GlassNavBar(
                index: safeIndex,
                accent: const Color(0xff2547a8),
                tint: const Color(0xff0d7d8c),
                onSelected: (i) => _go(i, tabs.length),
                items: [for (final t in tabs) t.item],
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
