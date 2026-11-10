// ============================================================
//  کارتابل مالی سفارش‌های ویزیتور — آینهٔ /sales/finance-queue
//  منبع: Pages/SalesVisit/FinanceQueue.razor
//
//  • ۴ شاخص: در انتظار تأیید مالی، منتقل‌شده به فاکتور فروش،
//    مبلغ کل در صف مالی، کل گردش کارتابل
//  • ردیف‌ها: سفارش، تاریخ، تاریخ نهایی تحویل (با هشدار تفاوت)،
//    مشتری، ویزیتور، روش پرداخت، مبلغ، وضعیت، موجودی، شماره فروش
//  • «تأیید مالی و ثبت فروش» روی وضعیت تأییدشده (مودال VisFinanceModal)
//  • «دیدن در فروش» برای فاکتورشده‌ها + «مشاهدهٔ سفارش»
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
import 'visit_finance_page.dart';
import 'visits_cards.dart';

class VisFinanceQueuePage extends StatefulWidget {
  const VisFinanceQueuePage({super.key});

  @override
  State<VisFinanceQueuePage> createState() => _VisFinanceQueuePageState();
}

class _VisFinanceQueuePageState extends State<VisFinanceQueuePage> {
  late final ShopRepository _repo;

  List<VisOrder> _items = const [];
  bool _loading = true;
  String? _error;

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
      final list = await _repo.visFinanceQueue();
      if (!mounted) return;
      setState(() {
        _items = list;
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

  int get _pendingCount =>
      _items.where((o) => o.status == VisStatus.approved).length;

  int get _soldCount =>
      _items.where((o) => o.status == VisStatus.invoiced).length;

  double get _pendingAmount => _items
      .where((o) => o.status == VisStatus.approved)
      .fold<double>(0, (a, o) => a + o.totalNet);

  void _toast(String msg, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        backgroundColor: ok ? ShopColors.ok : null,
      ),
    );
  }

