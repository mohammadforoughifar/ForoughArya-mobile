// ============================================================
//  انبارها
//  آینهٔ صفحهٔ وب: /warehouses → Pages/Catalog/Warehouses.razor
//
//  همان اجزا: ستون‌های نام، آدرس، تلفن، اقلام موجود، وضعیت، ویرایش/حذف ·
//  فرم: نام*، آدرس، تلفن، یادداشت، سوییچ «انبار فعال باشد» ·
//  صفحه‌بندی ۱۲تایی. (وب این صفحه جستجو ندارد و اضافه نشده.)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../data/shop_repository.dart';
import '../models/shop_models.dart';
import 'shop_style.dart';

class WarehousesPage extends StatefulWidget {
  const WarehousesPage({super.key});

  @override
  State<WarehousesPage> createState() => _WarehousesPageState();
}

class _WarehousesPageState extends State<WarehousesPage> {
  late final ShopRepository _repo =
      Provider.of<ShopRepository?>(context, listen: false) ??
      ShopRepository(context.read<ApiClient>());

  static const int pageSize = 12;
  int _page = 1;
  int _total = 0;
  List<Warehouse> _items = const [];
  bool _loading = true;
  String? _error;

  int get _pageCount => _total <= 0 ? 1 : ((_total + pageSize - 1) ~/ pageSize);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _repo.warehouses(
        skip: (_page - 1) * pageSize,
        take: pageSize,
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

  Future<void> _openForm([Warehouse? source]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WarehouseFormSheet(repo: _repo, source: source),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Warehouse w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(
          'آیا از حذف «${w.name}» مطمئن هستید؟',
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
      await _repo.deleteWarehouse(w.id);
      _toast('انبار حذف شد.', ok: true);
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
                title: 'انبارها',
                subtitle: 'تعریف انبارها و مراکز نگهداری کالا',
                icon: Icons.warehouse_rounded,
                badge: '${Fa.number(_total)} انبار',
                actions: [
                  ShopHeaderButton(
                    label: 'انبار جدید',
                    icon: Icons.add_rounded,
                    filled: true,
                    onTap: () => _openForm(),
                  ),
                ],
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
                        title: 'دریافت انبارها انجام نشد',
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
                    icon: Icons.warehouse_outlined,
                    title: 'انباری تعریف نشده است',
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                sliver: SliverList.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (_, i) {
                    final w = _items[i];
                    return Container(
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
                              Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: ShopColors.seed.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: const Icon(
                                  Icons.warehouse_rounded,
                                  size: 18,
                                  color: ShopColors.seed,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            w.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w800,
                                              color: ShopColors.ink,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        ShopTag(
                                          text: w.isActive
                                              ? 'فعال'
                                              : 'غیرفعال',
                                          color: w.isActive
                                              ? ShopColors.ok
                                              : ShopColors.inkFaint,
                                        ),
                                      ],
                                    ),
                                    Text(
                                      (w.address ?? 'بدون آدرس') +
                                          ((w.phone ?? '').isEmpty
                                              ? ''
                                              : ' — ${w.phone}'),
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'اقلام',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: ShopColors.inkFaint,
                                    ),
                                  ),
                                  Text(
                                    Fa.number(w.itemCount),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: ShopColors.seed,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if ((w.note ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                w.note!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: ShopColors.inkFaint,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => _openForm(w),
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: ShopColors.seed,
                                ),
                                label: const Text(
                                  'ویرایش',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: ShopColors.seed,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _delete(w),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: ShopColors.danger,
                                ),
                                label: const Text(
                                  'حذف',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: ShopColors.danger,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
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

class _WarehouseFormSheet extends StatefulWidget {
  const _WarehouseFormSheet({required this.repo, this.source});
  final ShopRepository repo;
  final Warehouse? source;

  @override
  State<_WarehouseFormSheet> createState() => _WarehouseFormSheetState();
}

class _WarehouseFormSheetState extends State<_WarehouseFormSheet> {
  late final _name = TextEditingController(text: widget.source?.name ?? '');
  late final _address = TextEditingController(
    text: widget.source?.address ?? '',
  );
  late final _phone = TextEditingController(text: widget.source?.phone ?? '');
  late final _note = TextEditingController(text: widget.source?.note ?? '');
  late bool _active;
  bool _saving = false;

  bool get _editing => (widget.source?.id ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _active = widget.source?.isActive ?? true;
  }

  @override
  void dispose() {
    for (final c in [_name, _address, _phone, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _toast('نام انبار را وارد کنید.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repo.saveWarehouse(
        Warehouse(
          id: widget.source?.id ?? 0,
          name: _name.text,
          address: _address.text,
          phone: _phone.text,
          note: _note.text,
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
                    _editing ? 'ویرایش انبار' : 'انبار جدید',
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
              label: 'نام انبار',
              required: true,
              child: TextField(
                controller: _name,
                decoration: const InputDecoration(isDense: true),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            ShopField(
              label: 'آدرس',
              child: TextField(
                controller: _address,
                decoration: const InputDecoration(isDense: true),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            ShopField(
              label: 'تلفن',
              child: TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(isDense: true),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            ShopField(
              label: 'یادداشت',
              child: TextField(
                controller: _note,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(isDense: true),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Row(
              children: [
                Switch(
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
                const Text(
                  'انبار فعال باشد',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ShopColors.inkSoft,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
