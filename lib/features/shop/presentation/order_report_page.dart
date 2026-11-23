// ============================================================
//  گزارش جامع و تحلیلی خرید / فروش — آینهٔ کامل
//  `/operations/reports/orders/{Type}` → `OperationsOrderReport.razor`
//
//  • فیلتر بازهٔ شمسی، طرف حساب، انبار و فیلتر «تاخیر تادیه چک»
//  • کارت‌های شاخص (مبلغ کل، تعداد اسناد، تعداد ردیف، مجموع مقدار، میانگین سند)
//    + تفکیک کالا با ارزش افزوده و تاخیر تادیه چک (برای فروش با دسترسی سود)
//  • نمودار روند زمانی + رتبه‌بندی طرف حساب‌های برتر
//  • جدول صفحه‌بندی‌شدهٔ «جزئیات اسناد و فاکتورها» (شامل سود ناخالص، پورسانت معرف و سود خالص)
//  • «چاپ صورت‌حساب مشتری» (`CustomerStatementPrint`) + «چاپ رسمی گزارش» (HTML / اشتراک‌گذاری)
// ============================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../../../core/utils/web_files.dart';
import '../data/shop_perms.dart';
import '../data/shop_repository.dart';
import '../models/ops_models.dart';
import '../models/order_models.dart';
import '../models/shop_models.dart';
import 'shop_phase4_prints_sheet.dart';
import 'shop_style.dart';

class OrderReportPage extends StatefulWidget {
  const OrderReportPage({super.key, required this.type});

  final int type;

  @override
  State<OrderReportPage> createState() => _OrderReportPageState();
}

class _OrderReportPageState extends State<OrderReportPage> {
  late final ShopRepository _repo;
  late final ShopPerms _perms;

  static const _pageSize = 20;

  bool get _isPurchase => widget.type == TxnType.purchase;

  OrderReport? _report;
  List<ShopOrder> _orders = const [];
  int _totalOrders = 0;
  int _page = 1;

  bool _loading = true;
  bool _canSeeProfit = false;
  bool _printing = false;
  String? _error;

  DateTime? _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime? _to = DateTime.now();
  int? _partyId;
  int? _warehouseId;
  String _chequeIncomeFilter = 'all'; // all | with | without
  String _statementRange = 'all'; // all | period

  List<Party> _parties = const [];
  List<Warehouse> _warehouses = const [];

  int get _pageCount =>
      _totalOrders <= 0 ? 1 : ((_totalOrders + _pageSize - 1) ~/ _pageSize);

