import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../../shop/data/fa_num.dart';
import '../data/moadian_calc.dart';
import '../data/moadian_perms.dart';
import '../data/moadian_repository.dart';
import '../models/moadian_models.dart';
import 'moadian_invoice_detail_page.dart';
import 'moadian_invoice_form_page.dart';
import 'moadian_style.dart';

class MoadianInvoicesTab extends StatefulWidget {
  const MoadianInvoicesTab({
    super.key,
    required this.companies,
    required this.activeCpInfoId,
    required this.onSelectCompany,
    required this.onChangedAny,
    this.externalFilterCode,
    this.externalSearchQuery,
    this.externalSignal = 0,
  });

  final List<MoadianCpInfo> companies;
  final int activeCpInfoId;
  final ValueChanged<MoadianCpInfo> onSelectCompany;
  final VoidCallback onChangedAny;
  final String? externalFilterCode;
  final String? externalSearchQuery;
  final int externalSignal;

  @override
  State<MoadianInvoicesTab> createState() => _MoadianInvoicesTabState();
}

class _MoadianInvoicesTabState extends State<MoadianInvoicesTab> {
  late final MoadianRepository _repo = MoadianRepository(
    context.read<ApiClient>(),
  );

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  String _operation = 'همه';
  DateTime? _fromDate;
  DateTime? _toDate;
  int _page = 1;
  static const int _pageSize = 15;

