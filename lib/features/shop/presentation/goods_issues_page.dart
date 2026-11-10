// ============================================================
//  بیجک — حوالهٔ تحویل کالا (سند «فقط مقدار»، بدون هیچ مبلغی)
//  آینهٔ صفحهٔ وب: /goods-issues → Pages/Catalog/GoodsIssues.razor
//
//  فهرست: فیلتر مشتری/بازهٔ شمسی/جستجو + عملیات مشاهده/ویرایش/حذف
//          (دکمهٔ «چاپ» وب ساخته نشد — چاپ مرورگر است)
//  فرم:   مشتری* (+ «مشتری جدید» همان‌جا) · تاریخ* · شمارهٔ حواله (خودکار)
//          توضیحات · اقلام با «نام کالای آزاد» و فقط «مقدار» + جمع مقدار
//  حذف:   نیازمند مجوز مستقل GoodsIssues.Delete (مثل وب)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/fa_num.dart';
import '../data/shop_perms.dart';
import '../data/shop_repository.dart';
import '../models/ops_models.dart';
import '../models/shop_models.dart';
import 'party_form_page.dart';
import 'shop_style.dart';

class GoodsIssuesPage extends StatefulWidget {
  const GoodsIssuesPage({super.key});

  @override
  State<GoodsIssuesPage> createState() => _GoodsIssuesPageState();
}

/// سطر قابل ویرایش فرم حواله
class _GiLine {
  _GiLine() : name = '', qty = '';
  int id = 0;
  String name;
  String qty;
  double get qtyValue => parseNum(qty);
}

class _GoodsIssuesPageState extends State<GoodsIssuesPage> {
  late final ShopRepository _repo;
  late final ShopPerms _perms;

  List<GoodsIssue> _items = const [];
  List<Party> _parties = const [];
  bool _loading = true;
  String? _error;

  int? _partyId;
  DateTime? _from;
  DateTime? _to;
  final _search = TextEditingController();

