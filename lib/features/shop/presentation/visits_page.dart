// ============================================================
//  سفارش‌های من (ویزیتوری)
//  آینهٔ صفحهٔ وب: /sales/visits → Pages/SalesVisit/MyVisits.razor
//
//  • کارت‌های آمار کارتابلی (VisQueueStats)
//  • فیلتر: وضعیت، جستجوی «شماره سفارش، نام مشتری یا ویزیتور»،
//    بازهٔ تاریخ شمسی
//  • ردیف‌ها: شماره، تاریخ ثبت، تاریخ تحویل، مشتری، (ویزیتور مسئول
//    برای مدیر)، مبلغ خالص، وضعیت، شماره فاکتور
//  • دکمهٔ «ثبت سفارش جدید» فقط با SalesVisit.Create (عیناً وب)
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

class VisitsPage extends StatefulWidget {
  const VisitsPage({super.key});

  @override
  State<VisitsPage> createState() => _VisitsPageState();
}

class _VisitsPageState extends State<VisitsPage> {
  late final ShopRepository _repo;

  VisActor? _me;
  VisStats? _stats;
  List<VisOrder> _items = const [];
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await _repo.visMe();
      VisStats? stats;
      List<VisOrder> items = const [];
      try {
        stats = await _repo.visStats();
      } catch (_) {}
      items = await _repo.visOrders(
        status: _status,
        from: _from,
        to: _to,
        search: _searchCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _me = me;
        _stats = stats;
        _items = items;
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

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');

  Future<void> _pick(bool isFrom) async {
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
    _load();
  }

  Future<void> _newOrder() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const VisitFormPage()),
    );
    if (ok == true && mounted) _load();
  }

  Future<void> _openDetail(VisOrder o) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => VisitDetailPage(orderId: o.id)),
    );
    if (changed == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = _me?.canCreate == true || _me?.isAdmin == true;
    final showReferrerCol = _me?.canApprove == true || _me?.isAdmin == true;
    return Scaffold(
      backgroundColor: ShopColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            ShopHeader(
              title: 'سفارش‌های من',
              subtitle: _me?.referrerName.isNotEmpty == true
                  ? 'پروندهٔ ویزیتوری: ${_me!.referrerName}'
                  : 'سفارش‌های میدانی ثبت‌شده',
              icon: Icons.assignment_rounded,
              actions: [
                if (canCreate)
                  ShopHeaderButton(
                    label: 'ثبت سفارش جدید',
                    icon: Icons.add_rounded,
                    filled: true,
                    onTap: _newOrder,
                  ),
              ],
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 70),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 50),
                child: ShopEmpty(
                  title: 'دریافت سفارش‌ها ناموفق بود',
                  subtitle: _error,
                  icon: Icons.error_outline_rounded,
                ),
              )
            else ...[
              if (_stats != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 2.0,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    children: [
                      ShopKpi(
                        title: 'پیش‌نویس',
                        value: Fa.number(_stats!.draft),
                        unit: 'سفارش',
                        icon: Icons.edit_note_rounded,
                        color: ShopColors.inkSoft,
                      ),
                      ShopKpi(
                        title: 'در انتظار تأیید',
                        value: Fa.number(_stats!.submitted),
                        unit: 'سفارش',
                        icon: Icons.hourglass_top_rounded,
                        color: ShopColors.warn,
                      ),
                      ShopKpi(
                        title: 'تأییدشده',
                        value: Fa.number(_stats!.approved),
                        unit: '${Fa.number(_stats!.approvedAmount)} ریال',
                        icon: Icons.verified_rounded,
                        color: ShopColors.ok,
                      ),
                      ShopKpi(
                        title: 'فاکتورشده',
                        value: Fa.number(_stats!.invoiced),
                        unit: '${Fa.number(_stats!.invoicedAmount)} ریال',
                        icon: Icons.receipt_long_rounded,
                        color: ShopColors.seed,
                      ),
                      if (_stats!.commissionEstimate > 0)
                        ShopKpi(
                          title: 'پورسانت تخمینی',
                          value: Fa.number(_stats!.commissionEstimate),
                          unit: 'ریال',
                          icon: Icons.savings_rounded,
                          color: ShopColors.indigo,
                        ),
                      if (_stats!.returned > 0)
                        ShopKpi(
                          title: 'برگشتی برای اصلاح',
                          value: Fa.number(_stats!.returned),
                          unit: 'سفارش',
                          icon: Icons.undo_rounded,
                          color: ShopColors.danger,
                        ),
                    ],
                  ),
                ),
              // ---------- فیلترها ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: ShopColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ShopColors.line),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _load(),
                        style: const TextStyle(fontSize: 12.5),
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'شماره سفارش، نام مشتری یا ویزیتور…',
                          hintStyle: TextStyle(fontSize: 12),
                          prefixIcon: Icon(Icons.search_rounded, size: 18),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int?>(
                        initialValue: _status,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'وضعیت سفارش',
                          labelStyle: TextStyle(fontSize: 10.5),
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: ShopColors.ink,
                        ),
                        items: const [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text('همهٔ وضعیت‌ها'),
                          ),
                          DropdownMenuItem<int?>(
                            value: VisStatus.draft,
                            child: Text('پیش‌نویس'),
                          ),
                          DropdownMenuItem<int?>(
                            value: VisStatus.submitted,
                            child: Text('در انتظار تأیید'),
                          ),
                          DropdownMenuItem<int?>(
                            value: VisStatus.approved,
                            child: Text('تأییدشده'),
                          ),
                          DropdownMenuItem<int?>(
                            value: VisStatus.returned,
                            child: Text('برگشتی برای اصلاح'),
                          ),
                          DropdownMenuItem<int?>(
                            value: VisStatus.invoiced,
                            child: Text('فاکتورشده'),
                          ),
                          DropdownMenuItem<int?>(
                            value: VisStatus.rejected,
                            child: Text('رد‌شده'),
                          ),
                          DropdownMenuItem<int?>(
                            value: VisStatus.canceled,
                            child: Text('ابطال‌شده'),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => _status = v);
                          _load();
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _dateBox(
                              'از تاریخ',
                              _from,
                              () => _pick(true),
                              () {
                                setState(() => _from = null);
                                _load();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _dateBox(
                              'تا تاریخ',
                              _to,
                              () => _pick(false),
                              () {
                                setState(() => _to = null);
                                _load();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: ShopEmpty(
                    title: 'سفارشی یافت نشد',
                    subtitle: 'اولین سفارش میدانی را ثبت کنید.',
                    icon: Icons.assignment_outlined,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Column(
                    children: [
                      for (final o in _items)
                        _orderCard(o, showReferrer: showReferrerCol),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dateBox(
    String label,
    DateTime? value,
    VoidCallback onTap,
    VoidCallback onClear,
  ) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShopColors.line),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_month_rounded,
            size: 14,
            color: ShopColors.inkFaint,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value == null ? label : jalaliShort(value),
              maxLines: 1,
              style: TextStyle(
                fontSize: 10.5,
                color: value == null ? ShopColors.inkFaint : ShopColors.ink,
              ),
            ),
          ),
          if (value != null)
            InkWell(
              onTap: onClear,
              child: const Icon(
                Icons.close_rounded,
                size: 13,
                color: ShopColors.inkFaint,
              ),
            ),
        ],
      ),
    ),
  );

  Widget _orderCard(VisOrder o, {required bool showReferrer}) {
    final color = switch (o.status) {
      VisStatus.draft => ShopColors.inkFaint,
      VisStatus.submitted => ShopColors.warn,
      VisStatus.approved => ShopColors.seed,
      VisStatus.returned => ShopColors.danger,
      VisStatus.rejected || VisStatus.canceled => ShopColors.danger,
      VisStatus.invoiced || VisStatus.closed => ShopColors.ok,
      _ => ShopColors.inkSoft,
    };
    return InkWell(
      onTap: () => _openDetail(o),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border(
            right: BorderSide(color: color, width: 3),
            top: const BorderSide(color: ShopColors.line),
            bottom: const BorderSide(color: ShopColors.line),
            left: const BorderSide(color: ShopColors.line),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'سفارش ${Fa.number(int.tryParse(o.number) ?? 0)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (o.returnCount > 0) ...[
                            const SizedBox(width: 5),
                            ShopTag(
                              text: '${Fa.number(o.returnCount)} بار برگشت',
                              color: ShopColors.danger,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        o.partyName.isEmpty ? '—' : o.partyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: ShopColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Fa.number(o.totalNet),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    const Text(
                      'ریال خالص',
                      style: TextStyle(
                        fontSize: 9,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: ShopColors.bg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Column(
                children: [
                  _kv('تاریخ ثبت', o.date == null ? '—' : jalaliShort(o.date!)),
                  _kv(
                    'تاریخ تحویل',
                    o.deliveryDate == null
                        ? '—'
                        : jalaliShort(o.deliveryDate!),
                  ),
                  if (o.finalDeliveryDate != null)
                    _kv(
                      'تحویل نهایی (مدیر)',
                      '${jalaliShort(o.finalDeliveryDate!)}'
                      '${o.finalDateChanged ? ' ⚠ تغییر یافته' : ''}',
                    ),
                  _kv('روش پرداخت', o.paymentMethodTitle),
                  _kv(
                    'اقلام',
                    '${Fa.number(o.lineCount)} سطر · '
                        '${Fa.number(o.totalQuantity, decimals: 2)} واحد',
                  ),
                  if (showReferrer && o.referrerName.isNotEmpty)
                    _kv('ویزیتور مسئول', o.referrerName),
                  if ((o.invoiceNumber ?? 0) > 0)
                    _kv('شماره فاکتور', Fa.number(o.invoiceNumber!)),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                ShopTag(text: o.statusTitle, color: color),
                if (o.discountOverLimit)
                  const Padding(
                    padding: EdgeInsets.only(right: 5),
                    child: ShopTag(
                      text: 'تخفیف بیش از سقف',
                      color: ShopColors.danger,
                      icon: Icons.warning_amber_rounded,
                    ),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _openDetail(o),
                  icon: const Icon(Icons.chevron_left_rounded, size: 16),
                  label: const Text(
                    'جزئیات',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1.5),
    child: Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            k,
            style: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
          ),
        ),
        Expanded(
          child: Text(
            v,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: ShopColors.inkSoft,
            ),
          ),
        ),
      ],
    ),
  );
}
