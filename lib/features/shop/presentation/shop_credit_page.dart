// ============================================================
//  مدیریت جامع چک‌ها و دفترچه اقساط (نسخهٔ فاز ۳ — هم‌تراز کامل وب)
//  آینهٔ صفحهٔ وب: /shop/credit-management
//                 → Pages/Shop/ShopCreditManagement.razor
//
//  • چهار کارت شاخص تعاملی با فیلتر سریع:
//      چک‌های در جریان · چک‌های برگشتی · اقساط باز/معوق · وصولی‌های قطعی
//  • تب «مدیریت چک‌ها»:
//      جستجوی هوشمند (شماره، مشتری، فاکتور، بانک، موبایل و تلفن ثابت)
//      عملیات کامل وب:
//        ۱) وصول چک فروش / پرداخت چک خرید (با انتخاب حساب بانکی و تاریخ)
//        ۲) لغو وصول / لغو پرداخت چک (سند معکوس خزانه با تاریخ)
//        ۳) تغییر سررسید چک + پیش‌نمایش و ثبت تعدیل سود تاخیر تادیه
//        ۴) تعویض چک وصول‌نشده و حفظ چک قبلی در تاریخچه
//        ۵) مشاهده تاریخچه وضعیت چک
//        ۶) ثبت برگشت چک و بازگردانی به جریان (پشتیبانی از چک‌های سوددار)
//  • تب «مدیریت دفترچه اقساط»:
//      دریافت قسط فروش / پرداخت قسط خرید با انتخاب حساب صندوق/بانک
//      و لغو دریافت/پرداخت قسط ردگیری‌شده با تاریخ سند معکوس
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../../../core/utils/uuid_v4.dart';
import '../data/fa_num.dart';
import '../data/shop_perms.dart';
import '../data/shop_repository.dart';
import '../models/order_models.dart';
import '../models/treasury_models.dart';
import 'shop_style.dart';

class ShopCreditPage extends StatefulWidget {
  const ShopCreditPage({
    super.key,
    this.initialTab = 0,
    this.initialQuickFilter,
  });

  final int initialTab;
  final String? initialQuickFilter;

  @override
  State<ShopCreditPage> createState() => _ShopCreditPageState();
}

class _ShopCreditPageState extends State<ShopCreditPage> {
  late final ShopRepository _repo;
  late final ShopPerms _perms;

  ShopCreditSummary? _summary;
  List<ShopCheque> _cheques = const [];
  List<ShopInstallment> _installments = const [];
  bool _loading = true;
  String? _error;
  late int _tab;
  String? _quickKey;

  // فیلتر چک
  final _chequeSearch = TextEditingController();
  int? _chequeStatus;
  int? _chequeTxnType;

