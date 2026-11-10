// ============================================================
//  هزینه‌ها + انواع هزینه
//  آینهٔ صفحهٔ وب: /expenses → Pages/Finance/Expenses.razor
//
//  • فهرست با جستجو/فیلتر نوع/بازهٔ شمسی، صفحه‌بندی ۱۵تایی و «جمع صفحه»
//  • فرم سند: نوع هزینه* (+ تعریف نوع جدید) · مبلغ* · تاریخ* ·
//    نحوه پرداخت (نقد/کارت‌خوان/کارت به کارت) · صندوق/بانک (+ «تعریف بانک»)
//    · دریافت‌کننده · توضیحات
//  • مدیریت انواع هزینه: افزودن/ویرایش نام، فعال‌سازی، حذف
//  ⚠️ همان پیام‌های وب: «نوع هزینه را انتخاب کنید.» و «مبلغ هزینه را وارد کنید.»
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/fa_num.dart';
import '../data/shop_repository.dart';
import '../models/ops_models.dart';
import '../models/order_models.dart';
import 'order_form_page.dart' show QuickBankSheet;
import 'shop_style.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  late final ShopRepository _repo;
  static const pageSize = 15;

  int _page = 1;
  int _total = 0;
  List<ShopExpense> _items = const [];
  List<ExpenseCategory> _categories = const [];
  List<TrsAccount> _accounts = const [];

  int? _categoryId;
  DateTime? _from;
  DateTime? _to;
  final _search = TextEditingController();

  bool _loading = true;
  String? _error;

  int get _pageCount => _total <= 0 ? 1 : ((_total + pageSize - 1) ~/ pageSize);

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _loadCats();
    _loadAccounts();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCats() async {
    try {
      final list = await _repo.expenseCategories();
      if (!mounted) return;
      setState(() => _categories = list);
    } catch (_) {}
  }

  Future<void> _loadAccounts() async {
    try {
      final list = await _repo.trsAccounts();
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
      final res = await _repo.expenses(
        search: _search.text,
        categoryId: _categoryId,
        from: _from,
        to: _to,
        page: _page,
        pageSize: pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _total = res.total ?? res.items.length;
        if (_page > _pageCount) _page = _pageCount;
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

  Future<void> _pickDate({required bool isFrom}) async {
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
    });
  }

  // ---------------- فرم ----------------
  Future<void> _openForm([ShopExpense? source]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpenseFormSheet(
        repo: _repo,
        categories: _categories,
        accounts: _accounts,
        source: source,
        onAccountCreated: (a) {
          setState(() => _accounts = [..._accounts, a]);
        },
        onCategoryCreated: _loadCats,
      ),
    );
    if (saved == true) {
      await _loadCats();
      _load();
    }
  }

  Future<void> _openCats() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoriesSheet(repo: _repo, items: _categories),
    );
    await _loadCats();
    _load();
  }

  Future<void> _delete(ShopExpense e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(
          'آیا از حذف سند «${e.number}» مطمئن هستید؟',
          style: const TextStyle(fontSize: 12.5, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ShopColors.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('تأیید'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteExpense(e.id);
      _toast('سند هزینه حذف شد.', ok: true);
      await _loadCats();
      _load();
    } catch (err) {
      _toast(err.toString());
    }
  }

  static String payLabel(int t) => switch (t) {
    CashKind.cardReader => 'کارت‌خوان',
    CashKind.cardTransfer => 'کارت به کارت',
    _ => 'نقد',
  };

  @override
  Widget build(BuildContext context) {
    final pageSum = _items.fold<double>(0, (s, e) => s + e.amount);
    return Scaffold(
      backgroundColor: ShopColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ShopHeader(
                title: 'هزینه‌ها',
                subtitle: 'ثبت اسناد هزینه با نوع، مبلغ و نحوه پرداخت',
                icon: Icons.payments_rounded,
                badge: '${Fa.number(_total)} سند',
                actions: [
                  ShopHeaderButton(
                    label: 'انواع هزینه',
                    icon: Icons.sell_rounded,
                    onTap: _openCats,
                  ),
                  ShopHeaderButton(
                    label: 'هزینه جدید',
                    icon: Icons.add_rounded,
                    filled: true,
                    onTap: () => _openForm(),
                  ),
                ],
              ),
            ),
            // ---------- فیلترها ----------
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ShopColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ShopColors.line),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _search,
                        onSubmitted: (_) {
                          _page = 1;
                          _load();
                        },
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'شماره سند، دریافت‌کننده، توضیحات…',
                          hintStyle: TextStyle(
                            fontSize: 11.5,
                            color: ShopColors.inkFaint,
                          ),
                          prefixIcon: Icon(Icons.search_rounded, size: 18),
                        ),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int?>(
                        initialValue: _categoryId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'نوع هزینه',
                          labelStyle: TextStyle(fontSize: 11.5),
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: ShopColors.ink,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('همه انواع هزینه'),
                          ),
                          for (final c in _categories)
                            DropdownMenuItem<int?>(
                              value: c.id,
                              child: Text(c.name),
                            ),
                        ],
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _dateBox(
                              'از تاریخ',
                              _from,
                              () => _pickDate(isFrom: true),
                              () => setState(() => _from = null),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _dateBox(
                              'تا تاریخ',
                              _to,
                              () => _pickDate(isFrom: false),
                              () => setState(() => _to = null),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            _page = 1;
                            _load();
                          },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            backgroundColor: ShopColors.seed,
                          ),
                          icon: const Icon(Icons.filter_alt_rounded, size: 17),
                          label: const Text(
                            'اعمال فیلتر',
                            style: TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
                child: ShopEmpty(
                  title: 'اسناد هزینه دریافت نشد',
                  subtitle: _error,
                  icon: Icons.error_outline_rounded,
                ),
              )
            else if (_items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: ShopEmpty(
                  title: 'سند هزینه‌ای یافت نشد',
                  subtitle: 'با «هزینه جدید» اولین سند را ثبت کنید.',
                  icon: Icons.payments_rounded,
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                sliver: SliverList.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _card(_items[i]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                sliver: SliverToBoxAdapter(
                  child: _pager(pageSum),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card(ShopExpense e) {
    return Container(
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
                e.number,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.seed,
                ),
              ),
              const SizedBox(width: 6),
              ShopTag(
                text: e.categoryName ?? '—',
                color: ShopColors.warn,
              ),
              const Spacer(),
              Text(
                Fa.date(e.date?.toIso8601String(), time: false),
                style: const TextStyle(
                  fontSize: 10.5,
                  color: ShopColors.inkFaint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((e.payee ?? '').trim().isNotEmpty)
                      Text(
                        e.payee!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    Text(
                      '${payLabel(e.payType)}'
                      '${(e.trsAccountName ?? '').trim().isEmpty ? '' : ' — ${e.trsAccountName}'}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: ShopColors.inkSoft,
                      ),
                    ),
                    if ((e.description ?? '').trim().isNotEmpty)
                      Text(
                        e.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${Fa.number(e.amount)} ریال',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.danger,
                ),
              ),
            ],
          ),
          const Divider(height: 12, color: ShopColors.line),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _openForm(e),
                  icon: const Icon(Icons.edit_rounded, size: 15),
                  label: const Text(
                    'ویرایش',
                    style: TextStyle(fontSize: 11),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: ShopColors.seed,
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _delete(e),
                  icon: const Icon(Icons.delete_outline_rounded, size: 15),
                  label: const Text(
                    'حذف',
                    style: TextStyle(fontSize: 11),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: ShopColors.danger,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pager(double pageSum) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'جمع صفحه: ',
                style: TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
              ),
              Text(
                '${Fa.number(pageSum)} ریال',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: ShopColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _page > 1
                    ? () {
                        _page--;
                        _load();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
              ),
              Text(
                'صفحه ${Fa.number(_page)} از ${Fa.number(_pageCount)}',
                style: const TextStyle(fontSize: 11),
              ),
              IconButton(
                onPressed: _page < _pageCount
                    ? () {
                        _page++;
                        _load();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateBox(
    String label,
    DateTime? value,
    VoidCallback onTap,
    VoidCallback onClear,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ShopColors.line),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: 15,
              color: ShopColors.inkFaint,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                value == null ? label : jalaliShort(value),
                style: TextStyle(
                  fontSize: 11.5,
                  color: value == null ? ShopColors.inkFaint : ShopColors.ink,
                ),
              ),
            ),
            if (value != null)
              InkWell(
                onTap: onClear,
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: ShopColors.inkFaint,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  فرم سند هزینه
// ============================================================
class _ExpenseFormSheet extends StatefulWidget {
  const _ExpenseFormSheet({
    required this.repo,
    required this.categories,
    required this.accounts,
    required this.onAccountCreated,
    required this.onCategoryCreated,
    this.source,
  });

  final ShopRepository repo;
  final List<ExpenseCategory> categories;
  final List<TrsAccount> accounts;
  final void Function(TrsAccount) onAccountCreated;
  final Future<void> Function() onCategoryCreated;
  final ShopExpense? source;

  @override
  State<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<_ExpenseFormSheet> {
  late List<ExpenseCategory> _cats;
  late List<TrsAccount> _accounts;

  int _catId = 0;
  final _amount = TextEditingController();
  DateTime? _date;
  int _payType = CashKind.cash;
  int? _trsAccountId;
  final _payee = TextEditingController();
  final _desc = TextEditingController();
  bool _saving = false;

  bool get _isEdit => (widget.source?.id ?? 0) > 0;

  /// همان فیلتر وب: حساب‌های مجاز هر نحوهٔ پرداخت
  List<TrsAccount> get _accountsForPayType => switch (_payType) {
    CashKind.cash => _accounts
        .where(
          (a) => a.kind == AccountKind.cash || a.kind == AccountKind.pettyCash,
        )
        .toList(),
    CashKind.cardReader => _accounts
        .where((a) => a.kind == AccountKind.pos || a.kind == AccountKind.bank)
        .toList(),
    _ => _accounts
        .where((a) => a.kind == AccountKind.bank || a.kind == AccountKind.pos)
        .toList(),
  };

  @override
  void initState() {
    super.initState();
    _cats = widget.categories;
    _accounts = widget.accounts;
    final s = widget.source;
    if (s != null) {
      _catId = s.categoryId;
      _amount.text = formatNumText(s.amount.toStringAsFixed(0));
      _date = s.date ?? DateTime.now();
      _payType = s.payType;
      _trsAccountId = s.trsAccountId;
      _payee.text = s.payee ?? '';
      _desc.text = s.description ?? '';
    } else {
      _date = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _payee.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12.5)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ShopColors.danger,
      ),
    );
  }

  Future<void> _save() async {
    // همان اعتبارسنجی‌های وب با همان متن‌ها
    if (_catId <= 0) {
      _toast('نوع هزینه را انتخاب کنید.');
      return;
    }
    final amount = parseNum(_amount.text);
    if (amount <= 0) {
      _toast('مبلغ هزینه را وارد کنید.');
      return;
    }
    setState(() => _saving = true);
    final accName = _accounts
        .where((a) => a.id == _trsAccountId)
        .map((a) => a.displayName)
        .firstOrNull;
    try {
      await widget.repo.saveExpense(
        ShopExpense(
          id: widget.source?.id ?? 0,
          number: widget.source?.number ?? '',
          categoryId: _catId,
          amount: amount,
          date: _date ?? DateTime.now(),
          payType: _payType,
          trsAccountId: _trsAccountId,
          trsAccountName: accName,
          payee: _payee.text.trim().isEmpty ? null : _payee.text.trim(),
          description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.toString());
    }
  }

  Future<void> _newBank() async {
    final created = await showModalBottomSheet<TrsAccount>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickBankSheet(repo: widget.repo),
    );
    if (created == null || !mounted) return;
    setState(() {
      _accounts = [..._accounts, created];
      _trsAccountId = created.id;
    });
    widget.onAccountCreated(created);
  }

  Future<void> _newCategory() async {
    final created = await showDialog<ExpenseCategory>(
      context: context,
      builder: (_) => _CategoryDialog(repo: widget.repo),
    );
    if (created == null || !mounted) return;
    setState(() {
      _cats = [..._cats, created];
      _catId = created.id;
    });
    await widget.onCategoryCreated();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEdit ? 'ویرایش سند ${widget.source!.number}' : 'هزینه جدید',
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
            ShopField(
              label: 'نوع هزینه',
              required: true,
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _catId == 0 ? null : _catId,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true),
                      hint: const Text(
                        '— انتخاب کنید —',
                        style: TextStyle(fontSize: 11.5),
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: ShopColors.ink,
                      ),
                      items: [
                        for (final c in _cats.where(
                          (c) => c.isActive || c.id == _catId,
                        ))
                          DropdownMenuItem<int>(
                            value: c.id,
                            child: Text(c.name),
                          ),
                      ],
                      onChanged: (v) => setState(() => _catId = v ?? 0),
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton(
                    onPressed: _newCategory,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: ShopColors.seed,
                      side: const BorderSide(color: ShopColors.line),
                    ),
                    child: const Icon(Icons.add_rounded, size: 18),
                  ),
                ],
              ),
            ),
            ShopField(
              label: 'مبلغ (ریال)',
              required: true,
              child: TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                onChanged: (v) {
                  final f = formatNumText(v);
                  if (f != v) {
                    _amount.value = TextEditingValue(
                      text: f,
                      selection: TextSelection.collapsed(offset: f.length),
                    );
                  }
                },
                decoration: const InputDecoration(isDense: true),
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
            ShopField(
              label: 'تاریخ سند',
              required: true,
              child: InkWell(
                onTap: () async {
                  final d = await showJalaliDatePicker(
                    context,
                    initial: _date,
                    title: 'تاریخ سند',
                  );
                  if (d != null) setState(() => _date = d);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
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
                        _date == null ? 'انتخاب تاریخ' : jalaliShort(_date!),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ShopField(
              label: 'نحوه پرداخت',
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in const [
                    MapEntry(CashKind.cash, 'وجه نقد'),
                    MapEntry(CashKind.cardReader, 'کارت‌خوان'),
                    MapEntry(CashKind.cardTransfer, 'کارت به کارت'),
                  ])
                    GestureDetector(
                      onTap: () => setState(() {
                        _payType = e.key;
                        final valid = _accountsForPayType;
                        if (_trsAccountId != null &&
                            !valid.any((a) => a.id == _trsAccountId)) {
                          _trsAccountId = valid.firstOrNull?.id;
                        }
                      }),
                      child: ShopTag(
                        text: e.value,
                        color: _payType == e.key
                            ? ShopColors.seed
                            : ShopColors.inkFaint,
                      ),
                    ),
                ],
              ),
            ),
            ShopField(
              label: _payType == CashKind.cash
                  ? 'صندوق پرداخت'
                  : 'بانک / کارت‌خوان پرداخت',
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      key: ValueKey('acc-$_payType'),
                      initialValue: _accountsForPayType.any(
                        (a) => a.id == _trsAccountId,
                      )
                          ? _trsAccountId
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true),
                      hint: const Text(
                        '— انتخاب کنید —',
                        style: TextStyle(fontSize: 11.5),
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: ShopColors.ink,
                      ),
                      items: [
                        for (final a in _accountsForPayType)
                          DropdownMenuItem<int?>(
                            value: a.id,
                            child: Text(
                              a.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _trsAccountId = v),
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton(
                    onPressed: _newBank,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: ShopColors.seed,
                      side: const BorderSide(color: ShopColors.line),
                    ),
                    child: const Text(
                      'تعریف بانک',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            ShopField(
              label: 'دریافت‌کننده / طرف هزینه',
              child: TextField(
                controller: _payee,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'مثلاً موجر، اداره برق…',
                  hintStyle: TextStyle(
                    fontSize: 11.5,
                    color: ShopColors.inkFaint,
                  ),
                ),
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
            ShopField(
              label: 'توضیحات',
              child: TextField(
                controller: _desc,
                decoration: const InputDecoration(isDense: true),
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      foregroundColor: ShopColors.inkSoft,
                      side: const BorderSide(color: ShopColors.line),
                    ),
                    child: const Text('انصراف'),
                  ),
                ),
                const SizedBox(width: 10),
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
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      _saving ? 'در حال ذخیره…' : 'ذخیره',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  دیالوگ افزودن/ویرایش نوع هزینه
// ============================================================
class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.repo, this.source});

  final ShopRepository repo;
  final ExpenseCategory? source;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final _name = TextEditingController(text: widget.source?.name ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'نام نوع هزینه را وارد کنید.',
            style: TextStyle(fontSize: 12.5),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ShopColors.danger,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await widget.repo.saveExpenseCategory(
        ExpenseCategory(
          id: widget.source?.id ?? 0,
          name: _name.text.trim(),
          isActive: widget.source?.isActive ?? true,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString(), style: const TextStyle(fontSize: 12.5)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ShopColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.source == null ? 'نوع هزینه جدید' : 'ویرایش نوع هزینه',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      content: TextField(
        controller: _name,
        autofocus: true,
        decoration: const InputDecoration(
          isDense: true,
          hintText: 'نام نوع هزینه',
          hintStyle: TextStyle(fontSize: 12, color: ShopColors.inkFaint),
        ),
        style: const TextStyle(fontSize: 12.5),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: ShopColors.seed),
          child: Text(_saving ? '…' : 'ذخیره'),
        ),
      ],
    );
  }
}

// ============================================================
//  مدیریت انواع هزینه — آینهٔ مودال «انواع هزینه» وب
// ============================================================
class _CategoriesSheet extends StatefulWidget {
  const _CategoriesSheet({required this.repo, required this.items});

  final ShopRepository repo;
  final List<ExpenseCategory> items;

  @override
  State<_CategoriesSheet> createState() => _CategoriesSheetState();
}

class _CategoriesSheetState extends State<_CategoriesSheet> {
  late List<ExpenseCategory> _items;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _items = widget.items;
  }

  Future<void> _reload() async {
    try {
      final list = await widget.repo.expenseCategories();
      if (!mounted) return;
      setState(() => _items = list);
    } catch (_) {}
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

  Future<void> _add() async {
    final created = await showDialog<ExpenseCategory>(
      context: context,
      builder: (_) => _CategoryDialog(repo: widget.repo),
    );
    if (created == null) return;
    _toast('نوع هزینه ذخیره شد.', ok: true);
    await _reload();
  }

  Future<void> _edit(ExpenseCategory c) async {
    final created = await showDialog<ExpenseCategory>(
      context: context,
      builder: (_) => _CategoryDialog(repo: widget.repo, source: c),
    );
    if (created == null) return;
    _toast('نوع هزینه ذخیره شد.', ok: true);
    await _reload();
  }

  Future<void> _toggle(ExpenseCategory c) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.repo.saveExpenseCategory(
        c.copyWith(isActive: !c.isActive),
      );
      await _reload();
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(ExpenseCategory c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(
          'آیا از حذف نوع هزینهٔ «${c.name}» مطمئن هستید؟',
          style: const TextStyle(fontSize: 12.5, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ShopColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأیید'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.repo.deleteExpenseCategory(c.id);
      _toast('نوع هزینه حذف شد.', ok: true);
      await _reload();
    } catch (e) {
      _toast(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'انواع هزینه',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    'افزودن',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            Flexible(
              child: _items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'نوع هزینه‌ای تعریف نشده است.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _items.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: ShopColors.line),
                      itemBuilder: (_, i) {
                        final c = _items[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            c.name,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '${Fa.number(c.expenseCount)} سند — '
                            '${Fa.number(c.totalAmount)} ریال',
                            style: const TextStyle(
                              fontSize: 10,
                              color: ShopColors.inkFaint,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ShopTag(
                                text: c.isActive ? 'فعال' : 'غیرفعال',
                                color: c.isActive
                                    ? ShopColors.ok
                                    : ShopColors.inkFaint,
                              ),
                              IconButton(
                                onPressed: () => _edit(c),
                                icon: const Icon(
                                  Icons.edit_rounded,
                                  size: 17,
                                  color: ShopColors.seed,
                                ),
                              ),
                              IconButton(
                                onPressed: () => _toggle(c),
                                tooltip: 'فعال/غیرفعال',
                                icon: Icon(
                                  Icons.power_settings_new_rounded,
                                  size: 17,
                                  color: c.isActive
                                      ? ShopColors.warn
                                      : ShopColors.ok,
                                ),
                              ),
                              IconButton(
                                onPressed: () => _delete(c),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 17,
                                  color: ShopColors.danger,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
