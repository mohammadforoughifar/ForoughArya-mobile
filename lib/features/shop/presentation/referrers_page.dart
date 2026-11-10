// ============================================================
//  معرف‌ها — آینهٔ /referrers (Pages/Catalog/Referrers.razor)
//
//  • جستجوی نام + سوئیچ «فقط فعال‌ها» + شمارش کل
//  • کارت‌ها: نام، مجموعه، تلفن، پورسانت کالا (٪ از سود)،
//    پورسانت خدمات (٪ از مبلغ)، تعداد اسناد فروش، وضعیت
//  • اقدام‌ها: کارت ویزیت، ویرایش، حذف
//  • فرم: نام*، نام مجموعه، تلفن، پورسانت کالا/خدمات (٪)،
//    شماره کارت (۱۶ رقم)، شبا (IR + ۲۴ رقم)، سقف تخفیف ویزیتوری (٪)
//    با همان توضیح «۰ یا خالی = بدون سقف»، سوئیچ «کالاهای موجود»،
//    وضعیت فعال/غیرفعال
//  اعتبارسنجی‌ها عیناً وب: «نام معرف را وارد کنید.»، سقف ۰..۱۰۰
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../data/fa_num.dart';
import '../data/shop_repository.dart';
import '../models/visit_models.dart';
import 'shop_style.dart';

class ReferrersPage extends StatefulWidget {
  const ReferrersPage({super.key});

  @override
  State<ReferrersPage> createState() => _ReferrersPageState();
}

class _ReferrersPageState extends State<ReferrersPage> {
  late final ShopRepository _repo;

