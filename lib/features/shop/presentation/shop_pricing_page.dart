// ============================================================
//  قیمت‌گذاری و حداقل سود — آینهٔ دقیق `/shop/pricing` در وب
//    ۱) سیاست حداقل سود فروش روی آخرین خرید معتبر تا تاریخ فاکتور
//    ۲) اصلاح گروهی قیمت فروش کالاها (پیش‌نمایش + اعمال با تاریخ اجرا)
//    ۳) جدول سابقهٔ ۲۰۰ تغییر آخر قیمت فروش در شرکت فعال
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
import '../models/shop_models.dart';
import 'shop_style.dart';

class ShopPricingPage extends StatefulWidget {
  const ShopPricingPage({super.key});

  @override
  State<ShopPricingPage> createState() => _ShopPricingPageState();
}

class _ShopPricingPageState extends State<ShopPricingPage> {
  late final ShopRepository _repo;
  late final ShopPerms _perms;

  final _markupCtrl = TextEditingController(text: '0');
  final _percentCtrl = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  String? _error;

  ShopPricingPolicy _policy = ShopPricingPolicy();
  bool _savedMinimumEnabled = false;
  double _savedMarkup = 0;

  List<ShopLookup> _categories = const [];
  List<ShopPriceHistoryItem> _history = const [];

  int _categoryId = 0;
  bool _increase = true;
  bool _includeDescendants = false;
  DateTime _effectiveDate = DateTime.now();

  ShopPriceAdjustmentPreview? _preview;
  ShopPriceAdjustmentRequest? _previewRequest;
  String _operationId = '';

