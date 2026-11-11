// ============================================================
//  «سیستم‌های ثبت‌شده» — فاز ۹-ج
//  آینهٔ `Pages/ItAssets/SystemInfoList.razor` (مسیر وب: /system-info)
//
//  • سرصفحه: «شناسنامه سیستم‌ها» / «فهرست تجهیزات رایانه‌ای، وضعیت ایجنت و
//    تغییرات سخت‌افزاری»
//  • بنر آلارم: «آلارم: N سیستم تغییرات سخت‌افزاری گزارش داده — ایجنت با بانک
//    اطلاعاتی اختلاف دارد و منتظر تایید شماست» + دکمهٔ «بررسی و مقایسه»
//  • سه کارت تحلیل: نمودار دایره‌ای سیستم‌عامل، میانگین رم دپارتمان‌ها،
//    ۱۰ سیستم ضعیف‌تر برای ارتقا
//  • جدول «لیست سیستم‌ها به تفکیک شرکت» + دکمهٔ «ثبت دستی سیستم»
//  • ستون‌ها: # | ایجنت | CPU | RAM | مادربرد | IP | سلامت | زمان | واحد |
//    کاربر | وضعیت | عملیات (تأیید / جزئیات / تاریخچه / حذف)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/system_repository.dart';
import '../models/system_models.dart';
import 'system_detail_page.dart';
import 'system_manual_page.dart';
import 'system_style.dart';

class SystemInfoListPage extends StatefulWidget {
  const SystemInfoListPage({super.key});

  @override
  State<SystemInfoListPage> createState() => _SystemInfoListPageState();
}

class _SystemInfoListPageState extends State<SystemInfoListPage> {
  late final SystemRepository _repo;

