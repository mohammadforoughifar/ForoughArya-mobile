// ============================================================
//  مدیریت جامع چک‌ها و دفترچه اقساط
//  آینهٔ صفحهٔ وب: /shop/credit-management
//                 → Pages/Shop/ShopCreditManagement.razor
//
//  • چهار کارت شاخص: چک‌های در جریان، چک‌های برگشتی، اقساط باز/معوق،
//    مجموع وصولی‌های قطعی (چک وصول‌شده + قسط پرداخت‌شده)
//  • تب «مدیریت چک‌ها»:
//      فیلتر جستجو + وضعیت + نوع تراکنش (دریافتی/پرداختی)
//      هر سطر: نوع، سریال، طرف حساب، بانک و شعبه، شماره فاکتور، مبلغ،
//      سررسید (+ معوق/سررسید امروز)، وضعیت
//      عملیات: وصول · برگشت (با علت) · لغو وصول/بازگردانی
//  • تب «مدیریت دفترچه اقساط»:
//      فیلتر جستجو + وضعیت تسویه
//      هر سطر: نوبت قسط، مشتری، فاکتور، مبلغ، سررسید، وضعیت زمانی/تسویه
//      عملیات: تسویه قسط · لغو تسویه
//  پیام‌های موفقیت/خطا عیناً وب هستند.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/fa_num.dart';
import '../data/shop_repository.dart';
import '../models/treasury_models.dart';
import 'shop_style.dart';

class ShopCreditPage extends StatefulWidget {
  const ShopCreditPage({super.key});

  @override
  State<ShopCreditPage> createState() => _ShopCreditPageState();
}

class _ShopCreditPageState extends State<ShopCreditPage> {
  late final ShopRepository _repo;

