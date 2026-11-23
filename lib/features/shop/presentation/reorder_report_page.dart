// ============================================================
//  گزارش هوشمند نقطه سفارش و کسری کالا
//  آینهٔ دقیق صفحهٔ وب: /reports/reorder → Pages/Reports/Reorder.razor
//
//  • سه کارت KPI: اقلام زیر نقطه سفارش، محدوده انبار جاری، پیشنهاد تأمین کالا
//  • فیلتر انبار + جستجوی فوری کد/نام/گروه کالا + خروجی CSV
//  • فهرست اقلام زیر نقطه سفارش با موجودی فعلی، نقطه سفارش، حداکثر انبار،
//    مقدار کسری، پیشنهاد خرید و میانبر مستقیم ثبت سفارش خرید
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
import '../../../core/utils/web_files.dart';
import '../data/shop_perms.dart';
import '../data/shop_repository.dart';
import '../models/order_models.dart';
import '../models/report_models.dart';
import '../models/shop_models.dart';
import 'order_form_page.dart';
import 'shop_style.dart';

class ReorderReportPage extends StatefulWidget {
  const ReorderReportPage({super.key});

  @override
  State<ReorderReportPage> createState() => _ReorderReportPageState();
}

class _ReorderReportPageState extends State<ReorderReportPage> {
  static const int _pageSize = 20;

  late final ShopRepository _repo =
      Provider.of<ShopRepository?>(context, listen: false) ??
      ShopRepository(context.read<ApiClient>());
  late final ShopPerms _perms = ShopPerms(
    context.read<AuthController>().session,
  );

  List<ReorderItem> _items = const [];
  List<Warehouse> _warehouses = const [];
  int _warehouseId = 0;
  int _page = 1;
  int _totalCount = 0;
  bool _loading = true;
  bool _exporting = false;
  String? _error;
  final _search = TextEditingController();

  int get _pageCount =>
      _totalCount <= 0 ? 1 : ((_totalCount + _pageSize - 1) ~/ _pageSize);

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadWarehouses() async {
    try {
      final list = await _repo.warehouses();
      if (!mounted) return;
      setState(() {
        _warehouses = list.items.where((w) => w.isActive).toList();
      });
    } catch (_) {}
  }

