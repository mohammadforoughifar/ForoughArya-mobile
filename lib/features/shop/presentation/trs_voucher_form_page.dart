// ============================================================
//  فرم سند دریافت / پرداخت / انتقال
//  آینهٔ صفحهٔ وب: /trs/vouchers/new/{Kind} ، /trs/vouchers/edit/{Id}
//                 → Pages/Treasury/TrsVoucherForm.razor
//
//  • سربرگ: شماره (سرور)، تاریخ شمسی، بابت، شماره عطف، طرف حساب + بانک سریع
//  • انتقال: حساب مبدأ/مقصد + کارمزد (بدون سطر و بدون فاکتور)
//  • دریافت/پرداخت:
//      - سطرهای ابزار: نقد / کارتخوان / حواله / چک / تخفیف
//        حساب‌ها همان‌طور که وب فیلتر می‌کند:
//          نقد  → صندوق + تنخواه
//          کارت → کارتخوان + بانک
//          حواله/چک → بانک
//      - تخصیص به فاکتورهای باز همان طرف حساب (چند فاکتور، مبلغ جزئی)
//  • دکمهٔ «ذخیره پیش‌نویس» و «ثبت و قطعی» — عیناً وب
//  • سند قطعی/ابطال‌شده قفل است (IsLocked وب)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/fa_num.dart';
import '../data/shop_repository.dart';
import '../models/shop_models.dart';
import '../models/treasury_models.dart';
import 'order_form_page.dart' show QuickBankSheet;
import 'shop_style.dart';

class TrsVoucherFormPage extends StatefulWidget {
  const TrsVoucherFormPage({
    super.key,
    required this.kind,
    this.voucherId,
    this.settleInvoiceId,
  });

  /// ۰ دریافت · ۱ پرداخت · ۲ انتقال
  final int kind;

  /// اگر > ۰ یعنی ویرایش سند موجود
  final int? voucherId;

  /// اگر مقدار داشته باشد، سند تسویهٔ آمادهٔ همان فاکتور از سرور گرفته می‌شود
  final int? settleInvoiceId;

  @override
  State<TrsVoucherFormPage> createState() => _TrsVoucherFormPageState();
}

class _TrsVoucherFormPageState extends State<TrsVoucherFormPage> {
  late final ShopRepository _repo;

  TreasuryVoucher? _doc;
  List<TreasuryAccount> _accounts = const [];
  List<Party> _parties = const [];
  List<SettlementInvoice> _openInvoices = const [];

  bool _loading = true;
  bool _saving = false;
  String? _error;

  int _kind = TrsKind.receipt;
  DateTime _date = DateTime.now();
  int? _partyId;
  String? _partyName;
  final _descCtrl = TextEditingController();
  final _refCtrl = TextEditingController();

  // انتقال
  int? _fromAccountId;
  int? _toAccountId;
  final _transferAmount = TextEditingController();
  final _feeCtrl = TextEditingController();

  bool get _isTransfer => _kind == TrsKind.transfer;

  bool get _locked =>
      _doc != null &&
      (_doc!.status == TrsState.confirmed ||
          _doc!.status == TrsState.cancelled);

  double get _total => _isTransfer
      ? parseNum(_transferAmount.text)
      : _lines.fold<double>(0, (s, l) => s + l.amount);

  // ------------------------------------------------------------
  //  بارگذاری
  // ------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _kind = widget.kind;
    _load();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _refCtrl.dispose();
    _transferAmount.dispose();
    _feeCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // حساب‌های خزانه + طرف حساب‌ها همیشه لازم‌اند
      final accs = await _repo.treasuryAccounts(activeOnly: true);
      List<Party> parties = const [];
      try {
        final c = await _repo.parties(type: 0, take: 1000);
        final s = await _repo.parties(type: 1, take: 1000);
        parties = [...c.items, ...s.items];
      } catch (_) {}

      TreasuryVoucher doc;
      if ((widget.voucherId ?? 0) > 0) {
        final existing = await _repo.treasuryVoucher(widget.voucherId!);
        if (existing == null) throw Exception('سند یافت نشد.');
        doc = existing;
      } else if ((widget.settleInvoiceId ?? 0) > 0) {
        doc = await _repo.settleVoucher(widget.settleInvoiceId!);
      } else {
        doc = await _repo.newVoucher(kind: widget.kind);
      }