  ShopCreditSummary? _summary;
  List<ShopCheque> _cheques = const [];
  List<ShopInstallment> _installments = const [];
  bool _loading = true;
  String? _error;
  int _tab = 0;

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
    _load();
  }

  @override
  void dispose() {
    _chequeSearch.dispose();
    _instSearch.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await _repo.shopCreditSummary();
      final cheques = await _repo.shopCheques();
      final insts = await _repo.shopInstallments();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _cheques = cheques;
        _installments = insts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _clean(e);
        _loading = false;
      });
    }
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');

  /// همان `ApplyChequeFilter` وب — مرتب‌سازی بر اساس سررسید
  List<ShopCheque> get _filteredCheques {
    var q = _cheques.where((c) {
      if (_chequeStatus != null) {
        if (_chequeStatus == TrsChequeState.cleared) {
          if (!(c.isCleared || c.status == TrsChequeState.cleared)) {
            return false;
          }
        } else if (_chequeStatus == TrsChequeState.bounced) {
          if (c.status != TrsChequeState.bounced) return false;
        } else {
          if (c.isCleared || c.status == TrsChequeState.bounced) return false;
        }
      }
      if (_chequeTxnType != null && c.transactionType != _chequeTxnType) {
        return false;
      }
      final s = toEnDigits(_chequeSearch.text).trim().toLowerCase();
      if (s.isNotEmpty) {
        final hay = [
          c.number,
          c.partyName,
          c.orderNumber,
          c.bankName ?? '',
        ].join(' ').toLowerCase();
        if (!hay.contains(s)) return false;
      }
      return true;
    }).toList();
    q.sort(
      (a, b) => (a.dueDate ?? DateTime(2100)).compareTo(
        b.dueDate ?? DateTime(2100),
      ),
    );
    return q;
  }

  /// همان `ApplyInstallmentFilter` وب
  List<ShopInstallment> get _filteredInstallments {
    var q = _installments.where((i) {
      if (_instPaid != null && i.isPaid != _instPaid) return false;
      final s = toEnDigits(_instSearch.text).trim().toLowerCase();
      if (s.isNotEmpty) {
        final hay = [
          i.partyName,
          i.orderNumber,
          i.partyMobile ?? '',
        ].join(' ').toLowerCase();
        if (!hay.contains(s)) return false;
      }
      return true;
    }).toList();
    q.sort(
      (a, b) => (a.dueDate ?? DateTime(2100)).compareTo(
        b.dueDate ?? DateTime(2100),
      ),
    );
    return q;
  }

  void _toast(String msg, {bool ok = false, bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        backgroundColor: ok
            ? ShopColors.ok
            : error
            ? ShopColors.danger
            : null,
      ),
    );
  }

  Future<void> _clearCheque(ShopCheque c) async {
    try {
      await _repo.clearShopCheque(c.id);
      _toast('چک ${Fa.number(int.tryParse(c.number) ?? 0)} با موفقیت وصول شد.',
          ok: true);
      _load();
    } catch (e) {
      _toast(_clean(e), error: true);
    }
  }

  Future<void> _bounceCheque(ShopCheque c) async {
    final reasonCtrl = TextEditingController(text: 'کسر موجودی حساب');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'ثبت برگشت چک در سیستم',
          style: TextStyle(fontSize: 15),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'آیا از ثبت برگشت چک شماره ${Fa.number(int.tryParse(c.number) ?? 0)} '
              'به مبلغ ${Fa.number(c.amount)} ریال طرف حساب ${c.partyName} اطمینان دارید؟',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            const Text(
              'با ثبت برگشت، چک به عنوان چک لاوصول علامت‌گذاری شده و مانده بدهی مشتری '
              'در کلیه گزارش‌های مالی احیا خواهد شد.',
              style: TextStyle(fontSize: 10.5, color: ShopColors.warn),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'علت برگشت چک',
                labelStyle: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: ShopColors.danger),
            child: const Text('ثبت قطعی برگشت چک'),
          ),
        ],
      ),
    );
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (ok != true || !mounted) return;
    try {
      await _repo.bounceShopCheque(c.id, reason);
      _toast(
        'چک ${Fa.number(int.tryParse(c.number) ?? 0)} برگشت خورد و در وضعیت بدهی ثبت شد.',
        error: true,
      );
      _load();
    } catch (e) {
      _toast(_clean(e), error: true);
    }
  }

  Future<void> _resetCheque(ShopCheque c) async {
    try {
      await _repo.resetShopCheque(c.id);
      _toast(
        'وضعیت چک ${Fa.number(int.tryParse(c.number) ?? 0)} به در جریان بازگردانده شد.',
      );
      _load();
    } catch (e) {
      _toast(_clean(e), error: true);
    }
  }

  Future<void> _payInstallment(ShopInstallment i) async {
    try {
      await _repo.payInstallment(i.id);
      _toast(
        'قسط شماره ${Fa.number(i.no)} مشتری ${i.partyName} با موفقیت تسویه شد.',
        ok: true,
      );
      _load();
    } catch (e) {
      _toast(_clean(e), error: true);
    }
  }

  Future<void> _unpayInstallment(ShopInstallment i) async {
    try {
      await _repo.unpayInstallment(i.id);
      _toast(
        'تسویه قسط شماره ${Fa.number(i.no)} لغو شد و به عنوان بدهی معوق منظور گردید.',
      );
      _load();
    } catch (e) {
      _toast(_clean(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShopColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            ShopHeader(
              title: 'مدیریت چک‌ها، اسناد و دفترچه اقساط',
              subtitle:
                  'پیگیری تعهدات مشتریان و تأمین‌کنندگان، تأیید وصولی‌ها، '
                  'اعلام برگشتی‌ها و تسویه اقساط',
              icon: Icons.wallet_rounded,
              badge: 'وصول مطالبات',
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 70),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 50),
                child: ShopEmpty(
                  title: 'بارگذاری ناموفق بود',
                  subtitle: _error,
                  icon: Icons.error_outline_rounded,
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: _kpis(),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: ShopSegmented(
                  labels: [
                    'مدیریت چک‌ها (${Fa.number(_cheques.length)})',
                    'دفترچه اقساط (${Fa.number(_installments.length)})',
                  ],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              if (_tab == 0) _chequesTab() else _installmentsTab(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kpis() {
    final s = _summary!;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.85,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [
        ShopKpi(
          title: 'چک‌های در جریان وصول',
          value: Fa.number(s.inHandChequesTotal),
          unit: 'ریال نزد صندوق یا بانک',
          footer: '${Fa.number(s.inHandChequesCount)} برگ چک فعال',
          icon: Icons.hourglass_bottom_rounded,
          color: ShopColors.indigo,
        ),
        ShopKpi(
          title: 'چک‌های برگشتی (مطالبات معوق)',
          value: Fa.number(s.bouncedChequesTotal),
          unit: 'ریال وصول‌نشده',
          footer: '${Fa.number(s.bouncedChequesCount)} چک برگشتی و بدهکار',
          icon: Icons.cancel_rounded,
          color: ShopColors.danger,
        ),
        ShopKpi(
          title: 'اقساط باز و سررسیدشده',
          value: Fa.number(s.pendingInstallmentsTotal),
          unit: 'ریال اقساط وصولی',
          footer:
              '${Fa.number(s.pendingInstallmentsCount)} قسط باز '
              '(${Fa.number(s.overdueInstallmentsCount)} معوق)',
          icon: Icons.event_note_rounded,
          color: ShopColors.warn,
        ),
        ShopKpi(
          title: 'مجموع وصولی‌های موفق',
          value: Fa.number(s.collectedTotal),
          unit: 'ریال تسویه‌شده',
          footer: '${Fa.number(s.collectedCount)} فقره وصولی کامل',
          icon: Icons.check_circle_rounded,
          color: ShopColors.ok,
        ),
      ],
    );
  }

  Widget _filterCard(List<Widget> children) => Container(
    margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(children: children),
  );

  Widget _chequesTab() {
    final list = _filteredCheques;
    return Column(
      children: [
        _filterCard([
          TextField(
            controller: _chequeSearch,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 12.5),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'جستجوی سریال، کد صیاد، نام مشتری…',
              hintStyle: TextStyle(fontSize: 12),
              prefixIcon: Icon(Icons.search_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _chequeStatus,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'وضعیت چک',
                    labelStyle: TextStyle(fontSize: 10.5),
                  ),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: ShopColors.ink,
                  ),
                  items: const [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text('همه وضعیت‌ها'),
                    ),
                    DropdownMenuItem<int?>(
                      value: TrsChequeState.inHand,
                      child: Text('در جریان وصول'),
                    ),
                    DropdownMenuItem<int?>(
                      value: TrsChequeState.cleared,
                      child: Text('وصول‌شده (پاس شده)'),
                    ),
                    DropdownMenuItem<int?>(
                      value: TrsChequeState.bounced,
                      child: Text('برگشت خورده (بدهکار)'),
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
                    isDense: true,
                    labelText: 'نوع تراکنش',
                    labelStyle: TextStyle(fontSize: 10.5),
                  ),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: ShopColors.ink,
                  ),
                  items: const [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text('دریافتی و پرداختی'),
                    ),
                    DropdownMenuItem<int?>(
                      value: 2,
                      child: Text('دریافتی از مشتری'),
                    ),
                    DropdownMenuItem<int?>(
                      value: 1,
                      child: Text('پرداختی ما'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _chequeTxnType = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${Fa.number(list.length)} چک',
              style: const TextStyle(
                fontSize: 10,
                color: ShopColors.inkFaint,
              ),
            ),
          ),
        ]),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: ShopEmpty(
              title: 'هیچ چکی با شرایط انتخابی یافت نشد',
              icon: Icons.inbox_rounded,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(children: [for (final c in list) _chequeRow(c)]),
          ),
      ],
    );
  }

  Widget _chequeRow(ShopCheque c) {
    final color = c.isBounced
        ? ShopColors.danger
        : c.isCleared
        ? ShopColors.ok
        : ShopColors.seed;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
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
              ShopTag(
                text: c.isReceivable ? 'دریافتی' : 'پرداختی',
                color: c.isReceivable ? ShopColors.seed : ShopColors.warn,
                icon: c.isReceivable
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'سریال ${Fa.number(int.tryParse(c.number) ?? 0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                Fa.number(c.amount),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: ShopColors.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _kv('طرف حساب', c.partyName),
                if ((c.partyMobile ?? '').isNotEmpty)
                  _kv('موبایل', c.partyMobile!),
                _kv(
                  'بانک و شعبه',
                  [c.bankName, c.accountInfo]
                          .where((e) => (e ?? '').isNotEmpty)
                          .join(' — ')
                          .isEmpty
                      ? '—'
                      : [c.bankName, c.accountInfo]
                            .where((e) => (e ?? '').isNotEmpty)
                            .join(' — '),
                ),
                _kv('فاکتور', c.orderNumber),
                _kv(
                  'سررسید',
                  [
                    if (c.dueDate != null) jalaliShort(c.dueDate!),
                    if (!c.isCleared && !c.isBounced && c.daysOverdue > 0)
                      'معوق (${Fa.number(c.daysOverdue)} روز)'
                    else if (!c.isCleared &&
                        !c.isBounced &&
                        c.dueDate != null &&
                        _isToday(c.dueDate!))
                      'سررسید امروز',
                  ].join(' · '),
                ),
                if (!(c.ownerName ?? '').isEmpty)
                  _kv('صاحب چک', c.ownerName!),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              ShopTag(
                text: c.isBounced
                    ? 'برگشت خورده'
                    : c.isCleared
                    ? 'وصول‌شده'
                    : 'در جریان وصول',
                color: color,
              ),
              const Spacer(),
              if (!c.isCleared && !c.isBounced) ...[
                TextButton.icon(
                  onPressed: () => _clearCheque(c),
                  style: TextButton.styleFrom(
                    foregroundColor: ShopColors.ok,
                  ),
                  icon: const Icon(Icons.check_rounded, size: 14),
                  label: const Text('وصول', style: TextStyle(fontSize: 11)),
                ),
                TextButton.icon(
                  onPressed: () => _bounceCheque(c),
                  style: TextButton.styleFrom(
                    foregroundColor: ShopColors.danger,
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 14),
                  label: const Text('برگشت', style: TextStyle(fontSize: 11)),
                ),
              ] else if (c.isBounced) ...[
                TextButton.icon(
                  onPressed: () => _clearCheque(c),
                  style: TextButton.styleFrom(
                    foregroundColor: ShopColors.ok,
                  ),
                  icon: const Icon(Icons.check_rounded, size: 14),
                  label: const Text(
                    'وصول شد',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _resetCheque(c),
                  icon: const Icon(Icons.undo_rounded, size: 14),
                  label: const Text(
                    'بازگردانی',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ] else
                TextButton.icon(
                  onPressed: () => _resetCheque(c),
                  icon: const Icon(Icons.undo_rounded, size: 14),
                  label: const Text(
                    'لغو وصول',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
          if (c.isBounced && (c.bounceReason ?? '').isNotEmpty)
            Text(
              'علت: ${c.bounceReason}',
              style: const TextStyle(fontSize: 10, color: ShopColors.danger),
            ),
        ],
      ),
    );
  }

  Widget _installmentsTab() {
    final list = _filteredInstallments;
    return Column(
      children: [
        _filterCard([
          TextField(
            controller: _instSearch,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 12.5),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'جستجوی نام مشتری، تلفن، شماره فاکتور…',
              hintStyle: TextStyle(fontSize: 12),
              prefixIcon: Icon(Icons.search_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<bool?>(
                  initialValue: _instPaid,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'وضعیت تسویه اقساط',
                    labelStyle: TextStyle(fontSize: 10.5),
                  ),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: ShopColors.ink,
                  ),
                  items: const [
                    DropdownMenuItem<bool?>(
                      value: null,
                      child: Text('همه اقساط'),
                    ),
                    DropdownMenuItem<bool?>(
                      value: false,
                      child: Text('پرداخت‌نشده / معوق'),
                    ),
                    DropdownMenuItem<bool?>(
                      value: true,
                      child: Text('پرداخت‌شده'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _instPaid = v),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${Fa.number(list.length)} قسط',
                style: const TextStyle(
                  fontSize: 10,
                  color: ShopColors.inkFaint,
                ),
              ),
            ],
          ),
        ]),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: ShopEmpty(
              title: 'هیچ قسطی یافت نشد',
              icon: Icons.event_busy_rounded,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(children: [for (final i in list) _instRow(i)]),
          ),
      ],
    );
  }

  Widget _instRow(ShopInstallment i) {
    final color = i.isPaid
        ? ShopColors.ok
        : i.daysOverdue > 0
        ? ShopColors.danger
        : ShopColors.warn;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
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
              ShopTag(text: 'قسط ${Fa.number(i.no)}', color: ShopColors.inkSoft),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  i.partyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                Fa.number(i.amount),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: ShopColors.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                if ((i.partyMobile ?? '').isNotEmpty)
                  _kv('موبایل', i.partyMobile!),
                _kv('فاکتور', i.orderNumber),
                _kv(
                  'سررسید',
                  i.dueDate == null ? '—' : jalaliShort(i.dueDate!),
                ),
                _kv(
                  'وضعیت زمانی',
                  i.isPaid
                      ? '—'
                      : i.daysOverdue > 0
                      ? 'معوق (${Fa.number(i.daysOverdue)} روز)'
                      : i.dueDate != null && _isToday(i.dueDate!)
                      ? 'سررسید امروز'
                      : 'آتی',
                ),
                if (i.isPaid && i.paidAt != null)
                  _kv('تاریخ پرداخت', jalaliShort(i.paidAt!)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              ShopTag(
                text: i.isPaid ? 'پرداخت‌شده' : 'پرداخت‌نشده (بدهکار)',
                color: color,
              ),
              const Spacer(),
              if (!i.isPaid)
                TextButton.icon(
                  onPressed: () => _payInstallment(i),
                  style: TextButton.styleFrom(foregroundColor: ShopColors.ok),
                  icon: const Icon(Icons.check_rounded, size: 14),
                  label: const Text(
                    'تسویه قسط',
                    style: TextStyle(fontSize: 11),
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () => _unpayInstallment(i),
                  icon: const Icon(Icons.undo_rounded, size: 14),
                  label: const Text(
                    'لغو تسویه',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1.5),
    child: Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(
            k,
            style: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
          ),
        ),
        Expanded(
          child: Text(
            v,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: ShopColors.inkSoft,
            ),
          ),
        ),
      ],
    ),
  );
}
