// ============================================================
//  چک‌های خزانه
//  آینهٔ صفحهٔ وب: /trs/cheques → Pages/Treasury/TrsCheques.razor
//
//  • تب نوع چک: همه / دریافتی / پرداختی
//  • فیلتر: جستجو، وضعیت، فقط چک‌های باز، بازهٔ شمسی، پاک کردن
//  • ثبت چک جدید (دریافتی/صادره) با اعتبارسنجی وب:
//        «برای چک صادره، حساب بانکی الزامی است»
//  • «عملیات چک»: فقط تغییرهای مجاز سرور (`EnsureTransition`)
//        ۰ نزد صندوق → ۱ واگذاری / ۲ وصول / ۴ خرج / ۵ ابطال
//        ۱ در جریان → ۲ وصول / ۳ برگشت / ۰ بازگشت به صندوق
//        ۳ برگشتی  → ۱ واگذاری / ۲ وصول / ۵ ابطال
//    عملیات واگذاری و وصول چک دریافتی به حساب بانکی نیاز دارد.
//  • پروندهٔ چک: تاریخچهٔ عملیات‌ها با سند حسابداری هر عملیات
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
import '../models/treasury_models.dart';
import 'shop_style.dart';

class TrsChequesPage extends StatefulWidget {
  const TrsChequesPage({super.key});

  @override
  State<TrsChequesPage> createState() => _TrsChequesPageState();
}

class _TrsChequesPageState extends State<TrsChequesPage> {
  late final ShopRepository _repo;
  late final ShopPerms _perms;

  List<TreasuryCheque> _items = const [];
  List<TreasuryAccount> _accounts = const [];
  bool _loading = true;
  String? _error;

  int? _kind;
  int? _status;
  bool _onlyOpen = false;
  DateTime? _from;
  DateTime? _to;
  final _searchCtrl = TextEditingController();

  int _page = 1;
  static const _pageSize = 15;

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _perms = ShopPerms(context.read<AuthController>().session);
    _loadAccounts();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final list = await _repo.treasuryAccounts(activeOnly: true);
      if (!mounted) return;
      setState(() => _accounts = list);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _repo.treasuryCheques(
        kind: _kind,
        status: _status,
        search: _searchCtrl.text,
        from: _from,
        to: _to,
        onlyOpen: _onlyOpen,
        page: _page,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items = res.items;
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

  void _reset() {
    setState(() {
      _kind = null;
      _status = null;
      _onlyOpen = false;
      _from = null;
      _to = null;
      _page = 1;
      _searchCtrl.clear();
    });
    _load();
  }

  Future<void> _pick(bool isFrom) async {
    final picked = await showJalaliDatePicker(
      context,
      initial: isFrom ? _from : _to,
      title: isFrom ? 'از تاریخ' : 'تا تاریخ',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
      _page = 1;
    });
    _load();
  }

