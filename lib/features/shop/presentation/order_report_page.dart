// ============================================================
//  گزارش تحلیلی خرید / فروش
//  آینهٔ صفحهٔ وب: /operations/reports/orders/{Type}
//                 → Pages/Operations/OperationsOrderReport.razor
//
//  • گیت مجوز: CanSee("Orders") — همان پیام وب
//  • فیلتر: از تاریخ، تا تاریخ (شمسی)، طرف حساب، انبار + «اعمال فیلتر»
//  • کارت‌های شاخص: جمع مبلغ، تعداد اسناد، تعداد سطر، مجموع مقدار،
//    میانگین مبلغ سند
//  • نمودار روند دوره‌ای (میلگردهای نسبی) + رتبه‌بندی طرف حساب‌ها
//  ⚠️ «چاپ رسمی گزارش» وب با پنجرهٔ چاپ مرورگر کار می‌کند؛ ساخته نشد.
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
import '../models/order_models.dart';
import '../models/shop_models.dart';
import 'shop_style.dart';

class OrderReportPage extends StatefulWidget {
  const OrderReportPage({super.key, required this.type});

  final int type;

  @override
  State<OrderReportPage> createState() => _OrderReportPageState();
}

class _OrderReportPageState extends State<OrderReportPage> {
  late final ShopRepository _repo;
  late final ShopPerms _perms;

  bool get _isPurchase => widget.type == TxnType.purchase;

  OrderReport? _report;
  bool _loading = true;
  String? _error;

