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
import 'cctv_cameras_page.dart';
import 'cctv_nvrs_page.dart';
import 'hardware_dashboard_page.dart';
import 'ipam_page.dart';
import 'it_requests_page.dart';
import 'server_management_page.dart';
import 'system_info_list_page.dart';
import 'system_manual_page.dart';
import 'system_users_page.dart';
import 'vault_page.dart';
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
            if (perms.canSeeItRequests)
              _card(
                context,
                title: 'درخواست خدمت IT',
                subtitle:
                    'ثبت درخواست پشتیبانی، تخصیص کارشناس و پیگیری وضعیت انجام',
                icon: Icons.headset_mic_rounded,
                color: const Color(0xff0284c7),
                onTap: () => _push(context, const ItRequestsPage()),
              ),
            if (perms.canSeeSystemUsers) ...[
              _card(
                context,
                title: 'سیستم‌های ثبت‌شده',
                subtitle:
                    'فهرست تجهیزات رایانه‌ای، وضعیت ایجنت و تغییرات سخت‌افزاری',
                icon: Icons.devices_other_rounded,
                color: const Color(0xff7c3aed),
                onTap: () => _push(context, const SystemInfoListPage()),
              ),
              _card(
                context,
                title: 'شناسنامه سیستم',
                subtitle:
                    'مشخصات فنی قطعات، تخصیص به کاربر و بررسی تغییرات',
                icon: Icons.memory_rounded,
                color: const Color(0xff0f766e),
                onTap: () => _push(context, const SystemInfoListPage()),
              ),
              _card(
                context,
                title: 'ثبت دستی سیستم',
                subtitle:
                    'ثبت شناسنامهٔ سیستم‌هایی که هنوز توسط ایجنت شناسایی نشده‌اند',
                icon: Icons.desktop_windows_rounded,
                color: const Color(0xff0e7490),
                onTap: () => _push(context, const SystemManualPage()),
              ),
              _card(
                context,
                title: 'کاربران سیستم',
                subtitle:
                    'کاربران تجهیزات، شماره پرسنلی، شرکت و واحد سازمانی هر کاربر',
                icon: Icons.people_alt_rounded,
                color: const Color(0xffb45309),
                onTap: () => _push(context, const SystemUsersPage()),
              ),
              if (perms.canSeeServers)
                _card(
                  context,
                  title: 'مدیریت سرورها',
                  subtitle:
                      'شناسنامه، سلامت سخت‌افزار و دریافت Inventory امن از HPE iLO / Redfish',
                  icon: Icons.dns_rounded,
                  color: const Color(0xff2547a8),
                  onTap: () => _push(context, const ServerManagementPage()),
                ),
              if (perms.canSeeIpam)
                _card(
                  context,
                  title: 'مدیریت آی‌پی',
                  subtitle:
                      'نقشهٔ رنج‌های شبکه، شناسنامهٔ هر آی‌پی و کشف خودکار دستگاه‌های متصل',
                  icon: Icons.hub_rounded,
                  color: const Color(0xff0f766e),
                  onTap: () => _push(context, const IpamPage()),
                ),
              if (perms.canSeeCctvCameras)
                _card(
                  context,
                  title: 'دوربین‌های مداربسته',
                  subtitle:
                      'ثبت‌نام دوربین‌ها، گروه‌بندی بر اساس محل و NVR، ورود گروهی و خروجی اکسل',
                  icon: Icons.videocam_rounded,
                  color: const Color(0xff6d43d6),
                  onTap: () => _push(context, const CctvCamerasPage()),
                ),
              if (perms.canSeeCctvNvrs)
                _card(
                  context,
                  title: 'دستگاه‌های NVR',
                  subtitle:
                      'مدیریت دستگاه‌های ضبط NVR/DVR و دوربین‌های متصل به هر دستگاه',
                  icon: Icons.dns_rounded,
                  color: const Color(0xff0891b2),
                  onTap: () => _push(context, const CctvNvrsPage()),
                ),
              if (perms.canSeeItVault)
                _card(
                  context,
                  title: 'گاوصندوق رمزها',
                  subtitle:
                      'رمز سرور، سوییچ، میکروتیک، فایروال و سامانه‌ها با رمزنگاری AES-256 و لاگ دسترسی',
                  icon: Icons.shield_rounded,
                  color: const Color(0xff0f172a),
                  onTap: () => _push(context, const VaultPage()),
                ),
            ],
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
    // همهٔ صفحات گروه «مدیریت سیستم» پیاده شده‌اند.
    return '';
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
