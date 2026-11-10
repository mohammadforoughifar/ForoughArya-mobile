// ============================================================
//  کالاها (و خدمات)
//  آینهٔ صفحهٔ وب: /products → Pages/Catalog/Products.razor
//
//  همان اجزا:
//    • سرصفحه «کالاها / تعریف کالا، قیمت و نقطه سفارش» + سه دکمهٔ
//      «خروجی اکسل/چاپ فهرستِ» وب حذف شده (چاپ مرورگر است)،
//      «ورود از اکسل» و «کالای جدید»
//    • جستجوی نام/کد/گروه/بارکد + چک‌باکس «فقط زیر نقطه سفارش»
//    • همان ستون‌ها: کد، نام، گروه، انبار، واحد، قیمت خرید، قیمت فروش،
//      موجودی کل، نقطه سفارش، زمان ورود، وضعیت، ویرایش/حذف
//    • فرم: نوع (کالا/خدمات)، نام*، کد، بارکد، گروه، واحد، قیمت خرید،
//      قیمت فروش، نقطه سفارش، حداکثر موجودی، شناسه مالیاتی، وضعیت،
//      انبار اختصاصی، زمان ورود (فقط ویرایش)، توضیحات
//    • ورود گروهی از اکسل با انتخاب انبار مقصد (الزامی) + دانلود فایل نمونه
//    • صفحه‌بندی ۱۲تایی (PageSize وب)
// ============================================================

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/shop_repository.dart';
import '../models/shop_models.dart';
import 'shop_style.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  late final ShopRepository _repo =
      Provider.of<ShopRepository?>(context, listen: false) ??
      ShopRepository(context.read<ApiClient>());

  static const int pageSize = 12;

  final _searchCtrl = TextEditingController();
  bool _below = false;
  int _page = 1;
  int _total = 0;
  List<Product> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int get _pageCount => _total <= 0 ? 1 : ((_total + pageSize - 1) ~/ pageSize);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _repo.products(
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

  void _search() {
    _page = 1;
    _load();
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

  Future<void> _openForm([Product? source]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductFormSheet(repo: _repo, source: source),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Product p) async {
    final ok = await _confirm('آیا از حذف «${p.name}» مطمئن هستید؟');
    if (!ok) return;
    try {
      await _repo.deleteProduct(p.id);
      _toast('کالا حذف شد.', ok: true);
      _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<bool> _confirm(String text) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.7)),
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
    return r == true;
  }

  Future<void> _openImport() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImportSheet(repo: _repo),
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
                title: 'کالاها',
                subtitle: 'تعریف کالا، قیمت و نقطه سفارش',
                icon: Icons.inventory_2_rounded,
                badge: '${Fa.number(_total)} کالا',
                actions: [
                  ShopHeaderButton(
                    label: 'ورود از اکسل',
                    icon: Icons.upload_file_rounded,
                    onTap: _openImport,
                  ),
                  const SizedBox(width: 8),
                  ShopHeaderButton(
                    label: 'کالای جدید',
                    icon: Icons.add_rounded,
                    filled: true,
                    onTap: () => _openForm(),
                  ),
                ],
              ),
            ),
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
                      TextField(
                        controller: _searchCtrl,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'جستجوی نام، کد، گروه یا بارکد…',
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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Switch(
                            value: _below,
                            onChanged: (v) {
                              setState(() => _below = v);
                              _search();
                            },
                          ),
                          const Expanded(
                            child: Text(
                              'فقط زیر نقطه سفارش',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: ShopColors.inkSoft,
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _search,
                            style: FilledButton.styleFrom(
                              backgroundColor: ShopColors.seed,
                              minimumSize: const Size(96, 40),
                            ),
                            icon: const Icon(Icons.filter_alt_rounded, size: 16),
                            label: const Text(
                              'جستجو',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
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
                        title: 'دریافت فهرست کالاها انجام نشد',
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
                    icon: Icons.inventory_2_outlined,
                    title: 'کالایی یافت نشد',
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                sliver: SliverList.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _ProductCard(
                    product: _items[i],
                    onEdit: () => _openForm(_items[i]),
                    onDelete: () => _delete(_items[i]),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                sliver: SliverToBoxAdapter(child: _pager()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pager() {
    if (_pageCount <= 1) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
    );
  }
}

// ============================================================
//  کارت کالا — نمای کارتی موبایل وب (cards-mobile)
// ============================================================
class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final color = p.belowReorder ? ShopColors.danger : ShopColors.seed;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ShopColors.line),
        // نوار رنگی کنار کارت مثل st-ready/st-cancelled وب
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.05), ShopColors.surface],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  p.isService
                      ? Icons.handyman_rounded
                      : Icons.inventory_2_rounded,
                  size: 18,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (p.code.isNotEmpty)
                          Text(
                            p.code,
                            style: const TextStyle(
                              fontSize: 10,
                              color: ShopColors.inkFaint,
                            ),
                          ),
                        if (p.isService) ...[
                          const SizedBox(width: 6),
                          const ShopTag(text: 'خدمات', color: ShopColors.indigo),
                        ],
                        if (!p.isActive) ...[
                          const SizedBox(width: 6),
                          const ShopTag(
                            text: 'غیرفعال',
                            color: ShopColors.inkFaint,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: ShopColors.ink,
                      ),
                    ),
                    Text(
                      [
                        p.category ?? 'بدون گروه',
                        p.unit,
                        if (!p.isService)
                          (p.warehouseName ?? '').isEmpty
                              ? 'همه انبارها'
                              : p.warehouseName!,
                        if (p.isService) 'بدون موجودی انبار',
                      ].join(' — '),
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
            ],
          ),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ShopColors.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.inventory_rounded,
                      size: 13,
                      color: ShopColors.inkFaint,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'موجودی',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      p.isService ? '—' : Fa.number(p.totalStock),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: p.belowReorder
                            ? ShopColors.danger
                            : ShopColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _money('قیمت خرید', p.purchasePrice),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _money('قیمت فروش', p.salePrice, primary: true),
                    ),
                  ],
                ),
                if (!p.isService && p.reorderPoint > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text(
                        'نقطه سفارش',
                        style: TextStyle(
                          fontSize: 10,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        Fa.number(p.reorderPoint),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: ShopColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (p.belowReorder)
                const ShopTag(
                  text: 'زیر نقطه سفارش',
                  color: ShopColors.danger,
                  icon: Icons.warning_amber_rounded,
                )
              else if (!p.isService)
                const ShopTag(
                  text: 'موجود',
                  color: ShopColors.ok,
                  icon: Icons.check_rounded,
                ),
              const Spacer(),
              if (p.createdAt != null)
                Text(
                  jalaliShort(p.createdAt!),
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: ShopColors.inkFaint,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _action('ویرایش', Icons.edit_outlined, ShopColors.seed, onEdit),
              const SizedBox(width: 8),
              _action('حذف', Icons.delete_outline_rounded, ShopColors.danger, onDelete),
            ],
          ),
        ],
      ),
    );
  }

  Widget _money(String label, double value, {bool primary = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: ShopColors.inkFaint),
      ),
      Text(
        '${Fa.number(value)} ریال',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: primary ? FontWeight.w900 : FontWeight.w600,
          color: primary ? ShopColors.seed : ShopColors.ink,
        ),
      ),
    ],
  );

  Widget _action(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}