  List<SystemInfoItem> _items = const [];
  List<SystemUserRow> _users = const [];
  List<SystemCompanyRow> _companies = const [];
  List<SystemDepartmentRow> _departments = const [];
  final Map<int, String> _weakTips = {};

  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _repo = SystemRepository(context.read<ApiClient>());
    _load();
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '')
      .trim();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.systems();
      final results = await Future.wait<dynamic>([
        _repo.users(),
        _repo.companies(),
        _repo.departments(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = items;
        _users = results[0] as List<SystemUserRow>;
        _companies = results[1] as List<SystemCompanyRow>;
        _departments = results[2] as List<SystemDepartmentRow>;
        _loading = false;
      });
      _loadWeakTips();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _clean(e);
      });
    }
  }

  /// راهنمای ارتقای ۱۰ سیستم ضعیف — همان `LoadWeakestTips()` وب
  Future<void> _loadWeakTips() async {
    final targets = weakest10(_items);
    if (targets.isEmpty) return;
    final result = <int, String>{};
    await Future.wait(
      targets.map((it) async {
        final h = await _repo.health(it.id);
        final tip = h?.worstTip;
        if (tip != null) result[it.id] = tip;
      }),
    );
    if (!mounted) return;
    setState(() => _weakTips.addAll(result));
  }

  // ---------------- کمکی‌های نمایش (عیناً وب) ----------------

  int get _pendingCount => _items.where((i) => i.hasPending).length;

  int? get _firstPendingId {
    for (final i in _items) {
      if (i.hasPending) return i.id;
    }
    return null;
  }

  String _userName(int? userId) {
    if (userId == null) return '—';
    for (final u in _users) {
      if (u.id == userId) return u.fullName;
    }
    return '#$userId';
  }

  SystemUserRow? _user(int? userId) {
    if (userId == null) return null;
    for (final u in _users) {
      if (u.id == userId) return u;
    }
    return null;
  }

  String _deptName(int? id) {
    if (id == null) return '—';
    for (final d in _departments) {
      if (d.id == id) return d.name;
    }
    return 'واحد #$id';
  }

  String _ipCell(SystemInfoItem it) =>
      it.ip.trim().isEmpty ? '—' : it.ip.trim();

  // ---------------- عملیات ----------------

  Future<void> _approve(SystemInfoItem it) async {
    setState(() => _busy = true);
    try {
      await _repo.approve(it.id);
      await _load();
    } catch (e) {
      _toast('تأیید ناموفق بود — ${_clean(e)}', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(SystemInfoItem it) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'حذف رکورد سیستم',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'رکورد «${it.agentId}» حذف شود؟ این عمل قابل بازگشت نیست.',
          style: const TextStyle(fontSize: 12, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ShopColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _repo.delete(it.id);
      await _load();
    } catch (e) {
      _toast('حذف ناموفق بود — ${_clean(e)}', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDetail(SystemInfoItem it) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SystemDetailPage(systemId: it.id),
      ),
    );
    if (mounted) await _load();
  }

  /// مودال «تایم‌لاین تغییرات — سیستم #id»
  Future<void> _openHistory(SystemInfoItem it) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HistorySheet(repo: _repo, system: it),
    );
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 11.5)),
        backgroundColor: error ? ShopColors.danger : ShopColors.ok,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: const Text(
          'سیستم‌های ثبت‌شده',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'بارگذاری مجدد',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
          children: [
            const ShopHeader(
              title: 'شناسنامه سیستم‌ها',
              subtitle:
                  'فهرست تجهیزات رایانه‌ای، وضعیت ایجنت و تغییرات سخت‌افزاری',
              icon: Icons.devices_other_rounded,
              badge: 'IT',
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SystemNote(
                text: 'بارگذاری فهرست ناموفق بود — $_error',
                color: ShopColors.danger,
                icon: Icons.cloud_off_rounded,
              )
            else ...[
              if (_pendingCount > 0) _alarmBanner(),
              if (_items.isNotEmpty) _analytics(),
              _tableCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _alarmBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xfffff4e5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xfff6c47b)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.notifications_active_rounded,
                size: 17,
                color: Color(0xffb45309),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 10.8,
                      height: 1.8,
                      color: Color(0xff7c4a03),
                      fontWeight: FontWeight.w700,
                    ),
                    children: [
                      const TextSpan(text: 'آلارم: '),
                      TextSpan(
                        text: Fa.digits(_pendingCount),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const TextSpan(
                        text:
                            ' سیستم تغییرات سخت‌افزاری گزارش داده — ایجنت با بانک اطلاعاتی اختلاف دارد و منتظر تایید شماست',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xffb45309),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(0, 34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () async {
                final id = _firstPendingId;
                if (id == null) return;
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SystemDetailPage(systemId: id),
                  ),
                );
                if (mounted) await _load();
              },
              icon: const Icon(Icons.compare_arrows_rounded, size: 15),
              label: const Text(
                'بررسی و مقایسه',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _analytics() {
    final segs = osSegments(_items);
    final deptNames = {
      for (final d in _departments)
        if (d.id > 0) d.id: d.name,
    };
    final deptRam = ramByDept(_items, deptNames);
    final maxRam = maxDeptRam(deptRam);
    final weak = weakest10(_items);

    return Column(
      children: [
        // ---------- نمودار دایره‌ای: سیستم‌عامل ----------
        SystemCard(
          title: 'سیستم‌عامل (نمودار دایره‌ای)',
          icon: Icons.window_rounded,
          child: Row(
            children: [
              OsDonut(segments: segs, total: _items.length),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in segs)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: hexColor(s.color),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                s.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: ShopColors.inkSoft,
                                ),
                              ),
                            ),
                            Text(
                              Fa.digits(s.count),
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: ShopColors.ink,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${Fa.digits(s.pct)}٪',
                              style: const TextStyle(
                                fontSize: 10,
                                color: ShopColors.inkFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ---------- میانگین رم به تفکیک دپارتمان ----------
        SystemCard(
          title: 'میانگین رم به تفکیک دپارتمان (GB)',
          icon: Icons.bar_chart_rounded,
          child: deptRam.isEmpty
              ? const Text(
                  'داده‌ای برای نمایش نیست.',
                  style: TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
                )
              : Column(
                  children: [
                    for (final dr in deptRam)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 88,
                              child: Text(
                                '${dr.name} (${Fa.digits(dr.count)})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: ShopColors.inkSoft,
                                ),
                              ),
                            ),
                            Expanded(
                              child: MiniBar(
                                pct: dr.avg > 0
                                    ? ((dr.avg * 100) / maxRam).round()
                                    : 0,
                                color: ShopColors.ok,
                              ),
                            ),
                            const SizedBox(width: 7),
                            SizedBox(
                              width: 52,
                              child: Text(
                                Fa.digits(dr.avgLabel),
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: ShopColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),

        // ---------- ۱۰ سیستم ضعیف‌تر برای ارتقا ----------
        SystemCard(
          title: '۱۰ سیستم ضعیف‌تر برای ارتقا',
          icon: Icons.swap_vert_rounded,
          child: weak.isEmpty
              ? const Text(
                  'هنوز امتیاز سلامت محاسبه نشده است.',
                  style: TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
                )
              : Column(
                  children: [
                    for (var i = 0; i < weak.length; i++)
                      InkWell(
                        onTap: () => _openDetail(weak[i]),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                child: Text(
                                  Fa.digits(i + 1),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: ShopColors.inkFaint,
                                  ),
                                ),
                              ),
                              HealthGauge(score: weak[i].health, size: 34),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      weak[i].cpu.trim().isEmpty
                                          ? weak[i].agentId
                                          : weak[i].cpu,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: ShopColors.ink,
                                      ),
                                    ),
                                    Text(
                                      '${weak[i].agentId}'
                                      '${weak[i].totalRamGb > 0 ? ' — ${Fa.digits(weak[i].totalRamGb)} GB رم' : ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: ShopColors.inkFaint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_weakTips[weak[i].id] != null)
                                Flexible(
                                  child: ShopTag(
                                    text: _weakTips[weak[i].id]!,
                                    color: ShopColors.warn,
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
    );
  }

  Widget _tableCard() {
    final groups = companyGroups(_items, _companies);
    return Container(
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff4f8cff), Color(0xff8e5cff)],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.apartment_rounded,
                  size: 15,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'لیست سیستم‌ها به تفکیک شرکت',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xff4f5b8a),
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SystemManualPage(),
                      ),
                    );
                    if (mounted) await _load();
                  },
                  icon: const Icon(Icons.add_rounded, size: 14),
                  label: const Text(
                    'ثبت دستی سیستم',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SystemNote(text: 'هنوز داده‌ای ثبت نشده است.'),
            )
          else ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: ShopColors.inkFaint,
                  ),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'هر بخش زیر، سیستم‌های یک شرکت را جداگانه نمایش می‌دهد.',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final g in groups) _companyGroupTable(g),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _companyGroupTable(CompanySystemGroup group) {
    final unassigned = group.companyId == null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: unassigned
                  ? const Color(0xfffff7e6)
                  : const Color(0xffeef4ff),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: unassigned
                    ? const Color(0xfff3c96b)
                    : const Color(0xffc7d9f7),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  unassigned
                      ? Icons.help_outline_rounded
                      : Icons.business_rounded,
                  size: 14,
                  color: unassigned
                      ? const Color(0xffb45309)
                      : const Color(0xff1d4ed8),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: unassigned
                          ? const Color(0xff7c4a03)
                          : const Color(0xff1e3a8a),
                    ),
                  ),
                ),
                if ((group.code ?? '').isNotEmpty) ...[
                  const SizedBox(width: 5),
                  ShopTag(text: group.code!, color: ShopColors.inkFaint),
                ],
                const Spacer(),
                Text(
                  '${Fa.digits(group.items.length)} سیستم',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: ShopColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 34,
              dataRowMinHeight: 42,
              dataRowMaxHeight: 64,
              horizontalMargin: 10,
              columnSpacing: 16,
              headingRowColor: WidgetStateProperty.all(const Color(0xfff4f7fb)),
              columns: const [
                DataColumn(label: _Th('#')),
                DataColumn(label: _Th('ایجنت')),
                DataColumn(label: _Th('CPU')),
                DataColumn(label: _Th('RAM')),
                DataColumn(label: _Th('مادربرد')),
                DataColumn(label: _Th('IP')),
                DataColumn(label: _Th('سلامت')),
                DataColumn(label: _Th('زمان')),
                DataColumn(label: _Th('واحد')),
                DataColumn(label: _Th('کاربر')),
                DataColumn(label: _Th('وضعیت')),
                DataColumn(label: _Th('عملیات')),
              ],
              rows: [
                for (final item in group.items) _dataRow(item),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DataRow _dataRow(SystemInfoItem item) {
    final pendingCpu = item.pendingCpu;
    final cpuChanged =
        pendingCpu != null && pendingCpu.isNotEmpty && pendingCpu != item.cpu;
    final user = _user(item.userId);

    return DataRow(
      color: WidgetStateProperty.all(
        item.isApproved
            ? const Color(0xfff1fbf3)
            : ShopColors.surface,
      ),
      cells: [
        DataCell(_Td(Fa.digits(item.id), color: ShopColors.inkSoft)),
        DataCell(
          ShopTag(
            text: item.agentId.isEmpty ? '—' : item.agentId,
            color: ShopColors.ink,
          ),
        ),
        DataCell(
          cpuChanged
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.cpuCell,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: ShopColors.inkFaint,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    Text(
                      '⚠️ $pendingCpu',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: ShopColors.ok,
                      ),
                    ),
                  ],
                )
              : _Td(item.cpuCell),
        ),
        DataCell(_Td(item.ramCell)),
        DataCell(_Td(item.motherboardCell)),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xff1e293b),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _ipCell(item),
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        DataCell(
          item.health != null
              ? HealthGauge(score: item.health, size: 34)
              : const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '—',
                    style: TextStyle(fontSize: 10, color: ShopColors.inkFaint),
                  ),
                ),
        ),
        DataCell(
          _Td(
            Fa.date(item.receivedAt?.toUtc().toIso8601String()),
            color: ShopColors.inkSoft,
          ),
        ),
        DataCell(_Td(_deptName(item.departmentId))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (user != null) ...[
                CircleAvatar(
                  radius: 11,
                  backgroundColor: const Color(0xffe0e9ff),
                  child: Text(
                    Fa.digits(
                      user.fullName.isEmpty ? '؟' : user.fullName.characters.first,
                    ),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Color(0xff1d4ed8),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
              ],
              _Td(_userName(item.userId)),
            ],
          ),
        ),
        DataCell(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShopTag(
                text: item.isApproved ? 'تأیید شده' : 'در انتظار',
                color: item.isApproved ? ShopColors.ok : ShopColors.warn,
              ),
              if (item.hasPending)
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: ShopTag(
                    text: '🔄 تغییر در انتظار تایید',
                    color: ShopColors.danger,
                  ),
                ),
            ],
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!item.isApproved)
                RowAction(
                  icon: Icons.check_circle_rounded,
                  color: ShopColors.ok,
                  tooltip: 'تأیید',
                  onTap: _busy ? null : () => _approve(item),
                ),
              const SizedBox(width: 4),
              RowAction(
                icon: Icons.visibility_rounded,
                color: const Color(0xff0891b2),
                tooltip: 'جزئیات',
                onTap: () => _openDetail(item),
              ),
              const SizedBox(width: 4),
              RowAction(
                icon: Icons.history_rounded,
                color: ShopColors.inkSoft,
                tooltip: 'تاریخچه تغییرات',
                onTap: () => _openHistory(item),
              ),
              const SizedBox(width: 4),
              RowAction(
                icon: Icons.delete_rounded,
                color: ShopColors.danger,
                tooltip: 'حذف رکورد',
                onTap: _busy ? null : () => _delete(item),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Th extends StatelessWidget {
  const _Th(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w900,
      color: ShopColors.inkSoft,
    ),
  );
}

