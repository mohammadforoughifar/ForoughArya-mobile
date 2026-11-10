// ============================================================
//  کارتابل تأیید سفارش‌های ویزیتور — آینهٔ /sales/approvals
//  منبع: Pages/SalesVisit/Approvals.razor
//
//  • هشدار «تخفیف بالای سقف»، «کسری موجودی»، «N بار برگشتی»
//  • جدول اقلام + جمع‌ها + «قابل پرداخت» + روش پرداخت + انبار
//  • تاریخ درخواستی ویزیتور و «تاریخ نهایی تحویل» مدیر با هشدار تفاوت
//  • تأیید و ارسال به مالی (در صورت کسری: گفت‌وگوی تأیید مجدد)
//  • برگشت / رد با دلیل اجباری، ویرایش / تغییر تخفیف، جزئیات و گردش
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
import 'visits_cards.dart';

class VisApprovalsPage extends StatefulWidget {
  const VisApprovalsPage({super.key});

  @override
  State<VisApprovalsPage> createState() => _VisApprovalsPageState();
}

class _VisApprovalsPageState extends State<VisApprovalsPage> {
  late final ShopRepository _repo;

  List<VisApprovalItem> _items = const [];
  bool _loading = true;
  String? _error;

  /// تاریخ نهایی تحویل هر سفارش (با پیش‌فرض تاریخ درخواستی ویزیتور)
  final Map<int, DateTime?> _finalDates = {};
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
      final list = await _repo.visApprovals();
      if (!mounted) return;
      setState(() {
        _items = list;
        for (final it in list) {
          _finalDates.putIfAbsent(
            it.order.id,
            () => it.order.effectiveDeliveryDate,
          );
        }
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

  bool _isChanged(VisOrder o) {
    final f = _finalDates[o.id];
    if (f == null || o.deliveryDate == null) return false;
    return f.year != o.deliveryDate!.year ||
        f.month != o.deliveryDate!.month ||
        f.day != o.deliveryDate!.day;
  }

  Future<void> _pickFinalDate(VisApprovalItem item) async {
    final o = item.order;
    final d = await showJalaliDatePicker(
      context,
      initial: _finalDates[o.id] ?? o.deliveryDate ?? DateTime.now(),
      title: 'تاریخ نهایی تحویل',
    );
    if (d != null) setState(() => _finalDates[o.id] = d);
  }

  Future<void> _approve(VisApprovalItem it) async {
    setState(() => _busy = true);
    try {
      await _repo.visApprove(
        it.order.id,
        finalDeliveryDate: _finalDates[it.order.id],
      );
      if (!mounted) return;
      _toast('سفارش ${it.order.number} تأیید و به کارتابل مالی ارسال شد.', ok: true);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast(_clean(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// تأیید با کسری موجودی → ابتدا مودال تأیید مجدد (عیناً وب)
  Future<void> _tapApprove(VisApprovalItem it) async {
    if (it.stockWarnings.isEmpty) {
      await _approve(it);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'کسری موجودی — ${it.order.number}',
          style: const TextStyle(fontSize: 14),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'موجودی انبار «${it.order.warehouseName}» برای این اقلام کافی نیست:',
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 6),
            for (final w in it.stockWarnings)
              Text(
                '${w.productName} — نیاز ${Fa.number(w.required, decimals: 2)} · '
                'موجودی ${Fa.number(w.available, decimals: 2)}',
                style: const TextStyle(fontSize: 10, color: ShopColors.danger),
              ),
            const SizedBox(height: 6),
            const Text(
              'با تأیید شما، سفارش تأیید و به کارتابل مالی می‌رود؛ تأمین موجودی پیش از ثبت فروش لازم است.',
              style: TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
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
            style: FilledButton.styleFrom(backgroundColor: ShopColors.warn),
            child: const Text('تأیید و ادامه'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await _approve(it);
  }

  Future<void> _sendDecision(VisApprovalItem it, bool isReturn) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isReturn ? 'برگشت برای اصلاح' : 'رد سفارش',
          style: const TextStyle(fontSize: 14),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '— سفارش ${it.order.number}',
              style: const TextStyle(fontSize: 10, color: ShopColors.inkFaint),
            ),
            const SizedBox(height: 6),
            const Text(
              'دلیل (اجباری)',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            TextField(
              controller: ctrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'دلیل برای ویزیتور ارسال می‌شود',
                hintStyle: TextStyle(fontSize: 11),
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
            child: const Text('ثبت'),
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
    setState(() => _busy = true);
    try {
      if (isReturn) {
        await _repo.visReturn(it.order.id, reason);
      } else {
        await _repo.visReject(it.order.id, reason);
      }
      if (!mounted) return;
      _toast('تصمیم ثبت شد.', ok: true);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast(_clean(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDetail(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VisitDetailPage(orderId: id)),
    );
    if (mounted) _load();
  }

  Future<void> _openEdit(int id) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => VisitFormPage(orderId: id)),
    );
    if (ok == true && mounted) _load();
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
          'کارتابل تأیید سفارش‌ها',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'بازخوانی صف',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ShopEmpty(
              title: 'دریافت صف تأیید ناموفق بود',
              subtitle: _error,
              icon: Icons.error_outline_rounded,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
                children: [
                  ShopHeader(
                    title: 'کارتابل تأیید سفارش‌های سرپرست فروش',
                    subtitle:
                        'بررسی هشدارهای کسری موجودی، رعایت سقف تخفیف مجاز و تعیین تاریخ نهایی تحویل',
                    icon: Icons.verified_user_rounded,
                    badge: '${Fa.number(_items.length)} سفارش',
                  ),
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 30),
                      child: ShopEmpty(
                        title: 'صف تأیید خالی است',
                        subtitle: 'سفارش ارسال‌شدهٔ جدیدی وجود ندارد.',
                        icon: Icons.check_circle_outline_rounded,
                      ),
                    )
                  else
                    for (final it in _items) _approvalCard(it),
                ],
              ),
            ),
    );
  }

  Widget _approvalCard(VisApprovalItem it) {
    final o = it.order;
    return Container(
      margin: const EdgeInsets.only(top: 10),
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
              Expanded(
                child: Text(
                  '${o.number} — ${o.partyName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (o.discountOverLimit)
                const ShopTag(
                  text: 'تخفیف بالای سقف',
                  color: ShopColors.danger,
                ),
            ],
          ),
          Text(
            'ویزیتور: ${o.referrerName.isEmpty ? '—' : o.referrerName}'
            '${o.date == null ? '' : ' — ${jalaliShort(o.date!)}'}',
            style: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: [
              if (it.stockWarnings.isNotEmpty)
                const ShopTag(
                  text: 'کسری موجودی',
                  color: ShopColors.warn,
                  icon: Icons.warning_amber_rounded,
                ),
              if (o.returnCount > 0)
                ShopTag(
                  text: '${Fa.number(o.returnCount)} بار برگشتی',
                  color: ShopColors.danger,
                ),
              if (it.creditOverLimit)
                ShopTag(
                  text:
                      'اعتبار مشتری بیش از سقف (${Fa.number(it.customerBalance)} از ${Fa.number(it.creditLimit ?? 0)})',
                  color: ShopColors.danger,
                ),
            ],
          ),
          const SizedBox(height: 8),
          _lines(it),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: ShopColors.bg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              children: [
                _sum('جمع کل', o.totalGross, ShopColors.inkSoft),
                _sum('تخفیف', o.totalDiscount, ShopColors.danger),
                Divider(height: 10, color: ShopColors.line),
                _sum('قابل پرداخت', o.totalNet, ShopColors.seed, bold: true),
                const SizedBox(height: 3),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'پرداخت: ${o.paymentMethodTitle} — انبار: ${o.warehouseName}',
                    style: const TextStyle(
                      fontSize: 9,
                      color: ShopColors.inkFaint,
                    ),
                  ),
                ),
                if ((o.note ?? '').isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'یادداشت ویزیتور: ${o.note}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: ShopColors.indigo.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_shipping_outlined,
                      size: 13,
                      color: ShopColors.inkFaint,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'تاریخ درخواستی ویزیتور',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      o.deliveryDate == null ? '—' : jalaliShort(o.deliveryDate!),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                const Text(
                  'تاریخ نهایی تحویل (قابل تغییر)',
                  style: TextStyle(fontSize: 9.5, color: ShopColors.inkSoft),
                ),
                const SizedBox(height: 3),
                InkWell(
                  onTap: () => _pickFinalDate(it),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: ShopColors.surface,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: ShopColors.line),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.event_rounded,
                          size: 13,
                          color: ShopColors.inkFaint,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _finalDates[o.id] == null
                              ? 'انتخاب تاریخ'
                              : jalaliShort(_finalDates[o.id]!),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isChanged(o)
                      ? 'تاریخ نهایی با تاریخ ویزیتور فرق دارد؛ هر دو تاریخ در سابقه ثبت می‌شود.'
                      : 'مطابق تاریخ ویزیتور — برای تغییر، تاریخ دیگری انتخاب کنید.',
                  style: TextStyle(
                    fontSize: 9,
                    color: _isChanged(o)
                        ? ShopColors.warn
                        : ShopColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          if (it.stockWarnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            _warn(it.stockWarnings),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _tapApprove(it),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                backgroundColor: it.stockWarnings.isEmpty
                    ? ShopColors.seed
                    : ShopColors.warn,
              ),
              icon: const Icon(Icons.verified_rounded, size: 16),
              label: Text(
                it.stockWarnings.isEmpty
                    ? 'تأیید و ارسال به مالی'
                    : 'تأیید و ارسال به مالی (با کسری موجودی)',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _sendDecision(it, true),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    foregroundColor: ShopColors.warn,
                    side: BorderSide(
                      color: ShopColors.warn.withValues(alpha: 0.45),
                    ),
                  ),
                  icon: const Icon(Icons.keyboard_return_rounded, size: 15),
                  label: const Text(
                    'برگشت',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _sendDecision(it, false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    foregroundColor: ShopColors.danger,
                    side: BorderSide(
                      color: ShopColors.danger.withValues(alpha: 0.45),
                    ),
                  ),
                  icon: const Icon(Icons.block_rounded, size: 15),
                  label: const Text('رد', style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _openEdit(o.id),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    foregroundColor: ShopColors.indigo,
                    side: BorderSide(
                      color: ShopColors.indigo.withValues(alpha: 0.4),
                    ),
                  ),
                  icon: const Icon(Icons.edit_note_rounded, size: 15),
                  label: const Text(
                    'ویرایش / تغییر تخفیف',
                    style: TextStyle(fontSize: 10.5),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextButton(
                  onPressed: _busy ? null : () => _openDetail(o.id),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                  ),
                  child: const Text(
                    'جزئیات و گردش',
                    style: TextStyle(fontSize: 10.5, color: ShopColors.seed),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sum(String k, double v, Color c, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(
      children: [
        Text(
          k,
          style: TextStyle(
            fontSize: 9.5,
            color: ShopColors.inkSoft,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          Fa.number(v),
          style: TextStyle(
            fontSize: 10.5,
            color: c,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _lines(VisApprovalItem it) =>
      VisLinesTable(lines: it.order.lines, warnings: it.stockWarnings);

  Widget _warn(List<VisStockWarning> w) => VisStockWarnBox(
    warnings: w,
    note:
        'با تأیید شما، سفارش تأیید و به کارتابل مالی می‌رود؛ تأمین موجودی پیش از ثبت فروش لازم است.',
  );
}
