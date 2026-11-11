// ============================================================
//  داشبورد عملیاتی (خرید، فروش و تعمیرات)
//  آینهٔ /operations/reports/dashboard → Pages/Operations/OperationsDashboard.razor
//
//  گیت وب: `Orders` یا `Repairs` → «برای مشاهدهٔ داشبورد جامع، دسترسی
//  مشاهدهٔ خرید/فروش یا تعمیرات لازم است.»
//
//  • بازهٔ پیش‌فرض: ۳۰ روز گذشته تا امروز + «بازخوانی شاخص‌ها»
//  • ۴ شاخص خرید/فروش/درآمد تعمیرات/سود تعمیرات (هر کدام با گیت خودش)
//  • نمودار روند دوره‌ای خرید، فروش و درآمد تعمیرات
//  • بهترین معرف + رتبه‌بندی معرف‌ها
//  • کارت‌های وضعیت پذیرش‌های تعمیرات (باز، تحویل‌شده، لغو‌شده،
//    و عمر پذیرش‌های باز: ۰–۳ / ۴–۷ / بیش از ۷ روز)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/shop_perms.dart';
import '../data/shop_repository.dart';
import '../models/ops_models.dart';
import 'shop_style.dart';

class OpsDashboardPage extends StatefulWidget {
  const OpsDashboardPage({super.key});

  @override
  State<OpsDashboardPage> createState() => _OpsDashboardPageState();
}

class _OpsDashboardPageState extends State<OpsDashboardPage> {
  late final ShopRepository _repo;
  late final ShopPerms _perms;

