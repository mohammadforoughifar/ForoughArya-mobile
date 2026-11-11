// ============================================================
//  گروه‌های کالا
//  آینهٔ صفحهٔ وب: /categories → Pages/Catalog/Categories.razor
//
//  همان اجزا: جستجوی نام، چک‌باکس «فقط فعال‌ها»، تعداد گروه،
//  ستون‌های نام (با تورفتگی سلسله‌مراتبی)، شرح، تعداد کالا، تاریخ ایجاد،
//  وضعیت، ویرایش/حذف · فرم: نام*، گروه والد، شرح، وضعیت،
//  تاریخ ایجاد و تعداد کالا (فقط ویرایش) · صفحه‌بندی ۱۲تایی
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../data/shop_repository.dart';
import '../models/shop_models.dart';
import 'shop_style.dart';

class ProductCategoriesPage extends StatefulWidget {
  const ProductCategoriesPage({super.key});

  @override
  State<ProductCategoriesPage> createState() => _ProductCategoriesPageState();
}

class _ProductCategoriesPageState extends State<ProductCategoriesPage> {
  late final ShopRepository _repo =
      Provider.of<ShopRepository?>(context, listen: false) ??
      ShopRepository(context.read<ApiClient>());

  static const int pageSize = 12;
  final _searchCtrl = TextEditingController();
  bool _activeOnly = false;
  int _page = 1;
  List<ProductCategory> _items = const [];
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

  /// همان فیلتر وب: جستجو فقط روی نام، سمت کلاینت
  List<ProductCategory> get _filtered {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return _items;
    return _items.where((c) => c.name.contains(q)).toList();
  }

  int get _pageCount =>
      _filtered.isEmpty ? 1 : ((_filtered.length + pageSize - 1) ~/ pageSize);

