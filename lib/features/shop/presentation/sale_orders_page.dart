// ============================================================
//  اسناد فروش / اسناد خرید + پیش‌فاکتورهای فروش (فاز ۲ فروشگاهی کایر)
//  آینهٔ کامل صفحهٔ وب: /orders/{Type} → Pages/Orders/Orders.razor
//
//  امکانات همگام‌سازی‌شده با وب:
//    • سرصفحه «اسناد فروش/خرید» + «پیش‌فاکتور جدید» (فروش) + «فروش/خرید جدید»
//    • تب دوگانه در فروش: «فاکتورهای فروش» و «پیش‌فاکتورهای فروش» (با چاپ و تبدیل به فروش)
//    • فیلترها: از تاریخ، تا تاریخ (شمسی)، انبار، طرف حساب
//    • عملیات کامل هر سند: مشاهده · چاپ (A4/A5/80mm) · کپی فاکتور · ویرایش ·
//      نسیه و سوابق دریافت · برگشت فاکتور چکی · تعیین‌تکلیف بستانکاری مشتری ·
//      ابطال فاکتور چکی · حذف (منطبق با گیت‌های Shop.Sale.* / Shop.Purchase.*)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/shop_perms.dart';
import '../data/shop_repository.dart';
import '../models/order_models.dart';
import '../models/shop_models.dart';
import 'order_form_page.dart';
import 'order_operations_sheets.dart';
import 'shop_invoice_print_sheet.dart';
import 'shop_style.dart';

class SaleOrdersPage extends StatefulWidget {
  const SaleOrdersPage({super.key, this.type = TxnType.sale});

  final int type;

  @override
  State<SaleOrdersPage> createState() => _SaleOrdersPageState();
}

class _SaleOrdersPageState extends State<SaleOrdersPage> {
  late final ShopRepository _repo;
  late final ShopPerms _perms;

  static const int pageSize = 15;

  int _page = 1;
  int _total = 0;
  List<ShopOrder> _items = const [];
  List<SalesProforma> _proformas = const [];
  bool _showProformas = false;
  bool _loading = true;
  String? _error;

  DateTime? _from;
  DateTime? _to;
  int? _warehouseId;
  int? _partyId;

  List<Warehouse> _warehouses = const [];
  List<Party> _parties = const [];
  bool _serverProfitAccess = false;

  bool get _isPurchase => widget.type == TxnType.purchase;
  bool get _canManage =>
      _isPurchase ? _perms.canManagePurchase : _perms.canManageSale;
  bool get _canSeeProfit => _perms.canViewProfit || _serverProfitAccess;

