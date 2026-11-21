// ============================================================
//  تنظیمات فروشگاه — آینهٔ دقیق `/shop/print-settings` در وب
//    ۱) سقف تخفیف سفارش ویزیتوری به تفکیک هر ویزیتور فعال شرکت
//    ۲) شماره کارت‌ها (۱۶ رقم) و شباهای (۲۴ رقم + IR) فروشنده برای چاپ فاکتور
//    ۳) پیش‌نمایش زندهٔ کادر فروشنده در چاپ فاکتور
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../data/fa_num.dart';
import '../data/shop_identifier_rules.dart';
import '../data/shop_perms.dart';
import '../data/shop_repository.dart';
import '../models/shop_models.dart';
import 'shop_style.dart';

class ShopPrintSettingsPage extends StatefulWidget {
  const ShopPrintSettingsPage({super.key});

  @override
  State<ShopPrintSettingsPage> createState() => _ShopPrintSettingsPageState();
}

class _BankRowVm {
  _BankRowVm({String card = '', String iban = ''})
    : cardCtrl = TextEditingController(text: card),
      ibanCtrl = TextEditingController(text: iban);

  final TextEditingController cardCtrl;
  final TextEditingController ibanCtrl;
  final FocusNode cardFocus = FocusNode();
  final FocusNode ibanFocus = FocusNode();

  String get card => cardCtrl.text;
  String get iban => ibanCtrl.text;

  void dispose() {
    cardCtrl.dispose();
    ibanCtrl.dispose();
    cardFocus.dispose();
    ibanFocus.dispose();
  }
}

class _VisitorRowVm {
  _VisitorRowVm(this.dto)
    : ctrl = TextEditingController(
        text: dto.maxDiscountPercent == dto.maxDiscountPercent.roundToDouble()
            ? dto.maxDiscountPercent.toInt().toString()
            : dto.maxDiscountPercent.toStringAsFixed(2).replaceAll(
                RegExp(r'\.?0+$'),
                '',
              ),
      );

  final ShopVisitorDiscount dto;
  final TextEditingController ctrl;

  void dispose() => ctrl.dispose();
}

class _ShopPrintSettingsPageState extends State<ShopPrintSettingsPage> {
  late final ShopRepository _repo;
  late final ShopPerms _perms;

  final List<_BankRowVm> _rows = [];
  final List<_VisitorRowVm> _visitors = [];

  ShopCompanyProfile? _profile;
  bool _loading = true;
  bool _busy = false;
  bool _visitorBusy = false;
  String? _loadError;
  String? _error;
  String? _visitorError;

