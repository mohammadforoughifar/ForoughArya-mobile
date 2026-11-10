// ============================================================
//  پذیرش تعمیرات
//  آینهٔ صفحهٔ وب: /repairs → Pages/Repairs/Repairs.razor
//
//  • فهرست با جستجو/فیلتر وضعیت/تعمیرکار (+ مدیریت تعمیرکارها)
//  • فرم پذیرش: مشتری* (+ مشتری جدید) · تعمیرکار · تاریخ ورود · وضعیت
//    (در ویرایش) · یادداشت · کارت‌های «دستگاه» (نوع/مدل/سریال/لوازم/ایراد/
//    مبلغ برآوردی) · ردیف‌های «کار و قطعه» (شرح، قطعه از انبار، مقدار،
//    هزینه داخلی، قیمت فروش، سود ردیف) + جمع هزینه/دریافتی/سود
//  • جزئیات پذیرش (مشاهده) و «تبدیل به فروش و تحویل» با انبار برداشت،
//    روش تسویه نقد/نسیه، نوع دریافت، حساب خزانه و پیش‌دریافت
//  ⚠️ چاپ فیش تحویل/فاکتور (پنجرهٔ چاپ مرورگر) ساخته نشد.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/fa_num.dart';
import '../data/shop_repository.dart';
import '../models/ops_models.dart';
import '../models/order_models.dart';
import '../models/shop_models.dart';
import 'order_form_page.dart' show QuickBankSheet;
import 'party_form_page.dart';
import 'shop_style.dart';

class RepairsPage extends StatefulWidget {
  const RepairsPage({super.key});

  @override
  State<RepairsPage> createState() => _RepairsPageState();
}

class _RepairsPageState extends State<RepairsPage> {
  late final ShopRepository _repo;
  static const pageSize = 15;

  int _page = 1;
  int _total = 0;
  List<RepairOrder> _items = const [];
  List<Technician> _technicians = const [];
  final _search = TextEditingController();
  int? _status;
  int? _technicianId;

  bool _loading = true;
  String? _error;

  // گزارش (داشبورد عملیات)
  bool _showReport = false;
  bool _reportLoading = false;
  OpsDashboard? _report;
  DateTime? _reportFrom;
  DateTime? _reportTo;

  int get _pageCount => _total <= 0 ? 1 : ((_total + pageSize - 1) ~/ pageSize);

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _loadTechs();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadTechs() async {
    try {
      final list = await _repo.technicians();
      if (!mounted) return;
      setState(() => _technicians = list);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _repo.repairs(
        search: _search.text,
        status: _status,
        technicianId: _technicianId,
        page: _page,
        pageSize: pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _total = res.total ?? res.items.length;
        if (_page > _pageCount) _page = _pageCount;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _toast(String msg, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12.5)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? ShopColors.ok : ShopColors.danger,
      ),
    );
  }

  /// همان پیش‌تنظیم‌های بازهٔ گزارش وب
  void _preset(int days) {
    final now = DateTime.now();
    setState(() {
      if (days == 0) {
        _reportFrom = DateTime(now.year, now.month, 1);
      } else {
        _reportFrom = now.subtract(Duration(days: days));
      }
      _reportTo = now;
    });
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _reportLoading = true);
    try {
      final rep = await _repo.opsDashboard(
        from: _reportFrom,
        to: _reportTo,
      );
      if (!mounted) return;
      setState(() {
        _report = rep;
        _reportLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _reportLoading = false);
      _toast(e.toString());
    }
  }

