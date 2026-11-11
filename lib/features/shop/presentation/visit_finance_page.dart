// ============================================================
//  تأیید مالی سفارش ویزیتوری — آینهٔ VisFinanceModal.razor
//
//  مسیر وب: «صف مالی» / «همهٔ درخواست‌ها» → دکمهٔ «تأیید مالی»
//  ساختار عیناً وب: نقدی (صندوق/بانک) ← چک ← اقساط ← نسیه
//  با ثبت، سند فروش فروشگاه ساخته می‌شود و سفارش «فروش‌شده» می‌گردد.
//
//  اعتبارسنجی‌ها و پیام‌ها کلمه‌به‌کلمه از وب:
//   • پیش‌دریافت نقدی نمی‌تواند برابر یا بیشتر از مبلغ سفارش باشد...
//   • صندوق/بانک دریافت را انتخاب کنید.
//   • حداقل یک چک ثبت کنید. / شماره چک ردیف N ... / سررسید چک ردیف N ...
//   • مبلغ چک ردیف N را وارد کنید. / ابتدا دفترچه اقساط را بسازید.
//   • جمع پرداخت‌ها (...) کمتر از مبلغ سفارش (...) است؛ ...
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/fa_num.dart';
import '../data/shop_repository.dart';
import '../models/order_models.dart';
import '../models/visit_models.dart';
import 'shop_style.dart';

class VisitFinancePage extends StatefulWidget {
  const VisitFinancePage({super.key, required this.order});

  final VisOrder order;

  @override
  State<VisitFinancePage> createState() => _VisitFinancePageState();
}

class _ChequeVm {
  String number = '';
  String bankName = '';
  String ownerName = '';
  final amountCtrl = TextEditingController();
  DateTime? dueDate;
}

class _InstVm {
  _InstVm({this.no = 1, required this.amount, required this.dueDate});

  int no;
  final double amount;
  DateTime dueDate;
  final TextEditingController amountCtrl = TextEditingController();
}

class _VisitFinancePageState extends State<VisitFinancePage> {
  late final ShopRepository _repo;

  List<TrsAccount> _accounts = const [];
  bool _loadingAccounts = true;

  bool _useCash = true;
  bool _useCheque = false;
  bool _useInst = false;
  bool _useCredit = false;

  String _cashType = '0';
  int _trsAccountId = 0;
  final _cashCtrl = TextEditingController();
  DateTime? _dueDate;
  final _commentCtrl = TextEditingController();

  final List<_ChequeVm> _cheques = [];
  final List<_InstVm> _insts = [];
  int _instCount = 3;
  int _instInterval = 30;
  DateTime? _instFirstDue;

  bool _busy = false;

  double get _total => widget.order.totalNet;

  int get _cashKind => int.tryParse(_cashType) ?? 0;

  /// همان `HasNonCash` وب
  bool get _hasNonCash => _useCheque || _useInst || _useCredit;

  /// همان `CashPart`: اگر تنها جزء باشد تمام مبلغ سفارش
  double get _cashPart => !_hasNonCash ? _total : parseNum(_cashCtrl.text);

  double get _chequeSum =>
      _useCheque ? _cheques.fold<double>(0, (s, c) => s + parseNum(c.amountCtrl.text)) : 0;

  double get _instSum =>
      _useInst ? _insts.fold<double>(0, (s, r) => s + parseNum(r.amountCtrl.text)) : 0;

  double get _finalRemaining => _total - _cashPart - _chequeSum - _instSum;

  /// همان `DeclaredMethod` وب — سرور خودش جزء ترکیبی را استخراج می‌کند
  int get _declaredMethod => !_hasNonCash
      ? PayMethod.cash
      : _useCheque
      ? PayMethod.cheque
      : _useInst
      ? PayMethod.installment
      : PayMethod.credit;

