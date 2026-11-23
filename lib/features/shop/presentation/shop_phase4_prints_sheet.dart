// ============================================================
//  پیش‌نمایش، چاپ و اشتراک‌گذاری اسناد فاز ۴ سامانه فروشگاهی:
//    ۱. قبض پذیرش تعمیرات / فاکتور خدمات و تعمیرات (`RepairInvoicePrint.cs`)
//    ۲. فیش ترخیص و تحویل کارگاهی دستگاه (`RepairDeliveryReceiptPrint.cs`)
//    ۳. بیجک (حوالهٔ تحویل کالا — بدون قیمت، با انتخاب A4/A5) (`GoodsIssuesPrint.cs`)
//    ۴. صورت‌حساب رسمی مشتری / طرف حساب (`CustomerStatementPrint.cs`)
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
import '../models/ops_models.dart';
import '../models/order_models.dart';
import '../models/shop_models.dart';
import 'shop_style.dart';

// ------------------------------------------------------------
//  توابع عمومی نمایش شیت‌های چاپ
// ------------------------------------------------------------

Future<void> showRepairInvoicePrintSheet(
  BuildContext context, {
  required ShopRepository repo,
  required RepairOrder repair,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RepairPrintSheet(
      repo: repo,
      initialRepair: repair,
      deliveryReceiptMode: false,
    ),
  );
}

Future<void> showRepairDeliveryReceiptPrintSheet(
  BuildContext context, {
  required ShopRepository repo,
  required RepairOrder repair,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RepairPrintSheet(
      repo: repo,
      initialRepair: repair,
      deliveryReceiptMode: true,
    ),
  );
}

Future<void> showGoodsIssuePrintSheet(
  BuildContext context, {
  required ShopRepository repo,
  required GoodsIssue issue,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GoodsIssuePrintSheet(repo: repo, initialIssue: issue),
  );
}

Future<void> showCustomerStatementPrintSheet(
  BuildContext context, {
  required ShopRepository repo,
  required Map<String, dynamic> statement,
  DateTime? from,
  DateTime? to,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CustomerStatementPrintSheet(
      repo: repo,
      statement: statement,
      from: from,
      to: to,
    ),
  );
}

// ============================================================
//  ۱ و ۲) شیت چاپ قبض پذیرش / فاکتور تعمیرات و فیش تحویل دستگاه
// ============================================================

class _RepairPrintSheet extends StatefulWidget {
  const _RepairPrintSheet({
    required this.repo,
    required this.initialRepair,
    required this.deliveryReceiptMode,
  });

  final ShopRepository repo;
  final RepairOrder initialRepair;
  final bool deliveryReceiptMode;

  @override
  State<_RepairPrintSheet> createState() => _RepairPrintSheetState();
}