  bool? get _selectedChequeIncome {
    if (_isPurchase) return null;
    return switch (_chequeIncomeFilter) {
      'with' => true,
      'without' => false,
      _ => null,
    };
  }

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _perms = ShopPerms(context.read<AuthController>().session);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (!_isPurchase) {
      _canSeeProfit = await _repo.orderProfitAccess();
    }
    await _loadLookups();
    await _load(page: 1);
  }

  Future<void> _loadLookups() async {
    List<Party> parties = const [];
    List<Warehouse> whs = const [];
    try {
      parties = await _repo.invoiceParties(type: widget.type);
    } catch (_) {
      try {
        parties = (await _repo.parties(
          type: _isPurchase ? PartyType.supplier : PartyType.customer,
          take: 1000,
        )).items;
      } catch (_) {}
    }
    try {
      whs = await _repo.invoiceWarehouses();
    } catch (_) {
      try {
        whs = (await _repo.warehouses()).items;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _parties = parties;
      _warehouses = whs;
    });
  }

  Future<void> _load({int? page}) async {
    final targetPage = page ?? _page;
    setState(() {
      _loading = true;
      _error = null;
      _page = targetPage;
    });
    try {
      final results = await Future.wait([
        _repo.orderReport(
          type: widget.type,
          from: _from,
          to: _to,
          partyId: _partyId,
          warehouseId: _warehouseId,
          hasChequeIncome: _selectedChequeIncome,
        ),
        _repo.orders(
          type: widget.type,
          from: _from,
          to: _to,
          partyId: _partyId,
          warehouseId: _warehouseId,
          page: targetPage,
          pageSize: _pageSize,
          hasChequeIncome: _selectedChequeIncome,
        ),
      ]);
      if (!mounted) return;
      final rep = results[0] as OrderReport;
      final paged = results[1] as ShopPage<ShopOrder>;
      setState(() {
        _report = rep;
        _orders = paged.items;
        _totalOrders = paged.total ?? paged.items.length;
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

  Future<void> _printCustomerStatement() async {
    if (_isPurchase || (_partyId ?? 0) <= 0 || _printing) return;
    final start = _statementRange == 'period' ? _from : null;
    final end = _statementRange == 'period' ? _to : null;
    if (start != null && end != null && start.isAfter(end)) {
      _toast('تاریخ شروع صورت‌حساب نمی‌تواند پس از تاریخ پایان باشد.');
      return;
    }
    setState(() => _printing = true);
    try {
      final st = await _repo.partyStatement(_partyId!, from: start, to: end);
      if (!mounted) return;
      await showCustomerStatementPrintSheet(
        context,
        repo: _repo,
        statement: st,
        from: start,
        to: end,
      );
    } catch (e) {
      _toast('صورت‌حساب مشتری تهیه نشد: $e');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _printReport({bool share = false}) async {
    final r = _report;
    if (r == null || _printing) return;
    setState(() => _printing = true);
    try {
      ShopCompanyProfile? company;
      try {
        company = await _repo.companyProfile();
      } catch (_) {}
      final title = _isPurchase
          ? 'گزارش جامع و تحلیلی خرید'
          : 'گزارش جامع و تحلیلی فروش';
      final partyName = _partyId == null
          ? 'همه'
          : (_parties
                    .where((p) => p.id == _partyId)
                    .map((p) => p.name)
                    .firstOrNull ??
                'انتخاب‌شده');
      final whName = _warehouseId == null
          ? 'همه انبارها'
          : (_warehouses
                    .where((w) => w.id == _warehouseId)
                    .map((w) => w.name)
                    .firstOrNull ??
                'انتخاب‌شده');
      final html = _buildReportHtml(
        title: title,
        companyName: company?.name ?? '',
        report: r,
        orders: _orders,
        partyName: partyName,
        warehouseName: whName,
      );
      final fileName = '${_isPurchase ? 'purchase' : 'sale'}_report_print.html';
      if (await webOpenHtmlForPrint(html, fileName, share: share)) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(html, encoding: utf8);
      if (share) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'text/html')],
            subject: title,
          ),
        );
      } else {
        await OpenFilex.open(file.path, type: 'text/html');
      }
    } catch (e) {
      _toast('آماده‌سازی خروجی چاپ انجام نشد: $e');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  String _buildReportHtml({
    required String title,
    required String companyName,
    required OrderReport report,
    required List<ShopOrder> orders,
    required String partyName,
    required String warehouseName,
  }) {
    final sb = StringBuffer()
      ..writeln('<!doctype html><html lang="fa" dir="rtl"><head><meta charset="utf-8">')
      ..writeln('<title>${_esc(title)}</title>')
      ..writeln('<style>')
      ..writeln('body{font-family:Tahoma,sans-serif;margin:20px;color:#0f172a;font-size:12px}')
      ..writeln('h1{margin:0 0 4px;font-size:18px} .meta{color:#475569;margin-bottom:14px}')
      ..writeln('.kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin-bottom:16px}')
      ..writeln('.kpi{border:1px solid #cbd5e1;border-radius:8px;padding:8px}')
      ..writeln('.kpi b{display:block;font-size:14px;margin-top:4px}')
      ..writeln('table{width:100%;border-collapse:collapse;margin-top:10px}')
      ..writeln('th,td{border:1px solid #cbd5e1;padding:6px 8px;text-align:right}')
      ..writeln('th{background:#f1f5f9;font-weight:700}')
      ..writeln('@media print{.no-print{display:none}}')
      ..writeln('</style></head><body>')
      ..writeln('<div class="no-print" style="margin-bottom:12px"><button onclick="window.print()" style="padding:8px 16px;font-weight:bold;cursor:pointer">چاپ گزارش</button></div>')
      ..writeln('<h1>${_esc(title)}${companyName.isEmpty ? '' : ' — ${_esc(companyName)}'}</h1>')
      ..writeln('<div class="meta">بازه: ${_from == null ? 'ابتدا' : jalaliShort(_from!)} تا ${_to == null ? 'امروز' : jalaliShort(_to!)} · طرف حساب: ${_esc(partyName)} · انبار: ${_esc(warehouseName)}</div>')
      ..writeln('<div class="kpis">')
      ..writeln('<div class="kpi">جمع کل مبلغ<b>${Fa.number(report.totalAmount)} ریال</b></div>')
      ..writeln('<div class="kpi">تعداد اسناد<b>${Fa.number(report.documentCount)} سند</b></div>')
      ..writeln('<div class="kpi">مجموع مقدار<b>${Fa.number(report.totalQuantity, decimals: 2)}</b></div>')
      ..writeln('<div class="kpi">میانگین هر سند<b>${Fa.number(report.averageDocumentAmount)} ریال</b></div>')
      ..writeln('</div>');

    if (report.topParties.isNotEmpty) {
      sb
        ..writeln('<h3>برترین طرف‌حساب‌ها</h3>')
        ..writeln('<table><thead><tr><th>#</th><th>طرف حساب</th><th>تعداد اسناد</th><th>مقدار</th><th>مبلغ کل (ریال)</th></tr></thead><tbody>');
      for (var i = 0; i < report.topParties.length; i++) {
        final p = report.topParties[i];
        sb.writeln(
          '<tr><td>${Fa.digits(i + 1)}</td><td>${_esc(p.partyName)}</td><td>${Fa.number(p.documentCount)}</td><td>${Fa.number(p.totalQuantity, decimals: 2)}</td><td>${Fa.number(p.totalAmount)}</td></tr>',
        );
      }
      sb.writeln('</tbody></table>');
    }

    if (orders.isNotEmpty) {
      sb
        ..writeln('<h3>جزئیات اسناد (صفحه جاری)</h3>')
        ..writeln('<table><thead><tr><th>شماره</th><th>تاریخ</th><th>طرف حساب</th><th>انبار</th><th>مبلغ کل (ریال)</th>');
      if (!_isPurchase && _canSeeProfit) {
        sb.writeln('<th>سود ناخالص</th><th>پورسانت</th><th>سود خالص</th>');
      }
      sb.writeln('</tr></thead><tbody>');
      for (final o in orders) {
        sb.write(
          '<tr><td>${_esc(o.number)}</td><td>${Fa.date(o.date?.toIso8601String(), time: false)}</td><td>${_esc(o.partyName ?? '—')}</td><td>${_esc(o.warehouseName ?? '—')}</td><td>${Fa.number(o.totalAmount)}</td>',
        );
        if (!_isPurchase && _canSeeProfit) {
          sb.write(
            '<td>${o.totalProfit == null ? '—' : Fa.number(o.totalProfit!)}</td>'
            '<td>${o.commissionAmount == null ? '—' : Fa.number(o.commissionAmount!)}</td>'
            '<td>${o.netProfit == null ? '—' : Fa.number(o.netProfit!)}</td>',
          );
        }
        sb.writeln('</tr>');
      }
      sb.writeln('</tbody></table>');
    }
    sb.writeln('</body></html>');
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (!_perms.canSeeOrderReports) {
      return Scaffold(
        backgroundColor: ShopColors.bg,
        body: const ShopEmpty(
          icon: Icons.lock_outline_rounded,
          title: 'دسترسی محدود شده',
          subtitle: 'مجوز مشاهده گزارش خرید و فروش برای حساب شما فعال نیست.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: ShopColors.bg,
      body: RefreshIndicator(
        onRefresh: () => _load(page: 1),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ShopHeader(
                title: _isPurchase
                    ? 'گزارش جامع و تحلیلی خرید'
                    : 'گزارش جامع و تحلیلی فروش',
                subtitle: _isPurchase
                    ? 'عملیات تأمین کالا — روند دوره‌ای، برترین تأمین‌کنندگان و ریز فاکتورها'
                    : 'عملیات فروش — روند دوره‌ای، برترین مشتریان، سود و پورسانت فاکتورها',
                icon: _isPurchase
                    ? Icons.shopping_bag_rounded
                    : Icons.shopping_cart_rounded,
                actions: [
                  if (!_isPurchase && (_partyId ?? 0) > 0)
                    ShopHeaderButton(
                      label: 'چاپ صورت‌حساب مشتری',
                      icon: Icons.badge_outlined,
                      onTap: _printCustomerStatement,
                    ),
                  if (_report != null)
                    ShopHeaderButton(
                      label: 'چاپ رسمی گزارش',
                      icon: Icons.print_rounded,
                      filled: true,
                      onTap: () => _printReport(),
                    ),
                  if (_report != null)
                    ShopHeaderButton(
                      label: 'اشتراک‌گذاری',
                      icon: Icons.share_rounded,
                      onTap: () => _printReport(share: true),
                    ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              sliver: SliverToBoxAdapter(child: _filters()),
            ),
            if (_loading && _report == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ShopEmpty(
                  title: 'گزارش دریافت نشد',
                  subtitle: _error,
                  icon: Icons.error_outline_rounded,
                  actionLabel: 'تلاش مجدد',
                  onAction: () => _load(page: 1),
                ),
              )
            else if (_report == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: ShopEmpty(
                  title: 'داده‌ای برای این گزارش دریافت نشد',
                  icon: Icons.insights_rounded,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                sliver: SliverList.list(children: _body(_report!)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filters() {
    return Container(
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
          DropdownButtonFormField<int?>(
            initialValue: _parties.any((p) => p.id == _partyId)
                ? _partyId
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              isDense: true,
              labelText: _isPurchase ? 'تأمین‌کننده' : 'مشتری',
              labelStyle: const TextStyle(fontSize: 11),
            ),
            style: const TextStyle(fontSize: 12, color: ShopColors.ink),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text(_isPurchase ? 'همهٔ تأمین‌کنندگان' : 'همهٔ مشتریان'),
              ),
              for (final p in _parties)
                DropdownMenuItem<int?>(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() => _partyId = v),
          ),
          if (!_isPurchase && (_partyId ?? 0) > 0) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _statementRange,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'بازهٔ چاپ صورت‌حساب مشتری',
                labelStyle: TextStyle(fontSize: 11),
              ),
              style: const TextStyle(fontSize: 12, color: ShopColors.ink),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('همه زمان‌ها')),
                DropdownMenuItem(value: 'period', child: Text('بازه فیلتر جاری')),
              ],
              onChanged: (v) => setState(() => _statementRange = v ?? 'all'),
            ),
          ],
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            initialValue: _warehouses.any((w) => w.id == _warehouseId)
                ? _warehouseId
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'انبار مبدأ/مقصد',
              labelStyle: TextStyle(fontSize: 11),
            ),
            style: const TextStyle(fontSize: 12, color: ShopColors.ink),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('همهٔ انبارها'),
              ),
              for (final w in _warehouses)
                DropdownMenuItem<int?>(value: w.id, child: Text(w.name)),
            ],
            onChanged: (v) => setState(() => _warehouseId = v),
          ),
          if (!_isPurchase && _canSeeProfit) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _chequeIncomeFilter,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'تاخیر تادیه چک',
                labelStyle: TextStyle(fontSize: 11),
              ),
              style: const TextStyle(fontSize: 12, color: ShopColors.ink),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('همه فاکتورها')),
                DropdownMenuItem(
                  value: 'with',
                  child: Text('دارای تاخیر تادیه چک'),
                ),
                DropdownMenuItem(
                  value: 'without',
                  child: Text('بدون تاخیر تادیه چک'),
                ),
              ],
              onChanged: (v) =>
                  setState(() => _chequeIncomeFilter = v ?? 'all'),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _load(page: 1),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                backgroundColor: _isPurchase ? ShopColors.indigo : ShopColors.ok,
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
    );
  }

  List<Widget> _body(OrderReport r) {
    final maxTrend = r.trend.fold<double>(
      0,
      (m, t) => t.amount.abs() > m ? t.amount.abs() : m,
    );
    final maxParty = r.topParties.fold<double>(
      0,
      (m, p) => p.totalAmount > m ? p.totalAmount : m,
    );

    return [
      if (!_isPurchase && _canSeeProfit)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: ShopColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ShopColors.line),
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              Text(
                'کالا و خدمات با ارزش افزوده: ${Fa.number(r.goodsAmount)} ریال',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'تاخیر تادیه چک: ${Fa.number(r.chequeIncomeAmount)} ریال',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: ShopColors.teal,
                ),
              ),
              Text(
                'جمع فاکتورها: ${Fa.number(r.totalAmount)} ریال',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.ok,
                ),
              ),
            ],
          ),
        ),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 2.0,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        children: [
          ShopKpi(
            title: _isPurchase ? 'جمع کل مبلغ خرید' : 'جمع کل مبلغ فروش',
            value: Fa.number(r.totalAmount),
            unit: 'ریال',
            icon: _isPurchase
                ? Icons.shopping_bag_rounded
                : Icons.shopping_cart_rounded,
            color: _isPurchase ? ShopColors.indigo : ShopColors.ok,
          ),
          ShopKpi(
            title: 'تعداد اسناد',
            value: Fa.number(r.documentCount),
            unit: '${Fa.number(r.lineCount)} ردیف',
            icon: Icons.receipt_long_rounded,
            color: ShopColors.seed,
          ),
          ShopKpi(
            title: 'مجموع مقدار',
            value: Fa.number(r.totalQuantity, decimals: 2),
            unit: 'واحد کالا',
            icon: Icons.inventory_rounded,
            color: ShopColors.warn,
          ),
          ShopKpi(
            title: 'میانگین مبلغ هر سند',
            value: Fa.number(r.averageDocumentAmount),
            unit: 'ریال',
            icon: Icons.calculate_rounded,
            color: ShopColors.accent,
          ),
        ],
      ),
      const SizedBox(height: 12),

      // ---------- روند زمانی ----------
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ShopColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isPurchase ? 'روند زمانی خرید' : 'روند زمانی فروش',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            if (r.trend.isEmpty)
              const Text(
                'داده‌ای در این بازه ثبت نشده است.',
                style: TextStyle(fontSize: 11.5, color: ShopColors.inkFaint),
              )
            else
              for (final t in r.trend)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${Fa.digits(t.label)} (${Fa.number(t.documentCount)} سند)',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${Fa.number(t.amount)} ریال',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: maxTrend <= 0
                              ? 0
                              : (t.amount.abs() / maxTrend).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: ShopColors.bg,
                          valueColor: AlwaysStoppedAnimation(
                            t.amount < 0
                                ? ShopColors.danger
                                : (_isPurchase
                                      ? ShopColors.indigo
                                      : ShopColors.ok),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
      const SizedBox(height: 12),

      // ---------- برترین طرف‌حساب‌ها ----------
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ShopColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isPurchase ? 'برترین تأمین‌کنندگان' : 'برترین مشتریان',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            if (r.topParties.isEmpty)
              const Text(
                'موردی یافت نشد.',
                style: TextStyle(fontSize: 11.5, color: ShopColors.inkFaint),
              )
            else
              for (var i = 0; i < r.topParties.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          ShopTag(
                            text: '#${Fa.digits(i + 1)}',
                            color: ShopColors.seed,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              r.topParties[i].partyName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${Fa.number(r.topParties[i].totalAmount)} ریال',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: maxParty <= 0
                              ? 0
                              : (r.topParties[i].totalAmount / maxParty).clamp(
                                  0.0,
                                  1.0,
                                ),
                          minHeight: 5,
                          backgroundColor: ShopColors.bg,
                          valueColor: AlwaysStoppedAnimation(
                            _isPurchase ? ShopColors.indigo : ShopColors.ok,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
      const SizedBox(height: 12),

      // ---------- جدول جزئیات اسناد و فاکتورها ----------
      Container(
        padding: const EdgeInsets.all(14),
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
                    'جزئیات اسناد و فاکتورها',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                ),
                ShopTag(
                  text: '${Fa.number(_totalOrders)} سند',
                  color: ShopColors.inkSoft,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_orders.isEmpty)
              const Text(
                'در فیلتر انتخاب‌شده سندی یافت نشد.',
                style: TextStyle(fontSize: 11.5, color: ShopColors.inkFaint),
              )
            else ...[
              for (final o in _orders)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ShopColors.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ShopColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            o.number,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: _isPurchase
                                  ? ShopColors.indigo
                                  : ShopColors.ok,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              o.partyName ?? '—',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            Fa.date(o.date?.toIso8601String(), time: false),
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: ShopColors.inkFaint,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          Text(
                            'انبار: ${o.warehouseName ?? '—'}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: ShopColors.inkSoft,
                            ),
                          ),
                          Text(
                            'اقلام: ${Fa.number(o.lines.length)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: ShopColors.inkSoft,
                            ),
                          ),
                          Text(
                            'مبلغ کل: ${Fa.number(o.totalAmount)} ریال',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      if (!_isPurchase && _canSeeProfit) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            if (o.chequeIncomeAmount > 0)
                              Text(
                                'تاخیر تادیه چک: ${Fa.number(o.chequeIncomeAmount)}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: ShopColors.teal,
                                ),
                              ),
                            if (o.totalProfit != null)
                              Text(
                                'سود ناخالص: ${Fa.number(o.totalProfit!)}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: o.totalProfit! >= 0
                                      ? ShopColors.ok
                                      : ShopColors.danger,
                                ),
                              ),
                            if ((o.referrerId ?? 0) > 0)
                              Text(
                                'معرف: ${o.referrerName ?? '—'} (${o.commissionAmount == null ? '—' : Fa.number(o.commissionAmount!)})',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: ShopColors.accent,
                                ),
                              ),
                            if (o.netProfit != null)
                              Text(
                                'سود خالص: ${Fa.number(o.netProfit!)}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: o.netProfit! >= 0
                                      ? ShopColors.ok
                                      : ShopColors.danger,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              if (_pageCount > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _page > 1 ? () => _load(page: _page - 1) : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                    Text(
                      'صفحه ${Fa.number(_page)} از ${Fa.number(_pageCount)}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    IconButton(
                      onPressed: _page < _pageCount
                          ? () => _load(page: _page + 1)
                          : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    ];
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
