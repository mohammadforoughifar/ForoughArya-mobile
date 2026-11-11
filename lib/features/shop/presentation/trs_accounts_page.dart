// ============================================================
//  صندوق، بانک، کارتخوان و تنخواه (POS)
//  آینهٔ صفحهٔ وب: /trs/accounts → Pages/Treasury/TrsAccounts.razor
//
//  • فیلتر نوع حساب (همه/صندوق/بانک/کارتخوان/تنخواه)
//  • کارت هر حساب: مانده جاری، ورودی/خروجی، تعداد گردش، مشخصات بانکی
//  • فرم کامل: نوع، کد، ترتیب، نام، حساب حسابداری معین، مشخصات بانکی،
//    مانده ابتدای دوره، فعال/پیش‌فرض، توضیحات
//  • «گردش» → صفحهٔ گردش همان حساب (TrsFlow)
//  • حذف فقط با مجوز TrsAccounts.Delete — سرور هم می‌سنجد
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../data/fa_num.dart';
import '../data/shop_perms.dart';
import '../data/shop_repository.dart';
import '../models/treasury_models.dart';
import 'shop_style.dart';
import 'trs_flow_page.dart';

class TrsAccountsPage extends StatefulWidget {
  const TrsAccountsPage({super.key});

  @override
  State<TrsAccountsPage> createState() => _TrsAccountsPageState();
}

class _TrsAccountsPageState extends State<TrsAccountsPage> {
  late final ShopRepository _repo;
  late final ShopPerms _perms;

  List<TreasuryAccount> _items = const [];
  bool _loading = true;
  String? _error;
  int? _kindFilter;

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _perms = ShopPerms(context.read<AuthController>().session);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.treasuryAccounts();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  List<TreasuryAccount> get _filtered => _kindFilter == null
      ? _items
      : _items.where((a) => a.kind == _kindFilter).toList();

