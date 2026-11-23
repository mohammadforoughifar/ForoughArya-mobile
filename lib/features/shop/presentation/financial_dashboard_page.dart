// ============================================================
//  «داشبورد مالی» نسخهٔ وب در اندروید
//  آینهٔ ۱۰۰٪ دقیق:
//    • Inventory.Client/Shared/AdminHome.razor
//    • Inventory.Client/Pages/Panel/MyDashboard.razor
//    • Inventory.Api/Controllers/System/DashboardController.cs
//    • tests/ShopFinancialDashboard/test_financial_dashboard.py
//
//  کنترل دسترسی دقیق مطابق وب:
//    • نقش Referrer  → داشبورد اختصاصی معرف (`GET /api/my/dashboard`)
//    • سایر نقش‌ها   → فقط با مجوز `Dashboards.Financial`
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../data/fa_num.dart';
import '../data/shop_perms.dart';
import '../data/shop_repository.dart';
import '../models/financial_dashboard_models.dart';
import '../models/report_models.dart';
import 'expenses_page.dart';
import 'reorder_report_page.dart';
import 'shop_credit_page.dart';
import 'shop_style.dart';
import 'trs_cheques_page.dart';

const Color _warnSoft = Color(0xfffff7ed);

class FaNum {
  FaNum._();

  static String money(num v) => Fa.number(v.round());

  static String qty(num v) => v == v.roundToDouble()
      ? Fa.number(v.round())
      : Fa.number(v, decimals: 1);

  static String compact(num v) {
    final abs = v.abs();
    if (abs >= 1000000000) {
      return '${Fa.number(v / 1000000000, decimals: 1)} میلیارد';
    }
    if (abs >= 1000000) {
      return '${Fa.number(v / 1000000, decimals: 1)} م.ر';
    }
    return Fa.number(v.round());
  }
}

class FinancialDashboardPage extends StatefulWidget {
  const FinancialDashboardPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<FinancialDashboardPage> createState() => _FinancialDashboardPageState();
}

class _FinancialDashboardPageState extends State<FinancialDashboardPage> {
  ShopRepository get _repo => ShopRepository(context.read<ApiClient>());

  bool _loading = true;
  bool _busyAction = false;
  String? _loadedSessionSig;

  // دادهٔ داشبورد مالی (AdminHome.razor)
  DashboardSummaryDto _summary = const DashboardSummaryDto();
  AdminDashboardDto? _admin;
  List<RecentActivityDto> _recent = const [];
  List<ReorderItem> _lowStock = const [];
  final List<String> _loadErrors = [];