  MoadianPagedList<MoadianInvoice> _paged = MoadianPagedList.empty();
  MoadianInvoiceLabels _labels = const MoadianInvoiceLabels();
  bool _loading = false;
  int? _busyInvoiceId;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.externalFilterCode != null) {
      _operation = widget.externalFilterCode!;
    }
    if ((widget.externalSearchQuery ?? '').isNotEmpty) {
      _searchCtrl.text = widget.externalSearchQuery!;
    }
    _load();
  }

  @override
  void didUpdateWidget(covariant MoadianInvoicesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeCpInfoId != widget.activeCpInfoId) {
      _page = 1;
      _load();
    } else if (oldWidget.externalSignal != widget.externalSignal) {
      if (widget.externalFilterCode != null) {
        _operation = widget.externalFilterCode!;
      }
      if (widget.externalSearchQuery != null) {
        _searchCtrl.text = widget.externalSearchQuery!;
      }
      _page = 1;
      _load();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.activeCpInfoId <= 0) {
      setState(() {
        _paged = MoadianPagedList.empty();
        _labels = const MoadianInvoiceLabels();
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      DateTime? d1 = _fromDate;
      DateTime? d2 = _toDate;
      if (d1 != null && d2 == null) d2 = DateTime.now();
      if (d2 != null && d1 == null) {
        d1 = d2.subtract(const Duration(days: 365));
      }

      final res = await _repo.getInvoices(
        cpInfoId: widget.activeCpInfoId,
        operation: _operation,
        firstDate: d1,
        endDate: d2,
        search: toEnDigits(_searchCtrl.text.trim()),
        page: _page,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _paged = res.invoices;
        _labels = res.labels;
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

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 420), () {
      _page = 1;
      _load();
    });
  }

  void _jumpToRefTax(String refTax) {
    setState(() {
      _operation = 'همه';
      _fromDate = null;
      _toDate = null;
      _searchCtrl.text = refTax;
      _page = 1;
    });
    _load();
  }

  Future<void> _openCreate() async {
    final res = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => MoadianInvoiceFormPage(
          mode: MoadianFormMode.create,
          initialCpInfoId: widget.activeCpInfoId,
        ),
      ),
    );
    if (res != null && mounted) {
      widget.onChangedAny();
      await _load();
      if (res > 0 && mounted) {
        await _openDetail(res);
      }
    }
  }

  Future<void> _openDetail(int id) async {
    await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (_) => MoadianInvoiceDetailPage(
          invoiceId: id,
          cpInfoId: widget.activeCpInfoId,
          onJumpToReferenceTax: _jumpToRefTax,
        ),
      ),
    );
    if (mounted) {
      widget.onChangedAny();
      await _load();
    }
  }

  Future<void> _quickSend(MoadianInvoice row) async {
    if (_busyInvoiceId != null) return;
    setState(() => _busyInvoiceId = row.effectiveId);
    try {
      final full = await _repo.getInvoice(
        row.effectiveId,
        cpInfoId: widget.activeCpInfoId,
      );
      final res = await _repo.sendInvoice(full);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.message ??
                (res.success
                    ? 'صورتحساب ارسال شد.'
                    : 'خطا در ارسال صورتحساب.'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onChangedAny();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyInvoiceId = null);
    }
  }

  Future<void> _quickInquiry(MoadianInvoice row) async {
    if (_busyInvoiceId != null || (row.referenceId ?? '').trim().isEmpty) {
      return;
    }
    setState(() => _busyInvoiceId = row.effectiveId);
    try {
      final res = await _repo.estelamInvoice(
        referenceId: row.referenceId!.trim(),
        invoiceId: row.effectiveId,
        dateOrder: row.dateOrder,
        cpInfoId: widget.activeCpInfoId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'استعلام انجام شد.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onChangedAny();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyInvoiceId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthController>().session;
    final canCreate =
        session == null ||
        MoadianPerms.can(session, MoadianPerms.invoiceCreate);
    final canSend =
        session == null || MoadianPerms.can(session, MoadianPerms.invoiceSend);
    final canInquiry =
        session == null ||
        MoadianPerms.can(session, MoadianPerms.invoiceInquiry);

    final filters = <({String op, String label, int? count})>[
      (op: 'همه', label: 'همه', count: _labels.all),
      (op: '0', label: 'ارسال‌نشده', count: _labels.notSent),
      (op: '1', label: 'انتظار استعلام', count: _labels.waitingInquiry),
      (op: '4', label: 'انتظار واکنش', count: _labels.waitingReaction),
      (op: '5', label: 'دارای خطا', count: _labels.hasError),
      (op: '3', label: 'ارسال‌شده', count: _labels.sent),
      (op: '6', label: 'بدون واکنش', count: null),
    ];

    return Stack(
      children: [
        RefreshIndicator(
          color: MoadianColors.primary,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 88),
            children: [
              MoadianCompanyBar(
                companies: widget.companies,
                activeCpInfoId: widget.activeCpInfoId,
                onSelect: widget.onSelectCompany,
              ),
              const SizedBox(height: 10),

              // جستجو و فیلتر بازه تاریخ شمسی
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MoadianColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MoadianColors.line),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText:
                            'جستجو با شماره فاکتور، مشتری، کد مالیاتی ۲۲ رقمی…',
                        hintStyle: const TextStyle(fontSize: 11.5),
                        prefixIcon: const Icon(Icons.search_rounded, size: 19),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _page = 1;
                                  _load();
                                },
                              )
                            : null,
                        isDense: true,
                        filled: true,
                        fillColor: MoadianColors.surfaceSoft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _DateRangeChip(
                            label: _fromDate == null
                                ? 'از تاریخ'
                                : 'از: ${jalaliShort(_fromDate!)}',
                            active: _fromDate != null,
                            onTap: () async {
                              final d = await showJalaliDatePicker(
                                context,
                                initial: _fromDate ?? DateTime.now(),
                                title: 'انتخاب تاریخ شروع',
                              );
                              if (d != null) {
                                setState(() {
                                  _fromDate = d;
                                  _toDate ??= DateTime.now();
                                  _page = 1;
                                });
                                _load();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _DateRangeChip(
                            label: _toDate == null
                                ? 'تا تاریخ'
                                : 'تا: ${jalaliShort(_toDate!)}',
                            active: _toDate != null,
                            onTap: () async {
                              final d = await showJalaliDatePicker(
                                context,
                                initial: _toDate ?? DateTime.now(),
                                title: 'انتخاب تاریخ پایان',
                              );
                              if (d != null) {
                                setState(() {
                                  _toDate = d;
                                  _fromDate ??= d.subtract(
                                    const Duration(days: 30),
                                  );
                                  _page = 1;
                                });
                                _load();
                              }
                            },
                          ),
                        ),
                        if (_fromDate != null || _toDate != null) ...[
                          const SizedBox(width: 6),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'پاک کردن تاریخ',
                            onPressed: () {
                              setState(() {
                                _fromDate = null;
                                _toDate = null;
                                _page = 1;
                              });
                              _load();
                            },
                            icon: const Icon(
                              Icons.filter_alt_off_rounded,
                              size: 18,
                              color: MoadianColors.danger,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // چیپ‌های وضعیت به همراه شمارندهٔ زنده
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in filters) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          selected: _operation == f.op,
                          onSelected: (_) {
                            setState(() {
                              _operation = f.op;
                              _page = 1;
                            });
                            _load();
                          },
                          selectedColor: MoadianColors.primary,
                          backgroundColor: MoadianColors.surface,
                          side: BorderSide(
                            color: _operation == f.op
                                ? MoadianColors.primary
                                : MoadianColors.line,
                          ),
                          label: Text(
                            f.count == null
                                ? f.label
                                : '${f.label} (${Fa.digits(f.count)})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _operation == f.op
                                  ? Colors.white
                                  : MoadianColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),

              if (_error != null) ...[
                MoadianErrorBanner(message: _error!, onRetry: _load),
                const SizedBox(height: 10),
              ],

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: MoadianColors.primary,
                    ),
                  ),
                )
              else if (_paged.items.isEmpty)
                MoadianEmptyCard(
                  icon: Icons.find_in_page_outlined,
                  title: 'صورتحسابی در این فیلتر یافت نشد',
                  subtitle:
                      'فیلتر وضعیت یا جستجو را تغییر دهید، یا یک صورتحساب جدید ثبت کنید.',
                  actionLabel: canCreate ? 'صدور صورتحساب جدید' : null,
                  onAction: canCreate ? _openCreate : null,
                )
              else ...[
                for (final inv in _paged.items) ...[
                  _InvoiceListCard(
                    inv: inv,
                    busy: _busyInvoiceId == inv.effectiveId,
                    canSend: canSend,
                    canInquiry: canInquiry,
                    onTap: () => _openDetail(inv.effectiveId),
                    onQuickSend: () => _quickSend(inv),
                    onQuickInquiry: () => _quickInquiry(inv),
                    onTapRefTax: _jumpToRefTax,
                  ),
                  const SizedBox(height: 8),
                ],
                if (_paged.totalPages > 1)
                  _PaginationBar(
                    page: _page,
                    totalPages: _paged.totalPages,
                    totalCount: _paged.totalCount,
                    onChanged: (p) {
                      setState(() => _page = p);
                      _load();
                    },
                  ),
              ],
            ],
          ),
        ),
        if (canCreate && widget.activeCpInfoId > 0)
          Positioned(
            left: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'moadian_new_invoice_fab',
              onPressed: _openCreate,
              backgroundColor: MoadianColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.post_add_rounded, size: 20),
              label: const Text(
                'صورتحساب جدید',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
              ),
            ),
          ),
      ],
    );
  }
}

