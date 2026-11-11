// ============================================================
//  اسناد دریافت و پرداخت (تسویه فاکتورها)
//  آینهٔ صفحهٔ وب: /trs/vouchers → Pages/Treasury/TrsVouchers.razor
//
//  • سه دکمهٔ بالای صفحه: انتقال وجه / پرداخت / دریافت (عیناً وب)
//  • تب نوع سند + فیلتر جستجو/وضعیت/صندوق‌وبانک/بازهٔ شمسی + پاک کردن
//  • هر سطر: شماره، نوع، تاریخ، طرف حساب یا مسیر انتقال، فاکتورهای مرتبط،
//    شرح، نقد، چک، جمع، وضعیت، شماره سند حسابداری
//  • عملیات: ویرایش · قطعی · برگشت از قطعی · ابطال · حذف
//    (قطعی/حذف فقط در پیش‌نویس، برگشت و ابطال فقط در قطعی — قاعدهٔ وب)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/shop_perms.dart';
import '../data/shop_repository.dart';
import '../models/treasury_models.dart';
import 'shop_style.dart';
import 'trs_voucher_form_page.dart';

class TrsVouchersPage extends StatefulWidget {
  const TrsVouchersPage({super.key});

  @override
  State<TrsVouchersPage> createState() => _TrsVouchersPageState();
}

class _TrsVouchersPageState extends State<TrsVouchersPage> {
  late final ShopRepository _repo;
  late final ShopPerms _perms;

  List<TreasuryVoucher> _items = const [];
  List<TreasuryAccount> _accounts = const [];
  bool _loading = true;
  String? _error;

