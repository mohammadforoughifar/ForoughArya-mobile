// ============================================================
//  پیش‌نمایش و چاپ فاکتور فروش / رسید خرید / پیش‌فاکتور فروش
//  آینهٔ دقیق `ShopSaleInvoicePrint.cs` و `Orders.razor` در وب:
//    • قالب‌های A4، A5 و رول حرارتی ۸۰ میلی‌متری
//    • هدر فروشگاه + لوگو + متادیتای فروشنده/خریدار + کارت‌ها/شباهای ۴رقمی
//    • جدول اقلام با ناخالص، تخفیف، ارزش افزوده، جمع خالص، برگشتی و کارمزد چک
//    • خلاصه پرداخت زمان صدور + وضعیت مالی فعلی + جدول چک‌ها و اقساط + مهر باطل‌شد
//    • خروجی HTML استاندارد برای چاپ مستقیم مرورگر/اندروید و اشتراک‌گذاری
// ============================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/fa.dart';
import '../../../core/utils/web_files.dart';
import '../data/shop_repository.dart';
import '../models/order_models.dart';
import '../models/shop_models.dart';
import 'shop_style.dart';

Future<void> showShopInvoicePrintSheet(
  BuildContext context, {
  required ShopRepository repo,
  required ShopOrder order,
  bool isProforma = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ShopInvoicePrintSheet(
      repo: repo,
      initialOrder: order,
      isProforma: isProforma,
    ),
  );
}

class _ShopInvoicePrintSheet extends StatefulWidget {
  const _ShopInvoicePrintSheet({
    required this.repo,
    required this.initialOrder,
    required this.isProforma,
  });

  final ShopRepository repo;
  final ShopOrder initialOrder;
  final bool isProforma;

  @override
  State<_ShopInvoicePrintSheet> createState() => _ShopInvoicePrintSheetState();
}

