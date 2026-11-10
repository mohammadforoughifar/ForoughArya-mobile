// ============================================================
//  جزئیات سفارش ویزیتوری
//  آینهٔ صفحهٔ وب: /sales/visits/{Id} → Pages/SalesVisit/VisitDetail.razor
//
//  نمایش: هدر سفارش، تاریخ‌ها (ثبت / درخواستی / نهایی مدیر)، مشتری،
//  انبار، روش پرداخت، سطرها با تخفیف هر سطر، جمع‌ها، گردش کامل،
//  هشدار کسری موجودی و اعتبار مشتری.
//
//  اقدام‌ها (عیناً وب):
//    • ویرایش — پیش‌نویس/ارسال‌شده/برگشتی و با CanCreate یا CanApprove
//    • ارسال برای تأیید — از پیش‌نویس/برگشتی
//    • تأیید / برگشت / رد — فقط مدیر و فقط روی «ارسال‌شده»
//      (برگشت و رد با دلیل اجباری: «دلیل را وارد کنید.»)
//    • ابطال — پیش‌نویس/برگشتی/ارسال‌شده
//    • تأیید مالی (ثبت فروش فروشگاه) — روی «تأییدشده» با CanFinance/CanApprove
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/shop_repository.dart';
import '../models/visit_models.dart';
import 'shop_style.dart';
import 'visit_finance_page.dart';
import 'visit_form_page.dart';

class VisitDetailPage extends StatefulWidget {
  const VisitDetailPage({super.key, required this.orderId});

  final int orderId;

  @override
  State<VisitDetailPage> createState() => _VisitDetailPageState();
}

class _VisitDetailPageState extends State<VisitDetailPage> {
  late final ShopRepository _repo;

  VisActor? _me;
  VisOrder? _order;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _load();
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
      final me = await _repo.visMe();
      final order = await _repo.visOrder(widget.orderId);
      if (order == null) throw Exception('سفارش یافت نشد یا به شما تعلق ندارد.');
      if (!mounted) return;
      setState(() {
        _me = me;
        _order = order;
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

  void _toast(String msg, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        backgroundColor: ok ? ShopColors.ok : null,
      ),
    );
  }