  Future<void> _openForm([TreasuryAccount? a]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TrsAccountFormPage(account: a)),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _delete(TreasuryAccount a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف صندوق/بانک', style: TextStyle(fontSize: 15)),
        content: Text('حساب «${a.name}» حذف شود؟', style: const TextStyle(fontSize: 13)),
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
      await _repo.deleteTreasuryAccount(a.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('حذف شد.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_cleanMsg(e))));
    }
  }

  static String _cleanMsg(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    final canWrite =
        _perms.has('TrsAccounts.Create') || _perms.hasModule('TrsAccounts');
    final canDelete = _perms.has('TrsAccounts.Delete');
    return Scaffold(
      backgroundColor: ShopColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            ShopHeader(
              title: 'بانک، صندوق و کارتخوان (POS)',
              subtitle: 'حساب‌های خزانه با مانده جاری و مشخصات بانکی',
              icon: Icons.account_balance_rounded,
              actions: [
                if (canWrite)
                  ShopHeaderButton(
                    label: 'حساب جدید',
                    icon: Icons.add_rounded,
                    filled: true,
                    onTap: () => _openForm(),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _chip(null, 'همه'),
                  _chip(0, 'صندوق'),
                  _chip(1, 'بانک'),
                  _chip(2, 'کارتخوان'),
                  _chip(3, 'تنخواه'),
                ],
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: ShopEmpty(
                  title: 'دریافت حساب‌ها ناموفق بود',
                  subtitle: _cleanMsg(_error!),
                  icon: Icons.error_outline_rounded,
                ),
              )
            else if (_filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: ShopEmpty(
                  title: 'حسابی ثبت نشده است',
                  subtitle: 'اولین صندوق یا حساب بانکی را ایجاد کنید.',
                  icon: Icons.account_balance_wallet_outlined,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Column(
                  children: [
                    for (final a in _filtered)
                      _card(a, canDelete: canDelete, canWrite: canWrite),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(int? kind, String label) {
    final selected = _kindFilter == kind;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11.5)),
      selected: selected,
      onSelected: (_) => setState(() => _kindFilter = kind),
      selectedColor: ShopColors.seed.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        fontSize: 11.5,
        color: selected ? ShopColors.seed : ShopColors.inkSoft,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected ? ShopColors.seed.withValues(alpha: 0.4) : ShopColors.line,
      ),
      backgroundColor: Colors.white,
      showCheckmark: false,
    );
  }

  Widget _card(
    TreasuryAccount a, {
    required bool canDelete,
    required bool canWrite,
  }) {
    final color = switch (a.kind) {
      0 => ShopColors.ok,
      1 => ShopColors.seed,
      2 => ShopColors.indigo,
      _ => ShopColors.warn,
    };
    final icon = switch (a.kind) {
      0 => Icons.point_of_sale_rounded,
      1 => Icons.account_balance_rounded,
      2 => Icons.credit_card_rounded,
      _ => Icons.wallet_rounded,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: color),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            a.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (a.isDefault) ...[
                          const SizedBox(width: 5),
                          const ShopTag(
                            text: 'پیش‌فرض',
                            color: ShopColors.seed,
                            icon: Icons.star_rounded,
                          ),
                        ],
                        if (!a.isActive) ...[
                          const SizedBox(width: 5),
                          const ShopTag(
                            text: 'غیرفعال',
                            color: ShopColors.inkFaint,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${a.kindTitle}${a.code.isEmpty ? '' : ' · کد ${a.code}'}',
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
                    Fa.number(a.balance),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: a.balance < 0 ? ShopColors.danger : ShopColors.ink,
                    ),
                  ),
                  const Text(
                    'ریال مانده',
                    style: TextStyle(fontSize: 9, color: ShopColors.inkFaint),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            decoration: BoxDecoration(
              color: ShopColors.bg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _miniStat(
                    'ورودی',
                    Fa.number(a.totalIn),
                    ShopColors.ok,
                  ),
                ),
                Expanded(
                  child: _miniStat(
                    'خروجی',
                    Fa.number(a.totalOut),
                    ShopColors.danger,
                  ),
                ),
                Expanded(
                  child: _miniStat(
                    'گردش',
                    Fa.number(a.moveCount),
                    ShopColors.inkSoft,
                  ),
                ),
                Expanded(
                  child: _miniStat(
                    'اول دوره',
                    Fa.number(a.openingBalance),
                    ShopColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          if ((a.bankName ?? '').isNotEmpty ||
              (a.accountNumber ?? '').isNotEmpty ||
              (a.iban ?? '').isNotEmpty ||
              (a.cardNumber ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if ((a.bankName ?? '').isNotEmpty)
                  _kv('بانک', a.bankName!),
                if ((a.branchName ?? '').isNotEmpty)
                  _kv('شعبه', a.branchName!),
                if ((a.accountNumber ?? '').isNotEmpty)
                  _kv('حساب', a.accountNumber!),
                if ((a.iban ?? '').isNotEmpty) _kv('شبا', 'IR${a.iban}'),
                if ((a.cardNumber ?? '').isNotEmpty)
                  _kv('کارت', a.cardNumber!),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            a.hasAccounting
                ? 'حساب حسابداری: ${a.accountCode ?? ''} — ${a.accountName ?? ''}'
                : 'حساب حسابداری متصل نشده — سند خودکار صادر نمی‌شود',
            style: TextStyle(
              fontSize: 10,
              color: a.hasAccounting ? ShopColors.inkFaint : ShopColors.danger,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TrsFlowPage(account: a),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    side: const BorderSide(color: ShopColors.line),
                    foregroundColor: ShopColors.seed,
                  ),
                  icon: const Icon(Icons.list_alt_rounded, size: 15),
                  label: const Text('گردش', style: TextStyle(fontSize: 11.5)),
                ),
              ),
              if (canWrite) ...[
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => _openForm(a),
                  style: IconButton.styleFrom(
                    backgroundColor: ShopColors.bg,
                    minimumSize: const Size(38, 38),
                  ),
                  icon: const Icon(
                    Icons.edit_rounded,
                    size: 16,
                    color: ShopColors.inkSoft,
                  ),
                ),
              ],
              if (canDelete) ...[
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => _delete(a),
                  style: IconButton.styleFrom(
                    backgroundColor: ShopColors.danger.withValues(alpha: 0.08),
                    minimumSize: const Size(38, 38),
                  ),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: ShopColors.danger,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 8.5, color: ShopColors.inkFaint),
      ),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    ],
  );

  Widget _kv(String k, String v) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$k: ',
        style: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
      ),
      Text(
        v,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: ShopColors.inkSoft,
        ),
      ),
    ],
  );
}