  List<ShopReferrer> _items = const [];
  bool _loading = true;
  String? _error;
  bool _activeOnly = false;
  final _searchCtrl = TextEditingController();

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
      final list = await _repo.referrerList(
        activeOnly: _activeOnly,
        search: _searchCtrl.text,
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

  Future<void> _openForm([ShopReferrer? r]) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReferrerSheet(repo: _repo, referrer: r),
    );
    if (ok == true) await _load();
  }

  Future<void> _delete(ShopReferrer r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف معرف', style: TextStyle(fontSize: 14)),
        content: Text(
          'آیا از حذف معرف «${r.name}» مطمئن هستید؟',
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
      await _repo.deleteReferrer(r.id);
      _toast('معرف حذف شد.', ok: true);
      await _load();
    } catch (e) {
      _toast(_clean(e));
    }
  }

  void _showCard(ShopReferrer r) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'کارت ویزیت — ${r.name}',
          style: const TextStyle(fontSize: 13.5),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [ShopColors.seed, ShopColors.indigo],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  if ((r.companyName ?? '').isNotEmpty)
                    Text(
                      r.companyName!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  const SizedBox(height: 10),
                  if ((r.phone ?? '').isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          r.phone!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  if ((r.cardNumber ?? '').isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.credit_card_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          r.cardNumber!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  if ((r.iban ?? '').isNotEmpty)
                    Text(
                      'IR${r.iban}',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: const Text(
          'معرف‌ها',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add_rounded, size: 22),
            tooltip: 'معرف جدید',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ShopEmpty(
              title: 'دریافت معرف‌ها ناموفق بود',
              subtitle: _error,
              icon: Icons.error_outline_rounded,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
                children: [
                  ShopHeader(
                    title: 'معرف‌ها',
                    subtitle: 'بازاریاب‌ها و درصد پورسانت فروش کالا و خدمات',
                    icon: Icons.badge_rounded,
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
                        TextField(
                          controller: _searchCtrl,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _load(),
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'جستجوی نام معرف…',
                            hintStyle: TextStyle(fontSize: 11.5),
                            prefixIcon: Icon(Icons.search_rounded, size: 17),
                          ),
                        ),
                        Row(
                          children: [
                            const Text(
                              'فقط فعال‌ها',
                              style: TextStyle(
                                fontSize: 11,
                                color: ShopColors.inkSoft,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Switch(
                              value: _activeOnly,
                              onChanged: (v) {
                                setState(() => _activeOnly = v);
                                _load();
                              },
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _load,
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 14),
                              label: const Text(
                                'بازخوانی',
                                style: TextStyle(fontSize: 10),
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
                        subtitle: 'با دکمهٔ + یک معرف جدید ثبت کنید.',
                        icon: Icons.person_outline_rounded,
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
          children: [
            Expanded(
              child: Text(
                r.name,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ShopTag(
              text: r.isActive ? 'فعال' : 'غیرفعال',
              color: r.isActive ? ShopColors.ok : ShopColors.inkFaint,
            ),
          ],
        ),
        Text(
          [(r.companyName ?? ''), (r.phone ?? '')]
              .where((e) => e.isNotEmpty)
              .join(' — ')
              .ifEmpty('—'),
          style: const TextStyle(fontSize: 10, color: ShopColors.inkFaint),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: _statBox(
                'پورسانت کالا (از سود)',
                '${_num(r.goodsCommissionPercent)}٪',
                ShopColors.seed,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _statBox(
                'پورسانت خدمات (از مبلغ)',
                '${_num(r.serviceCommissionPercent)}٪',
                ShopColors.indigo,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _statBox(
                'اسناد فروش',
                Fa.number(r.orderCount),
                ShopColors.inkSoft,
              ),
            ),
          ],
        ),
        if (r.maxDiscountPercent > 0) ...[
          const SizedBox(height: 6),
          ShopTag(
            text: 'سقف تخفیف ویزیتوری: ${_num(r.maxDiscountPercent)}٪',
            color: ShopColors.warn,
            icon: Icons.percent_rounded,
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showCard(r),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  foregroundColor: ShopColors.ok,
                  side: BorderSide(color: ShopColors.ok.withValues(alpha: 0.4)),
                ),
                icon: const Icon(Icons.contact_page_rounded, size: 15),
                label: const Text('کارت', style: TextStyle(fontSize: 10.5)),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openForm(r),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  foregroundColor: ShopColors.seed,
                  side: BorderSide(
                    color: ShopColors.seed.withValues(alpha: 0.4),
                  ),
                ),
                icon: const Icon(Icons.edit_rounded, size: 15),
                label: const Text('ویرایش', style: TextStyle(fontSize: 10.5)),
              ),
            ),
            const SizedBox(width: 6),
            OutlinedButton(
              onPressed: () => _delete(r),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(42, 38),
                padding: EdgeInsets.zero,
                foregroundColor: ShopColors.danger,
                side: BorderSide(
                  color: ShopColors.danger.withValues(alpha: 0.35),
                ),
              ),
              child: const Icon(Icons.delete_outline_rounded, size: 16),
            ),
          ],
        ),
      ],
    ),
  );

  static String _num(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  Widget _statBox(String label, String value, Color color) => Container(
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 8.5, color: ShopColors.inkFaint),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    ),
  );
}

extension _EmptyExt on String {
  String ifEmpty(String alt) => trim().isEmpty ? alt : this;
}

/// فرم ثبت/ویرایش معرف — معادل مودال وب
class _ReferrerSheet extends StatefulWidget {
  const _ReferrerSheet({required this.repo, this.referrer});

  final ShopRepository repo;
  final ShopReferrer? referrer;

  @override
  State<_ReferrerSheet> createState() => _ReferrerSheetState();
}

class _ReferrerSheetState extends State<_ReferrerSheet> {
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _phone = TextEditingController();
  final _goods = TextEditingController();
  final _service = TextEditingController();
  final _card = TextEditingController();
  final _iban = TextEditingController();
  final _cap = TextEditingController();
  bool _canViewProducts = false;
  bool _isActive = true;
  bool _saving = false;

  bool get _editing => (widget.referrer?.id ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    final r = widget.referrer;
    if (r != null) {
      _name.text = r.name;
      _company.text = r.companyName ?? '';
      _phone.text = r.phone ?? '';
      _goods.text = r.goodsCommissionPercent == 0
          ? ''
          : _plain(r.goodsCommissionPercent);
      _service.text = r.serviceCommissionPercent == 0
          ? ''
          : _plain(r.serviceCommissionPercent);
      _card.text = r.cardNumber ?? '';
      _iban.text = r.iban ?? '';
      _cap.text = r.maxDiscountPercent == 0
          ? ''
          : _plain(r.maxDiscountPercent);
      _canViewProducts = r.canViewProducts;
      _isActive = r.isActive;
    }
  }

  static String _plain(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void dispose() {
    for (final c in [
      _name,
      _company,
      _phone,
      _goods,
      _service,
      _card,
      _iban,
      _cap,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _toast('نام معرف را وارد کنید.');
      return;
    }
    final cap = parseNum(_cap.text).clamp(0, 100).toDouble();
    final r = ShopReferrer(
      id: widget.referrer?.id ?? 0,
      name: _name.text.trim(),
      companyName: _company.text.trim().isEmpty ? null : _company.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      goodsCommissionPercent: parseNum(_goods.text),
      serviceCommissionPercent: parseNum(_service.text),
      cardNumber: _card.text.trim().isEmpty ? null : _card.text.trim(),
      iban: _iban.text.trim().isEmpty ? null : _iban.text.trim(),
      canViewProducts: _canViewProducts,
      maxDiscountPercent: cap,
      isActive: _isActive,
    );
    setState(() => _saving = true);
    try {
      await widget.repo.saveReferrer(r);
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
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
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
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  Text(
                    _editing ? 'ویرایش معرف' : 'معرف جدید',
                    style: const TextStyle(
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
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  ShopField(
                    label: 'نام معرف',
                    required: true,
                    child: TextField(
                      controller: _name,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: _dec(null),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ShopField(
                    label: 'نام مجموعه',
                    hint: 'شرکت / فروشگاه / مجموعه',
                    child: TextField(
                      controller: _company,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: _dec('شرکت / فروشگاه / مجموعه'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ShopField(
                    label: 'تلفن',
                    child: TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: _dec(null),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ShopField(
                          label: 'درصد پورسانت کالا',
                          hint: 'بر مبنای سود سطرهای کالا',
                          child: TextField(
                            controller: _goods,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: _dec('0'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ShopField(
                          label: 'درصد پورسانت خدمات',
                          hint: 'بر مبنای کل مبلغ خدمات',
                          child: TextField(
                            controller: _service,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: _dec('0'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ShopField(
                    label: 'شماره کارت',
                    hint: '۱۶ رقم — برای واریز پورسانت',
                    child: TextField(
                      controller: _card,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      maxLength: 16,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 12.5),
                      decoration: _dec('6037xxxxxxxxxxxx'),
                    ),
                  ),
                  ShopField(
                    label: 'شماره شبا (IBAN)',
                    hint: '۲۴ رقم بعد از IR',
                    child: TextField(
                      controller: _iban,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      maxLength: 24,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 12.5),
                      decoration: _dec('IRxxxxxxxxxxxxxxxxxxxxxxxx'),
                    ),
                  ),
                  ShopField(
                    label: 'سقف تخفیف در سفارش ویزیتوری (٪)',
                    hint:
                        '۰ یا خالی = بدون سقف؛ عبور از سقف، سفارش را «نیازمند تأیید ویژه» می‌کند.',
                    child: TextField(
                      controller: _cap,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: _dec('0'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile.adaptive(
                    value: _canViewProducts,
                    onChanged: (v) => setState(() => _canViewProducts = v),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'اجازه مشاهده «کالاهای موجود» در پنل معرف',
                      style: TextStyle(fontSize: 11.5),
                    ),
                    subtitle: const Text(
                      'در صورت فعال بودن، این معرف در پنل خودش فهرست کالاهای دارای موجودی '
                      '(نام، کد، قیمت فروش) را می‌بیند — بدون قیمت خرید و مقدار موجودی.',
                      style: TextStyle(fontSize: 9, color: ShopColors.inkFaint),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'وضعیت',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: ShopColors.inkSoft,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<bool>(
                          value: true,
                          // ignore: deprecated_member_use
                          groupValue: _isActive,
                          // ignore: deprecated_member_use
                          onChanged: (v) =>
                              setState(() => _isActive = v ?? true),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'فعال',
                            style: TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<bool>(
                          value: false,
                          // ignore: deprecated_member_use
                          groupValue: _isActive,
                          // ignore: deprecated_member_use
                          onChanged: (v) =>
                              setState(() => _isActive = v ?? false),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'غیرفعال',
                            style: TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving
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
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            backgroundColor: ShopColors.seed,
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
                              : const Icon(Icons.save_rounded, size: 17),
                          label: const Text(
                            'ذخیره',
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

  InputDecoration _dec(String? hint) => InputDecoration(
    isDense: true,
    filled: true,
    fillColor: ShopColors.bg,
    hintText: hint,
    counterText: '',
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