  bool get _canView => _perms.canSeePricing;
  bool get _canManage => _perms.canManagePricing;

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _perms = ShopPerms(context.read<AuthController>().session);
    _load();
  }

  @override
  void dispose() {
    _markupCtrl.dispose();
    _percentCtrl.dispose();
    super.dispose();
  }

  static String _fmtPercent(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  static double? _tryPercent(String raw) {
    final clean = toEnDigits(raw).trim().replaceAll(',', '');
    if (clean.isEmpty) return null;
    final val = double.tryParse(clean);
    if (val == null || val < 0) return null;
    final parts = clean.split('.');
    if (parts.length > 2) return null;
    if (parts.length == 2 && parts[1].length > 2) return null;
    return val;
  }

  Future<void> _load() async {
    if (!_canView) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<ApiClient>().ensureCompanyId();
      final res = await Future.wait([
        _repo.pricingPolicy(),
        _repo.pricingCategories(),
        _repo.pricingHistory(take: 200),
      ]);
      if (!mounted) return;
      final policy = res[0] as ShopPricingPolicy;
      setState(() {
        _policy = policy;
        _savedMinimumEnabled = policy.minimumProfitEnabled;
        _savedMarkup = policy.minimumMarkupPercent;
        _markupCtrl.text = _fmtPercent(policy.minimumMarkupPercent);
        _categories = res[1] as List<ShopLookup>;
        _history = res[2] as List<ShopPriceHistoryItem>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _savePolicy() async {
    if (!_canManage || _busy) return;
    final markup = _tryPercent(_markupCtrl.text);
    if (markup == null || markup > 10000) {
      _toast('درصد سود معتبر نیست.');
      return;
    }
    setState(() => _busy = true);
    try {
      _policy.minimumMarkupPercent = markup;
      final saved = await _repo.savePricingPolicy(_policy);
      if (!mounted) return;
      setState(() {
        _policy = saved;
        _savedMinimumEnabled = saved.minimumProfitEnabled;
        _savedMarkup = saved.minimumMarkupPercent;
        _markupCtrl.text = _fmtPercent(saved.minimumMarkupPercent);
      });
      _toast(
        _savedMinimumEnabled
            ? 'حداقل سود فعال و ذخیره شد.'
            : 'تنظیم ذخیره شد؛ کنترل حداقل سود غیرفعال است.',
        ok: true,
      );
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  ShopPriceAdjustmentRequest? _buildRequest() {
    final pct = _tryPercent(_percentCtrl.text);
    if (_categoryId <= 0 ||
        pct == null ||
        pct <= 0 ||
        pct > (_increase ? 10000 : 100)) {
      return null;
    }
    final d = DateTime(
      _effectiveDate.year,
      _effectiveDate.month,
      _effectiveDate.day,
    );
    return ShopPriceAdjustmentRequest(
      categoryId: _categoryId,
      includeDescendants: _includeDescendants,
      increase: _increase,
      percent: pct,
      effectiveDate: d,
    );
  }

  Future<void> _loadPreview() async {
    if (!_canManage || _busy) return;
    final req = _buildRequest();
    if (req == null) {
      _toast('گروه، تاریخ و درصد معتبر را وارد کنید.');
      return;
    }
    setState(() {
      _busy = true;
      _preview = null;
    });
    try {
      final res = await _repo.previewPriceAdjustment(req);
      if (!mounted) return;
      setState(() {
        _preview = res;
        _previewRequest = req;
        _operationId = generateUuidV4();
      });
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _applyPreview() async {
    if (!_canManage || _busy) return;
    final current = _buildRequest();
    if (_preview == null ||
        _previewRequest == null ||
        current == null ||
        !current.sameAs(_previewRequest!)) {
      _toast('مشخصات تغییر کرده‌اند؛ دوباره پیش‌نمایش بگیرید.');
      return;
    }
    setState(() => _busy = true);
    try {
      await _repo.applyPriceAdjustment(
        current,
        previewHash: _preview!.previewHash,
        operationId: _operationId,
      );
      final hist = await _repo.pricingHistory(take: 200);
      if (!mounted) return;
      setState(() {
        _preview = null;
        _previewRequest = null;
        _history = hist;
      });
      _toast('تغییر قیمت ثبت شد.', ok: true);
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickEffectiveDate() async {
    final picked = await showJalaliDatePicker(
      context,
      initial: _effectiveDate,
      title: 'تاریخ اجرای قیمت جدید',
    );
    if (picked == null || !mounted) return;
    setState(() => _effectiveDate = picked);
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
                title: 'قیمت‌گذاری و حداقل سود',
                subtitle:
                    'کنترل حداقل سود فروش، اصلاح گروهی قیمت کالاها و سابقهٔ تغییرات قیمت',
                icon: Icons.sell_rounded,
                badge: 'فروشگاهی کایر',
              ),
            ),
            if (!_canView)
              const SliverPadding(
                padding: EdgeInsets.all(14),
                sliver: SliverToBoxAdapter(
                  child: ShopEmpty(
                    icon: Icons.lock_outline_rounded,
                    title: 'مجوز مشاهدهٔ قیمت‌گذاری را ندارید',
                    subtitle:
                        'برای مشاهده یا مدیریت این بخش، مجوز «قیمت‌گذاری و حداقل سود» لازم است.',
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
            else if (_error != null)
              SliverPadding(
                padding: const EdgeInsets.all(14),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      ShopEmpty(
                        icon: Icons.error_outline_rounded,
                        title: 'بارگذاری قیمت‌گذاری انجام نشد',
                        subtitle: _error,
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
                    _policyCard(),
                    const SizedBox(height: 12),
                    _bulkAdjustmentCard(),
                    const SizedBox(height: 12),
                    _historyCard(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _policyCard() {
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
                Icons.verified_user_rounded,
                size: 18,
                color: ShopColors.seed,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'حداقل سود فروش',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.ink,
                  ),
                ),
              ),
              ShopTag(
                text: _savedMinimumEnabled ? 'فعال' : 'غیرفعال',
                color: _savedMinimumEnabled
                    ? ShopColors.ok
                    : ShopColors.inkFaint,
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'اختیاری؛ مبلغ مبنا آخرین خرید معتبر کالا تا تاریخ فاکتور است. خدمات مشمول نیستند.',
            style: TextStyle(
              fontSize: 11,
              height: 1.6,
              color: ShopColors.inkFaint,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: ShopColors.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Switch(
                  value: _policy.minimumProfitEnabled,
                  onChanged: (!_canManage || _busy)
                      ? null
                      : (v) => setState(() => _policy.minimumProfitEnabled = v),
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'جلوگیری از فروش کمتر از حداقل سود',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: ShopColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'وضعیت ذخیره‌شده برای شرکت فعال: ${_savedMinimumEnabled ? 'فعال · ${Fa.digits(_fmtPercent(_savedMarkup))}٪ روی بهای خرید' : 'غیرفعال'} — تغییر کلید یا درصد تا ذخیره اعمال نمی‌شود.',
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.6,
              color: ShopColors.inkSoft,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: ShopField(
                  label: 'حداقل درصد روی بهای خرید',
                  child: TextField(
                    controller: _markupCtrl,
                    enabled: _canManage && !_busy,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      suffixText: '٪',
                    ),
                  ),
                ),
              ),
              if (_canManage) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _savePolicy,
                    style: FilledButton.styleFrom(
                      backgroundColor: ShopColors.seed,
                      minimumSize: const Size(124, 44),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 17),
                    label: const Text(
                      'ذخیره تنظیمات',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_policy.minimumProfitEnabled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ShopColors.warn.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: ShopColors.warn.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: ShopColors.warn,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'بدون خرید معتبر، فروش کالا متوقف می‌شود.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ShopColors.warn,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: const ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.only(bottom: 6),
              title: Text(
                'جزئیات محاسبه حداقل سود',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: ShopColors.seed,
                ),
              ),
              children: [
                Text(
                  'مثال: خرید ۱۰۰ و سود ۲۰٪ یعنی حداقل ۱۲۰، پیش از کسر پورسانت. کنترل پس از تخفیف و کسر پورسانت است؛ ارزش افزوده و تاخیر تادیه چک در آن محاسبه نمی‌شوند. برای اسناد هم‌تاریخ، ترتیب ثبت سند ملاک است.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.7,
                    color: ShopColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          if (_policy.updatedAt != null)
            Text(
              'آخرین تغییر: ${Fa.date(_policy.updatedAt!.toIso8601String())} · ${_policy.updatedBy ?? '—'}',
              style: const TextStyle(fontSize: 10, color: ShopColors.inkFaint),
            ),
        ],
      ),
    );
  }

  Widget _bulkAdjustmentCard() {
    final preview = _preview;
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
              Icon(Icons.tune_rounded, size: 18, color: ShopColors.indigo),
              SizedBox(width: 8),
              Text(
                'تغییر گروهی قیمت فروش',
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
            'قیمت جدید از تاریخ انتخابی اعمال می‌شود؛ مبلغ فاکتورهای ثبت‌شده تغییر نمی‌کند.',
            style: TextStyle(
              fontSize: 11,
              height: 1.6,
              color: ShopColors.inkFaint,
            ),
          ),
          const SizedBox(height: 12),
          ShopField(
            label: 'گروه کالا',
            required: true,
            child: DropdownButtonFormField<int>(
              initialValue: _categoryId == 0 ? null : _categoryId,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              hint: const Text(
                'انتخاب گروه…',
                style: TextStyle(fontSize: 12),
              ),
              style: const TextStyle(fontSize: 12.5, color: ShopColors.ink),
              items: [
                for (final c in _categories)
                  DropdownMenuItem<int>(value: c.id, child: Text(c.name)),
              ],
              onChanged: (!_canManage || _busy)
                  ? null
                  : (v) => setState(() => _categoryId = v ?? 0),
            ),
          ),
          ShopField(
            label: 'نوع تغییر',
            child: ShopSegmented(
              labels: const ['افزایش قیمت', 'کاهش قیمت'],
              index: _increase ? 0 : 1,
              onChanged: (i) {
                if (!_canManage || _busy) return;
                setState(() => _increase = i == 0);
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: ShopField(
                  label: 'درصد تغییر',
                  required: true,
                  child: TextField(
                    controller: _percentCtrl,
                    enabled: _canManage && !_busy,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'مثلاً 15',
                      suffixText: '٪',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ShopField(
                  label: 'تاریخ اجرا',
                  required: true,
                  child: InkWell(
                    onTap: (!_canManage || _busy) ? null : _pickEffectiveDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ShopColors.line),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.event_rounded,
                            size: 16,
                            color: ShopColors.seed,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              jalaliShort(_effectiveDate),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: ShopColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: _includeDescendants,
            onChanged: (!_canManage || _busy)
                ? null
                : (v) => setState(() => _includeDescendants = v == true),
            title: const Text(
              'زیرگروه‌ها نیز اعمال شوند',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ShopColors.inkSoft,
              ),
            ),
          ),
          if (_canManage)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _loadPreview,
                icon: const Icon(Icons.visibility_rounded, size: 17),
                label: const Text(
                  'پیش‌نمایش تغییرات',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          if (preview != null) ...[
            const Divider(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'پیش‌نمایش (${_increase ? 'افزایش' : 'کاهش'} ${Fa.digits(_percentCtrl.text)}٪)',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: ShopColors.ink,
                    ),
                  ),
                ),
                ShopTag(
                  text:
                      '${Fa.number(preview.rows.length)} کالا · ${Fa.number(preview.changeableCount)} قابل تغییر',
                  color: ShopColors.indigo,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: preview.rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final r = preview.rows[i];
                  final canChange = r.newPrice != null;
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ShopColors.bg,
                      borderRadius: BorderRadius.circular(12),
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
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: ShopColors.ink,
                                ),
                              ),
                            ),
                            ShopTag(
                              text: r.reason ?? 'آماده',
                              color: canChange
                                  ? ShopColors.ok
                                  : ShopColors.warn,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${r.code}${!r.isActive ? ' · غیرفعال' : ''}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: ShopColors.inkFaint,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'قبلی: ${r.previousPrice != null ? money(r.previousPrice) : '—'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: ShopColors.inkSoft,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'جدید: ${r.newPrice != null ? money(r.newPrice) : '—'}',
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  color: canChange
                                      ? ShopColors.seed
                                      : ShopColors.inkFaint,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'مبالغ به ریال هستند. کالاهای بدون قیمت معتبر در تاریخ انتخابی تغییر نمی‌کنند.',
              style: TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
            ),
            if (_canManage) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_busy || preview.changeableCount == 0)
                      ? null
                      : _applyPreview,
                  style: FilledButton.styleFrom(
                    backgroundColor: ShopColors.ok,
                    minimumSize: const Size(0, 44),
                  ),
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text(
                    'تأیید و ثبت تغییرات',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _historyCard() {
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
                Icons.history_rounded,
                size: 18,
                color: ShopColors.teal,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'سابقه قیمت فروش',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.ink,
                  ),
                ),
              ),
              ShopTag(
                text: '${Fa.number(_history.length)} رکورد (۲۰۰ تغییر آخر)',
                color: ShopColors.teal,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'هنوز سابقه‌ای ثبت نشده است.',
                  style: TextStyle(fontSize: 12, color: ShopColors.inkFaint),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _history.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final h = _history[i];
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ShopColors.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ShopColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              h.productName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: ShopColors.ink,
                              ),
                            ),
                          ),
                          ShopTag(text: h.sourceTitle, color: ShopColors.seed),
                        ],
                      ),
                      if (h.productCode.isNotEmpty)
                        Text(
                          'کد: ${h.productCode}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: ShopColors.inkFaint,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'قبلی: ${h.previousPrice != null ? money(h.previousPrice) : '—'} ریال',
                              style: const TextStyle(
                                fontSize: 11,
                                color: ShopColors.inkSoft,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'جدید: ${money(h.price)} ریال',
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: ShopColors.ok,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'تاریخ اجرا: ${h.effectiveDate != null ? jalaliShort(h.effectiveDate!) : '—'}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: ShopColors.inkFaint,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${h.createdBy ?? '—'} · ${h.createdAt != null ? Fa.date(h.createdAt!.toIso8601String(), time: false) : '—'}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: ShopColors.inkFaint,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 8),
          const Text(
            'قیمت‌های پیش از نخستین سابقه مشخص نیستند و از فاکتورهای گذشته حدس زده نمی‌شوند.',
            style: TextStyle(fontSize: 10, color: ShopColors.inkFaint),
          ),
        ],
      ),
    );
  }
}