  // دادهٔ داشبورد معرف (MyDashboard.razor)
  ReferrerDashboard? _refDash;
  String? _refError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = Provider.of<AuthController?>(context)?.session;
    final sig =
        '${s?.userId}_${s?.role}_${s?.referrerId}_${s?.permissions.join(',')}';
    if (_loadedSessionSig != sig) {
      _loadedSessionSig = sig;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  String _todayJalaliLong() {
    final j = Jalali.now();
    final f = j.formatter;
    return '${f.wN} ${Fa.digits(j.day)} ${f.mN} ${Fa.digits(j.year)}';
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    final j = Jalali.fromDateTime(d);
    final mm = j.month.toString().padLeft(2, '0');
    final dd = j.day.toString().padLeft(2, '0');
    return Fa.digits('${j.year}/$mm/$dd');
  }

  Future<void> _loadSection(Future<void> Function() task, String label) async {
    try {
      await task();
    } catch (e) {
      _loadErrors.add('$label: $e');
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    final session = context.read<AuthController>().session;
    final perms = ShopPerms(session);

    setState(() {
      _loading = true;
      _loadErrors.clear();
      _refError = null;
    });

    try {
      if (session?.isReferrer == true) {
        if ((session?.referrerId ?? 0) <= 0) {
          if (mounted) setState(() => _loading = false);
          return;
        }
        try {
          final dash = await _repo.myReferrerDashboard();
          if (mounted) setState(() => _refDash = dash);
        } catch (e) {
          if (mounted) setState(() => _refError = e.toString());
        }
        return;
      }

      if (!perms.canSeeFinancialDashboard) {
        return;
      }

      // مطابق تست رسمی وب: بارگذاری هر ۴ بخش مستقل است تا خطای یکی (مثلاً نقطه سفارش)
      // هشدارهای چک و بدهکاران داشبورد مالی را پنهان نکند.
      await Future.wait<void>([
        _loadSection(() async {
          _admin = await _repo.adminFinancialDashboard();
        }, 'چک‌ها و بدهکاران / آمار مالی'),
        _loadSection(() async {
          _summary = await _repo.financialSummary();
        }, 'خلاصه فروشگاه'),
        _loadSection(() async {
          _recent = await _repo.dashboardRecent(count: 8);
        }, 'فعالیت‌های اخیر'),
        _loadSection(() async {
          final page = await _repo.reorderItems(take: 5);
          _lowStock = page.items.take(5).toList();
        }, 'کالاهای نیازمند سفارش'),
      ]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? ShopColors.danger : ShopColors.ok,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _pushPage(Widget page) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page)).then((_) {
      if (mounted) _load();
    });
  }

  /// مطابق `AdminHome.ClearCheque`: شناسه‌های چک خزانه/هزینه هرگز به endpoint فاکتور ارسال نمی‌شوند.
  Future<void> _handleClearCheque(ChequeAlertDto c) async {
    if (!c.isInvoiceSource) {
      if (c.source.trim().toLowerCase() == 'expense') {
        _pushPage(const ExpensesPage());
      } else {
        _pushPage(const TrsChequesPage());
      }
      return;
    }
    setState(() => _busyAction = true);
    try {
      await _repo.clearShopCheque(c.chequeId);
      _toast('وضعیت چک ${Fa.digits(c.number)} با موفقیت به وصول‌شده تغییر یافت.');
      final fresh = await _repo.adminFinancialDashboard();
      if (mounted) setState(() => _admin = fresh);
    } catch (e) {
      _toast(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _promptBounceCheque(ChequeAlertDto c) async {
    if (!c.isInvoiceSource) return;
    final ctrl = TextEditingController(text: 'عدم موجودی کافی');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: ShopColors.danger),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ثبت برگشت چک',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'آیا از ثبت برگشت چک شماره ${Fa.digits(c.number)} به مبلغ '
                  '${FaNum.money(c.amount)} ریال متعلق به «${c.partyName}» اطمینان دارید؟',
                  style: const TextStyle(fontSize: 12.5, height: 1.75),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _warnSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'با ثبت برگشت، این چک در وضعیت برگشتی قرار گرفته و حساب طرف حساب بدهکار باقی خواهد ماند.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.65,
                      color: Color(0xff92400e),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                    labelText: 'علت برگشت',
                    hintText: 'مثلاً: کسر موجودی، مسدودی حساب یا عدم تطابق امضا',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: ShopColors.danger),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.cancel_outlined, size: 17),
              label: const Text('ثبت قطعی برگشت چک'),
            ),
          ],
        ),
      ),
    );
    final reason = ctrl.text.trim();
    ctrl.dispose();
    if (confirmed != true) return;

    setState(() => _busyAction = true);
    try {
      await _repo.bounceShopCheque(c.chequeId, reason);
      _toast(
        'چک شماره ${Fa.digits(c.number)} مشتری «${c.partyName}» برگشت خورد.',
        error: true,
      );
      final fresh = await _repo.adminFinancialDashboard();
      if (mounted) setState(() => _admin = fresh);
    } catch (e) {
      _toast(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _promptSettleDebtor(OverdueDebtorDto d) async {
    final ctrl = TextEditingController(text: d.amount.toStringAsFixed(0));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'تسویه نسیه / اعتبار مشتری',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مشتری: ${d.partyName}\nسند: ${Fa.digits(d.number)} (${d.kind})',
                style: const TextStyle(fontSize: 12.5, height: 1.7),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: 'مبلغ تسویه (ریال)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: ShopColors.ok),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check_circle_outline, size: 17),
              label: const Text('ثبت تسویه'),
            ),
          ],
        ),
      ),
    );
    final raw = toEnDigits(ctrl.text).replaceAll(',', '').trim();
    final amount = double.tryParse(raw) ?? 0;
    ctrl.dispose();
    if (confirmed != true || amount <= 0) return;

    setState(() => _busyAction = true);
    try {
      await _repo.settleDashboardCredit(d.transactionId, amount);
      _toast('تسویه نسیه «${d.partyName}» با موفقیت ثبت شد.');
      await _load();
    } catch (e) {
      _toast(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthController>().session;
    final perms = ShopPerms(session);
    final isRef = session?.isReferrer == true;

    final body = Directionality(
      textDirection: TextDirection.rtl,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : isRef
          ? _buildReferrerBody(session?.referrerId)
          : !perms.canSeeFinancialDashboard
          ? _buildAccessDenied()
          : _buildFinancialBody(perms),
    );

    if (widget.embedded) {
      return Scaffold(backgroundColor: ShopColors.bg, body: body);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: ShopColors.bg,
        appBar: AppBar(
          backgroundColor: ShopColors.surface,
          foregroundColor: ShopColors.ink,
          elevation: 0.5,
          title: Text(
            isRef ? 'داشبورد من (پنل معرف)' : 'داشبورد مالی فروشگاه',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              tooltip: 'به‌روزرسانی',
              onPressed: _loading || _busyAction ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: body,
      ),
    );
  }

  Widget _buildAccessDenied() => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _warnSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ShopColors.warn.withValues(alpha: 0.35)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, color: ShopColors.warn, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'شما به «داشبورد مالی» دسترسی ندارید. از منو یکی از بخش‌های مجاز را انتخاب کنید.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.75,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff92400e),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  // ============================================================
  //  حالت معرف (`MyDashboard.razor` خطوط ۱۰ تا ۱۵۹)
  // ============================================================

  Widget _buildReferrerBody(int? referrerId) {
    if ((referrerId ?? 0) <= 0) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ShopEmpty(
            title: 'معرف به حساب کاربری متصل نیست',
            subtitle:
                'هنوز معرفی به حساب کاربری شما متصل نشده است. برای اتصال معرف با مدیر سیستم تماس بگیرید.',
            icon: Icons.info_outline_rounded,
          ),
        ],
      );
    }
    if (_refError != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ShopEmpty(
            title: 'بارگذاری داشبورد انجام نشد',
            subtitle: _refError!,
            icon: Icons.cloud_off_rounded,
          ),
        ],
      );
    }
    final d = _refDash ?? const ReferrerDashboard();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
        children: [
          ShopHeader(
            title: 'سلام، ${d.referrerName.isEmpty ? 'همکار گرامی' : d.referrerName}',
            subtitle:
                '${(d.companyName == null || d.companyName!.trim().isEmpty) ? 'پنل معرف' : d.companyName!} — '
                'پورسانت کالا ${Fa.number(d.goodsCommissionPercent)}٪ از سود | '
                'خدمات ${Fa.number(d.serviceCommissionPercent)}٪ از مبلغ',
            icon: Icons.workspace_premium_rounded,
            badge: 'پنل معرف',
          ),
          const SizedBox(height: 12),
          _responsiveTwoColGrid([
            _GradStatCard(
              title: 'مانده کیف پول',
              value: FaNum.money(d.walletBalance),
              unit: 'ریال',
              icon: Icons.account_balance_wallet_rounded,
              colors: const [Color(0xff2563eb), Color(0xff1d4ed8)],
            ),
            _GradStatCard(
              title: 'جمع پورسانت',
              value: FaNum.money(d.totalCommission),
              unit: 'ریال',
              icon: Icons.trending_up_rounded,
              colors: const [Color(0xff059669), Color(0xff047857)],
            ),
            _GradStatCard(
              title: 'جمع دریافتی',
              value: FaNum.money(d.totalPaid),
              unit: 'ریال',
              icon: Icons.payments_rounded,
              colors: const [Color(0xff0284c7), Color(0xff0369a1)],
            ),
            _GradStatCard(
              title: 'پورسانت ماه جاری',
              value: FaNum.money(d.monthCommission),
              unit: 'ریال — ${Fa.digits(d.orderCount)} سند فروش',
              icon: Icons.calendar_month_rounded,
              colors: const [Color(0xff7c3aed), Color(0xff5b21b6)],
            ),
          ]),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'آخرین فروش‌های دارای پورسانت',
            icon: Icons.receipt_long_rounded,
            iconColor: ShopColors.seed,
            child: d.recentSales.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'فروشی ثبت نشده است.',
                      style: TextStyle(fontSize: 12, color: ShopColors.inkSoft),
                    ),
                  )
                : Column(
                    children: [
                      for (final s in d.recentSales)
                        _RowItem(
                          leadingBadge: Fa.digits(s.number),
                          title: (s.customerName == null ||
                                  s.customerName!.trim().isEmpty)
                              ? '—'
                              : s.customerName!,
                          subtitle: _fmtDate(s.date),
                          amount: '${FaNum.money(s.commission)} ریال پورسانت',
                          subAmount: 'فاکتور: ${FaNum.money(s.amount)} ریال',
                          amountColor: ShopColors.ok,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'آخرین دریافتی‌ها',
            icon: Icons.savings_rounded,
            iconColor: ShopColors.ok,
            child: d.recentPayments.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'پرداختی ثبت نشده است.',
                      style: TextStyle(fontSize: 12, color: ShopColors.inkSoft),
                    ),
                  )
                : Column(
                    children: [
                      for (final p in d.recentPayments)
                        _RowItem(
                          leadingBadge: Fa.digits(p.number),
                          title: 'سند تسویه معرف',
                          subtitle: _fmtDate(p.date),
                          amount: '${FaNum.money(p.amount)} ریال',
                          amountColor: ShopColors.ok,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  داشبورد مالی اصلی (`AdminHome.razor`)
  // ============================================================

  Widget _buildFinancialBody(ShopPerms perms) {
    final admin = _admin;
    final d = _summary;
    final now = DateTime.now();

    return RefreshIndicator(
      onRefresh: _load,
      color: ShopColors.seed,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
        children: [
          ShopHeader(
            title: 'داشبورد مالی و مدیریتی',
            subtitle: 'خلاصه وضعیت انبار، خرید، فروش و چک‌ها — ${_todayJalaliLong()}',
            icon: Icons.speed_rounded,
            badge: 'مالی',
          ),

          if (_loadErrors.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _warnSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: ShopColors.warn.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'اطلاعات داشبورد کامل بارگذاری نشده است؛ مقادیر خالی را صفر قطعی در نظر نگیرید.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xff92400e),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final err in _loadErrors)
                    Text(
                      '• $err',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xff92400e),
                      ),
                    ),
                ],
              ),
            ),
          ],

          if (admin != null) ...[
            // ---------- ۱. فروش دوره‌ای ----------
            const SizedBox(height: 14),
            const _SubHeading(
              icon: Icons.shopping_cart_checkout_rounded,
              title: 'فروش دوره‌ای',
            ),
            const SizedBox(height: 8),
            _responsiveTwoColGrid([
              _GradStatCard(
                title: 'فروش امروز',
                value: FaNum.money(admin.salesToday),
                unit: 'ریال',
                icon: Icons.today_rounded,
                colors: const [Color(0xff2563eb), Color(0xff1d4ed8)],
              ),
              _GradStatCard(
                title: 'فروش هفته (از شنبه)',
                value: FaNum.money(admin.salesWeek),
                unit: 'ریال',
                icon: Icons.date_range_rounded,
                colors: const [Color(0xff059669), Color(0xff0f766e)],
              ),
              _GradStatCard(
                title: 'فروش ماه شمسی',
                value: FaNum.money(admin.salesMonth),
                unit: 'ریال',
                icon: Icons.calendar_month_rounded,
                colors: const [Color(0xff0284c7), Color(0xff0369a1)],
              ),
              _GradStatCard(
                title: 'فروش فصل جاری',
                value: FaNum.money(admin.salesQuarter),
                unit: 'ریال',
                icon: Icons.event_note_rounded,
                colors: const [Color(0xff7c3aed), Color(0xff5b21b6)],
              ),
            ]),

            // ---------- ۲. سود دوره‌ای ----------
            const SizedBox(height: 14),
            const _SubHeading(
              icon: Icons.trending_up_rounded,
              title: 'سود دوره‌ای',
            ),
            const SizedBox(height: 8),
            _responsiveTwoColGrid([
              _ProfitCard(title: 'سود امروز', value: admin.profitToday),
              _ProfitCard(title: 'سود هفته', value: admin.profitWeek),
              _ProfitCard(title: 'سود ماه', value: admin.profitMonth),
              _ProfitCard(title: 'سود فصل', value: admin.profitQuarter),
            ]),

            // ---------- ۳. گجت‌های نموداری ----------
            const SizedBox(height: 14),
            _SectionCard(
              title: 'فروش و سود ۶ ماه اخیر',
              icon: Icons.bar_chart_rounded,
              iconColor: const Color(0xff4f46e5),
              trailing: const _ChartLegend(
                items: [
                  (label: 'فروش', color: Color(0xff4f46e5)),
                  (label: 'سود', color: Color(0xff059669)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                child: _MonthlySalesProfitChart(points: admin.monthlyTrend),
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'تفکیک روش پرداخت (فصل جاری)',
              icon: Icons.pie_chart_rounded,
              iconColor: const Color(0xff059669),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                child: _PaymentMixView(admin: admin),
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'روند فروش ۳۰ روز اخیر',
              icon: Icons.show_chart_rounded,
              iconColor: const Color(0xffd97706),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                child: _DailySalesChart(points: admin.dailyTrend),
              ),
            ),

            // ---------- ۴. بدهکاران سررسیدشده ----------
            const SizedBox(height: 14),
            _SectionCard(
              title: 'بدهکاران سررسیدشده',
              icon: Icons.person_off_outlined,
              iconColor: ShopColors.danger,
              badge: admin.overdueDebtors.isNotEmpty
                  ? '${Fa.digits(admin.overdueDebtors.length)} مورد'
                  : null,
              badgeColor: ShopColors.danger,
              trailing: perms.canSeeInstallments
                  ? TextButton(
                      onPressed: () => _pushPage(const ShopCreditPage()),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      child: const Text(
                        'اقساط و چک‌ها',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  : null,
              child: admin.overdueDebtors.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'نسیه یا قسط فروشِ پرداخت‌نشده با سررسید امروز یا گذشته ثبت نشده است.',
                        style: TextStyle(
                          fontSize: 12,
                          color: ShopColors.inkSoft,
                          height: 1.65,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (final b in admin.overdueDebtors.take(8))
                          _DebtorAlertTile(
                            item: b,
                            dueLabel: _fmtDate(b.dueDate),
                            onSettle: _busyAction
                                ? null
                                : () => _promptSettleDebtor(b),
                          ),
                      ],
                    ),
            ),

            // ---------- ۵. چک‌های دریافتی مشتریان (امروز و معوق) ----------
            const SizedBox(height: 12),
            _SectionCard(
              title: 'چک‌های دریافتی مشتریان (امروز و معوق)',
              icon: Icons.account_balance_rounded,
              iconColor: ShopColors.seed,
              badge: admin.todayCheques.isNotEmpty
                  ? '${Fa.digits(admin.todayCheques.length)} چک'
                  : null,
              badgeColor: ShopColors.seed,
              trailing: perms.canSeeInstallments
                  ? TextButton(
                      onPressed: () => _pushPage(const ShopCreditPage()),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      child: const Text(
                        'مشاهدهٔ چک‌ها',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  : null,
              child: admin.todayCheques.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        admin.pendingReceivedChequesCount > 0
                            ? '${Fa.digits(admin.pendingReceivedChequesCount)} چک دریافتی باز دارید؛ موعد آن‌ها در آینده است.'
                            : 'چک دریافتی باز در فاکتورهای فروش ثبت نشده است.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: ShopColors.inkSoft,
                          height: 1.65,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (final c in admin.todayCheques)
                          _ChequeAlertTile(
                            cheque: c,
                            issued: false,
                            dueLabel: _fmtDate(c.dueDate),
                            daysPastDue: c.daysPastDue(now),
                            busy: _busyAction,
                            onClear: () => _handleClearCheque(c),
                            onBounce: c.isInvoiceSource && !c.isBounced
                                ? () => _promptBounceCheque(c)
                                : null,
                          ),
                      ],
                    ),
            ),

            // ---------- ۶. چک‌های پرداختی ما (صادره به تأمین‌کنندگان) ----------
            const SizedBox(height: 12),
            _SectionCard(
              title: 'چک‌های پرداختی ما (صادره به تأمین‌کنندگان)',
              icon: Icons.credit_card_rounded,
              iconColor: ShopColors.warn,
              badge: admin.issuedCheques.isNotEmpty
                  ? '${Fa.digits(admin.issuedCheques.length)} سررسیدشده'
                  : null,
              badgeColor: ShopColors.warn,
              child: admin.issuedCheques.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        admin.pendingIssuedChequesCount > 0
                            ? '${Fa.digits(admin.pendingIssuedChequesCount)} چک پرداختی باز دارید؛ موعد آن‌ها در آینده است.'
                            : 'چک پرداختی باز در فاکتورهای خرید ثبت نشده است.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: ShopColors.inkSoft,
                          height: 1.65,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (final c in admin.issuedCheques)
                          _ChequeAlertTile(
                            cheque: c,
                            issued: true,
                            dueLabel: _fmtDate(c.dueDate),
                            daysPastDue: c.daysPastDue(now),
                            busy: _busyAction,
                            onClear: () => _handleClearCheque(c),
                          ),
                      ],
                    ),
            ),
          ],

          // ---------- ۷. خلاصهٔ عملیاتی فروشگاه (`DashboardSummary`) ----------
          const SizedBox(height: 14),
          const _SubHeading(
            icon: Icons.storefront_rounded,
            title: 'خلاصه وضعیت انبار و فروشگاه',
          ),
          const SizedBox(height: 8),
          _responsiveTwoColGrid([
            _SummaryMiniCard(
              label: 'ارزش موجودی',
              value: FaNum.money(d.inventoryValue),
              icon: Icons.monetization_on_outlined,
              color: ShopColors.seed,
            ),
            _SummaryMiniCard(
              label: 'فروش امروز',
              value: FaNum.money(d.todaySales),
              icon: Icons.shopping_cart_checkout_rounded,
              color: ShopColors.ok,
            ),
            _SummaryMiniCard(
              label: 'خرید امروز',
              value: FaNum.money(d.todayPurchases),
              icon: Icons.shopping_bag_outlined,
              color: const Color(0xff0284c7),
            ),
            _SummaryMiniCard(
              label: 'فروش این ماه',
              value: FaNum.money(d.monthSales),
              icon: Icons.auto_graph_rounded,
              color: ShopColors.warn,
            ),
            _SummaryMiniCard(
              label: 'اقلام کالا',
              value: Fa.digits(d.productCount),
              icon: Icons.inventory_2_outlined,
              color: const Color(0xff4f46e5),
            ),
            _SummaryMiniCard(
              label: 'زیر نقطه سفارش',
              value: Fa.digits(d.belowReorderCount),
              icon: Icons.warning_amber_rounded,
              color: d.belowReorderCount > 0
                  ? ShopColors.danger
                  : ShopColors.inkSoft,
              highlightDanger: d.belowReorderCount > 0,
              onTap: perms.canSeeReorder
                  ? () => _pushPage(const ReorderReportPage())
                  : null,
            ),
          ]),

          // ---------- ۸. فعالیت‌های اخیر ----------
          const SizedBox(height: 14),
          _SectionCard(
            title: 'فعالیت‌های اخیر خرید و فروش',
            icon: Icons.history_rounded,
            iconColor: ShopColors.seed,
            child: _recent.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'فعالیتی ثبت نشده است.',
                      style: TextStyle(fontSize: 12, color: ShopColors.inkSoft),
                    ),
                  )
                : Column(
                    children: [
                      for (final a in _recent)
                        _RowItem(
                          leadingBadge: a.typeLabel,
                          badgeColor: switch (a.type.trim()) {
                            'Sale' => ShopColors.ok,
                            'Purchase' => ShopColors.seed,
                            _ => ShopColors.warn,
                          },
                          title: a.partyName.isEmpty
                              ? 'سند #${Fa.digits(a.number)}'
                              : a.partyName,
                          subtitle:
                              'سند ${Fa.digits(a.number)} • ${_fmtDate(a.date)}',
                          amount: '${FaNum.money(a.amount)} ریال',
                        ),
                    ],
                  ),
          ),

          // ---------- ۹. نیازمند سفارش مجدد ----------
          const SizedBox(height: 12),
          _SectionCard(
            title: 'نیازمند سفارش مجدد',
            icon: Icons.warning_amber_rounded,
            iconColor: ShopColors.danger,
            trailing: perms.canSeeReorder
                ? TextButton(
                    onPressed: () => _pushPage(const ReorderReportPage()),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: const Text(
                      'مشاهده همه',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                : null,
            child: _lowStock.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                          color: ShopColors.ok,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'موجودی همه اقلام مناسب است.',
                            style: TextStyle(
                              fontSize: 12,
                              color: ShopColors.inkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      for (final r in _lowStock)
                        _RowItem(
                          leadingBadge: Fa.digits(r.productCode),
                          badgeColor: ShopColors.danger,
                          title: r.productName,
                          subtitle:
                              'موجودی: ${FaNum.qty(r.totalStock)} • نقطه سفارش: ${FaNum.qty(r.reorderPoint)}',
                          amount: 'کمبود: ${FaNum.qty(r.shortage)}',
                          amountColor: ShopColors.danger,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _responsiveTwoColGrid(List<Widget> children) => LayoutBuilder(
    builder: (_, c) {
      const gap = 8.0;
      final itemWidth = (c.maxWidth - gap) / 2;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final child in children) SizedBox(width: itemWidth, child: child),
        ],
      );
    },
  );
}

// ============================================================
//  ویجت‌های نمایشی اختصاصی داشبورد مالی (بدون سرریز در ۳۶۰px)
// ============================================================

class _SubHeading extends StatelessWidget {
  const _SubHeading({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: ShopColors.inkSoft),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: ShopColors.ink,
          ),
        ),
      ),
    ],
  );
}

