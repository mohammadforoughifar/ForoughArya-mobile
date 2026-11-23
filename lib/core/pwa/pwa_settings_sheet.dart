// ============================================================
//  شیت تنظیمات نسخهٔ وب و آیفون (iOS Safari PWA + Web Push Control Center)
//
//  قابلیت‌ها:
//    ۱) تشخیص هوشمند وضعیت نصب روی آیفون / آیپد (Standalone یا مرورگر)
//       و تشخیص مرورگرهای درون‌برنامه‌ای (تلگرام / واتساپ / اینستاگرام)
//    ۲) راهنمای تصویری ۳ مرحله‌ای نصب روی صفحهٔ اصلی آیفون (Add to Home Screen)
//    ۳) فعال‌سازی، بررسی وضعیت، غیرفعال‌سازی و ارسال اعلان آزمایشی
//       برای نوتیفیکیشن استاندارد iOS 16.4+ (متصل به VAPID سرور)
//    ۴) بررسی و دریافت آخرین نسخهٔ کش آفلاین (Service Worker Update)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import '../network/api_client.dart';
import 'pwa_bridge.dart';

Future<void> openPwaSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const PwaSettingsSheet(),
  );
}

class PwaSettingsSheet extends StatefulWidget {
  const PwaSettingsSheet({super.key});

  @override
  State<PwaSettingsSheet> createState() => _PwaSettingsSheetState();
}