  /// همان قاعدهٔ فیلتر حساب بر اساس نوع دریافت
  List<TrsAccount> get _accountsForCashType => switch (_cashKind) {
    CashKind.cash => _accounts
        .where(
          (a) => a.kind == AccountKind.cash || a.kind == AccountKind.pettyCash,
        )
        .toList(),
    CashKind.cardReader => _accounts
        .where((a) => a.kind == AccountKind.pos || a.kind == AccountKind.bank)
        .toList(),
    CashKind.cardTransfer => _accounts
        .where((a) => a.kind == AccountKind.pos || a.kind == AccountKind.bank)
        .toList(),
    _ => _accounts,
  };

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    // پیش‌فرض‌ها از انتخاب ویزیتور — همان OnParametersSetAsync وب
    final pm = widget.order.paymentMethod;
    _useCheque = pm == PayMethod.cheque;
    _useInst = pm == PayMethod.installment;
    _useCredit = pm == PayMethod.credit;
    _useCash = !_hasNonCash;
    _dueDate = _useCredit ? _monthLater(1) : null;
    _instFirstDue = _monthLater(1);
    if (_useCheque) _addCheque();
    if (_useInst) _buildInsts(silent: true);
    _loadAccounts();
  }

  static DateTime _monthLater(int m) {
    final n = DateTime.now();
    return DateTime(n.year, n.month + m, n.day);
  }

  @override
  void dispose() {
    _cashCtrl.dispose();
    _commentCtrl.dispose();
    for (final c in _cheques) {
      c.amountCtrl.dispose();
    }
    for (final r in _insts) {
      r.amountCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final list = await _repo.trsAccounts(activeOnly: true);
      if (!mounted) return;
      setState(() {
        _accounts = list;
        final def = list.where((a) => a.isDefault).firstOrNull ??
            (list.isEmpty ? null : list.first);
        _trsAccountId = def?.id ?? 0;
        _loadingAccounts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingAccounts = false);
      _toast(_clean(e));
    }
  }

  void _toast(String msg, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        backgroundColor: ok ? ShopColors.ok : null,
      ),
    );
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');

  // ---------------- اجزای پرداخت ----------------

  void _toggleCash() {
    setState(() {
      _useCash = !_useCash;
      if (!_useCash && !_hasNonCash) _useCash = true;
    });
  }

  void _toggleCheque() {
    setState(() {
      _useCheque = !_useCheque;
      if (_useCheque && _cheques.isEmpty) _addCheque();
    });
  }

  void _toggleInst() {
    setState(() {
      _useInst = !_useInst;
      if (_useInst && _insts.isEmpty) _buildInsts(silent: true);
    });
  }

  void _toggleCredit() {
    setState(() {
      _useCredit = !_useCredit;
      if (_useCredit && _dueDate == null) _dueDate = _monthLater(1);
    });
  }

  void _setCashType(String v) {
    setState(() {
      _cashType = v;
      final valid = _accountsForCashType;
      if (_trsAccountId > 0 && !valid.any((a) => a.id == _trsAccountId)) {
        _trsAccountId = valid.where((a) => a.isDefault).firstOrNull?.id ??
            (valid.isEmpty ? 0 : valid.first.id);
      }
    });
  }

  /// سطر چک جدید — مبلغ پیش‌فرض = باقی‌ماندهٔ فعلی (همان `AddCheque` وب)
  void _addCheque() {
    final rest = _finalRemaining;
    final c = _ChequeVm()
      ..dueDate = _monthLater(2);
    if (rest > 0) c.amountCtrl.text = formatNumText(rest.toStringAsFixed(0));
    _cheques.add(c);
  }

  void _removeCheque(int i) {
    final c = _cheques.removeAt(i);
    c.amountCtrl.dispose();
    setState(() {});
  }

  void _removeInst(int i) {
    final r = _insts.removeAt(i);
    r.amountCtrl.dispose();
    setState(() {});
  }

  /// همان `BuildInstallments` وب — تقسیم مساوی با تعدیل آخرین قسط
  void _buildInsts({bool silent = false}) {
    if (_instCount < 1) {
      if (!silent) _toast('تعداد قسط را وارد کنید.');
      return;
    }
    if (_instFirstDue == null) {
      if (!silent) _toast('تاریخ اولین قسط را وارد کنید.');
      return;
    }
    final payable = (_total - _cashPart - _chequeSum);
    if (payable <= 0) {
      if (!silent) _toast('مبلغ قابل قسط‌بندی باقی نمانده است.');
      return;
    }
    setState(() {
      for (final r in _insts) {
        r.amountCtrl.dispose();
      }
      _insts.clear();
      final per = (payable / _instCount).roundToDouble();
      for (var i = 0; i < _instCount; i++) {
        final amount = i == _instCount - 1
            ? payable - per * (_instCount - 1)
            : per;
        final due = _instFirstDue!.add(Duration(days: _instInterval * i));
        final vm = _InstVm(no: i + 1, amount: amount, dueDate: due);
        vm.amountCtrl.text = formatNumText(amount.toStringAsFixed(0));
        _insts.add(vm);
      }
    });
    if (!silent) _toast('${Fa.digits(_instCount)} قسط ساخته شد.', ok: true);
  }

  Future<void> _submit() async {
    final o = widget.order;

    // ---------- جزء نقدی ----------
    if (_hasNonCash && _cashPart > 0 && _cashPart >= _total) {
      _toast(
        'پیش‌دریافت نقدی نمی‌تواند برابر یا بیشتر از مبلغ سفارش باشد؛ در این صورت فقط «نقدی» را فعال کنید.',
      );
      return;
    }
    if (_useCash && _trsAccountId == 0 && _accounts.isNotEmpty) {
      _toast('صندوق/بانک دریافت را انتخاب کنید.');
      return;
    }
    final cash = _hasNonCash ? _cashPart : _total;

    final cmd = <String, dynamic>{
      'id': o.id,
      'paymentMethod': _declaredMethod,
      'cashType': _cashKind,
      if (_trsAccountId > 0) 'trsAccountId': _trsAccountId,
      'cashAmount': _hasNonCash ? cash : 0,
      'comment': _commentCtrl.text.trim().isEmpty
          ? null
          : _commentCtrl.text.trim(),
    };

    // ---------- جزء چک ----------
    final chequeList = <Map<String, dynamic>>[];
    if (_useCheque) {
      if (_cheques.isEmpty) {
        _toast('حداقل یک چک ثبت کنید.');
        return;
      }
      for (var i = 0; i < _cheques.length; i++) {
        final c = _cheques[i];
        if (c.number.trim().isEmpty) {
          _toast('شماره چک ردیف ${Fa.digits(i + 1)} را وارد کنید.');
          return;
        }
        if (c.dueDate == null) {
          _toast('سررسید چک ردیف ${Fa.digits(i + 1)} را وارد کنید.');
          return;
        }
        final amount = parseNum(c.amountCtrl.text);
        if (amount <= 0) {
          _toast('مبلغ چک ردیف ${Fa.digits(i + 1)} را وارد کنید.');
          return;
        }
        chequeList.add({
          'id': 0,
          'number': c.number.trim(),
          'trsAccountId': null,
          'bankName': c.bankName.trim().isEmpty ? null : c.bankName.trim(),
          'ownerName': c.ownerName.trim().isEmpty ? null : c.ownerName.trim(),
          'amount': amount,
          'dueDate': c.dueDate!.toIso8601String(),
          'isCleared': false,
        });
      }
    }
    cmd['cheques'] = chequeList;

    // ---------- جزء اقساط ----------
    final instList = <Map<String, dynamic>>[];
    if (_useInst) {
      if (_insts.isEmpty) {
        _toast('ابتدا دفترچه اقساط را بسازید.');
        return;
      }
      for (var i = 0; i < _insts.length; i++) {
        final r = _insts[i];
        final amount = parseNum(r.amountCtrl.text);
        if (amount <= 0) {
          _toast('مبلغ قسط ${Fa.digits(i + 1)} را وارد کنید.');
          return;
        }
        instList.add({
          'id': 0,
          'no': i + 1,
          'amount': amount,
          'dueDate': r.dueDate.toIso8601String(),
          'isPaid': false,
        });
      }
    }
    cmd['installments'] = instList;

    // ---------- ماندهٔ نهایی = نسیه ----------
    final paid = cash +
        chequeList.fold<double>(0, (s, c) => s + (c['amount'] as double)) +
        instList.fold<double>(0, (s, r) => s + (r['amount'] as double));
    final remainder = _total - paid;
    if (remainder > 1) {
      if (!_useCredit || _dueDate == null) {
        _toast(
          'جمع پرداخت‌ها (${Fa.number(paid)}) کمتر از مبلغ سفارش (${Fa.number(_total)}) است؛ '
          'باقی‌ماندهٔ ${Fa.number(remainder)} ریال به نسیه می‌رود — جزء «نسیه» را فعال و تاریخ سررسید را وارد کنید.',
        );
        return;
      }
      cmd['dueDate'] = _dueDate!.toIso8601String();
    } else {
      cmd['dueDate'] = null;
    }

    setState(() => _busy = true);
    try {
      final res = await _repo.visFinanceApprove(o.id, cmd);
      if (!mounted) return;
      _toast(
        'سفارش ${res.number} به فروش فروشگاه منتقل شد.',
        ok: true,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _toast(_clean(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate({
    required DateTime? initial,
    required ValueChanged<DateTime> onPicked,
    String title = 'انتخاب تاریخ',
  }) async {
    final d = await showJalaliDatePicker(
      context,
      initial: initial ?? DateTime.now(),
      title: title,
    );
    if (d != null) setState(() => onPicked(d));
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: Text(
          'تأیید مالی سفارش ${o.number}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
      body: _loadingAccounts
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
              children: [
                _headCard(o),
                if (o.stockWarnings.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _stockWarn(o),
                ],
                const SizedBox(height: 10),
                _payBox(),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: ShopColors.indigo.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'با این تأیید، سند فروش در فهرست «فروش» سامانه فروشگاهی ثبت می‌شود، '
                    'موجودی انبار کم می‌شود و سند حسابداری خودکار صادر می‌گردد.',
                    style: TextStyle(fontSize: 10, color: ShopColors.indigo),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 46),
                        ),
                        child: const Text(
                          'انصراف',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 46),
                          backgroundColor: ShopColors.seed,
                        ),
                        icon: _busy
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline_rounded,
                                size: 17),
                        label: const Text(
                          'تأیید مالی و ثبت فروش',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _headCard(VisOrder o) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      children: [
        _kv('مشتری', o.partyName),
        _kv('ویزیتور', o.referrerName.isEmpty ? '—' : o.referrerName),
        _kv('انبار', o.warehouseName),
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(
            children: [
              const Text(
                'مبلغ سفارش',
                style: TextStyle(fontSize: 11, color: ShopColors.inkFaint),
              ),
              const Spacer(),
              Text(
                '${Fa.number(_total)} ریال',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.seed,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _stockWarn(VisOrder o) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: ShopColors.warn.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ShopColors.warn.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: ShopColors.warn),
            SizedBox(width: 6),
            Text(
              'موجودی انبار برای این اقلام کافی نیست:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: ShopColors.warn,
              ),
            ),
          ],
        ),
        for (final w in o.stockWarnings)
          Text(
            '${w.productName} — موجودی ${Fa.number(w.available, decimals: 2)}، '
            'نیاز ${Fa.number(w.required, decimals: 2)}',
            style: const TextStyle(fontSize: 10, color: ShopColors.inkSoft),
          ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'ثبت فروش، موجودی را از انبار کم می‌کند؛ پیش از تأیید، از «خرید» یا «موجودی اول دوره» تأمین کنید.',
            style: TextStyle(fontSize: 9.5, color: ShopColors.warn),
          ),
        ),
      ],
    ),
  );

  Widget _payBox() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.credit_card_rounded,
              size: 16,
              color: ShopColors.seed,
            ),
            SizedBox(width: 6),
            Text(
              'روش پرداخت نهایی (ترکیبی)',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 3),
        const Text(
          'چند جزء را هم‌زمان فعال کنید؛ باقی‌ماندهٔ هر سطر از مبلغ سفارش و سطرهای قبلی محاسبه می‌شود.',
          style: TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _payTab('نقدی', Icons.payments_rounded, _useCash, _toggleCash),
            _payTab('چک', Icons.account_balance_rounded, _useCheque,
                _toggleCheque),
            _payTab('اقساطی', Icons.event_note_rounded, _useInst, _toggleInst),
            _payTab('نسیه', Icons.hourglass_bottom_rounded, _useCredit,
                _toggleCredit),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: ShopColors.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ShopColors.line),
          ),
          child: Column(
            children: [
              _sumRow('مبلغ سفارش', _total, ShopColors.seed),
              _sumRow('نقد', _cashPart, ShopColors.ok),
              _sumRow('چک', _chequeSum, ShopColors.ink),
              _sumRow('اقساط', _instSum, ShopColors.ink),
              Divider(height: 12, color: ShopColors.line),
              Row(
                children: [
                  Text(
                    _finalRemaining < -1 ? 'مازاد (سود مدت‌دار)' : 'باقی‌مانده',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    Fa.number(_finalRemaining.abs()),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: _finalRemaining < -1
                          ? ShopColors.warn
                          : _finalRemaining > 1
                          ? ShopColors.danger
                          : ShopColors.ok,
                    ),
                  ),
                  if (_finalRemaining > 1)
                    const Text(
                      '  (به نسیه می‌رود)',
                      style: TextStyle(
                        fontSize: 9,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_useCash) ...[
          const SizedBox(height: 10),
          if (_hasNonCash)
            ShopField(
              label: 'پیش‌دریافت نقدی (بخشی از مبلغ)',
              child: TextField(
                controller: _cashCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 12),
                decoration: _dec('0'),
              ),
            ),
          if (_hasNonCash) const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ShopField(
                  label: 'نوع دریافت نقدی',
                  child: DropdownButtonFormField<String>(
                    initialValue: _cashType,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: ShopColors.ink,
                    ),
                    decoration: _dec(null),
                    items: const [
                      DropdownMenuItem(value: '0', child: Text('وجه نقد')),
                      DropdownMenuItem(
                        value: '1',
                        child: Text('کارت‌خوان (POS)'),
                      ),
                      DropdownMenuItem(value: '2', child: Text('کارت به کارت')),
                    ],
                    onChanged: (v) => _setCashType(v ?? '0'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ShopField(
                  label: 'صندوق/بانک',
                  child: DropdownButtonFormField<int>(
                    initialValue: _accountsForCashType.any(
                      (a) => a.id == _trsAccountId,
                    )
                        ? _trsAccountId
                        : null,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: ShopColors.ink,
                    ),
                    decoration: _dec(null),
                    hint: const Text(
                      '— انتخاب حساب —',
                      style: TextStyle(fontSize: 11),
                    ),
                    items: [
                      for (final a in _accountsForCashType)
                        DropdownMenuItem(
                          value: a.id,
                          child: Text(
                            a.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _trsAccountId = v ?? 0),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _hasNonCash
                ? 'باقی‌مانده پس از نقد: ${Fa.number(_total - _cashPart)}'
                : 'تمام مبلغ نقدی است.',
            style: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
          ),
        ],
        if (_useCheque) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'چک‌ها',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(_addCheque),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text(
                  'افزودن چک',
                  style: TextStyle(fontSize: 10.5),
                ),
              ),
            ],
          ),
          for (var i = 0; i < _cheques.length; i++) _chequeRow(i),
        ],
        if (_useInst) ...[
          const SizedBox(height: 12),
          const Text(
            'دفترچهٔ اقساط',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ShopField(
                  label: 'تعداد قسط',
                  child: TextField(
                    controller: TextEditingController(
                      text: Fa.digits(_instCount),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 12),
                    onChanged: (v) => _instCount = int.tryParse(
                          toEnDigits(v),
                        ) ??
                        _instCount,
                    decoration: _dec(null),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ShopField(
                  label: 'فاصله (روز)',
                  child: TextField(
                    controller: TextEditingController(
                      text: Fa.digits(_instInterval),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 12),
                    onChanged: (v) =>
                        _instInterval = int.tryParse(toEnDigits(v)) ??
                        _instInterval,
                    decoration: _dec(null),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _dateField(
            label: 'تاریخ اولین قسط',
            value: _instFirstDue,
            onTap: () => _pickDate(
              initial: _instFirstDue,
              title: 'تاریخ اولین قسط',
              onPicked: (d) => _instFirstDue = d,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _buildInsts(),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 42),
                foregroundColor: ShopColors.seed,
                side: BorderSide(color: ShopColors.seed.withValues(alpha: 0.4)),
              ),
              icon: const Icon(Icons.playlist_add_rounded, size: 16),
              label: const Text(
                'ساخت دفترچه',
                style: TextStyle(fontSize: 11.5),
              ),
            ),
          ),
          if (_insts.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (var i = 0; i < _insts.length; i++) _instRow(i),
            Text(
              'جمع اقساط: ${Fa.number(_instSum)}',
              style: const TextStyle(fontSize: 10, color: ShopColors.inkSoft),
            ),
          ],
        ],
        if (_useCredit) ...[
          const SizedBox(height: 12),
          _dateField(
            label: 'تاریخ سررسید نسیه',
            value: _dueDate,
            onTap: () => _pickDate(
              initial: _dueDate,
              title: 'تاریخ سررسید نسیه',
              onPicked: (d) => _dueDate = d,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'مبلغ نسیه (باقی‌ماندهٔ نهایی): '
            '${Fa.number(_finalRemaining > 0 ? _finalRemaining : 0)} ریال — '
            'در حساب دریافتنی طرف حساب می‌نشیند.',
            style: const TextStyle(fontSize: 9.5, color: ShopColors.danger),
          ),
        ],
        const SizedBox(height: 10),
        ShopField(
          label: 'یادداشت مالی (اختیاری)',
          child: TextField(
            controller: _commentCtrl,
            style: const TextStyle(fontSize: 12),
            decoration: _dec('مثلاً: چک به ضمانت مدیرعامل…'),
          ),
        ),
      ],
    ),
  );

  Widget _chequeRow(int i) {
    final c = _cheques[i];
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: ShopColors.bg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'چک ${Fa.digits(i + 1)}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _removeCheque(i),
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: ShopColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ShopField(
                  label: 'شماره چک',
                  required: true,
                  child: TextField(
                    controller: TextEditingController(text: c.number),
                    style: const TextStyle(fontSize: 12),
                    onChanged: (v) => c.number = v,
                    decoration: _dec('—'),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ShopField(
                  label: 'مبلغ (ریال)',
                  required: true,
                  child: TextField(
                    controller: c.amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 12),
                    onChanged: (_) => setState(() {}),
                    decoration: _dec('0'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ShopField(
                  label: 'بانک',
                  child: TextField(
                    controller: TextEditingController(text: c.bankName),
                    style: const TextStyle(fontSize: 12),
                    onChanged: (v) => c.bankName = v,
                    decoration: _dec('نام بانک…'),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ShopField(
                  label: 'صاحب چک',
                  child: TextField(
                    controller: TextEditingController(text: c.ownerName),
                    style: const TextStyle(fontSize: 12),
                    onChanged: (v) => c.ownerName = v,
                    decoration: _dec(null),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _dateField(
            label: 'سررسید',
            required: true,
            value: c.dueDate,
            onTap: () => _pickDate(
              initial: c.dueDate,
              title: 'سررسید چک',
              onPicked: (d) => c.dueDate = d,
            ),
          ),
          const SizedBox(height: 3),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'باقی‌مانده پس از این چک: ${Fa.number(_remainingAfterCheque(i))}',
              style: const TextStyle(fontSize: 9, color: ShopColors.inkFaint),
            ),
          ),
        ],
      ),
    );
  }

  double _remainingAfterCheque(int i) {
    if (_cheques.isEmpty) return _total - _cashPart;
    final upto = i.clamp(0, _cheques.length - 1);
    var sum = _cashPart;
    for (var k = 0; k <= upto; k++) {
      sum += parseNum(_cheques[k].amountCtrl.text);
    }
    return _total - sum;
  }

  Widget _instRow(int i) {
    final r = _insts[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: ShopColors.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              'قسط ${Fa.digits(r.no)}',
              style: const TextStyle(fontSize: 10),
            ),
          ),
          Expanded(
            child: TextField(
              controller: r.amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 11.5),
              onChanged: (_) => setState(() {}),
              decoration: _dec('مبلغ'),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => _pickDate(
              initial: r.dueDate,
              title: 'سررسید قسط',
              onPicked: (d) => r.dueDate = d,
            ),
            child: Text(
              jalaliShort(r.dueDate),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: ShopColors.seed,
              ),
            ),
          ),
          InkWell(
            onTap: () => _removeInst(i),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.close_rounded,
                size: 15,
                color: ShopColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _payTab(String label, IconData icon, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: active ? ShopColors.seed : ShopColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? ShopColors.seed : ShopColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? Colors.white : ShopColors.inkSoft,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                color: active ? Colors.white : ShopColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sumRow(String label, double value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1.5),
    child: Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: ShopColors.inkSoft),
        ),
        const Spacer(),
        Text(
          Fa.number(value),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    bool required = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: ShopColors.inkSoft,
                ),
              ),
              if (required)
                const Text(
                  ' *',
                  style: TextStyle(fontSize: 11, color: ShopColors.danger),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
            decoration: BoxDecoration(
              color: ShopColors.surface,
              border: Border.all(color: ShopColors.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_rounded,
                  size: 14,
                  color: ShopColors.inkFaint,
                ),
                const SizedBox(width: 6),
                Text(
                  value == null ? 'انتخاب تاریخ' : jalaliShort(value),
                  style: const TextStyle(fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            k,
            style: const TextStyle(fontSize: 10, color: ShopColors.inkFaint),
          ),
        ),
        Expanded(
          child: Text(
            v.isEmpty ? '—' : v,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  InputDecoration _dec(String? hint) => InputDecoration(
    isDense: true,
    filled: true,
    fillColor: ShopColors.surface,
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 11, color: ShopColors.inkFaint),
    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
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
