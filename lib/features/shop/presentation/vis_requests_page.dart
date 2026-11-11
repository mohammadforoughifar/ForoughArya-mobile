// ============================================================
//  همهٔ درخواست‌های سفارش — آینهٔ /sales/requests
//  منبع: Pages/SalesVisit/AllRequests.razor
//
//  • ۴ شاخص: فروش نهایی‌شده، در انتظار بررسی، تأییدشده/آماده صف مالی،
//    مرجوعی+رد+لغو
//  • نوار وضعیت با شمارندهٔ هر وضعیت (شامل رد‌شده و برگشتی)
//  • جستجو + بازهٔ تاریخ شمسی، «پاک‌سازی فیلترها»
//  • ردیف‌ها با «تصمیم سرپرست» (یادداشت + تصمیم‌گیرنده + تاریخ)
//  • جزئیات بازشو: سطرهای کالا، خلاصهٔ مالی، تاریخچهٔ رویدادها (جدیدترین
//    در ابتدا — همان ترتیب نمایش وب از انتها یعنی جدیدترین‌ها اول)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/shop_repository.dart';
import '../models/visit_models.dart';
import 'shop_style.dart';
import 'visit_detail_page.dart';
import 'visit_form_page.dart';
import 'vis_approvals_page.dart';
import 'visits_cards.dart';

class VisRequestsPage extends StatefulWidget {
  const VisRequestsPage({super.key});

  @override
  State<VisRequestsPage> createState() => _VisRequestsPageState();
}

class _VisRequestsPageState extends State<VisRequestsPage> {
  late final ShopRepository _repo;

  List<VisOrder> _all = const [];
  bool _loading = true;
  String? _error;

  int? _status;
  final _searchCtrl = TextEditingController();
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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
    try {
      final list = await _repo.visOrders(
        from: _from,
        to: _to,
        search: _searchCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _all = list;
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

  List<VisOrder> get _items =>
      _status == null ? _all : _all.where((o) => o.status == _status).toList();

  int _count(int s) => _all.where((o) => o.status == s).length;

  double _sumNet(int s) => _all
      .where((o) => o.status == s)
      .fold<double>(0, (a, o) => a + o.totalNet);

  void _clearFilters() {
    setState(() {
      _status = null;
      _from = null;
      _to = null;
      _searchCtrl.clear();
    });
    _load();
  }

  bool get _hasFilter =>
      _status != null ||
      _from != null ||
      _to != null ||
      _searchCtrl.text.trim().isNotEmpty;

  Future<void> _pick(bool isFrom) async {
    final d = await showJalaliDatePicker(
      context,
      initial: (isFrom ? _from : _to) ?? DateTime.now(),
      title: isFrom ? 'از تاریخ' : 'تا تاریخ',
    );
    if (d == null) return;
    setState(() => isFrom ? _from = d : _to = d);
    _load();
  }

  Future<void> _openDetail(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VisitDetailPage(orderId: id)),
    );
    if (mounted) _load();
  }