  bool get _canView => _perms.canSeePrintSettings;
  bool get _canManage => _perms.canManagePrintSettings;

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _perms = ShopPerms(context.read<AuthController>().session);
    _load();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    for (final v in _visitors) {
      v.dispose();
    }
    super.dispose();
  }

  void _setRows(ShopPrintSettings settings) {
    for (final r in _rows) {
      r.dispose();
    }
    _rows.clear();
    for (final b in settings.banks) {
      final card = ShopIdentifierRules.digitsOnly(b.card, maxLength: 16);
      final rawIban = ShopIdentifierRules.normalizeIban(b.iban) ?? '';
      final iban = ShopIdentifierRules.digitsOnly(rawIban, maxLength: 24);
      _rows.add(_BankRowVm(card: card, iban: iban));
    }
    if (_rows.isEmpty) {
      _rows.add(_BankRowVm());
    }
  }

  void _setVisitors(List<ShopVisitorDiscount> list) {
    for (final v in _visitors) {
      v.dispose();
    }
    _visitors
      ..clear()
      ..addAll(list.map(_VisitorRowVm.new));
  }

  Future<void> _load() async {
    if (!_canView) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
      _error = null;
      _visitorError = null;
    });
    try {
      await context.read<ApiClient>().ensureCompanyId();
      final results = await Future.wait([
        _repo.companyProfile(),
        _repo.shopPrintSettings(),
      ]);
      if (!mounted) return;
      _profile = results[0] as ShopCompanyProfile;
      _setRows(results[1] as ShopPrintSettings);

      try {
        final vis = await _repo.shopVisitorDiscounts();
        if (!mounted) return;
        _setVisitors(vis);
      } catch (e) {
        _visitorError = e.toString();
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  static double? _parsePercent2Decimals(String raw) {
    final clean = toEnDigits(raw).trim().replaceAll(',', '');
    if (clean.isEmpty) return null;
    final val = double.tryParse(clean);
    if (val == null) return null;
    final parts = clean.split('.');
    if (parts.length > 2) return null;
    if (parts.length == 2 && parts[1].length > 2) return null;
    return val;
  }

  Future<void> _saveVisitor(_VisitorRowVm vm) async {
    if (!_canManage || _visitorBusy) return;
    final val = _parsePercent2Decimals(vm.ctrl.text);
    if (val == null || val < 0 || val > 100) {
      setState(() {
        _visitorError =
            'سقف تخفیف باید بین صفر و صد و حداکثر با دو رقم اعشار باشد.';
      });
      return;
    }
    setState(() {
      _visitorBusy = true;
      _visitorError = null;
    });
    try {
      vm.dto.maxDiscountPercent = val;
      await _repo.saveShopVisitorDiscount(vm.dto);
      if (!mounted) return;
      _toast('سقف تخفیف ویزیتور ذخیره شد.', ok: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _visitorError = e.toString());
    } finally {
      if (mounted) setState(() => _visitorBusy = false);
    }
  }

  bool _invalidCard(_BankRowVm row) {
    final c = row.card;
    if (c.isEmpty) return false;
    if (c.length != 16 || !ShopIdentifierRules.isDigits(c)) return true;
    return _rows.where((r) => r.card == c).length > 1;
  }

  bool _invalidIban(_BankRowVm row) {
    final ib = row.iban;
    if (ib.isEmpty) return false;
    if (ib.length != 24 || !ShopIdentifierRules.isDigits(ib)) return true;
    return _rows.where((r) => r.iban == ib).length > 1;
  }

  void _onCardChanged(_BankRowVm row, String value) {
    final digits = ShopIdentifierRules.digitsOnly(value, maxLength: 16);
    if (digits != value) {
      row.cardCtrl.value = TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
    }
    setState(() => _error = null);
    // پرش خودکار به شبا به محض تکمیل ۱۶ رقم کارت (عین رفتار وب)
    if (digits.length == 16) {
      row.ibanFocus.requestFocus();
    }
  }

  void _onIbanChanged(_BankRowVm row, String value) {
    var clean = toEnDigits(value).toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
    if (clean.startsWith('IR')) clean = clean.substring(2);
    final digits = ShopIdentifierRules.digitsOnly(clean, maxLength: 24);
    if (digits != value) {
      row.ibanCtrl.value = TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
    }
    setState(() => _error = null);
  }

  void _addRow() {
    if (!_canManage || _rows.length >= 30) return;
    final next = _BankRowVm();
    setState(() => _rows.add(next));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) next.cardFocus.requestFocus();
    });
  }

  void _removeRow(_BankRowVm row) {
    if (!_canManage || _busy) return;
    setState(() {
      _rows.remove(row);
      row.dispose();
      if (_rows.isEmpty) _rows.add(_BankRowVm());
    });
  }

  ShopPrintSettings _validateAndBuild() {
    if (_rows.length > 30) {
      throw const FormatException('حداکثر ۳۰ ردیف اطلاعات بانکی مجاز است.');
    }
    final cards = <String>{};
    final ibans = <String>{};
    final out = <ShopPrintBank>[];

    for (final r in _rows) {
      final card = ShopIdentifierRules.digitsOnly(r.card);
      final ibanDigits = ShopIdentifierRules.digitsOnly(r.iban);
      if (card.isEmpty && ibanDigits.isEmpty) continue;
      if (card.isNotEmpty && card.length != 16) {
        throw const FormatException('شماره کارت باید دقیقاً ۱۶ رقم باشد.');
      }
      if (ibanDigits.isNotEmpty && ibanDigits.length != 24) {
        throw const FormatException('شبا باید IR و دقیقاً ۲۴ رقم باشد.');
      }
      if ((card.isNotEmpty && !cards.add(card)) ||
          (ibanDigits.isNotEmpty && !ibans.add(ibanDigits))) {
        throw const FormatException('شماره کارت یا شبا تکراری است.');
      }
      out.add(
        ShopPrintBank(
          card: card,
          iban: ibanDigits.isEmpty ? '' : 'IR$ibanDigits',
        ),
      );
    }
    return ShopPrintSettings(banks: out);
  }

  Future<void> _saveBanks() async {
    if (!_canManage || _busy) return;
    ShopPrintSettings payload;
    try {
      payload = _validateAndBuild();
    } on FormatException catch (e) {
      setState(() => _error = e.message);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await _repo.saveShopPrintSettings(payload);
      if (!mounted) return;
      setState(() => _setRows(saved));
      _toast('تنظیمات چاپ ذخیره شد.', ok: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? ShopColors.ok : ShopColors.danger,
      ),
    );
  }

  Uint8List? _decodeLogoBytes(String? dataUrl) {
    if (dataUrl == null || !dataUrl.startsWith('data:image')) return null;
    final comma = dataUrl.indexOf(',');
    if (comma < 0 || comma + 1 >= dataUrl.length) return null;
    try {
      return base64Decode(dataUrl.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShopColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: ShopHeader(
                title: 'تنظیمات فروشگاه',
                subtitle: 'چاپ و فروش ویزیتوری · مستقل برای شرکت فعال',
                icon: Icons.print_rounded,
                badge: 'فروشگاهی کایر',
              ),
            ),
            if (!_canView)
              const SliverPadding(
                padding: EdgeInsets.all(14),
                sliver: SliverToBoxAdapter(
                  child: ShopEmpty(
                    icon: Icons.lock_outline_rounded,
                    title: 'مجوز مشاهدهٔ تنظیمات فروشگاه را ندارید',
                    subtitle:
                        'برای مشاهده یا ویرایش این بخش، مجوز «تنظیمات فروشگاه» را از مدیر سیستم دریافت کنید.',
                  ),
                ),
              )
            else if (_loading)
              const SliverPadding(
                padding: EdgeInsets.symmetric(vertical: 60),
                sliver: SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_loadError != null)
              SliverPadding(
                padding: const EdgeInsets.all(14),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      ShopEmpty(
                        icon: Icons.error_outline_rounded,
                        title: 'بارگذاری تنظیمات انجام نشد',
                        subtitle: _loadError,
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('تلاش دوباره'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
                sliver: SliverList.list(
                  children: [
                    _visitorSection(),
                    const SizedBox(height: 12),
                    _banksSection(),
                    const SizedBox(height: 12),
                    _previewSection(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _visitorSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.directions_walk_rounded,
                size: 18,
                color: ShopColors.seed,
              ),
              SizedBox(width: 8),
              Text(
                'تنظیمات فروش ویزیتوری',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'سقف تخفیف برای هر ویزیتور فعالِ شرکت انتخاب‌شده جداگانه تنظیم می‌شود. مقدار صفر یعنی تخفیف مجاز نیست.',
            style: TextStyle(
              fontSize: 11,
              height: 1.6,
              color: ShopColors.inkFaint,
            ),
          ),
          if (_visitorError != null) ...[
            const SizedBox(height: 8),
            Text(
              _visitorError!,
              style: const TextStyle(
                fontSize: 11.5,
                color: ShopColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (_visitors.isEmpty && _visitorError == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ShopColors.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'ویزیتور فعالی با مجوز ثبت سفارش در این شرکت یافت نشد.',
                style: TextStyle(fontSize: 11.5, color: ShopColors.inkSoft),
              ),
            )
          else
            for (final vm in _visitors)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: ShopColors.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ShopColors.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          vm.dto.userName,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: ShopColors.ink,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 88,
                        child: TextField(
                          controller: vm.ctrl,
                          enabled: _canManage && !_visitorBusy,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            suffixText: '٪',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 9,
                            ),
                          ),
                        ),
                      ),
                      if (_canManage) ...[
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: _visitorBusy
                              ? null
                              : () => _saveVisitor(vm),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(64, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text(
                            'ذخیره',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _banksSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.credit_card_rounded,
                size: 18,
                color: ShopColors.seed,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'کارت‌ها و شباهای فروشنده',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.ink,
                  ),
                ),
              ),
              ShopTag(
                text: '${Fa.digits(_rows.length)} / ۳۰',
                color: ShopColors.indigo,
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'شماره کارت ۱۶ رقم و شبا ۲۴ رقم بدون IR است. مالکیت و صحت بانکی حساب بررسی نمی‌شود.',
            style: TextStyle(
              fontSize: 11,
              height: 1.6,
              color: ShopColors.inkFaint,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _rows.length; i++) _bankRowCard(i, _rows[i]),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 11.5,
                color: ShopColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (_canManage) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_busy || _rows.length >= 30) ? null : _addRow,
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: const Text(
                      'افزودن کارت / شبا',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _saveBanks,
                    style: FilledButton.styleFrom(
                      backgroundColor: ShopColors.seed,
                    ),
                    icon: _busy
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
                      'ذخیره تنظیمات',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'نام، تلفن و نشانی از تعریف شرکت خوانده می‌شوند. مشخصات مشتری از سند مربوط خوانده می‌شود و اینجا ورودی ندارد. اندازهٔ کاغذ فقط هنگام چاپ انتخاب می‌شود.',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.6,
              color: ShopColors.inkFaint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bankRowCard(int index, _BankRowVm row) {
    final badCard = _invalidCard(row);
    final badIban = _invalidIban(row);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ShopColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: (badCard || badIban)
                ? ShopColors.danger.withValues(alpha: 0.5)
                : ShopColors.line,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'حساب فروشنده ${Fa.digits(index + 1)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: ShopColors.inkSoft,
                  ),
                ),
                const Spacer(),
                if (_canManage)
                  InkWell(
                    onTap: _busy ? null : () => _removeRow(row),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 15,
                            color: ShopColors.danger,
                          ),
                          SizedBox(width: 2),
                          Text(
                            'حذف',
                            style: TextStyle(
                              fontSize: 11,
                              color: ShopColors.danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ShopField(
              label: 'شماره کارت (۱۶ رقم)',
              child: TextField(
                controller: row.cardCtrl,
                focusNode: row.cardFocus,
                enabled: _canManage && !_busy,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                textDirection: TextDirection.ltr,
                maxLength: 16,
                onChanged: (v) => _onCardChanged(row, v),
                onSubmitted: (_) => row.ibanFocus.requestFocus(),
                style: const TextStyle(
                  fontSize: 13,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  counterText: '',
                  hintText: '6037991000000000',
                  errorText: badCard
                      ? 'شماره کارت باید دقیقاً ۱۶ رقم و غیرتکراری باشد.'
                      : null,
                ),
              ),
            ),
            ShopField(
              label: 'شماره شبا (۲۴ رقم بدون IR)',
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  controller: row.ibanCtrl,
                  focusNode: row.ibanFocus,
                  enabled: _canManage && !_busy,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  maxLength: 24,
                  onChanged: (v) => _onIbanChanged(row, v),
                  style: const TextStyle(
                    fontSize: 12.5,
                    letterSpacing: 0.7,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    prefixText: 'IR ',
                    prefixStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: ShopColors.seed,
                    ),
                    hintText: '000000000000000000000000',
                    errorText: badIban
                        ? 'شماره شبا باید دقیقاً ۲۴ رقم و غیرتکراری باشد.'
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewSection() {
    final activeRows = _rows
        .where((r) => r.card.isNotEmpty || r.iban.isNotEmpty)
        .toList();
    final logoBytes = _decodeLogoBytes(_profile?.logoDataUrl);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 18,
                color: ShopColors.teal,
              ),
              SizedBox(width: 8),
              Text(
                'پیش‌نمایش اطلاعات فروشنده',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xfffafcff),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: ShopColors.seed.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (logoBytes != null) ...[
                  SizedBox(
                    width: 106,
                    height: 64,
                    child: Image.memory(logoBytes, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  (_profile?.name ?? '').trim().isEmpty
                      ? '—'
                      : _profile!.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'تلفن: ${Fa.digits(_profile?.phone ?? '—')}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: ShopColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'نشانی: ${_profile?.address ?? '—'}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: ShopColors.inkSoft,
                  ),
                ),
                if (activeRows.isNotEmpty) ...[
                  const Divider(height: 18),
                  for (final r in activeRows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ShopColors.line),
                        ),
                        child: Column(
                          children: [
                            if (r.card.isNotEmpty)
                              Row(
                                children: [
                                  const Text(
                                    'شماره کارت',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: ShopColors.inkFaint,
                                    ),
                                  ),
                                  const Spacer(),
                                  Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                      Fa.digits(
                                        ShopIdentifierRules.groupBy4(r.card),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: ShopColors.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            if (r.card.isNotEmpty && r.iban.isNotEmpty)
                              const SizedBox(height: 4),
                            if (r.iban.isNotEmpty)
                              Row(
                                children: [
                                  const Text(
                                    'شماره شبا',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: ShopColors.inkFaint,
                                    ),
                                  ),
                                  const Spacer(),
                                  Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                      Fa.digits(
                                        ShopIdentifierRules.groupBy4(
                                          'IR${r.iban}',
                                        ),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: ShopColors.seed,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 6),
                const Text(
                  'تغییرات تا زمان ذخیره فقط در همین پیش‌نمایش دیده می‌شوند.',
                  style: TextStyle(fontSize: 10, color: ShopColors.inkFaint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