class _DateRangeChip extends StatelessWidget {
  const _DateRangeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: active
            ? MoadianColors.primary.withValues(alpha: 0.09)
            : MoadianColors.surfaceSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? MoadianColors.primary : MoadianColors.line,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.date_range_rounded,
            size: 15,
            color: active ? MoadianColors.primary : MoadianColors.inkSoft,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? MoadianColors.primary : MoadianColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _InvoiceListCard extends StatelessWidget {
  const _InvoiceListCard({
    required this.inv,
    required this.busy,
    required this.canSend,
    required this.canInquiry,
    required this.onTap,
    required this.onQuickSend,
    required this.onQuickInquiry,
    required this.onTapRefTax,
  });

  final MoadianInvoice inv;
  final bool busy;
  final bool canSend;
  final bool canInquiry;
  final VoidCallback onTap;
  final VoidCallback onQuickSend;
  final VoidCallback onQuickInquiry;
  final ValueChanged<String> onTapRefTax;

  @override
  Widget build(BuildContext context) {
    final ownTax = MoadianCalc.primaryTaxNumber(inv);
    final refTax = MoadianCalc.referenceTaxNumber(inv);
    final code = inv.statusCode;

    final showSend = canSend && MoadianPerms.canSend(code, inv.showButtons);
    final showInq =
        canInquiry && MoadianPerms.canInquiry(code, inv.referenceId);

    return Material(
      color: MoadianColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MoadianColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'فاکتور #${Fa.digits(inv.numberInvoice ?? inv.effectiveId)}',
                        style: const TextStyle(
                          fontSize: 13.2,
                          fontWeight: FontWeight.w900,
                          color: MoadianColors.ink,
                        ),
                      ),
                      const SizedBox(width: 6),
                      MoadianSubjectBadge(subject: inv.subject),
                    ],
                  ),
                  MoadianStatusPill(code: code, compact: true),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      inv.isNoBuyerType
                          ? 'مصرف‌کننده نهایی (${inv.typePattern})'
                          : (inv.customerName ?? '—'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: MoadianColors.inkSoft,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${Fa.number(inv.totalMoney.round())} ریال',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: MoadianColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    inv.dateOrder == null ? '—' : jalaliShort(inv.dateOrder!),
                    style: const TextStyle(
                      fontSize: 10.6,
                      color: MoadianColors.inkSoft,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '• ${inv.typePattern} • ${inv.paymentType}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: MoadianColors.inkFaint,
                      ),
                    ),
                  ),
                ],
              ),
              if (ownTax.isNotEmpty) ...[
                const SizedBox(height: 7),
                MoadianCopyCodeRow(label: 'کد مالیاتی', code: ownTax),
              ],
              if (refTax.isNotEmpty) ...[
                const SizedBox(height: 5),
                MoadianCopyCodeRow(
                  label: 'مرجع',
                  code: refTax,
                  onTapReference: () => onTapRefTax(refTax),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (busy)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: MoadianColors.primary,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (showSend)
                          FilledButton.tonalIcon(
                            onPressed: onQuickSend,
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              backgroundColor: MoadianColors.primary.withValues(
                                alpha: 0.12,
                              ),
                              foregroundColor: MoadianColors.primary,
                            ),
                            icon: const Icon(Icons.send_rounded, size: 14),
                            label: Text(
                              code == '5' ? 'ارسال مجدد' : 'ارسال',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        if (showInq)
                          FilledButton.tonalIcon(
                            onPressed: onQuickInquiry,
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              backgroundColor: MoadianColors.accent.withValues(
                                alpha: 0.12,
                              ),
                              foregroundColor: MoadianColors.accent,
                            ),
                            icon: const Icon(Icons.sync_rounded, size: 14),
                            label: const Text(
                              'استعلام',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  TextButton.icon(
                    onPressed: onTap,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: MoadianColors.inkSoft,
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: const Text(
                      'جزئیات و عملیات',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.totalCount,
    required this.onChanged,
  });

  final int page;
  final int totalPages;
  final int totalCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: MoadianColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: MoadianColors.line),
    ),
    child: Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: page > 1 ? () => onChanged(page - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            'صفحهٔ ${Fa.digits(page)} از ${Fa.digits(totalPages)} • مجموع ${Fa.number(totalCount)} صورتحساب',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.2,
              fontWeight: FontWeight.w700,
              color: MoadianColors.inkSoft,
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: page < totalPages ? () => onChanged(page + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    ),
  );
}