// ============================================================
//  فرم ایجاد/ویرایش صندوق/بانک — آینهٔ مودال TrsAccounts.razor
// ============================================================

class TrsAccountFormPage extends StatefulWidget {
  const TrsAccountFormPage({super.key, this.account});

  final TreasuryAccount? account;

  @override
  State<TrsAccountFormPage> createState() => _TrsAccountFormPageState();
}

class _TrsAccountFormPageState extends State<TrsAccountFormPage> {
  late final ShopRepository _repo;
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _sort = TextEditingController();
  final _bank = TextEditingController();
  final _branch = TextEditingController();
  final _branchCode = TextEditingController();
  final _accountNumber = TextEditingController();
  final _iban = TextEditingController();
  final _card = TextEditingController();
  final _opening = TextEditingController();
  final _desc = TextEditingController();

  int _kind = 0;
  int? _accountId;
  String? _accountName;
  bool _isActive = true;
  bool _isDefault = false;
  bool _saving = false;
  List<AccLookup> _accLookups = const [];

  bool get _isEdit => (widget.account?.id ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    final a = widget.account;
    if (a != null) {
      _name.text = a.name;
      _code.text = a.code;
      _sort.text = a.sortOrder == 0 ? '' : a.sortOrder.toString();
      _bank.text = a.bankName ?? '';
      _branch.text = a.branchName ?? '';
      _branchCode.text = a.branchCode ?? '';
      _accountNumber.text = a.accountNumber ?? '';
      _iban.text = a.iban ?? '';
      _card.text = a.cardNumber ?? '';
      _opening.text = a.openingBalance == 0
          ? ''
          : a.openingBalance.toStringAsFixed(0);
      _desc.text = a.description ?? '';
      _kind = a.kind;
      _accountId = a.accountId;
      _accountName = a.accountName;
      _isActive = a.isActive;
      _isDefault = a.isDefault;
    } else {
      _sort.text = '';
    }
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    try {
      final list = await _repo.accAccountLookups();
      if (!mounted) return;
      setState(() => _accLookups = list);
    } catch (_) {}
  }