  List<ProductCategory> get _paged {
    final start = (_page - 1) * pageSize;
    if (start >= _filtered.length) return const [];
    return _filtered.sublist(
      start,
      (start + pageSize).clamp(0, _filtered.length),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.categories(activeOnly: _activeOnly);
      if (!mounted) return;
      setState(() {
        _items = list;
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

  Future<void> _openForm([ProductCategory? source]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryFormSheet(
        repo: _repo,
        source: source,
        all: _items,
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(ProductCategory c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(
          'آیا از حذف گروه «${c.name}» مطمئن هستید؟',
          style: const TextStyle(fontSize: 12.5, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ShopColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأیید'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteCategory(c.id);
      _toast('گروه کالا حذف شد.', ok: true);
      _load();
    } catch (e) {
      _toast(e.toString());
    }
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
                title: 'گروه‌های کالا',
                subtitle: 'تعریف و مدیریت دسته‌بندی کالاها',
                icon: Icons.sell_rounded,
                badge: '${Fa.number(_filtered.length)} گروه',
                actions: [
                  ShopHeaderButton(
                    label: 'گروه جدید',
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
                        onChanged: (_) => setState(() => _page = 1),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'جستجوی نام گروه…',
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
                            value: _activeOnly,
                            onChanged: (v) {
                              setState(() => _activeOnly = v);
                              _load();
                            },
                          ),
                          const Text(
                            'فقط فعال‌ها',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: ShopColors.inkSoft,
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
                        title: 'دریافت گروه‌ها انجام نشد',
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
            else if (_filtered.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.all(14),
                sliver: SliverToBoxAdapter(
                  child: ShopEmpty(
                    icon: Icons.sell_outlined,
                    title: 'گروهی یافت نشد',
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                sliver: SliverList.separated(
                  itemCount: _paged.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (_, i) {
                    final c = _paged[i];
                    return Container(
                      // تورفتگی گروه‌های فرزند، مثل وب
                      margin: EdgeInsetsDirectional.only(start: c.depth * 14.0),
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: ShopColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ShopColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                c.depth > 0
                                    ? Icons.subdirectory_arrow_left_rounded
                                    : Icons.sell_rounded,
                                size: 16,
                                color: ShopColors.inkFaint,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  c.name,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: ShopColors.ink,
                                  ),
                                ),
                              ),
                              ShopTag(
                                text: c.isActive ? 'فعال' : 'غیرفعال',
                                color: c.isActive
                                    ? ShopColors.ok
                                    : ShopColors.inkFaint,
                              ),
                            ],
                          ),
                          if ((c.description ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                c.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: ShopColors.inkFaint,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ShopTag(
                                text: '${Fa.number(c.productCount)} کالا',
                                color: ShopColors.seed,
                                icon: Icons.inventory_2_outlined,
                              ),
                              if (c.createdAt != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  Fa.date(
                                    c.createdAt!.toIso8601String(),
                                    time: false,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    color: ShopColors.inkFaint,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              IconButton(
                                onPressed: () => _openForm(c),
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: ShopColors.seed,
                                ),
                                tooltip: 'ویرایش',
                              ),
                              IconButton(
                                onPressed: () => _delete(c),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: ShopColors.danger,
                                ),
                                tooltip: 'حذف',
                              ),
                            ],
                          ),
                        ],
                      ),
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
                                    ? () => setState(() => _page--)
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
                                    ? () => setState(() => _page++)
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

class _CategoryFormSheet extends StatefulWidget {
  const _CategoryFormSheet({
    required this.repo,
    this.source,
    required this.all,
  });

  final ShopRepository repo;
  final ProductCategory? source;
  final List<ProductCategory> all;

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  late final _name = TextEditingController(text: widget.source?.name ?? '');
  late final _description = TextEditingController(
    text: widget.source?.description ?? '',
  );
  late bool _active;
  int? _parentId;
  bool _saving = false;

  bool get _editing => (widget.source?.id ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _active = widget.source?.isActive ?? true;
    _parentId = widget.source?.parentId;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _toast('نام گروه را وارد کنید.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repo.saveCategory(
        ProductCategory(
          id: widget.source?.id ?? 0,
          name: _name.text,
          parentId: _parentId,
          description: _description.text,
          isActive: _active,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.toString());
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 12.5)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: ShopColors.danger,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
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
                    _editing ? 'ویرایش گروه کالا' : 'گروه کالای جدید',
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
            ShopField(
              label: 'نام گروه',
              required: true,
              child: TextField(
                controller: _name,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'مثلاً: روغن، فیلتر، لاستیک…',
                  hintStyle: TextStyle(
                    fontSize: 11.5,
                    color: ShopColors.inkFaint,
                  ),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            ShopField(
              label: 'گروه والد',
              child: DropdownButtonFormField<int?>(
                initialValue: _parentId,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                style: const TextStyle(fontSize: 12.5, color: ShopColors.ink),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('— گروه ریشه (بدون والد) —'),
                  ),
                  for (final c in widget.all.where(
                    (x) => x.id != (widget.source?.id ?? 0),
                  ))
                    DropdownMenuItem<int?>(
                      value: c.id,
                      child: Text('${'  ' * c.depth}${c.name}'),
                    ),
                ],
                onChanged: (v) => setState(() => _parentId = v),
              ),
            ),
            ShopField(
              label: 'شرح',
              child: TextField(
                controller: _description,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(isDense: true),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            ShopField(
              label: 'وضعیت',
              child: Row(
                children: [
                  Switch(
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                  ),
                  Text(
                    _active ? 'فعال' : 'غیرفعال',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ShopColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            if (_editing)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'تاریخ ایجاد: ${Fa.date(widget.source?.createdAt?.toIso8601String(), time: false)}'
                  ' — ${Fa.number(widget.source?.productCount ?? 0)} کالا در این گروه',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: ShopColors.inkFaint,
                  ),
                ),
              ),
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
          ],
        ),
      ),
    );
  }
}
