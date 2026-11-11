// ============================================================
//  کیف پول معرف‌ها — آینهٔ /referrer-wallets
//  منبع: Pages/Catalog/ReferrerWallets.razor
//
//  • جستجوی «نام معرف یا مجموعه» + مرتب‌سازی (نام / جمع پورسانت /
//    جمع پرداختی / مانده کیف پول) + دکمهٔ صعودی/نزولی
//  • کارت‌ها: مجموعه، حساب بانکی (کارت + IR شبا)، جمع پورسانت،
//    جمع پرداختی، مانده کیف پول (سبز/قرمز)
//  • «سند پرداخت جدید» و «پرداخت به این معرف»
//  • اسناد پرداخت هر معرف با جمع پرداختی و حذف سند
//  اعتبارسنجی‌ها عیناً وب: «معرف را انتخاب کنید.»، «مبلغ پرداخت را وارد کنید.»
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/fa_num.dart';
import '../data/shop_repository.dart';
import '../models/visit_models.dart';
import 'shop_style.dart';

class ReferrerWalletsPage extends StatefulWidget {
  const ReferrerWalletsPage({super.key});

  @override
  State<ReferrerWalletsPage> createState() => _ReferrerWalletsPageState();
}

class _ReferrerWalletsPageState extends State<ReferrerWalletsPage> {
  late final ShopRepository _repo;

  List<ShopReferrer> _items = const [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  String _sortBy = 'balance';
  bool _desc = true;

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.referrerWallets(
        search: _searchCtrl.text,
        sortBy: _sortBy,
        desc: _desc,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
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

  void _toast(String msg, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        backgroundColor: ok ? ShopColors.ok : null,
      ),
    );
  }

