// ============================================================
//  داشبورد سخت‌افزار (بلادرنگ) — فاز ۹-الف
//  آینهٔ `Pages/DashboardHardware.razor` (مسیر وب: /dashboard-hardware)
//
//  ترتیب بخش‌ها عیناً مثل وب:
//    ۱) بلوک «درخواست‌های خدمت IT — واحد» با نمودار میله‌ای + «مجموع: N درخواست»
//    ۲) هدر: «داشبورد سخت‌افزار» + نشان اتصال (🟢 برخط (SignalR) / ⚪ در حال اتصال…)
//       + دکمهٔ «بررسی فوری» (در حال اجرا: «در حال پینگ…»)
//    ۳) KPI سیستم‌ها: کل سیستم‌ها / روشن-آنلاین / خاموش-آفلاین / در انتظار تایید
//    ۴) حلقهٔ «وضعیت روشن/خاموش سیستم‌ها» + «میانگین سلامت ناوگان» + لیست سیستم‌ها
//    ۵) KPI دوربین‌ها: کل / آنلاین (پینگ فعال) / آفلاین / غیرفعال (ثبت)
//    ۶) حلقهٔ دوربین‌ها + نوارهای فعال/غیرفعال + لیست دوربین‌ها
//    ۷) KPI NVRها: کل / آنلاین (پینگ فعال) / آفلاین / بدون IP ثبت‌شده
//    ۸) حلقهٔ NVRها + لیست دستگاه‌ها
//    ۹) پانویس: «آخرین پویش: … — پویش خودکار هر ۳۰ ثانیه + پخش بلادرنگ»
//
//  گیت: `Dashboards.Hardware` — پیام وب:
//    «شما به «داشبورد سخت‌افزار» دسترسی ندارید. برای دریافت دسترسی با
//     مدیر سیستم تماس بگیرید.»
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/hardware_hub.dart';
import '../data/it_perms.dart';
import '../data/it_repository.dart';
import '../models/hardware_models.dart';

class HardwareDashboardPage extends StatefulWidget {
  const HardwareDashboardPage({super.key});

  @override
  State<HardwareDashboardPage> createState() => _HardwareDashboardPageState();
}

class _HardwareDashboardPageState extends State<HardwareDashboardPage> {
  late final ItRepository _repo;
  late final ItPerms _perms;
  late final ApiClient _api;
  HardwareHub? _hub;
  StreamSubscription<Map<String, dynamic>>? _hubSub;
  StreamSubscription<bool>? _connSub;

  HardwareStats? _stats;
  ItStats? _itStats;
  bool _connected = false;
  bool _loading = true;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _repo = ItRepository(_api);
    _perms = ItPerms(context.read<AuthController>().session);
    if (_perms.canSeeHardwareDashboard) {
      _load();
      _connectHub();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _hubSub?.cancel();
    _connSub?.cancel();
    _hub?.dispose();
    super.dispose();
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // آمار IT مستقل است؛ خطای آن نباید داشبورد را از کار بیندازد (مثل وب)
    try {
      final it = await _repo.itStats();
      if (mounted) setState(() => _itStats = it);
    } catch (_) {}
    try {
      final s = await _repo.hardwareStats();
      if (!mounted) return;
      setState(() {
        _stats = s;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _clean(e);
        _loading = false;
      });
    }
  }

  Future<void> _connectHub() async {
    final token = context.read<AuthController>().session?.token ?? '';
    final hub = HardwareHub(_api.dio, _api.dio.options.baseUrl);
    _hub = hub;
    _connSub = hub.connection.listen((v) {
      if (mounted) setState(() => _connected = v);
    });
    _hubSub = hub.events.listen((e) {
      final target = e['target'];
      if (target != 'ReceiveHardwareStats') return;
      final args = e['args'];
      if (args is! List || args.isEmpty) return;
      final raw = args.first;
      if (raw is! Map) return;
      final parsed = HardwareStats.fromJson(Map<String, dynamic>.from(raw));
      if (!mounted) return;
      setState(() {
        _stats = parsed;
        _loading = false;
        if (!parsed.sweeping) _checking = false;
      });
    });
    await hub.connectWithToken(_api.dio.options.baseUrl, token);
  }