  OpsDashboard? _data;
  bool _loading = true;
  String? _error;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _perms = ShopPerms(context.read<AuthController>().session);
    _from = DateTime.now().subtract(const Duration(days: 30));
    _to = DateTime.now();
    _load();
  }

  bool get _canOpen =>
      _perms.canSeeModule('Orders') || _perms.canSeeModule('Repairs');

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');

  Future<void> _load() async {
    if (!_canOpen) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _repo.opsDashboard(from: _from, to: _to);
      if (!mounted) return;
      setState(() {
        _data = d;
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

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showJalaliDatePicker(
      context,
      initial: (isFrom ? _from : _to) ?? DateTime.now(),
      title: isFrom ? 'از تاریخ' : 'تا تاریخ',
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
    _load();
  }

  String get _rangeText =>
      '${_from == null ? 'از ابتدا' : jalaliShort(_from!)} تا '
      '${_to == null ? 'امروز' : jalaliShort(_to!)}';

  @override
  Widget build(BuildContext context) {
    if (!_canOpen) {
      return Scaffold(
        backgroundColor: ShopColors.bg,
        appBar: AppBar(
          backgroundColor: ShopColors.surface,
          foregroundColor: ShopColors.ink,
          elevation: 0.5,
          title: const Text(
            'داشبورد عملیاتی',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
        ),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: ShopEmpty(
            title: 'دسترسی لازم را ندارید',
            subtitle:
                'برای مشاهدهٔ داشبورد جامع، دسترسی مشاهدهٔ خرید/فروش یا تعمیرات لازم است.',
            icon: Icons.shield_outlined,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: const Text(
          'داشبورد عملیاتی',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'به‌روزرسانی',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ShopEmpty(
              title: 'داده‌های داشبورد بارگذاری نشد',
              subtitle: _error,
              icon: Icons.error_outline_rounded,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
                children: [
                  ShopHeader(
                    title: 'داشبورد جامع تحلیلی عملیات و فروشگاه',
                    subtitle:
                        'تحلیل زنده و یکپارچه خرید، فروش، خدمات تعمیراتی، سودآوری و عملکرد معرف‌ها',
                    icon: Icons.speed_rounded,
                    badge: 'دیده‌بان کسب‌وکار',
                  ),
                  const SizedBox(height: 10),
                  _filters(),
                  if (_data == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 30),
                      child: ShopEmpty(
                        title: 'داده‌ای برای این بازه نیست',
                        subtitle: 'بازهٔ دیگری را انتخاب و بازخوانی کنید.',
                        icon: Icons.insights_rounded,
                      ),
                    )
                  else
                    ..._body(_data!),
                ],
              ),
            ),
    );
  }

  Widget _filters() => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _dateBox(
                'از تاریخ',
                _from,
                () => _pickDate(isFrom: true),
                () {
                  setState(() => _from = null);
                  _load();
                },
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _dateBox(
                'تا تاریخ',
                _to,
                () => _pickDate(isFrom: false),
                () {
                  setState(() => _to = null);
                  _load();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _loading ? null : _load,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 42),
              backgroundColor: ShopColors.seed,
            ),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text(
              'بازخوانی شاخص‌ها',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(
              Icons.date_range_rounded,
              size: 13,
              color: ShopColors.indigo,
            ),
            const SizedBox(width: 5),
            Text(
              'بازه گزارش: $_rangeText',
              style: const TextStyle(fontSize: 9.5, color: ShopColors.inkSoft),
            ),
          ],
        ),
      ],
    ),
  );

  List<Widget> _body(OpsDashboard d) {
    final showOrders = _perms.canSeeModule('Orders');
    final showRepairs = _perms.canSeeModule('Repairs');
    final maxTrend = d.trend.fold<double>(0, (m, p) {
      final x = [p.purchase, p.sale, p.repairRevenue];
      final mx = x.reduce((a, b) => a > b ? a : b);
      return mx > m ? mx : m;
    });

    return [
      if (showOrders) ...[
        Row(
          children: [
            Expanded(
              child: ShopKpi(
                title: 'کل خرید دوره',
                value: Fa.number(d.purchaseTotal),
                unit: 'ریال — ${Fa.number(d.purchaseCount)} فاکتور خرید',
                icon: Icons.shopping_bag_rounded,
                color: ShopColors.indigo,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ShopKpi(
                title: 'کل فروش دوره',
                value: Fa.number(d.saleTotal),
                unit: 'ریال — ${Fa.number(d.saleCount)} فاکتور فروش',
                icon: Icons.shopping_cart_rounded,
                color: ShopColors.ok,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
      if (showRepairs) ...[
        Row(
          children: [
            Expanded(
              child: ShopKpi(
                title: 'درآمد تعمیرات تحویل‌شده',
                value: Fa.number(d.repairRevenue),
                unit: '${Fa.number(d.deliveredRepairCount)} پذیرش تحویل‌شده',
                icon: Icons.build_rounded,
                color: ShopColors.warn,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ShopKpi(
                title: 'سود خالص تعمیرات',
                value: Fa.number(d.repairProfit),
                unit: '${Fa.number(d.activeRepairCount)} دستگاه در دست اقدام',
                icon: d.repairProfit >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: d.repairProfit >= 0 ? ShopColors.ok : ShopColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
      // ---------- نمودار روند ----------
      Container(
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
                const Text(
                  'روند خرید، فروش و درآمد تعمیرات',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                ShopTag(text: 'ماهانه', color: ShopColors.inkFaint),
              ],
            ),
            const SizedBox(height: 8),
            if (d.trend.isEmpty)
              const Text(
                'در این بازه داده‌ای ثبت نشده است.',
                style: TextStyle(fontSize: 11, color: ShopColors.inkFaint),
              )
            else
              SizedBox(
                height: 140,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final p in d.trend)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _bar(p.sale, maxTrend, ShopColors.ok),
                              _bar(p.purchase, maxTrend, ShopColors.indigo),
                              _bar(
                                p.repairRevenue,
                                maxTrend,
                                ShopColors.warn,
                              ),
                              Text(
                                p.label,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: const TextStyle(
                                  fontSize: 7,
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
            const SizedBox(height: 6),
            Row(
              children: [
                _legend('فروش', ShopColors.ok),
                const SizedBox(width: 10),
                _legend('خرید', ShopColors.indigo),
                const SizedBox(width: 10),
                _legend('درآمد تعمیرات', ShopColors.warn),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 9),
      // ---------- بهترین معرف + رتبه‌بندی ----------
      Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ShopColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'بهترین معرف دوره',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            if (d.bestReferrer == null)
              const Text(
                'در این بازه فروش ارجاعی ثبت نشده است.',
                style: TextStyle(fontSize: 11, color: ShopColors.inkFaint),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ShopColors.seed.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      size: 20,
                      color: ShopColors.warn,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.bestReferrer!.referrerName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${Fa.number(d.bestReferrer!.saleCount)} فاکتور موفق ارجاعی',
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: ShopColors.inkFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${Fa.number(d.bestReferrer!.salesAmount)} ریال',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: ShopColors.seed,
                      ),
                    ),
                  ],
                ),
              ),
              if (d.topReferrers.length > 1) ...[
                const SizedBox(height: 8),
                const Text(
                  'رتبه‌بندی معرف‌ها',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.inkSoft,
                  ),
                ),
                for (var i = 1; i < d.topReferrers.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          child: Text(
                            Fa.number(i + 1),
                            style: const TextStyle(
                              fontSize: 10,
                              color: ShopColors.inkFaint,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            d.topReferrers[i].referrerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${Fa.number(d.topReferrers[i].saleCount)} فاکتور',
                          style: const TextStyle(
                            fontSize: 9,
                            color: ShopColors.inkFaint,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          Fa.number(d.topReferrers[i].salesAmount),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
      if (showRepairs) ...[
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: ShopColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ShopColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'وضعیت پذیرش‌های تعمیرات',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              _kv('کل پذیرش‌های باز', Fa.number(d.openRepairCount)),
              _kv('در انتظار بررسی', Fa.number(d.openReceivedCount)),
              _kv('در حال انجام', Fa.number(d.openInProgressCount)),
              _kv('آمادهٔ تحویل', Fa.number(d.openReadyCount)),
              Divider(color: ShopColors.line, height: 14),
              _kv('عمر ۰ تا ۳ روز', Fa.number(d.openAge0To3DaysCount)),
              _kv('عمر ۴ تا ۷ روز', Fa.number(d.openAge4To7DaysCount)),
              _kv('بیش از ۷ روز', Fa.number(d.openAgeOver7DaysCount)),
              if (d.averageRepairTurnaroundDays != null)
                _kv(
                  'میانگین زمان تحویل',
                  '${Fa.number(d.averageRepairTurnaroundDays!, decimals: 1)} روز',
                ),
              Divider(color: ShopColors.line, height: 14),
              _kv('پذیرش‌های دوره', Fa.number(d.repairCount)),
              _kv('تحویل‌شده', Fa.number(d.deliveredRepairCount)),
              _kv('لغو‌شده', Fa.number(d.cancelledRepairCount)),
            ],
          ),
        ),
      ],
    ];
  }

  Widget _bar(double value, double max, Color color) {
    final h = max <= 0 ? 2.0 : (value / max) * 90;
    return Container(
      height: h.clamp(2.0, 90.0),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _legend(String label, Color color) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(fontSize: 9, color: ShopColors.inkSoft),
      ),
    ],
  );

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Text(
          k,
          style: const TextStyle(fontSize: 10, color: ShopColors.inkSoft),
        ),
        const Spacer(),
        Text(
          v,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
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
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
      decoration: BoxDecoration(
        color: ShopColors.bg,
        borderRadius: BorderRadius.circular(10),
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