  // فیلتر قسط
  final _instSearch = TextEditingController();
  bool? _instPaid;

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _perms = ShopPerms(context.read<AuthController>().session);
    _tab = widget.initialTab.clamp(0, 1);
    if (widget.initialQuickFilter != null) {
      _applyQuickFilterState(widget.initialQuickFilter!);
    }
    _load();
  }

  @override
  void dispose() {
    _chequeSearch.dispose();
    _instSearch.dispose();
    super.dispose();
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');

  void _toast(String msg, {Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Future.wait([
        _repo.shopCreditSummary(),
        _repo.shopCheques(),
        _repo.shopInstallments(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = res[0] as ShopCreditSummary;
        _cheques = res[1] as List<ShopCheque>;
        _installments = res[2] as List<ShopInstallment>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'خطا در بارگذاری داده‌ها: ${_clean(e)}';
        _loading = false;
      });
    }
  }

  static String _digitsOnly(String? s) =>
      toEnDigits(s ?? '').replaceAll(RegExp(r'[^0-9]'), '');

  static bool _matchesPhone(String query, String? mobile, String? phone) {
    final q = _digitsOnly(query);
    if (q.length < 3) return false;
    final m = _digitsOnly(mobile);
    final p = _digitsOnly(phone);
    return (m.isNotEmpty && m.contains(q)) || (p.isNotEmpty && p.contains(q));
  }

  void _applyQuickFilterState(String key) {
    _quickKey = key;
    _chequeSearch.clear();
    _instSearch.clear();
    _chequeTxnType = null;
    _chequeStatus = null;
    _instPaid = null;
    switch (key) {
      case 'inhand':
        _tab = 0;
        _chequeStatus = TrsChequeState.inHand;
        break;
      case 'bounced':
        _tab = 0;
        _chequeStatus = TrsChequeState.bounced;
        break;
      case 'pending':
        _tab = 1;
        _instPaid = false;
        break;
      case 'collected':
        _tab = 0;
        _chequeStatus = TrsChequeState.cleared;
        _instPaid = true;
        break;
    }
  }

  void _toggleQuickFilter(String key) {
    setState(() {
      if (_quickKey == key) {
        _quickKey = null;
        _chequeStatus = null;
        _chequeTxnType = null;
        _instPaid = null;
      } else {
        _applyQuickFilterState(key);
      }
    });
  }

  List<ShopCheque> get _filteredCheques {
    Iterable<ShopCheque> q = _cheques;
    if (_chequeStatus != null) {
      final st = _chequeStatus!;
      if (st == TrsChequeState.cleared) {
        q = q.where((c) => c.isCleared || c.status == TrsChequeState.cleared);
      } else if (st == TrsChequeState.bounced) {
        q = q.where((c) => c.status == TrsChequeState.bounced);
      } else if (st == TrsChequeState.cancelled) {
        q = q.where((c) => c.status == TrsChequeState.cancelled);
      } else {
        q = q.where(
          (c) =>
              !c.isCleared &&
              c.status != TrsChequeState.cleared &&
              c.status != TrsChequeState.bounced &&
              c.status != TrsChequeState.cancelled &&
              c.status != TrsChequeState.endorsed,
        );
      }
    }
    if (_chequeTxnType != null) {
      q = q.where((c) => c.transactionType == _chequeTxnType);
    }
    final raw = _chequeSearch.text.trim();
    final s = toEnDigits(raw).toLowerCase();
    if (s.isNotEmpty) {
      q = q.where(
        (c) =>
            toEnDigits(c.number).toLowerCase().contains(s) ||
            c.partyName.toLowerCase().contains(s) ||
            toEnDigits(c.orderNumber).toLowerCase().contains(s) ||
            (c.bankName ?? '').toLowerCase().contains(s) ||
            _matchesPhone(raw, c.partyMobile, c.partyPhone),
      );
    }
    final list = q.toList()
      ..sort(
        (a, b) =>
            (a.dueDate ?? DateTime(1970)).compareTo(b.dueDate ?? DateTime(1970)),
      );
    return list;
  }

  List<ShopInstallment> get _filteredInstallments {
    Iterable<ShopInstallment> q = _installments;
    if (_instPaid != null) {
      q = q.where((i) => i.isPaid == _instPaid);
    }
    final raw = _instSearch.text.trim();
    final s = toEnDigits(raw).toLowerCase();
    if (s.isNotEmpty) {
      q = q.where(
        (i) =>
            i.partyName.toLowerCase().contains(s) ||
            toEnDigits(i.orderNumber).toLowerCase().contains(s) ||
            _matchesPhone(raw, i.partyMobile, i.partyPhone),
      );
    }
    final list = q.toList()
      ..sort(
        (a, b) =>
            (a.dueDate ?? DateTime(1970)).compareTo(b.dueDate ?? DateTime(1970)),
      );
    return list;
  }

  // -------------------- ۱) وصول / پرداخت چک با انتخاب بانک --------------------

  Future<void> _openChequeReceiptSheet(ShopCheque c) async {
    List<TrsAccount> banks = const [];
    try {
      banks = await _repo.trsAccounts(activeOnly: true, kind: AccountKind.bank);
      if (banks.isEmpty) {
        banks = await _repo.trsAccounts(activeOnly: true);
      }
    } catch (e) {
      _toast(_clean(e), bg: ShopColors.danger);
      return;
    }
    if (!mounted) return;
    if (banks.isEmpty) {
      _toast(
        'هیچ حساب بانکی/خزانه فعالی تعریف نشده است. ابتدا در بخش «بانک، صندوق و کارتخوان» یک حساب ثبت کنید.',
        bg: ShopColors.warn,
      );
      return;
    }

    int selectedBankId =
        c.isPurchase &&
            (c.trsAccountId ?? 0) > 0 &&
            banks.any((b) => b.id == c.trsAccountId)
        ? c.trsAccountId!
        : banks.first.id;
    DateTime opDate = DateTime.now();
    final opId = generateUuidV4();
    bool busy = false;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ShopColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                c.isPurchase ? 'پرداخت چک خرید' : 'وصول چک فروش',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'چک ${Fa.digits(c.number)} · ${c.partyName} · ${money(c.amount)} ریال',
                style: const TextStyle(fontSize: 11.5, color: ShopColors.inkSoft),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: selectedBankId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: c.isPurchase
                      ? 'حساب بانکی پرداخت‌کننده *'
                      : 'حساب بانکی مقصد وصول *',
                ),
                items: [
                  for (final b in banks)
                    DropdownMenuItem(
                      value: b.id,
                      child: Text(
                        b.bankName != null && b.bankName!.trim().isNotEmpty
                            ? '${b.name} — ${b.bankName}'
                            : b.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (v) {
                        if (v != null) setM(() => selectedBankId = v);
                      },
              ),
              const SizedBox(height: 12),
              _DateFieldTile(
                label: c.isPurchase ? 'تاریخ پرداخت چک' : 'تاریخ وصول چک',
                date: opDate,
                onTap: busy
                    ? null
                    : () async {
                        final p = await showJalaliDatePicker(
                          ctx,
                          initial: opDate,
                          title: 'انتخاب تاریخ عملیات',
                        );
                        if (p != null) setM(() => opDate = p);
                      },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : () => Navigator.pop(ctx, false),
                      child: const Text('انصراف'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: ShopColors.ok,
                      ),
                      onPressed: busy || selectedBankId <= 0
                          ? null
                          : () async {
                              setM(() => busy = true);
                              try {
                                await _repo.receiveShopCheque(
                                  c.id,
                                  operationId: opId,
                                  trsAccountId: selectedBankId,
                                  date: opDate,
                                );
                                if (ctx.mounted) Navigator.pop(ctx, true);
                              } catch (e) {
                                setM(() => busy = false);
                                _toast(_clean(e), bg: ShopColors.danger);
                              }
                            },
                      icon: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(
                        c.isPurchase ? 'ثبت پرداخت چک' : 'ثبت وصول چک',
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

    if (ok == true) {
      _toast(
        c.isPurchase ? 'پرداخت چک ثبت شد.' : 'وصول چک ثبت شد.',
        bg: ShopColors.ok,
      );
      await _load();
    }
  }

  // -------------------- ۲) لغو وصول / لغو پرداخت چک --------------------

  Future<void> _openChequeReversalSheet(ShopCheque c) async {
    DateTime opDate = DateTime.now();
    final opId = generateUuidV4();
    bool busy = false;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ShopColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                c.isPurchase ? 'لغو پرداخت چک' : 'لغو وصول چک',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'سند معکوس خزانه برای چک ${Fa.digits(c.number)} (${money(c.amount)} ریال) صادر و وضعیت چک به «در جریان» برمی‌گردد.',
                style: const TextStyle(fontSize: 11.5, color: ShopColors.inkSoft),
              ),
              const SizedBox(height: 14),
              _DateFieldTile(
                label: 'تاریخ سند معکوس',
                date: opDate,
                onTap: busy
                    ? null
                    : () async {
                        final p = await showJalaliDatePicker(
                          ctx,
                          initial: opDate,
                          title: 'تاریخ لغو وصول',
                        );
                        if (p != null) setM(() => opDate = p);
                      },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : () => Navigator.pop(ctx, false),
                      child: const Text('انصراف'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: ShopColors.warn,
                      ),
                      onPressed: busy
                          ? null
                          : () async {
                              setM(() => busy = true);
                              try {
                                await _repo.reverseShopChequeReceipt(
                                  c.id,
                                  operationId: opId,
                                  date: opDate,
                                );
                                if (ctx.mounted) Navigator.pop(ctx, true);
                              } catch (_) {
                                try {
                                  await _repo.resetShopCheque(c.id);
                                  if (ctx.mounted) Navigator.pop(ctx, true);
                                } catch (e2) {
                                  setM(() => busy = false);
                                  _toast(_clean(e2), bg: ShopColors.danger);
                                }
                              }
                            },
                      icon: const Icon(Icons.undo_rounded, size: 18),
                      label: Text(
                        c.isPurchase ? 'تأیید لغو پرداخت' : 'تأیید لغو وصول',
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

    if (ok == true) {
      _toast(
        c.isPurchase ? 'پرداخت چک لغو شد.' : 'وصول چک لغو شد.',
        bg: ShopColors.warn,
      );
      await _load();
    }
  }

  // -------------------- ۳) تغییر سررسید چک + پیش‌نمایش تعدیل سود --------------------

  Future<void> _openRescheduleSheet(ShopCheque c) async {
    final origDue = c.dueDate ?? DateTime.now();
    DateTime newDue = origDue;
    DateTime opDate = DateTime.now();
    String opId = generateUuidV4();
    SaleChequeReschedulePreview? preview;
    bool busy = false;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ShopColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'تغییر سررسید چک و محاسبه تعدیل',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'چک ${Fa.digits(c.number)} · سررسید فعلی: ${jalaliShort(origDue)} · مبلغ: ${money(c.amount)} ریال',
                style: const TextStyle(fontSize: 11.5, color: ShopColors.inkSoft),
              ),
              const SizedBox(height: 14),
              _DateFieldTile(
                label: 'سررسید جدید چک',
                date: newDue,
                onTap: busy
                    ? null
                    : () async {
                        final p = await showJalaliDatePicker(
                          ctx,
                          initial: newDue,
                          title: 'سررسید جدید چک',
                        );
                        if (p != null) {
                          setM(() {
                            newDue = p;
                            preview = null;
                            opId = generateUuidV4();
                          });
                        }
                      },
              ),
              const SizedBox(height: 10),
              _DateFieldTile(
                label: 'تاریخ ثبت عملیات',
                date: opDate,
                onTap: busy
                    ? null
                    : () async {
                        final p = await showJalaliDatePicker(
                          ctx,
                          initial: opDate,
                          title: 'تاریخ عملیات',
                        );
                        if (p != null) setM(() => opDate = p);
                      },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        setM(() => busy = true);
                        try {
                          final p = await _repo.previewChequeReschedule(
                            c.id,
                            expectedDueDate: origDue,
                            newDueDate: newDue,
                          );
                          setM(() {
                            preview = p;
                            busy = false;
                          });
                        } catch (e) {
                          setM(() => busy = false);
                          _toast(_clean(e), bg: ShopColors.danger);
                        }
                      },
                icon: const Icon(Icons.calculate_outlined, size: 18),
                label: const Text('محاسبه پیش‌نمایش تعدیل تاخیر تادیه'),
              ),
              if (preview != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ShopColors.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ShopColors.line),
                  ),
                  child: Column(
                    children: [
                      _kvRow('مبلغ پایه محاسبه', '${money(preview!.baseAmount)} ریال'),
                      _kvRow(
                        'نرخ و مدت جدید',
                        '${Fa.digits(preview!.ratePercent.toStringAsFixed(2))}٪ · ${Fa.digits(preview!.periodDays)} روز',
                      ),
                      const Divider(height: 14),
                      _kvRow(
                        'تعدیل درآمد تاخیر تادیه',
                        '${preview!.incomeDelta >= 0 ? '+' : ''}${money(preview!.incomeDelta)} ریال',
                        valueColor: preview!.incomeDelta < 0
                            ? ShopColors.danger
                            : ShopColors.ok,
                        bold: true,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : () => Navigator.pop(ctx, false),
                      child: const Text('انصراف'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: busy || preview == null
                          ? null
                          : () async {
                              setM(() => busy = true);
                              try {
                                await _repo.rescheduleShopCheque(
                                  c.id,
                                  operationId: opId,
                                  expectedDueDate: origDue,
                                  newDueDate: newDue,
                                  operationDate: opDate,
                                  confirmedIncomeDelta: preview!.incomeDelta,
                                );
                                if (ctx.mounted) Navigator.pop(ctx, true);
                              } catch (e) {
                                setM(() => busy = false);
                                _toast(_clean(e), bg: ShopColors.danger);
                              }
                            },
                      icon: const Icon(Icons.event_available_rounded, size: 18),
                      label: const Text('ثبت قطعی سررسید و تعدیل'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (ok == true) {
      _toast('سررسید و تعدیل ثبت شد.', bg: ShopColors.ok);
      await _load();
    }
  }

  // -------------------- ۴) تعویض چک وصول‌نشده --------------------

  Future<void> _openReplaceChequeSheet(ShopCheque c) async {
    final numCtrl = TextEditingController();
    final amtCtrl = TextEditingController(
      text: formatNumText(c.amount.round().toString()),
    );
    final bankCtrl = TextEditingController(text: c.bankName ?? '');
    final reasonCtrl = TextEditingController();
    DateTime opDate = DateTime.now();
    final opId = generateUuidV4();
    bool busy = false;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ShopColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'تعویض چک وصول‌نشده',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'چک فعلی (${Fa.digits(c.number)}) در تاریخچه ابطال/حفظ شده و چک جایگزین ثبت می‌شود.',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: ShopColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: numCtrl,
                  decoration: const InputDecoration(
                    labelText: 'شماره / سریال چک جایگزین *',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amtCtrl,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  inputFormatters: moneyInputFormatters,
                  decoration: const InputDecoration(
                    labelText: 'مبلغ چک جایگزین (ریال) *',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bankCtrl,
                  decoration: const InputDecoration(
                    labelText: 'نام بانک چک جایگزین',
                  ),
                ),
                const SizedBox(height: 10),
                _DateFieldTile(
                  label: 'تاریخ عملیات تعویض',
                  date: opDate,
                  onTap: busy
                      ? null
                      : () async {
                          final p = await showJalaliDatePicker(
                            ctx,
                            initial: opDate,
                            title: 'تاریخ تعویض چک',
                          );
                          if (p != null) setM(() => opDate = p);
                        },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'علت تعویض (اختیاری)',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy ? null : () => Navigator.pop(ctx, false),
                        child: const Text('انصراف'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                final numText = numCtrl.text.trim();
                                final amt = parseNum(amtCtrl.text);
                                if (numText.isEmpty) {
                                  _toast(
                                    'شماره چک جایگزین را وارد کنید.',
                                    bg: ShopColors.warn,
                                  );
                                  return;
                                }
                                if (amt <= 0) {
                                  _toast(
                                    'مبلغ چک جایگزین را وارد کنید.',
                                    bg: ShopColors.warn,
                                  );
                                  return;
                                }
                                setM(() => busy = true);
                                try {
                                  await _repo.replaceShopCheque(
                                    c.id,
                                    operationId: opId,
                                    operationDate: opDate,
                                    number: numText,
                                    amount: amt,
                                    dueDate: c.dueDate ?? DateTime.now(),
                                    bankName: bankCtrl.text,
                                    ownerName: c.ownerName,
                                    accountInfo: c.accountInfo,
                                    reason: reasonCtrl.text,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx, true);
                                } catch (e) {
                                  setM(() => busy = false);
                                  _toast(_clean(e), bg: ShopColors.danger);
                                }
                              },
                        icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                        label: const Text('ثبت تعویض چک'),
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

    numCtrl.dispose();
    amtCtrl.dispose();
    bankCtrl.dispose();
    reasonCtrl.dispose();

    if (ok == true) {
      _toast(
        'تعویض چک ثبت شد و چک قبلی در تاریخچه حفظ گردید.',
        bg: ShopColors.ok,
      );
      await _load();
    }
  }

  // -------------------- ۵) تاریخچه وضعیت چک --------------------

  Future<void> _openChequeHistorySheet(ShopCheque c) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ShopColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => FutureBuilder<List<SaleChequeStatusHistoryItem>>(
        future: _repo.chequeStatusHistory(c.id),
        builder: (ctx, snap) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تاریخچه وضعیت چک ${Fa.digits(c.number)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              if (snap.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snap.hasError)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _clean(snap.error!),
                    style: const TextStyle(color: ShopColors.danger),
                  ),
                )
              else if ((snap.data ?? const []).isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'تغییر وضعیتی برای این چک ثبت نشده است.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ShopColors.inkFaint),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.55,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: snap.data!.length,
                    separatorBuilder: (_, _) => const Divider(height: 14),
                    itemBuilder: (_, idx) {
                      final h = snap.data![idx];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.history_rounded,
                            size: 17,
                            color: ShopColors.seed,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_historyStatusLabel(h.previousStatus)} ← ${_historyStatusLabel(h.newStatus)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: ShopColors.ink,
                                  ),
                                ),
                                if ((h.reason ?? '').isNotEmpty)
                                  Text(
                                    'علت: ${h.reason}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: ShopColors.inkSoft,
                                    ),
                                  ),
                                Text(
                                  [
                                    if (h.createdAt != null)
                                      jalaliShort(h.createdAt!),
                                    if ((h.createdBy ?? '').isNotEmpty)
                                      h.createdBy!,
                                  ].join(' · '),
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: ShopColors.inkFaint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _historyStatusLabel(int status) => switch (status) {
    TrsChequeState.inHand => 'در جریان',
    TrsChequeState.bounced => 'برگشتی',
    TrsChequeState.cleared => 'وصول‌شده',
    TrsChequeState.cancelled => 'ابطال / تعویض شده',
    TrsChequeState.endorsed => 'خرج‌شده',
    _ => 'در جریان وصول',
  };

  // -------------------- ۶) برگشت چک و بازگردانی --------------------

  Future<void> _bounceCheque(ShopCheque c) async {
    final ctl = TextEditingController(text: 'کسر موجودی حساب');
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ثبت برگشت چک'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'چک ${Fa.digits(c.number)} · ${c.partyName} · ${money(c.amount)} ریال',
              style: const TextStyle(fontSize: 12, color: ShopColors.inkSoft),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              decoration: const InputDecoration(labelText: 'علت برگشت چک'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ShopColors.danger),
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: const Text('ثبت برگشت چک'),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (reason == null) return;
    try {
      if (c.hasChequeCharge) {
        await _repo.changeShopChequeStatus(
          c.id,
          operationId: generateUuidV4(),
          bounced: true,
          reason: reason,
        );
      } else {
        await _repo.bounceShopCheque(c.id, reason);
      }
      _toast(
        'چک ${Fa.digits(c.number)} برگشت خورد و در وضعیت بدهی ثبت شد.',
        bg: ShopColors.danger,
      );
      await _load();
    } catch (e) {
      _toast(_clean(e), bg: ShopColors.danger);
    }
  }

  Future<void> _resetCheque(ShopCheque c) async {
    try {
      if (c.hasChequeCharge) {
        await _repo.changeShopChequeStatus(
          c.id,
          operationId: generateUuidV4(),
          bounced: false,
        );
      } else {
        await _repo.resetShopCheque(c.id);
      }
      _toast('وضعیت چک ${Fa.digits(c.number)} به در جریان بازگردانده شد.');
      await _load();
    } catch (e) {
      _toast(_clean(e), bg: ShopColors.danger);
    }
  }

  // -------------------- ۷) دریافت / پرداخت قسط و لغو تسویه --------------------

  Future<void> _openInstallmentReceiptSheet(ShopInstallment i) async {
    List<TrsAccount> accounts = const [];
    try {
      accounts = await _repo.trsAccounts(activeOnly: true);
    } catch (e) {
      _toast(_clean(e), bg: ShopColors.danger);
      return;
    }
    if (!mounted) return;
    if (accounts.isEmpty) {
      _toast(
        'ابتدا یک صندوق یا بانک فعال در خزانه تعریف کنید.',
        bg: ShopColors.warn,
      );
      return;
    }

    int selectedAccId = accounts.first.id;
    DateTime opDate = DateTime.now();
    final opId = generateUuidV4();
    bool busy = false;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ShopColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                i.isPurchase ? 'پرداخت قسط خرید' : 'دریافت قسط فروش',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'قسط ${numFa(i.no)} · ${i.partyName} · ${money(i.amount)} ریال',
                style: const TextStyle(fontSize: 11.5, color: ShopColors.inkSoft),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: selectedAccId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: i.isPurchase
                      ? 'صندوق / بانک پرداخت‌کننده *'
                      : 'صندوق / بانک دریافت‌کننده *',
                ),
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(
                      value: a.id,
                      child: Text(
                        a.bankName != null && a.bankName!.trim().isNotEmpty
                            ? '${a.name} — ${a.bankName}'
                            : a.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (v) {
                        if (v != null) setM(() => selectedAccId = v);
                      },
              ),
              const SizedBox(height: 12),
              _DateFieldTile(
                label: i.isPurchase ? 'تاریخ پرداخت قسط' : 'تاریخ دریافت قسط',
                date: opDate,
                onTap: busy
                    ? null
                    : () async {
                        final p = await showJalaliDatePicker(
                          ctx,
                          initial: opDate,
                          title: 'تاریخ تسویه قسط',
                        );
                        if (p != null) setM(() => opDate = p);
                      },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : () => Navigator.pop(ctx, false),
                      child: const Text('انصراف'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: ShopColors.ok,
                      ),
                      onPressed: busy || selectedAccId <= 0
                          ? null
                          : () async {
                              setM(() => busy = true);
                              try {
                                await _repo.receiveShopInstallment(
                                  i.id,
                                  operationId: opId,
                                  trsAccountId: selectedAccId,
                                  date: opDate,
                                );
                                if (ctx.mounted) Navigator.pop(ctx, true);
                              } catch (e) {
                                setM(() => busy = false);
                                _toast(_clean(e), bg: ShopColors.danger);
                              }
                            },
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(
                        i.isPurchase ? 'ثبت پرداخت قسط' : 'ثبت دریافت قسط',
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

    if (ok == true) {
      _toast(
        i.isPurchase ? 'پرداخت قسط ثبت شد.' : 'دریافت قسط ثبت شد.',
        bg: ShopColors.ok,
      );
      await _load();
    }
  }

  Future<void> _unpayInstallment(ShopInstallment i) async {
    if (i.hasChequeCharge || i.hasTrackedReceipt) {
      DateTime opDate = DateTime.now();
      final opId = generateUuidV4();
      bool busy = false;
      final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: ShopColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setM) => Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  i.isPurchase ? 'لغو پرداخت قسط' : 'لغو دریافت قسط',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'سند معکوس قسط شماره ${numFa(i.no)} (${money(i.amount)} ریال) در خزانه ثبت می‌شود.',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: ShopColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 14),
                _DateFieldTile(
                  label: 'تاریخ سند معکوس',
                  date: opDate,
                  onTap: busy
                      ? null
                      : () async {
                          final p = await showJalaliDatePicker(
                            ctx,
                            initial: opDate,
                            title: 'تاریخ لغو قسط',
                          );
                          if (p != null) setM(() => opDate = p);
                        },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy ? null : () => Navigator.pop(ctx, false),
                        child: const Text('انصراف'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: ShopColors.warn,
                        ),
                        onPressed: busy
                            ? null
                            : () async {
                                setM(() => busy = true);
                                try {
                                  await _repo.reverseShopInstallmentReceipt(
                                    i.id,
                                    operationId: opId,
                                    date: opDate,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx, true);
                                } catch (e) {
                                  setM(() => busy = false);
                                  _toast(_clean(e), bg: ShopColors.danger);
                                }
                              },
                        icon: const Icon(Icons.undo_rounded, size: 18),
                        label: Text(
                          i.isPurchase ? 'تأیید لغو پرداخت' : 'تأیید لغو دریافت',
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
      if (ok == true) {
        _toast(
          i.isPurchase ? 'پرداخت قسط لغو شد.' : 'دریافت قسط لغو شد.',
          bg: ShopColors.warn,
        );
        await _load();
      }
      return;
    }

    try {
      await _repo.unpayInstallment(i.id);
      _toast(
        'تسویه قسط شماره ${numFa(i.no)} لغو شد و به عنوان بدهی معوق منظور گردید.',
        bg: ShopColors.warn,
      );
      await _load();
    } catch (e) {
      _toast(_clean(e), bg: ShopColors.danger);
    }
  }

  static Widget _kvRow(
    String label,
    String val, {
    Color? valueColor,
    bool bold = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: ShopColors.inkSoft),
          ),
        ),
        Text(
          val,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: valueColor ?? ShopColors.ink,
          ),
        ),
      ],
    ),
  );

  // -------------------- رابط کاربری --------------------

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    final cheques = _filteredCheques;
    final insts = _filteredInstallments;
    final canManage =
        _perms.canManageInstallments ||
        _perms.canManageSale ||
        _perms.canManagePurchase;

    return Scaffold(
      backgroundColor: ShopColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ShopHeader(
                title: 'مدیریت جامع چک‌ها و دفترچه اقساط',
                subtitle:
                    'وصول به بانک، تغییر سررسید و تعدیل سود، تعویض چک، برگشت و تسویه اقساط',
                icon: Icons.event_note_rounded,
                actions: [
                  ShopHeaderButton(
                    label: 'بروزرسانی اطلاعات',
                    icon: Icons.refresh_rounded,
                    onTap: _load,
                  ),
                ],
              ),
            ),
            if (s != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _QuickKpiCard(
                              active: _quickKey == 'inhand',
                              title: 'چک‌های در جریان',
                              value: money(s.inHandChequesTotal),
                              footer: '${numFa(s.inHandChequesCount)} فقره باز',
                              icon: Icons.hourglass_top_rounded,
                              color: ShopColors.seed,
                              onTap: () => _toggleQuickFilter('inhand'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _QuickKpiCard(
                              active: _quickKey == 'bounced',
                              title: 'چک‌های برگشتی',
                              value: money(s.bouncedChequesTotal),
                              footer: s.bouncedChequesCount > 0
                                  ? 'نیازمند پیگیری (${numFa(s.bouncedChequesCount)} فقره)'
                                  : 'بدون چک برگشتی',
                              icon: Icons.report_gmailerrorred_rounded,
                              color: ShopColors.danger,
                              onTap: () => _toggleQuickFilter('bounced'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickKpiCard(
                              active: _quickKey == 'pending',
                              title: 'اقساط باز و معوق',
                              value: money(s.pendingInstallmentsTotal),
                              footer: s.overdueInstallmentsCount > 0
                                  ? '${numFa(s.overdueInstallmentsCount)} قسط معوق (${money(s.overdueInstallmentsTotal)})'
                                  : '${numFa(s.pendingInstallmentsCount)} قسط در سررسید',
                              icon: Icons.calendar_month_rounded,
                              color: ShopColors.warn,
                              onTap: () => _toggleQuickFilter('pending'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _QuickKpiCard(
                              active: _quickKey == 'collected',
                              title: 'وصولی‌های قطعی',
                              value: money(s.collectedTotal),
                              footer:
                                  '${numFa(s.collectedCount)} تراکنش موفق مالی',
                              icon: Icons.verified_rounded,
                              color: ShopColors.ok,
                              onTap: () => _toggleQuickFilter('collected'),
                            ),
                          ),
                        ],
                      ),
                      if (_quickKey != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ActionChip(
                            avatar: const Icon(Icons.close_rounded, size: 15),
                            label: const Text(
                              'حذف فیلتر سریع شاخص',
                              style: TextStyle(fontSize: 11),
                            ),
                            onPressed: () => _toggleQuickFilter(_quickKey!),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    _tabBtn(0, 'مدیریت چک‌ها', _cheques.length),
                    const SizedBox(width: 8),
                    _tabBtn(1, 'مدیریت دفترچه اقساط', _installments.length),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              sliver: SliverToBoxAdapter(
                child: _tab == 0 ? _chequeFilters() : _instFilters(),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ShopEmpty(
                      icon: Icons.error_outline_rounded,
                      title: _error!,
                      actionLabel: 'تلاش دوباره',
                      onAction: _load,
                    ),
                  ),
                ),
              )
            else if (_tab == 0 && cheques.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: ShopEmpty(
                    icon: Icons.credit_card_off_rounded,
                    title: 'هیچ چکی با فیلترهای انتخابی یافت نشد.',
                  ),
                ),
              )
            else if (_tab == 1 && insts.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: ShopEmpty(
                    icon: Icons.event_busy_rounded,
                    title: 'هیچ قسطی در این بخش ثبت نشده است.',
                  ),
                ),
              )
            else if (_tab == 0)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                sliver: SliverList.separated(
                  itemCount: cheques.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _chequeCard(cheques[i], canManage: canManage),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                sliver: SliverList.separated(
                  itemCount: insts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _instCard(insts[i], canManage: canManage),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tabBtn(int i, String label, int count) {
    final sel = _tab == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
          decoration: BoxDecoration(
            color: sel ? ShopColors.seed : ShopColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: sel ? ShopColors.seed : ShopColors.line,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: sel ? Colors.white : ShopColors.ink,
                  ),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: sel
                        ? Colors.white.withValues(alpha: 0.22)
                        : ShopColors.seed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    numFa(count),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: sel ? Colors.white : ShopColors.seed,
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

  Widget _chequeFilters() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        children: [
          ShopSearchField(
            controller: _chequeSearch,
            hint: 'جستجو (شماره چک، مشتری، تلفن، فاکتور، بانک)...',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _chequeStatus,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'وضعیت',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('همه وضعیت‌ها')),
                    DropdownMenuItem(
                      value: TrsChequeState.inHand,
                      child: Text('در جریان وصول'),
                    ),
                    DropdownMenuItem(
                      value: TrsChequeState.cleared,
                      child: Text('وصول‌شده (پاس شده)'),
                    ),
                    DropdownMenuItem(
                      value: TrsChequeState.bounced,
                      child: Text('برگشت‌خورده'),
                    ),
                    DropdownMenuItem(
                      value: TrsChequeState.cancelled,
                      child: Text('ابطال / تعویض شده'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _chequeStatus = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _chequeTxnType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'نوع چک',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('همه انواع چک')),
                    DropdownMenuItem(
                      value: 2,
                      child: Text('چک‌های دریافتی (فروش)'),
                    ),
                    DropdownMenuItem(
                      value: 1,
                      child: Text('چک‌های پرداختی (خرید)'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _chequeTxnType = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _instFilters() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        children: [
          ShopSearchField(
            controller: _instSearch,
            hint: 'جستجو (نام مشتری، شماره تلفن، شماره فاکتور)...',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<bool?>(
            initialValue: _instPaid,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'وضعیت اقساط',
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('همه اقساط')),
              DropdownMenuItem(
                value: false,
                child: Text('پرداخت‌نشده / سررسید'),
              ),
              DropdownMenuItem(value: true, child: Text('تسویه‌شده')),
            ],
            onChanged: (v) => setState(() => _instPaid = v),
          ),
        ],
      ),
    );
  }

  Widget _chequeCard(ShopCheque c, {required bool canManage}) {
    final recv = c.isReceivable;
    final bounced = c.isBounced;
    final cleared = c.isCleared || c.status == TrsChequeState.cleared;
    final cancelled = c.status == TrsChequeState.cancelled;
    final endorsed = c.status == TrsChequeState.endorsed;

    final statusColor = bounced
        ? ShopColors.danger
        : cleared
        ? ShopColors.ok
        : endorsed
        ? ShopColors.teal
        : cancelled
        ? ShopColors.inkFaint
        : ShopColors.inkSoft;
    final statusText = bounced
        ? 'برگشتی'
        : cleared
        ? 'وصول‌شده'
        : endorsed
        ? 'خرج‌شده بابت هزینه'
        : cancelled
        ? 'ابطال / تعویض شده'
        : 'در جریان وصول';

    final canActOnOpen =
        !cleared && !bounced && !cancelled && !endorsed && canManage;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bounced
            ? ShopColors.danger.withValues(alpha: 0.04)
            : cleared
            ? ShopColors.ok.withValues(alpha: 0.04)
            : ShopColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: bounced
              ? ShopColors.danger.withValues(alpha: 0.3)
              : ShopColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShopPill(
                text: recv ? 'دریافتی' : 'پرداختی',
                color: recv ? ShopColors.ok : ShopColors.warn,
              ),
              const SizedBox(width: 6),
              if (c.hasChequeCharge) ...[
                const ShopPill(text: 'سوددار', color: ShopColors.indigo),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  'سریال: ${Fa.digits(c.number)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.ink,
                  ),
                ),
              ),
              ShopPill(text: statusText, color: statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  c.partyName,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: ShopColors.ink,
                  ),
                ),
              ),
              Text(
                '${money(c.amount)} ریال',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: recv ? ShopColors.ok : ShopColors.ink,
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
                'فاکتور: ${Fa.digits(c.orderNumber)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: ShopColors.seed,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if ((c.bankName ?? '').isNotEmpty)
                Text(
                  'بانک: ${c.bankName}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: ShopColors.inkSoft,
                  ),
                ),
              if (c.dueDate != null)
                Text(
                  'سررسید: ${jalaliShort(c.dueDate!)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: ShopColors.inkSoft,
                  ),
                ),
              if (!cleared && !cancelled && !endorsed && c.daysOverdue > 0)
                ShopPill(
                  text: '${numFa(c.daysOverdue)} روز معوق',
                  color: ShopColors.danger,
                )
              else if (!cleared &&
                  !cancelled &&
                  !endorsed &&
                  c.daysOverdue == 0 &&
                  c.dueDate != null)
                const ShopPill(text: 'سررسید امروز', color: ShopColors.warn),
            ],
          ),
          if (bounced && (c.bounceReason ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'علت برگشت: ${c.bounceReason}',
              style: const TextStyle(fontSize: 11, color: ShopColors.danger),
            ),
          ],
          if (cleared && c.clearedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'تاریخ وصول: ${jalaliShort(c.clearedAt!)}',
              style: const TextStyle(fontSize: 11, color: ShopColors.ok),
            ),
          ],
          const Divider(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [
              if (c.hasChequeCharge)
                _miniBtn(
                  'تاریخچه',
                  Icons.history_rounded,
                  ShopColors.inkSoft,
                  () => _openChequeHistorySheet(c),
                ),
              if (c.hasChequeCharge &&
                  !cleared &&
                  !cancelled &&
                  !endorsed &&
                  canManage) ...[
                _miniBtn(
                  'سررسید',
                  Icons.edit_calendar_rounded,
                  ShopColors.seed,
                  () => _openRescheduleSheet(c),
                ),
                _miniBtn(
                  'تعویض',
                  Icons.swap_horiz_rounded,
                  ShopColors.warn,
                  () => _openReplaceChequeSheet(c),
                ),
              ],
              if (canActOnOpen) ...[
                _miniBtn(
                  c.isPurchase ? 'پرداخت چک' : 'وصول چک',
                  Icons.check_rounded,
                  ShopColors.ok,
                  () => _openChequeReceiptSheet(c),
                ),
                _miniBtn(
                  'برگشت',
                  Icons.cancel_outlined,
                  ShopColors.danger,
                  () => _bounceCheque(c),
                ),
              ] else if (bounced && canManage) ...[
                _miniBtn(
                  'وصول شد',
                  Icons.check_rounded,
                  ShopColors.ok,
                  () => _openChequeReceiptSheet(c),
                ),
                _miniBtn(
                  'بازگردانی',
                  Icons.undo_rounded,
                  ShopColors.inkSoft,
                  () => _resetCheque(c),
                ),
              ] else if (cleared && canManage)
                _miniBtn(
                  c.isPurchase ? 'لغو پرداخت' : 'لغو وصول',
                  Icons.undo_rounded,
                  ShopColors.inkSoft,
                  () => _openChequeReversalSheet(c),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _instCard(ShopInstallment i, {required bool canManage}) {
    final overdue = !i.isPaid && i.daysOverdue > 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: i.isPaid
            ? ShopColors.ok.withValues(alpha: 0.04)
            : overdue
            ? ShopColors.danger.withValues(alpha: 0.04)
            : ShopColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: overdue
              ? ShopColors.danger.withValues(alpha: 0.3)
              : ShopColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShopPill(
                text: 'قسط ${numFa(i.no)}',
                color: i.isPurchase ? ShopColors.warn : ShopColors.seed,
              ),
              const SizedBox(width: 6),
              if (i.isPurchase) ...[
                const ShopPill(text: 'خرید', color: ShopColors.warn),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  i.partyName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ShopColors.ink,
                  ),
                ),
              ),
              Text(
                '${money(i.amount)} ریال',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              Text(
                'فاکتور: ${Fa.digits(i.orderNumber)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: ShopColors.seed,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (i.dueDate != null)
                Text(
                  'سررسید: ${jalaliShort(i.dueDate!)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: ShopColors.inkSoft,
                  ),
                ),
              if (i.isPaid)
                ShopPill(
                  text: i.paidAt != null
                      ? 'تسویه‌شده (${jalaliShort(i.paidAt!)})'
                      : 'تسویه‌شده',
                  color: ShopColors.ok,
                )
              else if (i.daysOverdue > 0)
                ShopPill(
                  text: '${numFa(i.daysOverdue)} روز تاخیر',
                  color: ShopColors.danger,
                )
              else if (i.daysOverdue == 0)
                const ShopPill(text: 'سررسید امروز', color: ShopColors.warn)
              else
                ShopPill(
                  text: '${numFa(-i.daysOverdue)} روز مانده',
                  color: ShopColors.seed,
                ),
            ],
          ),
          if (canManage) ...[
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!i.isPaid)
                  _miniBtn(
                    i.isPurchase ? 'پرداخت قسط' : 'دریافت قسط',
                    Icons.payments_rounded,
                    ShopColors.ok,
                    () => _openInstallmentReceiptSheet(i),
                  )
                else
                  _miniBtn(
                    i.isPurchase ? 'لغو پرداخت' : 'لغو دریافت',
                    Icons.undo_rounded,
                    ShopColors.inkSoft,
                    () => _unpayInstallment(i),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickKpiCard extends StatelessWidget {
  const _QuickKpiCard({
    required this.active,
    required this.title,
    required this.value,
    required this.footer,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final bool active;
  final String title;
  final String value;
  final String footer;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.08) : ShopColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? color : ShopColors.line,
            width: active ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: ShopColors.inkSoft,
                    ),
                  ),
                ),
                Icon(icon, size: 16, color: color),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$value ریال',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              footer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: ShopColors.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateFieldTile extends StatelessWidget {
  const _DateFieldTile({
    required this.label,
    required this.date,
    this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_rounded, size: 17),
        ),
        child: Text(
          jalaliShort(date),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ShopColors.ink,
          ),
        ),
      ),
    );
  }
}