class _Td extends StatelessWidget {
  const _Td(this.text, {this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: 10.5,
      height: 1.5,
      fontWeight: FontWeight.w600,
      color: color ?? ShopColors.ink,
    ),
  );
}

/// مودال «تایم‌لاین تغییرات — سیستم #id»
class _HistorySheet extends StatefulWidget {
  const _HistorySheet({required this.repo, required this.system});

  final SystemRepository repo;
  final SystemInfoItem system;

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  List<SystemHistoryEntry> _rows = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await widget.repo.history(widget.system.id);
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      maxChildSize: 0.94,
      minChildSize: 0.4,
      expand: false,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: ShopColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 6),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: ShopColors.line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 17,
                    color: ShopColors.inkSoft,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'تایم‌لاین تغییرات — سیستم #${Fa.digits(widget.system.id)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: ShopColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: ShopEmpty(
                        title: 'تاریخچه‌ای ثبت نشده است',
                        subtitle:
                            'با هر بار گزارش تغییر توسط ایجنت و تایید آن، یک رکورد اینجا ثبت می‌شود.',
                        icon: Icons.history_toggle_off_rounded,
                      ),
                    )
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: _rows.length,
                      itemBuilder: (_, i) =>
                          _timelineCard(_rows[i], i == 0),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timelineCard(SystemHistoryEntry e, bool first) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: first ? ShopColors.ok : ShopColors.inkFaint,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  Fa.date(e.changedAt?.toUtc().toIso8601String()),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: ShopColors.ink,
                  ),
                ),
              ),
              ShopTag(
                text: '${Fa.digits(e.changeCount)} تغییر',
                color: ShopColors.accent,
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final d in e.diffs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      '${d.changed ? '⚠️ ' : ''}${d.field}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: d.changed ? ShopColors.ink : ShopColors.inkFaint,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${d.oldValue ?? '—'}  ←  ${d.newValue ?? '—'}',
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.6,
                        color: d.changed ? ShopColors.ok : ShopColors.inkFaint,
                        fontWeight: d.changed
                            ? FontWeight.w800
                            : FontWeight.w500,
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
}
