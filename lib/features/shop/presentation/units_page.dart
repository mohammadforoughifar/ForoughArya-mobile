// ============================================================
//  واحدهای شمارش
//  آینهٔ صفحهٔ وب: /units → Pages/Catalog/Units.razor
//
//  همان اجزا: جستجوی نام واحد، چک‌باکس «فقط فعال‌ها»، تعداد واحد،
//  ستون‌های نام، تعداد کالا، تاریخ ایجاد، وضعیت، ویرایش/حذف ·
//  فرم: نام* و وضعیت · صفحه‌بندی ۱۲تایی
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../data/shop_repository.dart';
import '../models/shop_models.dart';
import 'shop_style.dart';

class UnitsPage extends StatefulWidget {
  const UnitsPage({super.key});

  @override
  State<UnitsPage> createState() => _UnitsPageState();
}

class _UnitsPageState extends State<UnitsPage> {
  late final ShopRepository _repo =
      Provider.of<ShopRepository?>(context, listen: false) ??
      ShopRepository(context.read<ApiClient>());

  static const int pageSize = 12;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _activeOnly = false;
  int _page = 1;
  int _total = 0;
  List<MeasureUnit> _items = const [];
  bool _loading = true;
  String? _error;

  int get _pageCount => _total <= 0 ? 1 : ((_total + pageSize - 1) ~/ pageSize);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _repo.units(
        activeOnly: _activeOnly,
        search: _searchCtrl.text,
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

  Future<void> _openForm([MeasureUnit? source]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UnitFormSheet(repo: _repo, source: source),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(MeasureUnit u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(
          'آیا از حذف واحد «${u.name}» مطمئن هستید؟',
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
      await _repo.deleteUnit(u.id);
      _toast('واحد شمارش حذف شد.', ok: true);
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
                title: 'واحدهای شمارش',
                subtitle: 'تعریف واحدهای اندازه‌گیری کالا',
                icon: Icons.straighten_rounded,
                badge: '${Fa.number(_total)} واحد',
                actions: [
                  ShopHeaderButton(
                    label: 'واحد جدید',
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
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'جستجوی نام واحد…',
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
                        onChanged: (_) {
                          _debounce?.cancel();
                          _debounce = Timer(const Duration(milliseconds: 400), () {
                            _page = 1;
                            _load();
                          });
                        },
                      ),
                      Row(
                        children: [
                          Switch(
                            value: _activeOnly,
                            onChanged: (v) {
                              setState(() {
                                _activeOnly = v;
                                _page = 1;
                              });
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
                        title: 'دریافت واحدها انجام نشد',
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
                    icon: Icons.straighten_rounded,
                    title: 'واحدی یافت نشد',
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
                    final u = _items[i];
                    return Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: ShopColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ShopColors.line),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: ShopColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(
                              Icons.straighten_rounded,
                              size: 17,
                              color: ShopColors.accent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      u.name,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: ShopColors.ink,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    ShopTag(
                                      text: u.isActive ? 'فعال' : 'غیرفعال',
                                      color: u.isActive
                                          ? ShopColors.ok
                                          : ShopColors.inkFaint,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'کالاها: ${Fa.number(u.productCount)}'
                                  '${u.createdAt == null ? '' : '  ·  ایجاد: ${Fa.date(u.createdAt!.toIso8601String(), time: false)}'}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: ShopColors.inkFaint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _openForm(u),
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: ShopColors.seed,
                            ),
                            tooltip: 'ویرایش',
                          ),
                          IconButton(
                            onPressed: () => _delete(u),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: ShopColors.danger,
                            ),
                            tooltip: 'حذف',
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

class _UnitFormSheet extends StatefulWidget {
  const _UnitFormSheet({required this.repo, this.source});
  final ShopRepository repo;
  final MeasureUnit? source;

  @override
  State<_UnitFormSheet> createState() => _UnitFormSheetState();
}

class _UnitFormSheetState extends State<_UnitFormSheet> {
  late final _name = TextEditingController(text: widget.source?.name ?? '');
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
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _toast('نام واحد را وارد کنید.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repo.saveUnit(
        MeasureUnit(
          id: widget.source?.id ?? 0,
          name: _name.text,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _editing ? 'ویرایش واحد شمارش' : 'واحد شمارش جدید',
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
              label: 'نام واحد',
              required: true,
              child: TextField(
                controller: _name,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'عدد، کیلوگرم، متر…',
                  hintStyle: TextStyle(
                    fontSize: 11.5,
                    color: ShopColors.inkFaint,
                  ),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Row(
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