  /// حذف حواله نیازمند مجوز مستقل است (مثل وب)
  bool get _canDelete => _perms.has('GoodsIssues.Delete');

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _perms = ShopPerms(context.read<AuthController>().session);
    _loadLookups();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    List<Party> parties = const [];
    try {
      parties = (await _repo.parties(
        type: PartyType.customer,
        take: 1000,
      )).items.where((p) => p.isActive).toList();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _parties = parties);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.goodsIssues(
        partyId: _partyId,
        from: _from,
        to: _to,
        search: _search.text,
      );
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

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showJalaliDatePicker(
      context,
      initial: isFrom ? _from : _to,
      title: isFrom ? 'از تاریخ' : 'تا تاریخ',
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

  Future<void> _openForm({GoodsIssue? source, bool viewOnly = false}) async {
    GoodsIssue? full = source;
    if (source != null) {
      try {
        full = await _repo.goodsIssue(source.id) ?? source;
      } catch (_) {}
    }
    if (!mounted) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _GoodsIssueFormPage(
          repo: _repo,
          parties: _parties,
          source: full,
          viewOnly: viewOnly,
          onPartiesChanged: _loadLookups,
        ),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _delete(GoodsIssue g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(
          'آیا از حذف سند «${g.number}» مطمئن هستید؟',
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
      await _repo.deleteGoodsIssue(g.id);
      _toast('حواله حذف شد.', ok: true);
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
                title: 'بیجک',
                subtitle: 'ثبت خروج کالا به مشتری — فقط مقدار، بدون قیمت',
                icon: Icons.local_shipping_rounded,
                badge: '${Fa.number(_items.length)} حواله',
                actions: [
                  ShopHeaderButton(
                    label: 'حواله جدید',
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
                      DropdownButtonFormField<int?>(
                        initialValue: _partyId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'مشتری',
                          labelStyle: TextStyle(fontSize: 11.5),
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: ShopColors.ink,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('همه مشتری‌ها'),
                          ),
                          for (final p in _parties)
                            DropdownMenuItem<int?>(
                              value: p.id,
                              child: Text(p.name),
                            ),
                        ],
                        onChanged: (v) => setState(() => _partyId = v),
                      ),
                      const SizedBox(height: 8),
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
                      TextField(
                        controller: _search,
                        onSubmitted: (_) => _load(),
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'شماره حواله، مشتری یا کالا…',
                          hintStyle: TextStyle(
                            fontSize: 11.5,
                            color: ShopColors.inkFaint,
                          ),
                          prefixIcon: Icon(Icons.search_rounded, size: 18),
                        ),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _load,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            backgroundColor: ShopColors.seed,
                          ),
                          icon: const Icon(Icons.filter_alt_rounded, size: 17),
                          label: const Text(
                            'اعمال فیلتر',
                            style: TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // ---------- فهرست ----------
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ShopEmpty(
                  title: 'حواله‌ها دریافت نشد',
                  subtitle: _error,
                  icon: Icons.error_outline_rounded,
                ),
              )
            else if (_items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: ShopEmpty(
                  title: 'حواله‌ای ثبت نشده است',
                  subtitle: 'با دکمهٔ «حواله جدید» اولین بیجک را ثبت کنید.',
                  icon: Icons.local_shipping_rounded,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                sliver: SliverList.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _card(_items[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _card(GoodsIssue g) {
    return Container(
      padding: const EdgeInsets.all(12),
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
              Text(
                g.number,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.seed,
                ),
              ),
              const SizedBox(width: 6),
              ShopTag(
                text: '${Fa.number(g.lineCount)} قلم',
                color: ShopColors.seed,
              ),
              const Spacer(),
              Text(
                Fa.date(g.date?.toIso8601String(), time: false),
                style: const TextStyle(
                  fontSize: 10.5,
                  color: ShopColors.inkFaint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            g.partyName,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            'جمع مقدار: ${Fa.number(g.totalQuantity)}'
            '${(g.description ?? '').trim().isEmpty ? '' : ' — ${g.description}'}',
            style: const TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
          ),
          if (g.lines.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              g.lines
                  .take(3)
                  .map((l) => '${l.productName} × ${Fa.number(l.quantity)}')
                  .join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: ShopColors.inkSoft),
            ),
          ],
          const Divider(height: 12, color: ShopColors.line),
          Row(
            children: [
              _act(
                'مشاهده',
                Icons.visibility_rounded,
                ShopColors.inkSoft,
                () => _openForm(source: g, viewOnly: true),
              ),
              _act(
                'ویرایش',
                Icons.edit_rounded,
                ShopColors.seed,
                () => _openForm(source: g),
              ),
              if (_canDelete)
                _act(
                  'حذف',
                  Icons.delete_outline_rounded,
                  ShopColors.danger,
                  () => _delete(g),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _act(String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: Text(label, style: const TextStyle(fontSize: 11)),
        style: TextButton.styleFrom(foregroundColor: color),
      ),
    );
  }

  Widget _dateBox(
    String label,
    DateTime? value,
    VoidCallback onTap,
    VoidCallback onClear,
  ) {
    return InkWell(
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
                value == null ? label : jalaliShort(value),
                style: TextStyle(
                  fontSize: 11.5,
                  color: value == null ? ShopColors.inkFaint : ShopColors.ink,
                ),
              ),
            ),
            if (value != null)
              InkWell(
                onTap: onClear,
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: ShopColors.inkFaint,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  فرم حواله
// ============================================================
class _GoodsIssueFormPage extends StatefulWidget {
  const _GoodsIssueFormPage({
    required this.repo,
    required this.parties,
    required this.onPartiesChanged,
    this.source,
    this.viewOnly = false,
  });

  final ShopRepository repo;
  final List<Party> parties;
  final Future<void> Function() onPartiesChanged;
  final GoodsIssue? source;
  final bool viewOnly;

  @override
  State<_GoodsIssueFormPage> createState() => _GoodsIssueFormPageState();
}

class _GoodsIssueFormPageState extends State<_GoodsIssueFormPage> {
  bool get _isEdit => (widget.source?.id ?? 0) > 0;

  late List<Party> _parties;
  int _partyId = 0;
  DateTime? _date;
  final _desc = TextEditingController();
  final List<_GiLine> _lines = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _parties = widget.parties;
    final src = widget.source;
    if (src != null) {
      _partyId = src.partyId;
      _date = src.date ?? DateTime.now();
      _desc.text = src.description ?? '';
      _lines.addAll(
        src.lines.map(
          (l) => _GiLine()
            ..id = l.id
            ..name = l.productName
            ..qty = l.quantity.toString().replaceAll(RegExp(r'\.0$'), ''),
        ),
      );
      if (_partyId > 0 && !_parties.any((p) => p.id == _partyId)) {
        _parties = [
          ..._parties,
          Party(id: _partyId, name: src.partyName),
        ];
      }
    } else {
      _date = DateTime.now();
    }
    if (_lines.isEmpty) _lines.add(_GiLine());
  }

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  double get _totalQty => _lines.fold(0, (s, l) => s + l.qtyValue);

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
      title: 'تاریخ حواله',
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  Future<void> _newCustomer() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PartyFormPage(type: PartyType.customer)),
    );
    if (saved != true) return;
    await widget.onPartiesChanged();
    try {
      final list = (await widget.repo.parties(
        type: PartyType.customer,
        take: 1000,
      )).items.where((p) => p.isActive).toList();
      if (!mounted) return;
      setState(() {
        _parties = list;
        final newest = list.isEmpty
            ? null
            : list.reduce((a, b) => a.id > b.id ? a : b);
        if (newest != null) _partyId = newest.id;
      });
      _toastOk('مشتری جدید ثبت و انتخاب شد.');
    } catch (e) {
      _toast(e.toString());
    }
  }

  void _toastOk(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12.5)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ShopColors.ok,
      ),
    );
  }

  Future<void> _save() async {
    // همان اعتبارسنجی‌های وب
    if (_partyId == 0) {
      _toast('مشتری را انتخاب کنید.');
      return;
    }
    if (_date == null) {
      _toast('تاریخ حواله را وارد کنید.');
      return;
    }
    final valid = _lines
        .where((l) => l.name.trim().isNotEmpty && l.qtyValue > 0)
        .toList();
    if (valid.isEmpty) {
      _toast('حداقل یک سطر کالا با نام و مقدار وارد کنید.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repo.saveGoodsIssue({
        'id': widget.source?.id ?? 0,
        'date': _date!.toIso8601String(),
        'partyId': _partyId,
        'description':
            _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        'lines': [
          for (final l in valid)
            {
              'id': l.id,
              'productId': 0,
              'productName': l.name.trim(),
              'quantity': l.qtyValue,
            },
        ],
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final ro = widget.viewOnly;
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: Text(
          ro
              ? 'مشاهده حواله ${widget.source!.number}'
              : _isEdit
              ? 'ویرایش حواله ${widget.source!.number}'
              : 'حواله تحویل کالای جدید',
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        children: [
          Container(
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
                    const Expanded(
                      child: Text(
                        'مشتری',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                    ),
                    if (!ro)
                      GestureDetector(
                        onTap: _newCustomer,
                        child: const Row(
                          children: [
                            Icon(
                              Icons.person_add_alt_1_rounded,
                              size: 14,
                              color: ShopColors.ok,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'مشتری جدید',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: ShopColors.ok,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (ro)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: ShopColors.bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.source!.partyName,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  )
                else
                  DropdownButtonFormField<int>(
                    initialValue: _partyId == 0 ? null : _partyId,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    hint: const Text(
                      'انتخاب مشتری…',
                      style: TextStyle(fontSize: 11.5),
                    ),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: ShopColors.ink,
                    ),
                    items: [
                      for (final p in _parties)
                        DropdownMenuItem<int>(
                          value: p.id,
                          child: Text(
                            (p.mobile ?? '').trim().isEmpty
                                ? p.name
                                : '${p.name} — ${p.mobile}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _partyId = v ?? 0),
                  ),
                const SizedBox(height: 10),
                const Text(
                  'تاریخ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ShopColors.inkFaint,
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: ro ? null : _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: ro ? ShopColors.bg : Colors.white,
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
                        const SizedBox(width: 6),
                        Text(
                          _date == null ? 'انتخاب تاریخ' : jalaliShort(_date!),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'شماره حواله',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ShopColors.inkFaint,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: ShopColors.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _isEdit ? widget.source!.number : 'خودکار',
                    style: const TextStyle(fontSize: 12, color: ShopColors.inkSoft),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'توضیحات',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ShopColors.inkFaint,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _desc,
                  enabled: !ro,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'اختیاری',
                    hintStyle: TextStyle(
                      fontSize: 11.5,
                      color: ShopColors.inkFaint,
                    ),
                  ),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'اقلام حواله',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'نام کالا را آزادانه تایپ کنید؛ فقط مقدار ثبت می‌شود',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: ShopColors.inkFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!ro)
                      TextButton.icon(
                        onPressed: () => setState(() => _lines.add(_GiLine())),
                        icon: const Icon(Icons.add_rounded, size: 15),
                        label: const Text(
                          'سطر تازه',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),
                for (var i = 0; i < _lines.length; i++) _lineRow(i, ro),
                const Divider(height: 14, color: ShopColors.line),
                Row(
                  children: [
                    const Text(
                      'جمع کل مقدار',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: ShopColors.inkSoft,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      Fa.number(_totalQty),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: ShopColors.indigo,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: ShopColors.surface,
            border: Border(top: BorderSide(color: ShopColors.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: ShopColors.inkSoft,
                    side: const BorderSide(color: ShopColors.line),
                  ),
                  child: Text(ro ? 'بستن' : 'انصراف'),
                ),
              ),
              if (!ro) ...[
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: ShopColors.seed,
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: const Text(
                      'ذخیره',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _lineRow(int i, bool ro) {
    final l = _lines[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: ShopColors.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 4),
            child: Text(
              Fa.digits(i + 1),
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: ShopColors.inkFaint,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: TextField(
              controller: TextEditingController(text: l.name)
                ..selection = TextSelection.collapsed(offset: l.name.length),
              enabled: !ro,
              onChanged: (v) => l.name = v,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'نام کالا…',
                hintStyle: TextStyle(fontSize: 11),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextField(
              controller: TextEditingController(text: l.qty)
                ..selection = TextSelection.collapsed(offset: l.qty.length),
              enabled: !ro,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              onChanged: (v) {
                l.qty = v;
                setState(() {});
              },
              decoration: const InputDecoration(isDense: true, hintText: '0'),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (!ro)
            InkWell(
              onTap: () => setState(() {
                _lines.removeAt(i);
                if (_lines.isEmpty) _lines.add(_GiLine());
              }),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 17,
                  color: ShopColors.danger,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