class _RepairPrintSheetState extends State<_RepairPrintSheet> {
  late RepairOrder _repair;
  ShopCompanyProfile _profile = const ShopCompanyProfile();
  ShopOrder? _invoice;
  late bool _deliveryMode;
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _repair = widget.initialRepair;
    _deliveryMode = widget.deliveryReceiptMode;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    RepairOrder full = _repair;
    if (_repair.id > 0) {
      try {
        full = await widget.repo.repair(_repair.id) ?? _repair;
      } catch (_) {}
    }
    ShopCompanyProfile profile = const ShopCompanyProfile();
    try {
      profile = await widget.repo.companyProfile();
    } catch (_) {}
    ShopOrder? inv;
    if (full.hasInvoice && full.id > 0) {
      try {
        inv = await widget.repo.repairLinkedInvoice(full.id);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _repair = full;
      _profile = profile;
      _invoice = inv;
      _loading = false;
    });
  }

  String get _docTitle {
    if (_deliveryMode) return 'فیش تحویل دستگاه ${_repair.number}';
    if (_invoice != null) return 'فاکتور خدمات و تعمیرات ${_invoice!.number}';
    return 'قبض پذیرش تعمیرات ${_repair.number}';
  }

  (String html, String fileName) _buildRepairDoc() {
    final html = _deliveryMode
        ? _Phase4HtmlBuilder.buildRepairDeliveryReceipt(
            repair: _repair,
            profile: _profile,
          )
        : _Phase4HtmlBuilder.buildRepairInvoice(
            repair: _repair,
            profile: _profile,
            invoice: _invoice,
          );
    final safeNo = _repair.number.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final prefix = _deliveryMode ? 'repair_delivery' : 'repair_receipt';
    return (html, '${prefix}_$safeNo.html');
  }

  Future<File> _writeHtmlFile() async {
    final (html, fileName) = _buildRepairDoc();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(html, encoding: utf8);
    return file;
  }

  Future<void> _openForPrint() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final (html, fileName) = _buildRepairDoc();
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
      final (html, fileName) = _buildRepairDoc();
      if (await webOpenHtmlForPrint(html, fileName, share: true)) return;
      final file = await _writeHtmlFile();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/html')],
          subject: _docTitle,
          text: _docTitle,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در اشتراک‌گذاری فایل چاپ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = _profile.name.trim().isEmpty
        ? 'فروغ آریا'
        : _profile.name.trim();
    final devices = _repair.devices.isNotEmpty
        ? _repair.devices
        : [RepairDevice(deviceType: 'دستگاه', quotedPrice: _repair.quotedPrice)];
    final grandTotal = _invoice != null && !_deliveryMode
        ? _invoice!.totalAmount
        : (_repair.hasWarrantyRows
              ? _repair.totalPrice
              : (_repair.totalPrice > 0
                    ? _repair.totalPrice
                    : _repair.quotedPrice));

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
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
            _SheetTopBar(
              title: _docTitle,
              subtitle: company,
              onClose: () => Navigator.of(context).pop(),
            ),
            // سوییچ بین قبض/فاکتور و فیش تحویل کارگاهی
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment<bool>(
                    value: false,
                    icon: const Icon(Icons.receipt_long_rounded, size: 16),
                    label: Text(
                      _invoice != null ? 'فاکتور تعمیرات' : 'قبض پذیرش',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                  const ButtonSegment<bool>(
                    value: true,
                    icon: Icon(Icons.assignment_turned_in_rounded, size: 16),
                    label: Text(
                      'فیش تحویل دستگاه',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
                selected: {_deliveryMode},
                onSelectionChanged: (s) =>
                    setState(() => _deliveryMode = s.first),
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ShopColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      company,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: ShopColors.ink,
                                      ),
                                    ),
                                    Text(
                                      _deliveryMode
                                          ? 'واحد تخصصی خدمات و تعمیرات — رسید ترخیص و تحویل'
                                          : (_invoice != null
                                                ? 'فاکتور خدمات و تعمیرات'
                                                : 'قبض پذیرش و خدمات تعمیرات'),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: ShopColors.inkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ShopTag(
                                text: _deliveryMode
                                    ? _repair.number
                                    : (_invoice?.number ?? _repair.number),
                                color: _deliveryMode
                                    ? ShopColors.teal
                                    : ShopColors.indigo,
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              _kv('مشتری', _repair.partyName ?? '—'),
                              if (_repair.partyTel.trim().isNotEmpty)
                                _kv('تماس', Fa.digits(_repair.partyTel)),
                              _kv(
                                'تاریخ پذیرش',
                                Fa.date(_repair.receivedAt?.toIso8601String()),
                              ),
                              _kv(
                                'تعمیرکار',
                                _repair.technicianName ?? 'واحد فنی',
                              ),
                              _kv('وضعیت', RepairStatus.label(_repair.status)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'مشخصات دستگاه‌ها',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: ShopColors.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          for (var i = 0; i < devices.length; i++)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: ShopColors.bg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: ShopColors.line),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'دستگاه ${Fa.digits(i + 1)}: '
                                    '${devices[i].deviceType} ${devices[i].deviceModel ?? ''}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if ((devices[i].serialNumber ?? '')
                                      .trim()
                                      .isNotEmpty)
                                    Text(
                                      'سریال: ${devices[i].serialNumber}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: ShopColors.inkSoft,
                                      ),
                                    ),
                                  if ((devices[i].problemDescription ?? '')
                                      .trim()
                                      .isNotEmpty)
                                    Text(
                                      'ایراد: ${devices[i].problemDescription}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: ShopColors.inkSoft,
                                      ),
                                    ),
                                  if ((devices[i].accessories ?? '')
                                      .trim()
                                      .isNotEmpty)
                                    Text(
                                      'متعلقات: ${devices[i].accessories}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: ShopColors.teal,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 10),
                          const Text(
                            'شرح خدمات و قطعات',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: ShopColors.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (_repair.items.isEmpty)
                            const Text(
                              'سرویس و بازبینی فنی دستگاه',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: ShopColors.inkSoft,
                              ),
                            )
                          else
                            for (final it in _repair.items)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        it.description.trim().isNotEmpty
                                            ? it.description
                                            : (it.productName ??
                                                  'خدمت تعمیراتی'),
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${Fa.number(it.quantity)} × ${Fa.number(it.customerUnitPrice)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: ShopColors.inkSoft,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${Fa.number(it.rowPrice)} ریال',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _deliveryMode
                                    ? 'مبلغ کل خدمات و قطعات:'
                                    : (_invoice != null
                                          ? 'مبلغ قابل پرداخت:'
                                          : 'جمع خدمات / برآورد:'),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${Fa.number(grandTotal)} ریال',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: ShopColors.seed,
                                ),
                              ),
                            ],
                          ),
                          if (_deliveryMode) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: ShopColors.ok.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: ShopColors.ok.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Text(
                                'اقرارنامه تحویل: دستگاه به همراه کلیه متعلقات به صورت روشن، تست‌شده و سالم تحویل گرفته شد. مهلت تست کارگاهی قطعات تعویضی ۱۰ روز است.',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  height: 1.7,
                                  color: ShopColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            _PrintBottomBar(
              exporting: _exporting,
              onPrint: _openForPrint,
              onShare: _shareFile,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  ۳) شیت چاپ بیجک تحویل کالا (`GoodsIssuesPrint.cs`)
// ============================================================

class _GoodsIssuePrintSheet extends StatefulWidget {
  const _GoodsIssuePrintSheet({required this.repo, required this.initialIssue});

  final ShopRepository repo;
  final GoodsIssue initialIssue;

  @override
  State<_GoodsIssuePrintSheet> createState() => _GoodsIssuePrintSheetState();
}

class _GoodsIssuePrintSheetState extends State<_GoodsIssuePrintSheet> {
  late GoodsIssue _issue;
  ShopCompanyProfile _profile = const ShopCompanyProfile();
  String _paper = 'A4'; // A4 | A5
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _issue = widget.initialIssue;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    GoodsIssue full = _issue;
    if (_issue.id > 0) {
      try {
        full = await widget.repo.goodsIssue(_issue.id) ?? _issue;
      } catch (_) {}
    }
    ShopCompanyProfile profile = const ShopCompanyProfile();
    try {
      profile = await widget.repo.companyProfile();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _issue = full;
      _profile = profile;
      _paper = profile.printPaperSize.toUpperCase() == 'A5' ? 'A5' : 'A4';
      _loading = false;
    });
  }

  (String html, String fileName) _buildIssueDoc() {
    final html = _Phase4HtmlBuilder.buildGoodsIssue(
      issue: _issue,
      profile: _profile,
      paper: _paper,
    );
    final safeNo = _issue.number.replaceAll(RegExp(r'[^\w\-]+'), '_');
    return (html, 'goods_issue_${safeNo}_$_paper.html');
  }

  Future<File> _writeHtmlFile() async {
    final (html, fileName) = _buildIssueDoc();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(html, encoding: utf8);
    return file;
  }

  Future<void> _openForPrint() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final (html, fileName) = _buildIssueDoc();
      if (await webOpenHtmlForPrint(html, fileName, share: false)) return;
      final file = await _writeHtmlFile();
      await OpenFilex.open(file.path, type: 'text/html');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در باز کردن بیجک: $e')),
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
      final (html, fileName) = _buildIssueDoc();
      if (await webOpenHtmlForPrint(html, fileName, share: true)) return;
      final file = await _writeHtmlFile();
      final title = 'بیجک تحویل کالا ${_issue.number}';
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/html')],
          subject: title,
          text: title,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در اشتراک‌گذاری بیجک: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = _profile.name.trim().isEmpty
        ? 'فروغ آریا'
        : _profile.name.trim();
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: ShopColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            _SheetTopBar(
              title: 'چاپ بیجک تحویل کالا ${_issue.number}',
              subtitle: company,
              onClose: () => Navigator.of(context).pop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'A4',
                    icon: Icon(Icons.description_outlined, size: 16),
                    label: Text('قالب A4', style: TextStyle(fontSize: 11.5)),
                  ),
                  ButtonSegment(
                    value: 'A5',
                    icon: Icon(Icons.note_outlined, size: 16),
                    label: Text('قالب A5', style: TextStyle(fontSize: 11.5)),
                  ),
                ],
                selected: {_paper},
                onSelectionChanged: (s) => setState(() => _paper = s.first),
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ShopColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'بیجک تحویل کالا (فقط مقدار)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: ShopColors.teal,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      company,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ShopTag(
                                text: _issue.number,
                                color: ShopColors.teal,
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Wrap(
                            spacing: 14,
                            runSpacing: 6,
                            children: [
                              _kv('گیرنده کالا', _issue.partyName),
                              _kv(
                                'تاریخ',
                                Fa.date(
                                  _issue.date?.toIso8601String(),
                                  time: false,
                                ),
                              ),
                              _kv('تعداد ردیف', Fa.digits(_issue.lineCount)),
                              _kv(
                                'جمع مقدار',
                                Fa.number(_issue.totalQuantity),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          for (var i = 0; i < _issue.lines.length; i++)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: ShopColors.bg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '${Fa.digits(i + 1)}. ',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: ShopColors.inkFaint,
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _issue.lines[i].productName,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if ((_issue.lines[i].note ?? '')
                                            .trim()
                                            .isNotEmpty)
                                          Text(
                                            _issue.lines[i].note!,
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              color: ShopColors.inkSoft,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  ShopTag(
                                    text: Fa.number(_issue.lines[i].quantity),
                                    color: ShopColors.seed,
                                  ),
                                ],
                              ),
                            ),
                          if ((_issue.description ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'ملاحظات: ${_issue.description}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: ShopColors.inkSoft,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            _PrintBottomBar(
              exporting: _exporting,
              onPrint: _openForPrint,
              onShare: _shareFile,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  ۴) شیت چاپ رسمی صورت‌حساب مشتری / طرف حساب (`CustomerStatementPrint.cs`)
// ============================================================

class _CustomerStatementPrintSheet extends StatefulWidget {
  const _CustomerStatementPrintSheet({
    required this.repo,
    required this.statement,
    this.from,
    this.to,
  });

  final ShopRepository repo;
  final Map<String, dynamic> statement;
  final DateTime? from;
  final DateTime? to;

  @override
  State<_CustomerStatementPrintSheet> createState() =>
      _CustomerStatementPrintSheetState();
}

class _CustomerStatementPrintSheetState
    extends State<_CustomerStatementPrintSheet> {
  ShopCompanyProfile _profile = const ShopCompanyProfile();
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await widget.repo.companyProfile();
      if (!mounted) return;
      setState(() {
        _profile = p;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
  static String _s(dynamic v) {
    final s = v?.toString();
    return (s == null || s == 'null') ? '' : s.trim();
  }

  String get _partyName {
    final s = _s(widget.statement['partyName'] ?? widget.statement['PartyName']);
    return s.isEmpty ? 'طرف حساب' : s;
  }

  (String html, String fileName) _buildStatementDoc() {
    final html = _Phase4HtmlBuilder.buildCustomerStatement(
      statement: widget.statement,
      profile: _profile,
      from: widget.from,
      to: widget.to,
    );
    final partyId =
        (widget.statement['partyId'] ?? widget.statement['PartyId'] ?? 0)
            .toString();
    return (html, 'party_statement_$partyId.html');
  }

  Future<File> _writeHtmlFile() async {
    final (html, fileName) = _buildStatementDoc();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(html, encoding: utf8);
    return file;
  }

  Future<void> _openForPrint() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final (html, fileName) = _buildStatementDoc();
      if (await webOpenHtmlForPrint(html, fileName, share: false)) return;
      final file = await _writeHtmlFile();
      await OpenFilex.open(file.path, type: 'text/html');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در باز کردن صورت‌حساب: $e')),
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
      final (html, fileName) = _buildStatementDoc();
      if (await webOpenHtmlForPrint(html, fileName, share: true)) return;
      final file = await _writeHtmlFile();
      final title = 'صورت‌حساب رسمی $_partyName';
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/html')],
          subject: title,
          text: title,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در اشتراک‌گذاری صورت‌حساب: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = _profile.name.trim().isEmpty
        ? 'فروشگاه'
        : _profile.name.trim();
    final opening = _d(
      widget.statement['openingBalance'] ?? widget.statement['OpeningBalance'],
    );
    final closing = _d(
      widget.statement['closingBalance'] ?? widget.statement['ClosingBalance'],
    );
    final totalDebit = _d(
      widget.statement['totalDebit'] ?? widget.statement['TotalDebit'],
    );
    final totalCredit = _d(
      widget.statement['totalCredit'] ?? widget.statement['TotalCredit'],
    );
    final rawRows = widget.statement['rows'] ?? widget.statement['Rows'];
    final rows = rawRows is List
        ? rawRows
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : const <Map<String, dynamic>>[];

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
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
            _SheetTopBar(
              title: 'چاپ رسمی صورت‌حساب — $_partyName',
              subtitle: company,
              onClose: () => Navigator.of(context).pop(),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ShopColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 14,
                            runSpacing: 8,
                            children: [
                              _kv('طرف حساب', _partyName),
                              _kv(
                                'مانده اول دوره',
                                _Phase4HtmlBuilder.balanceText(opening),
                              ),
                              _kv(
                                'گردش بدهکار',
                                '${Fa.number(totalDebit)} ریال',
                              ),
                              _kv(
                                'گردش بستانکار',
                                '${Fa.number(totalCredit)} ریال',
                              ),
                              _kv(
                                'مانده پایان دوره',
                                _Phase4HtmlBuilder.balanceText(closing),
                              ),
                              _kv('تعداد ردیف گردش', Fa.digits(rows.length)),
                            ],
                          ),
                          const Divider(height: 20),
                          for (final r in rows.take(25))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 68,
                                    child: Text(
                                      Fa.date(
                                        _s(r['date'] ?? r['Date']),
                                        time: false,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: ShopColors.inkSoft,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _s(r['title'] ?? r['Title']),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _Phase4HtmlBuilder.balanceText(
                                      _d(r['balance'] ?? r['Balance']),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: ShopColors.indigo,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (rows.length > 25)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'و ${Fa.digits(rows.length - 25)} ردیف دیگر در فایل چاپی کامل قرار دارد.',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: ShopColors.inkFaint,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            _PrintBottomBar(
              exporting: _exporting,
              onPrint: _openForPrint,
              onShare: _shareFile,
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
//  ویجت‌های مشترک بالای شیت و نوار اکشن پایین
// ------------------------------------------------------------

Widget _kv(String k, String v) => RichText(
  text: TextSpan(
    style: const TextStyle(fontSize: 11.5, fontFamily: 'Vazirmatn'),
    children: [
      TextSpan(
        text: '$k: ',
        style: const TextStyle(color: ShopColors.inkFaint),
      ),
      TextSpan(
        text: v,
        style: const TextStyle(
          color: ShopColors.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  ),
);

class _SheetTopBar extends StatelessWidget {
  const _SheetTopBar({
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
    child: Column(
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: ShopColors.line,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: ShopColors.ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: ShopColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ],
    ),
  );
}

class _PrintBottomBar extends StatelessWidget {
  const _PrintBottomBar({
    required this.exporting,
    required this.onPrint,
    required this.onShare,
  });

  final bool exporting;
  final VoidCallback onPrint;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ShopColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: exporting ? null : onShare,
              icon: const Icon(Icons.share_rounded, size: 17),
              label: const Text('اشتراک‌گذاری'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: exporting ? null : onPrint,
              style: FilledButton.styleFrom(backgroundColor: ShopColors.seed),
              icon: exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.print_rounded, size: 18),
              label: const Text('چاپ / نمایش رسمی'),
            ),
          ),
        ],
      ),
    ),
  );
}

// ============================================================
//  تولیدکنندهٔ HTML خودبسندهٔ چاپ — منطبق با کلاس‌های C# وب
// ============================================================

class _Phase4HtmlBuilder {
  static String _esc(String? s) =>
      const HtmlEscape().convert((s ?? '').trim());

  static String balanceText(double v) {
    if (v == 0) return '۰ — تسویه';
    final abs = Fa.number(v.abs());
    return v > 0 ? '$abs بدهکار' : '$abs بستانکار';
  }

  static List<RepairDevice> _devicesFor(RepairOrder r) {
    if (r.devices.isNotEmpty) return r.devices;
    return [RepairDevice(deviceType: 'دستگاه', quotedPrice: r.quotedPrice)];
  }

  static String _deviceLabel(RepairDevice d) =>
      (d.deviceModel ?? '').trim().isEmpty
      ? (d.deviceType.trim().isEmpty ? 'دستگاه' : d.deviceType.trim())
      : '${d.deviceType.trim()} ${d.deviceModel!.trim()}';

  static bool _matchesLine(RepairItem item, OrderLine line) {
    if ((item.productId ?? 0) > 0) {
      return item.productId == line.productId &&
          item.quantity == line.quantity &&
          item.price == line.price;
    }
    return (line.quantity == item.quantity && line.price == item.price) ||
        (line.quantity == 1 && line.price == item.price * item.quantity);
  }

  /// آینهٔ دقیق `RepairInvoicePrint.cs`
  static String buildRepairInvoice({
    required RepairOrder repair,
    required ShopCompanyProfile profile,
    ShopOrder? invoice,
  }) {
    final company = profile.name.trim().isEmpty
        ? 'فروغ آریا'
        : profile.name.trim();
    final hasInvoice = invoice != null;
    final devices = _devicesFor(repair);
    final phone = repair.partyTel;
    final sb = StringBuffer();
    sb.write('<!doctype html><html lang="fa" dir="rtl"><head><meta charset="utf-8">');
    sb.write('<meta name="viewport" content="width=device-width,initial-scale=1">');
    sb.write('<title>${hasInvoice ? 'فاکتور خدمات و تعمیرات ${_esc(invoice.number)}' : 'قبض پذیرش تعمیرات ${_esc(repair.number)}'}</title>');
    sb.write('<style>$_repairInvoiceCss</style></head><body><main class="sheet">');
    sb.write('<header class="header"><div class="brand"><div class="mark">ت</div><div>');
    sb.write('<div class="company">${_esc(company)}</div>');
    sb.write('<div class="caption">${hasInvoice ? 'فاکتور خدمات و تعمیرات' : 'قبض پذیرش و خدمات تعمیرات'}</div>');
    sb.write('</div></div>');
    sb.write('<div class="invoice-stamp"><span>${hasInvoice ? 'فاکتور فروش' : 'قبض پذیرش'}</span><strong>${_esc(hasInvoice ? invoice.number : repair.number)}</strong></div>');
    sb.write('</header>');

    sb.write('<section class="meta">');
    _meta(sb, 'شماره پذیرش', repair.number);
    if (hasInvoice) {
      _meta(sb, 'شماره فاکتور', invoice.number);
      _meta(sb, 'تاریخ فاکتور', Fa.date(invoice.date?.toIso8601String(), time: false));
    }
    _meta(sb, 'تاریخ پذیرش', Fa.date(repair.receivedAt?.toIso8601String(), time: false));
    _meta(sb, 'تعمیرکار', (repair.technicianName ?? '').trim().isEmpty ? '—' : repair.technicianName!);
    _meta(sb, 'وضعیت', RepairStatus.label(repair.status));
    sb.write('</section>');

    sb.write('<section class="party"><div class="party-info"><div class="eyebrow">${hasInvoice ? 'صورتحساب برای' : 'پذیرش از / مشتری'}</div>');
    sb.write('<strong>${_esc(repair.partyName ?? invoice?.partyName ?? 'مشتری')}</strong>');
    if (phone.trim().isNotEmpty) {
      sb.write('<span class="phone" dir="ltr">${_esc(phone)}</span>');
    }
    sb.write('</div><div class="party-note">ارائهٔ این قبض هنگام پیگیری و تحویل دستگاه الزامی است.</div></section>');

    sb.write('<section class="section"><h3>۱. دستگاه‌های پذیرش‌شده (${Fa.digits(devices.length)} دستگاه)</h3>');
    for (var i = 0; i < devices.length; i++) {
      final d = devices[i];
      sb.write('<article class="device"><div><strong>${Fa.digits(i + 1)}. ${_esc(_deviceLabel(d))}</strong></div>');
      if (d.quotedPrice > 0) {
        sb.write('<div class="device-detail">برآورد اولیه: <b>${Fa.number(d.quotedPrice)} ریال</b></div>');
      }
      if ((d.serialNumber ?? '').trim().isNotEmpty) {
        sb.write('<div class="device-detail">سریال: <b dir="ltr">${_esc(d.serialNumber)}</b></div>');
      }
      if ((d.problemDescription ?? '').trim().isNotEmpty) {
        sb.write('<div class="device-detail">ایراد اعلامی: <b>${_esc(d.problemDescription)}</b></div>');
      }
      if ((d.accessories ?? '').trim().isNotEmpty) {
        sb.write('<div class="device-detail">لوازم همراه: <b>${_esc(d.accessories)}</b></div>');
      }
      sb.write('</article>');
    }
    sb.write('</section>');

    sb.write('<section class="section"><h3>۲. شرح خدمات و قطعات</h3>');
    sb.write('<table><thead><tr><th>ردیف</th><th>شرح</th><th>تعداد</th><th>فی (ریال)</th><th>مبلغ (ریال)</th></tr></thead><tbody>');
    if (hasInvoice) {
      final unmatched = repair.items
          .where((i) => i.customerUnitPrice > 0)
          .toList();
      for (var i = 0; i < invoice.lines.length; i++) {
        final line = invoice.lines[i];
        final idx = unmatched.indexWhere((it) => _matchesLine(it, line));
        final RepairItem? matched = idx >= 0 ? unmatched.removeAt(idx) : null;
        final desc = (matched?.description ?? '').trim().isNotEmpty
            ? matched!.description
            : (line.productName.trim().isEmpty
                  ? 'خدمت تعمیراتی'
                  : line.productName);
        sb.write('<tr><td>${Fa.digits(i + 1)}</td><td><strong>${_esc(desc)}</strong></td>');
        sb.write('<td>${Fa.number(line.quantity)}</td><td>${Fa.number(line.price)}</td><td><strong>${Fa.number(line.total)}</strong></td></tr>');
      }
      if (invoice.lines.isEmpty) {
        sb.write('<tr><td colspan="5" class="empty">ردیفی ثبت نشده است.</td></tr>');
      }
    } else {
      for (var i = 0; i < repair.items.length; i++) {
        final it = repair.items[i];
        final desc = it.description.trim().isNotEmpty
            ? it.description
            : (it.productName ?? 'خدمت تعمیراتی');
        sb.write('<tr><td>${Fa.digits(i + 1)}</td><td><strong>${_esc(desc)}</strong></td>');
        sb.write('<td>${Fa.number(it.quantity)}</td><td>${Fa.number(it.customerUnitPrice)}</td><td><strong>${Fa.number(it.rowPrice)}</strong></td></tr>');
      }
      if (repair.items.isEmpty) {
        sb.write('<tr><td colspan="5" class="empty">دستگاه در مرحلهٔ عیب‌یابی اولیه است.</td></tr>');
      }
    }
    sb.write('</tbody></table></section>');

    final totalAmount = hasInvoice
        ? invoice.totalAmount
        : (repair.hasWarrantyRows
              ? repair.totalPrice
              : (repair.totalPrice > 0
                    ? repair.totalPrice
                    : repair.quotedPrice));
    final totalLabel = hasInvoice
        ? 'مبلغ قابل پرداخت'
        : (repair.totalPrice > 0 || repair.hasWarrantyRows
              ? 'مجموع خدمات و قطعات'
              : 'برآورد اولیه هزینه');
    sb.write('<section class="grand-total"><span>$totalLabel</span><strong>${Fa.number(totalAmount)} ریال</strong></section>');
    if ((repair.note ?? '').trim().isNotEmpty) {
      sb.write('<div class="note-box">یادداشت پذیرش: <strong>${_esc(repair.note)}</strong></div>');
    }
    sb.write('<div class="terms"><b>شرایط و مقررات پذیرش و تحویل:</b>');
    sb.write('<div>۱. ارائه اصل این قبض هنگام تحویل گرفتن دستگاه الزامی است.</div>');
    sb.write('<div>۲. مرکز هیچ‌گونه مسئولیتی در قبال حفظ داده‌ها و اطلاعات شخصی روی دستگاه ندارد.</div>');
    sb.write('<div>۳. حداکثر مهلت مراجعه جهت تحویل گرفتن دستگاه ۳۰ روز کاری پس از اعلام آماده بودن است.</div></div>');
    sb.write('<section class="signatures"><div>امضای مشتری / تحویل‌دهنده</div><div>مهر و امضای واحد پذیرش و تعمیرات</div></section>');
    sb.write('<footer>${_esc(company)} • چاپ‌شده در ${Fa.date(DateTime.now().toIso8601String())}</footer>');
    sb.write('</main><script>window.onload=function(){setTimeout(function(){window.print();},350);};</script></body></html>');
    return sb.toString();
  }

  /// آینهٔ دقیق `RepairDeliveryReceiptPrint.cs`
  static String buildRepairDeliveryReceipt({
    required RepairOrder repair,
    required ShopCompanyProfile profile,
  }) {
    final company = profile.name.trim().isEmpty
        ? 'فروغ آریا'
        : profile.name.trim();
    final devices = _devicesFor(repair);
    final deliveryDate = repair.deliveredAt ?? DateTime.now();
    final grandTotal = repair.hasWarrantyRows
        ? repair.totalPrice
        : (repair.totalPrice > 0 ? repair.totalPrice : repair.quotedPrice);
    final sb = StringBuffer();
    sb.write('<!doctype html><html lang="fa" dir="rtl"><head><meta charset="utf-8">');
    sb.write('<meta name="viewport" content="width=device-width,initial-scale=1">');
    sb.write('<title>فیش تحویل دستگاه ${_esc(repair.number)}</title>');
    sb.write('<style>$_repairInvoiceCss</style></head><body><main class="sheet">');
    sb.write('<header class="header"><div class="brand"><div class="mark" style="background:#0284c7">ت</div><div>');
    sb.write('<div class="company">${_esc(company)}</div>');
    sb.write('<div class="caption">واحد تخصصی خدمات و تعمیرات سخت‌افزار و تجهیزات</div></div></div>');
    sb.write('<div class="invoice-stamp"><span>رسید ترخیص و تحویل</span><strong>فیش تحویل ${_esc(repair.number)}</strong></div></header>');

    sb.write('<section class="meta">');
    _meta(sb, 'شماره سند پذیرش', repair.number);
    _meta(sb, 'تاریخ پذیرش', Fa.date(repair.receivedAt?.toIso8601String()));
    _meta(sb, 'تاریخ تحویل دستگاه', Fa.date(deliveryDate.toIso8601String()));
    _meta(sb, 'کارشناس فنی', (repair.technicianName ?? '').trim().isEmpty ? 'واحد خدمات فنی' : repair.technicianName!);
    sb.write('</section>');

    sb.write('<section class="party"><div class="party-info"><strong>تحویل‌گیرنده: ${_esc(repair.partyName ?? 'مشتری گرامی')}</strong>');
    if (repair.partyTel.trim().isNotEmpty) {
      sb.write('<span class="phone" dir="ltr">${_esc(repair.partyTel)}</span>');
    }
    sb.write('</div><div class="party-note">وضعیت: <b>${repair.deliveredAt != null ? 'تحویل شده به مشتری' : 'آماده تحویل و ترخیص'}</b></div></section>');

    sb.write('<section class="section"><h3>مشخصات دستگاه و متعلقات تحویل‌شده</h3>');
    for (var i = 0; i < devices.length; i++) {
      final d = devices[i];
      sb.write('<article class="device"><div><strong>دستگاه ${Fa.digits(i + 1)}: ${_esc(_deviceLabel(d))}</strong></div>');
      if ((d.serialNumber ?? '').trim().isNotEmpty) {
        sb.write('<div class="device-detail">شماره سریال: <b dir="ltr">${_esc(d.serialNumber)}</b></div>');
      }
      if ((d.problemDescription ?? '').trim().isNotEmpty) {
        sb.write('<div class="device-detail">ایراد اظهارشده: <b>${_esc(d.problemDescription)}</b></div>');
      }
      if ((d.accessories ?? '').trim().isNotEmpty) {
        sb.write('<div class="device-detail">لوازم و متعلقات همراه: <b>${_esc(d.accessories)}</b></div>');
      }
      sb.write('</article>');
    }
    sb.write('</section>');

    sb.write('<section class="section"><h3>شرح اقدامات فنی و قطعات مصرفی</h3>');
    sb.write('<table><thead><tr><th>ردیف</th><th>شرح خدمات و قطعات</th><th>تعداد</th><th>اجرت/فی</th><th>جمع (ریال)</th></tr></thead><tbody>');
    for (var i = 0; i < repair.items.length; i++) {
      final it = repair.items[i];
      final desc = it.description.trim().isNotEmpty
          ? it.description
          : (it.productName ?? 'خدمات تعمیراتی');
      sb.write('<tr><td>${Fa.digits(i + 1)}</td><td><strong>${_esc(desc)}</strong></td>');
      sb.write('<td>${Fa.number(it.quantity)}</td><td>${Fa.number(it.customerUnitPrice)}</td><td><strong>${Fa.number(it.rowPrice)}</strong></td></tr>');
    }
    if (repair.items.isEmpty) {
      sb.write('<tr><td colspan="5" class="empty">سرویس و بازبینی فنی دستگاه طبق درخواست انجام گرفت.</td></tr>');
    }
    sb.write('</tbody></table></section>');

    sb.write('<section class="grand-total"><span>مبلغ کل خدمات و قطعات (${repair.hasInvoice ? 'طبق فاکتور فروش' : (repair.hasWarrantyRows ? 'گارانتی / بدون فاکتور' : 'تسویه کارگاهی')})</span><strong>${Fa.number(grandTotal)} ریال</strong></section>');
    sb.write('<div class="terms"><b>اقرارنامه و تاییدیه تحویل دستگاه توسط مشتری:</b>');
    sb.write('<div>اینجانب تایید و اقرار می‌نمایم که دستگاه مندرج در این فیش را به همراه کلیه لوازم و متعلقات، به صورت <b>روشن، تست‌شده، سالم و بدون نقص ظاهری</b> تحویل گرفتم.</div>');
    sb.write('<div style="margin-top:6px"><b>شرایط گارانتی:</b> ۱. قطعات تعویضی و خدمات انجام‌شده دارای ۱۰ روز مهلت تست و ضمانت کارگاهی می‌باشند. ۲. صدمات فیزیکی، نوسان برق، آب‌خوردگی و باز شدن توسط غیرمجاز خارج از ضمانت است. ۳. ارائه اصل فیش الزامی است.</div></div>');
    sb.write('<section class="signatures"><div>نام و امضای تحویل‌گیرنده (مشتری)</div><div>مهر و امضای واحد فنی (${_esc(company)})</div></section>');
    sb.write('<footer>فیش تحویل کارگاهی • ${_esc(company)} • ${Fa.date(DateTime.now().toIso8601String())}</footer>');
    sb.write('</main><script>window.onload=function(){setTimeout(function(){window.print();},350);};</script></body></html>');
    return sb.toString();
  }

  /// آینهٔ دقیق `GoodsIssuesPrint.cs`
  static String buildGoodsIssue({
    required GoodsIssue issue,
    required ShopCompanyProfile profile,
    required String paper,
  }) {
    final company = profile.name.trim().isEmpty
        ? 'فروغ آریا'
        : profile.name.trim();
    final a5 = paper.toUpperCase() == 'A5';
    final logo = (profile.logoDataUrl ?? '').startsWith('data:image/')
        ? '<img src="${_esc(profile.logoDataUrl)}" alt="لوگو" style="max-height:48px;max-width:90px">'
        : '<div class="mark" style="background:#0d9488">ب</div>';
    final sb = StringBuffer();
    sb.write('<!doctype html><html lang="fa" dir="rtl"><head><meta charset="utf-8">');
    sb.write('<meta name="viewport" content="width=device-width,initial-scale=1">');
    sb.write('<title>بیجک تحویل کالا ${_esc(issue.number)}</title>');
    sb.write('<style>@page{size:${a5 ? 'A5' : 'A4'};margin:${a5 ? '6mm' : '10mm'}}$_repairInvoiceCss</style></head><body>');
    sb.write('<main class="sheet" style="max-width:${a5 ? '136mm' : '190mm'}">');
    sb.write('<header class="header"><div class="brand">$logo<div><div class="caption">بیجک تحویل کالا</div><div class="company">${_esc(company)}</div></div></div>');
    sb.write('<div class="invoice-stamp"><span>شماره بیجک: ${_esc(issue.number)}</span><strong>${Fa.date(issue.date?.toIso8601String(), time: false)}</strong></div></header>');
    sb.write('<section class="party"><div class="party-info"><div class="eyebrow">گیرندهٔ کالا</div><strong>${_esc(issue.partyName)}</strong></div>');
    sb.write('<div class="party-note">${Fa.digits(issue.lineCount)} ردیف · جمع مقدار: <b>${Fa.number(issue.totalQuantity)}</b></div></section>');
    sb.write('<table><thead><tr><th style="width:9%">ردیف</th><th>شرح کالا</th><th style="width:18%">تعداد</th><th style="width:26%">ملاحظات</th></tr></thead><tbody>');
    for (var i = 0; i < issue.lines.length; i++) {
      final l = issue.lines[i];
      sb.write('<tr><td>${Fa.digits(i + 1)}</td><td><strong>${_esc(l.productName)}</strong></td>');
      sb.write('<td><strong>${Fa.number(l.quantity)}</strong></td><td>${_esc((l.note ?? '').trim().isEmpty ? '-' : l.note)}</td></tr>');
    }
    sb.write('</tbody></table>');
    if ((issue.description ?? '').trim().isNotEmpty) {
      sb.write('<div class="note-box">توضیحات بیجک: <strong>${_esc(issue.description)}</strong></div>');
    }
    sb.write('<section class="signatures"><div><strong>امضای تحویل‌دهنده</strong><br><small>نام و امضا</small></div><div><strong>امضای تحویل‌گیرنده</strong><br><small>نام، مهر و امضا</small></div></section>');
    sb.write('<footer>بیجک تحویل کالا • ${_esc(company)}</footer>');
    sb.write('</main><script>window.onload=function(){setTimeout(function(){window.print();},350);};</script></body></html>');
    return sb.toString();
  }

  /// آینهٔ دقیق `CustomerStatementPrint.cs`
  static String buildCustomerStatement({
    required Map<String, dynamic> statement,
    required ShopCompanyProfile profile,
    DateTime? from,
    DateTime? to,
  }) {
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
    String s(dynamic v) =>
        (v == null || v.toString() == 'null') ? '' : v.toString().trim();

    final company = profile.name.trim().isEmpty
        ? 'فروشگاه'
        : profile.name.trim();
    final partyName = s(statement['partyName'] ?? statement['PartyName']);
    final mobile = s(statement['mobile'] ?? statement['Mobile']);
    final opening = d(
      statement['openingBalance'] ?? statement['OpeningBalance'],
    );
    final closing = d(
      statement['closingBalance'] ?? statement['ClosingBalance'],
    );
    final saleGoods = d(
      statement['saleGoodsTotal'] ?? statement['SaleGoodsTotal'],
    );
    final saleDiscount = d(
      statement['saleIssuedDiscountTotal'] ??
          statement['SaleIssuedDiscountTotal'],
    );
    final chequeIncome = d(
      statement['saleChequeIncomeTotal'] ?? statement['SaleChequeIncomeTotal'],
    );
    final totalDebit = d(statement['totalDebit'] ?? statement['TotalDebit']);
    final totalCredit = d(statement['totalCredit'] ?? statement['TotalCredit']);
    final rawRows = statement['rows'] ?? statement['Rows'];
    final rows = rawRows is List
        ? rawRows
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : const <Map<String, dynamic>>[];

    final fromTxt = from != null
        ? Fa.date(from.toIso8601String(), time: false)
        : 'ابتدا';
    final toTxt = to != null
        ? Fa.date(to.toIso8601String(), time: false)
        : 'آخرین گردش ثبت‌شده';

    final sb = StringBuffer();
    sb.write('<!doctype html><html lang="fa" dir="rtl"><head><meta charset="utf-8">');
    sb.write('<meta name="viewport" content="width=device-width,initial-scale=1">');
    sb.write('<title>صورت‌حساب مشتری ${_esc(partyName)}</title>');
    sb.write('<style>@page{size:A4 portrait;margin:10mm}$_repairInvoiceCss</style></head><body>');
    sb.write('<main class="sheet" style="max-width:190mm">');
    sb.write('<header class="header"><div><div class="company">${_esc(company)}</div><div class="caption">صورت‌حساب رسمی طرف حساب</div></div>');
    sb.write('<div class="invoice-stamp"><span>بازه گزارش</span><strong>از $fromTxt تا $toTxt</strong></div></header>');

    sb.write('<section class="meta">');
    _meta(sb, 'طرف حساب', partyName.isEmpty ? '—' : partyName);
    if (mobile.isNotEmpty) _meta(sb, 'شماره تماس', Fa.digits(mobile));
    _meta(sb, 'مانده اول دوره', balanceText(opening));
    _meta(sb, 'مانده پایان دوره', balanceText(closing));
    sb.write('</section>');

    sb.write('<section class="meta">');
    _meta(sb, 'کالا و خدمات خالص دوره', '${Fa.number(saleGoods)} ریال');
    _meta(sb, 'تخفیف فاکتورهای صادرشده', '${Fa.number(saleDiscount)} ریال');
    _meta(sb, 'تاخیر تادیه چک', '${Fa.number(chequeIncome)} ریال');
    _meta(sb, 'جمع بدهکار دوره', '${Fa.number(totalDebit)} ریال');
    _meta(sb, 'جمع بستانکار دوره', '${Fa.number(totalCredit)} ریال');
    sb.write('</section>');

    sb.write('<div class="note-box">تخفیف در مبلغ فاکتور لحاظ شده و دوباره از مانده کسر نمی‌شود. برگشت کالا و تعدیل سود در تاریخ واقعی خود آمده‌اند. تحویل چک، تا زمان وصول، پرداخت محسوب نمی‌شود.</div>');
    sb.write('<table><thead><tr><th style="width:12%">تاریخ</th><th style="width:13%">شماره سند</th><th>شرح گردش</th><th style="width:14%">بدهکار</th><th style="width:14%">بستانکار</th><th style="width:17%">مانده</th></tr></thead><tbody>');
    for (final row in rows) {
      final dateStr = s(row['date'] ?? row['Date']);
      final docNo = s(row['documentNumber'] ?? row['DocumentNumber']);
      final title = s(row['title'] ?? row['Title']);
      final desc = s(row['description'] ?? row['Description']);
      final disc = row['saleInvoiceDiscount'] ?? row['SaleInvoiceDiscount'];
      final debit = d(row['debit'] ?? row['Debit']);
      final credit = d(row['credit'] ?? row['Credit']);
      final bal = d(row['balance'] ?? row['Balance']);
      sb.write('<tr><td>${Fa.date(dateStr, time: false)}</td>');
      sb.write('<td>${_esc(docNo.isEmpty ? '—' : docNo)}</td>');
      sb.write('<td><strong>${_esc(title)}</strong>');
      if (desc.isNotEmpty) sb.write('<br><small style="color:#64748b">${_esc(desc)}</small>');
      if (disc is num && disc > 0) {
        sb.write('<br><small style="color:#64748b">تخفیف فاکتور: ${Fa.number(disc.toDouble())} ریال (لحاظ‌شده)</small>');
      }
      sb.write('</td>');
      sb.write('<td>${debit == 0 ? '—' : Fa.number(debit)}</td>');
      sb.write('<td>${credit == 0 ? '—' : Fa.number(credit)}</td>');
      sb.write('<td><strong>${balanceText(bal)}</strong></td></tr>');
    }
    if (rows.isEmpty) {
      sb.write('<tr><td colspan="6" class="empty">در این بازه گردشی ثبت نشده است.</td></tr>');
    }
    sb.write('</tbody></table>');
    sb.write('<footer>همه مبالغ به ریال است. • ${_esc(company)}</footer>');
    sb.write('</main><script>window.onload=function(){setTimeout(function(){window.print();},350);};</script></body></html>');
    return sb.toString();
  }

  static void _meta(StringBuffer sb, String label, String value) {
    sb.write('<div class="meta-item"><span>${_esc(label)}</span><strong>${_esc(value)}</strong></div>');
  }

  static const String _repairInvoiceCss = '''
* { box-sizing:border-box; }
body { margin:0; padding:10px; background:#fff; color:#0f172a; font-family:Tahoma,'Segoe UI',sans-serif; font-size:11px; line-height:1.6; }
.sheet { max-width:148mm; margin:0 auto; }
.header { display:flex; justify-content:space-between; align-items:center; gap:12px; padding-bottom:10px; border-bottom:2px solid #2563eb; }
.brand { display:flex; align-items:center; gap:10px; }
.mark { width:40px; height:40px; display:flex; align-items:center; justify-content:center; border-radius:10px; background:#2563eb; color:#fff; font-size:20px; font-weight:800; }
.company { color:#172554; font-size:16px; font-weight:800; }
.caption { color:#64748b; font-size:10px; }
.invoice-stamp { padding:6px 12px; border:1px solid #bfdbfe; border-radius:10px; background:#eff6ff; color:#1d4ed8; text-align:center; }
.invoice-stamp span { display:block; font-size:9px; }
.invoice-stamp strong { font-size:13px; }
.meta { display:grid; grid-template-columns:repeat(auto-fit,minmax(115px,1fr)); gap:6px; margin:10px 0; }
.meta-item { padding:6px 8px; border:1px solid #e2e8f0; border-radius:8px; background:#f8fafc; }
.meta-item span,.eyebrow { display:block; color:#64748b; font-size:9px; }
.meta-item strong { color:#0f172a; font-size:10.5px; }
.party { display:flex; flex-wrap:wrap; justify-content:space-between; align-items:center; gap:8px; margin-bottom:10px; padding:8px 12px; border:1px solid #c7d2fe; border-radius:10px; background:#eef2ff; }
.phone { margin-right:8px; color:#475569; font-size:10.5px; }
.party-note { color:#475569; font-size:9.5px; }
.section { margin-top:10px; }
.section h3 { margin:0 0 6px; font-size:11.5px; color:#1e293b; }
.device { border:1px solid #cbd5e1; border-radius:8px; padding:7px 10px; margin-bottom:6px; }
.device-detail { font-size:10px; color:#334155; margin-top:2px; }
table { width:100%; border-collapse:collapse; margin-top:6px; }
th { background:#1e293b; color:#fff; padding:6px; text-align:right; font-size:10px; }
td { padding:6px; border-bottom:1px solid #e2e8f0; vertical-align:top; font-size:10.5px; }
tbody tr:nth-child(even) { background:#f8fafc; }
.empty { text-align:center; color:#64748b; padding:14px; }
.grand-total { display:flex; justify-content:space-between; align-items:center; margin-top:10px; padding:9px 12px; border-radius:10px; background:#eff6ff; border:1px solid #bfdbfe; font-size:12px; }
.grand-total strong { color:#1d4ed8; font-size:14px; }
.note-box { margin-top:8px; padding:7px 10px; border-radius:8px; background:#f8fafc; border:1px solid #e2e8f0; font-size:10px; color:#334155; }
.terms { margin-top:10px; padding:8px 10px; border:1px dashed #cbd5e1; border-radius:8px; font-size:9.5px; color:#334155; }
.signatures { display:grid; grid-template-columns:1fr 1fr; gap:14px; margin-top:14px; }
.signatures > div { height:64px; padding:8px; border:1px dashed #94a3b8; border-radius:8px; text-align:center; font-size:10px; color:#334155; }
footer { margin-top:10px; padding-top:6px; border-top:1px solid #e2e8f0; text-align:center; color:#64748b; font-size:9px; }
@media print { body { padding:0; -webkit-print-color-adjust:exact; print-color-adjust:exact; } }
''';
}