  Future<void> _checkNow() async {
    setState(() => _checking = true);
    // مثل وب: هم متد هاب و هم اندپوینت REST (هر کدام در دسترس بود)
    _hub?.requestHardwareCheck();
    try {
      await _repo.requestHardwareCheck();
    } catch (e) {
      if (!mounted) return;
      setState(() => _checking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('بررسی شروع نشد: ${_clean(e)}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_perms.canSeeHardwareDashboard) {
      return Scaffold(
        backgroundColor: ShopColors.bg,
        appBar: AppBar(
          backgroundColor: ShopColors.surface,
          foregroundColor: ShopColors.ink,
          elevation: 0.5,
          title: const Text(
            'داشبورد سخت‌افزار',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
        ),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: ShopEmpty(
            title: 'دسترسی لازم را ندارید',
            subtitle:
                'شما به «داشبورد سخت‌افزار» دسترسی ندارید. برای دریافت دسترسی با مدیر سیستم تماس بگیرید.',
            icon: Icons.shield_outlined,
          ),
        ),
      );
    }

    final stats = _stats;
    final busy = _checking || (stats?.sweeping ?? false);

    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: const Row(
          children: [
            Icon(Icons.memory_rounded, size: 18),
            SizedBox(width: 6),
            Text(
              'داشبورد سخت‌افزار',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 6, right: 6),
            child: Center(
              child: ShopTag(
                text: _connected ? '🟢 برخط (SignalR)' : '⚪ در حال اتصال…',
                color: _connected ? ShopColors.ok : ShopColors.inkFaint,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
          children: [
            // ---------- ۱) درخواست‌های خدمت IT ----------
            if (_itStats != null) _itBlock(_itStats!),
            // ---------- ۲) دکمهٔ بررسی فوری ----------
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : _checkNow,
                    style: FilledButton.styleFrom(
                      backgroundColor: ShopColors.warn,
                      minimumSize: const Size(0, 42),
                    ),
                    icon: busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.wifi_tethering_rounded, size: 16),
                    label: Text(
                      busy ? 'در حال پینگ…' : 'بررسی فوری',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              ShopEmpty(
                title: 'وضعیت سخت‌افزار دریافت نشد',
                subtitle: _error,
                icon: Icons.error_outline_rounded,
              )
            else if (stats == null)
              const ShopEmpty(
                title: 'داده‌ای نیست',
                subtitle: 'در حال دریافت وضعیت سخت‌افزار…',
                icon: Icons.devices_other_rounded,
              )
            else
              ..._body(stats),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------ بلوک آمار IT
  Widget _itBlock(ItStats s) {
    final bars = ItBar.from(s);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.headset_mic_rounded,
                size: 15,
                color: ShopColors.seed,
              ),
              const SizedBox(width: 5),
              const Expanded(
                child: Text(
                  'درخواست‌های خدمت IT — واحد',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ShopTag(
                text: 'مجموع: ${Fa.number(s.total)} درخواست',
                color: ShopColors.inkFaint,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 132,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final b in bars)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            Fa.number(b.value),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: Color(b.color),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: (b.percent / 100).clamp(0.03, 1),
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Color(b.color),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            b.label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: const TextStyle(
                              fontSize: 8.5,
                              height: 1.4,
                              color: ShopColors.inkSoft,
                            ),
                          ),
                          if (b.sub != null)
                            Text(
                              Fa.digits(b.sub!),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 7.5,
                                color: ShopColors.inkFaint,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------ بدنهٔ اصلی
  List<Widget> _body(HardwareStats s) {
    final sys = HardwareGroupStats.of(s.systems);
    final cam = HardwareGroupStats.of(s.cameras);
    final nvr = HardwareGroupStats.of(s.nvrs);

    return [
      // ---------- ۳) KPI سیستم‌ها ----------
      Row(
        children: [
          Expanded(
            child: ShopKpi(
              title: 'کل سیستم‌ها',
              value: Fa.number(sys.total),
              icon: Icons.desktop_windows_rounded,
              color: ShopColors.seed,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ShopKpi(
              title: 'روشن / آنلاین',
              value: Fa.number(sys.online),
              icon: Icons.wifi_rounded,
              color: ShopColors.ok,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: ShopKpi(
              title: 'خاموش / آفلاین',
              value: Fa.number(sys.offline),
              icon: Icons.power_settings_new_rounded,
              color: ShopColors.danger,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ShopKpi(
              title: 'در انتظار تایید',
              value: Fa.number(s.systemsPending),
              icon: Icons.hourglass_top_rounded,
              color: ShopColors.warn,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      // ---------- ۴) حلقهٔ سیستم‌ها + میانگین سلامت + لیست ----------
      _donutCard(
        title: 'وضعیت روشن/خاموش سیستم‌ها',
        icon: Icons.desktop_windows_rounded,
        group: sys,
        middleLabel: 'آنلاین',
        extra: s.systemsAvgHealth == null
            ? null
            : Row(
                children: [
                  _gauge(s.systemsAvgHealth!, 46),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.favorite_rounded,
                              size: 12,
                              color: Color(0xffe0245e),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'میانگین سلامت ناوگان',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${Fa.number(s.systemsAvgHealth!)} — از ۱۰۰',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: _healthColor(s.systemsAvgHealth!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        listTitle: 'سیستم‌ها (${Fa.number(sys.total)})',
        emptyText: 'سیستمی ثبت نشده',
        showHealth: true,
      ),
      const SizedBox(height: 10),
      // ---------- ۵) KPI دوربین‌ها ----------
      Row(
        children: [
          Expanded(
            child: ShopKpi(
              title: 'کل دوربین‌ها',
              value: Fa.number(cam.total),
              icon: Icons.videocam_rounded,
              color: ShopColors.indigo,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ShopKpi(
              title: 'آنلاین (پینگ فعال)',
              value: Fa.number(cam.online),
              icon: Icons.wifi_rounded,
              color: ShopColors.ok,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: ShopKpi(
              title: 'آفلاین',
              value: Fa.number(cam.offline),
              icon: Icons.videocam_off_rounded,
              color: ShopColors.danger,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ShopKpi(
              title: 'غیرفعال (ثبت)',
              value: Fa.number(s.camerasInactive),
              icon: Icons.remove_circle_outline_rounded,
              color: ShopColors.teal,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      // ---------- ۶) حلقهٔ دوربین‌ها ----------
      _donutCard(
        title: 'آنلاین/آفلاین دوربین‌ها',
        icon: Icons.videocam_rounded,
        group: cam,
        middleLabel: 'آنلاین',
        extra: Column(
          children: [
            _bar('فعال (ثبت‌شده)', s.camerasActiveFlag, s.camerasTotal,
                ShopColors.seed),
            _bar(
              'غیرفعال (ثبت‌شده)',
              s.camerasInactive,
              s.camerasTotal,
              ShopColors.indigo,
            ),
          ],
        ),
        listTitle: 'دوربین‌ها (${Fa.number(cam.total)})',
        emptyText: 'دوربینی ثبت نشده',
      ),
      const SizedBox(height: 10),
      // ---------- ۷) KPI NVRها ----------
      Row(
        children: [
          Expanded(
            child: ShopKpi(
              title: 'کل NVRها',
              value: Fa.number(nvr.total),
              icon: Icons.dns_rounded,
              color: ShopColors.teal,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ShopKpi(
              title: 'آنلاین (پینگ فعال)',
              value: Fa.number(nvr.online),
              icon: Icons.wifi_rounded,
              color: ShopColors.ok,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: ShopKpi(
              title: 'آفلاین',
              value: Fa.number(nvr.offline),
              icon: Icons.power_settings_new_rounded,
              color: ShopColors.danger,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ShopKpi(
              title: 'بدون IP ثبت‌شده',
              value: Fa.number(nvr.noIp),
              icon: Icons.help_outline_rounded,
              color: ShopColors.warn,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      // ---------- ۸) حلقهٔ NVRها ----------
      _donutCard(
        title: 'آنلاین/آفلاین NVRها',
        icon: Icons.dns_rounded,
        group: nvr,
        middleLabel: 'آنلاین',
        listTitle: 'دستگاه‌های NVR (${Fa.number(nvr.total)})',
        emptyText: 'دستگاهی ثبت نشده',
      ),
      const SizedBox(height: 10),
      // ---------- ۹) پانویس ----------
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ShopColors.line),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 13,
              color: ShopColors.inkFaint,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'آخرین پویش: ${_lastSweep(s.lastSweepAt)} — پویش خودکار هر ۳۰ ثانیه + پخش بلادرنگ',
                style: const TextStyle(
                  fontSize: 9.5,
                  height: 1.6,
                  color: ShopColors.inkFaint,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  static String _lastSweep(DateTime? d) {
    if (d == null || d.year <= 2000) return '—';
    String two(int v) => v.toString().padLeft(2, '0');
    return Fa.digits(
      '${d.year}/${two(d.month)}/${two(d.day)} '
      '${two(d.hour)}:${two(d.minute)}:${two(d.second)}',
    );
  }

  static Color _healthColor(int score) {
    if (score >= 80) return ShopColors.ok;
    if (score >= 50) return ShopColors.warn;
    return ShopColors.danger;
  }

  // ------------------------------------------------ کارت حلقه‌ای + لیست
  Widget _donutCard({
    required String title,
    required IconData icon,
    required HardwareGroupStats group,
    required String middleLabel,
    required String listTitle,
    required String emptyText,
    Widget? extra,
    bool showHealth = false,
  }) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: ShopColors.inkSoft),
            const SizedBox(width: 5),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _donut(group, middleLabel),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      ShopTag(
                        text: 'آنلاین: ${Fa.number(group.online)}',
                        color: ShopColors.ok,
                      ),
                      ShopTag(
                        text: 'آفلاین: ${Fa.number(group.offline)}',
                        color: ShopColors.danger,
                      ),
                      ShopTag(
                        text: 'بدون IP: ${Fa.number(group.noIp)}',
                        color: ShopColors.inkFaint,
                      ),
                    ],
                  ),
                  if (extra != null) ...[const SizedBox(height: 8), extra],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          listTitle,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            color: ShopColors.inkSoft,
          ),
        ),
        const SizedBox(height: 4),
        if (group.items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                emptyText,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: ShopColors.inkFaint,
                ),
              ),
            ),
          )
        else
          ...group.items.map(
            (d) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _dot(d.online),
                  const SizedBox(width: 6),
                  if (showHealth && d.health != null) ...[
                    _gauge(d.health!, 22),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      d.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    d.ipText,
                    style: const TextStyle(
                      fontSize: 9,
                      color: ShopColors.inkFaint,
                    ),
                  ),
                  if (d.extra.trim().isNotEmpty) ...[
                    const SizedBox(width: 6),
                    ShopTag(text: d.extra, color: ShopColors.inkFaint),
                  ],
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _dot(bool? online) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: online == null
          ? ShopColors.inkFaint
          : (online ? ShopColors.ok : ShopColors.danger),
    ),
  );

  /// حلقهٔ درصد آنلاین — معادل `Donut` وب
  Widget _donut(HardwareGroupStats g, String label) {
    final pct = g.onlinePercent;
    return SizedBox(
      width: 82,
      height: 82,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 82,
            height: 82,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 9,
              valueColor: AlwaysStoppedAnimation(
                ShopColors.line.withValues(alpha: 0.8),
              ),
            ),
          ),
          SizedBox(
            width: 82,
            height: 82,
            child: CircularProgressIndicator(
              value: pct / 100,
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation(
                pct >= 80
                    ? ShopColors.ok
                    : pct >= 50
                    ? ShopColors.warn
                    : ShopColors.danger,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${Fa.number(pct)}٪',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 8,
                  color: ShopColors.inkFaint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// نشانگر کوچک امتیاز سلامت — معادل `HealthGauge` وب
  Widget _gauge(int score, double size) {
    final color = _healthColor(score);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: size > 30 ? 6 : 3.5,
              valueColor: AlwaysStoppedAnimation(
                ShopColors.line.withValues(alpha: 0.8),
              ),
            ),
          ),
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: (score.clamp(0, 100)) / 100,
              strokeWidth: size > 30 ? 6 : 3.5,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(
            Fa.number(score),
            style: TextStyle(
              fontSize: size > 30 ? 11 : 7.5,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(String label, int value, int total, Color color) {
    final pct = total <= 0 ? 0.0 : (value * 100 / total);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: ShopColors.inkSoft,
            ),
          ),
          const SizedBox(height: 2),
          Stack(
            children: [
              Container(
                height: 13,
                decoration: BoxDecoration(
                  color: ShopColors.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (pct / 100).clamp(0.0, 1.0),
                child: Container(
                  height: 13,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    Fa.number(value),
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
