// ============================================================
//  شیت‌های عملیاتی فاکتورهای فروش (فاز ۲ فروشگاهی کایر)
//  آینهٔ دقیق مودال‌های `Pages/Orders/Orders.razor` در وب:
//    ۱. نسیه و سوابق دریافت فاکتور (`credit-receipts` + `reversal`)
//    ۲. برگشت کالا در فاکتور چکی (`cheque-return-preview` + `cheque-return`)
//    ۳. تعیین‌تکلیف بستانکاری مشتری (`credit-refund` + `credit-allocation`)
//    ۴. ابطال فاکتور چکی (`cheque-cancel`)
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/fa_num.dart';
import '../data/shop_repository.dart';
import '../models/order_models.dart';
import 'shop_style.dart';

// ============================================================
//  ۱. شیت نسیه و سوابق دریافت فاکتور
// ============================================================

Future<bool?> showOrderCreditSheet(
  BuildContext context, {
  required ShopRepository repo,
  required ShopOrder order,
  required bool canManage,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _OrderCreditSheet(
      repo: repo,
      order: order,
      canManage: canManage,
    ),
  );
}

class _OrderCreditSheet extends StatefulWidget {
  const _OrderCreditSheet({
    required this.repo,
    required this.order,
    required this.canManage,
  });

  final ShopRepository repo;
  final ShopOrder order;
  final bool canManage;

  @override
  State<_OrderCreditSheet> createState() => _OrderCreditSheetState();
}

class _OrderCreditSheetState extends State<_OrderCreditSheet> {
  ShopOrderCreditState _state = const ShopOrderCreditState();
  List<TrsAccount> _accounts = const [];
  int? _accountId;
  DateTime _date = DateTime.now();
  final _amountCtrl = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;

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
      final st = await widget.repo.orderCreditState(widget.order.id);
      List<TrsAccount> accs = _accounts;
      if (accs.isEmpty) {
        try {
          accs = await widget.repo.trsAccounts();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _state = st;
        _accounts = accs;
        _accountId ??=
            accs.where((a) => a.isDefault).firstOrNull?.id ??
            accs.firstOrNull?.id;
        if (st.outstanding > 0) {
          _amountCtrl.text = formatNumText(st.outstanding.toStringAsFixed(0));
        } else {
          _amountCtrl.clear();
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast(e.toString());
    }
  }

  Future<void> _submitReceipt() async {
    final amount = parseNum(_amountCtrl.text);
    if (amount <= 0) {
      _toast('مبلغ دریافتی را وارد کنید.');
      return;
    }
    if ((_accountId ?? 0) <= 0) {
      _toast('حساب صندوق/بانک مقصد را انتخاب کنید.');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.repo.addOrderCreditReceipt(
        widget.order.id,
        amount: amount,
        trsAccountId: _accountId!,
        date: _date,
      );
      _changed = true;
      _toast('دریافت نسیه ثبت شد.', ok: true);
      await _load();
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reverseReceipt(ShopOrderCreditReceipt r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text(
          'برگشت دریافت نسیه',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'آیا از ثبت سند برگشتی برای دریافت ${Fa.number(r.amount)} ریال مطمئن هستید؟',
          style: const TextStyle(fontSize: 12.5, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ShopColors.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('تأیید برگشت'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await widget.repo.reverseOrderCreditReceipt(
        widget.order.id,
        r.id,
        date: DateTime.now(),
      );
      _changed = true;
      _toast('دریافت برگشت داده شد.', ok: true);
      await _load();
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        backgroundColor: ok ? ShopColors.ok : ShopColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: ShopColors.surface,
            borderRadius: BorderRadius.circular(22),
          ),
          child: _loading
              ? const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: ShopColors.seed,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'نسیه و سوابق فاکتور ${Fa.digits(widget.order.number)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context, _changed),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ShopColors.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _kv(
                            'مانده نسیه قابل دریافت',
                            '${Fa.number(_state.outstanding)} ریال',
                            bold: true,
                            color: _state.outstanding > 0
                                ? ShopColors.danger
                                : ShopColors.ok,
                          ),
                          if (_state.reservedForCheques > 0)
                            _kv(
                              'رزروشده بابت چک‌ها',
                              '${Fa.number(_state.reservedForCheques)} ریال',
                            ),
                          if (_state.reservedForInstallments > 0)
                            _kv(
                              'رزروشده بابت اقساط',
                              '${Fa.number(_state.reservedForInstallments)} ریال',
                            ),
                          if (_state.availableCredit > 0)
                            _kv(
                              'بستانکاری مشتری روی این سند',
                              '${Fa.number(_state.availableCredit)} ریال',
                              color: ShopColors.teal,
                              bold: true,
                            ),
                        ],
                      ),
                    ),
                    if (widget.canManage &&
                        !_state.isCancelled &&
                        _state.outstanding > 0) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'ثبت دریافت جدید روی این فاکتور',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        onChanged: (v) {
                          final f = formatNumText(v);
                          if (f != v) {
                            _amountCtrl.value = TextEditingValue(
                              text: f,
                              selection: TextSelection.collapsed(
                                offset: f.length,
                              ),
                            );
                          }
                        },
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'مبلغ دریافتی (ریال)',
                        ),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        initialValue: _accountId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'صندوق / بانک مقصد',
                        ),
                        items: [
                          for (final a in _accounts)
                            DropdownMenuItem<int>(
                              value: a.id,
                              child: Text(
                                a.displayName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => _accountId = v),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final d = await showJalaliDatePicker(
                            context,
                            initial: _date,
                            title: 'تاریخ دریافت',
                          );
                          if (d != null && mounted) setState(() => _date = d);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ShopColors.line),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.event_rounded, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'تاریخ دریافت: ${jalaliShort(_date)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _busy ? null : _submitReceipt,
                        style: FilledButton.styleFrom(
                          backgroundColor: ShopColors.seed,
                          minimumSize: const Size.fromHeight(44),
                        ),
                        icon: const Icon(Icons.add_task_rounded, size: 18),
                        label: const Text('ثبت دریافت'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'سوابق دریافت‌های ثبت‌شده',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_state.receipts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'تا کنون دریافت جداگانه‌ای روی این فاکتور ثبت نشده است.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: ShopColors.inkFaint,
                          ),
                        ),
                      )
                    else
                      for (final r in _state.receipts)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: r.isReversed
                                ? const Color(0xFFFEF2F2)
                                : ShopColors.bg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${Fa.number(r.amount)} ریال — ${r.accountName}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        decoration: r.isReversed
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                    Text(
                                      'تاریخ: ${Fa.date(r.date?.toIso8601String(), time: false)}'
                                      '${r.isReversed ? ' · برگشت‌شده' : ''}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: ShopColors.inkFaint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.canManage && !r.isReversed)
                                TextButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _reverseReceipt(r),
                                  icon: const Icon(
                                    Icons.undo_rounded,
                                    size: 15,
                                    color: ShopColors.danger,
                                  ),
                                  label: const Text(
                                    'برگشت',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: ShopColors.danger,
                                    ),
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
}

