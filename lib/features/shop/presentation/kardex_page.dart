// ============================================================
//  کاردکس کالا (تعدادی و ریالی) — آینهٔ وب:
//    Pages/Reports/Kardex.razor            → /operations/reports/kardex-quantity
//    Pages/Warehousing/InvKardex.razor     → /operations/reports/kardex-rial
//
//  گیت وب: `ReportPages.Kardex` → پیام «شما به «گزارش کاردکس کالا»
//  دسترسی ندارید…»
//
//  مشترک: انتخاب کالا (الزامی)، انبار، از/تا تاریخ شمسی.
//  • نمای تعدادی: کاردکس خط‌به‌خط با وارده/صادره/مانده، نوع سند
//    (خرید / فروش / اصلاح موجودی) و صفحه‌بندی ۱۵تایی
//  • نمای ریالی: ۴ شاخص (مانده ابتدا/وارده/صادره/مانده انتها با ارزش دفتری)
//    + جدول فی و مبلغ و میانگین فی + روش قیمت‌گذاری
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/shop_perms.dart';
import '../data/shop_repository.dart';
import '../models/report_models.dart';
import '../models/shop_models.dart';
import 'shop_style.dart';

class KardexPage extends StatefulWidget {
  const KardexPage({super.key, this.rial = false});

  /// false = کاردکس تعدادی (وب: kardex-quantity) · true = ریالی (kardex-rial)
  final bool rial;

  @override
  State<KardexPage> createState() => _KardexPageState();
}

class _KardexPageState extends State<KardexPage> {
  late final ShopRepository _repo;
  late final ShopPerms _perms;

  List<ShopLookup> _products = const [];
  List<ShopLookup> _warehouses = const [];

  int _productId = 0;
  int _warehouseId = 0;
  DateTime? _from;
  DateTime? _to;

  KardexQuantityResult? _qty;
  KardexRialResult? _rial;
  bool _loading = false;
  String? _error;
  int _page = 1;
  static const _pageSize = 15;

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _perms = ShopPerms(context.read<AuthController>().session);
    _loadLookups();
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');