class _GradStatCard extends StatelessWidget {
  const _GradStatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.colors,
  });

  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: colors,
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: colors.first.withValues(alpha: 0.22),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
            ),
            Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.8)),
          ],
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          unit,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
      ],
    ),
  );
}

class _ProfitCard extends StatelessWidget {
  const _ProfitCard({required this.title, required this.value});
  final String title;
  final double value;

  @override
  Widget build(BuildContext context) {
    final positive = value >= 0;
    final color = positive ? ShopColors.ok : ShopColors.danger;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: ShopColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              positive
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: ShopColors.inkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    FaNum.money(value),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMiniCard extends StatelessWidget {
  const _SummaryMiniCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.highlightDanger = false,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool highlightDanger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlightDanger
              ? ShopColors.danger.withValues(alpha: 0.55)
              : ShopColors.line,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
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
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: ShopColors.inkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: highlightDanger
                          ? ShopColors.danger
                          : ShopColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
    this.badge,
    this.badgeColor,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final String? badge;
  final Color? badgeColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.ink,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? iconColor).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: badgeColor ?? iconColor,
                    ),
                  ),
                ),
              ],
              ?trailing,
            ],
          ),
        ),
        const Divider(height: 1, color: ShopColors.line),
        child,
      ],
    ),
  );
}

