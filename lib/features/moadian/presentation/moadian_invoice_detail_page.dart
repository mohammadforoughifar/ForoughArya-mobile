import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/moadian_calc.dart';
import '../data/moadian_perms.dart';
import '../data/moadian_repository.dart';
import '../models/moadian_models.dart';
import 'moadian_invoice_form_page.dart';
import 'moadian_style.dart';

class MoadianInvoiceDetailPage extends StatefulWidget {
  const MoadianInvoiceDetailPage({
    super.key,
    required this.invoiceId,
    this.cpInfoId,
    this.onJumpToReferenceTax,
  });

  final int invoiceId;
  final int? cpInfoId;
  final ValueChanged<String>? onJumpToReferenceTax;

  @override
  State<MoadianInvoiceDetailPage> createState() =>
      _MoadianInvoiceDetailPageState();
}

class _MoadianInvoiceDetailPageState extends State<MoadianInvoiceDetailPage> {
  late final MoadianRepository _repo = MoadianRepository(
    context.read<ApiClient>(),
  );

  MoadianInvoice? _inv;
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;
  String? _error;
  String? _bannerMessage;
  bool _bannerUncertain = false;

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
      final inv = await _repo.getInvoice(
        widget.invoiceId,
        cpInfoId: widget.cpInfoId,
      );
      if (!mounted) return;
      setState(() {
        _inv = inv;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String _prettyJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return raw;
    }
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    Color confirmColor = MoadianColors.primary,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          content: Text(
            body,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.65,
              color: MoadianColors.inkSoft,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: confirmColor),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _onPreviewJson() async {
    final inv = _inv;
    if (inv == null || _busy) return;
    setState(() => _busy = true);
    try {
      final res = await _repo.previewSendInvoice(inv);
      if (!mounted) return;
      final txt = res.requestJson?.trim().isNotEmpty == true
          ? _prettyJson(res.requestJson!)
          : (res.data != null
                ? _prettyJson(jsonEncode(res.data))
                : (res.message ?? 'بدون خروجی JSON'));
      await showMoadianJsonSheet(
        context,
        title: 'پیش‌نمایش بستهٔ ارسالی به سامانه مودیان',
        subtitle: res.message,
        jsonText: txt,
      );
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onSendToMoadian() async {
    final inv = _inv;
    if (inv == null || _busy) return;
    final ok = await _confirm(
      title: 'ارسال رسمی صورتحساب به سامانه مودیان',
      body:
          'صورتحساب شماره ${Fa.digits(inv.numberInvoice ?? inv.effectiveId)} امضا و برای کارپوشهٔ مالیاتی ارسال می‌شود. آیا ادامه می‌دهید؟',
      confirmLabel: 'تأیید و ارسال',
    );
    if (!ok) return;

    setState(() => _busy = true);
    try {
      final res = await _repo.sendInvoice(inv);
      if (!mounted) return;
      _changed = true;
      setState(() {
        _bannerUncertain = res.deliveryUncertain;
        _bannerMessage = res.message;
      });
      if (res.deliveryUncertain) {
        HapticFeedback.heavyImpact();
      } else if (res.success) {
        HapticFeedback.mediumImpact();
      }
      _toast(
        res.message ??
            (res.success
                ? 'صورتحساب به سامانه مودیان ارسال شد.'
                : 'ارسال ناموفق بود.'),
      );
      await _load();
      if (mounted &&
          !res.success &&
          (res.responseJson ?? '').trim().isNotEmpty) {
        await showMoadianJsonSheet(
          context,
          title: 'پاسخ برگشتی سامانه مودیان',
          subtitle: res.message,
          jsonText: _prettyJson(res.responseJson!),
        );
      }
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onInquiry() async {
    final inv = _inv;
    if (inv == null || _busy || (inv.referenceId ?? '').trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final res = await _repo.estelamInvoice(
        referenceId: inv.referenceId!.trim(),
        invoiceId: inv.effectiveId,
        dateOrder: inv.dateOrder,
        cpInfoId: inv.cpInfoId,
      );
      if (!mounted) return;
      _changed = true;
      setState(() {
        _bannerUncertain = false;
        _bannerMessage = res.message;
      });
      _toast(res.message ?? 'استعلام از سامانه انجام شد.');
      await _load();
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onShowErrors() async {
    final inv = _inv;
    if (inv == null || _busy || (inv.referenceId ?? '').trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final err = await _repo.getInvoiceErrors(
        inv.referenceId!.trim(),
        cpInfoId: inv.cpInfoId,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MoadianColors.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: MoadianColors.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.bug_report_outlined,
                          color: MoadianColors.danger,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'جزئیات خطای برگشتی از سامانه مودیان',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if ((err.status ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'وضعیت سامانه: ${err.status}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: MoadianColors.danger,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: SelectableText(
                      err.displayMessage,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.7,
                        color: Color(0xFF7F1D1D),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: err.displayMessage),
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            _toast('متن خطا کپی شد.');
                          },
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('کپی متن خطا'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onSetBuyerReaction() async {
    final inv = _inv;
    if (inv == null || _busy) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MoadianColors.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'ثبت دستی واکنش خریدار (مطابق کارپوشه my.tax.gov.ir)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'به دلیل محدودیت پروتکل سامانه مودیان، نتیجه نهایی تأیید/رد خریدار پس از مشاهده در کارپوشه در اینجا ثبت می‌شود:',
                  style: TextStyle(
                    fontSize: 11.2,
                    height: 1.6,
                    color: MoadianColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 12),
                _ReactionTile(
                  code: '7',
                  title: 'تأیید شده توسط خریدار',
                  subtitle: 'خریدار در کارپوشه صورتحساب را تأیید کرده است',
                  color: MoadianColors.ok,
                  icon: Icons.verified_rounded,
                  onTap: () => Navigator.pop(ctx, '7'),
                ),
                const SizedBox(height: 8),
                _ReactionTile(
                  code: '11',
                  title: 'تأیید سیستمی (انقضای مهلت ۳۰ روزه)',
                  subtitle: 'تأیید خودکار به علت عدم واکنش در مهلت قانونی',
                  color: MoadianColors.primary,
                  icon: Icons.task_alt_rounded,
                  onTap: () => Navigator.pop(ctx, '11'),
                ),
                const SizedBox(height: 8),
                _ReactionTile(
                  code: '8',
                  title: 'رد شده توسط خریدار',
                  subtitle: 'خریدار صورتحساب را در کارپوشه رد کرده است',
                  color: MoadianColors.danger,
                  icon: Icons.cancel_outlined,
                  onTap: () => Navigator.pop(ctx, '8'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked == null) return;

    setState(() => _busy = true);
    try {
      final res = await _repo.setInvoiceStatus(
        invoiceId: inv.effectiveId,
        targetStatus: picked,
        cpInfoId: inv.cpInfoId,
      );
      if (!mounted) return;
      _changed = true;
      _toast(res.message ?? 'وضعیت واکنش خریدار ثبت شد.');
      await _load();
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onSalesReturn() async {
    final inv = _inv;
    if (inv == null || _busy) return;
    final ok = await _confirm(
      title: 'صدور و ارسال صورتحساب برگشت از فروش',
      body:
          'سند «برگشت از فروش» (Ins=3) با ارجاع به کد مالیاتی این صورتحساب صادر و به سامانه مودیان ارسال می‌شود. آیا مطمئن هستید؟',
      confirmLabel: 'ثبت برگشت از فروش',
      confirmColor: MoadianColors.warn,
    );
    if (!ok) return;

    setState(() => _busy = true);
    try {
      final res = await _repo.sendSalesReturn(inv);
      if (!mounted) return;
      _changed = true;
      _toast(res.message ?? 'صورتحساب برگشت از فروش ارسال شد.');
      await _load();
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onEbtal() async {
    final inv = _inv;
    if (inv == null || _busy) return;
    final ok = await _confirm(
      title: 'ابطال قطعی صورتحساب در سامانه مودیان',
      body:
          'هشدار مهم: با ارسال صورتحساب ابطالی (Ins=4)، این صورتحساب در سامانه مودیان باطل می‌شود و این عملیات قابل بازگشت نیست!',
      confirmLabel: 'تأیید ابطال قطعی',
      confirmColor: MoadianColors.danger,
    );
    if (!ok) return;

    setState(() => _busy = true);
    try {
      final res = await _repo.ebtalInvoice(inv);
      if (!mounted) return;
      _changed = true;
      _toast(res.message ?? 'درخواست ابطال به سامانه ارسال شد.');
      await _load();
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onDelete() async {
    final inv = _inv;
    if (inv == null || _busy) return;
    final ok = await _confirm(
      title: 'حذف پیش‌نویس صورتحساب',
      body:
          'پیش‌نویس شماره ${Fa.digits(inv.numberInvoice ?? inv.effectiveId)} هنوز به سامانه ارسال نشده است. آیا برای همیشه حذف شود؟',
      confirmLabel: 'حذف پیش‌نویس',
      confirmColor: MoadianColors.danger,
    );
    if (!ok) return;

    setState(() => _busy = true);
    try {
      final res = await _repo.deleteInvoice(
        inv.effectiveId,
        cpInfoId: inv.cpInfoId,
      );
      if (!mounted) return;
      if (res.success) {
        _toast('پیش‌نویس حذف شد.');
        Navigator.of(context).pop(true);
      } else {
        _toast(res.message ?? 'حذف ناموفق بود.');
      }
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openForm(MoadianFormMode mode) async {
    final inv = _inv;
    if (inv == null) return;
    final res = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (_) => MoadianInvoiceFormPage(
          mode: mode,
          invoiceId: inv.effectiveId,
          initialCpInfoId: inv.cpInfoId,
        ),
      ),
    );
    if (res != null && mounted) {
      _changed = true;
      if (mode == MoadianFormMode.copy && res is int && res > 0 && res != inv.effectiveId) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MoadianInvoiceDetailPage(
              invoiceId: res,
              cpInfoId: inv.cpInfoId,
            ),
          ),
        );
      } else {
        await _load();
      }
    }
  }

  Future<void> _shareSummary() async {
    final inv = _inv;
    if (inv == null) return;
    final tax = MoadianCalc.primaryTaxNumber(inv);
    final refTax = MoadianCalc.referenceTaxNumber(inv);
    final grand = inv.totalMoney > 0
        ? inv.totalMoney
        : MoadianCalc.grandTotal(inv.invoiceItems);

    final buf = StringBuffer()
      ..writeln('📄 صورتحساب الکترونیکی مودیان تیسا')
      ..writeln(
        'شماره داخلی: ${Fa.digits(inv.numberInvoice ?? inv.effectiveId)} | موضوع: ${inv.subject ?? 'اصلی'}',
      )
      ..writeln(
        'تاریخ: ${inv.dateOrder == null ? '—' : jalaliShort(inv.dateOrder!)} | وضعیت: ${MoadianPerms.statusLabel(inv.statusCode)}',
      );
    if ((inv.persianName ?? '').isNotEmpty) {
      buf.writeln('فروشنده: ${inv.persianName}');
    }
    buf.writeln(
      'خریدار: ${inv.isNoBuyerType ? 'مصرف‌کننده نهایی (${inv.typePattern})' : (inv.customerName ?? '—')}',
    );
    if (tax.isNotEmpty) buf.writeln('کد مالیاتی ۲۲ رقمی: $tax');
    if (refTax.isNotEmpty) buf.writeln('کد مالیاتی مرجع: $refTax');
    if ((inv.referenceId ?? '').isNotEmpty) {
      buf.writeln('کد رهگیری سامانه: ${inv.referenceId}');
    }
    buf.writeln('────────────────────');
    for (var i = 0; i < inv.invoiceItems.length; i++) {
      final it = inv.invoiceItems[i];
      buf.writeln(
        '${Fa.digits(i + 1)}. ${it.name ?? 'کالا'} × ${Fa.number(it.count)} = ${Fa.number(MoadianCalc.lineTotal(it).round())} ریال',
      );
    }
    buf
      ..writeln('────────────────────')
      ..writeln('مبلغ قابل پرداخت: ${Fa.number(grand.round())} ریال');

    await SharePlus.instance.share(ShareParams(text: buf.toString()));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthController>().session;
    final inv = _inv;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        backgroundColor: MoadianColors.bg,
        body: Column(
          children: [
            MoadianPageHeader(
              title: inv == null
                  ? 'جزئیات صورتحساب #${Fa.digits(widget.invoiceId)}'
                  : 'صورتحساب شماره ${Fa.digits(inv.numberInvoice ?? inv.effectiveId)}',
              subtitle: inv == null
                  ? 'سامانه مودیان تیسا'
                  : '${inv.persianName ?? 'پرونده مودیان'} • ${inv.typePattern}',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (inv != null)
                    IconButton(
                      tooltip: 'اشتراک‌گذاری خلاصه صورتحساب',
                      onPressed: _shareSummary,
                      icon: const Icon(
                        Icons.share_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  IconButton(
                    tooltip: 'نوسازی',
                    onPressed: _loading || _busy ? null : _load,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                ],
              ),
            ),
            if (_busy)
              const LinearProgressIndicator(
                minHeight: 2.5,
                color: MoadianColors.primaryBright,
              ),
            if (_loading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    color: MoadianColors.primary,
                  ),
                ),
              )
            else if (_error != null || inv == null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: MoadianErrorBanner(
                      message: _error ?? 'صورتحساب یافت نشد.',
                      onRetry: _load,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  color: MoadianColors.primary,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                    children: [
                      if (_bannerMessage != null &&
                          _bannerMessage!.trim().isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: _bannerUncertain
                                ? const Color(0xFFFFFBEB)
                                : MoadianColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _bannerUncertain
                                  ? const Color(0xFFFCD34D)
                                  : MoadianColors.primary.withValues(
                                      alpha: 0.28,
                                    ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _bannerUncertain
                                    ? Icons.warning_amber_rounded
                                    : Icons.info_outline_rounded,
                                size: 19,
                                color: _bannerUncertain
                                    ? MoadianColors.warn
                                    : MoadianColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _bannerMessage!,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // کارت وضعیت و شناسه‌های مالیاتی رسمی
                      _buildIdentityCard(inv),
                      const SizedBox(height: 10),

                      // کنسول عملیات الکترونیکی سامانه مودیان
                      _buildOperationsConsole(inv, session),
                      const SizedBox(height: 12),

                      // مشخصات فروشنده و خریدار
                      _buildPartiesSection(inv),
                      const SizedBox(height: 12),

                      // جدول/کارت اقلام صورتحساب
                      _buildItemsSection(inv),
                      const SizedBox(height: 12),

                      // جمع‌بندی مبالغ و تسویه
                      _buildTotalsCard(inv),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityCard(MoadianInvoice inv) {
    final ownTax = MoadianCalc.primaryTaxNumber(inv);
    final refTax = MoadianCalc.referenceTaxNumber(inv);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MoadianColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MoadianColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    MoadianStatusPill(code: inv.statusCode),
                    MoadianSubjectBadge(subject: inv.subject),
                  ],
                ),
              ),
              Text(
                inv.dateOrder == null ? '—' : jalaliShort(inv.dateOrder!),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: MoadianColors.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _MetaInline('شماره داخلی', Fa.digits(inv.numberInvoice ?? inv.effectiveId)),
              _MetaInline('الگوی صورتحساب', inv.typePattern),
              _MetaInline('نحوه پرداخت', inv.paymentType),
              if ((inv.fiscalYearName ?? '').isNotEmpty)
                _MetaInline('سال مالی', inv.fiscalYearName!),
            ],
          ),
          if (ownTax.isNotEmpty) ...[
            const SizedBox(height: 10),
            MoadianCopyCodeRow(
              label: 'کد مالیاتی ۲۲ رقمی',
              code: ownTax,
              highlight: true,
            ),
          ],
          if (refTax.isNotEmpty) ...[
            const SizedBox(height: 6),
            MoadianCopyCodeRow(
              label: 'کد مالیاتی مرجع',
              code: refTax,
              onTapReference: widget.onJumpToReferenceTax == null
                  ? null
                  : () {
                      Navigator.of(context).pop(_changed);
                      widget.onJumpToReferenceTax!(refTax);
                    },
            ),
          ],
          if ((inv.referenceId ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            MoadianCopyCodeRow(
              label: 'کد رهگیری سامانه',
              code: inv.referenceId!.trim(),
            ),
          ],
          if ((inv.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'توضیحات: ${inv.description}',
              style: const TextStyle(
                fontSize: 11.2,
                color: MoadianColors.inkSoft,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOperationsConsole(MoadianInvoice inv, dynamic session) {
    final code = inv.statusCode;
    final showBtns = inv.showButtons;
    final ref = inv.referenceId;

    final canSend =
        MoadianPerms.canSend(code, showBtns) &&
        (session == null || MoadianPerms.can(session, MoadianPerms.invoiceSend));
    final canPreview =
        MoadianPerms.canPreview(code, showBtns) &&
        (session == null ||
            MoadianPerms.can(session, MoadianPerms.invoicePreview));
    final canInquiry =
        MoadianPerms.canInquiry(code, ref) &&
        (session == null ||
            MoadianPerms.can(session, MoadianPerms.invoiceInquiry));
    final canErrors =
        MoadianPerms.canShowErrors(code, ref) &&
        (session == null ||
            MoadianPerms.can(session, MoadianPerms.invoiceInquiry));
    final canReact =
        MoadianPerms.canReactManually(code, ref) &&
        (session == null ||
            MoadianPerms.can(session, MoadianPerms.invoiceStatus));
    final canEdit =
        MoadianPerms.canEdit(code) &&
        (session == null ||
            MoadianPerms.can(session, MoadianPerms.invoiceUpdate));
    final canCopy =
        session == null ||
        MoadianPerms.can(session, MoadianPerms.invoiceCreate);
    final canDelete =
        MoadianPerms.canDelete(code, showBtns) &&
        (session == null ||
            MoadianPerms.can(session, MoadianPerms.invoiceDelete));
    final canRef =
        MoadianPerms.canReference(code, ref) &&
        (session == null || MoadianPerms.can(session, MoadianPerms.invoiceSend));
    final canEbtal =
        MoadianPerms.canEbtal(code, ref) &&
        (session == null || MoadianPerms.can(session, MoadianPerms.invoiceSend));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MoadianColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MoadianColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MoadianSectionTitle(
            title: 'عملیات الکترونیکی سامانه مودیان',
            subtitle: 'بر اساس وضعیت فعلی سند و دسترسی‌های کاربری شما',
          ),
          if (canSend) ...[
            SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: _busy ? null : _onSendToMoadian,
                style: FilledButton.styleFrom(
                  backgroundColor: MoadianColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  code == '5'
                      ? 'ارسال مجدد صورتحساب به سامانه مودیان'
                      : 'امضا و ارسال به سامانه مودیان',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canPreview)
                _ActionChipBtn(
                  icon: Icons.data_object_rounded,
                  label: 'پیش‌نمایش JSON',
                  color: MoadianColors.indigo,
                  onTap: _onPreviewJson,
                ),
              if (canInquiry)
                _ActionChipBtn(
                  icon: Icons.sync_rounded,
                  label: 'استعلام وضعیت از سامانه',
                  color: MoadianColors.accent,
                  onTap: _onInquiry,
                ),
              if (canErrors)
                _ActionChipBtn(
                  icon: Icons.error_outline_rounded,
                  label: 'مشاهده خطای سامانه',
                  color: MoadianColors.danger,
                  onTap: _onShowErrors,
                ),
              if (canReact)
                _ActionChipBtn(
                  icon: Icons.fact_check_outlined,
                  label: 'ثبت واکنش خریدار',
                  color: MoadianColors.ok,
                  onTap: _onSetBuyerReaction,
                ),
              if (canEdit)
                _ActionChipBtn(
                  icon: Icons.edit_outlined,
                  label: 'ویرایش',
                  color: MoadianColors.primary,
                  onTap: () => _openForm(MoadianFormMode.edit),
                ),
              if (canCopy)
                _ActionChipBtn(
                  icon: Icons.copy_all_rounded,
                  label: 'کپی به پیش‌نویس جدید',
                  color: MoadianColors.inkSoft,
                  onTap: () => _openForm(MoadianFormMode.copy),
                ),
              if (canRef)
                _ActionChipBtn(
                  icon: Icons.published_with_changes_rounded,
                  label: 'صدور اصلاحی',
                  color: MoadianColors.warn,
                  onTap: () => _openForm(MoadianFormMode.eslahi),
                ),
              if (canRef)
                _ActionChipBtn(
                  icon: Icons.assignment_return_outlined,
                  label: 'برگشت از فروش',
                  color: MoadianColors.warn,
                  onTap: _onSalesReturn,
                ),
              if (canEbtal)
                _ActionChipBtn(
                  icon: Icons.block_rounded,
                  label: 'ابطال صورتحساب',
                  color: MoadianColors.danger,
                  onTap: _onEbtal,
                ),
              if (canDelete)
                _ActionChipBtn(
                  icon: Icons.delete_outline_rounded,
                  label: 'حذف پیش‌نویس',
                  color: MoadianColors.danger,
                  onTap: _onDelete,
                ),
              if (MoadianPerms.hasReference(ref))
                _ActionChipBtn(
                  icon: Icons.open_in_new_rounded,
                  label: 'کپی آدرس my.tax.gov.ir',
                  color: MoadianColors.inkSoft,
                  onTap: () async {
                    await Clipboard.setData(
                      const ClipboardData(text: MoadianPerms.workFolderUrl),
                    );
                    _toast(
                      'آدرس درگاه ملی مالیاتی (https://my.tax.gov.ir) کپی شد.',
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPartiesSection(MoadianInvoice inv) {
    return Column(
      children: [
        _PartyCard(
          roleTitle: 'فروشنده (پرونده مودیان)',
          icon: Icons.storefront_rounded,
          name: inv.persianName ?? '—',
          nationalId: inv.sellerNationalId,
          economicNo: inv.sellerEconomicNo,
          postalCode: inv.sellerPostalCode,
        ),
        const SizedBox(height: 8),
        _PartyCard(
          roleTitle: 'خریدار (مشتری)',
          icon: Icons.person_outline_rounded,
          name: inv.isNoBuyerType
              ? 'مصرف‌کننده نهایی (${inv.typePattern} — بدون خریدار)'
              : (inv.customerName ?? '—'),
          nationalId: inv.buyerNationalId,
          economicNo: inv.buyerEconomicNo,
          postalCode: inv.buyerPostalCode,
          extra: [
            if ((inv.buyerPhone ?? '').trim().isNotEmpty)
              'تلفن: ${Fa.digits(inv.buyerPhone)}',
            if ((inv.buyerAddress ?? '').trim().isNotEmpty)
              'نشانی: ${inv.buyerAddress}',
          ].join(' • '),
        ),
      ],
    );
  }

  Widget _buildItemsSection(MoadianInvoice inv) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MoadianColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MoadianColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MoadianSectionTitle(
            title: 'اقلام کالا و خدمات (${Fa.digits(inv.invoiceItems.length)} ردیف)',
          ),
          for (var i = 0; i < inv.invoiceItems.length; i++) ...[
            if (i > 0) const Divider(height: 16),
            Builder(
              builder: (_) {
                final it = inv.invoiceItems[i];
                final gross = MoadianCalc.lineGross(it);
                final vat = MoadianCalc.lineVat(it);
                final total = MoadianCalc.lineTotal(it);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: MoadianColors.primary.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            Fa.digits(i + 1),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: MoadianColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            it.name ?? 'کالا/خدمت',
                            style: const TextStyle(
                              fontSize: 12.8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${Fa.number(total.round())} ریال',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: MoadianColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'کد CPC: ${Fa.digits(it.uniqueIdentifier ?? '—')} • تعداد: ${Fa.number(it.count)} ${it.unitOfMeasurement ?? ''} × فی: ${Fa.number(it.priceUnit.round())}',
                      style: const TextStyle(
                        fontSize: 10.8,
                        color: MoadianColors.inkSoft,
                      ),
                    ),
                    Text(
                      'پایه: ${Fa.number(gross.round())} • تخفیف: ${Fa.number(it.discount.round())} • ارزش افزوده (${Fa.number(it.valueAddedPercentage)}٪): ${Fa.number(vat.round())}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: MoadianColors.inkSoft,
                      ),
                    ),
                    if ((it.descriptionKala ?? '').trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'شرح: ${it.descriptionKala}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: MoadianColors.inkSoft,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTotalsCard(MoadianInvoice inv) {
    final gross = MoadianCalc.totalGross(inv.invoiceItems);
    final disc = MoadianCalc.totalDiscount(inv.invoiceItems);
    final net = MoadianCalc.totalNet(inv.invoiceItems);
    final vat = MoadianCalc.totalVat(inv.invoiceItems);
    final grand = inv.totalMoney > 0
        ? inv.totalMoney
        : MoadianCalc.grandTotal(inv.invoiceItems);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: MoadianColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _TotalLine('جمع مبلغ قبل از تخفیف', gross),
          _TotalLine('جمع تخفیفات', disc),
          _TotalLine('مبلغ پس از تخفیف', net),
          _TotalLine('جمع مالیات بر ارزش افزوده', vat),
          const Divider(color: Colors.white24, height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'مبلغ نهایی صورتحساب',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '${Fa.number(grand.round())} ریال',
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF5EEAD4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaInline extends StatelessWidget {
  const _MetaInline(this.k, this.v);
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) => RichText(
    text: TextSpan(
      style: const TextStyle(
        fontFamily: 'Vazirmatn',
        fontSize: 11.2,
        color: MoadianColors.inkSoft,
      ),
      children: [
        TextSpan(text: '$k: '),
        TextSpan(
          text: v,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: MoadianColors.ink,
          ),
        ),
      ],
    ),
  );
}

class _ActionChipBtn extends StatelessWidget {
  const _ActionChipBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color.withValues(alpha: 0.09),
    borderRadius: BorderRadius.circular(11),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withValues(alpha: 0.26)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15.5, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.2,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PartyCard extends StatelessWidget {
  const _PartyCard({
    required this.roleTitle,
    required this.icon,
    required this.name,
    this.nationalId,
    this.economicNo,
    this.postalCode,
    this.extra,
  });

  final String roleTitle;
  final IconData icon;
  final String name;
  final String? nationalId;
  final String? economicNo;
  final String? postalCode;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final details = [
      if ((nationalId ?? '').trim().isNotEmpty)
        'شناسه/کد ملی: ${Fa.digits(nationalId)}',
      if ((economicNo ?? '').trim().isNotEmpty)
        'کد اقتصادی: ${Fa.digits(economicNo)}',
      if ((postalCode ?? '').trim().isNotEmpty)
        'کد پستی: ${Fa.digits(postalCode)}',
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MoadianColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MoadianColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: MoadianColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: MoadianColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roleTitle,
                  style: const TextStyle(
                    fontSize: 10.2,
                    fontWeight: FontWeight.w700,
                    color: MoadianColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12.8,
                    fontWeight: FontWeight.w900,
                    color: MoadianColors.ink,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    details.join(' • '),
                    style: const TextStyle(
                      fontSize: 10.6,
                      color: MoadianColors.inkSoft,
                    ),
                  ),
                ],
                if ((extra ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    extra!,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: MoadianColors.inkSoft,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine(this.label, this.value);
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: Colors.white70),
          ),
        ),
        Text(
          '${Fa.number(value.round())} ریال',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
}

class _ReactionTile extends StatelessWidget {
  const _ReactionTile({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String code;
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color.withValues(alpha: 0.08),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.8,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10.6,
                      color: MoadianColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