      if (!mounted) return;
      setState(() {
        _accounts = accs;
        _parties = parties;
        _doc = doc;
        _kind = doc.kind;
        _date = doc.date ?? DateTime.now();
        _partyId = doc.partyId;
        _partyName = doc.partyName;
        _descCtrl.text = doc.description ?? '';
        _refCtrl.text = doc.refNumber ?? '';
        _fromAccountId = doc.fromAccountId;
        _toAccountId = doc.toAccountId;
        if (doc.feeAmount != 0) _feeCtrl.text = doc.feeAmount.toStringAsFixed(0);
        if (doc.isTransfer) {
          _transferAmount.text = doc.totalAmount == 0
              ? ''
              : doc.totalAmount.toStringAsFixed(0);
        } else {
          _lines
            ..clear()
            ..addAll(doc.lines.map(_LineVm.fromModel));
          for (final l in _lines) {
            _allocations[l] = const [];
          }
        }
        _loading = false;
      });
      if ((_partyId ?? 0) > 0) _loadOpenInvoices();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _clean(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadOpenInvoices() async {
    if ((_partyId ?? 0) <= 0) {
      setState(() => _openInvoices = const []);
      return;
    }
    try {
      final list = await _repo.openInvoices(
        partyId: _partyId!,
        kind: _kind == TrsKind.payment ? TrsKind.payment : TrsKind.receipt,
      );
      if (!mounted) return;
      setState(() => _openInvoices = list);
    } catch (_) {}
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');

  // ------------------------------------------------------------
  //  سطرها
  // ------------------------------------------------------------

  final List<_LineVm> _lines = [];
  final Map<_LineVm, List<InvoiceAllocation>> _allocations = {};

  /// همان `AccountsFor` وب
  List<TreasuryAccount> _accountsFor(int method) => switch (method) {
    TrsMethod.cash => _accounts
        .where((a) => a.kind == 0 || a.kind == 3)
        .toList(),
    TrsMethod.card => _accounts
        .where((a) => a.kind == 2 || a.kind == 1)
        .toList(),
    _ => _accounts.where((a) => a.kind == 1).toList(),
  };

  void _addLine(int method) {
    final pool = _accountsFor(method);
    final def = pool.where((a) => a.isDefault).firstOrNull ??
        (pool.isEmpty ? null : pool.first);
    setState(() {
      final vm = _LineVm(method: method, accountId: def?.id, accountName: def?.name);
      if (method == TrsMethod.cheque) {
        vm.issueDate = _date;
        vm.dueDate = _date;
      }
      _lines.add(vm);
      _allocations[vm] = const [];
    });
  }

  void _removeLine(_LineVm l) {
    setState(() {
      _lines.remove(l);
      _allocations.remove(l);
      l.dispose();
    });
  }

  /// همان `AdjustSingleInvoiceAllocationToTotal` وب
  void _syncSingleAllocation(_LineVm line) {
    final list = _allocations[line];
    if (list == null || list.length != 1) return;
    final a = list.first;
    final max = a.remainingBeforeSettlement;
    a.amount = line.amount < max ? line.amount : max;
    a.effectiveAmount = a.amount;
  }

  Future<void> _pickAccount(_LineVm line) async {
    final pool = _accountsFor(line.method);
    final picked = await showModalBottomSheet<TreasuryAccount>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AccountPickSheet(items: pool, title: 'حساب سطر ${line.methodTitle}'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      line.accountId = picked.id;
      line.accountName = picked.displayName;
    });
  }

  Future<void> _quickBank() async {
    final acc = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => QuickBankSheet(repo: _repo),
    );
    if (acc == null || !mounted) return;
    try {
      final list = await _repo.treasuryAccounts(activeOnly: true);
      if (!mounted) return;
      setState(() => _accounts = list);
    } catch (_) {}
  }