// ============================================================
//  فرم کالا/خدمت — همان فیلدهای مودال وب
// ============================================================
class _ProductFormSheet extends StatefulWidget {
  const _ProductFormSheet({required this.repo, this.source});

  final ShopRepository repo;
  final Product? source;

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  late final _name = TextEditingController(text: widget.source?.name ?? '');
  late final _code = TextEditingController(text: widget.source?.code ?? '');
  late final _barcode = TextEditingController(text: widget.source?.barcode ?? '');
  late final _taxCode = TextEditingController(text: widget.source?.taxCode ?? '');
  late final _description = TextEditingController(
    text: widget.source?.description ?? '',
  );
  late final _sale = TextEditingController(
    text: widget.source == null ? '' : Fa.number(widget.source!.salePrice),
  );
  late final _purchase = TextEditingController(
    text: widget.source == null ? '' : Fa.number(widget.source!.purchasePrice),
  );
  late final _reorder = TextEditingController(
    text: widget.source == null
        ? ''
        : Fa.number(widget.source!.reorderPoint),
  );
  late final _maxStock = TextEditingController(
    text: widget.source == null ? '' : Fa.number(widget.source!.maxStock),
  );

  late bool _isService;
  late bool _active;
  late String _unit;
  String? _category;
  int? _warehouseId;