  Future<void> _openForm([TreasuryCheque? c]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TrsChequeFormPage(cheque: c, accounts: _accounts),
      ),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _openAction(TreasuryCheque c) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ChequeActionSheet(cheque: c, accounts: _accounts),
    );
    if (ok == true && mounted) _load();
  }

  Future<void> _openDetail(TreasuryCheque c) async {
    TreasuryCheque? full;
    try {
      full = await _repo.treasuryCheque(c.id);
    } catch (_) {}
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ChequeFileSheet(cheque: full ?? c),
    );
  }

  Future<void> _delete(TreasuryCheque c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف چک', style: TextStyle(fontSize: 15)),
        content: Text(
          'چک شماره ${Fa.number(int.tryParse(c.number) ?? 0)} حذف شود؟',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: ShopColors.danger),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.deleteCheque(c.id);
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_clean(e), style: const TextStyle(fontSize: 12))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canWrite =
        _perms.has('TrsCheques.Create') || _perms.hasModule('TrsCheques');
    final canDelete = _perms.has('TrsCheques.Delete');
    final canAction = _perms.has('TrsCheques.Confirm');
    return Scaffold(
      backgroundColor: ShopColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            ShopHeader(
              title: 'چک‌های دریافتی و پرداختی',
              subtitle: 'صدور، واگذاری، وصول، برگشت و خرج چک با اثر حسابداری',
              icon: Icons.credit_card_rounded,
              actions: [
                if (canWrite)
                  ShopHeaderButton(
                    label: 'چک جدید',
                    icon: Icons.add_rounded,
                    filled: true,
                    onTap: () => _openForm(),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ShopSegmented(
                labels: const ['همه', 'دریافتی', 'پرداختی'],
                index: _kind == null ? 0 : _kind! + 1,
                onChanged: (i) {
                  setState(() {
                    _kind = i == 0 ? null : i - 1;
                    _page = 1;
                  });
                  _load();
                },
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: ShopColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ShopColors.line),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) {
                        _page = 1;
                        _load();
                      },
                      style: const TextStyle(fontSize: 12.5),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'شماره چک، صیاد، طرف حساب…',
                        hintStyle: TextStyle(fontSize: 12),
                        prefixIcon: Icon(Icons.search_rounded, size: 18),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            initialValue: _status,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'وضعیت',
                              labelStyle: TextStyle(fontSize: 10.5),
                            ),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: ShopColors.ink,
                            ),
                            items: const [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text('همه'),
                              ),
                              DropdownMenuItem<int?>(
                                value: 0,
                                child: Text('نزد صندوق'),
                              ),
                              DropdownMenuItem<int?>(
                                value: 1,
                                child: Text('در جریان وصول'),
                              ),
                              DropdownMenuItem<int?>(
                                value: 2,
                                child: Text('وصول شده'),
                              ),
                              DropdownMenuItem<int?>(
                                value: 3,
                                child: Text('برگشتی'),
                              ),
                              DropdownMenuItem<int?>(
                                value: 4,
                                child: Text('خرج شده'),
                              ),
                              DropdownMenuItem<int?>(
                                value: 5,
                                child: Text('ابطال شده'),
                              ),
                            ],
                            onChanged: (v) {
                              setState(() {
                                _status = v;
                                _page = 1;
                              });
                              _load();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _onlyOpen = !_onlyOpen;
                                _page = 1;
                              });
                              _load();
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: _onlyOpen
                                    ? ShopColors.seed.withValues(alpha: 0.08)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _onlyOpen
                                      ? ShopColors.seed.withValues(alpha: 0.4)
                                      : ShopColors.line,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _onlyOpen
                                        ? Icons.check_box_rounded
                                        : Icons.check_box_outline_blank_rounded,
                                    size: 15,
                                    color: _onlyOpen
                                        ? ShopColors.seed
                                        : ShopColors.inkFaint,
                                  ),
                                  const SizedBox(width: 5),
                                  const Expanded(
                                    child: Text(
                                      'فقط چک‌های باز',
                                      style: TextStyle(fontSize: 10.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _dateBox(
                            'از تاریخ',
                            _from,
                            () => _pick(true),
                            () {
                              setState(() => _from = null);
                              _load();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _dateBox(
                            'تا تاریخ',
                            _to,
                            () => _pick(false),
                            () {
                              setState(() => _to = null);
                              _load();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _reset,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: ShopColors.line),
                            minimumSize: const Size(44, 44),
                          ),
                          icon: const Icon(
                            Icons.filter_alt_off_rounded,
                            size: 17,
                            color: ShopColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
                  title: 'دریافت چک‌ها ناموفق بود',
                  subtitle: _error,
                  icon: Icons.error_outline_rounded,
                ),
              )
            else if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 50),
                child: ShopEmpty(
                  title: 'چکی یافت نشد',
                  subtitle: 'با «چک جدید» اولین برگ چک را ثبت کنید.',
                  icon: Icons.credit_card_off_rounded,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Column(
                  children: [
                    for (final c in _items)
                      _chequeCard(
                        c,
                        canAction: canAction,
                        canDelete: canDelete,
                        canWrite: canWrite,
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _page <= 1
                              ? null
                              : () {
                                  setState(() => _page--);
                                  _load();
                                },
                          child: const Text(
                            'قبلی',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        Text(
                          'صفحهٔ ${Fa.number(_page)}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: ShopColors.inkFaint,
                          ),
                        ),
                        TextButton(
                          onPressed: _items.length < _pageSize
                              ? null
                              : () {
                                  setState(() => _page++);
                                  _load();
                                },
                          child: const Text(
                            'بعدی',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dateBox(
    String label,
    DateTime? value,
    VoidCallback onTap,
    VoidCallback onClear,
  ) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShopColors.line),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_month_rounded,
            size: 14,
            color: ShopColors.inkFaint,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value == null ? label : jalaliShort(value),
              maxLines: 1,
              style: TextStyle(
                fontSize: 10.5,
                color: value == null ? ShopColors.inkFaint : ShopColors.ink,
              ),
            ),
          ),
          if (value != null)
            InkWell(
              onTap: onClear,
              child: const Icon(
                Icons.close_rounded,
                size: 13,
                color: ShopColors.inkFaint,
              ),
            ),
        ],
      ),
    ),
  );

  Widget _chequeCard(
    TreasuryCheque c, {
    required bool canAction,
    required bool canDelete,
    required bool canWrite,
  }) {
    final color = c.isBounced
        ? ShopColors.danger
        : c.isCleared
        ? ShopColors.ok
        : c.isOverdue
        ? ShopColors.warn
        : ShopColors.seed;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border(
          right: BorderSide(color: color, width: 3),
          top: const BorderSide(color: ShopColors.line),
          bottom: const BorderSide(color: ShopColors.line),
          left: const BorderSide(color: ShopColors.line),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  c.kind == ChequeKind.received
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  size: 17,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'چک ${Fa.number(int.tryParse(c.number) ?? 0)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 5),
                        ShopTag(
                          text: c.kindTitle,
                          color: c.kind == ChequeKind.received
                              ? ShopColors.seed
                              : ShopColors.warn,
                        ),
                      ],
                    ),
                    Text(
                      c.partyName ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Fa.number(c.amount),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  const Text(
                    'ریال',
                    style: TextStyle(fontSize: 9, color: ShopColors.inkFaint),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            decoration: BoxDecoration(
              color: ShopColors.bg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              children: [
                _line(
                  'سررسید',
                  c.dueDate == null ? '—' : jalaliShort(c.dueDate!),
                ),
                if ((c.bankName ?? '').isNotEmpty ||
                    (c.branchName ?? '').isNotEmpty)
                  _line(
                    'بانک',
                    [c.bankName, c.branchName]
                        .where((e) => (e ?? '').isNotEmpty)
                        .join(' — '),
                  ),
                if ((c.sayadId ?? '').isNotEmpty) _line('صیاد', c.sayadId!),
                _line(
                  'محل نگهداری',
                  [c.trsAccountName, c.accountNumber]
                      .where((e) => (e ?? '').isNotEmpty)
                      .join(' — ').isEmpty
                      ? '—'
                      : [c.trsAccountName, c.accountNumber]
                            .where((e) => (e ?? '').isNotEmpty)
                            .join(' — '),
                ),
                if ((c.description ?? '').isNotEmpty)
                  _line('شرح', c.description!),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              ShopTag(text: c.statusTitle, color: color),
              if (c.isOverdue)
                const Padding(
                  padding: EdgeInsets.only(right: 5),
                  child: ShopTag(
                    text: 'سررسید گذشته',
                    color: ShopColors.danger,
                    icon: Icons.warning_amber_rounded,
                  ),
                )
              else if (c.isDueSoon)
                const Padding(
                  padding: EdgeInsets.only(right: 5),
                  child: ShopTag(
                    text: 'نزدیک سررسید',
                    color: ShopColors.warn,
                    icon: Icons.schedule_rounded,
                  ),
                ),
              const Spacer(),
              if (canAction && c.isOpen)
                TextButton.icon(
                  onPressed: () => _openAction(c),
                  icon: const Icon(Icons.play_circle_outline_rounded, size: 14),
                  label: const Text(
                    'عملیات',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              TextButton.icon(
                onPressed: () => _openDetail(c),
                icon: const Icon(Icons.folder_open_rounded, size: 14),
                label: const Text('پرونده', style: TextStyle(fontSize: 11)),
              ),
              if (canWrite && c.isOpen)
                TextButton.icon(
                  onPressed: () => _openForm(c),
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: const Text('ویرایش', style: TextStyle(fontSize: 11)),
                ),
              if (canDelete)
                TextButton.icon(
                  onPressed: () => _delete(c),
                  style: TextButton.styleFrom(
                    foregroundColor: ShopColors.danger,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 14),
                  label: const Text('حذف', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(
          width: 74,
          child: Text(
            label,
            style: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
          ),
        ),
        Expanded(
          child: Text(
            value,
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

// ============================================================
//  شیت عملیات چک — فقط تغییرهای مجاز همان `EnsureTransition` سرور
// ============================================================

class _ChequeActionSheet extends StatefulWidget {
  const _ChequeActionSheet({required this.cheque, required this.accounts});

  final TreasuryCheque cheque;
  final List<TreasuryAccount> accounts;

  @override
  State<_ChequeActionSheet> createState() => _ChequeActionSheetState();
}

class _ChequeActionSheetState extends State<_ChequeActionSheet> {
  late final ShopRepository _repo;
  final _descCtrl = TextEditingController();
  late int _status;
  late DateTime _date;
  int? _accountId;
  bool _saving = false;

  List<int> get _allowed {
    const all = [
      TrsChequeState.inHand,
      TrsChequeState.inCollection,
      TrsChequeState.cleared,
      TrsChequeState.bounced,
      TrsChequeState.endorsed,
      TrsChequeState.cancelled,
    ];
    return all
        .where(
          (t) => TrsChequeState.canGo(widget.cheque.kind, widget.cheque.status, t),
        )
        .toList();
  }

  bool get _needsBank =>
      _status == TrsChequeState.inCollection ||
      (_status == TrsChequeState.cleared &&
          widget.cheque.kind == ChequeKind.received);

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _status = _allowed.isEmpty ? widget.cheque.status : _allowed.first;
    _date = DateTime.now();
    _accountId = widget.cheque.trsAccountId;
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  static String _label(int kind, int s) => switch (s) {
    TrsChequeState.inCollection => 'واگذاری به بانک',
    TrsChequeState.cleared => kind == ChequeKind.received ? 'وصول شد' : 'پاس شد',
    TrsChequeState.bounced => 'برگشت خورد',
    TrsChequeState.endorsed => 'خرج چک',
    TrsChequeState.cancelled => 'ابطال',
    _ => 'بازگشت به صندوق',
  };

  /// همان `EffectHint` وب
  static String _hint(int kind, int s) {
    if (kind == ChequeKind.received) {
      return switch (s) {
        TrsChequeState.inCollection =>
          'اسناد در جریان وصول بدهکار | اسناد دریافتنی بستانکار',
        TrsChequeState.cleared =>
          'بانک بدهکار | اسناد در جریان وصول (یا اسناد دریافتنی) بستانکار — پول وارد حساب می‌شود.',
        TrsChequeState.bounced =>
          'حساب‌های دریافتنی بدهکار | اسناد در جریان وصول بستانکار — طلب دوباره روی طرف حساب می‌نشیند.',
        TrsChequeState.endorsed =>
          'حساب‌های پرداختنی بدهکار | اسناد دریافتنی بستانکار',
        TrsChequeState.cancelled =>
          'حساب‌های دریافتنی بدهکار | اسناد دریافتنی بستانکار',
        _ => 'اسناد دریافتنی بدهکار | اسناد در جریان وصول بستانکار',
      };
    }
    return switch (s) {
      TrsChequeState.cleared =>
        'اسناد پرداختنی بدهکار | بانک بستانکار — پول از حساب خارج می‌شود.',
      TrsChequeState.bounced =>
        'اسناد پرداختنی بدهکار | حساب‌های پرداختنی بستانکار — بدهی دوباره برقرار می‌شود.',
      TrsChequeState.cancelled =>
        'اسناد پرداختنی بدهکار | حساب‌های پرداختنی بستانکار',
      _ => '—',
    };
  }

  Future<void> _run() async {
    if (_needsBank && (_accountId ?? 0) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'حساب بانکی این عملیات را انتخاب کنید.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _repo.runChequeAction(
        chequeId: widget.cheque.id,
        status: _status,
        date: _date,
        trsAccountId: _accountId,
        description: _descCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('عملیات چک ثبت شد.', style: TextStyle(fontSize: 12)),
          backgroundColor: ShopColors.ok,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _TrsChequesPageState._clean(e),
            style: const TextStyle(fontSize: 12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cheque;
    final banks = widget.accounts.where((a) => a.kind == 1).toList();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: SingleChildScrollView(
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
                'عملیات چک',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ShopColors.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _row('چک شماره', Fa.number(int.tryParse(c.number) ?? 0)),
                        _row('مبلغ', '${Fa.number(c.amount)} ریال'),
                        _row(
                          'سررسید',
                          c.dueDate == null ? '—' : jalaliShort(c.dueDate!),
                        ),
                        _row('وضعیت فعلی', c.statusTitle),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_allowed.isEmpty)
                    const Text(
                      'این چک تعیین تکلیف نهایی شده است و عملیات جدید نمی‌پذیرد.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: ShopColors.danger,
                      ),
                    )
                  else ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in _allowed)
                          ChoiceChip(
                            label: Text(
                              _label(c.kind, t),
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: _status == t,
                            onSelected: (_) => setState(() => _status = t),
                            showCheckmark: false,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final d = await showJalaliDatePicker(
                          context,
                          initial: _date,
                          title: 'تاریخ عملیات',
                        );
                        if (d != null && mounted) setState(() => _date = d);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ShopColors.line),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              size: 15,
                              color: ShopColors.inkFaint,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'تاریخ عملیات: ${jalaliShort(_date)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_needsBank) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int?>(
                        initialValue: _accountId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'حساب بانکی *',
                          labelStyle: TextStyle(fontSize: 10.5),
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: ShopColors.ink,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('— انتخاب —'),
                          ),
                          for (final a in banks)
                            DropdownMenuItem<int?>(
                              value: a.id,
                              child: Text(a.displayName),
                            ),
                        ],
                        onChanged: (v) => setState(() => _accountId = v),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'توضیحات عملیات',
                        hintStyle: TextStyle(fontSize: 11.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ShopColors.indigo.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 15,
                            color: ShopColors.indigo,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _hint(c.kind, _status),
                              style: const TextStyle(
                                fontSize: 10,
                                color: ShopColors.indigo,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
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
                          onPressed: _saving || _allowed.isEmpty ? null : _run,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            backgroundColor: ShopColors.ok,
                          ),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text(
                            'ثبت عملیات',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Text(
          k,
          style: const TextStyle(fontSize: 10, color: ShopColors.inkFaint),
        ),
        const Spacer(),
        Text(
          v,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: ShopColors.ink,
          ),
        ),
      ],
    ),
  );
}

// ============================================================
//  پروندهٔ چک — تاریخچهٔ عملیات‌ها
// ============================================================

class _ChequeFileSheet extends StatelessWidget {
  const _ChequeFileSheet({required this.cheque});

  final TreasuryCheque cheque;

  @override
  Widget build(BuildContext context) {
    final c = cheque;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
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
              'پروندهٔ چک ${Fa.number(int.tryParse(c.number) ?? 0)}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: ShopColors.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _row('نوع', c.kindTitle),
                      _row('مبلغ', '${Fa.number(c.amount)} ریال'),
                      _row(
                        'تاریخ صدور',
                        c.issueDate == null ? '—' : jalaliShort(c.issueDate!),
                      ),
                      _row(
                        'سررسید',
                        c.dueDate == null ? '—' : jalaliShort(c.dueDate!),
                      ),
                      _row('طرف حساب', c.partyName ?? '—'),
                      _row(
                        'بانک',
                        [c.bankName, c.branchName]
                            .where((e) => (e ?? '').isNotEmpty)
                            .join(' — '),
                      ),
                      if ((c.sayadId ?? '').isNotEmpty)
                        _row('شناسه صیاد', c.sayadId!),
                      if ((c.accountNumber ?? '').isNotEmpty)
                        _row('شماره حساب', c.accountNumber!),
                      if ((c.ownerName ?? '').isNotEmpty)
                        _row('صاحب چک', c.ownerName!),
                      if ((c.trsVoucherNumber ?? 0) > 0)
                        _row(
                          'سند خزانه',
                          'شماره ${Fa.number(c.trsVoucherNumber!)}',
                        ),
                      if ((c.description ?? '').isNotEmpty)
                        _row('توضیحات', c.description!),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'تاریخچهٔ عملیات',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                if (c.actions.isEmpty)
                  const Text(
                    'هنوز عملیاتی روی این چک ثبت نشده است.',
                    style: TextStyle(
                      fontSize: 11,
                      color: ShopColors.inkFaint,
                    ),
                  )
                else
                  for (final a in c.actions)
                    Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: ShopColors.line),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 34,
                            decoration: BoxDecoration(
                              color: switch (a.status) {
                                2 => ShopColors.ok,
                                3 => ShopColors.danger,
                                4 || 5 => ShopColors.inkFaint,
                                _ => ShopColors.seed,
                              },
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.statusTitle,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  [
                                    if (a.date != null) jalaliShort(a.date!),
                                    if ((a.trsAccountName ?? '').isNotEmpty)
                                      a.trsAccountName!,
                                    if ((a.description ?? '').isNotEmpty)
                                      a.description!,
                                  ].join(' · '),
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    color: ShopColors.inkFaint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if ((a.voucherNumber ?? 0) > 0)
                            ShopTag(
                              text: 'سند ${Fa.number(a.voucherNumber!)}',
                              color: ShopColors.indigo,
                            ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(
          width: 88,
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
              color: ShopColors.ink,
            ),
          ),
        ),
      ],
    ),
  );
}

// ============================================================
//  فرم ثبت/ویرایش چک — آینهٔ مودال TrsCheques.razor
// ============================================================

class TrsChequeFormPage extends StatefulWidget {
  const TrsChequeFormPage({super.key, this.cheque, required this.accounts});

  final TreasuryCheque? cheque;
  final List<TreasuryAccount> accounts;

  @override
  State<TrsChequeFormPage> createState() => _TrsChequeFormPageState();
}

class _TrsChequeFormPageState extends State<TrsChequeFormPage> {
  late final ShopRepository _repo;
  final _number = TextEditingController();
  final _sayad = TextEditingController();
  final _amount = TextEditingController();
  final _bank = TextEditingController();
  final _branch = TextEditingController();
  final _accountNumber = TextEditingController();
  final _owner = TextEditingController();
  final _desc = TextEditingController();

  int _kind = ChequeKind.received;
  int? _accountId;
  DateTime _issue = DateTime.now();
  DateTime _due = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  bool get _isEdit => (widget.cheque?.id ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    final c = widget.cheque;
    if (c != null) {
      _number.text = c.number;
      _sayad.text = c.sayadId ?? '';
      _amount.text = c.amount == 0 ? '' : c.amount.toStringAsFixed(0);
      _bank.text = c.bankName ?? '';
      _branch.text = c.branchName ?? '';
      _accountNumber.text = c.accountNumber ?? '';
      _owner.text = c.ownerName ?? '';
      _desc.text = c.description ?? '';
      _kind = c.kind;
      _accountId = c.trsAccountId;
      _issue = c.issueDate ?? DateTime.now();
      _due = c.dueDate ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    for (final c in [
      _number,
      _sayad,
      _amount,
      _bank,
      _branch,
      _accountNumber,
      _owner,
      _desc,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String msg, {bool ok = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        backgroundColor: ok ? ShopColors.ok : null,
      ),
    );
  }

  Future<void> _save() async {
    if (_number.text.trim().isEmpty) {
      _toast('شماره چک را وارد کنید.');
      return;
    }
    if (parseNum(_amount.text) <= 0) {
      _toast('مبلغ چک باید بزرگ‌تر از صفر باشد.');
      return;
    }
    if (_kind == ChequeKind.issued && (_accountId ?? 0) <= 0) {
      _toast('برای چک صادره، حساب بانکی الزامی است.');
      return;
    }
    setState(() => _saving = true);
    try {
      final c = TreasuryCheque(
        id: widget.cheque?.id ?? 0,
        kind: _kind,
        number: _number.text.trim(),
        sayadId: _sayad.text.trim(),
        amount: parseNum(_amount.text),
        issueDate: _issue,
        dueDate: _due,
        bankName: _bank.text.trim(),
        branchName: _branch.text.trim(),
        accountNumber: _accountNumber.text.trim(),
        ownerName: _owner.text.trim(),
        partyId: widget.cheque?.partyId,
        trsAccountId: _accountId,
        status: widget.cheque?.status ?? 0,
        description: _desc.text.trim(),
      );
      await _repo.saveCheque(c);
      if (!mounted) return;
      _toast('چک ذخیره شد.', ok: true);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _toast(_TrsChequesPageState._clean(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final banks = widget.accounts.where((a) => a.kind == 1).toList();
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: Text(
          _isEdit ? 'ویرایش چک' : 'چک جدید',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: ShopColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ShopColors.line),
            ),
            child: Column(
              children: [
                ShopField(
                  label: 'نوع چک',
                  required: true,
                  child: DropdownButtonFormField<int>(
                    initialValue: _kind,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: ShopColors.ink,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: ChequeKind.received,
                        child: Text('چک دریافتی (از مشتری)'),
                      ),
                      DropdownMenuItem(
                        value: ChequeKind.issued,
                        child: Text('چک پرداختی (صادره)'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _kind = v ?? 0),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: ShopField(
                        label: 'شماره چک',
                        required: true,
                        child: TextField(
                          controller: _number,
                          style: const TextStyle(fontSize: 12.5),
                          decoration: const InputDecoration(isDense: true),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ShopField(
                        label: 'شناسه صیاد',
                        child: TextField(
                          controller: _sayad,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontSize: 12.5),
                          decoration: const InputDecoration(isDense: true),
                        ),
                      ),
                    ),
                  ],
                ),
                ShopField(
                  label: 'مبلغ چک (ریال)',
                  required: true,
                  child: TextField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: const InputDecoration(isDense: true),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: ShopField(
                        label: 'تاریخ صدور',
                        child: _dateBtn(_issue, (d) {
                          setState(() => _issue = d);
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ShopField(
                        label: 'تاریخ سررسید',
                        required: true,
                        child: _dateBtn(_due, (d) {
                          setState(() => _due = d);
                        }),
                      ),
                    ),
                  ],
                ),
                DropdownButtonFormField<int?>(
                  initialValue: _accountId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: _kind == ChequeKind.issued
                        ? 'حساب بانکی صادرکننده *'
                        : 'بانک واگذاری / وصول',
                    labelStyle: const TextStyle(fontSize: 10.5),
                  ),
                  style: const TextStyle(fontSize: 12, color: ShopColors.ink),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('— انتخاب —'),
                    ),
                    for (final a in banks)
                      DropdownMenuItem<int?>(
                        value: a.id,
                        child: Text(a.displayName),
                      ),
                  ],
                  onChanged: (v) => setState(() => _accountId = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ShopField(
                        label: 'بانک صادرکننده',
                        child: TextField(
                          controller: _bank,
                          style: const TextStyle(fontSize: 12.5),
                          decoration: const InputDecoration(isDense: true),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ShopField(
                        label: 'شعبه',
                        child: TextField(
                          controller: _branch,
                          style: const TextStyle(fontSize: 12.5),
                          decoration: const InputDecoration(isDense: true),
                        ),
                      ),
                    ),
                  ],
                ),
                ShopField(
                  label: 'شماره حساب',
                  child: TextField(
                    controller: _accountNumber,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: const InputDecoration(isDense: true),
                  ),
                ),
                ShopField(
                  label: 'نام صاحب چک',
                  hint: 'اگر با طرف حساب فرق دارد',
                  child: TextField(
                    controller: _owner,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: const InputDecoration(isDense: true),
                  ),
                ),
                ShopField(
                  label: 'توضیحات',
                  child: TextField(
                    controller: _desc,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: const InputDecoration(isDense: true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 46),
              backgroundColor: ShopColors.seed,
            ),
            icon: const Icon(Icons.save_rounded, size: 17),
            label: const Text(
              'ذخیره چک',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateBtn(DateTime value, ValueChanged<DateTime> onPick) => InkWell(
    onTap: () async {
      final d = await showJalaliDatePicker(
        context,
        initial: value,
        title: 'انتخاب تاریخ',
      );
      if (d != null) onPick(d);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
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
          Text(jalaliShort(value), style: const TextStyle(fontSize: 11.5)),
        ],
      ),
    ),
  );
}