  Future<void> _loadLookups() async {
    try {
      final p = await _repo.productLookups();
      final w = await _repo.warehouseLookups();
      if (!mounted) return;
      setState(() {
        _products = p;
        _warehouses = w;
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    if (_productId <= 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.rial) {
        final r = await _repo.kardexRial(
          productId: _productId,
          warehouseId: _warehouseId > 0 ? _warehouseId : null,
          from: _from,
          to: _to,
        );
        if (!mounted) return;
        setState(() {
          _rial = r;
          _loading = false;
          _page = 1;
        });
      } else {
        final rows = await _repo.kardexQuantity(
          productId: _productId,
          warehouseId: _warehouseId > 0 ? _warehouseId : null,
          from: _from,
          to: _to,
        );
        if (!mounted) return;
        setState(() {
          _qty = rows.isEmpty
              ? const KardexQuantityResult(rows: [])
              : KardexQuantityResult(
                  rows: rows,
                  productName: _products
                      .where((p) => p.id == _productId)
                      .map((p) => p.name)
                      .firstOrNull ??
                      '',
                  warehouseName: _warehouses
                      .where((w) => w.id == _warehouseId)
                      .map((w) => w.name)
                      .firstOrNull,
                );
          _loading = false;
          _page = 1;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _clean(e);
        _loading = false;
      });
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showJalaliDatePicker(
      context,
      initial: (isFrom ? _from : _to) ?? DateTime.now(),
      title: isFrom ? 'از تاریخ' : 'تا تاریخ',
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    // همان پیام و گیت وب
    if (!_perms.has('ReportPages.Kardex') &&
        !_perms.canSeeModule('ReportPages')) {
      return Scaffold(
        backgroundColor: ShopColors.bg,
        appBar: AppBar(
          backgroundColor: ShopColors.surface,
          foregroundColor: ShopColors.ink,
          elevation: 0.5,
          title: const Text(
            'کاردکس کالا',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
        ),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: ShopEmpty(
            title: 'دسترسی لازم را ندارید',
            subtitle:
                'شما به «گزارش کاردکس کالا» دسترسی ندارید. برای دریافت دسترسی با مدیر سیستم تماس بگیرید.',
            icon: Icons.shield_outlined,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: Text(
          widget.rial ? 'کاردکس ریالی کالا' : 'کاردکس تعدادی کالا',
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'بازخوانی',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
        children: [
          ShopHeader(
            title: widget.rial
                ? 'کاردکس ریالی و مقداری کالا'
                : 'کاردکس تعدادی کالا',
            subtitle: widget.rial
                ? 'رهگیری گردش ورودی، خروجی، فی تمام‌شده و ارزش دفتری مانده کالا بر پایه اسناد قطعی'
                : 'رهگیری خط‌به‌خط ورودی‌ها، خروجی‌ها، حواله‌ها و مانده فیزیکی کالا در انبار',
            icon: Icons.bar_chart_rounded,
            badge: widget.rial ? 'حسابداری انبار' : 'گردش انبار',
          ),
          const SizedBox(height: 10),
          _filters(),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            ShopEmpty(
              title: 'گزارش دریافت نشد',
              subtitle: _error,
              icon: Icons.error_outline_rounded,
            )
          else if (_productId <= 0)
            ShopEmpty(
              title: widget.rial ? 'کالایی انتخاب نشده است' : 'کالا انتخاب نشده',
              subtitle: widget.rial
                  ? 'جهت استخراج کاردکس، ابتدا کالای مورد نظر را از کادر بالا انتخاب کنید.'
                  : 'برای مشاهدهٔ کاردکس، ابتدا یک کالا از کادر بالا انتخاب کنید',
              icon: Icons.inventory_2_outlined,
            )
          else if (widget.rial)
            _rialBody()
          else
            _qtyBody(),
        ],
      ),
    );
  }

  Widget _filters() => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShopField(
          label: 'انتخاب کالا',
          required: true,
          child: DropdownButtonFormField<int>(
            initialValue: _productId > 0 ? _productId : null,
            isExpanded: true,
            style: const TextStyle(fontSize: 11.5, color: ShopColors.ink),
            decoration: _dec(),
            hint: const Text(
              'انتخاب یا جستجوی کالا…',
              style: TextStyle(fontSize: 11),
            ),
            menuMaxHeight: 340,
            items: [
              for (final p in _products)
                DropdownMenuItem(
                  value: p.id,
                  child: Text(
                    p.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
            onChanged: (v) {
              setState(() => _productId = v ?? 0);
              _load();
            },
          ),
        ),
        const SizedBox(height: 8),
        ShopField(
          label: 'انبار مبدأ/مقصد',
          child: DropdownButtonFormField<int>(
            initialValue: _warehouseId > 0 ? _warehouseId : null,
            isExpanded: true,
            style: const TextStyle(fontSize: 11.5, color: ShopColors.ink),
            decoration: _dec(),
            hint: const Text(
              'همه انبارها',
              style: TextStyle(fontSize: 11),
            ),
            items: [
              for (final w in _warehouses)
                DropdownMenuItem(
                  value: w.id,
                  child: Text(
                    w.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
            onChanged: (v) {
              setState(() => _warehouseId = v ?? 0);
              _load();
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _dateBox('از تاریخ', _from, () => _pickDate(isFrom: true),
                  () {
                setState(() => _from = null);
                _load();
              }),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _dateBox('تا تاریخ', _to, () => _pickDate(isFrom: false),
                  () {
                setState(() => _to = null);
                _load();
              }),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _productId <= 0 || _loading ? null : _load,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor: ShopColors.seed,
            ),
            icon: const Icon(Icons.search_rounded, size: 17),
            label: Text(
              widget.rial ? 'نمایش کاردکس' : 'نمایش کاردکس',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    ),
  );

  // ---------------- کاردکس تعدادی ----------------
  Widget _qtyBody() {
    final r = _qty;
    if (r == null) return const SizedBox();
    if (r.rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 30),
        child: ShopEmpty(
          title: 'گردشی ثبت نشده است',
          subtitle: 'هیچ گردشی برای این کالا در بازهٔ انتخابی ثبت نشده است',
          icon: Icons.inbox_outlined,
        ),
      );
    }
    final count = r.rows.length;
    final pageCount = ((count + _pageSize - 1) ~/ _pageSize).clamp(1, 1 << 30);
    final p = _page.clamp(1, pageCount);
    final start = (p - 1) * _pageSize;
    final rows = r.rows.skip(start).take(_pageSize).toList();

    return Column(
      children: [
        Container(
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
                  const Icon(
                    Icons.inventory_2_rounded,
                    size: 15,
                    color: ShopColors.indigo,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'کاردکس: ${r.productName}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if ((r.warehouseName ?? '').isNotEmpty)
                    ShopTag(text: r.warehouseName!, color: ShopColors.indigo),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'وارده: ${Fa.number(r.totalIn, decimals: 2)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: ShopColors.ok,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'صادره: ${Fa.number(r.totalOut, decimals: 2)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: ShopColors.danger,
                      ),
                    ),
                  ),
                  Text(
                    'مانده: ${Fa.number(r.finalBalance, decimals: 2)}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final row in rows) _kardexRow(row),
        if (pageCount > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: p > 1 ? () => setState(() => _page = p - 1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'قبلی',
              ),
              Text(
                'صفحهٔ ${Fa.number(p)} از ${Fa.number(pageCount)}',
                style: const TextStyle(fontSize: 11, color: ShopColors.inkSoft),
              ),
              IconButton(
                onPressed: p < pageCount
                    ? () => setState(() => _page = p + 1)
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'بعدی',
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _kardexRow(KardexRow r) {
    final (label, color) = switch (r.type) {
      2 => ('فروش', ShopColors.danger),
      1 => ('خرید', ShopColors.ok),
      _ => ('اصلاح موجودی', ShopColors.warn),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShopTag(text: label, color: color),
              const SizedBox(width: 5),
              Text(
                r.documentNo.isEmpty ? '—' : r.documentNo,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: ShopColors.indigo,
                ),
              ),
              const Spacer(),
              Text(
                jalaliShort(r.date),
                style: const TextStyle(
                  fontSize: 9.5,
                  color: ShopColors.inkFaint,
                ),
              ),
            ],
          ),
          if ((r.partyName ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                r.partyName!,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if ((r.description ?? '').isNotEmpty)
            Text(
              r.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                color: ShopColors.inkFaint,
              ),
            ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: _cell(
                  'وارده',
                  r.inQty > 0 ? Fa.number(r.inQty, decimals: 2) : '—',
                  r.inQty > 0 ? ShopColors.ok : ShopColors.inkFaint,
                ),
              ),
              Expanded(
                child: _cell(
                  'صادره',
                  r.outQty > 0 ? Fa.number(r.outQty, decimals: 2) : '—',
                  r.outQty > 0 ? ShopColors.danger : ShopColors.inkFaint,
                ),
              ),
              Expanded(
                child: _cell(
                  'مانده',
                  Fa.number(r.balance, decimals: 2),
                  ShopColors.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- کاردکس ریالی ----------------
  Widget _rialBody() {
    final r = _rial;
    if (r == null) return const SizedBox();
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: ShopColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ShopColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.productName,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'کد: ${r.productCode} — واحد سنجش: ${r.unit} — انبار: '
                '${(r.warehouseName ?? '').isEmpty ? 'همه انبارها' : r.warehouseName}',
                style: const TextStyle(
                  fontSize: 9.5,
                  color: ShopColors.inkFaint,
                ),
              ),
              if (r.methodTitle.isNotEmpty) ...[
                const SizedBox(height: 5),
                ShopTag(
                  text: 'روش قیمت‌گذاری: ${r.methodTitle}',
                  color: ShopColors.indigo,
                  icon: Icons.calculate_rounded,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ShopKpi(
                title: 'مانده ابتدای دوره',
                value: Fa.number(r.openingQty, decimals: 2),
                unit: 'ارزش: ${Fa.number(r.openingValue)} ریال',
                icon: Icons.hourglass_top_rounded,
                color: ShopColors.inkSoft,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ShopKpi(
                title: 'وارده دوره',
                value: Fa.number(r.totalInQty, decimals: 2),
                unit: 'ارزش: ${Fa.number(r.totalInValue)} ریال',
                icon: Icons.south_west_rounded,
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
                title: 'صادره دوره',
                value: Fa.number(r.totalOutQty, decimals: 2),
                unit: 'ارزش: ${Fa.number(r.totalOutValue)} ریال',
                icon: Icons.north_east_rounded,
                color: ShopColors.danger,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ShopKpi(
                title: 'مانده انتهای دوره',
                value: Fa.number(r.closingQty, decimals: 2),
                unit: 'ارزش دفتری: ${Fa.number(r.closingValue)} ریال',
                icon: Icons.inventory_rounded,
                color: ShopColors.indigo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (r.rows.isEmpty)
          const ShopEmpty(
            title: 'گردشی ثبت نشده است',
            subtitle: 'هیچ گردشی برای این کالا در بازهٔ انتخابی ثبت نشده است',
            icon: Icons.inbox_outlined,
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ShopColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ShopColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${Fa.number(r.rows.length)} گردش ثبت‌شده',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                // سطر افتتاحیه
                _rialRow(
                  date: null,
                  label: 'مانده ابتدای دوره',
                  docNo: '—',
                  party: null,
                  desc: null,
                  inQty: 0,
                  inPrice: r.openingQty != 0
                      ? r.openingValue / r.openingQty
                      : 0,
                  inValue: 0,
                  outQty: 0,
                  outPrice: 0,
                  outValue: 0,
                  balQty: r.openingQty,
                  balAvg: r.openingQty != 0
                      ? r.openingValue / r.openingQty
                      : 0,
                  balValue: r.openingValue,
                  opening: true,
                ),
                for (final row in r.rows) _rialRowFrom(row),
                Divider(color: ShopColors.line, height: 14),
                _totalsRow(r),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _rialRowFrom(KardexRow r) => _rialRow(
    date: r.date,
    label: switch (r.type) {
      2 => 'فروش',
      1 => 'خرید',
      _ => 'اصلاح موجودی',
    },
    docNo: r.documentNo,
    party: r.partyName,
    desc: r.description,
    inQty: r.inQty,
    inPrice: r.inPrice,
    inValue: r.inValue,
    outQty: r.outQty,
    outPrice: r.outPrice,
    outValue: r.outValue,
    balQty: r.balanceQty,
    balAvg: r.balanceAvg,
    balValue: r.balanceValue,
  );

  Widget _rialRow({
    required DateTime? date,
    required String label,
    required String docNo,
    required String? party,
    required String? desc,
    required double inQty,
    required double inPrice,
    required double inValue,
    required double outQty,
    required double outPrice,
    required double outValue,
    required double balQty,
    required double balAvg,
    required double balValue,
    bool opening = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: opening
            ? ShopColors.indigo.withValues(alpha: 0.05)
            : ShopColors.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                opening ? label : label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: opening ? ShopColors.indigo : ShopColors.ink,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                docNo,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: ShopColors.indigo,
                ),
              ),
              const Spacer(),
              if (date != null)
                Text(
                  jalaliShort(date),
                  style: const TextStyle(
                    fontSize: 9,
                    color: ShopColors.inkFaint,
                  ),
                ),
            ],
          ),
          if ((party ?? '').isNotEmpty || (desc ?? '').isNotEmpty)
            Text(
              [
                if ((party ?? '').isNotEmpty) party,
                if ((desc ?? '').isNotEmpty) desc,
              ].whereType<String>().join(' — '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, color: ShopColors.inkFaint),
            ),
          const SizedBox(height: 4),
          if (inQty > 0)
            _flowLine(
              'وارده',
              '${Fa.number(inQty, decimals: 2)} × ${Fa.number(inPrice)} = '
                  '${Fa.number(inValue)}',
              ShopColors.ok,
            ),
          if (outQty > 0)
            _flowLine(
              'صادره',
              '${Fa.number(outQty, decimals: 2)} × ${Fa.number(outPrice)} = '
                  '${Fa.number(outValue)}',
              ShopColors.danger,
            ),
          _flowLine(
            'مانده',
            '${Fa.number(balQty, decimals: 2)} · میانگین فی ${Fa.number(balAvg)} · '
                'ارزش ${Fa.number(balValue)}',
            ShopColors.indigo,
          ),
        ],
      ),
    );
  }

  Widget _flowLine(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.only(top: 1),
    child: Row(
      children: [
        SizedBox(
          width: 42,
          child: Text(
            label,
            style: TextStyle(fontSize: 9, color: color),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _totalsRow(KardexRialResult r) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'جمع وارده: ${Fa.number(r.totalInQty, decimals: 2)}',
              style: const TextStyle(fontSize: 10, color: ShopColors.ok),
            ),
          ),
          Text(
            '${Fa.number(r.totalInValue)} ریال',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: ShopColors.ok,
            ),
          ),
        ],
      ),
      Row(
        children: [
          Expanded(
            child: Text(
              'جمع صادره: ${Fa.number(r.totalOutQty, decimals: 2)}',
              style: const TextStyle(fontSize: 10, color: ShopColors.danger),
            ),
          ),
          Text(
            '${Fa.number(r.totalOutValue)} ریال',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: ShopColors.danger,
            ),
          ),
        ],
      ),
      Row(
        children: [
          Expanded(
            child: Text(
              'مانده: ${Fa.number(r.closingQty, decimals: 2)}',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                color: ShopColors.indigo,
              ),
            ),
          ),
          Text(
            '${Fa.number(r.closingValue)} ریال',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: ShopColors.indigo,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _cell(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 8.5, color: ShopColors.inkFaint),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    ],
  );

  Widget _dateBox(
    String label,
    DateTime? value,
    VoidCallback onTap,
    VoidCallback onClear,
  ) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 13),
      decoration: BoxDecoration(
        color: ShopColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShopColors.line),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_month_rounded,
            size: 13,
            color: ShopColors.inkFaint,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value == null ? label : jalaliShort(value),
              maxLines: 1,
              style: TextStyle(
                fontSize: 10,
                color: value == null ? ShopColors.inkFaint : ShopColors.ink,
              ),
            ),
          ),
          if (value != null)
            InkWell(
              onTap: onClear,
              child: const Icon(
                Icons.close_rounded,
                size: 12,
                color: ShopColors.inkFaint,
              ),
            ),
        ],
      ),
    ),
  );

  InputDecoration _dec() => InputDecoration(
    isDense: true,
    filled: true,
    fillColor: ShopColors.bg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: ShopColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: ShopColors.line),
    ),
  );
}
