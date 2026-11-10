// ============================================================
//  خانهٔ «مدیریت سخت‌افزار» — فاز ۹-الف
//  آینهٔ منوی وب: آیتم مستقل «داشبورد سخت‌افزار» بالای منو
//  + گروه «مدیریت سیستم» (فازهای بعدی همین‌جا اضافه می‌شوند).
//
//  گیت گروه در وب (`NavMenu.razor`):
//    ShowAdminGroup => CanSeeAny(ItRequests, SystemUsers, CctvCameras,
//                                CctvNvrs, ItVault, Servers, Ipam)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/it_perms.dart';
import 'hardware_dashboard_page.dart';
import '../../shop/presentation/shop_style.dart';

class ItHomePage extends StatelessWidget {
  const ItHomePage({super.key});

  void _push(BuildContext context, Widget page) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final perms = ItPerms(context.read<AuthController>().session);
    final canSeeDashboards = perms.canSeeHardwareDashboard;
    final canSeeGroup = perms.canSeeAdminGroup;

    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: const Text(
          'مدیریت سخت‌افزار',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
        children: [
          const ShopHeader(
            title: 'مدیریت سخت‌افزار و زیرساخت',
            subtitle:
                'پایش بلادرنگ تجهیزات، درخواست‌های خدمت IT، شناسنامه سیستم‌ها، سرورها، شبکه و دوربین‌ها',
            icon: Icons.dns_rounded,
            badge: 'IT',
          ),
          const SizedBox(height: 12),
          if (!canSeeDashboards && !canSeeGroup)
            const ShopEmpty(
              title: 'دسترسی ندارید',
              subtitle:
                  'برای مشاهدهٔ بخش‌های مدیریت سخت‌افزار با مدیر سیستم تماس بگیرید.',
              icon: Icons.shield_outlined,
            ),
          // ---------- آیتم مستقلِ بالای منوی وب ----------
          if (canSeeDashboards)
            _card(
              context,
              title: 'داشبورد سخت‌افزار',
              subtitle:
                  'وضعیت زندهٔ سیستم‌ها، دوربین‌ها و NVRها — پویش هر ۳۰ ثانیه',
              icon: Icons.memory_rounded,
              color: const Color(0xff4f46e5),
              onTap: () => _push(context, const HardwareDashboardPage()),
            ),
          // ---------- گروه «مدیریت سیستم» ----------
          if (canSeeGroup) ...[
            const SizedBox(height: 14),
            const Row(
              children: [
                Icon(
                  Icons.desktop_windows_rounded,
                  size: 15,
                  color: ShopColors.inkSoft,
                ),
                SizedBox(width: 6),
                Text(
                  'مدیریت سیستم',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _pendingNote(perms),
                style: const TextStyle(
                  fontSize: 10.5,
                  height: 1.7,
                  color: ShopColors.inkFaint,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// متن راهنمای گروه — تا فازهای بعدی که صفحات را اضافه می‌کنند.
  static String _pendingNote(ItPerms perms) {
    final parts = <String>[];
    if (perms.canSeeItRequests) parts.add('درخواست خدمت IT');
    if (perms.canSeeSystemUsers) parts.add('سیستم‌ها و شناسنامه');
    if (perms.canSeeServers) parts.add('سرورها');
    if (perms.canSeeIpam) parts.add('مدیریت آی‌پی');
    if (perms.canSeeCctvCameras) parts.add('دوربین‌های مداربسته');
    if (perms.canSeeCctvNvrs) parts.add('دستگاه‌های NVR');
    if (perms.canSeeItVault) parts.add('گاوصندوق رمزها');
    if (parts.isEmpty) return '';
    return 'شما مجوز مشاهدهٔ این بخش‌ها را دارید: ${parts.join('، ')}.\n'
        'صفحهٔ اختصاصی هر یک در فازهای بعدی همین ماژول اضافه می‌شود.';
  }

  Widget _card(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ShopColors.line),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.6,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left_rounded,
                size: 18,
                color: ShopColors.inkFaint,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