  int get _pageCount => _total <= 0 ? 1 : ((_total + pageSize - 1) ~/ pageSize);

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _perms = ShopPerms(context.read<AuthController>().session);
    _loadLookups();
    _load();
  }

  Future<void> _loadLookups() async {
    List<Warehouse> whs = const [];
    List<Party> parties = const [];
    bool profitAccess = false;
    try {
      whs = await _repo.invoiceWarehouses();
    } catch (_) {
      try {
        whs = (await _repo.warehouses()).items;
      } catch (_) {}
    }
    try {
      parties = await _repo.invoiceParties(
        type: _isPurchase ? PartyType.supplier : PartyType.customer,
      );
    } catch (_) {
      try {
        parties = (await _repo.parties(
          type: _isPurchase ? PartyType.supplier : PartyType.customer,
          take: 500,
        )).items;
      } catch (_) {}
    }
    if (!_isPurchase) {
      profitAccess = await _repo.orderProfitAccess();
    }
    if (!mounted) return;
    setState(() {
      _warehouses = whs;
      _parties = parties;
      _serverProfitAccess = profitAccess;
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _repo.orders(
        type: widget.type,
        from: _from,
        to: _to,
        partyId: _partyId,
        warehouseId: _warehouseId,
        page: _page,
        pageSize: pageSize,
      );
      List<SalesProforma> profs = const [];
      if (!_isPurchase) {
        try {
          profs = await _repo.proformas(
            from: _from,
            to: _to,
            partyId: _partyId,
            warehouseId: _warehouseId,
          );
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _proformas = profs;
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

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showJalaliDatePicker(
      context,
      initial: isFrom ? _from : _to,
      title: isFrom ? 'از تاریخ' : 'تا تاریخ',
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
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

  Future<void> _openForm([ShopOrder? source]) async {
    ShopOrder? full = source;
    if (source != null) {
      try {
        full = await _repo.order(source.id) ?? source;
      } catch (_) {}
    }
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OrderFormPage(type: widget.type, source: full),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _copyOrder(ShopOrder source) async {
    ShopOrder full = source;
    try {
      full = await _repo.order(source.id) ?? source;
    } catch (_) {}
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OrderFormPage(type: widget.type, copyTemplate: full),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _openNewProforma() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const OrderFormPage(
          type: TxnType.sale,
          isProforma: true,
        ),
      ),
    );
    if (saved == true) {
      setState(() => _showProformas = true);
      _load();
    }
  }

  Future<void> _convertProforma(SalesProforma p) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OrderFormPage(
          type: TxnType.sale,
          convertingProforma: p,
        ),
      ),
    );
    if (saved == true) {
      _toast('پیش‌فاکتور به فاکتور فروش تبدیل شد.', ok: true);
      _load();
    }
  }

  Future<void> _printOrder(ShopOrder o, {bool isProforma = false}) async {
    await showShopInvoicePrintSheet(
      context,
      repo: _repo,
      order: o,
      isProforma: isProforma,
    );
  }

  Future<void> _openCreditLedger(ShopOrder o) async {
    final changed = await showOrderCreditSheet(
      context,
      repo: _repo,
      order: o,
      canManage: _canManage,
    );
    if (changed == true) _load();
  }

  Future<void> _openChequeReturn(ShopOrder o) async {
    final changed = await showChequeReturnSheet(
      context,
      repo: _repo,
      order: o,
    );
    if (changed == true) {
      _toast('برگشت کالا ثبت و اعمال شد.', ok: true);
      _load();
    }
  }

  Future<void> _openCreditSettlement(ShopOrder o) async {
    final changed = await showCreditSettlementSheet(
      context,
      repo: _repo,
      order: o,
    );
    if (changed == true) {
      _toast('تسویه بستانکاری مشتری ثبت شد.', ok: true);
      _load();
    }
  }

  Future<void> _cancelChequeOrder(ShopOrder o) async {
    try {
      final done = await confirmChequeCancelDialog(
        context,
        repo: _repo,
        order: o,
      );
      if (done) {
        _toast('فاکتور چکی باطل شد.', ok: true);
        _load();
      }
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _delete(ShopOrder o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(
          'آیا از حذف سند «${o.number}» مطمئن هستید؟ موجودی انبار اصلاح خواهد شد.',
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
      await _repo.deleteOrder(o.id);
      _toast('سند حذف شد.', ok: true);
      _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _view(ShopOrder o) async {
    ShopOrder full = o;
    try {
      full = await _repo.order(o.id) ?? o;
    } catch (_) {}
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailsSheet(
        order: full,
        canSeeProfit: _canSeeProfit,
        onPrint: () {
          Navigator.pop(context);
          _printOrder(full);
        },
      ),
    );
  }

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
                title: _isPurchase ? 'اسناد خرید' : 'اسناد فروش',
                subtitle: _isPurchase
                    ? 'ثبت و مدیریت رسیدهای خرید'
                    : 'ثبت و مدیریت فاکتورها و پیش‌فاکتورهای فروش',
                icon: _isPurchase
                    ? Icons.shopping_bag_rounded
                    : Icons.shopping_cart_rounded,
                badge: '${Fa.number(_total)} سند',
                actions: [
                  if (!_isPurchase && _canManage)
                    ShopHeaderButton(
                      label: 'پیش‌فاکتور',
                      icon: Icons.description_outlined,
                      onTap: _openNewProforma,
                    ),
                  if (_canManage)
                    ShopHeaderButton(
                      label: _isPurchase ? 'خرید جدید' : 'فروش جدید',
                      icon: Icons.add_rounded,
                      filled: true,
                      onTap: () => _openForm(),
                    ),
                ],
              ),
            ),

            // ---------- سوییچر فاکتورها / پیش‌فاکتورهای فروش ----------
            if (!_isPurchase)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                sliver: SliverToBoxAdapter(
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment<bool>(
                        value: false,
                        icon: const Icon(Icons.receipt_long_rounded, size: 17),
                        label: Text(
                          'فاکتورهای فروش (${Fa.number(_total)})',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: const Icon(Icons.description_outlined, size: 17),
                        label: Text(
                          'پیش‌فاکتورها (${Fa.number(_proformas.length)})',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                    selected: {_showProformas},
                    onSelectionChanged: (s) =>
                        setState(() => _showProformas = s.first),
                  ),
                ),
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
                      _label('انبار'),
                      DropdownButtonFormField<int?>(
                        initialValue: _warehouseId,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true),
                        style: const TextStyle(
                          fontSize: 12,
                          color: ShopColors.ink,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('همه انبارها'),
                          ),
                          for (final w in _warehouses)
                            DropdownMenuItem<int?>(
                              value: w.id,
                              child: Text(w.name),
                            ),
                        ],
                        onChanged: (v) => setState(() => _warehouseId = v),
                      ),
                      const SizedBox(height: 8),
                      _label('طرف حساب'),
                      DropdownButtonFormField<int?>(
                        initialValue: _partyId,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true),
                        style: const TextStyle(
                          fontSize: 12,
                          color: ShopColors.ink,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('همه'),
                          ),
                          for (final p in _parties)
                            DropdownMenuItem<int?>(
                              value: p.id,
                              child: Text(p.name),
                            ),
                        ],
                        onChanged: (v) => setState(() => _partyId = v),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            _page = 1;
                            _load();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: ShopColors.seed,
                            minimumSize: const Size(0, 42),
                          ),
                          icon: const Icon(Icons.filter_alt_rounded, size: 16),
                          label: const Text(
                            'اعمال فیلتر',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (_loading)
              const SliverPadding(
                padding: EdgeInsets.symmetric(vertical: 60),
                sliver: SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_error != null)
              SliverPadding(
                padding: const EdgeInsets.all(14),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      ShopEmpty(
                        icon: Icons.wifi_off_rounded,
                        title: 'دریافت اسناد انجام نشد',
                        subtitle: _error,
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('تلاش دوباره'),
                      ),
                    ],
                  ),
                ),
              )
            else if (!_isPurchase && _showProformas)
              _proformas.isEmpty
                  ? const SliverPadding(
                      padding: EdgeInsets.all(14),
                      sliver: SliverToBoxAdapter(
                        child: ShopEmpty(
                          icon: Icons.description_outlined,
                          title: 'پیش‌فاکتوری ثبت نشده است',
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                      sliver: SliverList.separated(
                        itemCount: _proformas.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 9),
                        itemBuilder: (_, i) => _ProformaCard(
                          proforma: _proformas[i],
                          canManage: _canManage,
                          onPrint: () => _printOrder(
                            _proformas[i].toOrder(),
                            isProforma: true,
                          ),
                          onConvert: () => _convertProforma(_proformas[i]),
                        ),
                      ),
                    )
            else if (_items.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.all(14),
                sliver: SliverToBoxAdapter(
                  child: ShopEmpty(
                    icon: Icons.receipt_long_outlined,
                    title: 'سندی ثبت نشده است',
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                sliver: SliverList.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    return _OrderCard(
                      order: item,
                      isPurchase: _isPurchase,
                      canManage: _canManage,
                      canSeeProfit: _canSeeProfit,
                      onView: () => _view(item),
                      onPrint: () => _printOrder(item),
                      onCopy: () => _copyOrder(item),
                      onEdit: () => _openForm(item),
                      onCreditLedger: () => _openCreditLedger(item),
                      onChequeReturn: () => _openChequeReturn(item),
                      onCreditSettlement: () => _openCreditSettlement(item),
                      onChequeCancel: () => _cancelChequeOrder(item),
                      onDelete: () => _delete(item),
                    );
                  },
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                sliver: SliverToBoxAdapter(
                  child: _pageCount <= 1
                      ? const SizedBox.shrink()
                      : Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: ShopColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: ShopColors.line),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: _page > 1
                                    ? () {
                                        setState(() => _page--);
                                        _load();
                                      }
                                    : null,
                                icon: const Icon(Icons.chevron_right_rounded),
                              ),
                              Expanded(
                                child: Text(
                                  'صفحهٔ ${Fa.digits(_page)} از ${Fa.digits(_pageCount)}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: ShopColors.inkSoft,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _page < _pageCount
                                    ? () {
                                        setState(() => _page++);
                                        _load();
                                      }
                                    : null,
                                icon: const Icon(Icons.chevron_left_rounded),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        t,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: ShopColors.inkFaint,
        ),
      ),
    ),
  );

  Widget _dateBox(
    String label,
    DateTime? value,
    VoidCallback onTap,
    VoidCallback onClear,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(label),
      InkWell(
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
                  value == null ? 'همه' : jalaliShort(value),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: value == null
                        ? ShopColors.inkFaint
                        : ShopColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (value != null)
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: ShopColors.inkFaint,
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}

// ============================================================
//  کارت پیش‌فاکتور فروش
// ============================================================
class _ProformaCard extends StatelessWidget {
  const _ProformaCard({
    required this.proforma,
    required this.canManage,
    required this.onPrint,
    required this.onConvert,
  });

  final SalesProforma proforma;
  final bool canManage;
  final VoidCallback onPrint;
  final VoidCallback onConvert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
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
              const Icon(
                Icons.description_outlined,
                size: 16,
                color: ShopColors.teal,
              ),
              const SizedBox(width: 6),
              Text(
                Fa.digits(proforma.number),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.teal,
                ),
              ),
              const Spacer(),
              ShopTag(
                text: proforma.isConverted
                    ? 'تبدیل‌شده به فروش'
                    : 'در انتظار تبدیل',
                color: proforma.isConverted ? ShopColors.ok : ShopColors.warn,
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            proforma.partyName,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: ShopColors.ink,
            ),
          ),
          Text(
            '${Fa.date(proforma.document.date.toIso8601String(), time: false)}'
            ' — ${Fa.number(proforma.document.lines.length)} قلم — ${proforma.warehouseName}',
            style: const TextStyle(fontSize: 10, color: ShopColors.inkFaint),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: ShopColors.bg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                const Text(
                  'مبلغ پیش‌فاکتور',
                  style: TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
                ),
                const Spacer(),
                Text(
                  '${Fa.number(proforma.document.totalAmount)} ریال',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPrint,
                  icon: const Icon(Icons.print_rounded, size: 15),
                  label: const Text('چاپ', style: TextStyle(fontSize: 11.5)),
                ),
              ),
              if (canManage && !proforma.isConverted) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: ShopColors.seed,
                    ),
                    onPressed: onConvert,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: const Text(
                      'تبدیل به فاکتور فروش',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  کارت سند (نمای کارتی موبایل وب با همه عملیات فاز ۲)
// ============================================================
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.isPurchase,
    required this.canManage,
    required this.canSeeProfit,
    required this.onView,
    required this.onPrint,
    required this.onCopy,
    required this.onEdit,
    required this.onCreditLedger,
    required this.onChequeReturn,
    required this.onCreditSettlement,
    required this.onChequeCancel,
    required this.onDelete,
  });

  final ShopOrder order;
  final bool isPurchase;
  final bool canManage;
  final bool canSeeProfit;
  final VoidCallback onView;
  final VoidCallback onPrint;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onCreditLedger;
  final VoidCallback onChequeReturn;
  final VoidCallback onCreditSettlement;
  final VoidCallback onChequeCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final o = order;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: o.isCancelled
              ? ShopColors.danger.withValues(alpha: 0.5)
              : ShopColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                isPurchase
                    ? Icons.shopping_bag_rounded
                    : Icons.shopping_cart_rounded,
                size: 16,
                color: ShopColors.seed,
              ),
              Text(
                Fa.digits(o.number),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.seed,
                ),
              ),
              ShopTag(text: o.payLabel, color: _payColor(o.paymentMethod)),
              if (o.isCancelled)
                const ShopTag(text: 'باطل‌شده', color: ShopColors.danger),
              if (o.returnedGoodsAmount > 0)
                const ShopTag(text: 'دارای مرجوعی', color: ShopColors.warn),
              if (o.availableCustomerCredit > 0)
                ShopTag(
                  text: 'بستانکاری ${Fa.number(o.availableCustomerCredit)}',
                  color: ShopColors.teal,
                ),
              if (o.isSale && canSeeProfit && o.totalProfit != null)
                ShopTag(
                  text: 'سود ${Fa.number(o.totalProfit ?? 0)}',
                  color: (o.totalProfit ?? 0) >= 0
                      ? ShopColors.ok
                      : ShopColors.danger,
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            o.partyName ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: ShopColors.ink,
            ),
          ),
          Text(
            '${Fa.date(o.date?.toIso8601String(), time: false)}'
            ' — ${Fa.number(o.lines.length)} قلم'
            '${(o.warehouseName ?? '').isEmpty ? '' : ' — ${o.warehouseName}'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: ShopColors.inkFaint),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: ShopColors.bg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                const Text(
                  'مبلغ کل',
                  style: TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
                ),
                const Spacer(),
                Text(
                  '${Fa.number(o.totalAmount)} ریال',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _act('مشاهده', Icons.visibility_outlined, ShopColors.seed, onView),
              const SizedBox(width: 5),
              _act('چاپ', Icons.print_outlined, ShopColors.teal, onPrint),
              const SizedBox(width: 5),
              _act(
                'نسیه',
                Icons.account_balance_wallet_outlined,
                ShopColors.warn,
                onCreditLedger,
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: 'سایر عملیات سند',
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 19,
                  color: ShopColors.inkSoft,
                ),
                onSelected: (v) {
                  switch (v) {
                    case 'copy':
                      onCopy();
                    case 'edit':
                      onEdit();
                    case 'chequeReturn':
                      onChequeReturn();
                    case 'creditSettlement':
                      onCreditSettlement();
                    case 'chequeCancel':
                      onChequeCancel();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (_) => [
                  if (canManage)
                    const PopupMenuItem(
                      value: 'copy',
                      child: Text(
                        'کپی به سند جدید',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                  if (canManage && !o.isCancelled)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text(
                        'ویرایش سند',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                  if (canManage &&
                      o.isSale &&
                      o.hasChequeCharge &&
                      !o.isCancelled)
                    const PopupMenuItem(
                      value: 'chequeReturn',
                      child: Text(
                        'برگشت کالا (فاکتور چکی)',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                  if (canManage && o.isSale && o.availableCustomerCredit > 0)
                    const PopupMenuItem(
                      value: 'creditSettlement',
                      child: Text(
                        'تعیین‌تکلیف بستانکاری مشتری',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                  if (canManage &&
                      o.isSale &&
                      o.hasChequeCharge &&
                      !o.isCancelled)
                    const PopupMenuItem(
                      value: 'chequeCancel',
                      child: Text(
                        'ابطال فاکتور چکی',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: ShopColors.danger,
                        ),
                      ),
                    ),
                  if (canManage && o.canDelete)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'حذف سند',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: ShopColors.danger,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _payColor(int m) => switch (m) {
    PayMethod.cash => ShopColors.ok,
    PayMethod.credit => ShopColors.warn,
    PayMethod.cheque => ShopColors.indigo,
    PayMethod.mixed => ShopColors.accent,
    _ => ShopColors.teal,
  };

  Widget _act(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ============================================================
//  جزئیات سند — آینهٔ مودال «جزئیات سند» وب
// ============================================================
class _OrderDetailsSheet extends StatelessWidget {
  const _OrderDetailsSheet({
    required this.order,
    required this.canSeeProfit,
    required this.onPrint,
  });

  final ShopOrder order;
  final bool canSeeProfit;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final vatSum = o.lines.fold<double>(0, (s, l) => s + l.computedVat);
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
                    'جزئیات سند ${Fa.digits(o.number)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onPrint,
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: const Text('چاپ', style: TextStyle(fontSize: 12)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                _kv('شماره سند', Fa.digits(o.number)),
                _kv('تاریخ', Fa.date(o.date?.toIso8601String(), time: false)),
                _kv('طرف حساب', o.partyName ?? '—'),
                _kv('انبار', o.warehouseName ?? '—'),
                if ((o.referrerName ?? '').isNotEmpty)
                  _kv('معرف', o.referrerName!),
                if ((o.cashTrackingNumber ?? '').isNotEmpty)
                  _kv('کد رهگیری', Fa.digits(o.cashTrackingNumber)),
              ],
            ),
            if (o.description.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'توضیحات: ${o.description}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: ShopColors.inkSoft,
                    height: 1.7,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            for (final l in o.lines)
              Container(
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
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  l.productName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: ShopColors.ink,
                                  ),
                                ),
                              ),
                              if (l.isService) ...[
                                const SizedBox(width: 5),
                                const ShopTag(
                                  text: 'خدمات',
                                  color: ShopColors.indigo,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          '${Fa.number(l.total)} ریال',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: ShopColors.seed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 10,
                      children: [
                        _small('واحد', l.unit.isEmpty ? '—' : l.unit),
                        _small('مقدار', Fa.number(l.quantity)),
                        _small('قیمت واحد', Fa.number(l.price)),
                        if (l.discountAmount > 0)
                          _small('تخفیف', Fa.number(l.discountAmount)),
                        if (l.computedVat > 0)
                          _small('ارزش افزوده', Fa.number(l.computedVat)),
                        if (l.returnedQuantity > 0)
                          _small('مرجوعی', Fa.number(l.returnedQuantity)),
                        if (o.isSale && canSeeProfit)
                          _small(
                            'بهای تمام‌شده',
                            l.unitCost == null ? '—' : Fa.number(l.unitCost!),
                          ),
                        if (o.isSale && canSeeProfit)
                          _small(
                            'سود',
                            l.profit == null ? '—' : Fa.number(l.profit!),
                          ),
                        if ((o.commissionAmount ?? 0) > 0)
                          _small(
                            'پورسانت معرف',
                            (l.commission ?? 0) > 0
                                ? Fa.number(l.commission!)
                                : '—',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ShopColors.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  if (vatSum > 0)
                    _line(
                      'جمع ارزش افزوده',
                      '${Fa.number(vatSum)} ریال',
                      ShopColors.teal,
                    ),
                  if (o.chequeIncomeAmount > 0)
                    _line(
                      'مابه‌التفاوت فروش چکی',
                      '${Fa.number(o.chequeIncomeAmount)} ریال',
                      ShopColors.indigo,
                    ),
                  if (o.returnedGoodsAmount > 0)
                    _line(
                      'کالای مرجوعی ثبت‌شده',
                      '- ${Fa.number(o.returnedGoodsAmount)} ریال',
                      ShopColors.danger,
                    ),
                  if (o.isSale && canSeeProfit && o.totalProfit != null)
                    _line(
                      'سود سند',
                      Fa.number(o.totalProfit ?? 0),
                      ShopColors.ok,
                    ),
                  if ((o.commissionAmount ?? 0) > 0) ...[
                    _line(
                      'پورسانت معرف',
                      Fa.number(o.commissionAmount ?? 0),
                      ShopColors.seed,
                    ),
                    if (canSeeProfit)
                      _line(
                        'سود خالص',
                        Fa.number(o.netProfit ?? 0),
                        (o.netProfit ?? 0) >= 0
                            ? ShopColors.ok
                            : ShopColors.danger,
                      ),
                  ],
                  _line(
                    'مبلغ کل',
                    '${Fa.number(o.totalAmount)} ریال',
                    ShopColors.ink,
                    bold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _kv('روش تسویه', o.payLabel),
                if ((o.trsAccountName ?? '').isNotEmpty)
                  _kv('حساب / بانک', o.trsAccountName!),
                if (o.cheques.isNotEmpty)
                  _kv(
                    'چک‌ها',
                    '${Fa.number(o.cheques.length)} فقره'
                        '${o.cheques.any((c) => (c.bankName ?? '').isNotEmpty) ? ' (${o.cheques.where((c) => (c.bankName ?? '').isNotEmpty).map((c) => c.bankName!).toSet().join('، ')})' : ''}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        k,
        style: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
      ),
      Text(
        v,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: ShopColors.ink,
        ),
      ),
    ],
  );

  Widget _small(String k, String v) => Text(
    '$k: $v',
    style: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
  );

  Widget _line(String k, String v, Color c, {bool bold = false}) => Padding(
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
            fontSize: bold ? 13 : 11.5,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: c,
          ),
        ),
      ],
    ),
  );
}