  List<ProductCategory> _categories = const [];
  List<MeasureUnit> _units = const [];
  List<Warehouse> _warehouses = const [];
  bool _saving = false;

  bool get _editing => (widget.source?.id ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _isService = widget.source?.isService ?? false;
    _active = widget.source?.isActive ?? true;
    _unit = widget.source?.unit ?? 'عدد';
    _category = widget.source?.category;
    _warehouseId = widget.source?.warehouseId;
    _loadLookups();
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _code,
      _barcode,
      _taxCode,
      _description,
      _sale,
      _purchase,
      _reorder,
      _maxStock,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLookups() async {
    // عدم دسترسی به اطلاعات پایه مانع کار صفحه نمی‌شود (مثل وب)
    List<ProductCategory> cats = const [];
    List<MeasureUnit> units = const [];
    List<Warehouse> whs = const [];
    try {
      cats = await widget.repo.categories(activeOnly: true);
    } catch (_) {}
    try {
      units = (await widget.repo.units(activeOnly: true)).items;
    } catch (_) {}
    try {
      whs = (await widget.repo.warehouses()).items;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _units = units;
      _warehouses = whs;
      // اگر گروه/واحد فعلی در فهرست نبود، انتخاب حفظ شود (رفتار وب)
      if ((_category ?? '').isNotEmpty &&
          !cats.any((c) => c.name == _category)) {
        _categories = [
          ...cats,
          ProductCategory(name: _category!),
        ];
      }
      if (_unit.trim().isEmpty) _unit = 'عدد';
      if (!units.any((u) => u.name == _unit) && units.isNotEmpty) {
        _units = [MeasureUnit(name: _unit), ...units];
      }
    });
  }