  Future<void> _pickAccount() async {
    final picked = await showModalBottomSheet<AccLookup>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AccPickSheet(items: _accLookups),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _accountId = picked.id;
      _accountName = picked.name;
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _toast('نام صندوق/بانک الزامی است.');
      return;
    }
    if (_kind == 1 && _bank.text.trim().isEmpty) {
      _toast('برای حساب بانکی، نام بانک الزامی است.');
      return;
    }
    setState(() => _saving = true);
    try {
      final a = TreasuryAccount(
        id: widget.account?.id ?? 0,
        code: _code.text.trim(),
        name: _name.text.trim(),
        kind: _kind,
        accountId: _accountId,
        bankName: _bank.text.trim(),
        branchName: _branch.text.trim(),
        branchCode: _branchCode.text.trim(),
        accountNumber: _accountNumber.text.trim(),
        iban: _iban.text.trim(),
        cardNumber: _card.text.trim(),
        openingBalance: parseNum(_opening.text),
        isDefault: _isDefault,
        isActive: _isActive,
        description: _desc.text.trim(),
        sortOrder: int.tryParse(toEnDigits(_sort.text).trim()) ?? 0,
      );
      await _repo.saveTreasuryAccount(a);
      if (!mounted) return;
      _toast('صندوق/بانک ذخیره شد.', ok: true);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _toast(_TrsAccountsPageState._cleanMsg(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg, {bool ok = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        backgroundColor: ok ? ShopColors.ok : null,
      ),
    );
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _code,
      _sort,
      _bank,
      _branch,
      _branchCode,
      _accountNumber,
      _iban,
      _card,
      _opening,
      _desc,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showBank = _kind == 1 || _kind == 2;
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: Text(
          _isEdit ? 'ویرایش صندوق / بانک' : 'صندوق / بانک جدید',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
        children: [
          _formCard([
            ShopField(
              label: 'نوع',
              required: true,
              child: DropdownButtonFormField<int>(
                initialValue: _kind,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                style: const TextStyle(fontSize: 12.5, color: ShopColors.ink),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('صندوق')),
                  DropdownMenuItem(value: 1, child: Text('بانک')),
                  DropdownMenuItem(value: 2, child: Text('کارتخوان')),
                  DropdownMenuItem(value: 3, child: Text('تنخواه‌گردان')),
                ],
                onChanged: (v) => setState(() => _kind = v ?? 0),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ShopField(
                    label: 'کد',
                    hint: 'خودکار',
                    child: TextField(
                      controller: _code,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: const InputDecoration(isDense: true),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ShopField(
                    label: 'ترتیب نمایش',
                    child: TextField(
                      controller: _sort,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: const InputDecoration(isDense: true),
                    ),
                  ),
                ),
              ],
            ),
            ShopField(
              label: 'نام',
              required: true,
              hint: 'مثلاً صندوق مرکزی',
              child: TextField(
                controller: _name,
                style: const TextStyle(fontSize: 12.5),
                decoration: const InputDecoration(isDense: true),
              ),
            ),
            ShopField(
              label: 'حساب حسابداری متناظر',
              hint: 'برای صدور سند خودکار الزامی است',
              child: InkWell(
                onTap: _pickAccount,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: ShopColors.line),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _accountName ?? 'انتخاب حساب…',
                          style: TextStyle(
                            fontSize: 12,
                            color: _accountName == null
                                ? ShopColors.inkFaint
                                : ShopColors.ink,
                          ),
                        ),
                      ),
                      if (_accountId != null)
                        InkWell(
                          onTap: () => setState(() {
                            _accountId = null;
                            _accountName = null;
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
          ]),
          if (showBank) ...[
            const SizedBox(height: 10),
            _formCard([
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'مشخصات بانکی',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: ShopColors.inkSoft,
                  ),
                ),
              ),
              ShopField(
                label: 'نام بانک',
                required: _kind == 1,
                hint: 'مثلاً بانک ملت',
                child: TextField(
                  controller: _bank,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: const InputDecoration(isDense: true),
                ),
              ),
              Row(
                children: [
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: ShopField(
                      label: 'کد شعبه',
                      child: TextField(
                        controller: _branchCode,
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
                label: 'شبا (بدون IR)',
                child: TextField(
                  controller: _iban,
                  textDirection: TextDirection.ltr,
                  maxLength: 24,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: const InputDecoration(
                    isDense: true,
                    counterText: '',
                  ),
                ),
              ),
              ShopField(
                label: 'شماره کارت',
                child: TextField(
                  controller: _card,
                  textDirection: TextDirection.ltr,
                  maxLength: 19,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: const InputDecoration(
                    isDense: true,
                    counterText: '',
                  ),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 10),
          _formCard([
            ShopField(
              label: 'مانده ابتدای دوره (ریال)',
              child: TextField(
                controller: _opening,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 12.5),
                decoration: const InputDecoration(isDense: true),
              ),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              title: const Text(
                'فعال',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
              title: const Text(
                'حساب پیش‌فرض دریافت و پرداخت',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
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
          ]),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    side: const BorderSide(color: ShopColors.line),
                    foregroundColor: ShopColors.inkSoft,
                  ),
                  child: const Text('انصراف', style: TextStyle(fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    backgroundColor: ShopColors.seed,
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 17),
                  label: const Text(
                    'ذخیره',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formCard(List<Widget> children) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(children: children),
  );
}

/// انتخاب حساب معین حسابداری (جایگزین SearchSelect وب)
class _AccPickSheet extends StatefulWidget {
  const _AccPickSheet({required this.items});

  final List<AccLookup> items;

  @override
  State<_AccPickSheet> createState() => _AccPickSheetState();
}

class _AccPickSheetState extends State<_AccPickSheet> {
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
              .where((e) => e.name.toLowerCase().contains(q))
              .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
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
              'انتخاب حساب حسابداری',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'جستجوی کد یا نام حساب…',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _q.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => setState(_q.clear),
                        icon: const Icon(Icons.close_rounded, size: 16),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text(
                      'حسابی یافت نشد',
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
                      onTap: () => Navigator.pop(context, list[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