class _RowItem extends StatelessWidget {
  const _RowItem({
    required this.leadingBadge,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.subAmount,
    this.badgeColor = ShopColors.seed,
    this.amountColor = ShopColors.ink,
  });

  final String leadingBadge;
  final String title;
  final String subtitle;
  final String amount;
  final String? subAmount;
  final Color badgeColor;
  final Color amountColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: ShopColors.line, width: 0.6)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            leadingBadge,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: badgeColor,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: ShopColors.ink,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: ShopColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: amountColor,
                ),
              ),
              if (subAmount != null)
                Text(
                  subAmount!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: ShopColors.inkSoft,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DebtorAlertTile extends StatelessWidget {
  const _DebtorAlertTile({
    required this.item,
    required this.dueLabel,
    this.onSettle,
  });

  final OverdueDebtorDto item;
  final String dueLabel;
  final VoidCallback? onSettle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: ShopColors.line, width: 0.6)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.partyName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: ShopColors.ink,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: item.daysOverdue == 0
                    ? _warnSoft
                    : ShopColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                item.daysOverdue == 0
                    ? 'سررسید امروز'
                    : '${Fa.digits(item.daysOverdue)} روز تأخیر',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: item.daysOverdue == 0
                      ? const Color(0xff92400e)
                      : ShopColors.danger,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'سند ${Fa.digits(item.number)} (${item.kind})',
              style: const TextStyle(
                fontSize: 11,
                color: ShopColors.seed,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'سررسید: $dueLabel',
              style: const TextStyle(fontSize: 11, color: ShopColors.inkSoft),
            ),
            if (item.mobile != null && item.mobile!.trim().isNotEmpty)
              Text(
                Fa.digits(item.mobile!),
                style: const TextStyle(fontSize: 11, color: ShopColors.inkSoft),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                '${FaNum.money(item.amount)} ریال',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.danger,
                ),
              ),
            ),
            if (onSettle != null && item.transactionId > 0)
              OutlinedButton.icon(
                onPressed: onSettle,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  foregroundColor: ShopColors.ok,
                  side: BorderSide(
                    color: ShopColors.ok.withValues(alpha: 0.45),
                  ),
                ),
                icon: const Icon(Icons.payments_outlined, size: 15),
                label: const Text(
                  'تسویه نسیه',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class _ChequeAlertTile extends StatelessWidget {
  const _ChequeAlertTile({
    required this.cheque,
    required this.issued,
    required this.dueLabel,
    required this.daysPastDue,
    required this.busy,
    required this.onClear,
    this.onBounce,
  });

  final ChequeAlertDto cheque;
  final bool issued;
  final String dueLabel;
  final int daysPastDue;
  final bool busy;
  final VoidCallback onClear;
  final VoidCallback? onBounce;

  @override
  Widget build(BuildContext context) {
    final clearLabel = !cheque.isInvoiceSource
        ? 'مدیریت چک'
        : (issued ? 'پاس شد' : 'وصول شد');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ShopColors.line, width: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'چک ${Fa.digits(cheque.number)} — ${cheque.partyName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: ShopColors.ink,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: daysPastDue > 0
                      ? ShopColors.danger.withValues(alpha: 0.12)
                      : ShopColors.ok.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  daysPastDue > 0
                      ? 'معوق (${Fa.digits(daysPastDue)} روز)'
                      : 'سررسید امروز',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: daysPastDue > 0 ? ShopColors.danger : ShopColors.ok,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (cheque.bankName != null && cheque.bankName!.trim().isNotEmpty)
                Text(
                  cheque.bankName!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: ShopColors.inkSoft,
                  ),
                ),
              if (cheque.orderNumber.trim().isNotEmpty)
                Text(
                  'فاکتور: ${Fa.digits(cheque.orderNumber)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: ShopColors.inkSoft,
                  ),
                ),
              Text(
                'موعد: $dueLabel',
                style: const TextStyle(fontSize: 11, color: ShopColors.inkSoft),
              ),
              if (cheque.isBounced)
                const Text(
                  'برگشت‌خورده',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: ShopColors.danger,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${FaNum.money(cheque.amount)} ریال',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: issued ? ShopColors.warn : ShopColors.seed,
                  ),
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : onClear,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      backgroundColor: ShopColors.ok.withValues(alpha: 0.14),
                      foregroundColor: ShopColors.ok,
                    ),
                    icon: const Icon(Icons.check_rounded, size: 15),
                    label: Text(
                      clearLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (onBounce != null)
                    OutlinedButton.icon(
                      onPressed: busy ? null : onBounce,
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        foregroundColor: ShopColors.danger,
                        side: BorderSide(
                          color: ShopColors.danger.withValues(alpha: 0.45),
                        ),
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 14),
                      label: const Text(
                        'برگشت',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  ۳ گجت نموداری بومی داشبورد مالی (بدون کتابخانهٔ خارجی)
// ============================================================

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.items});
  final List<({String label, Color color})> items;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final it in items) ...[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: it.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          it.label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: ShopColors.inkSoft,
          ),
        ),
        const SizedBox(width: 7),
      ],
    ],
  );
}