  Future<void> _pickParty() async {
    final picked = await showModalBottomSheet<Party>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PartyPickSheet(items: _parties),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _partyId = picked.id;
      _partyName = picked.name;
    });
    _loadOpenInvoices();
  }

  Future<void> _addAllocation(_LineVm line) async {
    if (_openInvoices.isEmpty) {
      _toast('برای این طرف حساب فاکتور بازِ قابل تسویه‌ای وجود ندارد.');
      return;
    }
    final picked = await showModalBottomSheet<SettlementInvoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _InvoicePickSheet(items: _openInvoices),
    );
    if (picked == null || !mounted) return;
    final current = _allocations[line] ?? const <InvoiceAllocation>[];
    if (current.any((a) => a.invoiceId == picked.invoiceId)) {
      _toast('این فاکتور قبلاً به این سطر اضافه شده است.');
      return;
    }
    final remain = picked.remainingAmount;
    final amount = line.amount - current.fold<double>(0, (s, a) => s + a.amount);
    if (amount <= 0) {
      _toast('ابتدا مبلغ سطر را وارد کنید.');
      return;
    }
    if (amount > remain) {
      _toast('مبلغ تخصیص از ماندهٔ فاکتور بیشتر است (${Fa.number(remain)}).');
      return;
    }
    setState(() {
      _allocations[line] = [
        ...current,
        InvoiceAllocation(
          invoiceId: picked.invoiceId,
          invoiceNumber: picked.invoiceNumber,
          invoiceKind: picked.invoiceKind,
          invoiceDate: picked.invoiceDate,
          invoiceTotal: picked.invoiceTotal,
          remainingBeforeSettlement: remain,
          amount: amount,
          effectiveAmount: amount,
        ),
      ];
    });
  }

  // ------------------------------------------------------------
  //  ذخیره
  // ------------------------------------------------------------

  Future<void> _save({required bool confirm}) async {
    // اعتبارسنجی سمت کلاینت (سرور هم همان پیام‌ها را می‌دهد)
    if (_isTransfer) {
      if (_fromAccountId == null || _toAccountId == null) {
        _toast('حساب مبدأ و مقصد انتقال را انتخاب کنید.');
        return;
      }
      if (_fromAccountId == _toAccountId) {
        _toast('حساب مبدأ و مقصد نمی‌توانند یکی باشند.');
        return;
      }
      if (_total <= 0) {
        _toast('مبلغ انتقال باید بزرگ‌تر از صفر باشد.');
        return;
      }
    } else {
      if (_lines.isEmpty) {
        _toast('حداقل یک سطر با مبلغ ثبت کنید.');
        return;
      }
      for (final l in _lines) {
        if (l.needsAccount && (l.accountId ?? 0) <= 0) {
          _toast('برای سطر «${l.methodTitle}» صندوق/بانک را انتخاب کنید.');
          return;
        }
        if (l.method == TrsMethod.cheque &&
            l.chequeNumberCtrl.text.trim().isEmpty) {
          _toast('شماره چک الزامی است.');
          return;
        }
        if (l.method == TrsMethod.cheque && l.dueDate == null) {
          _toast('تاریخ سررسید چک الزامی است.');
          return;
        }
      }
      if (_total <= 0) {
        _toast('حداقل یک سطر با مبلغ ثبت کنید.');
        return;
      }
      final allocated = _allocations.values
          .expand((e) => e)
          .fold<double>(0, (s, a) => s + a.amount);
      if (allocated > _total) {
        _toast('جمع تخصیص‌ها از مبلغ سند بیشتر است.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final doc = _doc ?? TreasuryVoucher();
      doc
        ..kind = _kind
        ..date = _date
        ..partyId = _isTransfer ? null : _partyId
        ..description = _descCtrl.text.trim()
        ..refNumber = _refCtrl.text.trim()
        ..totalAmount = _total
        ..fromAccountId = _isTransfer ? _fromAccountId : null
        ..toAccountId = _isTransfer ? _toAccountId : null
        ..feeAmount = _isTransfer ? parseNum(_feeCtrl.text) : 0
        ..lines = [
          for (var i = 0; i < _lines.length; i++) _lines[i].toModel(i + 1),
        ];

      final allocs = <InvoiceAllocation>[];
      for (final l in _lines) {
        allocs.addAll(_allocations[l] ?? const []);
      }
      doc.invoiceAllocations = allocs;
      if (allocs.length == 1) {
        doc.invoiceId = allocs.first.invoiceId;
      }

      var saved = await _repo.saveVoucher(doc);
      _doc = saved;
      if (confirm) {
        saved = await _repo.confirmVoucher(saved.id);
        _doc = saved;
      }
      if (!mounted) return;
      _toast(confirm ? 'سند ثبت و قطعی شد.' : 'پیش‌نویس ذخیره شد.', ok: true);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _toast(_clean(e));
    } finally {
      if (mounted) setState(() => _saving = false);
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

  // ------------------------------------------------------------
  //  UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final title = (_doc?.id ?? 0) > 0
        ? '${TrsKind.longTitle(_kind)} شماره ${Fa.number(_doc!.number)}'
        : TrsKind.longTitle(_kind);
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: Text(
          title,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_doc != null)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Center(
                child: ShopTag(
                  text: _doc!.statusTitle,
                  color: _doc!.status == TrsState.confirmed
                      ? ShopColors.ok
                      : _doc!.status == TrsState.draft
                      ? ShopColors.warn
                      : ShopColors.inkFaint,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ShopEmpty(
              title: 'بارگذاری سند ناموفق بود',
              subtitle: _error,
              icon: Icons.error_outline_rounded,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 110),
              children: [
                if (_locked)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: ShopColors.warn.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ShopColors.warn.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 16,
                          color: ShopColors.warn,
                        ),
                        SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'سند قطعی یا ابطال‌شده قابل ویرایش نیست؛ ابتدا آن را به پیش‌نویس برگردانید.',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: ShopColors.warn,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                _headCard(),
                const SizedBox(height: 10),
                if (_isTransfer) _transferCard() else ...[
                  _linesCard(),
                  const SizedBox(height: 10),
                ],
                _totalsCard(),
              ],
            ),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 46),
                          side: const BorderSide(color: ShopColors.line),
                          foregroundColor: ShopColors.inkSoft,
                        ),
                        child: const Text(
                          'انصراف',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!_locked) ...[
                      Expanded(
                        flex: 2,
                        child: OutlinedButton(
                          onPressed: _saving ? null : () => _save(confirm: false),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            foregroundColor: ShopColors.seed,
                            side: BorderSide(
                              color: ShopColors.seed.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Text(
                            'ذخیره پیش‌نویس',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : () => _save(confirm: true),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            backgroundColor: ShopColors.ok,
                          ),
                          icon: _saving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                ),
                          label: const Text(
                            'ثبت و قطعی',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _headCard() => Container(
    padding: const EdgeInsets.all(13),
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
              child: ShopField(
                label: 'تاریخ سند',
                required: true,
                child: InkWell(
                  onTap: _locked
                      ? null
                      : () async {
                          final d = await showJalaliDatePicker(
                            context,
                            initial: _date,
                            title: 'تاریخ سند',
                          );
                          if (d != null && mounted) setState(() => _date = d);
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: ShopColors.line),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          size: 14,
                          color: ShopColors.inkFaint,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          jalaliShort(_date),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ShopField(
                label: 'شماره سند',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: ShopColors.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    (_doc?.number ?? 0) == 0
                        ? 'خودکار'
                        : Fa.number(_doc!.number),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: ShopColors.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (!_isTransfer) ...[
          ShopField(
            label: 'طرف حساب',
            hint: 'دریافت از مشتری / پرداخت به تأمین‌کننده',
            child: InkWell(
              onTap: _locked ? null : _pickParty,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: ShopColors.line),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _partyName ?? 'انتخاب طرف حساب…',
                        style: TextStyle(
                          fontSize: 12,
                          color: _partyName == null
                              ? ShopColors.inkFaint
                              : ShopColors.ink,
                        ),
                      ),
                    ),
                    if (_partyName != null && !_locked)
                      InkWell(
                        onTap: () => setState(() {
                          _partyId = null;
                          _partyName = null;
                          _openInvoices = const [];
                        }),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 15,
                          color: ShopColors.inkFaint,
                        ),
                      )
                    else
                      const Icon(
                        Icons.search_rounded,
                        size: 16,
                        color: ShopColors.inkFaint,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
        ShopField(
          label: 'بابت / شرح سند',
          child: TextField(
            controller: _descCtrl,
            enabled: !_locked,
            style: const TextStyle(fontSize: 12.5),
            decoration: const InputDecoration(isDense: true),
          ),
        ),
        ShopField(
          label: 'شماره عطف / ارجاع خارجی',
          child: TextField(
            controller: _refCtrl,
            enabled: !_locked,
            style: const TextStyle(fontSize: 12.5),
            decoration: const InputDecoration(isDense: true),
          ),
        ),
      ],
    ),
  );

  Widget _transferCard() => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'مسیر انتقال',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        ShopField(
          label: 'از حساب (مبدأ)',
          required: true,
          child: _accDropdown(
            value: _fromAccountId,
            onChanged: (v) => setState(() => _fromAccountId = v),
          ),
        ),
        ShopField(
          label: 'به حساب (مقصد)',
          required: true,
          child: _accDropdown(
            value: _toAccountId,
            onChanged: (v) => setState(() => _toAccountId = v),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: ShopField(
                label: 'مبلغ انتقال (ریال)',
                required: true,
                child: TextField(
                  controller: _transferAmount,
                  enabled: !_locked,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 12.5),
                  decoration: const InputDecoration(isDense: true),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ShopField(
                label: 'کارمزد (ریال)',
                child: TextField(
                  controller: _feeCtrl,
                  enabled: !_locked,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: const InputDecoration(isDense: true),
                ),
              ),
            ),
          ],
        ),
        Text(
          'انتقال بین حساب‌ها به فاکتور تخصیص داده نمی‌شود.',
          style: TextStyle(
            fontSize: 9.5,
            color: ShopColors.inkFaint.withValues(alpha: 0.9),
          ),
        ),
      ],
    ),
  );

  Widget _accDropdown({
    required int? value,
    required ValueChanged<int?> onChanged,
  }) => DropdownButtonFormField<int?>(
    initialValue: value,
    isExpanded: true,
    decoration: const InputDecoration(isDense: true),
    style: const TextStyle(fontSize: 12, color: ShopColors.ink),
    items: [
      const DropdownMenuItem<int?>(value: null, child: Text('انتخاب حساب…')),
      for (final a in _accounts)
        DropdownMenuItem<int?>(value: a.id, child: Text(a.displayName)),
    ],
    onChanged: _locked ? null : onChanged,
  );

  Widget _linesCard() {
    return Container(
      padding: const EdgeInsets.all(13),
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
                  'سطرهای ابزار پرداخت',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ),
              if (!_locked)
                TextButton.icon(
                  onPressed: _quickBank,
                  icon: const Icon(Icons.add_business_rounded, size: 14),
                  label: const Text(
                    'تعریف بانک',
                    style: TextStyle(fontSize: 10.5),
                  ),
                ),
            ],
          ),
          if (_lines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'هنوز سطری اضافه نشده است. یکی از ابزارهای زیر را انتخاب کنید.',
                style: TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
              ),
            ),
          for (var i = 0; i < _lines.length; i++) _lineCard(i, _lines[i]),
          if (!_locked) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _addBtn('نقد', TrsMethod.cash, Icons.payments_rounded),
                _addBtn('کارتخوان', TrsMethod.card, Icons.credit_card_rounded),
                _addBtn('حواله', TrsMethod.transfer, Icons.swap_horiz_rounded),
                _addBtn('چک', TrsMethod.cheque, Icons.receipt_rounded),
                _addBtn('تخفیف', TrsMethod.discount, Icons.percent_rounded),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _addBtn(String label, int method, IconData icon) => OutlinedButton.icon(
    onPressed: () => _addLine(method),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 9),
      side: const BorderSide(color: ShopColors.line),
      foregroundColor: ShopColors.seed,
    ),
    icon: Icon(icon, size: 14),
    label: Text(
      label,
      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
    ),
  );

  Widget _lineCard(int index, _LineVm line) {
    final allocs = _allocations[line] ?? const <InvoiceAllocation>[];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ShopColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: ShopColors.seed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'سطر ${Fa.number(index + 1)} · ${line.methodTitle}',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: ShopColors.seed,
                  ),
                ),
              ),
              const Spacer(),
              if (!_locked)
                InkWell(
                  onTap: () => _removeLine(line),
                  child: const Icon(
                    Icons.delete_outline_rounded,
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
                flex: 3,
                child: line.needsAccount
                    ? InkWell(
                        onTap: _locked ? null : () => _pickAccount(line),
                        borderRadius: BorderRadius.circular(9),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: ShopColors.line),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  line.accountName ?? 'انتخاب حساب…',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: line.accountName == null
                                        ? ShopColors.inkFaint
                                        : ShopColors.ink,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.expand_more_rounded,
                                size: 15,
                                color: ShopColors.inkFaint,
                              ),
                            ],
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: ShopColors.line),
                        ),
                        child: Text(
                          line.method == TrsMethod.discount
                              ? 'تخفیف — بدون حساب'
                              : 'چک — حساب در برگ چک',
                          style: const TextStyle(
                            fontSize: 11,
                            color: ShopColors.inkFaint,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: line.amountCtrl,
                  enabled: !_locked,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() => _syncSingleAllocation(line)),
                  style: const TextStyle(fontSize: 11.5),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'مبلغ',
                    hintStyle: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: line.refCtrl,
                  enabled: !_locked,
                  style: const TextStyle(fontSize: 11),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'شماره پیگیری / حواله',
                    hintStyle: TextStyle(fontSize: 10.5),
                  ),
                ),
              ),
            ],
          ),
          if (line.method == TrsMethod.cheque) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: line.chequeNumberCtrl,
                    enabled: !_locked,
                    style: const TextStyle(fontSize: 11),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'شماره چک *',
                      hintStyle: TextStyle(fontSize: 10.5),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: line.sayadCtrl,
                    enabled: !_locked,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontSize: 11),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'شناسه صیاد',
                      hintStyle: TextStyle(fontSize: 10.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: line.bankCtrl,
                    enabled: !_locked,
                    style: const TextStyle(fontSize: 11),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'بانک صادرکننده',
                      hintStyle: TextStyle(fontSize: 10.5),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: _locked
                        ? null
                        : () async {
                            final d = await showJalaliDatePicker(
                              context,
                              initial: line.dueDate ?? _date,
                              title: 'سررسید چک',
                            );
                            if (d != null && mounted) {
                              setState(() => line.dueDate = d);
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: ShopColors.line),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.event_rounded,
                            size: 13,
                            color: ShopColors.inkFaint,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              line.dueDate == null
                                  ? 'سررسید *'
                                  : jalaliShort(line.dueDate!),
                              style: TextStyle(
                                fontSize: 10.5,
                                color: line.dueDate == null
                                    ? ShopColors.inkFaint
                                    : ShopColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (!_locked && !_isTransfer) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _addAllocation(line),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      side: const BorderSide(color: ShopColors.line),
                      foregroundColor: ShopColors.indigo,
                    ),
                    icon: const Icon(Icons.link_rounded, size: 13),
                    label: const Text(
                      'تخصیص به فاکتور',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (allocs.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final a in allocs)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      size: 12,
                      color: ShopColors.indigo,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '#${Fa.number(a.invoiceNumber)} — ${Fa.number(a.amount)} ریال'
                        ' (مانده ${Fa.number(a.remainingBeforeSettlement)})',
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: ShopColors.inkSoft,
                        ),
                      ),
                    ),
                    if (!_locked)
                      InkWell(
                        onTap: () => setState(() {
                          _allocations[line] = allocs
                              .where((x) => x != a)
                              .toList();
                        }),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 13,
                          color: ShopColors.danger,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _totalsCard() {
    final cash = _isTransfer
        ? 0.0
        : _lines
              .where((l) => l.method != TrsMethod.cheque)
              .fold<double>(0, (s, l) => s + l.amount);
    final cheque = _isTransfer
        ? 0.0
        : _lines
              .where((l) => l.method == TrsMethod.cheque)
              .fold<double>(0, (s, l) => s + l.amount);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: ShopColors.seed,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'جمع سند',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                '${Fa.number(_total)} ریال',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (!_isTransfer) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'نقد/کارت/حواله: ${Fa.number(cash)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                Text(
                  'چک: ${Fa.number(cheque)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// یک سطر ابزار پرداخت در فرم
class _LineVm {
  _LineVm({required this.method, this.accountId, this.accountName});

  final int method;
  int? accountId;
  String? accountName;

  final amountCtrl = TextEditingController();
  final refCtrl = TextEditingController();
  final chequeNumberCtrl = TextEditingController();
  final sayadCtrl = TextEditingController();
  final bankCtrl = TextEditingController();
  DateTime? issueDate;
  DateTime? dueDate;

  double get amount => parseNum(amountCtrl.text);

  bool get needsAccount => TrsMethod.needsAccount(method);

  String get methodTitle => TrsMethod.title(method);

  static _LineVm fromModel(VoucherLine l) {
    final vm = _LineVm(
      method: l.method,
      accountId: l.trsAccountId,
      accountName: l.trsAccountName,
    );
    vm.amountCtrl.text = l.amount == 0 ? '' : l.amount.toStringAsFixed(0);
    vm.refCtrl.text = l.refNumber ?? '';
    vm.chequeNumberCtrl.text = l.chequeNumber ?? '';
    vm.sayadCtrl.text = l.sayadId ?? '';
    vm.bankCtrl.text = l.chequeBankName ?? '';
    vm.issueDate = l.issueDate;
    vm.dueDate = l.dueDate;
    return vm;
  }

  VoucherLine toModel(int rowNo) => VoucherLine(
    id: 0,
    rowNo: rowNo,
    method: method,
    trsAccountId: accountId,
    amount: amount,
    refNumber: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
    chequeNumber: chequeNumberCtrl.text.trim().isEmpty
        ? null
        : chequeNumberCtrl.text.trim(),
    sayadId: sayadCtrl.text.trim().isEmpty ? null : sayadCtrl.text.trim(),
    chequeBankName: bankCtrl.text.trim().isEmpty ? null : bankCtrl.text.trim(),
    issueDate: method == TrsMethod.cheque ? issueDate : null,
    dueDate: method == TrsMethod.cheque ? dueDate : null,
  );

  void dispose() {
    amountCtrl.dispose();
    refCtrl.dispose();
    chequeNumberCtrl.dispose();
    sayadCtrl.dispose();
    bankCtrl.dispose();
  }
}

/// انتخاب حساب خزانه برای یک سطر
class _AccountPickSheet extends StatelessWidget {
  const _AccountPickSheet({required this.items, required this.title});

  final List<TreasuryAccount> items;
  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ShopColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'حسابی از این نوع تعریف نشده است. از «تعریف بانک» استفاده کنید.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: ShopColors.line),
                    itemBuilder: (_, i) => ListTile(
                      dense: true,
                      title: Text(
                        items[i].displayName,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      subtitle: Text(
                        '${items[i].kindTitle} · مانده ${Fa.number(items[i].balance)}',
                        style: const TextStyle(fontSize: 10),
                      ),
                      onTap: () => Navigator.pop(context, items[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// انتخاب طرف حساب (جستجوپذیر)
class _PartyPickSheet extends StatefulWidget {
  const _PartyPickSheet({required this.items});

  final List<Party> items;

  @override
  State<_PartyPickSheet> createState() => _PartyPickSheetState();
}

class _PartyPickSheetState extends State<_PartyPickSheet> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = toEnDigits(_q.text).trim().toLowerCase();
    final list = q.isEmpty
        ? widget.items
        : widget.items
              .where(
                (e) =>
                    e.name.toLowerCase().contains(q) ||
                    (e.mobile ?? '').contains(q),
              )
              .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ShopColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'انتخاب طرف حساب',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 12.5),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'جستجوی نام یا موبایل…',
                hintStyle: TextStyle(fontSize: 12),
                prefixIcon: Icon(Icons.search_rounded, size: 18),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text(
                      'طرف حسابی یافت نشد',
                      style: TextStyle(
                        fontSize: 12,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: ShopColors.line),
                    itemBuilder: (_, i) => ListTile(
                      dense: true,
                      title: Text(
                        list[i].name,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      subtitle: list[i].mobile == null
                          ? null
                          : Text(
                              list[i].mobile!,
                              style: const TextStyle(fontSize: 10),
                            ),
                      trailing: Text(
                        list[i].type == 1 ? 'تأمین‌کننده' : 'مشتری',
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                      onTap: () => Navigator.pop(context, list[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// انتخاب فاکتور باز برای تخصیص
class _InvoicePickSheet extends StatelessWidget {
  const _InvoicePickSheet({required this.items});

  final List<SettlementInvoice> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.65,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ShopColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'فاکتورهای باز قابل تسویه',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: ShopColors.line),
              itemBuilder: (_, i) {
                final inv = items[i];
                return ListTile(
                  dense: true,
                  title: Text(
                    '#${Fa.number(inv.invoiceNumber)} · ${inv.kindTitle}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    '${inv.invoiceDate == null ? '' : jalaliShort(inv.invoiceDate!)}'
                    ' · مانده ${Fa.number(inv.remainingAmount)} ریال',
                    style: const TextStyle(fontSize: 10),
                  ),
                  onTap: () => Navigator.pop(context, inv),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
