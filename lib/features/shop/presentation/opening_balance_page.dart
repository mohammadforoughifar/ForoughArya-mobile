// ============================================================
//  افتتاح حساب و ثبت مانده‌های اولیه
//  آینهٔ صفحهٔ وب: /shop/opening-balance
//                 → Pages/Shop/OpeningBalanceWizard.razor
//
//  چهار تب، عیناً وب:
//    ۱) طرف حساب‌ها — طلب/بدهی اولیه اشخاص
//    ۲) چک‌های اول دوره — دریافتی از مشتری / پرداختی
//    ۳) اقساط باز و معوق — صدور دفترچه اقساط بدهی اولیه
//    ۴) موجودی اولیه کالاها
//
//  ⚠️ منطق وب: هر سه تب اول با ساخت یک «سند خرید/فروش نسیه» روی کالای
//     سیستمی «مانده افتتاح حساب» / «مانده بستانکاری افتتاحیه» انجام می‌شود
//     (OrderCommand با PaymentMethod.Credit). ما هم همان را می‌سازیم؛
//     کالا و انبار پیش‌فرض از سرور خوانده می‌شود. (وب در صورت نبود، کالا
//     می‌سازد — این مرحله با پیام روشن به کاربر واگذار شده است.)
//  پیام‌های اعتبارسنجی عیناً وب.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/fa_num.dart';
import '../data/shop_repository.dart';
import '../models/order_models.dart';
import '../models/shop_models.dart';
import '../models/treasury_models.dart';
import 'shop_style.dart';

class OpeningBalancePage extends StatefulWidget {
  const OpeningBalancePage({super.key});

  @override
  State<OpeningBalancePage> createState() => _OpeningBalancePageState();
}

class _OpeningBalancePageState extends State<OpeningBalancePage> {
  late final ShopRepository _repo;

  int _tab = 0;
  bool _loading = true;
  String? _error;

  List<Party> _customers = const [];
  List<Party> _suppliers = const [];
  List<Product> _products = const [];
  List<Warehouse> _warehouses = const [];
  List<TreasuryAccount> _accounts = const [];
  List<TreasuryCheque> _cheques = const [];