  DateTime? _from;
  DateTime? _to;
  int? _partyId;
  int? _warehouseId;
  List<Party> _parties = const [];
  List<Warehouse> _warehouses = const [];

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _perms = ShopPerms(context.read<AuthController>().session);
    _loadLookups();
    _load();
  }

  Future<void> _loadLookups() async {
    List<Party> parties = const [];
    List<Warehouse> whs = const [];
    try {
      parties = (await _repo.parties(
        type: _isPurchase ? PartyType.supplier : PartyType.customer,
        take: 1000,
      )).items;
    } catch (_) {}
    try {
      whs = (await _repo.warehouses()).items;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _parties = parties;
      _warehouses = whs;
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rep = await _repo.orderReport(
        type: widget.type,
        from: _from,
        to: _to,
        partyId: _partyId,
        warehouseId: _warehouseId,
      );
      if (!mounted) return;
      setState(() {
        _report = rep;
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

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showJalaliDatePicker(
      context,
      initial: isFrom ? _from : _to,
      title: isFrom ? 'از تاریخ' : 'تا تاریخ',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // همان پیام و گیت وب
    if (!_perms.canSeeModule('Orders')) {
      return Scaffold(
        backgroundColor: ShopColors.bg,
        appBar: AppBar(
          backgroundColor: ShopColors.surface,
          foregroundColor: ShopColors.ink,
          elevation: 0.5,
        ),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: ShopEmpty(
            title: 'دسترسی لازم را ندارید',
            subtitle:
                'برای مشاهدهٔ گزارش خرید و فروش، دسترسی مشاهدهٔ اسناد خرید و فروش لازم است.',
            icon: Icons.shield_outlined,
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: ShopColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ShopHeader(
                title: _isPurchase ? 'گزارش جامع و تحلیلی خرید' : 'گزارش جامع و تحلیلی فروش',
                subtitle: _isPurchase
                    ? 'عملیات تأمین کالا — روند دوره‌ای و رتبه‌بندی تأمین‌کنندگان'
                    : 'عملیات فروش و درآمد — روند دوره‌ای و رتبه‌بندی مشتریان',
                icon: _isPurchase
                    ? Icons.shopping_bag_rounded
                    : Icons.shopping_cart_rounded,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              sliver: SliverToBoxAdapter(child: _filters()),
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
                  title: 'گزارش دریافت نشد',
                  subtitle: _error,
                  icon: Icons.error_outline_rounded,
                ),
              )
            else if (_report == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: ShopEmpty(
                  title: 'داده‌ای برای این گزارش دریافت نشد',
                  icon: Icons.insights_rounded,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                sliver: SliverList.list(children: _body(_report!)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filters() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(16),
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
                  () => setState(() => _from = null),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dateBox(
                  'تا تاریخ',
                  _to,
                  () => _pickDate(isFrom: false),
                  () => setState(() => _to = null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            initialValue: _partyId,
            isExpanded: true,
            decoration: InputDecoration(
              isDense: true,
              labelText: _isPurchase ? 'تأمین‌کننده' : 'مشتری',
              labelStyle: const TextStyle(fontSize: 11),
            ),
            style: const TextStyle(fontSize: 12, color: ShopColors.ink),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('همهٔ طرف‌حساب‌ها'),
              ),
              for (final p in _parties)
                DropdownMenuItem<int?>(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() => _partyId = v),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            initialValue: _warehouseId,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'انبار مبدأ/مقصد',
              labelStyle: TextStyle(fontSize: 11),
            ),
            style: const TextStyle(fontSize: 12, color: ShopColors.ink),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('همهٔ انبارها'),
              ),
              for (final w in _warehouses)
                DropdownMenuItem<int?>(value: w.id, child: Text(w.name)),
            ],
            onChanged: (v) => setState(() => _warehouseId = v),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _load,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                backgroundColor: _isPurchase ? ShopColors.indigo : ShopColors.ok,
              ),
              icon: const Icon(Icons.filter_alt_rounded, size: 17),
              label: const Text(
                'اعمال فیلتر',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(OrderReport r) {
    // حداکثر مقدار روند برای نمایش میله‌های نسبی
    final maxTrend = r.trend.fold<double>(
      0,
      (m, t) => t.amount > m ? t.amount : m,
    );
    final maxParty = r.topParties.fold<double>(
      0,
      (m, p) => p.totalAmount > m ? p.totalAmount : m,
    );
    return [
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 2.0,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        children: [
          ShopKpi(
            title: _isPurchase ? 'جمع کل مبلغ خرید' : 'جمع کل مبلغ فروش',
            value: Fa.number(r.totalAmount),
            unit: 'ریال',
            icon: _isPurchase
                ? Icons.shopping_bag_rounded
                : Icons.shopping_cart_rounded,
            color: _isPurchase ? ShopColors.indigo : ShopColors.ok,
          ),
          ShopKpi(
            title: 'تعداد اسناد',
            value: Fa.number(r.documentCount),
            unit: 'سند',
            icon: Icons.receipt_long_rounded,
            color: ShopColors.seed,
          ),
          ShopKpi(
            title: 'تعداد سطر اقلام',
            value: Fa.number(r.lineCount),
            unit: 'سطر',
            icon: Icons.list_alt_rounded,
            color: ShopColors.teal,
          ),
          ShopKpi(
            title: 'مجموع مقدار',
            value: Fa.number(r.totalQuantity, decimals: 2),
            unit: 'واحد',
            icon: Icons.inventory_rounded,
            color: ShopColors.warn,
          ),
          ShopKpi(
            title: 'میانگین مبلغ هر سند',
            value: Fa.number(r.averageDocumentAmount),
            unit: 'ریال',
            icon: Icons.calculate_rounded,
            color: ShopColors.accent,
          ),
        ],
      ),
      const SizedBox(height: 12),
      // ---------- روند دوره‌ای ----------
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ShopColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'روند دوره‌ای مبلغ اسناد',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (r.trend.isEmpty)
              const Text(
                'در این بازه سندی ثبت نشده است.',
                style: TextStyle(fontSize: 11, color: ShopColors.inkFaint),
              )
            else
              SizedBox(
                height: 140,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final t in r.trend)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              Fa.number(t.documentCount),
                              style: const TextStyle(
                                fontSize: 8,
                                color: ShopColors.inkFaint,
                              ),
                            ),
                            Container(
                              height: maxTrend <= 0
                                  ? 2
                                  : (t.amount / maxTrend) * 100,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _isPurchase
                                    ? ShopColors.indigo
                                    : ShopColors.ok,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            Text(
                              t.label,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: const TextStyle(
                                fontSize: 7.5,
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
      const SizedBox(height: 10),
      // ---------- رتبه‌بندی طرف حساب‌ها ----------
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ShopColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isPurchase ? 'رتبه‌بندی تأمین‌کنندگان' : 'رتبه‌بندی مشتریان',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            if (r.topParties.isEmpty)
              const Text(
                'داده‌ای برای رتبه‌بندی نیست.',
                style: TextStyle(fontSize: 11, color: ShopColors.inkFaint),
              )
            else
              for (var i = 0; i < r.topParties.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${Fa.digits(i + 1)}. ',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: ShopColors.inkFaint,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              r.topParties[i].partyName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${Fa.number(r.topParties[i].documentCount)} سند',
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: ShopColors.inkFaint,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            Fa.number(r.topParties[i].totalAmount),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: ShopColors.seed,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: maxParty <= 0
                              ? 0
                              : r.topParties[i].totalAmount / maxParty,
                          minHeight: 5,
                          backgroundColor: ShopColors.bg,
                          valueColor: AlwaysStoppedAnimation(
                            _isPurchase ? ShopColors.indigo : ShopColors.ok,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    ];
  }

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