  Future<void> _pickReportDate({required bool isFrom}) async {
    final picked = await showJalaliDatePicker(
      context,
      initial: isFrom ? _reportFrom : _reportTo,
      title: isFrom ? 'از تاریخ' : 'تا تاریخ',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _reportFrom = picked;
      } else {
        _reportTo = picked;
      }
    });
    _loadReport();
  }

  Future<void> _openForm({RepairOrder? source}) async {
    RepairOrder? full = source;
    if (source != null) {
      try {
        full = await _repo.repair(source.id) ?? source;
      } catch (_) {}
    }
    if (!mounted) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RepairFormPage(
          repo: _repo,
          technicians: _technicians,
          source: full,
          onTechsChanged: _loadTechs,
        ),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _openView(RepairOrder r) async {
    RepairOrder? full;
    try {
      full = await _repo.repair(r.id);
    } catch (_) {}
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RepairDetailsSheet(order: full ?? r),
    );
  }

  Future<void> _delete(RepairOrder r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(
          'آیا از حذف پذیرش «${r.number}» مطمئن هستید؟',
          style: const TextStyle(fontSize: 12.5, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ShopColors.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('تأیید'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteRepair(r.id);
      _toast('پذیرش حذف شد.', ok: true);
      _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  /// «تبدیل به فروش و تحویل»
  Future<void> _openInvoice(RepairOrder r) async {
    RepairOrder? full;
    try {
      full = await _repo.repair(r.id);
    } catch (_) {}
    if (!mounted) return;
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RepairInvoiceSheet(repo: _repo, order: full ?? r),
    );
    if (done == true) _load();
  }

  Future<void> _openTechs() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TechniciansSheet(repo: _repo, items: _technicians),
    );
    await _loadTechs();
    _load();
  }

  /// همان نگاشت رنگی وب
  static Color statusColor(int s) => switch (s) {
    RepairStatus.received => ShopColors.seed,
    RepairStatus.inProgress => ShopColors.warn,
    RepairStatus.ready => ShopColors.ok,
    RepairStatus.delivered => ShopColors.teal,
    _ => ShopColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShopColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ShopHeader(
                title: 'پذیرش تعمیرات',
                subtitle: 'ثبت دستگاه، تعمیرکار، کارها و قطعات مصرفی',
                icon: Icons.build_rounded,
                badge: '${Fa.number(_total)} پذیرش',
                actions: [
                  ShopHeaderButton(
                    label: 'گزارش و نمودارها',
                    icon: Icons.bar_chart_rounded,
                    onTap: () {
                      setState(() => _showReport = !_showReport);
                      if (_showReport && _report == null) _loadReport();
                    },
                  ),
                  ShopHeaderButton(
                    label: 'پذیرش جدید',
                    icon: Icons.add_rounded,
                    filled: true,
                    onTap: () => _openForm(),
                  ),
                ],
              ),
            ),
            if (_showReport)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                sliver: SliverToBoxAdapter(child: _reportCard()),
              ),
            // ---------- فیلترها ----------
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ShopColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ShopColors.line),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _search,
                        onSubmitted: (_) {
                          _page = 1;
                          _load();
                        },
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'شماره پذیرش، دستگاه، سریال، مشتری…',
                          hintStyle: TextStyle(
                            fontSize: 11.5,
                            color: ShopColors.inkFaint,
                          ),
                          prefixIcon: Icon(Icons.search_rounded, size: 18),
                        ),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              initialValue: _status,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                isDense: true,
                                labelText: 'وضعیت',
                                labelStyle: TextStyle(fontSize: 11),
                              ),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: ShopColors.ink,
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('همه وضعیت‌ها'),
                                ),
                                for (final s in const [
                                  RepairStatus.received,
                                  RepairStatus.inProgress,
                                  RepairStatus.ready,
                                  RepairStatus.delivered,
                                  RepairStatus.cancelled,
                                ])
                                  DropdownMenuItem<int?>(
                                    value: s,
                                    child: Text(RepairStatus.label(s)),
                                  ),
                              ],
                              onChanged: (v) {
                                _status = v;
                                _page = 1;
                                _load();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              initialValue: _technicianId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                isDense: true,
                                labelText: 'تعمیرکار',
                                labelStyle: TextStyle(fontSize: 11),
                              ),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: ShopColors.ink,
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('همه تعمیرکارها'),
                                ),
                                for (final t in _technicians)
                                  DropdownMenuItem<int?>(
                                    value: t.id,
                                    child: Text(t.name),
                                  ),
                              ],
                              onChanged: (v) {
                                _technicianId = v;
                                _page = 1;
                                _load();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openTechs,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 42),
                                foregroundColor: ShopColors.seed,
                                side: const BorderSide(color: ShopColors.line),
                              ),
                              icon: const Icon(
                                Icons.engineering_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                'تعمیرکارها',
                                style: TextStyle(fontSize: 11.5),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                _page = 1;
                                _load();
                              },
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 42),
                                backgroundColor: ShopColors.seed,
                              ),
                              icon: const Icon(
                                Icons.filter_alt_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                'اعمال فیلتر',
                                style: TextStyle(fontSize: 11.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ShopEmpty(
                  title: 'پذیرش‌ها دریافت نشد',
                  subtitle: _error,
                  icon: Icons.error_outline_rounded,
                ),
              )
            else if (_items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: ShopEmpty(
                  title: 'پذیرشی یافت نشد',
                  subtitle: 'با «پذیرش جدید» اولین دستگاه را ثبت کنید.',
                  icon: Icons.build_rounded,
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                sliver: SliverList.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _card(_items[i]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                sliver: SliverToBoxAdapter(child: _pager()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _reportCard() {
    final r = _report;
    return Container(
      padding: const EdgeInsets.all(12),
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
                Icons.insights_rounded,
                size: 16,
                color: ShopColors.seed,
              ),
              const SizedBox(width: 5),
              const Expanded(
                child: Text(
                  'گزارش تعمیرات',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _showReport = false),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _dateBox(
                  'از تاریخ',
                  _reportFrom,
                  () => _pickReportDate(isFrom: true),
                  () => setState(() => _reportFrom = null),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dateBox(
                  'تا تاریخ',
                  _reportTo,
                  () => _pickReportDate(isFrom: false),
                  () => setState(() => _reportTo = null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in const [
                MapEntry(7, '۷ روز'),
                MapEntry(30, '۳۰ روز'),
                MapEntry(90, '۹۰ روز'),
                MapEntry(0, 'ماه جاری'),
              ])
                GestureDetector(
                  onTap: () => _preset(p.key),
                  child: ShopTag(text: p.value, color: ShopColors.inkSoft),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_reportLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (r == null)
            const Text(
              'گزارشی برای این بازه دریافت نشد.',
              style: TextStyle(fontSize: 11.5, color: ShopColors.inkFaint),
            )
          else ...[
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [
                ShopKpi(
                  title: 'پذیرش در بازه',
                  value: Fa.number(r.repairCount),
                  unit: 'دستگاه',
                  icon: Icons.inbox_rounded,
                  color: ShopColors.seed,
                ),
                ShopKpi(
                  title: 'تحویل در بازه',
                  value: Fa.number(r.deliveredRepairCount),
                  unit: 'مورد',
                  icon: Icons.inventory_2_rounded,
                  color: ShopColors.ok,
                ),
                ShopKpi(
                  title: 'باز در حال حاضر',
                  value: Fa.number(r.openRepairCount),
                  unit: 'مورد',
                  icon: Icons.hourglass_bottom_rounded,
                  color: ShopColors.warn,
                ),
                ShopKpi(
                  title: 'انصراف در بازه',
                  value: Fa.number(r.cancelledRepairCount),
                  unit: 'مورد',
                  icon: Icons.block_rounded,
                  color: ShopColors.danger,
                ),
                ShopKpi(
                  title: 'میانگین زمان تحویل',
                  value: r.averageRepairTurnaroundDays == null
                      ? '—'
                      : Fa.number(
                          r.averageRepairTurnaroundDays!,
                          decimals: 1,
                        ),
                  unit: 'روز',
                  icon: Icons.timer_rounded,
                  color: ShopColors.teal,
                ),
                ShopKpi(
                  title: 'سود تعمیرات تحویل‌شده',
                  value: Fa.number(r.repairProfit),
                  unit: 'ریال',
                  icon: Icons.payments_rounded,
                  color: r.repairProfit >= 0
                      ? ShopColors.ok
                      : ShopColors.danger,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ShopColors.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _kv('درآمد', Fa.number(r.repairRevenue), ShopColors.seed),
                  _kv('قطعات', Fa.number(r.repairPartsCost), ShopColors.warn),
                  _kv('دستمزد', Fa.number(r.repairLaborCost), ShopColors.warn),
                  _kv('جمع هزینه', Fa.number(r.repairCost), ShopColors.danger),
                  _kv(
                    'سود',
                    Fa.number(r.repairProfit),
                    r.repairProfit >= 0 ? ShopColors.ok : ShopColors.danger,
                  ),
                  _kv(
                    'حاشیهٔ سود',
                    '${Fa.number(r.repairMargin, decimals: 1)}٪',
                    r.repairMargin >= 0 ? ShopColors.ok : ShopColors.danger,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'مبنا: فقط تعمیرات تحویل‌شده در بازه؛ هزینه بر اساس بهای ثبت‌شدهٔ اقلام هنگام پذیرش است.',
              style: TextStyle(
                fontSize: 9.5,
                color: ShopColors.inkFaint,
                height: 1.7,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String k, String v, Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            k,
            style: const TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
          ),
        ),
        Text(
          v,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: c,
          ),
        ),
      ],
    ),
  );

  Widget _card(RepairOrder r) {
    return Container(
      padding: const EdgeInsets.all(12),
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
              Text(
                r.number,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.seed,
                ),
              ),
              const SizedBox(width: 6),
              ShopTag(
                text: RepairStatus.label(r.status),
                color: statusColor(r.status),
              ),
              const Spacer(),
              Text(
                Fa.date(r.receivedAt?.toIso8601String(), time: false),
                style: const TextStyle(
                  fontSize: 10.5,
                  color: ShopColors.inkFaint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            r.deviceSummary,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
          Text(
            '${r.partyName ?? '—'}'
            '${r.partyTel.trim().isEmpty ? '' : ' — ${r.partyTel}'}',
            style: const TextStyle(fontSize: 10.5, color: ShopColors.inkSoft),
          ),
          Text(
            'تعمیرکار: ${r.technicianName ?? '—'}'
            ' · ورود: ${Fa.date(r.receivedAt?.toIso8601String(), time: false)}'
            ' · خروج: ${r.deliveredAt == null ? 'در مجموعه' : Fa.date(r.deliveredAt!.toIso8601String(), time: false)}',
            style: const TextStyle(fontSize: 10, color: ShopColors.inkFaint),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'دریافتی',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                    Text(
                      '${Fa.number(r.totalPrice)} ریال',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'سود',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                    Text(
                      '${Fa.number(r.profit)} ریال',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: r.profit >= 0
                            ? ShopColors.ok
                            : ShopColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
              if (r.hasInvoice)
                ShopTag(
                  text: r.invoiceNumber ?? 'فاکتور صادر شد',
                  color: ShopColors.ok,
                ),
            ],
          ),
          const Divider(height: 12, color: ShopColors.line),
          Wrap(
            spacing: 2,
            children: [
              TextButton.icon(
                onPressed: () => _openView(r),
                icon: const Icon(Icons.visibility_rounded, size: 15),
                label: const Text('جزئیات', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: ShopColors.inkSoft,
                ),
              ),
              if (!r.hasInvoice) ...[
                TextButton.icon(
                  onPressed: () => _openForm(source: r),
                  icon: const Icon(Icons.edit_rounded, size: 15),
                  label: const Text('ویرایش', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(foregroundColor: ShopColors.seed),
                ),
                TextButton.icon(
                  onPressed: () => _openInvoice(r),
                  icon: const Icon(Icons.receipt_long_rounded, size: 15),
                  label: const Text(
                    'تبدیل به فروش',
                    style: TextStyle(fontSize: 11),
                  ),
                  style: TextButton.styleFrom(foregroundColor: ShopColors.ok),
                ),
                TextButton.icon(
                  onPressed: () => _delete(r),
                  icon: const Icon(Icons.delete_outline_rounded, size: 15),
                  label: const Text('حذف', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: ShopColors.danger,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _pager() => Container(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _page > 1
              ? () {
                  _page--;
                  _load();
                }
              : null,
          icon: const Icon(Icons.chevron_right_rounded, size: 20),
        ),
        Text(
          'صفحه ${Fa.number(_page)} از ${Fa.number(_pageCount)}',
          style: const TextStyle(fontSize: 11),
        ),
        IconButton(
          onPressed: _page < _pageCount
              ? () {
                  _page++;
                  _load();
                }
              : null,
          icon: const Icon(Icons.chevron_left_rounded, size: 20),
        ),
      ],
    ),
  );

  Widget _dateBox(
    String label,
    DateTime? value,
    VoidCallback onTap,
    VoidCallback onClear,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ShopColors.line),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: 15,
              color: ShopColors.inkFaint,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                value == null ? label : jalaliShort(value),
                style: TextStyle(
                  fontSize: 11.5,
                  color: value == null ? ShopColors.inkFaint : ShopColors.ink,
                ),
              ),
            ),
            if (value != null)
              InkWell(
                onTap: onClear,
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: ShopColors.inkFaint,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  فرم پذیرش تعمیر
// ============================================================
class RepairFormPage extends StatefulWidget {
  const RepairFormPage({
    super.key,
    required this.repo,
    required this.technicians,
    required this.onTechsChanged,
    this.source,
  });

  final ShopRepository repo;
  final List<Technician> technicians;
  final Future<void> Function() onTechsChanged;
  final RepairOrder? source;

  @override
  State<RepairFormPage> createState() => _RepairFormPageState();
}

/// کارت دستگاه قابل ویرایش
class _DeviceVm {
  _DeviceVm()
      : type = '',
        model = '',
        serial = '',
        problem = '',
        accessories = '',
        quote = '';
  int id = 0;
  String type;
  String model;
  String serial;
  String problem;
  String accessories;
  String quote;
  double get quoteValue => parseNum(quote);
}

/// ردیف کار/قطعه قابل ویرایش
class _ItemVm {
  _ItemVm()
      : description = '',
        qty = '1',
        cost = '',
        price = '';
  int id = 0;
  int? productId;
  String description;
  String qty;
  String cost;
  String price;

  double get qtyValue => parseNum(qty);
  double get costValue => parseNum(cost);
  double get priceValue => parseNum(price);
  double get rowCost => costValue * qtyValue;
  double get rowPrice => priceValue * qtyValue;
  double get rowProfit => rowPrice - rowCost;
}

class _RepairFormPageState extends State<RepairFormPage> {
  late ShopRepository _repo;
  late List<Technician> _techs;

  bool get _isEdit => (widget.source?.id ?? 0) > 0;

  // اطلاعات مشترک
  int _partyId = 0;
  int? _techId;
  DateTime? _receivedAt;
  int _status = RepairStatus.received;
  final _note = TextEditingController();

  List<Party> _customers = const [];
  List<Product> _products = const [];

  final List<_DeviceVm> _devices = [];
  final List<_ItemVm> _items = [];

  bool _loading = true;
  bool _saving = false;

  static const _deviceTypes = [
    'لپ‌تاپ',
    'کامپیوتر',
    'مانیتور',
    'دوربین',
    'پرینتر',
    'موبایل',
    'تبلت',
  ];

  double get _sumCost => _items.fold(0, (s, i) => s + i.rowCost);
  double get _sumPrice => _items.fold(0, (s, i) => s + i.rowPrice);

  @override
  void initState() {
    super.initState();
    _repo = widget.repo;
    _techs = widget.technicians;
    _bootstrap();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      List<Party> customers = const [];
      List<Product> products = const [];
      try {
        customers = (await _repo.parties(
          type: PartyType.customer,
          take: 1000,
        )).items.where((p) => p.isActive).toList();
      } catch (_) {}
      try {
        products = (await _repo.products(pageSize: 5000)).items
            .where((p) => p.isActive)
            .toList();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _products = products;
      });

      final src = widget.source;
      if (src != null) {
        _partyId = src.partyId;
        _techId = src.technicianId;
        _receivedAt = src.receivedAt ?? DateTime.now();
        _status = src.status;
        _note.text = src.note ?? '';
        _devices.addAll(
          src.devices.map(
            (d) => _DeviceVm()
              ..id = d.id
              ..type = d.deviceType
              ..model = d.deviceModel ?? ''
              ..serial = d.serialNumber ?? ''
              ..problem = d.problemDescription ?? ''
              ..accessories = d.accessories ?? ''
              ..quote = d.quotedPrice > 0
                  ? formatNumText(d.quotedPrice.toStringAsFixed(0))
                  : '',
          ),
        );
        _items.addAll(
          src.items.map(
            (i) => _ItemVm()
              ..id = i.id
              ..productId = i.productId
              ..description = i.description
              ..qty = i.quantity.toString().replaceAll(RegExp(r'\.0$'), '')
              ..cost = i.cost > 0 ? formatNumText(i.cost.toStringAsFixed(0)) : ''
              ..price = i.price > 0
                  ? formatNumText(i.price.toStringAsFixed(0))
                  : '',
          ),
        );
        if (_partyId > 0 && !_customers.any((p) => p.id == _partyId)) {
          _customers = [
            ..._customers,
            Party(id: _partyId, name: src.partyName ?? 'مشتری'),
          ];
        }
      } else {
        _receivedAt = DateTime.now();
      }
      if (_devices.isEmpty) _devices.add(_DeviceVm());
      if (_items.isEmpty) _items.add(_ItemVm());
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12.5)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ShopColors.danger,
      ),
    );
  }

  Future<void> _newCustomer() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const PartyFormPage(type: PartyType.customer),
      ),
    );
    if (saved != true) return;
    try {
      final list = (await _repo.parties(
        type: PartyType.customer,
        take: 1000,
      )).items.where((p) => p.isActive).toList();
      if (!mounted) return;
      setState(() {
        _customers = list;
        final newest = list.isEmpty
            ? null
            : list.reduce((a, b) => a.id > b.id ? a : b);
        if (newest != null) _partyId = newest.id;
      });
    } catch (e) {
      _toast(e.toString());
    }
  }

  void _pickProduct(_ItemVm item) async {
    final picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductPickSheet(products: _products),
    );
    if (picked == null || !mounted) return;
    setState(() {
      item.productId = picked.id;
      if (item.description.trim().isEmpty) item.description = picked.name;
      // مثل وب: قیمت فروش فعلی و بهای میانگین پیشنهاد می‌شود
      if (parseNum(item.price) <= 0 && picked.salePrice > 0) {
        item.price = formatNumText(picked.salePrice.toStringAsFixed(0));
      }
      if (parseNum(item.cost) <= 0) {
        final c = picked.avgCost > 0 ? picked.avgCost : picked.purchasePrice;
        if (c > 0) item.cost = formatNumText(c.toStringAsFixed(0));
      }
    });
  }

  Future<void> _pickDate() async {
    final d = await showJalaliDatePicker(
      context,
      initial: _receivedAt,
      title: 'تاریخ ورود (پذیرش)',
    );
    if (d == null || !mounted) return;
    setState(() => _receivedAt = d);
  }

  Future<void> _save() async {
    // همان اعتبارسنجی‌های SaveInternal وب با همان متن‌ها
    if (_partyId <= 0) {
      _toast('مشتری را انتخاب کنید.');
      return;
    }
    if (_devices.isEmpty) {
      _toast('حداقل یک دستگاه اضافه کنید.');
      return;
    }
    for (var i = 0; i < _devices.length; i++) {
      if (_devices[i].type.trim().isEmpty) {
        _toast('نوع دستگاه کارت شمارهٔ ${Fa.digits(i + 1)} را وارد کنید.');
        return;
      }
    }
    final items = _items
        .where(
          (i) =>
              i.description.trim().isNotEmpty ||
              (i.productId ?? 0) > 0,
        )
        .toList();
    for (final i in items) {
      if (i.qtyValue <= 0) {
        _toast('مقدار هر ردیف باید بزرگ‌تر از صفر باشد.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final order = RepairOrder(
        id: widget.source?.id ?? 0,
        partyId: _partyId,
        technicianId: _techId,
        status: _isEdit ? _status : RepairStatus.received,
        receivedAt: _receivedAt ?? DateTime.now(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        devices: _devices
            .map(
              (d) => RepairDevice(
                id: d.id,
                deviceType: d.type.trim(),
                deviceModel: d.model.trim().isEmpty ? null : d.model.trim(),
                serialNumber: d.serial.trim().isEmpty ? null : d.serial.trim(),
                problemDescription: d.problem.trim().isEmpty
                    ? null
                    : d.problem.trim(),
                accessories: d.accessories.trim().isEmpty
                    ? null
                    : d.accessories.trim(),
                quotedPrice: d.quoteValue,
              ),
            )
            .toList(),
        items: items
            .map(
              (i) => RepairItem(
                id: i.id,
                description: i.description.trim(),
                productId: i.productId,
                quantity: i.qtyValue,
                cost: i.costValue,
                price: i.priceValue,
              ),
            )
            .toList(),
      );
      // فیلدهای تخت کارت اول داخل toJson ساخته می‌شوند (سازگاری با وب)
      await _repo.saveRepair(order);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: Text(
          _isEdit ? 'ویرایش پذیرش ${widget.source!.number}' : 'پذیرش جدید',
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              children: [
                _sharedCard(),
                const SizedBox(height: 10),
                _devicesCard(),
                const SizedBox(height: 10),
                _itemsCard(),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: ShopColors.surface,
            border: Border(top: BorderSide(color: ShopColors.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: ShopColors.inkSoft,
                    side: const BorderSide(color: ShopColors.line),
                  ),
                  child: const Text('انصراف'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: ShopColors.seed,
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: const Text(
                    'ذخیره پذیرش',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Text(
          t,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: ShopColors.inkFaint,
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(
              fontSize: 11,
              color: ShopColors.danger,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    ),
  );

  InputDecoration _dec(String hint) => InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 11, color: ShopColors.inkFaint),
  );

  Widget _sharedCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.assignment_turned_in_rounded,
                size: 16,
                color: ShopColors.seed,
              ),
              SizedBox(width: 5),
              Text(
                'اطلاعات مشترک پذیرش',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'مشتری (صاحب همه دستگاه‌ها) *',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: ShopColors.inkFaint,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _newCustomer,
                child: const Row(
                  children: [
                    Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 14,
                      color: ShopColors.ok,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'مشتری جدید',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: ShopColors.ok,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          DropdownButtonFormField<int>(
            initialValue: _partyId == 0 ? null : _partyId,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            hint: const Text(
              'انتخاب مشتری…',
              style: TextStyle(fontSize: 11.5),
            ),
            style: const TextStyle(fontSize: 12.5, color: ShopColors.ink),
            items: [
              for (final p in _customers)
                DropdownMenuItem<int>(
                  value: p.id,
                  child: Text(
                    (p.mobile ?? '').trim().isEmpty
                        ? p.name
                        : '${p.name} — ${p.mobile}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _partyId = v ?? 0),
          ),
          const SizedBox(height: 10),
          _label('تعمیرکار'),
          DropdownButtonFormField<int?>(
            initialValue: _techId,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            style: const TextStyle(fontSize: 12, color: ShopColors.ink),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('— بعداً تعیین می‌شود —'),
              ),
              for (final t in _techs.where((x) => x.isActive))
                DropdownMenuItem<int?>(
                  value: t.id,
                  child: Text(
                    (t.specialty ?? '').trim().isEmpty
                        ? t.name
                        : '${t.name} (${t.specialty})',
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _techId = v),
          ),
          const SizedBox(height: 10),
          _label('تاریخ ورود (پذیرش)'),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ShopColors.line),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 15,
                    color: ShopColors.inkFaint,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _receivedAt == null
                        ? 'انتخاب تاریخ'
                        : jalaliShort(_receivedAt!),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          if (_isEdit) ...[
            const SizedBox(height: 10),
            _label('وضعیت پذیرش'),
            DropdownButtonFormField<int>(
              initialValue: _status,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              style: const TextStyle(fontSize: 12, color: ShopColors.ink),
              items: const [
                DropdownMenuItem(
                  value: RepairStatus.received,
                  child: Text('پذیرش شده'),
                ),
                DropdownMenuItem(
                  value: RepairStatus.inProgress,
                  child: Text('در حال تعمیر'),
                ),
                DropdownMenuItem(
                  value: RepairStatus.ready,
                  child: Text('آماده تحویل'),
                ),
                DropdownMenuItem(
                  value: RepairStatus.cancelled,
                  child: Text('انصراف / مرجوع'),
                ),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
          ],
          const SizedBox(height: 10),
          _label('یادداشت پذیرش'),
          TextField(
            controller: _note,
            decoration: _dec('اختیاری'),
            style: const TextStyle(fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _devicesCard() {
    return Container(
      padding: const EdgeInsets.all(12),
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
                Icons.devices_other_rounded,
                size: 16,
                color: ShopColors.seed,
              ),
              const SizedBox(width: 5),
              Text(
                'دستگاه‌های پذیرش‌شده (${Fa.number(_devices.length)})',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _devices.add(_DeviceVm())),
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text(
                  'افزودن دستگاه',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          for (var i = 0; i < _devices.length; i++) _deviceCard(i),
        ],
      ),
    );
  }

  Widget _deviceCard(int i) {
    final d = _devices[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ShopColors.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ShopColors.seed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  Fa.digits(i + 1),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.seed,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'دستگاه ${Fa.digits(i + 1)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (_devices.length > 1)
                InkWell(
                  onTap: () => setState(() => _devices.removeAt(i)),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 17,
                    color: ShopColors.danger,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          _label('نوع دستگاه', required: true),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: d.type)
                    ..selection = TextSelection.collapsed(
                      offset: d.type.length,
                    ),
                  onChanged: (v) => d.type = v,
                  decoration: _dec('لپ‌تاپ، پرینتر…'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final t in _deviceTypes)
                GestureDetector(
                  onTap: () => setState(() => d.type = t),
                  child: ShopTag(
                    text: t,
                    color: d.type == t ? ShopColors.seed : ShopColors.inkFaint,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('برند و مدل'),
                    TextField(
                      controller: TextEditingController(text: d.model)
                        ..selection = TextSelection.collapsed(
                          offset: d.model.length,
                        ),
                      onChanged: (v) => d.model = v,
                      decoration: const InputDecoration(isDense: true),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('سریال دستگاه'),
                    TextField(
                      controller: TextEditingController(text: d.serial)
                        ..selection = TextSelection.collapsed(
                          offset: d.serial.length,
                        ),
                      onChanged: (v) => d.serial = v,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(isDense: true),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('لوازم همراه'),
                    TextField(
                      controller: TextEditingController(text: d.accessories)
                        ..selection = TextSelection.collapsed(
                          offset: d.accessories.length,
                        ),
                      onChanged: (v) => d.accessories = v,
                      decoration: _dec('شارژر، کیف…'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('برآورد (ریال)'),
                    TextField(
                      controller: TextEditingController(text: d.quote)
                        ..selection = TextSelection.collapsed(
                          offset: d.quote.length,
                        ),
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      onChanged: (v) {
                        final f = formatNumText(v);
                        d.quote = f;
                        setState(() {});
                      },
                      decoration: const InputDecoration(isDense: true),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _label('ایراد اعلامی مشتری'),
          TextField(
            controller: TextEditingController(text: d.problem)
              ..selection = TextSelection.collapsed(offset: d.problem.length),
            onChanged: (v) => d.problem = v,
            maxLines: 2,
            decoration: const InputDecoration(isDense: true),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _itemsCard() {
    return Container(
      padding: const EdgeInsets.all(12),
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
                Icons.checklist_rounded,
                size: 16,
                color: ShopColors.seed,
              ),
              const SizedBox(width: 5),
              const Expanded(
                child: Text(
                  'کارها و قطعات مصرفی',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _items.add(_ItemVm())),
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text('ردیف جدید', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          for (var i = 0; i < _items.length; i++) _itemRow(i),
          const Divider(height: 14, color: ShopColors.line),
          Row(
            children: [
              Expanded(
                child: Text(
                  'جمع هزینه: ${Fa.number(_sumCost)}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: ShopColors.inkSoft,
                  ),
                ),
              ),
              Text(
                'دریافتی: ${Fa.number(_sumPrice)}',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: ShopColors.seed,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'سود: ${Fa.number(_sumPrice - _sumCost)}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: (_sumPrice - _sumCost) >= 0
                      ? ShopColors.ok
                      : ShopColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemRow(int i) {
    final it = _items[i];
    final p = it.productId == null
        ? null
        : _products.where((x) => x.id == it.productId).firstOrNull;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: ShopColors.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'ردیف ${Fa.digits(i + 1)}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: ShopColors.inkFaint,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => setState(() {
                  _items.removeAt(i);
                  if (_items.isEmpty) _items.add(_ItemVm());
                }),
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: ShopColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _label('شرح کار'),
          TextField(
            controller: TextEditingController(text: it.description)
              ..selection = TextSelection.collapsed(
                offset: it.description.length,
              ),
            onChanged: (v) => it.description = v,
            decoration: const InputDecoration(isDense: true),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 6),
          _label('قطعه از انبار (اختیاری)'),
          InkWell(
            onTap: () => _pickProduct(it),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ShopColors.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p == null
                          ? 'جستجوی قطعه از انبار…'
                          : '${p.code} — ${p.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: p == null
                            ? ShopColors.inkFaint
                            : ShopColors.ink,
                      ),
                    ),
                  ),
                  if (p != null)
                    InkWell(
                      onTap: () => setState(() => it.productId = null),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: ShopColors.inkFaint,
                      ),
                    )
                  else
                    const Icon(
                      Icons.expand_more_rounded,
                      size: 16,
                      color: ShopColors.inkFaint,
                    ),
                ],
              ),
            ),
          ),
          if (p != null)
            Text(
              'فروش فعلی: ${Fa.number(p.salePrice)} · بهای میانگین: ${Fa.number(p.avgCost)}',
              style: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('مقدار'),
                    TextField(
                      controller: TextEditingController(text: it.qty)
                        ..selection = TextSelection.collapsed(
                          offset: it.qty.length,
                        ),
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      onChanged: (v) {
                        it.qty = v;
                        setState(() {});
                      },
                      decoration: const InputDecoration(isDense: true),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('هزینه داخلی'),
                    TextField(
                      controller: TextEditingController(text: it.cost)
                        ..selection = TextSelection.collapsed(
                          offset: it.cost.length,
                        ),
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      onChanged: (v) {
                        it.cost = formatNumText(v);
                        setState(() {});
                      },
                      decoration: const InputDecoration(isDense: true),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('دریافتی'),
                    TextField(
                      controller: TextEditingController(text: it.price)
                        ..selection = TextSelection.collapsed(
                          offset: it.price.length,
                        ),
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      onChanged: (v) {
                        it.price = formatNumText(v);
                        setState(() {});
                      },
                      decoration: const InputDecoration(isDense: true),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'سود ردیف: ${Fa.number(it.rowProfit)}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: it.rowProfit >= 0
                      ? ShopColors.ok
                      : ShopColors.danger,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'هر واحد: ${Fa.number(it.priceValue - it.costValue)}',
                style: const TextStyle(
                  fontSize: 9.5,
                  color: ShopColors.inkFaint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  جزئیات پذیرش
// ============================================================
class _RepairDetailsSheet extends StatelessWidget {
  const _RepairDetailsSheet({required this.order});

  final RepairOrder order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'جزئیات پذیرش ${o.number}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _cell('مشتری', o.partyName ?? '—', sub: o.partyTel),
                _cell('تعمیرکار', o.technicianName ?? '—',
                    sub: o.technicianPhone),
                _cell(
                  'ورود',
                  Fa.date(o.receivedAt?.toIso8601String()),
                ),
                _cell(
                  'خروج',
                  o.deliveredAt == null
                      ? 'هنوز در مجموعه است'
                      : Fa.date(o.deliveredAt!.toIso8601String()),
                ),
                _cell('وضعیت', RepairStatus.label(o.status)),
                if ((o.invoiceNumber ?? '').isNotEmpty)
                  _cell('فاکتور فروش', o.invoiceNumber!),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'دستگاه‌های پذیرش‌شده',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < o.devices.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: ShopColors.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${Fa.digits(i + 1)}. '
                          '${o.devices[i].deviceType} '
                          '${o.devices[i].deviceModel ?? ''}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${Fa.number(o.devices[i].quotedPrice)} ریال',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: ShopColors.seed,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'سریال: ${o.devices[i].serialNumber ?? '—'}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                    if ((o.devices[i].problemDescription ?? '')
                        .isNotEmpty)
                      Text(
                        'ایراد: ${o.devices[i].problemDescription}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: ShopColors.inkSoft,
                        ),
                      ),
                    if ((o.devices[i].accessories ?? '').isNotEmpty)
                      Text(
                        'لوازم همراه: ${o.devices[i].accessories}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: ShopColors.inkSoft,
                        ),
                      ),
                  ],
                ),
              ),
            if ((o.note ?? '').trim().isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: ShopColors.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'یادداشت پذیرش: ${o.note}',
                  style: const TextStyle(fontSize: 10.5),
                ),
              ),
            const Text(
              'کارها و قطعات مصرفی',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            for (final it in o.items)
              Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ShopColors.bg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it.description,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          if ((it.productName ?? '').isNotEmpty)
                            Text(
                              it.productName!,
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: ShopColors.seed,
                              ),
                            ),
                          Text(
                            'مقدار ${Fa.number(it.quantity)} · هزینه ${Fa.number(it.rowCost)} · دریافتی ${Fa.number(it.rowPrice)}',
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: ShopColors.inkFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      Fa.number(it.rowProfit),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: it.rowProfit >= 0
                            ? ShopColors.ok
                            : ShopColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 14, color: ShopColors.line),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'جمع هزینه: ${Fa.number(o.totalCost)}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: ShopColors.inkSoft,
                    ),
                  ),
                ),
                Text(
                  'دریافتی: ${Fa.number(o.totalPrice)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.seed,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'سود: ${Fa.number(o.profit)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: o.profit >= 0 ? ShopColors.ok : ShopColors.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                foregroundColor: ShopColors.inkSoft,
                side: const BorderSide(color: ShopColors.line),
              ),
              child: const Text('بستن'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(String k, String v, {String? sub}) => SizedBox(
    width: 150,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          k,
          style: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
        ),
        Text(
          v,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
        ),
        if ((sub ?? '').trim().isNotEmpty)
          Text(
            sub!,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
          ),
      ],
    ),
  );
}

// ============================================================
//  تبدیل به فروش و تحویل — آینهٔ مودال وب
// ============================================================
class RepairInvoiceSheet extends StatefulWidget {
  const RepairInvoiceSheet({
    super.key,
    required this.repo,
    required this.order,
  });

  final ShopRepository repo;
  final RepairOrder order;

  @override
  State<RepairInvoiceSheet> createState() => _RepairInvoiceSheetState();
}

class _RepairInvoiceSheetState extends State<RepairInvoiceSheet> {
  List<Warehouse> _warehouses = const [];
  List<TrsAccount> _accounts = const [];

  int _warehouseId = 0;
  int _payMethod = PayMethod.cash;
  int _cashKind = CashKind.cardReader;
  int? _trsAccountId;
  DateTime? _dueDate;
  final _cash = TextEditingController();
  bool _saving = false;
  bool _loading = true;

  double get _cashValue => parseNum(_cash.text);
  double get _total => widget.order.totalPrice;

  /// همان فیلتر وب برای حساب‌های مجاز هر نوع دریافت
  List<TrsAccount> get _accountsForCashType => switch (_cashKind) {
    CashKind.cash => _accounts
        .where(
          (a) => a.kind == AccountKind.cash || a.kind == AccountKind.pettyCash,
        )
        .toList(),
    CashKind.cardReader => _accounts
        .where((a) => a.kind == AccountKind.pos || a.kind == AccountKind.bank)
        .toList(),
    _ => _accounts
        .where((a) => a.kind == AccountKind.bank || a.kind == AccountKind.pos)
        .toList(),
  };

  @override
  void initState() {
    super.initState();
    _dueDate = DateTime.now().add(const Duration(days: 30));
    _bootstrap();
  }

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final whs = (await widget.repo.warehouses()).items
          .where((w) => w.isActive)
          .toList();
      final accs = await widget.repo.trsAccounts();
      if (!mounted) return;
      setState(() {
        _warehouses = whs;
        _accounts = accs;
        _warehouseId = whs.isNotEmpty ? whs.first.id : 1;
        final def = accs.where((a) => a.isDefault).firstOrNull ??
            accs
                .where(
                  (a) => a.kind == AccountKind.pos || a.kind == AccountKind.bank,
                )
                .firstOrNull ??
            accs.firstOrNull;
        _trsAccountId = def?.id;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12.5)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ShopColors.danger,
      ),
    );
  }

  Future<void> _doInvoice() async {
    // همان قواعد وب
    if (_payMethod == PayMethod.credit) {
      if (_dueDate == null) {
        _toast('برای فاکتور نسیه، تعیین تاریخ سررسید الزامی است.');
        return;
      }
      if (_cashValue >= _total) {
        _toast(
          'پیش‌دریافت نقدی نمی‌تواند برابر یا بیشتر از مبلغ کل فاکتور باشد؛ در این حالت روش تسویه را «نقدی» انتخاب کنید.',
        );
        return;
      }
    }
    if (_warehouseId <= 0) {
      _toast('انبار برداشت قطعات را انتخاب کنید.');
      return;
    }
    setState(() => _saving = true);
    try {
      final res = await widget.repo.invoiceRepair(widget.order.id, {
        'warehouseId': _warehouseId,
        'paymentMethod': _payMethod,
        'cashType': _payMethod == PayMethod.cash
            ? _cashKind
            : (_cashValue > 0 ? _cashKind : null),
        'trsAccountId': (_trsAccountId ?? 0) > 0 ? _trsAccountId : null,
        'dueDate': _payMethod == PayMethod.credit
            ? _dueDate!.toIso8601String()
            : null,
        'cashAmount': _payMethod == PayMethod.credit ? _cashValue : 0,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فاکتور ${res.invoiceNumber ?? ''} به صورت '
            '${_payMethod == PayMethod.cash ? 'نقدی' : 'نسیه'} صادر و دستگاه تحویل شد.',
            style: const TextStyle(fontSize: 12.5),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ShopColors.ok,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'تبدیل به فروش و تحویل — پذیرش ${o.number}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: ShopColors.bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'دستگاه‌های مشمول پذیرش (${Fa.number(o.devices.length)} دستگاه)',
                          style: const TextStyle(
                            fontSize: 10,
                            color: ShopColors.inkFaint,
                          ),
                        ),
                        for (final d in o.devices)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${d.deviceType} ${d.deviceModel ?? ''}',
                                  style: const TextStyle(fontSize: 10.5),
                                ),
                              ),
                              Text(
                                'برآورد ${Fa.number(d.quotedPrice)} ریال',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: ShopColors.inkFaint,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ShopField(
                    label: 'انبار برداشت قطعات',
                    required: true,
                    child: DropdownButtonFormField<int>(
                      initialValue: _warehouseId == 0 ? null : _warehouseId,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true),
                      style: const TextStyle(
                        fontSize: 12,
                        color: ShopColors.ink,
                      ),
                      items: [
                        for (final w in _warehouses)
                          DropdownMenuItem<int>(
                            value: w.id,
                            child: Text(w.name),
                          ),
                      ],
                      onChanged: (v) => setState(() => _warehouseId = v ?? 0),
                    ),
                  ),
                  ShopField(
                    label: 'روش تسویه فاکتور',
                    required: true,
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(
                              () => _payMethod = PayMethod.cash,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _payMethod == PayMethod.cash
                                    ? ShopColors.ok.withValues(alpha: 0.12)
                                    : ShopColors.bg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _payMethod == PayMethod.cash
                                      ? ShopColors.ok
                                      : ShopColors.line,
                                ),
                              ),
                              child: const Text(
                                'نقدی',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(
                              () => _payMethod = PayMethod.credit,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _payMethod == PayMethod.credit
                                    ? ShopColors.warn.withValues(alpha: 0.12)
                                    : ShopColors.bg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _payMethod == PayMethod.credit
                                      ? ShopColors.warn
                                      : ShopColors.line,
                                ),
                              ),
                              child: const Text(
                                'نسیه',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_payMethod == PayMethod.cash) ...[
                    ShopField(
                      label: 'نوع دریافت نقدی',
                      child: DropdownButtonFormField<int>(
                        initialValue: _cashKind,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true),
                        style: const TextStyle(
                          fontSize: 12,
                          color: ShopColors.ink,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: CashKind.cardReader,
                            child: Text('کارت‌خوان (POS)'),
                          ),
                          DropdownMenuItem(
                            value: CashKind.cash,
                            child: Text('وجه نقد (صندوق)'),
                          ),
                          DropdownMenuItem(
                            value: CashKind.cardTransfer,
                            child: Text('کارت به کارت'),
                          ),
                        ],
                        onChanged: (v) => setState(() {
                          _cashKind = v ?? _cashKind;
                          final valid = _accountsForCashType;
                          if (_trsAccountId != null &&
                              !valid.any((a) => a.id == _trsAccountId)) {
                            _trsAccountId = valid.firstOrNull?.id;
                          }
                        }),
                      ),
                    ),
                    ShopField(
                      label: 'حساب بانکی / کارت‌خوان / صندوق',
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              key: ValueKey('inv-acc-$_cashKind'),
                              initialValue: _accountsForCashType.any(
                                (a) => a.id == _trsAccountId,
                              )
                                  ? _trsAccountId
                                  : null,
                              isExpanded: true,
                              decoration: const InputDecoration(isDense: true),
                              hint: const Text(
                                '— انتخاب حساب / صندوق —',
                                style: TextStyle(fontSize: 11),
                              ),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: ShopColors.ink,
                              ),
                              items: [
                                for (final a in _accountsForCashType)
                                  DropdownMenuItem<int?>(
                                    value: a.id,
                                    child: Text(
                                      a.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _trsAccountId = v),
                            ),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton(
                            onPressed: () async {
                              final created =
                                  await showModalBottomSheet<TrsAccount>(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (_) =>
                                        QuickBankSheet(repo: widget.repo),
                                  );
                              if (created == null || !mounted) return;
                              setState(() {
                                _accounts = [..._accounts, created];
                                _trsAccountId = created.id;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              foregroundColor: ShopColors.seed,
                              side: const BorderSide(color: ShopColors.line),
                            ),
                            child: const Text(
                              'تعریف حساب',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'کل مبلغ ${Fa.number(_total)} ریال به صورت نقدی تسویه می‌گردد.',
                      style: const TextStyle(
                        fontSize: 10,
                        color: ShopColors.ok,
                      ),
                    ),
                  ] else ...[
                    ShopField(
                      label: 'تاریخ سررسید نسیه',
                      required: true,
                      child: InkWell(
                        onTap: () async {
                          final d = await showJalaliDatePicker(
                            context,
                            initial: _dueDate,
                            title: 'تاریخ سررسید',
                          );
                          if (d != null) setState(() => _dueDate = d);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ShopColors.line),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.event_rounded,
                                size: 15,
                                color: ShopColors.inkFaint,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _dueDate == null
                                    ? 'انتخاب تاریخ'
                                    : jalaliShort(_dueDate!),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final d in const [15, 30, 45, 60])
                          GestureDetector(
                            onTap: () => setState(
                              () => _dueDate = DateTime.now().add(
                                Duration(days: d),
                              ),
                            ),
                            child: ShopTag(
                              text: '${Fa.digits(d)} روزه',
                              color: ShopColors.inkSoft,
                            ),
                          ),
                      ],
                    ),
                    ShopField(
                      label: 'پیش‌دریافت نقدی (اختیاری)',
                      child: TextField(
                        controller: _cash,
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        onChanged: (v) {
                          final f = formatNumText(v);
                          if (f != v) {
                            _cash.value = TextEditingValue(
                              text: f,
                              selection: TextSelection.collapsed(
                                offset: f.length,
                              ),
                            );
                          }
                          setState(() {});
                        },
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'مبلغ پیش‌پرداخت (ریال)',
                          hintStyle: TextStyle(fontSize: 11),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    if (_cashValue > 0)
                      ShopField(
                        label: 'حساب واریز پیش‌دریافت',
                        child: DropdownButtonFormField<int?>(
                          initialValue: _trsAccountId,
                          isExpanded: true,
                          decoration: const InputDecoration(isDense: true),
                          hint: const Text(
                            '— انتخاب حساب / صندوق —',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: ShopColors.ink,
                          ),
                          items: [
                            for (final a in _accounts)
                              DropdownMenuItem<int?>(
                                value: a.id,
                                child: Text(
                                  a.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() => _trsAccountId = v),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ShopColors.bg,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'پیش‌دریافت: ${Fa.number(_cashValue)} ریال',
                              style: const TextStyle(
                                fontSize: 10,
                                color: ShopColors.seed,
                              ),
                            ),
                          ),
                          Text(
                            'مانده نسیه: ${Fa.number((_total - _cashValue).clamp(0, double.infinity))} ریال',
                            style: const TextStyle(
                              fontSize: 10,
                              color: ShopColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'جمع دریافتی: ${Fa.number(_total)} ریال',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: ShopColors.seed,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        'سود تعمیر: ${Fa.number(o.profit)} ریال',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: ShopColors.ok,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            foregroundColor: ShopColors.inkSoft,
                            side: const BorderSide(color: ShopColors.line),
                          ),
                          child: const Text('انصراف'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _doInvoice,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            backgroundColor: ShopColors.ok,
                          ),
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.receipt_long_rounded, size: 18),
                          label: Text(
                            _saving
                                ? 'در حال صدور…'
                                : 'صدور فاکتور فروش (${_payMethod == PayMethod.cash ? 'نقدی' : 'نسیه'})',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

// ============================================================
//  مدیریت تعمیرکارها — آینهٔ مودال «تعمیرکارها» وب
// ============================================================
class _TechniciansSheet extends StatefulWidget {
  const _TechniciansSheet({required this.repo, required this.items});

  final ShopRepository repo;
  final List<Technician> items;

  @override
  State<_TechniciansSheet> createState() => _TechniciansSheetState();
}

class _TechniciansSheetState extends State<_TechniciansSheet> {
  late List<Technician> _items;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _items = widget.items;
  }

  Future<void> _reload() async {
    try {
      final list = await widget.repo.technicians();
      if (!mounted) return;
      setState(() => _items = list);
    } catch (_) {}
  }

  void _toast(String msg, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12.5)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? ShopColors.ok : ShopColors.danger,
      ),
    );
  }

  Future<void> _edit([Technician? t]) async {
    final saved = await showDialog<Technician>(
      context: context,
      builder: (_) => _TechDialog(repo: widget.repo, source: t),
    );
    if (saved == null) return;
    _toast('تعمیرکار ذخیره شد.', ok: true);
    await _reload();
  }

  Future<void> _toggle(Technician t) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.repo.saveTechnician(
        Technician(
          id: t.id,
          name: t.name,
          phone: t.phone,
          specialty: t.specialty,
          isActive: !t.isActive,
        ),
      );
      await _reload();
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Technician t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(
          'آیا از حذف تعمیرکار «${t.name}» مطمئن هستید؟',
          style: const TextStyle(fontSize: 12.5, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ShopColors.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('تأیید'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.repo.deleteTechnician(t.id);
      _toast('تعمیرکار حذف شد.', ok: true);
      await _reload();
    } catch (e) {
      _toast(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'تعمیرکارها',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    'افزودن',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            Flexible(
              child: _items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'تعمیرکاری تعریف نشده است.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _items.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: ShopColors.line),
                      itemBuilder: (_, i) {
                        final t = _items[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            t.name,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '${(t.specialty ?? '').isEmpty ? 'بدون تخصص' : t.specialty}'
                            '${(t.phone ?? '').isEmpty ? '' : ' · ${t.phone}'}'
                            ' · ${Fa.number(t.activeRepairs)} پذیرش فعال',
                            style: const TextStyle(
                              fontSize: 10,
                              color: ShopColors.inkFaint,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ShopTag(
                                text: t.isActive ? 'فعال' : 'غیرفعال',
                                color: t.isActive
                                    ? ShopColors.ok
                                    : ShopColors.inkFaint,
                              ),
                              IconButton(
                                onPressed: () => _edit(t),
                                icon: const Icon(
                                  Icons.edit_rounded,
                                  size: 17,
                                  color: ShopColors.seed,
                                ),
                              ),
                              IconButton(
                                onPressed: () => _toggle(t),
                                icon: Icon(
                                  Icons.power_settings_new_rounded,
                                  size: 17,
                                  color: t.isActive
                                      ? ShopColors.warn
                                      : ShopColors.ok,
                                ),
                              ),
                              IconButton(
                                onPressed: () => _delete(t),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 17,
                                  color: ShopColors.danger,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TechDialog extends StatefulWidget {
  const _TechDialog({required this.repo, this.source});

  final ShopRepository repo;
  final Technician? source;

  @override
  State<_TechDialog> createState() => _TechDialogState();
}

class _TechDialogState extends State<_TechDialog> {
  late final _name = TextEditingController(text: widget.source?.name ?? '');
  late final _phone = TextEditingController(text: widget.source?.phone ?? '');
  late final _specialty = TextEditingController(
    text: widget.source?.specialty ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _specialty.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'نام تعمیرکار را وارد کنید.',
            style: TextStyle(fontSize: 12.5),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ShopColors.danger,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await widget.repo.saveTechnician(
        Technician(
          id: widget.source?.id ?? 0,
          name: _name.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          specialty:
              _specialty.text.trim().isEmpty ? null : _specialty.text.trim(),
          isActive: widget.source?.isActive ?? true,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString(), style: const TextStyle(fontSize: 12.5)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ShopColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.source == null ? 'تعمیرکار جدید' : 'ویرایش تعمیرکار',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'نام',
              labelStyle: TextStyle(fontSize: 11.5),
            ),
            style: const TextStyle(fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'تلفن',
              labelStyle: TextStyle(fontSize: 11.5),
            ),
            style: const TextStyle(fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _specialty,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'تخصص',
              labelStyle: TextStyle(fontSize: 11.5),
            ),
            style: const TextStyle(fontSize: 12.5),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: ShopColors.seed),
          child: Text(_saving ? '…' : 'ذخیره'),
        ),
      ],
    );
  }
}

// ============================================================
//  انتخاب قطعه از انبار
// ============================================================
class _ProductPickSheet extends StatefulWidget {
  const _ProductPickSheet({required this.products});

  final List<Product> products;

  @override
  State<_ProductPickSheet> createState() => _ProductPickSheetState();
}

class _ProductPickSheetState extends State<_ProductPickSheet> {
  final _q = TextEditingController();

  List<Product> get _filtered {
    final q = _q.text.trim();
    if (q.isEmpty) return widget.products.take(60).toList();
    return widget.products
        .where(
          (p) => p.name.contains(q) || p.code.contains(q),
        )
        .take(80)
        .toList();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'انتخاب قطعه از انبار',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'جستجوی نام یا کد کالا…',
                hintStyle: TextStyle(
                  fontSize: 11.5,
                  color: ShopColors.inkFaint,
                ),
                prefixIcon: Icon(Icons.search_rounded, size: 18),
              ),
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: _filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'کالایی پیدا نشد.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: ShopColors.line),
                      itemBuilder: (_, i) {
                        final p = _filtered[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            '${p.code} — ${p.name}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            'فروش: ${Fa.number(p.salePrice)} · بهای میانگین: ${Fa.number(p.avgCost)}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: ShopColors.inkFaint,
                            ),
                          ),
                          onTap: () => Navigator.pop(context, p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