  Future<void> _load({int? page}) async {
    final targetPage = page ?? _page;
    setState(() {
      _loading = true;
      _error = null;
      _page = targetPage;
    });
    try {
      final res = await _repo.reorderItems(
        warehouseId: _warehouseId > 0 ? _warehouseId : null,
        skip: (targetPage - 1) * _pageSize,
        take: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _totalCount = res.total ?? res.items.length;
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

  List<ReorderItem> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((r) {
      return r.productName.toLowerCase().contains(q) ||
          r.productCode.toLowerCase().contains(q) ||
          (r.category ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _exportCsv() async {
    if (_exporting || _filtered.isEmpty) return;
    setState(() => _exporting = true);
    try {
      final sb = StringBuffer('\uFEFF');
      sb.writeln(
        'کد کالا,نام کالا,گروه کالا,واحد,موجودی فعلی,نقطه سفارش,حداکثر انبار,مقدار کسری,پیشنهاد خرید',
      );
      String esc(String s) => '"${s.replaceAll('"', '""')}"';
      for (final r in _filtered) {
        sb.writeln(
          [
            esc(r.productCode),
            esc(r.productName),
            esc(r.category ?? 'عمومی'),
            esc(r.unit),
            r.totalStock,
            r.reorderPoint,
            r.maxStock,
            r.shortage,
            r.suggested,
          ].join(','),
        );
      }
      final csvBytes = utf8.encode('\uFEFF${sb.toString()}');
      if (await webDeliver(
        csvBytes,
        'reorder_report.csv',
        mimeType: 'text/csv;charset=utf-8',
      )) {
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/reorder_report.csv');
      await file.writeAsString(sb.toString(), encoding: utf8);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'گزارش نقطه سفارش و کسری انبار',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در خروجی CSV: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _openPurchaseOrder() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const OrderFormPage(type: TxnType.purchase),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final whLabel = _warehouseId > 0
        ? (_warehouses
                  .where((w) => w.id == _warehouseId)
                  .map((w) => w.name)
                  .firstOrNull ??
              'انبار انتخاب‌شده')
        : 'همه انبارهای فعال';
    final totalSuggested = _items.fold<double>(0, (s, i) => s + i.suggested);
    final list = _filtered;

    return Scaffold(
      backgroundColor: ShopColors.bg,
      body: RefreshIndicator(
        onRefresh: () => _load(page: 1),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ShopHeader(
              title: 'نقطه سفارش و هشدار کسری انبار',
              subtitle:
                  'شناسایی اقلام زیر آستانهٔ سفارش و محاسبهٔ خودکار مقدار پیشنهادی خرید مجدد',
              icon: Icons.warning_amber_rounded,
              badge: 'زنجیره تأمین',
              actions: [
                if (_filtered.isNotEmpty)
                  ShopHeaderButton(
                    label: 'خروجی CSV',
                    icon: Icons.download_rounded,
                    onTap: _exporting ? () {} : _exportCsv,
                  ),
                if (_perms.canManageSection('Purchase'))
                  ShopHeaderButton(
                    label: 'ثبت خرید',
                    icon: Icons.add_shopping_cart_rounded,
                    filled: true,
                    onTap: _openPurchaseOrder,
                  ),
              ],
            ),

            // ---------- کارت‌های KPI ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ShopKpi(
                          title: 'اقلام زیر نقطه سفارش',
                          value: Fa.number(_totalCount),
                          unit: 'کالای نیازمند اقدام',
                          icon: Icons.notification_important_rounded,
                          color: ShopColors.warn,
                          footer: 'وضعیت بحرانی موجودی',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ShopKpi(
                          title: 'پیشنهاد تأمین کالا',
                          value: Fa.number(totalSuggested),
                          unit: 'مجموع واحد پیشنهادی صفحه',
                          icon: Icons.shopping_cart_checkout_rounded,
                          color: ShopColors.ok,
                          footer: 'تکمیل تا سقف مجاز انبار',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ShopKpi(
                    title: 'محدوده انبار جاری',
                    value: whLabel,
                    unit: 'مکان رهگیری فیزیکی',
                    icon: Icons.warehouse_rounded,
                    color: ShopColors.indigo,
                  ),
                ],
              ),
            ),

            // ---------- فیلتر انبار و جستجو ----------
            Container(
              margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ShopColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ShopColors.line),
              ),
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _warehouseId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'انتخاب انبار مورد بررسی',
                      isDense: true,
                      prefixIcon: Icon(Icons.warehouse_outlined, size: 18),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 0,
                        child: Text('همه انبارهای فعال'),
                      ),
                      for (final w in _warehouses)
                        DropdownMenuItem(value: w.id, child: Text(w.name)),
                    ],
                    onChanged: (v) {
                      setState(() => _warehouseId = v ?? 0);
                      _load(page: 1);
                    },
                  ),
                  const SizedBox(height: 10),
                  ShopSearchField(
                    controller: _search,
                    hint: 'جستجوی کد، نام یا گروه کالا…',
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(14),
                child: ShopEmpty(
                  icon: Icons.error_outline_rounded,
                  title: 'گزارش نقطه سفارش دریافت نشد',
                  subtitle: _error,
                  actionLabel: 'تلاش دوباره',
                  onAction: () => _load(page: 1),
                ),
              )
            else if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(18),
                child: ShopEmpty(
                  icon: Icons.verified_rounded,
                  title: 'تمامی کالاها در وضعیت مطلوب موجودی هستند',
                  subtitle: 'هیچ کالایی به آستانهٔ کمبود یا نقطه سفارش نرسیده است.',
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  children: [
                    for (final r in list) _ReorderCard(item: r),
                  ],
                ),
              ),
              if (_pageCount > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _page > 1
                            ? () => _load(page: _page - 1)
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                      Text(
                        'صفحه ${Fa.digits(_page)} از ${Fa.digits(_pageCount)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: _page < _pageCount
                            ? () => _load(page: _page + 1)
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReorderCard extends StatelessWidget {
  const _ReorderCard({required this.item});

  final ReorderItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
              if (item.productCode.trim().isNotEmpty) ...[
                ShopTag(text: item.productCode, color: ShopColors.inkSoft),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.ink,
                  ),
                ),
              ),
              ShopTag(
                text: (item.category ?? '').trim().isEmpty
                    ? 'عمومی'
                    : item.category!,
                color: ShopColors.indigo,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _stat(
                'موجودی فعلی',
                '${Fa.number(item.totalStock)} ${item.unit}',
                ShopColors.danger,
              ),
              _stat(
                'نقطه سفارش',
                '${Fa.number(item.reorderPoint)} ${item.unit}',
                ShopColors.inkSoft,
              ),
              _stat(
                'حداکثر انبار',
                '${Fa.number(item.maxStock)} ${item.unit}',
                ShopColors.inkSoft,
              ),
              _stat(
                'مقدار کسری',
                '${Fa.number(item.shortage)} -',
                ShopColors.danger,
              ),
            ],
          ),
          const Divider(height: 18, color: ShopColors.line),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'پیشنهاد خرید مجدد:',
                style: TextStyle(
                  fontSize: 11.5,
                  color: ShopColors.inkSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: ShopColors.ok.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_shopping_cart_rounded,
                      size: 14,
                      color: ShopColors.ok,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${Fa.number(item.suggested)} ${item.unit}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: ShopColors.ok,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String val, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: ShopColors.bg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: ShopColors.inkFaint),
        ),
        Text(
          val,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );
}