  Future<void> _openPay([ShopReferrer? r]) async {
    if (_items.isEmpty) {
      _toast('ابتدا معرفی ثبت کنید.');
      return;
    }
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaySheet(repo: _repo, referrers: _items, preset: r),
    );
    if (ok == true) await _load();
  }

  Future<void> _showPayments(ShopReferrer r) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentsSheet(repo: _repo, referrer: r),
    );
    if (changed == true) await _load();
  }

  static String _money(double v) => Fa.number(v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: const Text(
          'کیف پول معرف‌ها',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: () => _openPay(),
            icon: const Icon(Icons.add_card_rounded, size: 21),
            tooltip: 'سند پرداخت جدید',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ShopEmpty(
              title: 'دریافت کیف پول‌ها ناموفق بود',
              subtitle: _error,
              icon: Icons.error_outline_rounded,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
                children: [
                  ShopHeader(
                    title: 'کیف پول معرف‌ها',
                    subtitle: 'مانده پورسانت، پرداخت‌ها و اسناد پرداخت هر معرف',
                    icon: Icons.account_balance_wallet_rounded,
                    badge: '${Fa.number(_items.length)} معرف',
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: ShopColors.surface,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: ShopColors.line),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => _load(),
                                style: const TextStyle(fontSize: 12),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  hintText: 'جستجوی نام معرف یا مجموعه…',
                                  hintStyle: TextStyle(fontSize: 11),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    size: 17,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            FilledButton(
                              onPressed: _load,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 44),
                                backgroundColor: ShopColors.seed,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              child: const Text(
                                'جستجو',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _sortBy,
                                isDense: true,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: ShopColors.ink,
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'name',
                                    child: Text('مرتب‌سازی: نام'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'commission',
                                    child: Text('مرتب‌سازی: جمع پورسانت'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'paid',
                                    child: Text('مرتب‌سازی: جمع پرداختی'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'balance',
                                    child: Text('مرتب‌سازی: مانده کیف پول'),
                                  ),
                                ],
                                onChanged: (v) {
                                  setState(() => _sortBy = v ?? 'name');
                                  _load();
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() => _desc = !_desc);
                                _load();
                              },
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 44),
                                foregroundColor: ShopColors.seed,
                              ),
                              icon: Icon(
                                _desc
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                                size: 14,
                              ),
                              label: Text(
                                _desc ? 'نزولی' : 'صعودی',
                                style: const TextStyle(fontSize: 10.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 30),
                      child: ShopEmpty(
                        title: 'معرفی یافت نشد',
                        subtitle: 'معرفی با این جستجو وجود ندارد.',
                        icon: Icons.wallet_outlined,
                      ),
                    )
                  else
                    for (final r in _items) _card(r),
                ],
              ),
            ),
    );
  }

  Widget _card(ShopReferrer r) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if ((r.companyName ?? '').isNotEmpty)
                    Text(
                      r.companyName!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                  if ((r.cardNumber ?? '').isNotEmpty)
                    Text(
                      r.cardNumber!,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                  if ((r.iban ?? '').isNotEmpty)
                    Text(
                      'IR${r.iban}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                  if ((r.cardNumber ?? '').isEmpty &&
                      (r.iban ?? '').isEmpty)
                    const Text(
                      'حساب بانکی: —',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'مانده کیف پول',
                  style: TextStyle(fontSize: 8.5, color: ShopColors.inkFaint),
                ),
                Text(
                  _money(r.walletBalance),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: r.walletBalance > 0
                        ? ShopColors.ok
                        : r.walletBalance < 0
                        ? ShopColors.danger
                        : ShopColors.ink,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: _box('جمع پورسانت', _money(r.totalCommission),
                  ShopColors.seed),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _box('جمع پرداختی', _money(r.totalPaid),
                  ShopColors.inkSoft),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _openPay(r),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  backgroundColor: ShopColors.ok,
                ),
                icon: const Icon(Icons.payments_rounded, size: 15),
                label: const Text(
                  'پرداخت',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showPayments(r),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  foregroundColor: ShopColors.seed,
                  side: BorderSide(
                    color: ShopColors.seed.withValues(alpha: 0.4),
                  ),
                ),
                icon: const Icon(Icons.receipt_long_rounded, size: 15),
                label: const Text(
                  'اسناد',
                  style: TextStyle(fontSize: 10.5),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _box(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: ShopColors.bg,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 8.5, color: ShopColors.inkFaint),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );
}

// ------------------------------------------------------------
//  سند پرداخت پورسانت
// ------------------------------------------------------------
class _PaySheet extends StatefulWidget {
  const _PaySheet({
    required this.repo,
    required this.referrers,
    this.preset,
  });

  final ShopRepository repo;
  final List<ShopReferrer> referrers;
  final ShopReferrer? preset;

  @override
  State<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<_PaySheet> {
  late int _referrerId;
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _referrerId = widget.preset?.id ?? 0;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(fontSize: 12))),
    );
  }

  Future<void> _save() async {
    if (_referrerId <= 0) {
      _toast('معرف را انتخاب کنید.');
      return;
    }
    final amount = parseNum(_amountCtrl.text);
    if (amount <= 0) {
      _toast('مبلغ پرداخت را وارد کنید.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repo.addReferrerPayment(
        ReferrerPayment(
          referrerId: _referrerId,
          amount: amount,
          date: _date,
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _toast(
        e
            .toString()
            .replaceFirst('ApiException: ', '')
            .replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'سند پرداخت پورسانت',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
            ShopField(
              label: 'معرف',
              required: true,
              child: DropdownButtonFormField<int>(
                initialValue: _referrerId > 0 ? _referrerId : null,
                isExpanded: true,
                style: const TextStyle(fontSize: 11.5, color: ShopColors.ink),
                decoration: _dec(),
                hint: const Text(
                  '— انتخاب معرف —',
                  style: TextStyle(fontSize: 11),
                ),
                items: [
                  for (final r in widget.referrers)
                    DropdownMenuItem(
                      value: r.id,
                      child: Text(
                        '${r.name} — مانده: ${Fa.number(r.walletBalance)} ریال',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _referrerId = v ?? 0),
              ),
            ),
            const SizedBox(height: 8),
            ShopField(
              label: 'مبلغ پرداخت (ریال)',
              required: true,
              child: TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 12.5),
                decoration: _dec(),
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final d = await showJalaliDatePicker(
                  context,
                  initial: _date,
                  title: 'تاریخ پرداخت',
                );
                if (d != null) setState(() => _date = d);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: ShopColors.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ShopColors.line),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_rounded,
                      size: 15,
                      color: ShopColors.inkFaint,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'تاریخ پرداخت: ${jalaliShort(_date)}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            ShopField(
              label: 'توضیحات',
              child: TextField(
                controller: _descCtrl,
                style: const TextStyle(fontSize: 12.5),
                decoration: _dec(hint: 'اختیاری'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  backgroundColor: ShopColors.seed,
                ),
                icon: const Icon(Icons.save_rounded, size: 17),
                label: const Text(
                  'ثبت پرداخت',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec({String? hint}) => InputDecoration(
    isDense: true,
    filled: true,
    fillColor: ShopColors.bg,
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
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

// ------------------------------------------------------------
//  اسناد پرداخت یک معرف
// ------------------------------------------------------------
class _PaymentsSheet extends StatefulWidget {
  const _PaymentsSheet({required this.repo, required this.referrer});

  final ShopRepository repo;
  final ShopReferrer referrer;

  @override
  State<_PaymentsSheet> createState() => _PaymentsSheetState();
}

class _PaymentsSheetState extends State<_PaymentsSheet> {
  List<ReferrerPayment> _items = const [];
  bool _loading = true;
  bool _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.repo.referrerPayments(
        referrerId: widget.referrer.id,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e
            .toString()
            .replaceFirst('ApiException: ', '')
            .replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _delete(ReferrerPayment p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف سند پرداخت', style: TextStyle(fontSize: 14)),
        content: Text(
          'آیا از حذف سند پرداخت «${p.number}» مطمئن هستید؟',
          style: const TextStyle(fontSize: 12),
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
    if (ok != true) return;
    try {
      await widget.repo.deleteReferrerPayment(p.id);
      _changed = true;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString(), style: const TextStyle(fontSize: 12))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<double>(0, (a, p) => a + p.amount);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ShopColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'اسناد پرداخت — ${widget.referrer.name}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(_changed),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          ),
          Flexible(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: ShopColors.danger,
                      ),
                    ),
                  )
                : _items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(top: 26, bottom: 30),
                    child: ShopEmpty(
                      title: 'سند پرداختی ثبت نشده است',
                      subtitle: 'با «سند پرداخت جدید» اولین پرداخت را ثبت کنید.',
                      icon: Icons.receipt_long_rounded,
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      for (final p in _items)
                        Container(
                          margin: const EdgeInsets.only(bottom: 7),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ShopColors.bg,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'سند ${p.number}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                        color: ShopColors.seed,
                                      ),
                                    ),
                                    Text(
                                      '${p.date == null ? '—' : jalaliShort(p.date!)}'
                                      '${(p.description ?? '').isEmpty ? '' : ' — ${p.description}'}',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        color: ShopColors.inkFaint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                Fa.number(p.amount),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => _delete(p),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 17,
                                  color: ShopColors.danger,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text(
                            'جمع پرداختی:',
                            style: TextStyle(
                              fontSize: 11,
                              color: ShopColors.inkSoft,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${Fa.number(total)} ریال',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: ShopColors.seed,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