  Future<void> _openNew() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const VisitFormPage()),
    );
    if (ok == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final chips = <(String, int?, int)>[
      ('همه', null, _all.length),
      ('پیش‌نویس', VisStatus.draft, _count(VisStatus.draft)),
      ('در انتظار تأیید', VisStatus.submitted, _count(VisStatus.submitted)),
      ('تأییدشده', VisStatus.approved, _count(VisStatus.approved)),
      ('برگشتی', VisStatus.returned, _count(VisStatus.returned)),
      ('رد‌شده', VisStatus.rejected, _count(VisStatus.rejected)),
      ('فروش‌شده', VisStatus.invoiced, _count(VisStatus.invoiced)),
      ('لغوشده', VisStatus.canceled, _count(VisStatus.canceled)),
    ];

    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: const Text(
          'همهٔ درخواست‌های سفارش',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const VisApprovalsPage()),
            ),
            icon: const Icon(Icons.verified_user_rounded, size: 20),
            tooltip: 'کارتابل تأیید',
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'به‌روزرسانی داده‌ها',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNew,
        backgroundColor: ShopColors.seed,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text(
          'ثبت سفارش جدید',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ShopEmpty(
              title: 'دریافت درخواست‌ها ناموفق بود',
              subtitle: _error,
              icon: Icons.error_outline_rounded,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
                children: [
                  _kpis(),
                  const SizedBox(height: 12),
                  _tabs(chips),
                  const SizedBox(height: 10),
                  _filters(),
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 30),
                      child: ShopEmpty(
                        title: 'هیچ درخواستی یافت نشد',
                        subtitle:
                            'هیچ سفارشی مطابق با این فیلتر یا عبارت جستجو وجود ندارد.',
                        icon: Icons.inbox_outlined,
                      ),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: Text(
                        'نمایش ${Fa.number(_items.length)} از ${Fa.number(_all.length)} سفارش',
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                    ),
                    for (final o in _items)
                      VisOrderCard(
                        order: o,
                        showReferrer: true,
                        onTap: () => _openDetail(o.id),
                        leadingNote: (o.decisionNote ?? '').isEmpty
                            ? null
                            : _decisionNote(o),
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _decisionNote(VisOrder o) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: ShopColors.warn.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          o.decisionNote!,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9.5, color: ShopColors.inkSoft),
        ),
        Text(
          'توسط: ${o.decidedBy ?? '—'}'
          '${o.decidedAt == null ? '' : ' • ${jalaliShort(o.decidedAt!)}'}',
          style: const TextStyle(fontSize: 8.5, color: ShopColors.inkFaint),
        ),
      ],
    ),
  );

  Widget _kpis() {
    final canceledTail = _count(VisStatus.returned) +
        _count(VisStatus.rejected) +
        _count(VisStatus.canceled);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ShopKpi(
                title: 'مجموع فروش نهایی‌شده',
                value: Fa.number(_sumNet(VisStatus.invoiced)),
                unit: 'ریال — ${Fa.number(_count(VisStatus.invoiced))} فاکتور',
                icon: Icons.payments_rounded,
                color: ShopColors.ok,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ShopKpi(
                title: 'در انتظار بررسی',
                value: Fa.number(_count(VisStatus.submitted)),
                unit: 'ارزش: ${Fa.number(_sumNet(VisStatus.submitted))} ریال',
                icon: Icons.hourglass_top_rounded,
                color: ShopColors.warn,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ShopKpi(
                title: 'آمادهٔ صف مالی',
                value: Fa.number(_count(VisStatus.approved)),
                unit: 'سفارش تأییدشده',
                icon: Icons.fact_check_outlined,
                color: ShopColors.indigo,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ShopKpi(
                title: 'مرجوعی / رد / لغو',
                value: Fa.number(canceledTail),
                unit:
                    '${Fa.number(_count(VisStatus.returned))} برگشتی · '
                    '${Fa.number(_count(VisStatus.rejected))} رد · '
                    '${Fa.number(_count(VisStatus.canceled))} لغو',
                icon: Icons.replay_rounded,
                color: ShopColors.inkSoft,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tabs(List<(String, int?, int)> chips) => SizedBox(
    height: 34,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: chips.length,
      separatorBuilder: (_, _) => const SizedBox(width: 6),
      itemBuilder: (_, i) {
        final c = chips[i];
        final active = _status == c.$2;
        return InkWell(
          onTap: () => setState(() => _status = c.$2),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: active ? ShopColors.seed : ShopColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active ? ShopColors.seed : ShopColors.line,
              ),
            ),
            child: Row(
              children: [
                Text(
                  c.$1,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : ShopColors.inkSoft,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withValues(alpha: 0.22)
                        : ShopColors.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    Fa.number(c.$3),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : ShopColors.inkFaint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _filters() => Container(
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      children: [
        TextField(
          controller: _searchCtrl,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _load(),
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'شماره سفارش، مشتری، ویزیتور یا یادداشت…',
            hintStyle: const TextStyle(fontSize: 11.5),
            prefixIcon: const Icon(Icons.search_rounded, size: 17),
            suffixIcon: _searchCtrl.text.trim().isEmpty
                ? null
                : InkWell(
                    onTap: () {
                      _searchCtrl.clear();
                      _load();
                    },
                    child: const Icon(Icons.close_rounded, size: 16),
                  ),
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: _dateBox('از تاریخ', _from, () => _pick(true), () {
                setState(() => _from = null);
                _load();
              }),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _dateBox('تا تاریخ', _to, () => _pick(false), () {
                setState(() => _to = null);
                _load();
              }),
            ),
          ],
        ),
        if (_hasFilter)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _clearFilters,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              icon: const Icon(Icons.filter_alt_off_rounded, size: 14),
              label: const Text(
                'پاک‌سازی فیلترها',
                style: TextStyle(fontSize: 10),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _dateBox(
    String label,
    DateTime? value,
    VoidCallback onTap,
    VoidCallback onClear,
  ) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(9),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: ShopColors.bg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: ShopColors.line),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_month_rounded,
            size: 13,
            color: ShopColors.inkFaint,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value == null ? label : jalaliShort(value),
              maxLines: 1,
              style: TextStyle(
                fontSize: 10,
                color: value == null ? ShopColors.inkFaint : ShopColors.ink,
              ),
            ),
          ),
          if (value != null)
            InkWell(
              onTap: onClear,
              child: const Icon(
                Icons.close_rounded,
                size: 12,
                color: ShopColors.inkFaint,
              ),
            ),
        ],
      ),
    ),
  );
}
