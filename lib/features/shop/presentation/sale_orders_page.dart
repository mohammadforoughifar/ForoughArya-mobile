// ============================================================
//  اسناد فروش / اسناد خرید
//  آینهٔ صفحهٔ وب: /orders/{Type} → Pages/Orders/Orders.razor
//
//  همان اجزا:
//    • سرصفحه «اسناد فروش/خرید» + دکمهٔ «فروش جدید / خرید جدید»
//    • فیلترها: از تاریخ، تا تاریخ (شمسی)، انبار، طرف حساب، «اعمال فیلتر»
//    • ستون‌ها: شماره سند، تاریخ، طرف حساب، انبار، اقلام (تعداد قلم)،
//      مبلغ کل، پرداخت (نشان نقدی/نسیه/چک/ترکیبی/اقساطی)،
//      ستون سود فقط برای فروش و فقط با مجوز Orders.ViewProfit، عملیات
//    • مشاهدهٔ سند (با اقلام، سود/بهای تمام‌شده، پورسانت، روش تسویه،
//      حساب بانکی و چک‌ها) · ویرایش · حذف با متن تأیید وب
//    • صفحه‌بندی ۱۵تایی (PageSize وب)
//  ⚠️ دکمهٔ «چاپ فاکتور/رسید» وب با پنجرهٔ چاپ مرورگر کار می‌کند و در
//     اندروید معادل ندارد؛ ساخته نشد تا چیزی خارج از وب نباشد.
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
  bool _loading = true;
  String? _error;

  DateTime? _from;
  DateTime? _to;
  int? _warehouseId;
  int? _partyId;

  List<Warehouse> _warehouses = const [];
  List<Party> _parties = const [];

  bool get _isPurchase => widget.type == TxnType.purchase;

  /// همان گیت وب: Orders.ViewProfit
  bool get _canSeeProfit => _perms.has('Orders.ViewProfit');

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
    try {
      whs = (await _repo.warehouses()).items;
    } catch (_) {}
    try {
      parties = (await _repo.parties(
        type: _isPurchase ? PartyType.supplier : PartyType.customer,
        take: 500,
      )).items;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _warehouses = whs;
      _parties = parties;
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
        // ویرایش: سند کامل همراه اقلام از سرور (مثل وب)
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

  void _view(ShopOrder o) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailsSheet(order: o, canSeeProfit: _canSeeProfit),
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
                    : 'ثبت و مدیریت فاکتورهای فروش',
                icon: _isPurchase
                    ? Icons.shopping_bag_rounded
                    : Icons.shopping_cart_rounded,
                badge: '${Fa.number(_total)} سند',
                actions: [
                  ShopHeaderButton(
                    label: _isPurchase ? 'خرید جدید' : 'فروش جدید',
                    icon: Icons.add_rounded,
                    filled: true,
                    onTap: () => _openForm(),
                  ),
                ],
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
                          icon: const Icon(
                            Icons.filter_alt_rounded,
                            size: 16,
                          ),
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
                  itemBuilder: (_, i) => _OrderCard(
                    order: _items[i],
                    isPurchase: _isPurchase,
                    canSeeProfit: _canSeeProfit,
                    onView: () => _view(_items[i]),
                    onEdit: () => _openForm(_items[i]),
                    onDelete: () => _delete(_items[i]),
                  ),
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
//  کارت سند (نمای کارتی موبایل وب)
// ============================================================
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.isPurchase,
    required this.canSeeProfit,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final ShopOrder order;
  final bool isPurchase;
  final bool canSeeProfit;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final o = order;
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
              Icon(
                isPurchase
                    ? Icons.shopping_bag_rounded
                    : Icons.shopping_cart_rounded,
                size: 16,
                color: ShopColors.seed,
              ),
              const SizedBox(width: 6),
              Text(
                o.number,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.seed,
                ),
              ),
              const SizedBox(width: 8),
              ShopTag(text: o.payLabel, color: _payColor(o.paymentMethod)),
              const Spacer(),
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
              const SizedBox(width: 6),
              _act('ویرایش', Icons.edit_outlined, ShopColors.indigo, onEdit),
              const SizedBox(width: 6),
              _act(
                'حذف',
                Icons.delete_outline_rounded,
                ShopColors.danger,
                onDelete,
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
  const _OrderDetailsSheet({required this.order, required this.canSeeProfit});

  final ShopOrder order;
  final bool canSeeProfit;

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
                const Expanded(
                  child: Text(
                    'جزئیات سند',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
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
                _kv('شماره سند', o.number),
                _kv('تاریخ', Fa.date(o.date?.toIso8601String(), time: false)),
                _kv('طرف حساب', o.partyName ?? '—'),
                _kv('انبار', o.warehouseName ?? '—'),
                if ((o.referrerName ?? '').isNotEmpty)
                  _kv('معرف', o.referrerName!),
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
                  if (o.isSale && canSeeProfit && o.totalProfit != null)
                    _line('سود سند', Fa.number(o.totalProfit ?? 0), ShopColors.ok),
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
