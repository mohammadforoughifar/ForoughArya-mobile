// ============================================================
//  تب‌ها و پنجره‌های فاز ۴ کارگاه تعمیرات:
//    • `showRepairCreditSheet` — تسویه و سابقهٔ دریافت بدهی تعمیرات/گارانتی (`RepairCreditDialog.razor`)
//    • `ShopWarrantyTabView`  — پذیرش و تصمیم گارانتی (`WarrantyTab.razor`)
//    • `ShopTradeInTabView`   — طرح تعویض و مدیریت اعتبار مشتری (`TradeInTab.razor`)
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
import '../models/order_models.dart';
import '../models/shop_models.dart';
import '../models/treasury_models.dart';
import 'party_form_page.dart';
import 'shop_phase3_reports_pages.dart';
import 'shop_style.dart';

// ============================================================
//  ۱) شیت تسویه بدهی تعمیرات / گارانتی (`RepairCreditDialog.razor`)
// ============================================================

Future<void> showRepairCreditSheet(
  BuildContext context, {
  required ShopRepository repo,
  required int documentId,
  required String documentNumber,
  required bool isWarrantyModule,
  required bool canManage,
  VoidCallback? onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RepairCreditSheet(
      repo: repo,
      documentId: documentId,
      documentNumber: documentNumber,
      isWarrantyModule: isWarrantyModule,
      canManage: canManage,
      onChanged: onChanged,
    ),
  );
}

class _RepairCreditSheet extends StatefulWidget {
  const _RepairCreditSheet({
    required this.repo,
    required this.documentId,
    required this.documentNumber,
    required this.isWarrantyModule,
    required this.canManage,
    this.onChanged,
  });

  final ShopRepository repo;
  final int documentId;
  final String documentNumber;
  final bool isWarrantyModule;
  final bool canManage;
  final VoidCallback? onChanged;

  @override
  State<_RepairCreditSheet> createState() => _RepairCreditSheetState();
}

