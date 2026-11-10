// ============================================================
//  پنل معرف (نقش Referrer) — آینهٔ صفحه‌های وب:
//    Pages/Panel/MyWallet.razor   → /my-wallet    «کیف پول من»
//    Pages/Panel/MyProducts.razor → /my-products  «کالاهای موجود»
//    Pages/Panel/MyCard.razor     → /my-card      «کارت ویزیت من»
//
//  گیت‌ها عیناً وب:
//   • نقش معرف نباشد → «این صفحه مخصوص معرف‌هاست.»
//   • معرفی به حساب متصل نباشد → «هنوز معرفی به حساب کاربری شما متصل
//     نشده است. برای اتصال معرف با مدیر سیستم تماس بگیرید.»
//   • کالاها: بدون مجوز مشاهده → «دسترسی مشاهده کالاها برای شما فعال
//     نشده است» (ReferrerDashboard.CanViewProducts)
//   • منو: ReferrerPanel.MyWallet / .MyProducts / .MyCard
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/shop_repository.dart';
import '../models/report_models.dart';
import 'shop_style.dart';

bool isReferrerSession(AuthController auth) {
  final s = auth.session;
  if (s == null) return false;
  return s.role.toLowerCase() == 'referrer' ||
      (s.referrerId ?? 0) > 0;
}

/// پیام‌های مشترک سه صفحهٔ پنل معرف — همان متن وب
class _ReferrerGuard extends StatelessWidget {
  const _ReferrerGuard({
    required this.isReferrer,
    required this.referrerId,
    required this.title,
    required this.child,
  });

  final bool isReferrer;
  final int? referrerId;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isReferrer) {
      return _scaffold(
        title,
        const ShopEmpty(
          title: 'این صفحه مخصوص معرف‌هاست',
          subtitle: 'با نقش فعلی به این بخش دسترسی ندارید.',
          icon: Icons.lock_outline_rounded,
        ),
      );
    }
    if ((referrerId ?? 0) <= 0) {
      return _scaffold(
        title,
        const ShopEmpty(
          title: 'معرفی به حساب شما متصل نشده است',
          subtitle:
              'هنوز معرفی به حساب کاربری شما متصل نشده است. برای اتصال معرف با مدیر سیستم تماس بگیرید.',
          icon: Icons.person_search_rounded,
        ),
      );
    }
    return child;
  }

  Widget _scaffold(String title, Widget body) => Scaffold(
    backgroundColor: ShopColors.bg,
    appBar: AppBar(
      backgroundColor: ShopColors.surface,
      foregroundColor: ShopColors.ink,
      elevation: 0.5,
      title: Text(
        title,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
      ),
    ),
    body: Padding(padding: const EdgeInsets.all(16), child: body),
  );
}

// ------------------------------------------------------------
//  کیف پول من — /my-wallet
// ------------------------------------------------------------
class MyWalletPage extends StatefulWidget {
  const MyWalletPage({super.key});

  @override
  State<MyWalletPage> createState() => _MyWalletPageState();
}

class _MyWalletPageState extends State<MyWalletPage> {
  late final ShopRepository _repo;