  /// همان FormatMoney وب: نرمال‌سازی ارقام فارسی و جداکنندهٔ هزارگان
  static String _formatMoney(String input) {
    final raw = input
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
        .replaceAll('٫', '.')
        .replaceAll(',', '');
    if (raw.trim().isEmpty) return '';
    final parts = raw.split('.');
    final intDigits = parts.first.replaceAll(RegExp(r'[^0-9]'), '');
    final intPart = intDigits.isEmpty ? '0' : intDigits;
    final grouped = Fa.number(num.tryParse(intPart) ?? 0);
    if (parts.length > 1) {
      final frac = parts[1].replaceAll(RegExp(r'[^0-9]'), '');
      return frac.isEmpty ? grouped : '$grouped٫${Fa.digits(frac)}';
    }
    return grouped;
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
    if (_name.text.trim().isEmpty) {
      _toast(_isService ? 'نام خدمت را وارد کنید.' : 'نام کالا را وارد کنید.');
      return;
    }
    double sale = _parse(_sale.text);
    double purchase = _parse(_purchase.text);
    double reorder = _parse(_reorder.text);
    double maxStock = _parse(_maxStock.text);

    if (_isService) {
      // خدمات: فقط نام، کد و قیمت — بقیه پاک می‌شوند (عیناً مثل وب)
      if (sale <= 0) {
        _toast('قیمت خدمات را وارد کنید.');
        return;
      }
      purchase = 0;
      reorder = 0;
      maxStock = 0;
    }

    setState(() => _saving = true);
    final payload = Product(
      id: widget.source?.id ?? 0,
      code: _code.text,
      name: _name.text,
      unit: _isService ? 'خدمت' : _unit,
      category: _isService ? null : _category,
      barcode: _isService ? null : _barcode.text,
      taxCode: _taxCode.text,
      salePrice: sale,
      purchasePrice: purchase,
      reorderPoint: reorder,
      maxStock: maxStock,
      description: _description.text,
      isActive: _active,
      isService: _isService,
      warehouseId: _isService ? null : _warehouseId,
    );
    try {
      await widget.repo.saveProduct(payload);
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

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 11.5, color: ShopColors.inkFaint),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  @override
  Widget build(BuildContext context) {
    final title = _isService
        ? (_editing ? 'ویرایش خدمت' : 'خدمت جدید')
        : (_editing ? 'ویرایش کالا' : 'کالای جدید');
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: ShopColors.line),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                children: [
                  // نوع: کالا / خدمات
                  ShopField(
                    label: 'نوع',
                    hint: 'خدمات موجودی انبار ندارد و فقط در فروش انتخاب می‌شود',
                    child: Row(
                      children: [
                        _radio('کالا', !_isService, () {
                          setState(() => _isService = false);
                        }),
                        const SizedBox(width: 8),
                        _radio('خدمات', _isService, () {
                          setState(() => _isService = true);
                        }),
                      ],
                    ),
                  ),
                  ShopField(
                    label: _isService ? 'نام خدمت' : 'نام کالا',
                    required: true,
                    child: TextField(
                      controller: _name,
                      decoration: _dec('نام'),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  ShopField(
                    label: _isService ? 'کد خدمت' : 'کد کالا',
                    child: TextField(
                      controller: _code,
                      decoration: _dec('خودکار'),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  if (!_isService) ...[
                    ShopField(
                      label: 'بارکد',
                      child: TextField(
                        controller: _barcode,
                        textDirection: TextDirection.ltr,
                        decoration: _dec('بارکد کالا'),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    ShopField(
                      label: 'گروه / دسته‌بندی',
                      child: DropdownButtonFormField<String?>(
                        initialValue: _category,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: ShopColors.ink,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('— بدون گروه —'),
                          ),
                          for (final c in _categories)
                            DropdownMenuItem<String?>(
                              value: c.name,
                              child: Text('${'  ' * c.depth}${c.name}'),
                            ),
                        ],
                        onChanged: (v) => setState(() => _category = v),
                      ),
                    ),
                    ShopField(
                      label: 'واحد شمارش',
                      child: DropdownButtonFormField<String>(
                        initialValue: _unit,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: ShopColors.ink,
                        ),
                        items: [
                          for (final u in _units)
                            DropdownMenuItem<String>(
                              value: u.name,
                              child: Text(u.name),
                            ),
                        ],
                        onChanged: (v) => setState(() => _unit = v ?? 'عدد'),
                      ),
                    ),
                    ShopField(
                      label: 'قیمت خرید (ریال)',
                      child: TextField(
                        controller: _purchase,
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        decoration: _dec('۰'),
                        style: const TextStyle(fontSize: 13),
                        onChanged: (v) {
                          final f = _formatMoney(v);
                          if (f != v) {
                            _purchase.value = TextEditingValue(
                              text: f,
                              selection: TextSelection.collapsed(
                                offset: f.length,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    ShopField(
                      label: 'قیمت فروش (ریال)',
                      child: TextField(
                        controller: _sale,
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        decoration: _dec('۰'),
                        style: const TextStyle(fontSize: 13),
                        onChanged: (v) {
                          final f = _formatMoney(v);
                          if (f != v) {
                            _sale.value = TextEditingValue(
                              text: f,
                              selection: TextSelection.collapsed(
                                offset: f.length,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    ShopField(
                      label: 'نقطه سفارش (حداقل موجودی)',
                      child: TextField(
                        controller: _reorder,
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        decoration: _dec('۰'),
                        style: const TextStyle(fontSize: 13),
                        onChanged: (v) {
                          final f = _formatMoney(v);
                          if (f != v) {
                            _reorder.value = TextEditingValue(
                              text: f,
                              selection: TextSelection.collapsed(
                                offset: f.length,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    ShopField(
                      label: 'حداکثر موجودی مطلوب',
                      child: TextField(
                        controller: _maxStock,
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        decoration: _dec('۰'),
                        style: const TextStyle(fontSize: 13),
                        onChanged: (v) {
                          final f = _formatMoney(v);
                          if (f != v) {
                            _maxStock.value = TextEditingValue(
                              text: f,
                              selection: TextSelection.collapsed(
                                offset: f.length,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ] else
                    ShopField(
                      label: 'قیمت خدمات (ریال)',
                      required: true,
                      child: TextField(
                        controller: _sale,
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        decoration: _dec('۰'),
                        style: const TextStyle(fontSize: 13),
                        onChanged: (v) {
                          final f = _formatMoney(v);
                          if (f != v) {
                            _sale.value = TextEditingValue(
                              text: f,
                              selection: TextSelection.collapsed(
                                offset: f.length,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ShopField(
                    label: _isService ? 'شناسه مالیاتی خدمت' : 'شناسه مالیاتی کالا',
                    hint:
                        'برای استفاده در پیش‌نویس‌های سامانه مودیان؛ شناسه را با مرجع مالیاتی معتبر تطبیق دهید.',
                    child: TextField(
                      controller: _taxCode,
                      maxLength: 20,
                      textDirection: TextDirection.ltr,
                      decoration: _dec('شناسه رسمی کالا/خدمت'),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  ShopField(
                    label: 'وضعیت',
                    child: Row(
                      children: [
                        _radio('فعال', _active, () {
                          setState(() => _active = true);
                        }),
                        const SizedBox(width: 8),
                        _radio('غیرفعال', !_active, () {
                          setState(() => _active = false);
                        }),
                      ],
                    ),
                  ),
                  if (!_isService)
                    ShopField(
                      label: 'انبار اختصاصی',
                      hint:
                          'در صورت انتخاب، این کالا فقط در همان انبار قابل خرید/فروش است',
                      child: DropdownButtonFormField<int?>(
                        initialValue: _warehouseId,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: ShopColors.ink,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('— همه انبارها —'),
                          ),
                          for (final w in _warehouses)
                            DropdownMenuItem<int?>(
                              value: w.id,
                              child: Text(w.name),
                            ),
                        ],
                        onChanged: (v) => setState(() => _warehouseId = v),
                      ),
                    ),
                  if (_editing && widget.source?.createdAt != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'زمان ورود کالا: ${Fa.date(widget.source!.createdAt!.toIso8601String())}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                    ),
                  ShopField(
                    label: 'توضیحات',
                    child: TextField(
                      controller: _description,
                      minLines: 2,
                      maxLines: 4,
                      decoration: _dec('توضیحات'),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: ShopColors.line),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
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
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 46),
                        backgroundColor: ShopColors.seed,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('ذخیره'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _radio(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? ShopColors.seed.withValues(alpha: 0.11)
              : ShopColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? ShopColors.seed.withValues(alpha: 0.4)
                : ShopColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 15,
              color: selected ? ShopColors.seed : ShopColors.inkFaint,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: selected ? ShopColors.seed : ShopColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  ورود کالا از اکسل — همان منطق وب (انبار مقصد الزامی)
// ============================================================
class _ImportSheet extends StatefulWidget {
  const _ImportSheet({required this.repo});
  final ShopRepository repo;

  @override
  State<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<_ImportSheet> {
  List<Warehouse> _warehouses = const [];
  int _warehouseId = 0;
  File? _file;
  bool _importing = false;
  bool _downloadingTemplate = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  Future<void> _loadWarehouses() async {
    try {
      final res = await widget.repo.warehouses();
      if (!mounted) return;
      setState(() => _warehouses = res.items);
    } catch (_) {}
  }

  Future<void> _downloadTemplate() async {
    setState(() => _downloadingTemplate = true);
    try {
      final bytes = await widget.repo.productTemplate();
      if (bytes.isEmpty) {
        _toast('فایل نمونه خالی برگشت.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Products-Template.xlsx');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      // در موبایل، «دانلود» یعنی ذخیره و باز کردن/اشتراک فایل با اکسل
      final share = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text(
            'فایل نمونهٔ اکسل',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'فایل نمونه ذخیره شد. آن را با اکسل باز کنید یا برای رایانه بفرستید.',
            style: TextStyle(fontSize: 12, height: 1.7),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('باز کردن'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('ارسال/اشتراک'),
            ),
          ],
        ),
      );
      if (share == true) {
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
      } else {
        await OpenFilex.open(file.path);
      }
      if (mounted) _toast('فایل نمونهٔ اکسل آماده شد.', ok: true);
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _downloadingTemplate = false);
    }
  }

  Future<void> _pickFile() async {
    try {
      final picked = await FilePicker.pickFiles();
      final path = picked.isEmpty ? null : picked.first.path;
      if (path == null) return;
      if (!path.toLowerCase().endsWith('.xlsx')) {
        _toast('فقط فایل با فرمت xlsx پشتیبانی می‌شود.');
        return;
      }
      setState(() {
        _file = File(path);
        _result = null;
        _error = null;
      });
    } catch (e) {
      _toast('انتخاب فایل انجام نشد: $e');
    }
  }

  Future<void> _doImport() async {
    // همان دو پیام دقیق وب
    if (_warehouseId <= 0) {
      _toast(
        'لطفاً ابتدا انبار موردنظر را انتخاب کنید. ورود اکسل بدون انتخاب انبار امکان‌پذیر نیست.',
      );
      return;
    }
    if (_file == null) {
      _toast('ابتدا فایل اکسل را انتخاب کنید.');
      return;
    }
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final bytes = await _file!.readAsBytes();
      final res = await widget.repo.importProducts(
        bytes,
        _file!.uri.pathSegments.last,
        warehouseId: _warehouseId,
      );
      if (!mounted) return;
      setState(() => _result = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _toast(String msg, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? ShopColors.ok : ShopColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imported = ( _result?['imported'] as num?)?.toInt() ?? 0;
    final failed = (_result?['failed'] as num?)?.toInt() ?? 0;
    final errors = (_result?['errors'] as List?) ?? const [];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
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
                    'ورود کالا از اکسل',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(_result != null),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ShopColors.seed.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ابتدا فایل اکسل نمونه را بگیرید، کالاها را مطابق آن وارد کرده و سپس فایل را بارگذاری نمایید. گروه یا واحد جدید به‌صورت خودکار در اطلاعات پایه ساخته می‌شود.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.8,
                      color: ShopColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: _downloadingTemplate ? null : _downloadTemplate,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: Text(
                      _downloadingTemplate
                          ? 'در حال دریافت…'
                          : 'دریافت فایل اکسل نمونه',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ShopField(
              label: 'انبار مقصد',
              required: true,
              child: DropdownButtonFormField<int>(
                initialValue: _warehouseId == 0 ? null : _warehouseId,
                isExpanded: true,
                decoration: InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _warehouseId == 0
                          ? ShopColors.danger
                          : ShopColors.line,
                    ),
                  ),
                ),
                hint: const Text(
                  'انتخاب انبار جهت ورود کالاها (الزامی)',
                  style: TextStyle(fontSize: 11.5),
                ),
                style: const TextStyle(fontSize: 12.5, color: ShopColors.ink),
                items: [
                  for (final w in _warehouses)
                    DropdownMenuItem<int>(value: w.id, child: Text(w.name)),
                ],
                onChanged: (v) => setState(() => _warehouseId = v ?? 0),
              ),
            ),
            if (_warehouseId == 0)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'انتخاب انبار برای ورود اکسل الزامی است تا کالاها به تفکیک انبار مدیریت شوند.',
                  style: TextStyle(fontSize: 10, color: ShopColors.danger),
                ),
              ),
            ShopField(
              label: 'فایل اکسل (xlsx)',
              required: true,
              child: GestureDetector(
                onTap: _pickFile,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ShopColors.line),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.attach_file_rounded,
                        size: 16,
                        color: ShopColors.inkFaint,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _file == null
                              ? 'انتخاب فایل اکسل…'
                              : _file!.uri.pathSegments.last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: _file == null
                                ? ShopColors.inkFaint
                                : ShopColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ShopColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: ShopColors.danger,
                    height: 1.7,
                  ),
                ),
              ),
            if (_result != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (failed == 0 ? ShopColors.ok : ShopColors.warn)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${Fa.number(imported)} کالا ثبت شد'
                      '${failed > 0 ? ' — ${Fa.number(failed)} سطر رد شد:' : ''}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: ShopColors.ink,
                      ),
                    ),
                    for (final e in errors.take(8))
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          '• $e',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: ShopColors.inkSoft,
                            height: 1.6,
                          ),
                        ),
                      ),
                    if (errors.length > 8)
                      Text(
                        '… و ${Fa.number(errors.length - 8)} خطای دیگر',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(_result != null),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      foregroundColor: ShopColors.inkSoft,
                      side: const BorderSide(color: ShopColors.line),
                    ),
                    child: const Text('بستن'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _importing ? null : _doImport,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      backgroundColor: ShopColors.seed,
                    ),
                    child: _importing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('بارگذاری و ثبت'),
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