class _RepairCreditSheetState extends State<_RepairCreditSheet> {
  ShopOrderCreditState? _state;
  List<TreasuryAccount> _accounts = const [];
  final _amountCtrl = TextEditingController();
  int _accountId = 0;
  DateTime _date = DateTime.now();
  DateTime _reversalDate = DateTime.now();
  late String _opId = ShopRepository.newOperationId();
  final Map<int, String> _revIds = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final st = widget.isWarrantyModule
          ? await widget.repo.shopWarrantyCreditState(widget.documentId)
          : await widget.repo.repairWarrantyCreditState(widget.documentId);
      List<TreasuryAccount> accs = const [];
      if (widget.canManage && st.availableCredit > 0) {
        try {
          accs = widget.isWarrantyModule
              ? await widget.repo.shopWarrantyAccounts()
              : await widget.repo.repairAccounts();
        } catch (_) {}
      }
      if (!mounted) return;
      _amountCtrl.text = st.availableCredit > 0
          ? st.availableCredit.round().toString()
          : '';
      setState(() {
        _state = st;
        _accounts = accs;
        if (_accountId <= 0 && accs.isNotEmpty) _accountId = accs.first.id;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast(e.toString());
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

  Future<void> _receive() async {
    final st = _state;
    if (_saving || st == null || !widget.canManage) return;
    final amount = parseNum(_amountCtrl.text);
    if (amount <= 0 ||
        amount > st.availableCredit ||
        amount != amount.truncateToDouble()) {
      _toast(
        'مبلغ دریافت باید ریال صحیح، بیشتر از صفر و حداکثر برابر نسیه آزاد باشد.',
      );
      return;
    }
    if (_accountId <= 0) {
      _toast('حساب مقصد را انتخاب کنید.');
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.isWarrantyModule) {
        await widget.repo.receiveShopWarrantyCredit(
          widget.documentId,
          amount: amount,
          trsAccountId: _accountId,
          date: _date,
          operationId: _opId,
        );
      } else {
        await widget.repo.receiveRepairWarrantyCredit(
          widget.documentId,
          amount: amount,
          trsAccountId: _accountId,
          date: _date,
          operationId: _opId,
        );
      }
      _opId = ShopRepository.newOperationId();
      _toast('دریافت واقعی ثبت شد و از بدهی کسر گردید.', ok: true);
      widget.onChanged?.call();
      await _load();
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reverse(ShopOrderCreditReceipt r) async {
    if (_saving || !widget.canManage) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('لغو دریافت'),
        content: const Text('این دریافت با حفظ سابقه لغو شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: ShopColors.danger),
            child: const Text('لغو دریافت'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final op = _revIds.putIfAbsent(r.id, ShopRepository.newOperationId);
    setState(() => _saving = true);
    try {
      if (widget.isWarrantyModule) {
        await widget.repo.reverseShopWarrantyCredit(
          widget.documentId,
          r.id,
          date: _reversalDate,
          operationId: op,
        );
      } else {
        await widget.repo.reverseRepairWarrantyCredit(
          widget.documentId,
          r.id,
          date: _reversalDate,
          operationId: op,
        );
      }
      _toast('لغو دریافت ثبت شد.', ok: true);
      widget.onChanged?.call();
      await _load();
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = _state;
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: ShopColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'تسویه بدهی — ${widget.documentNumber}',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (st == null)
              const Expanded(
                child: ShopEmpty(
                  icon: Icons.info_outline_rounded,
                  title: 'اطلاعات مانده دریافت نشد',
                ),
              )
            else
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ShopColors.line),
                      ),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          Text(
                            'مانده کل: ${Fa.number(st.outstanding)} ریال',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: ShopColors.danger,
                            ),
                          ),
                          Text(
                            'نسیه قابل دریافت: ${Fa.number(st.availableCredit)} ریال',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (st.reservedForCheques > 0 ||
                              st.reservedForInstallments > 0)
                            const Text(
                              'چک و اقساط جداگانه تسویه می‌شوند.',
                              style: TextStyle(
                                fontSize: 11,
                                color: ShopColors.inkSoft,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (widget.canManage && st.availableCredit > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ShopColors.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _amountCtrl,
                              keyboardType: TextInputType.number,
                              textDirection: TextDirection.ltr,
                              decoration: const InputDecoration(
                                labelText: 'مبلغ دریافتی (ریال) *',
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<int>(
                              initialValue:
                                  _accounts.any((a) => a.id == _accountId)
                                  ? _accountId
                                  : 0,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'حساب مقصد (صندوق / بانک) *',
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: 0,
                                  child: Text('— انتخاب صندوق / بانک —'),
                                ),
                                for (final a in _accounts)
                                  DropdownMenuItem(
                                    value: a.id,
                                    child: Text(a.name),
                                  ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _accountId = v ?? 0),
                            ),
                            const SizedBox(height: 10),
                            _DateTile(
                              label: 'تاریخ دریافت',
                              value: _date,
                              onTap: () async {
                                final p = await showJalaliDatePicker(
                                  context,
                                  initial: _date,
                                  title: 'تاریخ دریافت',
                                );
                                if (p != null && mounted) {
                                  setState(() => _date = p);
                                }
                              },
                            ),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              onPressed: _saving ? null : _receive,
                              style: FilledButton.styleFrom(
                                backgroundColor: ShopColors.seed,
                              ),
                              icon: const Icon(Icons.payments_rounded, size: 17),
                              label: const Text('ثبت دریافت واقعی'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Text(
                      'سابقه دریافت‌ها',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (st.receipts.isEmpty)
                      const Text(
                        'دریافتی ثبت نشده است.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: ShopColors.inkSoft,
                        ),
                      )
                    else ...[
                      if (widget.canManage)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _DateTile(
                            label: 'تاریخ لغو دریافت',
                            value: _reversalDate,
                            onTap: () async {
                              final p = await showJalaliDatePicker(
                                context,
                                initial: _reversalDate,
                                title: 'تاریخ لغو دریافت',
                              );
                              if (p != null && mounted) {
                                setState(() => _reversalDate = p);
                              }
                            },
                          ),
                        ),
                      for (final r in st.receipts)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ShopColors.line),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${Fa.number(r.amount)} ریال — ${r.accountName}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      '${Fa.date(r.date?.toIso8601String(), time: false)} · '
                                      '${r.isReversed ? 'لغو در ${Fa.date(r.reversalDate?.toIso8601String(), time: false)}' : 'ثبت‌شده'}',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: r.isReversed
                                            ? ShopColors.danger
                                            : ShopColors.inkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.canManage && !r.isReversed)
                                TextButton(
                                  onPressed: _saving ? null : () => _reverse(r),
                                  style: TextButton.styleFrom(
                                    foregroundColor: ShopColors.danger,
                                  ),
                                  child: const Text(
                                    'لغو دریافت',
                                    style: TextStyle(fontSize: 11.5),
                                  ),
                                ),
                            ],
                          ),
                        ),
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
//  ۲) تب گارانتی (`WarrantyTab.razor`)
// ============================================================

class ShopWarrantyTabView extends StatefulWidget {
  const ShopWarrantyTabView({super.key});

  @override
  State<ShopWarrantyTabView> createState() => _ShopWarrantyTabViewState();
}

class _ShopWarrantyTabViewState extends State<ShopWarrantyTabView> {
  late final ShopRepository _repo =
      Provider.of<ShopRepository?>(context, listen: false) ??
      ShopRepository(context.read<ApiClient>());
  late final ShopPerms _perms = ShopPerms(
    context.read<AuthController>().session,
  );

  List<ShopWarranty> _items = const [];
  ShopWarrantyLookups _lookups = const ShopWarrantyLookups();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _canManage => _perms.canManageSection('Repairs');

  @override
  void initState() {
    super.initState();
    _loadLookups();
    _load();
  }

  Future<void> _loadLookups() async {
    try {
      final l = await _repo.shopWarrantyLookups();
      if (mounted) setState(() => _lookups = l);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.shopWarranties();
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

  Future<void> _openForm({ShopWarranty? source}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ShopWarrantyFormPage(
          repo: _repo,
          lookups: _lookups,
          source: source,
          onLookupsChanged: _loadLookups,
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _finalize(ShopWarranty w) async {
    if (_saving) return;
    if (w.items.any(
      (i) =>
          i.isChargeable &&
          ((i.customerUnitPrice ?? 0) <= 0 || i.customerAmount <= 0),
    )) {
      _toast(
        'برای هر ردیف ردشده که انجام یا مصرف شده، قیمت مشتری بزرگ‌تر از صفر را در پیش‌نویس وارد کنید.',
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('نهایی‌سازی گارانتی ${w.number}'),
        content: Text(
          'پذیرش ${w.number} نهایی شود؟ مبلغ ${Fa.number(w.customerAmount)} ریال به حساب مشتری منظور و قطعات مصرف‌شده از انبار کسر می‌شوند.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('تحویل و نهایی‌سازی'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await _repo.finalizeShopWarranty(w.id);
      _toast('گارانتی نهایی و گردش انبار و بدهی مربوط ثبت شد.', ok: true);
      await _load();
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openDetails(ShopWarranty w) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.5,
        maxChildSize: 0.94,
        expand: false,
        builder: (_, sc) => Container(
          decoration: const BoxDecoration(
            color: ShopColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: ListView(
            controller: sc,
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'جزئیات گارانتی ${w.number} — ${w.partyName}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(c),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final d in w.effectiveDevices)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ShopColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${d.label}${(d.serialNumber ?? '').isEmpty ? '' : ' — ${d.serialNumber}'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if ((d.problemDescription ?? '').trim().isNotEmpty)
                        Text(
                          d.problemDescription!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: ShopColors.inkSoft,
                          ),
                        ),
                      Text(
                        'لوازم همراه: ${(d.accessories ?? '').trim().isEmpty ? '—' : d.accessories}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                'ردیف‌های کار و قطعه',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              for (final it in w.items)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ShopColors.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${it.description}${it.productName == null ? '' : ' (${it.productName})'}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${WarrantyDecision.shortLabel(it.decision)} · '
                              'انجام/مصرف: ${it.isDone ? 'بله' : 'خیر'} · '
                              'مقدار: ${Fa.number(it.quantity)} · هزینه واحد: ${Fa.number(it.unitCost)}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: ShopColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${Fa.number(w.isFinalized && w.chargePolicyVersion == 0 ? 0 : it.customerAmount)} ریال',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: ShopColors.seed,
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 20),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  Text(
                    'هزینه داخلی: ${Fa.number(w.internalCost)} ریال',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'مبلغ مشتری: ${Fa.number(w.customerAmount)} ریال',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: ShopColors.seed,
                    ),
                  ),
                  if (w.hasCharge)
                    Text(
                      'فاکتور: ${w.chargeTransactionNumber ?? ''} — مانده: ${Fa.number(w.unpaidAmount)} ریال',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: ShopColors.danger,
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        children: [
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const WarrantyReportPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.bar_chart_rounded, size: 17),
                label: const Text(
                  'گزارش گارانتی',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const Spacer(),
              if (_canManage)
                FilledButton.icon(
                  onPressed: () => _openForm(),
                  style: FilledButton.styleFrom(
                    backgroundColor: ShopColors.seed,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'پذیرش گارانتی',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ShopColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ShopColors.line),
            ),
            child: const Text(
              'ردیف‌های پذیرفته رایگان‌اند. برای کار انجام‌شده یا قطعه مصرف‌شدهٔ پذیرفته‌نشده قیمت مشتری را جداگانه وارد کنید؛ مبلغ هنگام تحویل در حساب مشتری بدهکار می‌شود.',
              style: TextStyle(
                fontSize: 11,
                height: 1.7,
                color: ShopColors.inkSoft,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            ShopEmpty(
              icon: Icons.error_outline_rounded,
              title: 'پذیرش‌های گارانتی دریافت نشد',
              subtitle: _error,
              actionLabel: 'تلاش دوباره',
              onAction: _load,
            )
          else if (_items.isEmpty)
            const ShopEmpty(
              icon: Icons.verified_user_outlined,
              title: 'پذیرش گارانتی ثبت نشده است',
              subtitle: 'با دکمهٔ «پذیرش گارانتی» اولین مورد را ثبت کنید.',
            )
          else
            for (final w in _items)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
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
                          w.number,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: ShopColors.seed,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ShopTag(
                          text: w.isFinalized ? 'تحویل‌شده' : 'پیش‌نویس',
                          color: w.isFinalized ? ShopColors.ok : ShopColors.warn,
                        ),
                        const Spacer(),
                        Text(
                          Fa.date(w.receivedAt?.toIso8601String(), time: false),
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: ShopColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${w.partyName} — ${w.deviceSummary}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${Fa.digits(w.acceptedCount)} پذیرفته / ${Fa.digits(w.rejectedCount)} رد · '
                      'هزینه داخلی: ${Fa.number(w.internalCost)} ریال · '
                      'مبلغ مشتری: ${Fa.number(w.customerAmount)} ریال'
                      '${w.isFinalized && w.hasCharge ? ' (مانده: ${Fa.number(w.unpaidAmount)})' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: ShopColors.inkSoft,
                      ),
                    ),
                    const Divider(height: 14, color: ShopColors.line),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed: () => _openDetails(w),
                          icon: const Icon(Icons.visibility_rounded, size: 15),
                          label: const Text(
                            'جزئیات',
                            style: TextStyle(fontSize: 11.5),
                          ),
                        ),
                        if (w.hasCharge)
                          TextButton.icon(
                            onPressed: () => showRepairCreditSheet(
                              context,
                              repo: _repo,
                              documentId: w.id,
                              documentNumber: w.number,
                              isWarrantyModule: true,
                              canManage: _canManage,
                              onChanged: _load,
                            ),
                            icon: const Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 15,
                            ),
                            label: const Text(
                              'مانده / تسویه',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                        if (!w.isFinalized && _canManage) ...[
                          TextButton.icon(
                            onPressed: () => _openForm(source: w),
                            icon: const Icon(Icons.edit_rounded, size: 15),
                            label: const Text(
                              'ویرایش',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _saving ? null : () => _finalize(w),
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 15,
                            ),
                            label: const Text(
                              'تحویل / نهایی‌سازی',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _ShopWarrantyFormPage extends StatefulWidget {
  const _ShopWarrantyFormPage({
    required this.repo,
    required this.lookups,
    this.source,
    this.onLookupsChanged,
  });

  final ShopRepository repo;
  final ShopWarrantyLookups lookups;
  final ShopWarranty? source;
  final VoidCallback? onLookupsChanged;

  @override
  State<_ShopWarrantyFormPage> createState() => _ShopWarrantyFormPageState();
}

class _ShopWarrantyFormPageState extends State<_ShopWarrantyFormPage> {
  late ShopWarrantyLookups _lookups = widget.lookups;
  late int _partyId;
  late int _technicianId;
  late int _warehouseId;
  late DateTime _receivedAt;
  late final TextEditingController _noteCtrl;
  late String _operationId;
  late List<ShopWarrantyDevice> _devices;
  late List<ShopWarrantyItem> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.source;
    _partyId = s?.partyId ?? 0;
    _technicianId = s?.technicianId ?? 0;
    _warehouseId =
        s?.warehouseId ??
        (_lookups.warehouses.isNotEmpty ? _lookups.warehouses.first.id : 0);
    _receivedAt = s?.receivedAt ?? DateTime.now();
    _noteCtrl = TextEditingController(text: s?.note ?? '');
    _operationId = (s?.operationId ?? '').trim().isEmpty
        ? ShopRepository.newOperationId()
        : s!.operationId;
    _devices = s != null
        ? s.effectiveDevices
              .map(
                (d) => ShopWarrantyDevice(
                  id: d.id,
                  deviceType: d.deviceType,
                  deviceModel: d.deviceModel,
                  serialNumber: d.serialNumber,
                  problemDescription: d.problemDescription,
                  accessories: d.accessories,
                ),
              )
              .toList()
        : [ShopWarrantyDevice()];
    _items = s != null && s.items.isNotEmpty
        ? s.items
              .map(
                (i) => ShopWarrantyItem(
                  id: i.id,
                  description: i.description,
                  productId: i.productId,
                  productName: i.productName,
                  quantity: i.quantity,
                  unitCost: i.unitCost,
                  customerUnitPrice: i.customerUnitPrice,
                  decision: i.decision,
                  supplied: i.supplied,
                  performed: i.performed,
                ),
              )
              .toList()
        : [ShopWarrantyItem(performed: false)];
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  double get _draftCustomerAmount =>
      _items.fold<double>(0, (s, i) => s + i.customerAmount);

  Future<void> _quickCreateCustomer() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const PartyFormPage(type: PartyType.customer),
      ),
    );
    if (ok == true) {
      final l = await widget.repo.shopWarrantyLookups();
      widget.onLookupsChanged?.call();
      if (!mounted) return;
      setState(() {
        _lookups = l;
        if (l.customers.isNotEmpty) _partyId = l.customers.last.id;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_partyId <= 0) {
      _toast('مشتری را انتخاب کنید.');
      return;
    }
    if (_warehouseId <= 0) {
      _toast('انبار برداشت را انتخاب کنید.');
      return;
    }
    if (_devices.any((d) => d.deviceType.trim().isEmpty)) {
      _toast('نوع دستگاه را برای همهٔ دستگاه‌ها وارد کنید.');
      return;
    }
    if (_items.any((i) => i.description.trim().isEmpty)) {
      _toast('شرح کار یا قطعه را وارد کنید.');
      return;
    }
    setState(() => _saving = true);
    try {
      final dto = ShopWarranty(
        id: widget.source?.id ?? 0,
        operationId: _operationId,
        number: widget.source?.number ?? '',
        partyId: _partyId,
        technicianId: _technicianId > 0 ? _technicianId : null,
        warehouseId: _warehouseId,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        receivedAt: _receivedAt,
        devices: _devices,
        items: _items,
      );
      await widget.repo.saveShopWarranty(dto);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: ShopColors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        title: Text(
          widget.source == null
              ? 'پذیرش گارانتی'
              : 'ویرایش گارانتی ${widget.source!.number}',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ShopColors.line),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue:
                            _lookups.customers.any((c) => c.id == _partyId)
                            ? _partyId
                            : 0,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'مشتری *',
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 0,
                            child: Text('— انتخاب مشتری —'),
                          ),
                          for (final c in _lookups.customers)
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                        ],
                        onChanged: (v) => setState(() => _partyId = v ?? 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _quickCreateCustomer,
                      child: const Text('جدید'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue:
                      _lookups.technicians.any((t) => t.id == _technicianId)
                      ? _technicianId
                      : 0,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'تعمیرکار',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 0,
                      child: Text('— بعداً تعیین می‌شود —'),
                    ),
                    for (final t in _lookups.technicians)
                      DropdownMenuItem(value: t.id, child: Text(t.name)),
                  ],
                  onChanged: (v) => setState(() => _technicianId = v ?? 0),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue:
                      _lookups.warehouses.any((w) => w.id == _warehouseId)
                      ? _warehouseId
                      : 0,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'انبار برداشت *',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 0,
                      child: Text('— انتخاب انبار —'),
                    ),
                    for (final w in _lookups.warehouses)
                      DropdownMenuItem(value: w.id, child: Text(w.name)),
                  ],
                  onChanged: (v) => setState(() => _warehouseId = v ?? 0),
                ),
                const SizedBox(height: 10),
                _DateTile(
                  label: 'تاریخ پذیرش',
                  value: _receivedAt,
                  onTap: () async {
                    final p = await showJalaliDatePicker(
                      context,
                      initial: _receivedAt,
                      title: 'تاریخ پذیرش',
                    );
                    if (p != null && mounted) setState(() => _receivedAt = p);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'یادداشت',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'دستگاه‌های پذیرش‌شده (${Fa.digits(_devices.length)})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _devices.length >= 100
                    ? null
                    : () => setState(() => _devices.add(ShopWarrantyDevice())),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('افزودن دستگاه'),
              ),
            ],
          ),
          for (var i = 0; i < _devices.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ShopColors.line),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'دستگاه ${Fa.digits(i + 1)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      if (_devices.length > 1)
                        IconButton(
                          onPressed: () => setState(() => _devices.removeAt(i)),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: ShopColors.danger,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                  TextFormField(
                    initialValue: _devices[i].deviceType,
                    decoration: const InputDecoration(
                      labelText: 'نوع دستگاه * (مثلاً لپ‌تاپ، موبایل، پرینتر)',
                      isDense: true,
                    ),
                    onChanged: (v) => _devices[i].deviceType = v,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _devices[i].deviceModel,
                    decoration: const InputDecoration(
                      labelText: 'برند و مدل',
                      isDense: true,
                    ),
                    onChanged: (v) => _devices[i].deviceModel = v,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _devices[i].serialNumber,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'شماره سریال',
                      isDense: true,
                    ),
                    onChanged: (v) => _devices[i].serialNumber = v,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _devices[i].problemDescription,
                    decoration: const InputDecoration(
                      labelText: 'ایراد اعلامی مشتری',
                      isDense: true,
                    ),
                    onChanged: (v) => _devices[i].problemDescription = v,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _devices[i].accessories,
                    decoration: const InputDecoration(
                      labelText: 'لوازم همراه',
                      isDense: true,
                    ),
                    onChanged: (v) => _devices[i].accessories = v,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'کارها و قطعات مشترک پذیرش',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(
                  () => _items.add(ShopWarrantyItem(performed: false)),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('افزودن ردیف'),
              ),
            ],
          ),
          for (var i = 0; i < _items.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ShopColors.line),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'ردیف ${Fa.digits(i + 1)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _items.length <= 1
                            ? null
                            : () => setState(() => _items.removeAt(i)),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: ShopColors.danger,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  TextFormField(
                    initialValue: _items[i].description,
                    decoration: const InputDecoration(
                      labelText: 'شرح کار یا قطعه *',
                      isDense: true,
                    ),
                    onChanged: (v) => _items[i].description = v,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue:
                        _lookups.products.any(
                          (p) => p.id == (_items[i].productId ?? 0),
                        )
                        ? (_items[i].productId ?? 0)
                        : 0,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'کالای انبار (اختیاری)',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 0,
                        child: Text('— فقط کار / اجرت —'),
                      ),
                      for (final p in _lookups.products)
                        DropdownMenuItem(value: p.id, child: Text(p.name)),
                    ],
                    onChanged: (v) {
                      setState(() {
                        final pid = (v ?? 0) > 0 ? v : null;
                        if (_items[i].productId != pid) {
                          _items[i].productId = pid;
                          _items[i].supplied = false;
                          _items[i].performed = false;
                          _items[i].customerUnitPrice = null;
                          _items[i].unitCost = 0;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _items[i].quantity.toString(),
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                            labelText: 'مقدار',
                            isDense: true,
                          ),
                          onChanged: (v) => setState(
                            () => _items[i].quantity = parseNum(v) <= 0
                                ? 1
                                : parseNum(v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: _items[i].unitCost > 0
                              ? _items[i].unitCost.round().toString()
                              : '',
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                            labelText: 'هزینه داخلی واحد',
                            isDense: true,
                          ),
                          onChanged: (v) =>
                              setState(() => _items[i].unitCost = parseNum(v)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _items[i].decision,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'تصمیم گارانتی *',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: WarrantyDecision.unspecified,
                        child: Text('انتخاب کنید'),
                      ),
                      DropdownMenuItem(
                        value: WarrantyDecision.accepted,
                        child: Text('پذیرفته (رایگان برای مشتری)'),
                      ),
                      DropdownMenuItem(
                        value: WarrantyDecision.rejected,
                        child: Text('پذیرفته‌نشده (شامل هزینه مشتری)'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        final next = v ?? WarrantyDecision.unspecified;
                        if (next == WarrantyDecision.rejected &&
                            _items[i].decision != WarrantyDecision.rejected) {
                          _items[i].customerUnitPrice = null;
                        }
                        _items[i].decision = next;
                      });
                    },
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _items[i].isPart
                        ? _items[i].supplied
                        : _items[i].performed,
                    title: Text(
                      _items[i].isPart
                          ? 'این قطعه واقعاً تحویل یا مصرف شده است'
                          : 'این کار واقعاً انجام شده است',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onChanged: (v) {
                      setState(() {
                        if (_items[i].isPart) {
                          _items[i].supplied = v == true;
                        } else {
                          _items[i].performed = v == true;
                        }
                      });
                    },
                  ),
                  if (_items[i].isChargeable)
                    TextFormField(
                      initialValue: _items[i].customerUnitPrice != null
                          ? _items[i].customerUnitPrice!.round().toString()
                          : '',
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'قیمت واحد مشتری (ریال) *',
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() {
                        final p = parseNum(v);
                        _items[i].customerUnitPrice = p > 0 ? p : null;
                      }),
                    ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ShopColors.line),
            ),
            child: Text(
              'مبلغ مشتری در زمان تحویل: ${Fa.number(_draftCustomerAmount)} ریال',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: ShopColors.seed,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: ShopColors.seed,
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            icon: const Icon(Icons.save_rounded, size: 18),
            label: Text(_saving ? 'در حال ذخیره…' : 'ذخیره پیش‌نویس گارانتی'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ============================================================
//  ۳) تب طرح تعویض کالای کارکرده (`TradeInTab.razor`)
// ============================================================

class ShopTradeInTabView extends StatefulWidget {
  const ShopTradeInTabView({super.key});

  @override
  State<ShopTradeInTabView> createState() => _ShopTradeInTabViewState();
}

class _ShopTradeInTabViewState extends State<ShopTradeInTabView> {
  late final ShopRepository _repo =
      Provider.of<ShopRepository?>(context, listen: false) ??
      ShopRepository(context.read<ApiClient>());
  late final ShopPerms _perms = ShopPerms(
    context.read<AuthController>().session,
  );

  List<ShopTradeIn> _items = const [];
  List<ShopLookup> _customers = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _canManage => _perms.canManageSection('Repairs');
  bool get _canSettle => _perms.canSettleTradeIn;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _load();
  }

  Future<void> _loadCustomers() async {
    try {
      final c = await _repo.shopTradeInCustomers();
      if (mounted) setState(() => _customers = c);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.shopTradeIns();
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

  Future<void> _openForm({ShopTradeIn? source}) async {
    int partyId = source?.partyId ?? 0;
    DateTime receivedAt = source?.receivedAt ?? DateTime.now();
    final typeCtrl = TextEditingController(text: source?.deviceType ?? '');
    final modelCtrl = TextEditingController(text: source?.deviceModel ?? '');
    final serialCtrl = TextEditingController(text: source?.serialNumber ?? '');
    final valCtrl = TextEditingController(
      text: source != null && source.value > 0
          ? source.value.round().toString()
          : '',
    );
    final noteCtrl = TextEditingController(text: source?.note ?? '');
    final opId = (source?.operationId ?? '').trim().isEmpty
        ? ShopRepository.newOperationId()
        : source!.operationId;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => StatefulBuilder(
        builder: (c, setSt) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    source == null
                        ? 'پذیرش طرح تعویض'
                        : 'ویرایش ${source.number}',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _customers.any((x) => x.id == partyId)
                              ? partyId
                              : 0,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'مشتری *',
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 0,
                              child: Text('— انتخاب مشتری —'),
                            ),
                            for (final cu in _customers)
                              DropdownMenuItem(
                                value: cu.id,
                                child: Text(cu.name),
                              ),
                          ],
                          onChanged: (v) => setSt(() => partyId = v ?? 0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () async {
                          final ok = await Navigator.of(c).push<bool>(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const PartyFormPage(type: PartyType.customer),
                            ),
                          );
                          if (ok == true) {
                            await _loadCustomers();
                            setSt(() {
                              if (_customers.isNotEmpty) {
                                partyId = _customers.last.id;
                              }
                            });
                          }
                        },
                        child: const Text('جدید'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _DateTile(
                    label: 'تاریخ پذیرش',
                    value: receivedAt,
                    onTap: () async {
                      final p = await showJalaliDatePicker(
                        c,
                        initial: receivedAt,
                        title: 'تاریخ پذیرش',
                      );
                      if (p != null) setSt(() => receivedAt = p);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: typeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'نوع دستگاه *',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: modelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'مدل دستگاه',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: serialCtrl,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'شماره سریال',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: valCtrl,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'ارزش تعیین‌شده (ریال) *',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'یادداشت',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () async {
                      if (partyId <= 0 ||
                          typeCtrl.text.trim().isEmpty ||
                          parseNum(valCtrl.text) <= 0) {
                        _toast(
                          'مشتری، نوع دستگاه و ارزش تعیین‌شده را وارد کنید.',
                        );
                        return;
                      }
                      try {
                        await _repo.saveShopTradeIn(
                          ShopTradeIn(
                            id: source?.id ?? 0,
                            operationId: opId,
                            number: source?.number ?? '',
                            partyId: partyId,
                            deviceType: typeCtrl.text.trim(),
                            deviceModel: modelCtrl.text.trim().isEmpty
                                ? null
                                : modelCtrl.text.trim(),
                            serialNumber: serialCtrl.text.trim().isEmpty
                                ? null
                                : serialCtrl.text.trim(),
                            value: parseNum(valCtrl.text),
                            note: noteCtrl.text.trim().isEmpty
                                ? null
                                : noteCtrl.text.trim(),
                            receivedAt: receivedAt,
                          ),
                        );
                        if (c.mounted) Navigator.pop(c, true);
                      } catch (e) {
                        _toast(e.toString());
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: ShopColors.seed,
                    ),
                    child: const Text('ذخیره پیش‌نویس'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (saved == true) {
      _toast('پیش‌نویس تعویض ثبت شد.', ok: true);
      _load();
    }
  }

  Future<void> _finalize(ShopTradeIn t) async {
    if (_saving) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('نهایی‌سازی ${t.number}'),
        content: Text(
          'نهایی‌سازی ${t.number} و ثبت اعتبار ${Fa.number(t.value)} ریالی برای ${t.partyName}؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('تأیید و ثبت اعتبار'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await _repo.finalizeShopTradeIn(t.id, date: DateTime.now());
      _toast('اعتبار مشتری ثبت شد.', ok: true);
      await _load();
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openUse(ShopTradeIn t) async {
    List<ShopTradeInTargetSale> orders = const [];
    List<TrsAccount> accounts = const [];
    try {
      orders = await _repo.shopTradeInTargetSales(t.partyId);
    } catch (_) {}
    try {
      accounts = await _repo.trsAccounts();
    } catch (_) {}
    if (!mounted) return;

    int useKind = TradeInUseKind.applyToSale;
    int targetSaleId = 0;
    int accountId = 0;
    DateTime useDate = DateTime.now();
    final amountCtrl = TextEditingController(
      text: t.availableCredit.round().toString(),
    );
    final opId = ShopRepository.newOperationId();

    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => StatefulBuilder(
        builder: (c, setSt) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'مصرف یا پرداخت اعتبار مشتری',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${t.partyName} — اعتبار باقیمانده: ${Fa.number(t.availableCredit)} ریال',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ShopColors.seed,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: useKind,
                    decoration: const InputDecoration(
                      labelText: 'نوع عملیات',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: TradeInUseKind.applyToSale,
                        child: Text('تسویه فاکتور فروش'),
                      ),
                      DropdownMenuItem(
                        value: TradeInUseKind.refund,
                        child: Text('پرداخت وجه به مشتری'),
                      ),
                    ],
                    onChanged: (v) =>
                        setSt(() => useKind = v ?? TradeInUseKind.applyToSale),
                  ),
                  const SizedBox(height: 10),
                  _DateTile(
                    label: 'تاریخ عملیات',
                    value: useDate,
                    onTap: () async {
                      final p = await showJalaliDatePicker(
                        c,
                        initial: useDate,
                        title: 'تاریخ عملیات',
                      );
                      if (p != null) setSt(() => useDate = p);
                    },
                  ),
                  const SizedBox(height: 10),
                  if (useKind == TradeInUseKind.applyToSale)
                    DropdownButtonFormField<int>(
                      initialValue: orders.any((o) => o.id == targetSaleId)
                          ? targetSaleId
                          : 0,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'فاکتور فروش همین مشتری *',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 0,
                          child: Text('— انتخاب فاکتور —'),
                        ),
                        for (final o in orders)
                          DropdownMenuItem(
                            value: o.id,
                            child: Text(
                              '${o.number} — ${Fa.number(o.totalAmount)} ریال',
                            ),
                          ),
                      ],
                      onChanged: (v) => setSt(() => targetSaleId = v ?? 0),
                    )
                  else
                    DropdownButtonFormField<int>(
                      initialValue: accounts.any((a) => a.id == accountId)
                          ? accountId
                          : 0,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'صندوق / بانک پرداخت *',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 0,
                          child: Text('— انتخاب حساب —'),
                        ),
                        for (final a in accounts)
                          DropdownMenuItem(value: a.id, child: Text(a.name)),
                      ],
                      onChanged: (v) => setSt(() => accountId = v ?? 0),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'مبلغ عملیات (ریال) *',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () async {
                      final amt = parseNum(amountCtrl.text);
                      if (amt <= 0) {
                        _toast('مبلغ عملیات را وارد کنید.');
                        return;
                      }
                      try {
                        await _repo.useShopTradeIn(
                          t.id,
                          kind: useKind,
                          amount: amt,
                          date: useDate,
                          targetSaleId: useKind == TradeInUseKind.applyToSale
                              ? targetSaleId
                              : null,
                          trsAccountId: useKind == TradeInUseKind.refund
                              ? accountId
                              : null,
                          operationId: opId,
                        );
                        if (c.mounted) Navigator.pop(c, true);
                      } catch (e) {
                        _toast(e.toString());
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: ShopColors.seed,
                    ),
                    child: const Text('ثبت عملیات'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (done == true) {
      _toast('عملیات اعتبار ثبت شد.', ok: true);
      _load();
    }
  }

  void _openHistory(ShopTradeIn t) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'گردش اعتبار تعویض — ${t.number}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            for (final u in t.uses)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${u.kindLabel} → ${u.destinationLabel}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  Fa.date(u.date?.toIso8601String(), time: false),
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Text(
                  '${Fa.number(u.amount)} ریال',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.seed,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        children: [
          if (_canManage)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                onPressed: () => _openForm(),
                style: FilledButton.styleFrom(backgroundColor: ShopColors.seed),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'پذیرش تعویض',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ShopColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ShopColors.line),
            ),
            child: const Text(
              'ارزش دستگاه را فروشگاه تعیین می‌کند؛ دستگاه فعلاً وارد موجودی نمی‌شود. پس از نهایی‌سازی، ارزش دستگاه به اعتبار مشتری افزوده شده و در تسویه فاکتور فروش یا پرداخت وجه قابل مصرف است.',
              style: TextStyle(
                fontSize: 11,
                height: 1.7,
                color: ShopColors.inkSoft,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            ShopEmpty(
              icon: Icons.error_outline_rounded,
              title: 'پذیرش‌های تعویض دریافت نشد',
              subtitle: _error,
              actionLabel: 'تلاش دوباره',
              onAction: _load,
            )
          else if (_items.isEmpty)
            const ShopEmpty(
              icon: Icons.swap_horiz_rounded,
              title: 'پذیرش تعویضی ثبت نشده است',
              subtitle: 'با دکمهٔ «پذیرش تعویض» اولین دستگاه را ثبت کنید.',
            )
          else
            for (final t in _items)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
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
                          t.number,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: ShopColors.seed,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ShopTag(
                          text: t.isFinalized ? 'نهایی‌شده' : 'پیش‌نویس',
                          color: t.isFinalized ? ShopColors.ok : ShopColors.warn,
                        ),
                        const Spacer(),
                        Text(
                          Fa.date(t.receivedAt?.toIso8601String(), time: false),
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: ShopColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${t.partyName} — ${t.deviceLabel}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if ((t.serialNumber ?? '').trim().isNotEmpty)
                      Text(
                        'سریال: ${t.serialNumber}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'ارزش تعیین‌شده: ${Fa.number(t.value)} ریال · '
                      'اعتبار باقیمانده: ${Fa.number(t.availableCredit)} ریال',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: ShopColors.inkSoft,
                      ),
                    ),
                    const Divider(height: 14, color: ShopColors.line),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (!t.isFinalized && _canManage) ...[
                          TextButton.icon(
                            onPressed: () => _openForm(source: t),
                            icon: const Icon(Icons.edit_rounded, size: 15),
                            label: const Text(
                              'ویرایش',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _saving ? null : () => _finalize(t),
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 15,
                            ),
                            label: const Text(
                              'نهایی‌سازی',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                        ],
                        if (t.isFinalized &&
                            t.availableCredit > 0 &&
                            _canManage &&
                            _canSettle)
                          FilledButton.tonalIcon(
                            onPressed: () => _openUse(t),
                            icon: const Icon(Icons.payments_rounded, size: 15),
                            label: const Text(
                              'مصرف / پرداخت اعتبار',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                        if (t.uses.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => _openHistory(t),
                            icon: const Icon(Icons.history_rounded, size: 15),
                            label: const Text(
                              'گردش‌ها',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: ShopColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ShopColors.line),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_month_rounded,
            size: 16,
            color: ShopColors.inkSoft,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11.5, color: ShopColors.inkSoft),
          ),
          Text(
            jalaliShort(value),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}