  Future<void> _run(
    Future<VisOrder> Function() action, {
    required String success,
  }) async {
    setState(() => _busy = true);
    try {
      final o = await action();
      if (!mounted) return;
      setState(() => _order = o);
      _toast(success, ok: true);
    } catch (e) {
      if (!mounted) return;
      _toast(_clean(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// همان `DecisionAsync` وب: دلیل اجباری برای برگشت و رد
  Future<void> _decision({required bool isReturn}) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isReturn ? 'برگشت برای اصلاح' : 'رد سفارش',
          style: const TextStyle(fontSize: 15),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'دلیل برای ویزیتور ارسال می‌شود.',
              style: TextStyle(fontSize: 11, color: ShopColors.inkFaint),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 12.5),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'دلیل…',
                hintStyle: TextStyle(fontSize: 11.5),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: isReturn ? ShopColors.warn : ShopColors.danger,
            ),
            child: Text(isReturn ? 'برگشت' : 'رد'),
          ),
        ],
      ),
    );
    final reason = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || !mounted) return;
    if (reason.isEmpty) {
      _toast('دلیل را وارد کنید.');
      return;
    }
    await _run(
      () => isReturn
          ? _repo.visReturn(widget.orderId, reason)
          : _repo.visReject(widget.orderId, reason),
      success: 'تصمیم ثبت شد.',
    );
  }

  /// تأیید مدیر + امکان تعیین تاریخ نهایی تحویل (همان `FinalDeliveryDate` وب)
  Future<void> _approve() async {
    final o = _order!;
    DateTime? finalDate = o.deliveryDate;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('تأیید سفارش', style: TextStyle(fontSize: 15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تاریخ نهایی تحویل را تعیین کنید. اگر تغییر ندهید، تاریخ درخواستی ویزیتور ثبت می‌شود.',
                style: TextStyle(fontSize: 11, color: ShopColors.inkFaint),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  final d = await showJalaliDatePicker(
                    ctx,
                    initial: finalDate ?? DateTime.now(),
                    title: 'تاریخ نهایی تحویل',
                  );
                  if (d != null) setSt(() => finalDate = d);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: ShopColors.line),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_available_rounded,
                        size: 15,
                        color: ShopColors.inkFaint,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        finalDate == null
                            ? 'انتخاب تاریخ'
                            : jalaliShort(finalDate!),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: ShopColors.ok),
              child: const Text('تأیید'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await _run(
      () => _repo.visApprove(widget.orderId, finalDeliveryDate: finalDate),
      success: 'سفارش تأیید شد و به صف مالی رفت.',
    );
  }

  Future<void> _edit() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VisitFormPage(orderId: widget.orderId),
      ),
    );
    if (ok == true && mounted) _load();
  }

  Future<void> _finance() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VisitFinancePage(order: _order!),
      ),
    );
    if (ok == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    final me = _me;
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: Text(
          o == null
              ? 'جزئیات سفارش'
              : 'سفارش ${Fa.number(int.tryParse(o.number) ?? 0)}',
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ShopEmpty(
              title: 'دریافت سفارش ناموفق بود',
              subtitle: _error,
              icon: Icons.error_outline_rounded,
            )
          : o == null || me == null
          ? const SizedBox()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
                children: [
                  if (o.status == VisStatus.returned ||
                      o.status == VisStatus.rejected ||
                      o.status == VisStatus.canceled)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: (o.status == VisStatus.returned
                                ? ShopColors.warn
                                : ShopColors.danger)
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: o.status == VisStatus.returned
                                ? ShopColors.warn
                                : ShopColors.danger,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              o.decisionNote ??
                                  (o.status == VisStatus.returned
                                      ? 'سفارش برای اصلاح به شما برگشت داده شده است.'
                                      : 'این سفارش بسته شده است.'),
                              style: TextStyle(
                                fontSize: 10.5,
                                color: o.status == VisStatus.returned
                                    ? ShopColors.warn
                                    : ShopColors.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _statusCard(o),
                  const SizedBox(height: 10),
                  _infoCard(o),
                  const SizedBox(height: 10),
                  _linesCard(o),
                  if (o.stockWarnings.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _warnCard(o),
                  ],
                  const SizedBox(height: 10),
                  _totalsCard(o),
                  if (o.history.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _historyCard(o),
                  ],
                  const SizedBox(height: 14),
                  _actions(o, me),
                ],
              ),
            ),
    );
  }

  Widget _statusCard(VisOrder o) {
    final color = switch (o.status) {
      VisStatus.draft => ShopColors.inkFaint,
      VisStatus.submitted => ShopColors.warn,
      VisStatus.approved => ShopColors.seed,
      VisStatus.returned || VisStatus.rejected || VisStatus.canceled =>
        ShopColors.danger,
      VisStatus.invoiced || VisStatus.closed => ShopColors.ok,
      _ => ShopColors.inkSoft,
    };
    return Container(
      padding: const EdgeInsets.all(13),
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
              ShopTag(text: o.statusTitle, color: color),
              const Spacer(),
              Text(
                '${Fa.number(o.totalNet)} ریال',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [o.partyName, if ((o.partyMobile ?? '').isNotEmpty) o.partyMobile!]
                .join(' · '),
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            'ثبت: ${o.createdByName}'
            '${o.createdAt == null ? '' : ' · ${jalaliShort(o.createdAt!)}'}',
            style: const TextStyle(fontSize: 10, color: ShopColors.inkFaint),
          ),
          if ((o.invoiceNumber ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ShopTag(
                text: 'شماره فروش: ${Fa.number(o.invoiceNumber!)}',
                color: ShopColors.indigo,
                icon: Icons.receipt_long_rounded,
              ),
            ),
          if (o.discountOverLimit)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: ShopTag(
                text: 'تخفیف بیش از سقف مجاز — نیازمند تأیید ویژه',
                color: ShopColors.danger,
                icon: Icons.warning_amber_rounded,
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoCard(VisOrder o) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      children: [
        _kv('شماره سفارش', Fa.number(int.tryParse(o.number) ?? 0)),
        _kv('تاریخ ثبت سفارش', o.date == null ? '—' : jalaliShort(o.date!)),
        _kv(
          'تاریخ درخواستی تحویل',
          o.deliveryDate == null ? '—' : jalaliShort(o.deliveryDate!),
        ),
        _kv(
          'تاریخ نهایی تحویل',
          o.finalDeliveryDate == null
              ? '—'
              : '${jalaliShort(o.finalDeliveryDate!)}'
                    '${o.finalDateChanged ? '  (تغییر یافته توسط مدیر)' : ''}',
        ),
        _kv('انبار', o.warehouseName),
        _kv('روش پرداخت', o.paymentMethodTitle),
        _kv('ویزیتور مسئول', o.referrerName.isEmpty ? '—' : o.referrerName),
        if ((o.note ?? '').isNotEmpty) _kv('توضیحات', o.note!),
        if ((o.decisionNote ?? '').isNotEmpty)
          _kv('یادداشت تصمیم', o.decisionNote!),
      ],
    ),
  );

  Widget _linesCard(VisOrder o) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'اقلام سفارش (${Fa.number(o.lineCount)} سطر)',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < o.lines.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: ShopColors.bg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${Fa.number(i + 1)}. ${o.lines[i].productName}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      Fa.number(o.lines[i].lineTotal),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${Fa.number(o.lines[i].quantity, decimals: 2)} '
                  '${o.lines[i].unit ?? ''} × '
                  '${Fa.number(o.lines[i].unitPrice)}'
                  ' · تخفیف ${o.lines[i].discountText}',
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: ShopColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _warnCard(VisOrder o) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: ShopColors.warn.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ShopColors.warn.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: ShopColors.warn,
            ),
            SizedBox(width: 6),
            Text(
              'کسری موجودی انبار',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: ShopColors.warn,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final w in o.stockWarnings)
          Text(
            '${w.productName}: نیاز ${Fa.number(w.required, decimals: 2)} · '
            'موجودی ${Fa.number(w.available, decimals: 2)} · '
            'کسری ${Fa.number(w.shortage, decimals: 2)}',
            style: const TextStyle(fontSize: 10, color: ShopColors.inkSoft),
          ),
        const SizedBox(height: 4),
        const Text(
          'تأیید سفارش متوقف شد؛ ابتدا موجودی انبار را تأمین کنید.',
          style: TextStyle(fontSize: 9.5, color: ShopColors.warn),
        ),
      ],
    ),
  );

  Widget _totalsCard(VisOrder o) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: ShopColors.seed,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Row(
          children: [
            const Text(
              'مبلغ خالص',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            Text(
              '${Fa.number(o.totalNet)} ریال',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Expanded(
              child: Text(
                'جمع کل: ${Fa.number(o.totalGross)}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
            Text(
              'تخفیف: ${Fa.number(o.totalDiscount)}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _historyCard(VisOrder o) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'گردش سفارش',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        for (final h in o.history)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: ShopColors.seed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        VisStatus.title(h.toStatus),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        [
                          h.userName,
                          if (h.at != null) jalaliShort(h.at!),
                          if ((h.comment ?? '').isNotEmpty) h.comment!,
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 9.5,
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
  );

  Widget _actions(VisOrder o, VisActor me) {
    final canEdit =
        VisStatus.canEdit(o.status) && (me.canCreate || me.canApprove);
    final canCancel = VisStatus.canCancel(o.status);
    final canSubmit =
        (o.status == VisStatus.draft || o.status == VisStatus.returned) &&
        (me.canCreate || me.isAdmin);
    final canDecide = me.canApprove && o.status == VisStatus.submitted;
    final canFinance =
        (me.canFinance || me.canApprove) && o.status == VisStatus.approved;

    return Column(
      children: [
        if (canFinance)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _finance,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 46),
                backgroundColor: ShopColors.ok,
              ),
              icon: const Icon(Icons.point_of_sale_rounded, size: 17),
              label: const Text(
                'تأیید مالی و ثبت فروش',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        if (canDecide) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _approve,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: ShopColors.ok,
                  ),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text(
                    'تأیید',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _decision(isReturn: true),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: ShopColors.warn,
                    side: BorderSide(
                      color: ShopColors.warn.withValues(alpha: 0.4),
                    ),
                  ),
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  label: const Text(
                    'برگشت',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _decision(isReturn: false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: ShopColors.danger,
                    side: BorderSide(
                      color: ShopColors.danger.withValues(alpha: 0.4),
                    ),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('رد', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
        if (canEdit || canSubmit || canCancel) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (canEdit)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _edit,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: ShopColors.seed,
                      side: BorderSide(
                        color: ShopColors.seed.withValues(alpha: 0.4),
                      ),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text(
                      'ویرایش',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              if (canEdit && (canSubmit || canCancel)) const SizedBox(width: 6),
              if (canSubmit)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => _repo.visSubmit(widget.orderId),
                            success: 'سفارش برای تأیید مدیر فروش ارسال شد.',
                          ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      backgroundColor: ShopColors.seed,
                    ),
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text(
                      'ارسال برای تأیید',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                ),
              if ((canEdit || canSubmit) && canCancel)
                const SizedBox(width: 6),
              if (canCancel)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => _repo.visCancel(
                              widget.orderId,
                              comment: 'ابطال از صفحهٔ سفارش',
                            ),
                            success: 'سفارش ابطال شد.',
                          ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: ShopColors.danger,
                      side: BorderSide(
                        color: ShopColors.danger.withValues(alpha: 0.35),
                      ),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text(
                      'ابطال',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (o.status == VisStatus.submitted && !me.canApprove)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'سفارش در انتظار تأیید مدیر فروش است.',
              style: TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
            ),
          ),
        if (!canEdit && me.canApprove != true && o.status == VisStatus.draft)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'این سفارش در وضعیتی نیست که قابل ویرایش باشد.',
              style: TextStyle(fontSize: 10.5, color: ShopColors.danger),
            ),
          ),
      ],
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.5),
    child: Row(
      children: [
        SizedBox(
          width: 118,
          child: Text(
            k,
            style: const TextStyle(fontSize: 10, color: ShopColors.inkFaint),
          ),
        ),
        Expanded(
          child: Text(
            v.isEmpty ? '—' : v,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ShopColors.ink,
            ),
          ),
        ),
      ],
    ),
  );
}