class _ShopInvoicePrintSheetState extends State<_ShopInvoicePrintSheet> {
  late ShopOrder _order;
  ShopCompanyProfile _profile = const ShopCompanyProfile();
  ShopPrintSettings _printSettings = const ShopPrintSettings();
  ShopOrderCreditState? _creditState;
  String _paper = 'A4'; // A4 | A5 | 80mm
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    ShopOrder full = _order;
    if (!widget.isProforma && _order.id > 0) {
      try {
        full = await widget.repo.order(_order.id) ?? _order;
      } catch (_) {}
    }
    final profile = await widget.repo.companyProfile();
    ShopPrintSettings printSettings = const ShopPrintSettings();
    try {
      printSettings = await widget.repo.shopPrintSettings();
    } catch (_) {}
    ShopOrderCreditState? credit;
    if (!widget.isProforma && full.isSale && full.id > 0) {
      try {
        credit = await widget.repo.orderCreditState(full.id);
      } catch (_) {}
    }
    if (!mounted) return;
    final defaultPaper = profile.printPaperSize.toUpperCase() == 'A5'
        ? 'A5'
        : 'A4';
    setState(() {
      _order = full;
      _profile = profile;
      _printSettings = printSettings;
      _creditState = credit;
      _paper = defaultPaper;
      _loading = false;
    });
  }

  (String html, String fileName) _buildHtmlDoc() {
    final html = ShopInvoiceHtmlBuilder.build(
      order: _order,
      profile: _profile,
      printSettings: _printSettings,
      creditState: _creditState,
      isProforma: widget.isProforma,
      paper: _paper,
    );
    final safeNo = _order.number.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final prefix = widget.isProforma
        ? 'proforma'
        : (_order.isPurchase ? 'purchase' : 'invoice');
    return (html, '${prefix}_${safeNo}_$_paper.html');
  }

  Future<File> _writeHtmlFile() async {
    final (html, fileName) = _buildHtmlDoc();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(html, encoding: utf8);
    return file;
  }

  Future<void> _openForPrint() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final (html, fileName) = _buildHtmlDoc();
      if (await webOpenHtmlForPrint(html, fileName, share: false)) return;
      final file = await _writeHtmlFile();
      await OpenFilex.open(file.path, type: 'text/html');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در باز کردن فایل چاپ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _shareFile() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final (html, fileName) = _buildHtmlDoc();
      if (await webOpenHtmlForPrint(html, fileName, share: true)) return;
      final file = await _writeHtmlFile();
      final docTitle = widget.isProforma
          ? 'پیش‌فاکتور فروش ${_order.number}'
          : (_order.isPurchase
                ? 'رسید خرید ${_order.number}'
                : 'فاکتور فروش ${_order.number}');
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/html')],
          subject: docTitle,
          text: docTitle,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در اشتراک‌گذاری فاکتور: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPurchase = !widget.isProforma && _order.isPurchase;
    final docTitle = widget.isProforma
        ? 'پیش‌فاکتور فروش'
        : (isPurchase ? 'رسید خرید' : 'فاکتور فروش');
    final grossSum = _order.lines.fold<double>(0, (s, l) => s + l.gross);
    final discSum = _order.lines.fold<double>(
      0,
      (s, l) => s + l.discountAmount,
    );
    final vatSum = _order.lines.fold<double>(0, (s, l) => s + l.computedVat);
    final linesTotal = _order.lines.fold<double>(0, (s, l) => s + l.total);
    final activeBanks = _printSettings.banks
        .where((b) => b.card.trim().isNotEmpty || b.iban.trim().isNotEmpty)
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: ShopColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            // دستگیره و نوار بالا
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                color: ShopColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                border: Border(bottom: BorderSide(color: ShopColors.line)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: ShopColors.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.print_rounded,
                        color: ShopColors.teal,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'پیش‌نمایش و چاپ $docTitle — ${Fa.digits(_order.number)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: ShopColors.ink,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'اندازه کاغذ:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                      const SizedBox(width: 8),
                      for (final p in const [
                        ('A4', 'A4'),
                        ('A5', 'A5'),
                        ('80mm', 'رول ۸۰mm'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ChoiceChip(
                            label: Text(
                              p.$2,
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            selected: _paper == p.$1,
                            onSelected: (_) => setState(() => _paper = p.$1),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // بدنهٔ پیش‌نمایش
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(14),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFCBD5E1),
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_order.isCancelled)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                    horizontal: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFDC2626),
                                    ),
                                  ),
                                  child: const Text(
                                    'این سند باطل شده است',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFFB91C1C),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),

                              // سرصفحهٔ فروشگاه و شماره سند
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _profile.name.trim().isEmpty
                                              ? docTitle
                                              : _profile.name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: ShopColors.ink,
                                          ),
                                        ),
                                        if (_profile.name.trim().isNotEmpty)
                                          Text(
                                            docTitle,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: ShopColors.teal,
                                            ),
                                          ),
                                        if ((_profile.printHeaderLines ?? '')
                                            .trim()
                                            .isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(
                                              _profile.printHeaderLines!.trim(),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: ShopColors.inkFaint,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'شماره: ${Fa.digits(_order.number)}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        'تاریخ: ${_order.date != null ? Fa.date(_order.date!.toIso8601String(), time: false) : '—'}',
                                        style: const TextStyle(fontSize: 11.5),
                                      ),
                                      if ((_order.warehouseName ?? '')
                                          .trim()
                                          .isNotEmpty)
                                        Text(
                                          'انبار: ${_order.warehouseName}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: ShopColors.inkFaint,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 18),

                              // مشخصات فروشنده / خریدار
                              if (!isPurchase) ...[
                                _PartyBox(
                                  label: 'مشخصات فروشنده',
                                  name: _profile.name.trim().isEmpty
                                      ? 'فروشگاه'
                                      : _profile.name,
                                  phone: _profile.phone,
                                  taxId: _profile.taxId,
                                  address: _profile.address,
                                  banks: activeBanks,
                                ),
                                const SizedBox(height: 8),
                              ],
                              _PartyBox(
                                label: isPurchase
                                    ? 'تأمین‌کننده'
                                    : 'مشخصات خریدار',
                                name: (_order.partyName ?? '').trim().isEmpty
                                    ? '—'
                                    : _order.partyName!,
                                phone: _order.partyPhone,
                                taxId: _order.partyTaxId,
                                address: _order.partyAddress,
                              ),
                              const SizedBox(height: 12),

                              // جدول اقلام
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFFCBD5E1),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 7,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(7),
                                        ),
                                      ),
                                      child: const Row(
                                        children: [
                                          Expanded(
                                            flex: 4,
                                            child: Text(
                                              'کالا / خدمت',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'تعداد × فی',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              'جمع خالص (ریال)',
                                              textAlign: TextAlign.left,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    for (var i = 0; i < _order.lines.length; i++)
                                      _PreviewLineRow(
                                        index: i + 1,
                                        line: _order.lines[i],
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              // جمع‌ها
                              _TotalRow('جمع ناخالص اقلام', grossSum),
                              if (discSum > 0)
                                _TotalRow('جمع تخفیف', -discSum, accent: true),
                              if (vatSum > 0)
                                _TotalRow('جمع ارزش افزوده', vatSum),
                              if (!widget.isProforma &&
                                  _order.chequeIncomeAmount > 0)
                                _TotalRow(
                                  'مابه‌التفاوت فروش چکی / تعهدی',
                                  _order.chequeIncomeAmount,
                                ),
                              if (!widget.isProforma &&
                                  _order.returnedGoodsAmount > 0)
                                _TotalRow(
                                  'کالای مرجوعی ثبت‌شده',
                                  -_order.returnedGoodsAmount,
                                  accent: true,
                                ),
                              const Divider(height: 14),
                              _TotalRow(
                                widget.isProforma
                                    ? 'مبلغ کل پیش‌فاکتور'
                                    : 'مبلغ کل سند',
                                widget.isProforma
                                    ? linesTotal
                                    : _order.totalAmount,
                                bold: true,
                              ),

                              // وضعیت تسویه و چک‌ها/اقساط
                              if (!widget.isProforma) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'نحوه تسویه زمان صدور: ${_order.payLabel}'
                                        '${(_order.cashTrackingNumber ?? '').isNotEmpty ? ' · کد رهگیری: ${Fa.digits(_order.cashTrackingNumber)}' : ''}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (_creditState != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'مانده باز فعلی فاکتور: ${Fa.number(_creditState!.outstanding)} ریال'
                                          '${_creditState!.availableCredit > 0 ? ' · بستانکاری مشتری: ${Fa.number(_creditState!.availableCredit)} ریال' : ''}',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: ShopColors.ink,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],

                              if ((_order.description).trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'توضیحات: ${_order.description}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: ShopColors.inkFaint,
                                  ),
                                ),
                              ],
                              if ((_profile.printFooterLines ?? '')
                                  .trim()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _profile.printFooterLines!.trim(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: ShopColors.inkFaint,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
            ),

            // دکمه‌های چاپ و اشتراک‌گذاری
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              decoration: const BoxDecoration(
                color: ShopColors.surface,
                border: Border(top: BorderSide(color: ShopColors.line)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loading || _exporting ? null : _shareFile,
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('ارسال فایل فاکتور'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: ShopColors.teal,
                        ),
                        onPressed: _loading || _exporting
                            ? null
                            : _openForPrint,
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: Text('چاپ / PDF ($_paper)'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartyBox extends StatelessWidget {
  const _PartyBox({
    required this.label,
    required this.name,
    this.phone,
    this.taxId,
    this.address,
    this.banks = const [],
  });

  final String label;
  final String name;
  final String? phone;
  final String? taxId;
  final String? address;
  final List<ShopPrintBank> banks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$label: ',
                style: const TextStyle(
                  fontSize: 11,
                  color: ShopColors.inkFaint,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if ((phone ?? '').trim().isNotEmpty ||
              (taxId ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Wrap(
                spacing: 12,
                children: [
                  if ((phone ?? '').trim().isNotEmpty)
                    Text(
                      'تلفن: ${Fa.digits(phone)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  if ((taxId ?? '').trim().isNotEmpty)
                    Text(
                      'شناسه/کد ملی: ${Fa.digits(taxId)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                ],
              ),
            ),
          if ((address ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'نشانی: $address',
                style: const TextStyle(fontSize: 11, color: ShopColors.inkFaint),
              ),
            ),
          for (final b in banks)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                [
                  if (b.card.trim().isNotEmpty)
                    'کارت: ${ShopInvoiceHtmlBuilder.group4(b.card)}',
                  if (b.iban.trim().isNotEmpty)
                    'شبا: ${ShopInvoiceHtmlBuilder.formatIban(b.iban)}',
                ].join('   |   '),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: ShopColors.ink,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewLineRow extends StatelessWidget {
  const _PreviewLineRow({required this.index, required this.line});

  final int index;
  final OrderLine line;

  @override
  Widget build(BuildContext context) {
    final extras = <String>[
      if (line.discountAmount > 0)
        'تخفیف: ${Fa.number(line.discountAmount)}',
      if (line.computedVat > 0)
        'ارزش افزوده: ${Fa.number(line.computedVat)}',
      if (line.returnedQuantity > 0)
        'مرجوعی: ${Fa.number(line.returnedQuantity)}',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  '${Fa.digits(index)}. ${line.productName}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${Fa.number(line.quantity)} ${line.unit}\n× ${Fa.number(line.price)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10.5, height: 1.3),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  Fa.number(line.total),
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (extras.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                extras.join(' · '),
                style: const TextStyle(fontSize: 10, color: ShopColors.inkFaint),
              ),
            ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(
    this.label,
    this.value, {
    this.bold = false,
    this.accent = false,
  });

  final String label;
  final double value;
  final bool bold;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final absText = Fa.number(value.abs());
    final formatted = value < 0 ? '($absText)' : absText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: bold ? 12.5 : 11.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: accent ? ShopColors.danger : ShopColors.ink,
            ),
          ),
          Text(
            '$formatted ریال',
            style: TextStyle(
              fontSize: bold ? 13 : 11.5,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              color: accent
                  ? ShopColors.danger
                  : (bold ? ShopColors.teal : ShopColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// سازندهٔ HTML مستقل چاپ فاکتور — هم‌ساختار با `ShopSaleInvoicePrint.cs`
class ShopInvoiceHtmlBuilder {
  const ShopInvoiceHtmlBuilder._();

  static String _esc(String? s) => const HtmlEscape().convert(s ?? '');

  static String group4(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write('-');
      buf.write(digits[i]);
    }
    return Fa.digits(buf.toString());
  }

  static String formatIban(String raw) {
    var clean = raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (clean.isEmpty) return '';
    if (!clean.startsWith('IR')) clean = 'IR$clean';
    final body = clean.substring(2).replaceAll(RegExp(r'\D'), '');
    return 'IR${group4(body)}';
  }

  static String build({
    required ShopOrder order,
    required ShopCompanyProfile profile,
    required ShopPrintSettings printSettings,
    ShopOrderCreditState? creditState,
    required bool isProforma,
    required String paper,
  }) {
    final isPurchase = !isProforma && order.isPurchase;
    final isThermal = paper == '80mm';
    final isA5 = paper == 'A5';
    final docTitle = isProforma
        ? 'پیش‌فاکتور فروش'
        : (isPurchase ? 'رسید خرید' : 'فاکتور فروش');
    final pageRule = isThermal
        ? '@page { size: 80mm auto; margin: 3mm; }'
        : (isA5
              ? '@page { size: A5; margin: 7mm; }'
              : '@page { size: A4; margin: 10mm; }');
    final maxWidth = isThermal ? '76mm' : (isA5 ? '138mm' : '195mm');
    final baseFont = isThermal ? '10.5px' : (isA5 ? '11px' : '12px');

    final grossSum = order.lines.fold<double>(0, (s, l) => s + l.gross);
    final discSum = order.lines.fold<double>(0, (s, l) => s + l.discountAmount);
    final vatSum = order.lines.fold<double>(0, (s, l) => s + l.computedVat);
    final linesTotal = order.lines.fold<double>(0, (s, l) => s + l.total);
    final hasReturned =
        !isProforma && order.lines.any((l) => l.returnedQuantity > 0);

    final banks = printSettings.banks
        .where((b) => b.card.trim().isNotEmpty || b.iban.trim().isNotEmpty)
        .toList();

    final sb = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html lang="fa" dir="rtl"><head><meta charset="utf-8">')
      ..writeln(
        '<meta name="viewport" content="width=device-width,initial-scale=1">',
      )
      ..writeln('<title>${_esc(docTitle)} ${_esc(order.number)}</title>')
      ..writeln('<style>')
      ..writeln(pageRule)
      ..writeln('''
*{box-sizing:border-box}
body{font-family:Tahoma,'Vazirmatn',sans-serif;direction:rtl;margin:0;padding:8px;color:#0f172a;font-size:$baseFont;line-height:1.55;background:#fff}
.sheet{max-width:$maxWidth;margin:0 auto;position:relative}
.toolbar{display:flex;gap:8px;justify-content:center;margin-bottom:10px}
.toolbar button{padding:7px 16px;border-radius:8px;border:1px solid #0d9488;background:#0d9488;color:#fff;font-family:inherit;font-weight:700;cursor:pointer}
@media print{.toolbar{display:none}}
.head{display:flex;justify-content:space-between;align-items:flex-start;border-bottom:2px solid #0f172a;padding-bottom:8px;margin-bottom:8px}
.head h1{margin:0;font-size:1.25em}
.meta{font-size:.92em}
.box{border:1px solid #cbd5e1;border-radius:6px;padding:6px 8px;margin-bottom:7px;background:#f8fafc}
.box-title{font-weight:700;color:#334155;margin-bottom:2px}
table{width:100%;border-collapse:collapse;margin-bottom:8px}
th,td{border:1px solid #cbd5e1;padding:4px 6px;text-align:right;font-size:.92em}
th{background:#f1f5f9;font-weight:700}
.num{text-align:left;direction:ltr;unicode-bidi:embed}
.totals{width:100%;max-width:320px;margin-right:auto}
.watermark{border:2px solid #dc2626;color:#b91c1c;background:#fef2f2;font-weight:800;text-align:center;padding:4px;border-radius:6px;margin-bottom:8px}
.sigs{display:flex;justify-content:space-between;margin-top:18px;padding-top:8px;border-top:1px dashed #cbd5e1;font-size:.9em}
''')
      ..writeln('</style></head><body>')
      ..writeln(
        '<div class="toolbar"><button onclick="window.print()">چاپ / ذخیره PDF</button></div>',
      )
      ..writeln('<div class="sheet">');

    if (order.isCancelled) {
      sb.writeln('<div class="watermark">باطل شد</div>');
    }

    final dateStr = order.date != null
        ? Fa.date(order.date!.toIso8601String(), time: false)
        : '—';

    sb.writeln('<div class="head"><div>');
    if ((profile.logoDataUrl ?? '').startsWith('data:image/')) {
      sb.writeln(
        '<img src="${_esc(profile.logoDataUrl)}" alt="logo" style="max-height:44px;display:block;margin-bottom:4px">',
      );
    }
    sb.writeln(
      '<h1>${_esc(profile.name.trim().isEmpty ? docTitle : profile.name)}</h1>',
    );
    if (profile.name.trim().isNotEmpty) {
      sb.writeln('<div><strong>${_esc(docTitle)}</strong></div>');
    }
    if ((profile.printHeaderLines ?? '').trim().isNotEmpty) {
      sb.writeln('<div class="meta">${_esc(profile.printHeaderLines)}</div>');
    }
    sb.writeln('</div><div class="meta">');
    sb.writeln('<div>شماره: <strong>${Fa.digits(_esc(order.number))}</strong></div>');
    sb.writeln('<div>تاریخ: <strong>$dateStr</strong></div>');
    if ((order.warehouseName ?? '').trim().isNotEmpty) {
      sb.writeln('<div>انبار: ${_esc(order.warehouseName)}</div>');
    }
    sb.writeln('</div></div>');

    if (!isPurchase) {
      sb.writeln('<div class="box"><div class="box-title">فروشنده: ${_esc(profile.name.trim().isEmpty ? 'فروشگاه' : profile.name)}</div>');
      final sellerMeta = <String>[
        if ((profile.phone ?? '').trim().isNotEmpty)
          'تلفن: ${Fa.digits(_esc(profile.phone))}',
        if ((profile.taxId ?? '').trim().isNotEmpty)
          'شناسه ملی/مالیاتی: ${Fa.digits(_esc(profile.taxId))}',
        if ((profile.economicCode ?? '').trim().isNotEmpty)
          'کد اقتصادی: ${Fa.digits(_esc(profile.economicCode))}',
        if ((profile.address ?? '').trim().isNotEmpty)
          'نشانی: ${_esc(profile.address)}',
      ];
      if (sellerMeta.isNotEmpty) sb.writeln('<div>${sellerMeta.join(' · ')}</div>');
      for (final b in banks) {
        final parts = <String>[
          if (b.card.trim().isNotEmpty) 'کارت: ${group4(b.card)}',
          if (b.iban.trim().isNotEmpty) 'شبا: ${formatIban(b.iban)}',
        ];
        if (parts.isNotEmpty) sb.writeln('<div>${parts.join(' | ')}</div>');
      }
      sb.writeln('</div>');
    }

    final buyerTitle = isPurchase ? 'تأمین‌کننده' : 'خریدار';
    sb.writeln(
      '<div class="box"><div class="box-title">$buyerTitle: ${_esc((order.partyName ?? '').trim().isEmpty ? '—' : order.partyName)}</div>',
    );
    final buyerMeta = <String>[
      if ((order.partyPhone ?? '').trim().isNotEmpty)
        'تلفن: ${Fa.digits(_esc(order.partyPhone))}',
      if ((order.partyTaxId ?? '').trim().isNotEmpty)
        'شناسه/کد ملی: ${Fa.digits(_esc(order.partyTaxId))}',
      if ((order.partyAddress ?? '').trim().isNotEmpty)
        'نشانی: ${_esc(order.partyAddress)}',
    ];
    if (buyerMeta.isNotEmpty) sb.writeln('<div>${buyerMeta.join(' · ')}</div>');
    sb.writeln('</div>');

    // جدول اقلام
    sb.writeln('<table><thead><tr>');
    sb.writeln('<th>#</th><th>کالا / خدمت</th><th>تعداد</th><th>فی</th>');
    if (!isThermal) {
      sb.writeln('<th>تخفیف</th><th>ارزش افزوده</th>');
      if (hasReturned) sb.writeln('<th>مرجوعی</th>');
    }
    sb.writeln('<th>جمع خالص</th></tr></thead><tbody>');

    for (var i = 0; i < order.lines.length; i++) {
      final l = order.lines[i];
      sb.writeln('<tr>');
      sb.writeln('<td>${Fa.digits(i + 1)}</td>');
      sb.writeln('<td>${_esc(l.productName)}</td>');
      sb.writeln('<td>${Fa.number(l.quantity)} ${_esc(l.unit)}</td>');
      sb.writeln('<td class="num">${Fa.number(l.price)}</td>');
      if (!isThermal) {
        sb.writeln('<td class="num">${Fa.number(l.discountAmount)}</td>');
        sb.writeln('<td class="num">${Fa.number(l.computedVat)}</td>');
        if (hasReturned) {
          sb.writeln('<td class="num">${Fa.number(l.returnedQuantity)}</td>');
        }
      }
      sb.writeln('<td class="num"><strong>${Fa.number(l.total)}</strong></td>');
      sb.writeln('</tr>');
    }
    sb.writeln('</tbody></table>');

    // جدول جمع‌ها
    sb.writeln('<table class="totals"><tbody>');
    sb.writeln(
      '<tr><td>جمع ناخالص</td><td class="num">${Fa.number(grossSum)} ریال</td></tr>',
    );
    if (discSum > 0) {
      sb.writeln(
        '<tr><td>جمع تخفیف</td><td class="num">(${Fa.number(discSum)}) ریال</td></tr>',
      );
    }
    if (vatSum > 0) {
      sb.writeln(
        '<tr><td>جمع ارزش افزوده</td><td class="num">${Fa.number(vatSum)} ریال</td></tr>',
      );
    }
    if (!isProforma && order.chequeIncomeAmount > 0) {
      sb.writeln(
        '<tr><td>مابه‌التفاوت فروش چکی</td><td class="num">${Fa.number(order.chequeIncomeAmount)} ریال</td></tr>',
      );
    }
    if (!isProforma && order.returnedGoodsAmount > 0) {
      sb.writeln(
        '<tr><td>کالای مرجوعی</td><td class="num">(${Fa.number(order.returnedGoodsAmount)}) ریال</td></tr>',
      );
    }
    final grandTotal = isProforma ? linesTotal : order.totalAmount;
    sb.writeln(
      '<tr><th>مبلغ قابل پرداخت</th><th class="num">${Fa.number(grandTotal)} ریال</th></tr>',
    );
    sb.writeln('</tbody></table>');

    if (!isProforma) {
      sb.writeln('<div class="box">');
      sb.writeln(
        '<div><strong>نحوه تسویه زمان صدور:</strong> ${_esc(order.payLabel)}'
        '${(order.cashTrackingNumber ?? '').isNotEmpty ? ' · کد رهگیری: ${Fa.digits(_esc(order.cashTrackingNumber))}' : ''}</div>',
      );
      if (creditState != null) {
        sb.writeln(
          '<div>مانده باز فعلی فاکتور: <strong>${Fa.number(creditState.outstanding)} ریال</strong>'
          '${creditState.availableCredit > 0 ? ' · بستانکاری مشتری: ${Fa.number(creditState.availableCredit)} ریال' : ''}</div>',
        );
      }
      sb.writeln('</div>');

      if (order.cheques.isNotEmpty) {
        sb.writeln(
          '<table><thead><tr><th>شماره چک</th><th>بانک</th><th>سررسید</th><th>مبلغ</th></tr></thead><tbody>',
        );
        for (final ch in order.cheques) {
          final due = ch.dueDate != null
              ? Fa.date(ch.dueDate!.toIso8601String(), time: false)
              : '—';
          sb.writeln(
            '<tr><td>${Fa.digits(_esc(ch.number))}</td><td>${_esc(ch.bankName ?? '—')}</td><td>$due</td><td class="num">${Fa.number(ch.amount)}</td></tr>',
          );
        }
        sb.writeln('</tbody></table>');
      }

      if (order.installments.isNotEmpty) {
        sb.writeln(
          '<table><thead><tr><th>قسط</th><th>سررسید</th><th>مبلغ</th><th>وضعیت</th></tr></thead><tbody>',
        );
        for (final ins in order.installments) {
          final due = ins.dueDate != null
              ? Fa.date(ins.dueDate!.toIso8601String(), time: false)
              : '—';
          sb.writeln(
            '<tr><td>${Fa.digits(ins.no)}</td><td>$due</td><td class="num">${Fa.number(ins.amount)}</td><td>${ins.isPaid ? 'پرداخت‌شده' : 'مانده'}</td></tr>',
          );
        }
        sb.writeln('</tbody></table>');
      }
    }

    if (order.description.trim().isNotEmpty) {
      sb.writeln('<div class="box">توضیحات: ${_esc(order.description)}</div>');
    }
    if ((profile.printFooterLines ?? '').trim().isNotEmpty) {
      sb.writeln('<div class="meta">${_esc(profile.printFooterLines)}</div>');
    }

    sb.writeln(
      '<div class="sigs"><div>مهر و امضای ${isPurchase ? 'تحویل‌گیرنده' : 'فروشنده'}</div><div>مهر و امضای ${isPurchase ? 'تأمین‌کننده' : 'خریدار'}</div></div>',
    );
    sb.writeln('</div></body></html>');
    return sb.toString();
  }
}