// ============================================================
//  ۲. شیت برگشت کالا در فاکتور چکی (`cheque-return`)
// ============================================================

Future<bool?> showChequeReturnSheet(
  BuildContext context, {
  required ShopRepository repo,
  required ShopOrder order,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ChequeReturnSheet(repo: repo, initialOrder: order),
  );
}

class _ChequeReturnSheet extends StatefulWidget {
  const _ChequeReturnSheet({required this.repo, required this.initialOrder});

  final ShopRepository repo;
  final ShopOrder initialOrder;

  @override
  State<_ChequeReturnSheet> createState() => _ChequeReturnSheetState();
}

class _ChequeReturnSheetState extends State<_ChequeReturnSheet> {
  late ShopOrder _order;
  final Map<int, String> _returnQtys = {};
  DateTime _date = DateTime.now();
  int _decision = ChequeReturnDecision.none;
  final _repNumberCtrl = TextEditingController();
  final _repBankCtrl = TextEditingController();
  final _repAmountCtrl = TextEditingController();
  DateTime _repDueDate = DateTime.now().add(const Duration(days: 30));
  final _noteCtrl = TextEditingController();

  SaleChequeReturnPreview? _preview;
  bool _loading = true;
  bool _previewing = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    _loadOrder();
  }

  @override
  void dispose() {
    _repNumberCtrl.dispose();
    _repBankCtrl.dispose();
    _repAmountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    try {
      final full = await widget.repo.order(_order.id);
      if (full != null) _order = full;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _selectedLines {
    final res = <Map<String, dynamic>>[];
    for (final l in _order.lines) {
      final q = parseNum(_returnQtys[l.id] ?? '');
      if (q > 0) {
        res.add({'orderLineId': l.id, 'quantity': q});
      }
    }
    return res;
  }

  OrderCheque? get _replacementCheque {
    if (_decision != ChequeReturnDecision.replaceCheque) return null;
    final amt = parseNum(_repAmountCtrl.text);
    if (_repNumberCtrl.text.trim().isEmpty || amt <= 0) return null;
    return OrderCheque(
      number: _repNumberCtrl.text.trim(),
      bankName: _repBankCtrl.text.trim(),
      amount: amt,
      dueDate: _repDueDate,
    );
  }

  Future<void> _runPreview() async {
    final lines = _selectedLines;
    if (lines.isEmpty) {
      _toast('ابتدا مقدار برگشتی حداقل یک ردیف را وارد کنید.');
      return;
    }
    setState(() => _previewing = true);
    try {
      final p = await widget.repo.previewChequeReturn(
        _order.id,
        date: _date,
        lines: lines,
        decision: _decision,
        replacementCheque: _replacementCheque,
        note: _noteCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _preview = p;
        if (p.uncollectedChequeExcess > 0 &&
            _decision == ChequeReturnDecision.none) {
          _decision = ChequeReturnDecision.keepChequeForGoods;
        }
      });
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _submit() async {
    final lines = _selectedLines;
    if (lines.isEmpty) {
      _toast('مقدار برگشتی حداقل یک ردیف را مشخص کنید.');
      return;
    }
    if (_decision == ChequeReturnDecision.replaceCheque &&
        _replacementCheque == null) {
      _toast('مشخصات و مبلغ چک جایگزین را کامل وارد کنید.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.repo.submitChequeReturn(
        _order.id,
        date: _date,
        lines: lines,
        decision: _decision,
        replacementCheque: _replacementCheque,
        note: _noteCtrl.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast(e.toString());
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        backgroundColor: ShopColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final returnable = _order.lines
        .where((l) => !l.isService && l.remainingQuantity > 0)
        .toList();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: _loading
            ? const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.assignment_return_rounded,
                        color: ShopColors.warn,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'برگشت کالا از فاکتور چکی ${Fa.digits(_order.number)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () async {
                      final d = await showJalaliDatePicker(
                        context,
                        initial: _date,
                        title: 'تاریخ برگشت کالا',
                      );
                      if (d != null && mounted) setState(() => _date = d);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: ShopColors.bg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'تاریخ برگشت: ${jalaliShort(_date)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (returnable.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'همه اقلام قابل برگشت این فاکتور قبلاً مرجوع شده‌اند.',
                        style: TextStyle(fontSize: 12),
                      ),
                    )
                  else
                    for (final l in returnable)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: ShopColors.bg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.productName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'قابل برگشت: ${Fa.number(l.remainingQuantity)} ${l.unit}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: ShopColors.inkFaint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                keyboardType: TextInputType.number,
                                textDirection: TextDirection.ltr,
                                onChanged: (v) {
                                  _returnQtys[l.id] = v;
                                  setState(() => _preview = null);
                                },
                                decoration: const InputDecoration(
                                  isDense: true,
                                  hintText: 'مقدار برگشت',
                                  hintStyle: TextStyle(fontSize: 10.5),
                                ),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                  TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'توضیح برگشت (اختیاری)',
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _previewing ? null : _runPreview,
                    icon: const Icon(Icons.calculate_outlined, size: 17),
                    label: Text(
                      _previewing
                          ? 'در حال محاسبه…'
                          : 'محاسبه پیش‌نمایش مالی برگشت',
                    ),
                  ),
                  if (_preview != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ShopColors.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _kv(
                            'ارزش خالص کالای مرجوعی',
                            '${Fa.number(_preview!.goodsBeforeVat)} ریال',
                          ),
                          if (_preview!.vat > 0)
                            _kv(
                              'ارزش افزوده برگشتی',
                              '${Fa.number(_preview!.vat)} ریال',
                            ),
                          if (_preview!.income > 0)
                            _kv(
                              'کاهش کارمزد تاخیر تادیه چک',
                              '${Fa.number(_preview!.income)} ریال',
                            ),
                          _kv(
                            'جمع بستانکاری برگشت',
                            '${Fa.number(_preview!.totalCredit)} ریال',
                            bold: true,
                            color: ShopColors.teal,
                          ),
                          if (_preview!.uncollectedChequeExcess > 0)
                            _kv(
                              'مازاد چک‌های وصول‌نشده',
                              '${Fa.number(_preview!.uncollectedChequeExcess)} ریال',
                              color: ShopColors.warn,
                              bold: true,
                            ),
                        ],
                      ),
                    ),
                    if (_preview!.uncollectedChequeExcess > 0) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'تصمیم مشتری درباره مازاد چک وصول‌نشده:',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      RadioGroup<int>(
                        groupValue: _decision,
                        onChanged: (v) => setState(
                          () =>
                              _decision = v ?? ChequeReturnDecision.keepChequeForGoods,
                        ),
                        child: const Column(
                          children: [
                            RadioListTile<int>(
                              dense: true,
                              value: ChequeReturnDecision.keepChequeForGoods,
                              title: Text(
                                'نگه‌داشتن چک نزد فروشگاه بابت خرید بعدی (ثبت بستانکاری)',
                                style: TextStyle(fontSize: 11.5),
                              ),
                            ),
                            RadioListTile<int>(
                              dense: true,
                              value: ChequeReturnDecision.replaceCheque,
                              title: Text(
                                'عودت چک قبلی و دریافت چک جایگزین',
                                style: TextStyle(fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_decision == ChequeReturnDecision.replaceCheque) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _repNumberCtrl,
                                textDirection: TextDirection.ltr,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  labelText: 'شماره چک جایگزین',
                                ),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                controller: _repBankCtrl,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  labelText: 'نام بانک',
                                ),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _repAmountCtrl,
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                          onChanged: (v) {
                            final f = formatNumText(v);
                            if (f != v) {
                              _repAmountCtrl.value = TextEditingValue(
                                text: f,
                                selection: TextSelection.collapsed(
                                  offset: f.length,
                                ),
                              );
                            }
                          },
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'مبلغ چک جایگزین (ریال)',
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ],
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _submitting || returnable.isEmpty
                        ? null
                        : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: ShopColors.warn,
                      minimumSize: const Size.fromHeight(46),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(_submitting ? 'در حال ثبت…' : 'ثبت نهایی برگشت'),
                  ),
                ],
              ),
      ),
    );
  }
}