  ReferrerDashboard? _dash;
  List<ReferrerPaymentRow> _payments = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _load();
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
      final dash = await _repo.myReferrerDashboard();
      final page = await _repo.myReferrerPayments();
      if (!mounted) return;
      setState(() {
        _dash = dash;
        _payments = page.items;
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

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    return _ReferrerGuard(
      isReferrer: isReferrerSession(auth),
      referrerId: auth.session?.referrerId,
      title: 'کیف پول من',
      child: Scaffold(
        backgroundColor: ShopColors.bg,
        appBar: AppBar(
          backgroundColor: ShopColors.surface,
          foregroundColor: ShopColors.ink,
          elevation: 0.5,
          title: const Text(
            'کیف پول من',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ShopEmpty(
                title: 'دریافت کیف پول ناموفق بود',
                subtitle: _error,
                icon: Icons.error_outline_rounded,
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
                  children: [
                    ShopHeader(
                      title: 'کیف پول من',
                      subtitle: 'همه اسناد دریافت پورسانت شما',
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                    if (_dash != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ShopKpi(
                              title: 'مانده کیف پول',
                              value: Fa.number(_dash!.walletBalance),
                              unit: 'ریال',
                              icon: Icons.account_balance_wallet_rounded,
                              color: ShopColors.seed,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ShopKpi(
                              title: 'جمع پورسانت',
                              value: Fa.number(_dash!.totalCommission),
                              unit: 'ریال',
                              icon: Icons.trending_up_rounded,
                              color: ShopColors.ok,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ShopKpi(
                              title: 'جمع دریافتی',
                              value: Fa.number(_dash!.totalPaid),
                              unit: 'ریال',
                              icon: Icons.payments_rounded,
                              color: ShopColors.indigo,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ShopKpi(
                              title: 'پورسانت ماه جاری',
                              value: Fa.number(_dash!.monthCommission),
                              unit: '${Fa.number(_dash!.orderCount)} سند فروش',
                              icon: Icons.calendar_month_rounded,
                              color: ShopColors.warn,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ShopColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ShopColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.receipt_long_rounded,
                                size: 15,
                                color: ShopColors.seed,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'اسناد دریافت',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (_payments.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Text(
                                'هنوز پرداختی ثبت نشده است',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: ShopColors.inkFaint,
                                ),
                              ),
                            )
                          else
                            for (final p in _payments)
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: ShopColors.bg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'سند ${p.number}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              color: ShopColors.seed,
                                            ),
                                          ),
                                          Text(
                                            '${p.date == null ? '—' : jalaliShort(p.date!)}'
                                            '${(p.description ?? '').isEmpty ? '' : ' — ${p.description}'}',
                                            style: const TextStyle(
                                              fontSize: 9,
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
                                        color: ShopColors.ok,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ------------------------------------------------------------
//  کالاهای موجود — /my-products
// ------------------------------------------------------------
class MyProductsPage extends StatefulWidget {
  const MyProductsPage({super.key});

  @override
  State<MyProductsPage> createState() => _MyProductsPageState();
}

class _MyProductsPageState extends State<MyProductsPage> {
  late final ShopRepository _repo;

  List<ReferrerProductItem> _items = const [];
  bool _loading = true;
  bool _noAccess = false;
  String? _error;
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dash = await _repo.myReferrerDashboard();
      if (!mounted) return;
      if (!dash.canViewProducts) {
        setState(() {
          _noAccess = true;
          _loading = false;
        });
        return;
      }
      final list = await _repo.myReferrerProducts(search: _searchCtrl.text);
      if (!mounted) return;
      setState(() {
        _items = list;
        _noAccess = false;
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

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    return _ReferrerGuard(
      isReferrer: isReferrerSession(auth),
      referrerId: auth.session?.referrerId,
      title: 'کالاهای موجود',
      child: Scaffold(
        backgroundColor: ShopColors.bg,
        appBar: AppBar(
          backgroundColor: ShopColors.surface,
          foregroundColor: ShopColors.ink,
          elevation: 0.5,
          title: const Text(
            'کالاهای موجود',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ShopEmpty(
                title: 'دریافت کالاها ناموفق بود',
                subtitle: _error,
                icon: Icons.error_outline_rounded,
              )
            : _noAccess
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: ShopEmpty(
                  title:
                      'دسترسی مشاهده کالاها برای شما فعال نشده است',
                  subtitle: 'برای فعال‌سازی با مدیر مجموعه تماس بگیرید.',
                  icon: Icons.lock_outline_rounded,
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
                  children: [
                    ShopHeader(
                      title: 'کالاهای موجود',
                      subtitle: 'فهرست کالاهای دارای موجودی — قیمت فروش روز',
                      icon: Icons.inventory_2_rounded,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchCtrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _load(),
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'جستجو در نام، کد یا گروه کالا…',
                        hintStyle: TextStyle(fontSize: 11.5),
                        prefixIcon: Icon(Icons.search_rounded, size: 17),
                      ),
                    ),
                    if (_items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 30),
                        child: ShopEmpty(
                          title: 'کالای موجودی یافت نشد',
                          subtitle: 'با عبارت دیگری جستجو کنید.',
                          icon: Icons.inbox_outlined,
                        ),
                      )
                    else
                      for (final p in _items) _card(p),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _card(ReferrerProductItem p) => Container(
    margin: const EdgeInsets.only(top: 9),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: ShopColors.line),
    ),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ShopColors.seed.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.inventory_2_rounded,
            size: 16,
            color: ShopColors.seed,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.name,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${p.code} — ${p.category ?? 'بدون گروه'} — ${p.unit}',
                style: const TextStyle(
                  fontSize: 9.5,
                  color: ShopColors.inkFaint,
                ),
              ),
            ],
          ),
        ),
        const ShopTag(text: 'موجود', color: ShopColors.ok),
      ],
    ),
  );
}

// ------------------------------------------------------------
//  کارت ویزیت من — /my-card
// ------------------------------------------------------------
class MyCardPage extends StatefulWidget {
  const MyCardPage({super.key});

  @override
  State<MyCardPage> createState() => _MyCardPageState();
}

class _MyCardPageState extends State<MyCardPage> {
  late final ShopRepository _repo;

  ReferrerDashboard? _dash;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await _repo.myReferrerDashboard();
      if (!mounted) return;
      setState(() {
        _dash = d;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    return _ReferrerGuard(
      isReferrer: isReferrerSession(auth),
      referrerId: auth.session?.referrerId,
      title: 'کارت ویزیت من',
      child: Scaffold(
        backgroundColor: ShopColors.bg,
        appBar: AppBar(
          backgroundColor: ShopColors.surface,
          foregroundColor: ShopColors.ink,
          elevation: 0.5,
          title: const Text(
            'کارت ویزیت من',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _dash == null
            ? const ShopEmpty(
                title: 'کارت در دسترس نیست',
                subtitle: 'اطلاعات معرف دریافت نشد.',
                icon: Icons.badge_outlined,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
                children: [
                  ShopHeader(
                    title: 'کارت ویزیت من',
                    subtitle: 'پیش‌نمایش کارت معرف',
                    icon: Icons.contact_page_rounded,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [ShopColors.seed, ShopColors.indigo],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.badge_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _dash!.referrerName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if ((_dash!.companyName ?? '').isNotEmpty)
                                    Text(
                                      _dash!.companyName!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if ((_dash!.phone ?? '').isNotEmpty)
                          Row(
                            children: [
                              const Icon(
                                Icons.phone_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _dash!.phone!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'پورسانت کالا: ${Fa.number(_dash!.goodsCommissionPercent, decimals: 2)}٪ از سود',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'پورسانت خدمات: ${Fa.number(_dash!.serviceCommissionPercent, decimals: 2)}٪ از مبلغ',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.9),
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
}