  int? _kind;
  int? _status;
  int? _accountId;
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
      final res = await _repo.treasuryVouchers(
        kind: _kind,
        status: _status,
        trsAccountId: _accountId,
        search: _searchCtrl.text,
        from: _from,
        to: _to,
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
      _accountId = null;
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

  Future<void> _openForm({int kind = TrsKind.receipt, int? id}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TrsVoucherFormPage(kind: kind, voucherId: id),
      ),
    );
    if (changed == true && mounted) _load();
  }

  Future<void> _action(
    TreasuryVoucher v,
    String label,
    Future<void> Function() run,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label, style: const TextStyle(fontSize: 15)),
        content: Text(
          '$label برای سند شماره ${Fa.number(v.number)}؟',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأیید'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await run();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label انجام شد.', style: const TextStyle(fontSize: 12)),
          backgroundColor: ShopColors.ok,
        ),
      );
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
    final canCreate =
        _perms.has('TrsVouchers.Create') || _perms.hasModule('TrsVouchers');
    final canConfirm = _perms.has('TrsVouchers.Confirm');
    final canCancel = _perms.has('TrsVouchers.Cancel');
    final canDelete = _perms.has('TrsVouchers.Delete');
    return Scaffold(
      backgroundColor: ShopColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            ShopHeader(
              title: 'اسناد دریافت و پرداخت',
              subtitle: 'دریافت از مشتری، پرداخت به تأمین‌کننده و انتقال بین حساب‌ها',
              icon: Icons.receipt_long_rounded,
              actions: [
                if (canCreate) ...[
                  ShopHeaderButton(
                    label: 'دریافت',
                    icon: Icons.south_west_rounded,
                    filled: true,
                    onTap: () => _openForm(kind: TrsKind.receipt),
                  ),
                ],
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _quickBtn(
                      'انتقال وجه',
                      Icons.swap_horiz_rounded,
                      ShopColors.inkSoft,
                      canCreate
                          ? () => _openForm(kind: TrsKind.transfer)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _quickBtn(
                      'پرداخت',
                      Icons.north_east_rounded,
                      ShopColors.danger,
                      canCreate
                          ? () => _openForm(kind: TrsKind.payment)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _quickBtn(
                      'دریافت',
                      Icons.south_west_rounded,
                      ShopColors.ok,
                      canCreate
                          ? () => _openForm(kind: TrsKind.receipt)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ShopSegmented(
                labels: const ['همه', 'دریافت', 'پرداخت', 'انتقال'],
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
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'شماره، شرح یا طرف حساب…',
                        hintStyle: const TextStyle(fontSize: 12),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
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
                              fontSize: 12,
                              color: ShopColors.ink,
                            ),
                            items: const [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text('همه'),
                              ),
                              DropdownMenuItem<int?>(
                                value: TrsState.draft,
                                child: Text('پیش‌نویس'),
                              ),
                              DropdownMenuItem<int?>(
                                value: TrsState.confirmed,
                                child: Text('قطعی'),
                              ),
                              DropdownMenuItem<int?>(
                                value: TrsState.cancelled,
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
                          child: DropdownButtonFormField<int?>(
                            initialValue: _accountId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'صندوق/بانک',
                              labelStyle: TextStyle(fontSize: 10.5),
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: ShopColors.ink,
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('همه'),
                              ),
                              for (final a in _accounts)
                                DropdownMenuItem<int?>(
                                  value: a.id,
                                  child: Text(a.name),
                                ),
                            ],
                            onChanged: (v) {
                              setState(() {
                                _accountId = v;
                                _page = 1;
                              });
                              _load();
                            },
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
                          tooltip: 'پاک کردن فیلترها',
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
                  title: 'دریافت اسناد ناموفق بود',
                  subtitle: _error,
                  icon: Icons.error_outline_rounded,
                ),
              )
            else if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 50),
                child: ShopEmpty(
                  title: 'سندی یافت نشد',
                  subtitle: 'اولین سند دریافت یا پرداخت را ثبت کنید.',
                  icon: Icons.payments_rounded,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Column(
                  children: [
                    for (final v in _items)
                      _voucherCard(
                        v,
                        canConfirm: canConfirm,
                        canCancel: canCancel,
                        canDelete: canDelete,
                        canEdit: canCreate,
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: _page <= 1
                              ? null
                              : () {
                                  setState(() => _page--);
                                  _load();
                                },
                          icon: const Icon(Icons.chevron_right_rounded),
                          label: const Text(
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
                        TextButton.icon(
                          onPressed: _items.length < _pageSize
                              ? null
                              : () {
                                  setState(() => _page++);
                                  _load();
                                },
                          icon: const Icon(Icons.chevron_left_rounded),
                          label: const Text(
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

  Widget _quickBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback? onTap,
  ) => OutlinedButton.icon(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 44),
      foregroundColor: color,
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      backgroundColor: color.withValues(alpha: 0.05),
      padding: const EdgeInsets.symmetric(horizontal: 6),
    ),
    icon: Icon(icon, size: 15),
    label: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
      ),
    ),
  );

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

  Widget _voucherCard(
    TreasuryVoucher v, {
    required bool canConfirm,
    required bool canCancel,
    required bool canDelete,
    required bool canEdit,
  }) {
    final color = switch (v.kind) {
      TrsKind.receipt => ShopColors.ok,
      TrsKind.payment => ShopColors.danger,
      _ => ShopColors.inkSoft,
    };
    final icon = switch (v.kind) {
      TrsKind.receipt => Icons.south_west_rounded,
      TrsKind.payment => Icons.north_east_rounded,
      _ => Icons.swap_horiz_rounded,
    };
    final statusColor = switch (v.status) {
      TrsState.draft => ShopColors.warn,
      TrsState.confirmed => ShopColors.ok,
      _ => ShopColors.inkFaint,
    };
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
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${TrsKind.title(v.kind)} شماره ${Fa.number(v.number)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      v.date == null ? '—' : jalaliShort(v.date!),
                      style: const TextStyle(
                        fontSize: 10,
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
                    Fa.number(v.totalAmount),
                    style: TextStyle(
                      fontSize: 13.5,
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
                  v.isTransfer ? 'مسیر' : 'طرف حساب',
                  v.isTransfer
                      ? '${v.fromAccountName ?? '—'} ← ${v.toAccountName ?? '—'}'
                      : (v.partyName ?? '—'),
                ),
                if (v.invoiceAllocations.isNotEmpty)
                  _line(
                    'فاکتور',
                    v.invoiceAllocations.length == 1
                        ? '#${Fa.number(v.invoiceAllocations.first.invoiceNumber)} · '
                              '${Fa.number(v.invoiceAllocations.first.amount)} ریال'
                        : '${Fa.number(v.invoiceAllocations.length)} فاکتور · '
                              '${Fa.number(v.invoiceAllocations.fold<double>(0, (s, a) => s + a.amount))} ریال',
                  ),
                if ((v.description ?? '').isNotEmpty)
                  _line('شرح', v.description!),
                _line(
                  'نقد / چک',
                  '${v.cashAmount == 0 ? '—' : Fa.number(v.cashAmount)} / '
                      '${v.chequeAmount == 0 ? '—' : Fa.number(v.chequeAmount)}',
                ),
                if ((v.voucherNumber ?? 0) > 0)
                  _line('سند حسابداری', Fa.number(v.voucherNumber!)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ShopTag(text: v.statusTitle, color: statusColor),
              const Spacer(),
              if (v.isEditable && canEdit)
                TextButton.icon(
                  onPressed: () => _openForm(kind: v.kind, id: v.id),
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: const Text('ویرایش', style: TextStyle(fontSize: 11)),
                ),
              if (v.isEditable && canConfirm)
                TextButton.icon(
                  onPressed: () => _action(
                    v,
                    'قطعی کردن',
                    () => _repo.confirmVoucher(v.id),
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                  label: const Text('قطعی', style: TextStyle(fontSize: 11)),
                ),
              if (v.isEditable && canDelete)
                TextButton.icon(
                  onPressed: () => _action(
                    v,
                    'حذف',
                    () => _repo.deleteVoucher(v.id),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: ShopColors.danger,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 14),
                  label: const Text('حذف', style: TextStyle(fontSize: 11)),
                ),
              if (v.isConfirmed && canConfirm)
                TextButton.icon(
                  onPressed: () => _action(
                    v,
                    'برگشت از قطعی',
                    () => _repo.unconfirmVoucher(v.id),
                  ),
                  icon: const Icon(Icons.undo_rounded, size: 14),
                  label: const Text('برگشت', style: TextStyle(fontSize: 11)),
                ),
              if (v.isConfirmed && canCancel)
                TextButton.icon(
                  onPressed: () => _action(
                    v,
                    'ابطال',
                    () => _repo.cancelVoucher(v.id),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: ShopColors.danger,
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 14),
                  label: const Text('ابطال', style: TextStyle(fontSize: 11)),
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
          width: 78,
          child: Text(
            label,
            style: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
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