class _PwaSettingsSheetState extends State<PwaSettingsSheet> {
  late PwaEnvironment _env = PwaBridge.instance.environment();
  PwaPushStatus? _push;
  bool _busyPush = false;
  bool _busyUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPushState());
  }

  AuthController? _maybeAuth() {
    try {
      return Provider.of<AuthController>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  ApiClient? _maybeApi() {
    try {
      return Provider.of<ApiClient>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshPushState() async {
    if (!mounted) return;
    setState(() {
      _env = PwaBridge.instance.environment();
    });
    final auth = _maybeAuth();
    final api = _maybeApi();
    final session = auth?.session;
    if (session == null || session.token.isEmpty || api == null) return;
    setState(() => _busyPush = true);
    try {
      final st = await PwaBridge.instance.pushState(
        apiBaseUrl: api.baseUrl,
        token: session.token,
        userId: session.userId,
        companyId: api.companyId,
      );
      if (mounted) setState(() => _push = st);
    } finally {
      if (mounted) setState(() => _busyPush = false);
    }
  }

  Future<void> _togglePush(bool enable) async {
    final auth = _maybeAuth();
    final api = _maybeApi();
    final session = auth?.session;
    if (session == null || session.token.isEmpty || api == null) return;
    setState(() => _busyPush = true);
    try {
      final st = enable
          ? await PwaBridge.instance.enablePush(
              apiBaseUrl: api.baseUrl,
              token: session.token,
              userId: session.userId,
              companyId: api.companyId,
            )
          : await PwaBridge.instance.disablePush(
              apiBaseUrl: api.baseUrl,
              token: session.token,
              companyId: api.companyId,
            );
      if (!mounted) return;
      setState(() {
        _push = st;
        _env = PwaBridge.instance.environment();
      });
      if (st.message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(st.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyPush = false);
    }
  }

  Future<void> _sendTestPush() async {
    final auth = _maybeAuth();
    final api = _maybeApi();
    final session = auth?.session;
    if (session == null || session.token.isEmpty || api == null) return;
    setState(() => _busyPush = true);
    try {
      final st = await PwaBridge.instance.testPush(
        apiBaseUrl: api.baseUrl,
        token: session.token,
        companyId: api.companyId,
      );
      if (!mounted) return;
      if (st.message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(st.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _refreshPushState();
    } finally {
      if (mounted) setState(() => _busyPush = false);
    }
  }

  Future<void> _checkUpdate() async {
    setState(() => _busyUpdate = true);
    try {
      final updated = await PwaBridge.instance.checkForUpdates();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated
                ? 'نسخهٔ تازه دریافت شد؛ صفحه در حال بازآوری است…'
                : 'شما هم‌اکنون از آخرین نسخهٔ وب‌اپ استفاده می‌کنید.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyUpdate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = _maybeAuth();
    final loggedIn = auth?.isLoggedIn == true;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  18,
                  14,
                  18,
                  20 + bottomInset + bottomPad,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeroBanner(),
                    const SizedBox(height: 14),
                    _buildInstallSection(),
                    if (loggedIn) ...[
                      const SizedBox(height: 14),
                      _buildPushSection(),
                    ],
                    const SizedBox(height: 14),
                    _buildOfflineUpdateSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    final installed = _env.isStandalone;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF312E81)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x261E3A8A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.phone_iphone_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'نسخهٔ وب‌اپلیکیشن آیفون (iOS PWA)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      installed
                          ? 'اجرا در حالت تمام‌صفحهٔ بومی (Standalone)'
                          : 'اجرا در مرورگر — قابل نصب روی صفحهٔ اصلی آیفون',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                tooltip: 'بستن',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusPill(
                icon: installed
                    ? Icons.verified_rounded
                    : Icons.install_mobile_rounded,
                label: installed ? 'نصب‌شده در Home Screen' : 'آمادهٔ نصب',
                color: installed
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF59E0B),
              ),
              _statusPill(
                icon: _env.isOnline
                    ? Icons.wifi_rounded
                    : Icons.wifi_off_rounded,
                label: _env.isOnline ? 'آنلاین' : 'حالت آفلاین',
                color: _env.isOnline
                    ? const Color(0xFF38BDF8)
                    : const Color(0xFFFB7185),
              ),
              if (_env.isIos && _env.iosMajor > 0)
                _statusPill(
                  icon: Icons.apple_rounded,
                  label: 'iOS ${_env.iosMajor}',
                  color: const Color(0xFFA5B4FC),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallSection() {
    if (_env.isStandalone) {
      return _sectionCard(
        icon: Icons.check_circle_rounded,
        iconColor: const Color(0xFF059669),
        title: 'اپلیکیشن روی صفحهٔ اصلی آیفون نصب است',
        child: const Text(
          'اپ در حالت تمام‌صفحه (بدون نوار آدرس سافاری)، با پشتیبانی کامل از ناچ و Dynamic Island، ذخیرهٔ آفلاین و اشتراک‌گذاری بومی فایل‌های iOS در حال اجراست.',
          style: TextStyle(
            fontSize: 12,
            height: 1.75,
            color: Color(0xFF475569),
          ),
        ),
      );
    }

    return _sectionCard(
      icon: Icons.add_to_home_screen_rounded,
      iconColor: const Color(0xFF2563EB),
      title: 'نصب سریع روی صفحهٔ اصلی آیفون (Add to Home Screen)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_env.isInAppBrowser) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFDC2626),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لینک را داخل مرورگر داخلی تلگرام/اینستاگرام باز کرده‌اید. ابتدا از منوی بالا یا پایین گزینهٔ «Open in Safari» را بزنید تا امکان نصب فعال شود.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.65,
                        color: Color(0xFF991B1B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          _stepRow(
            number: '۱',
            icon: Icons.ios_share_rounded,
            title: 'دکمهٔ اشتراک‌گذاری (Share) سافاری را بزنید',
            subtitle: 'آیکن مربع با فلش رو به بالا در نوار پایین مرورگر Safari',
          ),
          const SizedBox(height: 10),
          _stepRow(
            number: '۲',
            icon: Icons.add_box_outlined,
            title: 'گزینهٔ «Add to Home Screen» را انتخاب کنید',
            subtitle: 'در فهرست بازشده کمی به پایین اسکرول کنید',
          ),
          const SizedBox(height: 10),
          _stepRow(
            number: '۳',
            icon: Icons.done_all_rounded,
            title: 'دکمهٔ «Add» در گوشهٔ بالا را لمس کنید',
            subtitle:
                'آیکن «فروغ آریا» کنار سایر اپ‌های آیفون قرار می‌گیرد و تمام‌صفحه باز می‌شود',
          ),
        ],
      ),
    );
  }

  Widget _stepRow({
    required String number,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, size: 20, color: const Color(0xFF2563EB)),
        ],
      ),
    );
  }

  Widget _buildPushSection() {
    final enabled = _push?.enabled == true;
    final needsHomeScreen = _env.needsIosHomeScreenForPush;
    final msg = _push?.message.isNotEmpty == true
        ? _push!.message
        : (needsHomeScreen
              ? 'در آیفون (iOS 16.4 به بعد)، اپل فقط برای وب‌اپ‌های نصب‌شده در صفحهٔ اصلی (Add to Home Screen) اجازهٔ نوتیفیکیشن پس‌زمینه می‌دهد.'
              : 'دریافت آنی نامه‌های ارجاع‌شده، دستور کارها و پیام‌ها روی قفل صفحهٔ آیفون.');

    return _sectionCard(
      icon: enabled
          ? Icons.notifications_active_rounded
          : Icons.notifications_none_rounded,
      iconColor: enabled ? const Color(0xFF059669) : const Color(0xFF4F46E5),
      title: 'اعلان لحظه‌ای آیفون (iOS Web Push)',
      trailing: _busyPush
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: enabled
                    ? const Color(0xFFD1FAE5)
                    : const Color(0xFFE0E7FF),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                enabled ? 'فعال' : 'غیرفعال',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: enabled
                      ? const Color(0xFF065F46)
                      : const Color(0xFF3730A3),
                ),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            msg,
            style: const TextStyle(
              fontSize: 12,
              height: 1.7,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!enabled)
                FilledButton.icon(
                  onPressed: (_busyPush || needsHomeScreen)
                      ? null
                      : () => _togglePush(true),
                  icon: const Icon(Icons.notifications_active_rounded, size: 18),
                  label: const Text('فعال‌سازی اعلان این دستگاه'),
                ),
              if (enabled) ...[
                FilledButton.tonalIcon(
                  onPressed: _busyPush ? null : _sendTestPush,
                  icon: const Icon(Icons.send_to_mobile_rounded, size: 18),
                  label: const Text('ارسال اعلان آزمایشی'),
                ),
                OutlinedButton.icon(
                  onPressed: _busyPush ? null : () => _togglePush(false),
                  icon: const Icon(Icons.notifications_off_outlined, size: 18),
                  label: const Text('غیرفعال‌سازی'),
                ),
              ],
              IconButton(
                onPressed: _busyPush ? null : _refreshPushState,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'بررسی دوبارهٔ وضعیت',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineUpdateSection() {
    return _sectionCard(
      icon: Icons.system_update_alt_rounded,
      iconColor: const Color(0xFF0284C7),
      title: 'حافظهٔ آفلاین و به‌روزرسانی خودکار',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'فایل‌های هستهٔ برنامه، فونت فارسی وزیرمتن و موتور گرافیکی به‌طور کامل روی آیفون کش می‌شوند تا بدون وابستگی به اینترنت خارجی با سرعت بالا باز شوند.',
            style: TextStyle(
              fontSize: 12,
              height: 1.7,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: _busyUpdate ? null : _checkUpdate,
              icon: _busyUpdate
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded, size: 18),
              label: const Text('بررسی و دریافت نسخهٔ جدید وب‌اپ'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