class _MonthlySalesProfitChart extends StatelessWidget {
  const _MonthlySalesProfitChart({required this.points});
  final List<FinancialTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Text(
        'داده‌ای برای نمایش روند ماهانه وجود ندارد.',
        style: TextStyle(fontSize: 11.5, color: ShopColors.inkSoft),
      );
    }
    final maxVal = points.fold<double>(
      1,
      (m, p) => math.max(m, math.max(p.sales.abs(), p.profit.abs())),
    );
    return SizedBox(
      height: 158,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final p in points)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                              child: FractionallySizedBox(
                                heightFactor: (p.sales.abs() / maxVal).clamp(
                                  0.04,
                                  1.0,
                                ),
                                child: Container(
                                  width: 10,
                                  decoration: BoxDecoration(
                                    color: const Color(0xff4f46e5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: FractionallySizedBox(
                                heightFactor: (p.profit.abs() / maxVal).clamp(
                                  0.04,
                                  1.0,
                                ),
                                child: Container(
                                  width: 10,
                                  decoration: BoxDecoration(
                                    color: p.profit >= 0
                                        ? const Color(0xff059669)
                                        : ShopColors.danger,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      Fa.digits(p.label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: ShopColors.inkSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaymentMixView extends StatelessWidget {
  const _PaymentMixView({required this.admin});
  final AdminDashboardDto admin;

  @override
  Widget build(BuildContext context) {
    final slices = [
      (label: 'نقدی', val: admin.payCash, color: const Color(0xff059669)),
      (label: 'نسیه', val: admin.payCredit, color: const Color(0xffd97706)),
      (label: 'چک', val: admin.payCheque, color: const Color(0xff2563eb)),
      (
        label: 'اقساطی',
        val: admin.payInstallment,
        color: const Color(0xff7c3aed),
      ),
    ];
    final total = admin.totalPayMix;

    return Row(
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: CustomPaint(
            painter: _DoughnutPainter(
              values: slices.map((s) => s.val).toList(),
              colors: slices.map((s) => s.color).toList(),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    total > 0 ? FaNum.compact(total) : '۰',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: ShopColors.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            children: [
              for (final s in slices)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.5),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: s.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        s.label,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: ShopColors.ink,
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          total > 0
                              ? '${FaNum.money(s.val)} (${Fa.number((s.val / total) * 100, decimals: 0)}٪)'
                              : '۰',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: ShopColors.inkSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DoughnutPainter extends CustomPainter {
  _DoughnutPainter({required this.values, required this.colors});
  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 13.0;
    final rect = Offset.zero & size;
    final inset = rect.deflate(stroke / 2);
    final total = values.fold<double>(0, (s, v) => s + (v > 0 ? v : 0));

    if (total <= 0) {
      canvas.drawArc(
        inset,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = ShopColors.line,
      );
      return;
    }

    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v <= 0) continue;
      final sweep = (v / total) * math.pi * 2;
      canvas.drawArc(
        inset,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = colors[i % colors.length],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DoughnutPainter old) => old.values != values;
}

class _DailySalesChart extends StatelessWidget {
  const _DailySalesChart({required this.points});
  final List<FinancialTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Text(
        'داده‌ای برای روند فروش ۳۰ روز اخیر ثبت نشده است.',
        style: TextStyle(fontSize: 11.5, color: ShopColors.inkSoft),
      );
    }
    final total30 = points.fold<double>(0, (s, p) => s + p.sales);
    final peak = points.fold<double>(0, (m, p) => math.max(m, p.sales));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              'جمع ۳۰ روز: ${FaNum.money(total30)} ریال',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: ShopColors.ink,
              ),
            ),
            Text(
              'بیشترین روز: ${FaNum.money(peak)} ریال',
              style: const TextStyle(
                fontSize: 11,
                color: ShopColors.inkSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 115,
          child: CustomPaint(
            painter: _AreaLinePainter(
              values: points.map((p) => p.sales).toList(),
              color: const Color(0xffd97706),
            ),
          ),
        ),
        if (points.length >= 2) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                Fa.digits(points.first.label),
                style: const TextStyle(
                  fontSize: 9.5,
                  color: ShopColors.inkSoft,
                ),
              ),
              Text(
                Fa.digits(points.last.label),
                style: const TextStyle(
                  fontSize: 9.5,
                  color: ShopColors.inkSoft,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AreaLinePainter extends CustomPainter {
  _AreaLinePainter({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.fold<double>(1, (m, v) => math.max(m, v));
    const pad = 6.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;

    final pts = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          pad +
              (values.length == 1
                  ? w / 2
                  : (i / (values.length - 1)) * w),
          pad + h - ((values[i].clamp(0, maxV)) / maxV) * h,
        ),
    ];

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.28),
            color.withValues(alpha: 0.01),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _AreaLinePainter old) => old.values != values;
}
