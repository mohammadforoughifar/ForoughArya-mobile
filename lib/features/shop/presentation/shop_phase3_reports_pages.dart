// ============================================================
//  گزارش‌های عملیاتی فاز ۳ همگام‌سازی وب ← اندروید:
//    ۱) ChequeIncomeReportPage  → /operations/reports/cheque-income
//    ۲) ExpenseReportPage       → /operations/reports/expenses
//    ۳) WarrantyReportPage      → /operations/reports/warranty
//    ۴) VisRequestsReportPage   → /sales/requests-report
// ============================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/shop_perms.dart';
import '../data/shop_repository.dart';
import '../models/ops_models.dart';
import '../models/order_models.dart';
import '../models/report_models.dart';
import '../models/shop_models.dart';
import 'shop_style.dart';

String _errText(Object e) => e
    .toString()
    .replaceFirst('ApiException: ', '')
    .replaceFirst('Exception: ', '');

Future<void> _shareCsv(
  BuildContext context, {
  required String fileName,
  required String title,
  required List<List<String>> rows,
}) async {
  try {
    final sb = StringBuffer('\uFEFF'); // UTF-8 BOM برای باز شدن درست فارسی در Excel
    for (final r in rows) {
      sb.writeln(
        r
            .map((cell) => '"${cell.replaceAll('"', '""')}"')
            .join(','),
      );
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(utf8.encode(sb.toString()), flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: title,
        text: title,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('خروجی آماده نشد: ${_errText(e)}'),
        backgroundColor: ShopColors.danger,
      ),
    );
  }
}

// ============================================================
//  ۱) گزارش تاخیر تادیه چک — `ChequeIncomeReport.razor`
// ============================================================

class ChequeIncomeReportPage extends StatefulWidget {
  const ChequeIncomeReportPage({super.key});

  @override
  State<ChequeIncomeReportPage> createState() => _ChequeIncomeReportPageState();
}

class _ChequeIncomeReportPageState extends State<ChequeIncomeReportPage> {
  late final ShopRepository _repo;
  late final ShopPerms _perms;

  DateTime? _from;
  DateTime? _to;
  int? _partyId;
  List<Party> _parties = const [];
  ChequeIncomeReport? _report;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _perms = ShopPerms(context.read<AuthController>().session);
    _from = DateTime.now().subtract(const Duration(days: 30));
    _to = DateTime.now();
    _init();
  }

  Future<void> _init() async {
    if (!_perms.canSeeChequeIncomeReport) {
      setState(() => _loading = false);
      return;
    }
    try {
      _parties = await _repo.invoiceParties(type: TxnType.sale);
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _repo.chequeIncomeReport(
        from: _from,
        to: _to,
        partyId: _partyId,
      );
      if (!mounted) return;
      setState(() {
        _report = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _errText(e);
        _loading = false;
      });
    }
  }

  Future<void> _export() async {
    final rep = _report;
    if (rep == null || rep.rows.isEmpty) return;
    await _shareCsv(
      context,
      fileName: 'cheque-income-report.csv',
      title: 'گزارش تاخیر تادیه چک',
      rows: [
        [
          'تاریخ گردش',
          'مشتری',
          'فاکتور فروش',
          'شناسه گردش',
          'نوع گردش',
          'بستانکاری درآمد فروشگاه (ریال)',
        ],
        for (final r in rep.rows)
          [
            jalaliShort(r.date),
            r.partyName,
            r.saleNumber,
            r.eventId.toString(),
            r.kindTitle,
            r.income.round().toString(),
          ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_perms.canSeeChequeIncomeReport) {
      return const Scaffold(
        backgroundColor: ShopColors.bg,
        body: Padding(
          padding: EdgeInsets.all(20),
          child: ShopEmpty(
            icon: Icons.lock_outline_rounded,
            title:
                'برای مشاهدهٔ این گزارش، دسترسی اسناد فروش و مشاهدهٔ سود لازم است.',
          ),
        ),
      );
    }

    final rep = _report;
    return Scaffold(
      backgroundColor: ShopColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ShopHeader(
                title: 'گزارش تاخیر تادیه چک',
                subtitle:
                    'گردش درآمد فروشگاه از چک‌های مدت‌دار؛ مبالغ منفی نشان‌دهنده برگشت/تعدیل کاهشی است',
                icon: Icons.request_quote_rounded,
                actions: [
                  ShopHeaderButton(
                    label: 'خروجی Excel/CSV',
                    icon: Icons.download_rounded,
                    onTap: _export,
                  ),
                  const SizedBox(width: 8),
                  ShopHeaderButton(
                    label: 'اعمال فیلتر',
                    icon: Icons.filter_alt_rounded,
                    filled: true,
                    onTap: _load,
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
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
                            child: _ReportDateBtn(
                              label: 'از تاریخ',
                              value: _from,
                              onPicked: (d) => setState(() => _from = d),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ReportDateBtn(
                              label: 'تا تاریخ',
                              value: _to,
                              onPicked: (d) => setState(() => _to = d),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int?>(
                        initialValue: _partyId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'مشتری',
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('همهٔ مشتریان'),
                          ),
                          for (final p in _parties)
                            DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                p.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          setState(() => _partyId = v);
                          _load();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ShopEmpty(
                    icon: Icons.error_outline_rounded,
                    title: _error!,
                    actionLabel: 'تلاش دوباره',
                    onAction: _load,
                  ),
                ),
              )
            else if (rep != null) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                sliver: SliverToBoxAdapter(
                  child: ShopKpi(
                    title: 'خالص درآمد تاخیر تادیه چک در دوره',
                    value: money(rep.totalIncome),
                    unit: 'ریال',
                    icon: Icons.trending_up_rounded,
                    color: rep.totalIncome < 0
                        ? ShopColors.danger
                        : ShopColors.ok,
                    footer: '${numFa(rep.rows.length)} گردش ثبت‌شده',
                  ),
                ),
              ),
              if (rep.rows.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: ShopEmpty(
                      icon: Icons.receipt_long_rounded,
                      title: 'گردش قطعی برای فیلتر انتخاب‌شده وجود ندارد.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                  sliver: SliverList.separated(
                    itemCount: rep.rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, idx) {
                      final r = rep.rows[idx];
                      final neg = r.income < 0;
                      return Container(
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
                                ShopPill(
                                  text: r.kindTitle,
                                  color: neg
                                      ? ShopColors.danger
                                      : ShopColors.indigo,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    r.partyName,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${money(r.income)} ریال',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: neg
                                        ? ShopColors.danger
                                        : ShopColors.ok,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'تاریخ: ${jalaliShort(r.date)} · فاکتور: ${Fa.digits(r.saleNumber)} · شناسه گردش: ${numFa(r.eventId)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: ShopColors.inkFaint,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  ۲) گزارش هزینه‌ها — `ExpenseReport.razor`
// ============================================================

class ExpenseReportPage extends StatefulWidget {
  const ExpenseReportPage({super.key});

  @override
  State<ExpenseReportPage> createState() => _ExpenseReportPageState();
}

class _ExpenseReportPageState extends State<ExpenseReportPage> {
  late final ShopRepository _repo;

  DateTime? _from;
  DateTime? _to;
  int? _categoryId;
  List<ExpenseCategory> _categories = const [];
  ExpenseReport? _report;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    final r = currentMonthRangeSafe();
    _from = r.from;
    _to = r.to;
    _init();
  }

  static ({DateTime from, DateTime to}) currentMonthRangeSafe() {
    final now = DateTime.now();
    return (from: now.subtract(const Duration(days: 30)), to: now);
  }

  Future<void> _init() async {
    try {
      _categories = await _repo.expenseCategories(activeOnly: false);
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rep = await _repo.expenseReport(
        categoryId: _categoryId,
        from: _from,
        to: _to,
      );
      if (!mounted) return;
      setState(() {
        _report = rep;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _errText(e);
        _loading = false;
      });
    }
  }

  Future<void> _export() async {
    final rep = _report;
    if (rep == null || rep.items.isEmpty) return;
    await _shareCsv(
      context,
      fileName: 'expense-report.csv',
      title: 'گزارش هزینه‌ها',
      rows: [
        ['شماره سند', 'تاریخ', 'نوع هزینه', 'ذینفع', 'مبلغ (ریال)', 'شرح'],
        for (final it in rep.items)
          [
            it.number,
            it.date == null ? '' : jalaliShort(it.date!),
            it.categoryName ?? '',
            it.payee ?? '',
            it.amount.round().toString(),
            it.description ?? '',
          ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rep = _report;
    return Scaffold(
      backgroundColor: ShopColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ShopHeader(
                title: 'گزارش هزینه‌ها',
                subtitle:
                    'جمع و جزئیات اسناد هزینه به تفکیک سرفصل و بازهٔ زمانی',
                icon: Icons.receipt_long_rounded,
                actions: [
                  ShopHeaderButton(
                    label: 'خروجی CSV',
                    icon: Icons.download_rounded,
                    onTap: _export,
                  ),
                  const SizedBox(width: 8),
                  ShopHeaderButton(
                    label: 'اعمال فیلتر',
                    icon: Icons.filter_alt_rounded,
                    filled: true,
                    onTap: _load,
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
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
                        initialValue: _categoryId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'نوع هزینه',
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('همه انواع هزینه'),
                          ),
                          for (final c in _categories)
                            DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                '${c.name}${!c.isActive ? ' (غیرفعال)' : ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          setState(() => _categoryId = v);
                          _load();
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _ReportDateBtn(
                              label: 'از تاریخ',
                              value: _from,
                              onPicked: (d) => setState(() => _from = d),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ReportDateBtn(
                              label: 'تا تاریخ',
                              value: _to,
                              onPicked: (d) => setState(() => _to = d),
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
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ShopEmpty(
                    icon: Icons.error_outline_rounded,
                    title: _error!,
                    actionLabel: 'تلاش دوباره',
                    onAction: _load,
                  ),
                ),
              )
            else if (rep != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
                sliver: SliverList.list(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ShopKpi(
                            title: 'جمع کل هزینه‌ها',
                            value: money(rep.totalAmount),
                            unit: 'ریال',
                            icon: Icons.payments_rounded,
                            color: ShopColors.danger,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ShopKpi(
                            title: 'تعداد اسناد هزینه',
                            value: numFa(rep.count),
                            unit: 'سند',
                            icon: Icons.tag_rounded,
                            color: ShopColors.seed,
                          ),
                        ),
                      ],
                    ),
                    if (rep.categories.isNotEmpty) ...[
                      const SizedBox(height: 12),
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
                            const Text(
                              'تفکیک بر اساس سرفصل هزینه',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Divider(height: 14),
                            for (final c in rep.categories)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${c.name} (${numFa(c.count)} سند)',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${money(c.amount)} ریال',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: ShopColors.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (rep.items.isEmpty)
                      const ShopEmpty(
                        icon: Icons.receipt_rounded,
                        title: 'سند هزینه‌ای در این بازه ثبت نشده است.',
                      )
                    else
                      for (final it in rep.items) ...[
                        Container(
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
                                  ShopPill(
                                    text: it.categoryName ?? 'هزینه',
                                    color: ShopColors.seed,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'سند ${Fa.digits(it.number)}',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${money(it.amount)} ریال',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: ShopColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                [
                                  if (it.date != null) jalaliShort(it.date!),
                                  if ((it.payee ?? '').isNotEmpty)
                                    'ذینفع: ${it.payee}',
                                  if ((it.trsAccountName ?? '').isNotEmpty)
                                    it.trsAccountName!,
                                ].join(' · '),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: ShopColors.inkSoft,
                                ),
                              ),
                              if ((it.description ?? '').isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  it.description!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: ShopColors.inkFaint,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  ۳) گزارش گارانتی — `WarrantyReport.razor`
// ============================================================

class WarrantyReportPage extends StatefulWidget {
  const WarrantyReportPage({super.key});

  @override
  State<WarrantyReportPage> createState() => _WarrantyReportPageState();
}

class _WarrantyReportPageState extends State<WarrantyReportPage> {
  late final ShopRepository _repo;

  DateTime? _from;
  DateTime? _to;
  List<ShopWarrantyReportRow> _rows = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    if (_from != null && _to != null && _from!.isAfter(_to!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تاریخ شروع پس از تاریخ پایان است.')),
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _repo.warrantyReport(from: _from, to: _to);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _errText(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalInternal = _rows.fold<double>(
      0,
      (s, w) => s + w.internalCost,
    );
    final totalCustomer = _rows.fold<double>(
      0,
      (s, w) => s + w.customerAmount,
    );
    final totalUnpaid = _rows.fold<double>(0, (s, w) => s + w.unpaidAmount);
    final acceptedCount = _rows.fold<int>(
      0,
      (s, w) => s + w.items.where((i) => i.isAccepted).length,
    );
    final rejectedCount = _rows.fold<int>(
      0,
      (s, w) => s + w.items.where((i) => i.isRejected).length,
    );

    return Scaffold(
      backgroundColor: ShopColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ShopHeader(
                title: 'گزارش گارانتی',
                subtitle:
                    'پذیرش‌های تحویل‌شده، هزینه داخلی و مبالغ منظورشده به مشتری',
                icon: Icons.verified_user_rounded,
                actions: [
                  ShopHeaderButton(
                    label: 'اعمال فیلتر',
                    icon: Icons.filter_alt_rounded,
                    filled: true,
                    onTap: _load,
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ShopColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ShopColors.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ReportDateBtn(
                          label: 'از تاریخ تحویل',
                          value: _from,
                          allowClear: true,
                          onPicked: (d) => setState(() => _from = d),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ReportDateBtn(
                          label: 'تا تاریخ تحویل',
                          value: _to,
                          allowClear: true,
                          onPicked: (d) => setState(() => _to = d),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ShopEmpty(
                    icon: Icons.error_outline_rounded,
                    title: _error!,
                    actionLabel: 'تلاش دوباره',
                    onAction: _load,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
                sliver: SliverList.list(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ShopKpi(
                            title: 'پذیرش تحویل‌شده',
                            value: numFa(_rows.length),
                            icon: Icons.assignment_turned_in_rounded,
                            color: ShopColors.seed,
                            footer:
                                'پذیرفته: ${numFa(acceptedCount)} · رد: ${numFa(rejectedCount)}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ShopKpi(
                            title: 'جمع هزینه داخلی',
                            value: money(totalInternal),
                            unit: 'ریال',
                            icon: Icons.build_circle_rounded,
                            color: ShopColors.warn,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ShopKpi(
                            title: 'مبلغ منظورشده به مشتری',
                            value: money(totalCustomer),
                            unit: 'ریال',
                            icon: Icons.request_page_rounded,
                            color: ShopColors.indigo,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ShopKpi(
                            title: 'مانده فعلی تسویه‌نشده',
                            value: money(totalUnpaid),
                            unit: 'ریال',
                            icon: Icons.pending_actions_rounded,
                            color: totalUnpaid > 0
                                ? ShopColors.danger
                                : ShopColors.ok,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_rows.isEmpty)
                      const ShopEmpty(
                        icon: Icons.shield_outlined,
                        title: 'پذیرش تحویل‌شده‌ای در این بازه یافت نشد.',
                      )
                    else
                      for (final w in _rows) ...[
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
                                  ShopPill(
                                    text: 'پذیرش ${Fa.digits(w.number)}',
                                    color: ShopColors.seed,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      w.partyName,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (w.finalizedAt != null)
                                    Text(
                                      jalaliShort(w.finalizedAt!),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: ShopColors.inkFaint,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'دستگاه: ${w.deviceLabel}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: ShopColors.inkSoft,
                                ),
                              ),
                              const Divider(height: 14),
                              for (final item in w.items)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      ShopPill(
                                        text: item.isAccepted
                                            ? 'پذیرفته'
                                            : 'پذیرفته‌نشده',
                                        color: item.isAccepted
                                            ? ShopColors.ok
                                            : ShopColors.warn,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${item.description} (${numFa(item.quantity)})',
                                          style: const TextStyle(fontSize: 11.5),
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'داخلی: ${money(item.internalCost)}',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              color: ShopColors.inkSoft,
                                            ),
                                          ),
                                          if ((w.chargePolicyVersion == 0
                                                  ? 0
                                                  : item.customerAmount) >
                                              0)
                                            Text(
                                              'مشتری: ${money(item.customerAmount)}',
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
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
                        ),
                        const SizedBox(height: 8),
                      ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  ۴) گزارش تجمیع درخواست‌های ویزیتوری — `RequestsReport.razor`
// ============================================================

class VisRequestsReportPage extends StatefulWidget {
  const VisRequestsReportPage({super.key});

  @override
  State<VisRequestsReportPage> createState() => _VisRequestsReportPageState();
}

class _VisRequestsReportPageState extends State<VisRequestsReportPage> {
  late final ShopRepository _repo;

  late DateTime _from;
  late DateTime _to;
  bool _includeCanceled = false;
  int _groupMode = 0; // ۰ کالا · ۱ ویزیتور · ۲ مشتری
  VisRequestsReport? _report;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _to = DateTime.now();
    _from = _to.subtract(const Duration(days: 30));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rep = await _repo.visRequestsReport(
        from: _from,
        to: _to,
        includeCanceled: _includeCanceled,
      );
      if (!mounted) return;
      setState(() {
        _report = rep;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _errText(e);
        _loading = false;
      });
    }
  }

  Future<void> _exportCsv() async {
    final rep = _report;
    if (rep == null || !rep.hasData) return;
    if (_groupMode == 0) {
      await _shareCsv(
        context,
        fileName: 'vis-requests-products.csv',
        title: 'گزارش تجمیع ویزیتوری بر اساس کالا',
        rows: [
          [
            'کد کالا',
            'نام کالا',
            'واحد',
            'تعداد درخواست',
            'مقدار سفارش',
            'موجودی کل',
            'کسری',
            'مبلغ خالص (ریال)',
          ],
          for (final r in rep.rows)
            [
              r.productCode,
              r.productName,
              r.unit ?? '',
              r.orderCount.toString(),
              r.orderedQty.toString(),
              r.isService ? 'خدماتی' : r.stockQty.toString(),
              r.hasShortage ? r.shortageQty.toString() : '0',
              r.amount.round().toString(),
            ],
        ],
      );
    } else {
      final list = _groupMode == 1 ? rep.referrerRows : rep.customerRows;
      final label = _groupMode == 1 ? 'ویزیتور' : 'مشتری';
      await _shareCsv(
        context,
        fileName: 'vis-requests-grouped.csv',
        title: 'گزارش تجمیع ویزیتوری به تفکیک $label',
        rows: [
          [
            label,
            'تعداد درخواست',
            'تنوع کالا',
            'جمع مقدار',
            'جمع کسری',
            'مبلغ خالص (ریال)',
          ],
          for (final g in list)
            [
              g.title,
              g.orderCount.toString(),
              g.productCount.toString(),
              g.totalQty.toString(),
              g.shortageQty.toString(),
              g.totalAmount.round().toString(),
            ],
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rep = _report;
    return Scaffold(
      backgroundColor: ShopColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ShopHeader(
                title: 'گزارش تجمیع سفارش‌های ویزیتوری',
                subtitle:
                    'تجمیع بر اساس کالا (موجودی و کسری)، ویزیتور یا مشتری',
                icon: Icons.analytics_rounded,
                actions: [
                  ShopHeaderButton(
                    label: 'خروجی CSV',
                    icon: Icons.download_rounded,
                    onTap: _exportCsv,
                  ),
                  const SizedBox(width: 8),
                  ShopHeaderButton(
                    label: 'اعمال فیلتر',
                    icon: Icons.filter_alt_rounded,
                    filled: true,
                    onTap: _load,
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
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
                            child: _ReportDateBtn(
                              label: 'از تاریخ',
                              value: _from,
                              onPicked: (d) {
                                if (d != null) setState(() => _from = d);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ReportDateBtn(
                              label: 'تا تاریخ',
                              value: _to,
                              onPicked: (d) {
                                if (d != null) setState(() => _to = d);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: _includeCanceled,
                        title: const Text(
                          'احتساب درخواست‌های ردشده و ابطال‌شده',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onChanged: (v) {
                          setState(() => _includeCanceled = v);
                          _load();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ShopEmpty(
                    icon: Icons.error_outline_rounded,
                    title: _error!,
                    actionLabel: 'تلاش دوباره',
                    onAction: _load,
                  ),
                ),
              )
            else if (rep != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
                sliver: SliverList.list(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ShopKpi(
                            title: 'جمع مبلغ خالص سفارش‌ها',
                            value: money(rep.totalAmount),
                            unit: 'ریال',
                            icon: Icons.shopping_bag_rounded,
                            color: ShopColors.seed,
                            footer:
                                '${numFa(rep.orderCount)} درخواست · ${numFa(rep.productCount)} کالا',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ShopKpi(
                            title: 'کسری موجودی سفارش‌ها',
                            value: numFa(rep.totalShortageQty),
                            icon: Icons.warning_amber_rounded,
                            color: rep.shortageRowCount > 0
                                ? ShopColors.danger
                                : ShopColors.ok,
                            footer: rep.shortageRowCount > 0
                                ? 'در ${numFa(rep.shortageRowCount)} قلم کالا'
                                : 'بدون کسری موجودی',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _modeChip(0, 'بر اساس کالا'),
                        const SizedBox(width: 6),
                        _modeChip(1, 'به تفکیک ویزیتور'),
                        const SizedBox(width: 6),
                        _modeChip(2, 'به تفکیک مشتری'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (!rep.hasData)
                      const ShopEmpty(
                        icon: Icons.inbox_rounded,
                        title: 'درخواستی در این بازهٔ زمانی یافت نشد.',
                      )
                    else if (_groupMode == 0)
                      for (final r in rep.rows) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: r.hasShortage
                                ? ShopColors.danger.withValues(alpha: 0.04)
                                : ShopColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: r.hasShortage
                                  ? ShopColors.danger.withValues(alpha: 0.3)
                                  : ShopColors.line,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      r.productName,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (r.hasShortage)
                                    ShopPill(
                                      text: 'کسری: ${numFa(r.shortageQty)}',
                                      color: ShopColors.danger,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Wrap(
                                spacing: 10,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    'سفارش: ${numFa(r.orderedQty)} ${r.unit ?? ''}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: ShopColors.seed,
                                    ),
                                  ),
                                  Text(
                                    r.isService
                                        ? 'خدماتی'
                                        : 'موجودی: ${numFa(r.stockQty)}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: ShopColors.inkSoft,
                                    ),
                                  ),
                                  Text(
                                    '${numFa(r.orderCount)} درخواست',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: ShopColors.inkFaint,
                                    ),
                                  ),
                                  Text(
                                    '${money(r.amount)} ریال',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ]
                    else
                      for (final g
                          in (_groupMode == 1
                              ? rep.referrerRows
                              : rep.customerRows)) ...[
                        Container(
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
                                  Expanded(
                                    child: Text(
                                      g.title,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${money(g.totalAmount)} ریال',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: ShopColors.seed,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Wrap(
                                spacing: 10,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    '${numFa(g.orderCount)} درخواست',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: ShopColors.inkSoft,
                                    ),
                                  ),
                                  Text(
                                    '${numFa(g.productCount)} قلم کالا',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: ShopColors.inkSoft,
                                    ),
                                  ),
                                  Text(
                                    'جمع مقدار: ${numFa(g.totalQty)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (g.shortageQty > 0)
                                    ShopPill(
                                      text: 'کسری: ${numFa(g.shortageQty)}',
                                      color: ShopColors.danger,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _modeChip(int mode, String label) {
    final sel = _groupMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _groupMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? ShopColors.seed : ShopColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel ? ShopColors.seed : ShopColors.line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: sel ? Colors.white : ShopColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportDateBtn extends StatelessWidget {
  const _ReportDateBtn({
    required this.label,
    required this.value,
    required this.onPicked,
    this.allowClear = false,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPicked;
  final bool allowClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final p = await showJalaliDatePicker(
          context,
          initial: value ?? DateTime.now(),
          title: label,
        );
        if (p != null) onPicked(p);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          suffixIcon: allowClear && value != null
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () => onPicked(null),
                )
              : const Icon(Icons.calendar_today_rounded, size: 16),
        ),
        child: Text(
          value == null ? 'همه تاریخ‌ها' : jalaliShort(value!),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