  Future<void> _openFinance(VisOrder o) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => VisitFinancePage(order: o)),
    );
    if (ok == true && mounted) _load();
  }

  Future<void> _syncInvoice(VisOrder o) async {
    try {
      await _repo.visSyncInvoice(o.id);
      if (!mounted) return;
      _toast('وضعیت فاکتور همگام‌سازی شد.', ok: true);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast(_clean(e));
    }
  }

  Future<void> _openDetail(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VisitDetailPage(orderId: id)),
    );
    if (mounted) _load();
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
          'کارتابل مالی سفارش‌ها',
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
              title: 'دریافت صف مالی ناموفق بود',
              subtitle: _error,
              icon: Icons.error_outline_rounded,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
                children: [
                  ShopHeader(
                    title: 'کارتابل مالی و صدور فاکتور سفارش‌های ویزیتور',
                    subtitle:
                        'تأیید شیوه تسویه، تعیین شرایط نقد، چک یا اقساط و تبدیل قطعی سفارش میدانی به سند فروشگاه',
                    icon: Icons.account_balance_wallet_rounded,
                    badge: 'صف مالی',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ShopKpi(
                          title: 'در انتظار تأیید مالی',
                          value: Fa.number(_pendingCount),
                          unit: 'سفارش آماده تسویه',
                          icon: Icons.hourglass_bottom_rounded,
                          color: ShopColors.warn,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ShopKpi(
                          title: 'منتقل‌شده به فاکتور',
                          value: Fa.number(_soldCount),
                          unit: 'فاکتور صادرشده',
                          icon: Icons.check_circle_outline_rounded,
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
                          title: 'مبلغ کل در صف مالی',
                          value: Fa.number(_pendingAmount),
                          unit: 'ریال ناخالص',
                          icon: Icons.payments_rounded,
                          color: ShopColors.indigo,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ShopKpi(
                          title: 'کل گردش کارتابل',
                          value: Fa.number(_items.length),
                          unit: 'ردیف سفارش',
                          icon: Icons.collections_bookmark_rounded,
                          color: ShopColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 30),
                      child: ShopEmpty(
                        title: 'موردی در کارتابل مالی نیست',
                        subtitle:
                            'سفارش تأییدشدهٔ مدیر فروش به‌طور خودکار اینجا می‌آید.',
                        icon: Icons.inbox_rounded,
                      ),
                    )
                  else
                    for (final o in _items) _row(o),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: ShopColors.indigo.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ترتیب کار: ویزیتور سفارش را می‌فرستد ← مدیر فروش تأیید می‌کند '
                      '(سفارش خودکار به این کارتابل می‌آید) ← مالی روش پرداخت را ثبت می‌کند: '
                      'نقدی (سند صندوق/بانک)، چک (ردیف چک‌ها)، اقساطی (دفترچهٔ اقساط) '
                      '← سند فروش در «سامانه فروشگاهی ← فروش» ثبت و سفارش «فروش‌شده» می‌شود.',
                      style: TextStyle(fontSize: 9.5, color: ShopColors.indigo),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _row(VisOrder o) {
    final isApproved = o.status == VisStatus.approved;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'سفارش ${o.number}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              ShopTag(
                text: o.statusTitle,
                color: visStatusColor(o.status),
              ),
              const Spacer(),
              Text(
                Fa.number(o.totalNet),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.seed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${o.partyName} — ویزیتور: ${o.referrerName.isEmpty ? '—' : o.referrerName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: ShopColors.inkSoft),
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: [
              ShopTag(
                text: 'ثبت: ${o.date == null ? '—' : jalaliShort(o.date!)}',
                color: ShopColors.inkFaint,
                icon: Icons.event_rounded,
              ),
              ShopTag(
                text:
                    'تحویل: ${o.finalDeliveryDate != null ? jalaliShort(o.finalDeliveryDate!) : (o.deliveryDate == null ? '—' : jalaliShort(o.deliveryDate!))}',
                color: o.finalDateChanged ? ShopColors.warn : ShopColors.inkFaint,
                icon: Icons.local_shipping_outlined,
              ),
              ShopTag(text: o.paymentMethodTitle, color: ShopColors.inkSoft),
              if (isApproved)
                o.stockWarnings.isEmpty
                    ? const ShopTag(
                        text: 'موجودی تأمین است',
                        color: ShopColors.ok,
                      )
                    : ShopTag(
                        text: 'کسری ${Fa.number(o.stockWarnings.length)} قلم',
                        color: ShopColors.danger,
                        icon: Icons.warning_amber_rounded,
                      ),
              if ((o.invoiceNumber ?? 0) > 0)
                ShopTag(
                  text: 'شماره فروش: ${Fa.number(o.invoiceNumber!)}',
                  color: ShopColors.indigo,
                  icon: Icons.receipt_long_rounded,
                ),
            ],
          ),
          if (isApproved && o.stockWarnings.isNotEmpty) ...[
            const SizedBox(height: 7),
            VisStockWarnBox(
              warnings: o.stockWarnings,
              note:
                  'ثبت فروش موجودی را کم می‌کند؛ پیش از تأیید از «خرید» یا «موجودی اول دوره» تأمین کنید.',
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: isApproved
                    ? FilledButton.icon(
                        onPressed: () => _openFinance(o),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          backgroundColor: ShopColors.ok,
                        ),
                        icon: const Icon(Icons.check_circle_outline_rounded,
                            size: 15),
                        label: const Text(
                          'تأیید مالی و ثبت فروش',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => _syncInvoice(o),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          foregroundColor: ShopColors.indigo,
                          side: BorderSide(
                            color: ShopColors.indigo.withValues(alpha: 0.4),
                          ),
                        ),
                        icon: const Icon(Icons.sync_rounded, size: 15),
                        label: const Text(
                          'دیدن در فروش',
                          style: TextStyle(fontSize: 10.5),
                        ),
                      ),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () => _openDetail(o.id),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 42),
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(
                  Icons.visibility_outlined,
                  size: 16,
                  color: ShopColors.inkSoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