// ============================================================
//  ۳. شیت تعیین‌تکلیف بستانکاری مشتری (`credit-refund` / `credit-allocation`)
// ============================================================

Future<bool?> showCreditSettlementSheet(
  BuildContext context, {
  required ShopRepository repo,
  required ShopOrder order,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CreditSettlementSheet(repo: repo, order: order),
  );
}

class _CreditSettlementSheet extends StatefulWidget {
  const _CreditSettlementSheet({required this.repo, required this.order});

  final ShopRepository repo;
  final ShopOrder order;

  @override
  State<_CreditSettlementSheet> createState() => _CreditSettlementSheetState();
}

class _CreditSettlementSheetState extends State<_CreditSettlementSheet> {
  bool _isAllocation = false;
  late final _amountCtrl = TextEditingController(
    text: formatNumText(
      widget.order.availableCustomerCredit.toStringAsFixed(0),
    ),
  );
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();

  List<TrsAccount> _accounts = const [];
  List<ShopOrder> _partyOrders = const [];
  int? _accountId;
  int? _targetOrderId;
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
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final accs = await widget.repo.trsAccounts();
      final ords = await widget.repo.orders(
        type: TxnType.sale,
        partyId: widget.order.partyId,
        pageSize: 50,
      );
      if (!mounted) return;
      setState(() {
        _accounts = accs;
        _accountId =
            accs.where((a) => a.isDefault).firstOrNull?.id ??
            accs.firstOrNull?.id;
        _partyOrders = ords.items
            .where((o) => o.id != widget.order.id && !o.isCancelled)
            .toList();
        _targetOrderId = _partyOrders.firstOrNull?.id;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final amt = parseNum(_amountCtrl.text);
    if (amt <= 0 || amt > widget.order.availableCustomerCredit) {
      _toast('مبلغ واردشده معتبر نیست یا از سقف بستانکاری بیشتر است.');
      return;
    }
    setState(() => _saving = true);
    try {
      if (_isAllocation) {
        if ((_targetOrderId ?? 0) <= 0) {
          setState(() => _saving = false);
          _toast('فاکتور مقصد را انتخاب کنید.');
          return;
        }
        await widget.repo.allocateCustomerCredit(
          widget.order.id,
          targetOrderId: _targetOrderId!,
          amount: amt,
          date: _date,
          note: _noteCtrl.text,
        );
      } else {
        if ((_accountId ?? 0) <= 0) {
          setState(() => _saving = false);
          _toast('حساب پرداخت را انتخاب کنید.');
          return;
        }
        await widget.repo.refundCustomerCredit(
          widget.order.id,
          amount: amt,
          trsAccountId: _accountId!,
          date: _date,
          note: _noteCtrl.text,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.toString());
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        backgroundColor: ShopColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: _loading
            ? const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'تعیین‌تکلیف بستانکاری مشتری',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                  Text(
                    'بستانکاری قابل تخصیص: ${Fa.number(widget.order.availableCustomerCredit)} ریال',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: ShopColors.teal,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text(
                          'بازپرداخت نقدی/بانکی',
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text(
                          'اعمال به فاکتور دیگر',
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ],
                    selected: {_isAllocation},
                    onSelectionChanged: (s) =>
                        setState(() => _isAllocation = s.first),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    onChanged: (v) {
                      final f = formatNumText(v);
                      if (f != v) {
                        _amountCtrl.value = TextEditingValue(
                          text: f,
                          selection: TextSelection.collapsed(offset: f.length),
                        );
                      }
                    },
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'مبلغ (ریال)',
                    ),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 8),
                  if (!_isAllocation)
                    DropdownButtonFormField<int>(
                      initialValue: _accountId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'پرداخت از حساب صندوق / بانک',
                      ),
                      items: [
                        for (final a in _accounts)
                          DropdownMenuItem<int>(
                            value: a.id,
                            child: Text(
                              a.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _accountId = v),
                    )
                  else
                    DropdownButtonFormField<int>(
                      initialValue: _targetOrderId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'فاکتور فروش مقصد',
                      ),
                      items: [
                        for (final o in _partyOrders)
                          DropdownMenuItem<int>(
                            value: o.id,
                            child: Text(
                              'فاکتور ${Fa.digits(o.number)} — ${Fa.number(o.totalAmount)} ریال',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _targetOrderId = v),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'توضیح (اختیاری)',
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: ShopColors.teal,
                      minimumSize: const Size.fromHeight(45),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(_saving ? 'در حال ثبت…' : 'ثبت تسویه بستانکاری'),
                  ),
                ],
              ),
      ),
    );
  }
}

// ============================================================
//  ۴. دیالوگ ابطال فاکتور چکی (`cheque-cancel`)
// ============================================================

Future<bool> confirmChequeCancelDialog(
  BuildContext context, {
  required ShopRepository repo,
  required ShopOrder order,
}) async {
  final noteCtrl = TextEditingController();
  DateTime cancelDate = DateTime.now();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setSt) => AlertDialog(
        title: Text(
          'ابطال فاکتور چکی ${Fa.digits(order.number)}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'با ابطال این فاکتور، اقلام به انبار برمی‌گردد و چک‌های وصول‌نشده باطل می‌شود.',
              style: TextStyle(fontSize: 12, height: 1.6),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final d = await showJalaliDatePicker(
                  c,
                  initial: cancelDate,
                  title: 'تاریخ ابطال',
                );
                if (d != null) setSt(() => cancelDate = d);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'تاریخ ابطال: ${jalaliShort(cancelDate)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ShopColors.seed,
                  ),
                ),
              ),
            ),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'علت ابطال (اختیاری)',
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ShopColors.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('تأیید ابطال'),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true) return false;
  await repo.cancelChequeOrder(
    order.id,
    date: cancelDate,
    note: noteCtrl.text,
  );
  return true;
}

Widget _kv(
  String k,
  String v, {
  bool bold = false,
  Color color = ShopColors.ink,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 2),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        k,
        style: const TextStyle(fontSize: 11, color: ShopColors.inkFaint),
      ),
      Text(
        v,
        style: TextStyle(
          fontSize: bold ? 12 : 11.5,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
          color: color,
        ),
      ),
    ],
  ),
);
