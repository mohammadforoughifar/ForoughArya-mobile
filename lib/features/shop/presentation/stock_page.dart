// ============================================================
//  موجودی لحظه‌ای انبارها (و تعدیل انبارگردانی)
//  آینهٔ صفحهٔ وب: /stock → Pages/Catalog/Stock.razor
//
//  همان اجزا:
//    • سربرگ «وضعیت موجودی لحظه‌ای انبارها» + دکمهٔ «اصلاح و تعدیل موجودی»
//    • فیلتر: انتخاب انبار، جستجوی کالا، سوییچ «فقط زیر نقطه سفارش»،
//      دکمهٔ «فیلتر موجودی»
//    • ستون‌ها: کد و نام کالا، گروه، انبار، واحد، موجودی فعلی،
//      میانگین خرید، ارزش کل موجودی (تعداد × میانگین)، نقطه سفارش، وضعیت
//      (زیر نقطه سفارش / ناموجود / مطلوب)
//    • مودال تعدیل: انبار*، کالا*، موجودی شمارش‌شدهٔ جدید*، تاریخ مؤثر
//      (شمسی)، شرح/دلیل — با همان اعتبارسنجی وب
//    • صفحه‌بندی ۱۵تایی (PageSize وب)
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/shop_repository.dart';
import '../models/shop_models.dart';
import 'shop_style.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  late final ShopRepository _repo =
      Provider.of<ShopRepository?>(context, listen: false) ??
      ShopRepository(context.read<ApiClient>());

  static const int pageSize = 15;

  final _searchCtrl = TextEditingController();
  int? _warehouseId;
  bool _below = false;
  int _page = 1;
  int _total = 0;
  List<StockItem> _items = const [];
  bool _loading = true;
  String? _error;

  List<Warehouse> _warehouses = const [];
  List<ShopLookup> _products = const [];

  @override
  void initState() {
    super.initState();
    _loadLookups();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int get _pageCount => _total <= 0 ? 1 : ((_total + pageSize - 1) ~/ pageSize);

  Future<void> _loadLookups() async {
    List<Warehouse> whs = const [];
    List<ShopLookup> prods = const [];
    try {
      whs = (await _repo.warehouses()).items;
    } catch (_) {}
    try {
      prods = await _repo.productLookups();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _warehouses = whs;
      _products = prods;
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _repo.stock(
        warehouseId: _warehouseId,
        search: _searchCtrl.text,
        below: _below,
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

  void _filter() {
    _page = 1;
    _load();
  }

  Future<void> _openAdjust() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdjustSheet(
        repo: _repo,
        warehouses: _warehouses,
        products: _products,
        initialWarehouseId: _warehouseId ?? 0,
      ),
    );
    if (done == true) _load();
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
                title: 'وضعیت موجودی لحظه‌ای انبارها',
                subtitle:
                    'پایش موجودی فیزیکی، ارزش ریالی، هشدار کسری نقطه سفارش و ثبت تعدیل انبارگردانی',
                icon: Icons.inventory_rounded,
                badge: 'کاردکس و انبارداری',
                actions: [
                  ShopHeaderButton(
                    label: 'اصلاح و تعدیل موجودی',
                    icon: Icons.tune_rounded,
                    filled: true,
                    onTap: _openAdjust,
                  ),
                ],
              ),
            ),
            // ---------- نوار فیلتر ----------
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'انتخاب انبار',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                      const SizedBox(height: 4),
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
                      const SizedBox(height: 10),
                      TextField(
                        controller: _searchCtrl,
                        onSubmitted: (_) => _filter(),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'نام یا کد کالا…',
                          hintStyle: const TextStyle(
                            fontSize: 11.5,
                            color: ShopColors.inkFaint,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                        ),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      Row(
                        children: [
                          Switch(
                            value: _below,
                            onChanged: (v) {
                              setState(() => _below = v);
                              _filter();
                            },
                          ),
                          const Expanded(
                            child: Text(
                              'فقط زیر نقطه سفارش',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: ShopColors.danger,
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _filter,
                            style: FilledButton.styleFrom(
                              backgroundColor: ShopColors.seed,
                              minimumSize: const Size(120, 40),
                            ),
                            icon: const Icon(
                              Icons.filter_alt_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              'فیلتر موجودی',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'موجودی اقلام انبار',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: ShopColors.ink,
                        ),
                      ),
                    ),
                    ShopTag(text: '${Fa.number(_total)} ردیف کالا'),
                  ],
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
                        title: 'دریافت موجودی انجام نشد',
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
                    icon: Icons.inventory_outlined,
                    title: 'موجودی برای این انبار ثبت نشده است',
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                sliver: SliverList.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (_, i) => _StockCard(item: _items[i]),
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
}

class _StockCard extends StatelessWidget {
  const _StockCard({required this.item});

  final StockItem item;

  @override
  Widget build(BuildContext context) {
    final s = item;
    final status = s.belowReorder
        ? ('زیر نقطه سفارش', ShopColors.danger)
        : s.quantity == 0
        ? ('ناموجود', ShopColors.inkFaint)
        : ('مطلوب', ShopColors.ok);

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: s.belowReorder
              ? ShopColors.danger.withValues(alpha: 0.35)
              : ShopColors.line,
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
                    Text(
                      s.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: ShopColors.ink,
                      ),
                    ),
                    Text(
                      'کد: ${s.productCode}'
                      '${(s.category ?? '').isEmpty ? '' : '  ·  ${s.category}'}'
                      '${(s.warehouseName ?? '').isEmpty ? '' : '  ·  ${s.warehouseName}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              ShopTag(text: status.$1, color: status.$2),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: ShopColors.bg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _cell(
                      'موجودی فعلی',
                      Fa.number(s.quantity),
                      color: s.belowReorder
                          ? ShopColors.danger
                          : ShopColors.ok,
                      bold: true,
                    ),
                    _cell('واحد', s.unit),
                    _cell(
                      'نقطه سفارش',
                      Fa.number(s.reorderPoint),
                      color: ShopColors.inkFaint,
                    ),
                  ],
                ),
                const Divider(height: 12, color: ShopColors.line),
                Row(
                  children: [
                    _cell('میانگین خرید (ریال)', Fa.number(s.avgCost)),
                    _cell(
                      'ارزش کل موجودی',
                      '${Fa.number(s.totalValue)} ریال',
                      bold: true,
                      color: ShopColors.ink,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(
    String label,
    String value, {
    Color color = ShopColors.inkSoft,
    bool bold = false,
  }) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: bold ? 12.5 : 11.5,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}

// ============================================================
//  مودال «اصلاح موجودی کالا (تعدیل انبارگردانی)»
// ============================================================
class _AdjustSheet extends StatefulWidget {
  const _AdjustSheet({
    required this.repo,
    required this.warehouses,
    required this.products,
    required this.initialWarehouseId,
  });

  final ShopRepository repo;
  final List<Warehouse> warehouses;
  final List<ShopLookup> products;
  final int initialWarehouseId;

  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  late int _warehouseId = widget.initialWarehouseId;
  int _productId = 0;
  final _qty = TextEditingController();
  final _desc = TextEditingController();
  DateTime? _date;
  bool _saving = false;
  String _productQuery = '';

  @override
  void initState() {
    super.initState();
    // وب: تاریخ مؤثر پیش‌فرض امروز است
    _date = DateTime.now();
  }

  @override
  void dispose() {
    _qty.dispose();
    _desc.dispose();
    super.dispose();
  }

  static double _parse(String v) {
    final en = v
        .replaceAll('۰', '0')
        .replaceAll('۱', '1')
        .replaceAll('۲', '2')
        .replaceAll('۳', '3')
        .replaceAll('۴', '4')
        .replaceAll('۵', '5')
        .replaceAll('۶', '6')
        .replaceAll('۷', '7')
        .replaceAll('۸', '8')
        .replaceAll('۹', '9')
        .replaceAll('٬', '')
        .replaceAll('٫', '.')
        .replaceAll(',', '');
    return double.tryParse(en) ?? 0;
  }

  Future<void> _save() async {
    // همان سه اعتبارسنجی وب، با همان متن‌ها
    if (_warehouseId == 0) {
      _toast('انبار را انتخاب کنید.');
      return;
    }
    if (_productId == 0) {
      _toast('کالا را انتخاب کنید.');
      return;
    }
    final qty = _parse(_qty.text);
    if (qty <= 0) {
      _toast('موجودی جدید باید بزرگ‌تر از صفر باشد.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repo.adjustStock(
        warehouseId: _warehouseId,
        productId: _productId,
        quantity: qty,
        date: _date,
        description: _desc.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.toString());
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

  Future<void> _pickDate() async {
    final picked = await showJalaliDatePicker(
      context,
      initial: _date,
      title: 'تاریخ مؤثر سند',
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  List<ShopLookup> get _filteredProducts {
    final q = _productQuery.trim();
    if (q.isEmpty) return const [];
    return widget.products
        .where(
          (p) => p.name.contains(q) || p.id.toString() == q,
        )
        .take(20)
        .toList();
  }

  String get _selectedProductName {
    for (final p in widget.products) {
      if (p.id == _productId) return p.name;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
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
                    'اصلاح موجودی کالا (تعدیل انبارگردانی)',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            ShopField(
              label: 'انبار مقصد',
              required: true,
              child: DropdownButtonFormField<int>(
                initialValue: _warehouseId == 0 ? null : _warehouseId,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                hint: const Text(
                  'انتخاب انبار…',
                  style: TextStyle(fontSize: 11.5),
                ),
                style: const TextStyle(fontSize: 12.5, color: ShopColors.ink),
                items: [
                  for (final w in widget.warehouses)
                    DropdownMenuItem<int>(value: w.id, child: Text(w.name)),
                ],
                onChanged: (v) => setState(() => _warehouseId = v ?? 0),
              ),
            ),
            ShopField(
              label: 'کالای مورد نظر',
              required: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_productId > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: ShopColors.seed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedProductName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: ShopColors.seed,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() {
                              _productId = 0;
                              _productQuery = '';
                            }),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 15,
                              color: ShopColors.seed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextField(
                    onChanged: (v) => setState(() => _productQuery = v),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'جستجوی کالا…',
                      hintStyle: TextStyle(
                        fontSize: 11.5,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  if (_productQuery.trim().isNotEmpty && _productId == 0)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(maxHeight: 170),
                      decoration: BoxDecoration(
                        border: Border.all(color: ShopColors.line),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _filteredProducts.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: Text(
                                'کالایی با این نام پیدا نشد.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: ShopColors.inkFaint,
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _filteredProducts.length,
                              itemBuilder: (_, i) {
                                final p = _filteredProducts[i];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    p.name,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onTap: () => setState(() {
                                    _productId = p.id;
                                    _productQuery = '';
                                  }),
                                );
                              },
                            ),
                    ),
                ],
              ),
            ),
            ShopField(
              label: 'موجودی شمارش‌شده جدید',
              required: true,
              child: TextField(
                controller: _qty,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(isDense: true),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ShopField(
              label: 'تاریخ مؤثر سند',
              child: InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
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
                        Icons.calendar_month_rounded,
                        size: 16,
                        color: ShopColors.inkFaint,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _date == null ? 'انتخاب تاریخ' : jalaliShort(_date!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: ShopColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ShopField(
              label: 'شرح / دلیل اصلاح',
              child: TextField(
                controller: _desc,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'مثلاً: انبارگردانی پایان سال، شکستگی یا مغایرت شمارش',
                  hintStyle: TextStyle(
                    fontSize: 11,
                    color: ShopColors.inkFaint,
                  ),
                ),
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
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
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      backgroundColor: ShopColors.seed,
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 17),
                    label: const Text(
                      'ثبت و اعمال اصلاح',
                      style: TextStyle(fontSize: 12.5),
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