  // سوابق این نشست (مثل وب که در حافظه نگه می‌دارد)
  final List<_PartyOpening> _partyHistory = [];
  final List<_StockOpening> _stockHistory = [];

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      List<Party> customers = const [];
      List<Party> suppliers = const [];
      List<Product> products = const [];
      List<Warehouse> whs = const [];
      List<TreasuryAccount> accounts = const [];
      List<TreasuryCheque> cheques = const [];
      try {
        customers = (await _repo.parties(type: 0, take: 1000)).items;
      } catch (_) {}
      try {
        suppliers = (await _repo.parties(type: 1, take: 1000)).items;
      } catch (_) {}
      try {
        products = (await _repo.products(pageSize: 1000)).items;
      } catch (_) {}
      try {
        whs = (await _repo.warehouses()).items;
      } catch (_) {}
      try {
        accounts = await _repo.treasuryAccounts(activeOnly: true);
      } catch (_) {}
      try {
        cheques = (await _repo.treasuryCheques(pageSize: 20)).items;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _suppliers = suppliers;
        _products = products;
        _warehouses = whs;
        _accounts = accounts;
        _cheques = cheques;
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

  void _toast(String msg, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        backgroundColor: ok ? ShopColors.ok : null,
      ),
    );
  }

  /// کالای سیستمی «مانده افتتاح حساب» (همان جستجوی وب)
  Future<Product?> _openingServiceProduct() async {
    final list = (await _repo.products(
      search: 'مانده افتتاح حساب',
      pageSize: 10,
    )).items;
    for (final p in list) {
      if (p.name.contains('مانده افتتاح حساب')) return p;
    }
    return list.isEmpty ? null : list.first;
  }

  /// کالای سیستمی «مانده بستانکاری افتتاحیه»
  Future<Product?> _openingGoodsProduct() async {
    final list = (await _repo.products(
      search: 'مانده بستانکاری افتتاحیه',
      pageSize: 10,
    )).items;
    for (final p in list) {
      if (p.name.contains('مانده بستانکاری افتتاحیه')) return p;
    }
    return list.isEmpty ? null : list.first;
  }

  Future<int> _warehouseIdFor(Product? p) async {
    final wh = (p?.warehouseId ?? 0);
    if (wh > 0) return wh;
    return _warehouses.isEmpty ? 1 : _warehouses.first.id;
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
              title: 'افتتاح حساب و ثبت مانده‌های اولیه',
              subtitle:
                  'ثبت مانده مطالبات، بدهی‌های اولیه، چک‌های اول دوره، '
                  'اقساط باز و کاردکس اولیه انبار',
              icon: Icons.savings_rounded,
              badge: 'آغاز دوره مالی',
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
                  title: 'بارگذاری اطلاعات پایه ناموفق بود',
                  subtitle: _error,
                  icon: Icons.error_outline_rounded,
                ),
              )
            else ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: ShopSegmented(
                  labels: const ['طرف حساب', 'چک‌ها', 'اقساط', 'موجودی'],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              const SizedBox(height: 10),
              switch (_tab) {
                0 => _partiesTab(),
                1 => _chequesTab(),
                2 => _installmentsTab(),
                _ => _stockTab(),
              },
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  //  تب ۱ — مانده افتتاحیه طرف حساب‌ها
  // ------------------------------------------------------------

  int? _partyId;
  String? _partyName;
  bool _isDebtor = true;
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  DateTime _docDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  Widget _partiesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _card([
            const Text(
              'ثبت مانده افتتاحیه شخص',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            const Text(
              'تعیین طلبکاری یا بدهکاری مشتری و تأمین‌کننده در ابتدای دوره',
              style: TextStyle(fontSize: 10, color: ShopColors.inkFaint),
            ),
            const SizedBox(height: 10),
            ShopField(
              label: 'طرف حساب (مشتری یا تأمین‌کننده)',
              required: true,
              child: InkWell(
                onTap: _pickOpeningParty,
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
                          _partyName ?? 'جستجو با نام یا کد طرف حساب…',
                          style: TextStyle(
                            fontSize: 12,
                            color: _partyName == null
                                ? ShopColors.inkFaint
                                : ShopColors.ink,
                          ),
                        ),
                      ),
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
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'ماهیت مانده حساب',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: ShopColors.inkSoft,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _segBtn(
                    'بدهکار (طلب ما)',
                    Icons.south_west_rounded,
                    ShopColors.danger,
                    _isDebtor,
                    () => setState(() => _isDebtor = true),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _segBtn(
                    'بستانکار (بدهی ما)',
                    Icons.north_east_rounded,
                    ShopColors.ok,
                    !_isDebtor,
                    () => setState(() => _isDebtor = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ShopField(
              label: 'مبلغ مانده افتتاحیه (ریال)',
              required: true,
              child: TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 12.5),
                decoration: const InputDecoration(isDense: true),
              ),
            ),
            if (parseNum(_amount.text) > 0)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'معادل: ${Fa.number(parseNum(_amount.text) / 10)} تومان',
                  style: const TextStyle(
                    fontSize: 10,
                    color: ShopColors.inkFaint,
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: ShopField(
                    label: 'تاریخ سند افتتاحیه',
                    child: _dateBtn(_docDate, (d) => setState(() => _docDate = d)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ShopField(
                    label: 'سررسید تسویه نسیه',
                    required: true,
                    child: _dateBtn(
                      _dueDate,
                      (d) => setState(() => _dueDate = d),
                    ),
                  ),
                ),
              ],
            ),
            ShopField(
              label: 'شرح سند / بابت',
              hint: 'مثال: مانده افتتاحیه انتقال از سال مالی قبل',
              child: TextField(
                controller: _desc,
                style: const TextStyle(fontSize: 12.5),
                decoration: const InputDecoration(isDense: true),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _savePartyOpening,
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
                    : const Icon(Icons.check_circle_rounded, size: 17),
                label: const Text(
                  'ثبت سند افتتاح حساب شخص',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _card([
            const Text(
              'افتتاح حساب‌های ثبت‌شده اخیر',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            if (_partyHistory.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'هنوز افتتاح حسابی در این نشست ثبت نشده است.',
                  style: TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
                ),
              )
            else
              for (final h in _partyHistory)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              h.partyName,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${h.isDebtor ? 'بدهکار (طلب ما)' : 'بستانکار (بدهی ما)'}'
                              '${h.date == null ? '' : ' · ${jalaliShort(h.date!)}'}',
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: ShopColors.inkFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        Fa.number(h.amount),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: h.isDebtor
                              ? ShopColors.danger
                              : ShopColors.ok,
                        ),
                      ),
                    ],
                  ),
                ),
          ]),
        ),
      ],
    );
  }

  Widget _segBtn(
    String label,
    IconData icon,
    Color color,
    bool selected,
    VoidCallback onTap,
  ) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(11),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.09) : Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: selected ? color.withValues(alpha: 0.5) : ShopColors.line,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: selected ? color : ShopColors.inkFaint),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? color : ShopColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _pickOpeningParty() async {
    final all = [..._customers, ..._suppliers];
    final picked = await showModalBottomSheet<Party>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PartySearchSheet(
        items: all,
        title: 'انتخاب طرف حساب',
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _partyId = picked.id;
      _partyName = picked.name;
    });
  }

  /// همان `SavePartyBalanceAsync` وب
  Future<void> _savePartyOpening() async {
    if ((_partyId ?? 0) <= 0) {
      _toast('لطفاً طرف حساب را انتخاب کنید.');
      return;
    }
    if (parseNum(_amount.text) <= 0) {
      _toast('مبلغ افتتاح حساب باید بزرگ‌تر از صفر باشد.');
      return;
    }
    setState(() => _saving = true);
    try {
      final isSale = _isDebtor;
      final svcProd = await _openingServiceProduct();
      final goodsProd = await _openingGoodsProduct();
      final selected = isSale ? svcProd : goodsProd;
      if (selected == null) {
        throw Exception(
          'کالای سیستمی «${isSale ? 'مانده افتتاح حساب' : 'مانده بستانکاری افتتاحیه'}» '
          'در اطلاعات پایه پیدا نشد؛ ابتدا آن را در صفحهٔ کالاها بسازید '
          '(همان کاری که وب هنگام اولین ثبت انجام می‌دهد).',
        );
      }
      final whId = await _warehouseIdFor(selected);
      final amount = parseNum(_amount.text);
      await _repo.createOrder({
        'type': isSale ? TxnType.sale : TxnType.purchase,
        'partyId': _partyId,
        'warehouseId': whId,
        'date': _docDate.toIso8601String(),
        'paymentMethod': PayMethod.credit,
        'dueDate': _dueDate.toIso8601String(),
        'description': _desc.text.trim().isEmpty
            ? 'مانده حساب افتتاحیه اول دوره'
            : _desc.text.trim(),
        'lines': [
          {
            'productId': selected.id,
            'quantity': 1.0,
            'price': amount,
            'discountPercent': 0.0,
            'discountAmount': 0.0,
            'discountIsAmount': false,
          },
        ],
        'cheques': const [],
        'installments': const [],
      });
      if (!mounted) return;
      _toast('افتتاح حساب طرف حساب «$_partyName» با موفقیت ثبت شد.', ok: true);
      setState(() {
        _partyHistory.insert(
          0,
          _PartyOpening(
            partyName: _partyName ?? '',
            amount: amount,
            isDebtor: _isDebtor,
            date: _docDate,
          ),
        );
        _partyId = null;
        _partyName = null;
        _amount.clear();
        _desc.clear();
      });
    } catch (e) {
      if (!mounted) return;
      _toast(_cleanMsg2(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _cleanMsg2(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');

  // ------------------------------------------------------------
  //  تب ۲ — چک‌های اول دوره
  // ------------------------------------------------------------

  int _chequeKind = ChequeKind.received;
  final _chqNumber = TextEditingController();
  final _chqAmount = TextEditingController();
  final _chqBank = TextEditingController();
  final _chqBranch = TextEditingController();
  final _chqAccount = TextEditingController();
  int? _chqAccountId;
  int? _chqPartyId;
  String? _chqPartyName;
  DateTime _chqDue = DateTime.now().add(const Duration(days: 30));
  bool _chqSaving = false;

  Widget _chequesTab() {
    final banks = _accounts.where((a) => a.kind == 1).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _card([
            const Text(
              'ثبت چک اول دوره',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            const Text(
              'چک دریافتی از مشتری یا چک صادره که در ابتدای دوره در جریان است',
              style: TextStyle(fontSize: 10, color: ShopColors.inkFaint),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _segBtn(
                    'دریافتی',
                    Icons.south_west_rounded,
                    ShopColors.seed,
                    _chequeKind == ChequeKind.received,
                    () => setState(() => _chequeKind = ChequeKind.received),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _segBtn(
                    'پرداختی (صادره)',
                    Icons.north_east_rounded,
                    ShopColors.warn,
                    _chequeKind == ChequeKind.issued,
                    () => setState(() => _chequeKind = ChequeKind.issued),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ShopField(
              label: 'طرف حساب',
              required: true,
              child: InkWell(
                onTap: () async {
                  final picked = await showModalBottomSheet<Party>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (_) => _PartySearchSheet(
                      items: [..._customers, ..._suppliers],
                      title: 'انتخاب طرف حساب چک',
                    ),
                  );
                  if (picked == null || !mounted) return;
                  setState(() {
                    _chqPartyId = picked.id;
                    _chqPartyName = picked.name;
                  });
                },
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
                          _chqPartyName ?? 'انتخاب طرف حساب…',
                          style: TextStyle(
                            fontSize: 12,
                            color: _chqPartyName == null
                                ? ShopColors.inkFaint
                                : ShopColors.ink,
                          ),
                        ),
                      ),
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
            Row(
              children: [
                Expanded(
                  child: ShopField(
                    label: 'شماره چک',
                    required: true,
                    child: TextField(
                      controller: _chqNumber,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: const InputDecoration(isDense: true),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ShopField(
                    label: 'مبلغ (ریال)',
                    required: true,
                    child: TextField(
                      controller: _chqAmount,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: const InputDecoration(isDense: true),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: ShopField(
                    label: 'بانک',
                    child: TextField(
                      controller: _chqBank,
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
                      controller: _chqBranch,
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
                controller: _chqAccount,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 12.5),
                decoration: const InputDecoration(isDense: true),
              ),
            ),
            if (_chequeKind == ChequeKind.issued) ...[
              DropdownButtonFormField<int?>(
                initialValue: _chqAccountId,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'حساب بانکی صادرکننده *',
                  labelStyle: TextStyle(fontSize: 10.5),
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
                onChanged: (v) => setState(() => _chqAccountId = v),
              ),
              const SizedBox(height: 8),
            ],
            ShopField(
              label: 'تاریخ سررسید',
              required: true,
              child: _dateBtn(_chqDue, (d) => setState(() => _chqDue = d)),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _chqSaving ? null : _saveOpeningCheque,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  backgroundColor: ShopColors.seed,
                ),
                icon: const Icon(Icons.save_rounded, size: 17),
                label: const Text(
                  'ثبت چک در دفتر چک',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _card([
            const Text(
              'چک‌های ثبت‌شده',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            if (_cheques.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'چکی در دفتر چک ثبت نشده است.',
                  style: TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
                ),
              )
            else
              for (final c in _cheques)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      ShopTag(
                        text: c.kindTitle,
                        color: c.kind == ChequeKind.received
                            ? ShopColors.seed
                            : ShopColors.warn,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${Fa.number(int.tryParse(c.number) ?? 0)} · ${c.partyName ?? '—'}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${Fa.number(c.amount)} ریال · '
                              '${c.dueDate == null ? '' : jalaliShort(c.dueDate!)}',
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: ShopColors.inkFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ShopTag(text: c.statusTitle, color: ShopColors.inkSoft),
                    ],
                  ),
                ),
          ]),
        ),
      ],
    );
  }

  /// همان `SaveChequeAsync` وب
  Future<void> _saveOpeningCheque() async {
    if ((_chqPartyId ?? 0) <= 0) {
      _toast('لطفاً طرف حساب را انتخاب کنید.');
      return;
    }
    if (_chqNumber.text.trim().isEmpty) {
      // وب شماره را از فرم می‌گیرد؛ اینجا هم لازم است
      _toast('شماره چک را وارد کنید.');
      return;
    }
    if (parseNum(_chqAmount.text) <= 0) {
      _toast('مبلغ چک باید بزرگ‌تر از صفر باشد.');
      return;
    }
    if (_chequeKind == ChequeKind.issued && (_chqAccountId ?? 0) <= 0) {
      _toast('لطفاً حساب بانکی صادرکننده را انتخاب کنید.');
      return;
    }
    setState(() => _chqSaving = true);
    try {
      final saved = await _repo.saveCheque(
        TreasuryCheque(
          kind: _chequeKind,
          number: _chqNumber.text.trim(),
          amount: parseNum(_chqAmount.text),
          issueDate: DateTime.now(),
          dueDate: _chqDue,
          bankName: _chqBank.text.trim(),
          branchName: _chqBranch.text.trim(),
          accountNumber: _chqAccount.text.trim(),
          partyId: _chqPartyId,
          trsAccountId: _chqAccountId,
          status: TrsChequeState.inHand,
        ),
      );
      if (!mounted) return;
      _toast(
        'چک شماره ${Fa.number(int.tryParse(saved.number) ?? 0)} به مبلغ '
        '${Fa.number(saved.amount)} ریال با موفقیت در دفتر چک ثبت شد.',
        ok: true,
      );
      setState(() {
        _chqNumber.clear();
        _chqAmount.clear();
        _chqBank.clear();
        _chqBranch.clear();
        _chqAccount.clear();
      });
      final list = (await _repo.treasuryCheques(pageSize: 20)).items;
      if (!mounted) return;
      setState(() => _cheques = list);
    } catch (e) {
      if (!mounted) return;
      _toast(_cleanMsg2(e));
    } finally {
      if (mounted) setState(() => _chqSaving = false);
    }
  }

  // ------------------------------------------------------------
  //  تب ۳ — اقساط باز و معوق
  // ------------------------------------------------------------

  int? _instPartyId;
  String? _instPartyName;
  final _instTotal = TextEditingController();
  final _instCount = TextEditingController(text: '3');
  final _instNote = TextEditingController(
    text: 'مانده بدهی اقساطی افتتاحیه',
  );
  int _instInterval = 1;
  DateTime _instFirstDue = DateTime.now().add(const Duration(days: 30));
  bool _instSaving = false;

  Widget _installmentsTab() {
    final total = parseNum(_instTotal.text);
    final count = int.tryParse(toEnDigits(_instCount.text).trim()) ?? 0;
    final preview = splitInstallments(total, count);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: _card([
        const Text(
          'صدور دفترچه اقساط بدهی اولیه',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        const Text(
          'بدهی قدیمی مشتری را به چند قسط با سررسید مشخص تبدیل می‌کند',
          style: TextStyle(fontSize: 10, color: ShopColors.inkFaint),
        ),
        const SizedBox(height: 10),
        ShopField(
          label: 'مشتری',
          required: true,
          child: InkWell(
            onTap: () async {
              final picked = await showModalBottomSheet<Party>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => _PartySearchSheet(
                  items: _customers,
                  title: 'انتخاب مشتری',
                ),
              );
              if (picked == null || !mounted) return;
              setState(() {
                _instPartyId = picked.id;
                _instPartyName = picked.name;
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
              decoration: BoxDecoration(
                border: Border.all(color: ShopColors.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _instPartyName ?? 'انتخاب مشتری…',
                      style: TextStyle(
                        fontSize: 12,
                        color: _instPartyName == null
                            ? ShopColors.inkFaint
                            : ShopColors.ink,
                      ),
                    ),
                  ),
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
        Row(
          children: [
            Expanded(
              child: ShopField(
                label: 'مبلغ کل بدهی (ریال)',
                required: true,
                child: TextField(
                  controller: _instTotal,
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
                label: 'تعداد اقساط',
                required: true,
                child: TextField(
                  controller: _instCount,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 12.5),
                  decoration: const InputDecoration(isDense: true),
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: ShopField(
                label: 'فاصلهٔ اقساط',
                child: DropdownButtonFormField<int>(
                  initialValue: _instInterval,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true),
                  style: const TextStyle(
                    fontSize: 12,
                    color: ShopColors.ink,
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('ماهانه')),
                    DropdownMenuItem(value: 2, child: Text('هر دو ماه')),
                    DropdownMenuItem(value: 3, child: Text('فصلی')),
                  ],
                  onChanged: (v) => setState(() => _instInterval = v ?? 1),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ShopField(
                label: 'سررسید اولین قسط',
                required: true,
                child: _dateBtn(
                  _instFirstDue,
                  (d) => setState(() => _instFirstDue = d),
                ),
              ),
            ),
          ],
        ),
        ShopField(
          label: 'شرح / بابت',
          child: TextField(
            controller: _instNote,
            style: const TextStyle(fontSize: 12.5),
            decoration: const InputDecoration(isDense: true),
          ),
        ),
        if (preview.isNotEmpty) ...[
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: ShopColors.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'پیش‌نمایش ${Fa.number(preview.length)} قسط',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: ShopColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (var i = 0; i < preview.length; i++)
                      ShopTag(
                        text:
                            '${Fa.number(i + 1)}: ${Fa.number(preview[i])}',
                        color: ShopColors.seed,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _instSaving ? null : _generateInstallments,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 46),
              backgroundColor: ShopColors.indigo,
            ),
            icon: const Icon(Icons.event_repeat_rounded, size: 17),
            label: const Text(
              'صدور دفترچه اقساط',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ]),
    );
  }

  /// همان `GenerateInstallmentsAsync` وب
  Future<void> _generateInstallments() async {
    if ((_instPartyId ?? 0) <= 0) {
      _toast('لطفاً مشتری را انتخاب کنید.');
      return;
    }
    final total = parseNum(_instTotal.text);
    final count = int.tryParse(toEnDigits(_instCount.text).trim()) ?? 0;
    if (total <= 0) {
      _toast('مبلغ بدهی اقساطی باید بزرگ‌تر از صفر باشد.');
      return;
    }
    if (count <= 0) {
      _toast('تعداد اقساط باید حداقل ۱ قسط باشد.');
      return;
    }
    setState(() => _instSaving = true);
    try {
      final svcProd = await _openingServiceProduct();
      if (svcProd == null) {
        throw Exception(
          'کالای سیستمی «مانده افتتاح حساب» پیدا نشد؛ ابتدا آن را در صفحهٔ کالاها بسازید.',
        );
      }
      final whId = await _warehouseIdFor(svcProd);
      final amounts = splitInstallments(total, count);
      final insts = <Map<String, dynamic>>[];
      for (var i = 0; i < amounts.length; i++) {
        final due = DateTime(
          _instFirstDue.year,
          _instFirstDue.month + i * _instInterval,
          _instFirstDue.day,
        );
        insts.add({
          'id': 0,
          'no': i + 1,
          'amount': amounts[i],
          'dueDate': due.toIso8601String(),
          'isPaid': false,
        });
      }
      final lastDue = DateTime(
        _instFirstDue.year,
        _instFirstDue.month + count * _instInterval,
        _instFirstDue.day,
      );
      await _repo.createOrder({
        'type': TxnType.sale,
        'partyId': _instPartyId,
        'warehouseId': whId,
        'date': DateTime.now().toIso8601String(),
        'paymentMethod': PayMethod.installment,
        'dueDate': lastDue.toIso8601String(),
        'description': _instNote.text.trim(),
        'lines': [
          {
            'productId': svcProd.id,
            'quantity': 1.0,
            'price': total,
            'discountPercent': 0.0,
            'discountAmount': 0.0,
            'discountIsAmount': false,
          },
        ],
        'cheques': const [],
        'installments': insts,
      });
      if (!mounted) return;
      _toast(
        'دفترچه اقساط بدهی افتتاحیه با ${Fa.number(count)} قسط با موفقیت صادر شد.',
        ok: true,
      );
      setState(() {
        _instTotal.clear();
        _instPartyId = null;
        _instPartyName = null;
      });
    } catch (e) {
      if (!mounted) return;
      _toast(_cleanMsg2(e));
    } finally {
      if (mounted) setState(() => _instSaving = false);
    }
  }

  // ------------------------------------------------------------
  //  تب ۴ — موجودی اولیه کالاها
  // ------------------------------------------------------------

  int? _stkWarehouseId;
  int? _stkProductId;
  String? _stkProductName;
  final _stkQty = TextEditingController(text: '1');
  final _stkPrice = TextEditingController();
  final _stkDesc = TextEditingController(
    text: 'موجودی اولیه ابتدای دوره',
  );
  bool _stkSaving = false;

  Widget _stockTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _card([
            const Text(
              'ثبت موجودی اولیه کالا',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            const Text(
              'هر کالا یک سند خرید اول دوره می‌سازد تا کاردکس و موجودی درست شروع شود',
              style: TextStyle(fontSize: 10, color: ShopColors.inkFaint),
            ),
            const SizedBox(height: 10),
            ShopField(
              label: 'انبار',
              required: true,
              child: DropdownButtonFormField<int?>(
                initialValue: _stkWarehouseId,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                style: const TextStyle(fontSize: 12, color: ShopColors.ink),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('انتخاب انبار…'),
                  ),
                  for (final w in _warehouses)
                    DropdownMenuItem<int?>(value: w.id, child: Text(w.name)),
                ],
                onChanged: (v) => setState(() => _stkWarehouseId = v),
              ),
            ),
            ShopField(
              label: 'کالا',
              required: true,
              child: InkWell(
                onTap: _pickStockProduct,
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
                          _stkProductName ?? 'جستجوی کالا…',
                          style: TextStyle(
                            fontSize: 12,
                            color: _stkProductName == null
                                ? ShopColors.inkFaint
                                : ShopColors.ink,
                          ),
                        ),
                      ),
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
            Row(
              children: [
                Expanded(
                  child: ShopField(
                    label: 'تعداد',
                    required: true,
                    child: TextField(
                      controller: _stkQty,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: const InputDecoration(isDense: true),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ShopField(
                    label: 'قیمت واحد (ریال)',
                    child: TextField(
                      controller: _stkPrice,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: const InputDecoration(isDense: true),
                    ),
                  ),
                ),
              ],
            ),
            ShopField(
              label: 'شرح سند',
              child: TextField(
                controller: _stkDesc,
                style: const TextStyle(fontSize: 12.5),
                decoration: const InputDecoration(isDense: true),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _stkSaving ? null : _saveOpeningStock,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  backgroundColor: ShopColors.teal,
                ),
                icon: const Icon(Icons.inventory_2_rounded, size: 17),
                label: const Text(
                  'ثبت موجودی اولیه',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ]),
        ),
        if (_stockHistory.isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _card([
              const Text(
                'اقلام ثبت‌شدهٔ این نشست',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              for (final s in _stockHistory)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${s.productName} · ${s.warehouseName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${Fa.number(s.quantity, decimals: 2)} × '
                        '${Fa.number(s.unitPrice)}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: ShopColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
            ]),
          ),
        ],
      ],
    );
  }

  Future<void> _pickStockProduct() async {
    final picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProductSearchSheet(
        items: _products,
        title: 'انتخاب کالا',
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _stkProductId = picked.id;
      _stkProductName = picked.name;
    });
  }

  /// همان `SaveOpeningStockAsync` وب
  Future<void> _saveOpeningStock() async {
    if ((_stkWarehouseId ?? 0) <= 0) {
      _toast('لطفاً انبار را انتخاب کنید.');
      return;
    }
    if ((_stkProductId ?? 0) <= 0) {
      _toast('لطفاً کالا را انتخاب کنید.');
      return;
    }
    final qty = parseNum(_stkQty.text);
    if (qty <= 0) {
      _toast('تعداد کالا باید بزرگ‌تر از صفر باشد.');
      return;
    }
    setState(() => _stkSaving = true);
    try {
      final supplierId = _suppliers.isEmpty ? null : _suppliers.first.id;
      await _repo.createOrder({
        'type': TxnType.purchase,
        'partyId': supplierId,
        'warehouseId': _stkWarehouseId,
        'date': DateTime.now().toIso8601String(),
        'paymentMethod': PayMethod.cash,
        'description': _stkDesc.text.trim(),
        'lines': [
          {
            'productId': _stkProductId,
            'quantity': qty,
            'price': parseNum(_stkPrice.text),
            'discountPercent': 0.0,
            'discountAmount': 0.0,
            'discountIsAmount': false,
          },
        ],
        'cheques': const [],
        'installments': const [],
      });
      final whName = _warehouses
          .firstWhere(
            (w) => w.id == _stkWarehouseId,
            orElse: () => Warehouse(id: 0, name: ''),
          )
          .name;
      if (!mounted) return;
      _toast(
        'موجودی اولیه کالای «$_stkProductName» به تعداد ${Fa.number(qty, decimals: 2)} '
        'در انبار «$whName» ثبت شد.',
        ok: true,
      );
      setState(() {
        _stockHistory.insert(
          0,
          _StockOpening(
            productName: _stkProductName ?? '',
            warehouseName: whName,
            quantity: qty,
            unitPrice: parseNum(_stkPrice.text),
          ),
        );
        _stkQty.text = '1';
        _stkPrice.clear();
      });
    } catch (e) {
      if (!mounted) return;
      _toast(_cleanMsg2(e));
    } finally {
      if (mounted) setState(() => _stkSaving = false);
    }
  }

  // ------------------------------------------------------------
  //  کمکی‌ها
  // ------------------------------------------------------------

  Widget _card(List<Widget> children) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

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

class _PartyOpening {
  _PartyOpening({
    required this.partyName,
    required this.amount,
    required this.isDebtor,
    this.date,
  });

  final String partyName;
  final double amount;
  final bool isDebtor;
  final DateTime? date;
}

class _StockOpening {
  _StockOpening({
    required this.productName,
    required this.warehouseName,
    required this.quantity,
    required this.unitPrice,
  });

  final String productName;
  final String warehouseName;
  final double quantity;
  final double unitPrice;
}

/// انتخاب طرف حساب با جستجو
class _PartySearchSheet extends StatefulWidget {
  const _PartySearchSheet({required this.items, required this.title});

  final List<Party> items;
  final String title;

  @override
  State<_PartySearchSheet> createState() => _PartySearchSheetState();
}

class _PartySearchSheetState extends State<_PartySearchSheet> {
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              widget.title,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
              ),
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
                      onTap: () => Navigator.pop(context, list[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// انتخاب کالا با جستجو
class _ProductSearchSheet extends StatefulWidget {
  const _ProductSearchSheet({required this.items, required this.title});

  final List<Product> items;
  final String title;

  @override
  State<_ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<_ProductSearchSheet> {
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
        : widget.items.where((e) => e.name.toLowerCase().contains(q)).toList();
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              widget.title,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
              ),
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
                hintText: 'جستجوی نام کالا…',
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
                      'کالایی یافت نشد',
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
                      subtitle: Text(
                        list[i].code,
                        style: const TextStyle(fontSize: 10),
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
