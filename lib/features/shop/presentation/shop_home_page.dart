// ============================================================
//  «میز کار فروشگاهی کایر» (Multi-Tab ERP Workspace Shell)
//  طراحی میز کار عملیاتی با الهام مستقیم از معماری تب‌های وب
//  (`Layout/TabBar.razor` + `Layout/TabPages.razor` + `ShopSections.cs`)
//  به‌همراه پیشخوان ثبت سریع، شاخص‌های زنده، کارتابل پیگیری‌های فوری
//  و شبکهٔ ابزارهای دسته‌بندی‌شده با حفظ وضعیت صفحات باز (`IndexedStack`).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/shop_perms.dart';
import '../data/shop_repository.dart';
import '../models/ops_models.dart';
import '../models/order_models.dart';
import '../models/treasury_models.dart';
import '../models/visit_models.dart';
import 'categories_page.dart';
import 'expenses_page.dart';
import 'goods_issues_page.dart';
import 'kardex_page.dart';
import 'opening_balance_page.dart';
import 'ops_dashboard_page.dart';
import 'order_form_page.dart';
import 'order_report_page.dart';
import 'parties_page.dart';
import 'party_statements_page.dart';
import 'products_page.dart';
import 'referrer_panel_pages.dart';
import 'referrer_wallets_page.dart';
import 'referrers_page.dart';
import 'repairs_page.dart';
import 'sale_orders_page.dart';
import 'shop_credit_page.dart';
import 'shop_guide_page.dart';
import 'shop_phase3_reports_pages.dart';
import 'shop_pricing_page.dart';
import 'shop_print_settings_page.dart';
import 'shop_style.dart';
import 'stock_page.dart';
import 'trs_accounts_page.dart';
import 'trs_cheques_page.dart';
import 'trs_dashboard_page.dart';
import 'trs_voucher_form_page.dart';
import 'trs_vouchers_page.dart';
import 'units_page.dart';
import 'vis_approvals_page.dart';
import 'vis_finance_queue_page.dart';
import 'vis_requests_page.dart';
import 'visit_form_page.dart';
import 'visits_page.dart';
import 'warehouses_page.dart';

enum _DeskCat {
  all('همه', Icons.apps_rounded),
  ops('عملیات روزانه', Icons.bolt_rounded),
  treasury('خزانه و تسویه', Icons.account_balance_wallet_rounded),
  catalog('کالا و انبار', Icons.inventory_2_rounded),
  reports('گزارش و تحلیل', Icons.insights_rounded),
  visits('ویزیتوری', Icons.directions_walk_rounded),
  settings('پایه و تنظیمات', Icons.tune_rounded);

  const _DeskCat(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _DeskTool {
  const _DeskTool({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.category,
    required this.builder,
    this.keywords = '',
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final _DeskCat category;
  final WidgetBuilder builder;
  final String keywords;
}

class _OpenWorkspaceTab {
  _OpenWorkspaceTab({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.builder,
  });

  final String id;
  final String title;
  final IconData icon;
  final Color color;
  WidgetBuilder builder;
  bool pinned = false;
  int reloadVersion = 0;
  final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
}

class ShopHomePage extends StatefulWidget {
  const ShopHomePage({super.key});

  @override
  State<ShopHomePage> createState() => _ShopHomePageState();
}

class _ShopHomePageState extends State<ShopHomePage> {
  static const String _homeTabId = '__workbench__';

  late final ShopRepository _repo;
  final List<_OpenWorkspaceTab> _openTabs = [];
  String _activeTabId = _homeTabId;

  // فیلترهای نمای میز کار
  final _searchCtrl = TextEditingController();
  _DeskCat _selectedCat = _DeskCat.all;

  // شاخص‌های زندهٔ میز کار
  bool _loadingLive = false;
  OpsDashboard? _opsDash;
  TreasuryDashboard? _trsDash;
  ShopCreditSummary? _creditSum;
  VisStats? _visStats;

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLiveMetrics());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLiveMetrics() async {
    if (!mounted) return;
    final auth = context.read<AuthController>();
    final perms = ShopPerms(auth.session);
    setState(() => _loadingLive = true);

    final now = DateTime.now();
    final monthAgo = now.subtract(const Duration(days: 30));

    final futures = <Future<void>>[
      if (perms.canSeeDashboard)
        _repo
            .opsDashboard(from: monthAgo, to: now)
            .then((v) => _opsDash = v)
            .catchError((_) => const OpsDashboard()),
      if (perms.canSeeSettlement || perms.canSeeBanks || perms.canSeeCheques)
        _repo
            .treasuryDashboard(from: monthAgo, to: now)
            .then((v) => _trsDash = v)
            .catchError((_) => TreasuryDashboard()),
      if (perms.canSeeInstallments || perms.canSeeSale || perms.canSeePurchase)
        _repo
            .shopCreditSummary()
            .then((v) => _creditSum = v)
            .catchError((_) => ShopCreditSummary()),
      if (perms.canSeeSalesVisit)
        _repo.visStats().then((v) => _visStats = v).catchError((_) => VisStats()),
    ];

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
    if (!mounted) return;
    setState(() => _loadingLive = false);
  }

  // -------------------- مدیریت تب‌های میز کار --------------------

  void _openToolInTab(
    _DeskTool tool, {
    WidgetBuilder? customBuilder,
  }) {
    HapticFeedback.selectionClick();
    final existingIdx = _openTabs.indexWhere((t) => t.id == tool.id);
    setState(() {
      if (existingIdx >= 0) {
        if (customBuilder != null) {
          _openTabs[existingIdx].builder = customBuilder;
          _openTabs[existingIdx].reloadVersion++;
        }
        _activeTabId = tool.id;
      } else {
        _openTabs.add(
          _OpenWorkspaceTab(
            id: tool.id,
            title: tool.title,
            icon: tool.icon,
            color: tool.color,
            builder: customBuilder ?? tool.builder,
          ),
        );
        _activeTabId = tool.id;
      }
    });
  }

  Future<void> _pushQuickModal(Widget page) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push<dynamic>(
      MaterialPageRoute<dynamic>(builder: (_) => page),
    );
    if (mounted) _loadLiveMetrics();
  }

  void _closeTab(String id) {
    final idx = _openTabs.indexWhere((t) => t.id == id);
    if (idx < 0 || _openTabs[idx].pinned) return;
    HapticFeedback.lightImpact();
    setState(() {
      final wasActive = _activeTabId == id;
      _openTabs.removeAt(idx);
      if (wasActive) {
        if (_openTabs.isEmpty) {
          _activeTabId = _homeTabId;
        } else {
          final nextIdx = idx.clamp(0, _openTabs.length - 1);
          _activeTabId = _openTabs[nextIdx].id;
        }
      }
    });
  }

  void _showTabActions(_OpenWorkspaceTab tab) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ShopColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: ShopColors.line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            ListTile(
              leading: Icon(tab.icon, color: tab.color),
              title: Text(
                tab.title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text(
                'مدیریت تب باز در میز کار',
                style: TextStyle(fontSize: 11),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: const Text('تازه‌سازی این تب'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  tab.reloadVersion++;
                  _activeTabId = tab.id;
                });
              },
            ),
            ListTile(
              leading: Icon(
                tab.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
              ),
              title: Text(
                tab.pinned ? 'برداشتن سنجاق تب' : 'سنجاق کردن در نوار میز کار',
              ),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => tab.pinned = !tab.pinned);
              },
            ),
            if (!tab.pinned)
              ListTile(
                leading: const Icon(
                  Icons.close_rounded,
                  color: ShopColors.danger,
                ),
                title: const Text(
                  'بستن این تب',
                  style: TextStyle(color: ShopColors.danger),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _closeTab(tab.id);
                },
              ),
            if (_openTabs.any((t) => t.id != tab.id && !t.pinned))
              ListTile(
                leading: const Icon(Icons.tab_unselected_rounded),
                title: const Text('بستن سایر تب‌ها'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _openTabs.removeWhere((t) => t.id != tab.id && !t.pinned);
                    _activeTabId = tab.id;
                  });
                },
              ),
            if (_openTabs.any((t) => !t.pinned))
              ListTile(
                leading: const Icon(Icons.clear_all_rounded),
                title: const Text('بستن همه تب‌های غیرسنجاق'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _openTabs.removeWhere((t) => !t.pinned);
                    if (!_openTabs.any((t) => t.id == _activeTabId)) {
                      _activeTabId = _homeTabId;
                    }
                  });
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openQuickSwitcherSheet(List<_DeskTool> tools) {
    final qCtrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ShopColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          final q = qCtrl.text.trim().toLowerCase();
          final filtered = q.isEmpty
              ? tools
              : tools
                    .where(
                      (t) =>
                          t.title.toLowerCase().contains(q) ||
                          t.subtitle.toLowerCase().contains(q) ||
                          t.keywords.toLowerCase().contains(q),
                    )
                    .toList();
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            maxChildSize: 0.92,
            minChildSize: 0.45,
            builder: (_, scrollCtrl) => Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: ShopColors.line,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.space_dashboard_rounded,
                        color: ShopColors.seed,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'پرش سریع بین بخش‌های میز کار',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '${numFa(tools.length)} ابزار',
                        style: const TextStyle(
                          fontSize: 11,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ShopSearchField(
                    controller: qCtrl,
                    hint: 'نام بخش را بنویسید (مثلاً فاکتور، چک، کاردکس)...',
                    onChanged: (_) => setM(() {}),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollCtrl,
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, idx) {
                        final t = filtered[idx];
                        final isOpen = _openTabs.any((o) => o.id == t.id);
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          leading: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: t.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(t.icon, size: 18, color: t.color),
                          ),
                          title: Text(
                            t.title,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            t.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10.5),
                          ),
                          trailing: isOpen
                              ? const ShopPill(
                                  text: 'تب باز',
                                  color: ShopColors.ok,
                                )
                              : const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 16,
                                  color: ShopColors.inkFaint,
                                ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _openToolInTab(t);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(qCtrl.dispose);
  }

  // -------------------- فهرست کامل ابزارهای میز کار (با گیت دسترسی وب) --------------------

  List<_DeskTool> _buildTools(ShopPerms perms, bool isRef) {
    final showParties = perms.anyPartyAccess;
    final partiesLabel = perms.partiesMenuLabel;
    final partiesSubtitle = perms.canSeeCustomers && perms.canSeeSuppliers
        ? 'مشتریان و تأمین‌کنندگان'
        : (perms.canSeeCustomers
              ? 'خریداران حقیقی و حقوقی'
              : 'فروشندگان کالا و خدمات');

    return <_DeskTool>[
      // ---- عملیات روزانه ----
      if (perms.canSeeSale)
        _DeskTool(
          id: 'sale',
          title: 'فروش و پیش‌فاکتور',
          subtitle: 'ثبت فاکتور فروش، پیش‌فاکتور، چاپ، نسیه و برگشت چکی',
          icon: Icons.shopping_cart_rounded,
          color: ShopColors.ok,
          category: _DeskCat.ops,
          keywords: 'فاکتور فروش پیش فاکتور مشتری برگشت از فروش',
          builder: (_) => const SaleOrdersPage(type: TxnType.sale),
        ),
      if (perms.canSeePurchase)
        _DeskTool(
          id: 'purchase',
          title: 'خرید و تأمین',
          subtitle: 'رسید خرید، ارزش افزوده، بروزرسانی فی فروش و چاپ رسید',
          icon: Icons.shopping_bag_rounded,
          color: ShopColors.seed,
          category: _DeskCat.ops,
          keywords: 'فاکتور خرید رسید تامین کننده',
          builder: (_) => const SaleOrdersPage(type: TxnType.purchase),
        ),
      if (perms.canSeeGoodsIssue)
        _DeskTool(
          id: 'goods-issue',
          title: 'بیجک خروج انبار',
          subtitle: 'حوالهٔ خروج کالا بدون قیمت برای ارسال بار',
          icon: Icons.local_shipping_rounded,
          color: ShopColors.teal,
          category: _DeskCat.ops,
          keywords: 'بیجک حواله خروج ارسال بار',
          builder: (_) => const GoodsIssuesPage(),
        ),
      if (perms.canSeeRepairs)
        _DeskTool(
          id: 'repairs',
          title: 'کارگاه تعمیرات',
          subtitle: 'پذیرش دستگاه، کارها و قطعات، گارانتی و تبدیل به فروش',
          icon: Icons.build_rounded,
          color: ShopColors.indigo,
          category: _DeskCat.ops,
          keywords: 'تعمیر پذیرش دستگاه گارانتی تکنسین',
          builder: (_) => const RepairsPage(),
        ),
      if (perms.canSeeExpenses)
        _DeskTool(
          id: 'expenses',
          title: 'ثبت هزینه‌ها',
          subtitle: 'ثبت اسناد هزینه جاری و مدیریت سرفصل‌های هزینه',
          icon: Icons.payments_rounded,
          color: ShopColors.danger,
          category: _DeskCat.ops,
          keywords: 'هزینه تنخواه سرفصل',
          builder: (_) => const ExpensesPage(),
        ),

      // ---- خزانه، چک و تسویه ----
      if (perms.canSeeSettlement || perms.canSeeBanks || perms.canSeeCheques)
        _DeskTool(
          id: 'trs-dashboard',
          title: 'داشبورد خزانه',
          subtitle: 'نقدینگی کل، جریان ورودی/خروجی دوره و چک‌های سررسید نزدیک',
          icon: Icons.account_balance_wallet_rounded,
          color: ShopColors.teal,
          category: _DeskCat.treasury,
          keywords: 'داشبورد خزانه نقدینگی موجودی بانک صندوق',
          builder: (_) => const TrsDashboardPage(),
        ),
      if (perms.canSeeSettlement)
        _DeskTool(
          id: 'settlement',
          title: 'تسویه فاکتورها',
          subtitle: 'اسناد دریافت، پرداخت و انتقال بین حساب‌ها',
          icon: Icons.swap_horiz_rounded,
          color: ShopColors.seed,
          category: _DeskCat.treasury,
          keywords: 'دریافت پرداخت انتقال تسویه سند خزانه',
          builder: (_) => const TrsVouchersPage(),
        ),
      if (perms.canSeeInstallments)
        _DeskTool(
          id: 'credit-mgmt',
          title: 'چک‌ها و دفترچه اقساط',
          subtitle: 'وصول به بانک، تغییر سررسید، تعویض چک، برگشت و اقساط',
          icon: Icons.event_note_rounded,
          color: ShopColors.warn,
          category: _DeskCat.treasury,
          keywords: 'چک اقساط قسط سررسید برگشتی تعویض وصول',
          builder: (_) => const ShopCreditPage(),
        ),
      if (perms.canSeeCheques)
        _DeskTool(
          id: 'trs-cheques',
          title: 'چک‌های خزانه‌داری',
          subtitle: 'صدور، واگذاری به بانک، خرج کردن، وصول و برگشت چک',
          icon: Icons.credit_card_rounded,
          color: ShopColors.indigo,
          category: _DeskCat.treasury,
          keywords: 'چک خزانه صیادی واگذاری خرج چک',
          builder: (_) => const TrsChequesPage(),
        ),
      if (perms.canSeeBanks)
        _DeskTool(
          id: 'banks',
          title: 'بانک، صندوق و POS',
          subtitle: 'حساب‌های خزانه با مانده جاری، شماره شبا و کارتخوان',
          icon: Icons.account_balance_rounded,
          color: ShopColors.deep,
          category: _DeskCat.treasury,
          keywords: 'بانک صندوق کارتخوان شبا حساب',
          builder: (_) => const TrsAccountsPage(),
        ),
      if (perms.canSeeOpeningBalance)
        _DeskTool(
          id: 'opening-balance',
          title: 'افتتاح حساب اول دوره',
          subtitle: 'طلب/بدهی اولیه اشخاص، چک‌ها، اقساط و موجودی اول دوره',
          icon: Icons.savings_rounded,
          color: ShopColors.accent,
          category: _DeskCat.treasury,
          keywords: 'افتتاح حساب مانده اولیه اول دوره',
          builder: (_) => const OpeningBalancePage(),
        ),

      // ---- کالا و انبار ----
      if (perms.canSeeProducts)
        _DeskTool(
          id: 'products',
          title: 'کالاها و خدمات',
          subtitle: 'تعریف کالا، بارکد، ارزش افزوده، ورود اکسل و نقطه سفارش',
          icon: Icons.inventory_2_rounded,
          color: ShopColors.seed,
          category: _DeskCat.catalog,
          keywords: 'کالا خدمات بارکد اکسل فی فروش',
          builder: (_) => const ProductsPage(),
        ),
      if (perms.canSeeStock)
        _DeskTool(
          id: 'stock',
          title: 'موجودی لحظه‌ای انبار',
          subtitle: 'موجودی به تفکیک انبار، هشدار کسری و تعدیل انبارگردانی',
          icon: Icons.inventory_rounded,
          color: ShopColors.teal,
          category: _DeskCat.catalog,
          keywords: 'موجودی انبار کسری انبارگردانی',
          builder: (_) => const StockPage(),
        ),
      if (perms.canSeePricing)
        _DeskTool(
          id: 'pricing',
          title: 'قیمت‌گذاری و حداقل سود',
          subtitle: 'سیاست کف سود فروش، اصلاح گروهی قیمت و تاریخچه قیمت',
          icon: Icons.price_change_rounded,
          color: ShopColors.ok,
          category: _DeskCat.catalog,
          keywords: 'قیمت گذاری حداقل سود افزایش قیمت گروهی',
          builder: (_) => const ShopPricingPage(),
        ),
      if (perms.canSeeWarehouses)
        _DeskTool(
          id: 'warehouses',
          title: 'انبارها',
          subtitle: 'تعریف انبارها و مراکز نگهداری کالا',
          icon: Icons.warehouse_rounded,
          color: ShopColors.indigo,
          category: _DeskCat.catalog,
          keywords: 'انبار مراکز نگهداری',
          builder: (_) => const WarehousesPage(),
        ),
      if (perms.canSeeCategories)
        _DeskTool(
          id: 'categories',
          title: 'گروه‌های کالا',
          subtitle: 'دسته‌بندی درختی و گروه‌بندی کالاها',
          icon: Icons.sell_rounded,
          color: ShopColors.accent,
          category: _DeskCat.catalog,
          keywords: 'گروه دسته بندی کالا',
          builder: (_) => const ProductCategoriesPage(),
        ),
      if (perms.canSeeUnits)
        _DeskTool(
          id: 'units',
          title: 'واحدهای شمارش',
          subtitle: 'تعریف عدد، کارتن، کیلوگرم و واحدهای اندازه‌گیری',
          icon: Icons.straighten_rounded,
          color: ShopColors.inkSoft,
          category: _DeskCat.catalog,
          keywords: 'واحد شمارش اندازه گیری',
          builder: (_) => const UnitsPage(),
        ),

      // ---- گزارش‌ها و تحلیل ----
      if (perms.canSeeDashboard)
        _DeskTool(
          id: 'ops-dashboard',
          title: 'داشبورد جامع عملیاتی',
          subtitle: 'تحلیل نموداری خرید، فروش، خدمات تعمیراتی و معرف‌ها',
          icon: Icons.bar_chart_rounded,
          color: ShopColors.seed,
          category: _DeskCat.reports,
          keywords: 'داشبورد عملیاتی نمودار سود',
          builder: (_) => const OpsDashboardPage(),
        ),
      if (perms.canSeePartyStatements)
        _DeskTool(
          id: 'party-statements',
          title: 'طلب و بدهی اشخاص',
          subtitle: 'گردش حساب، مانده افتتاحیه و ریز صورت‌حساب مشتریان',
          icon: Icons.account_balance_wallet_rounded,
          color: ShopColors.indigo,
          category: _DeskCat.reports,
          keywords: 'صورتحساب گردش حساب معین اشخاص بدهکار بستانکار',
          builder: (_) => const PartyStatementsPage(),
        ),
      if (perms.canSeeOrderReports) ...[
        _DeskTool(
          id: 'sale-report',
          title: 'گزارش جامع فروش',
          subtitle: 'تحلیل روند فروش، رتبه‌بندی مشتریان و سود ناخالص',
          icon: Icons.trending_up_rounded,
          color: ShopColors.ok,
          category: _DeskCat.reports,
          keywords: 'گزارش فروش سود مشتریان برتر',
          builder: (_) => const OrderReportPage(type: TxnType.sale),
        ),
        _DeskTool(
          id: 'purchase-report',
          title: 'گزارش جامع خرید',
          subtitle: 'تحلیل خرید دوره‌ای و رتبه‌بندی تأمین‌کنندگان',
          icon: Icons.shopping_bag_outlined,
          color: ShopColors.seed,
          category: _DeskCat.reports,
          keywords: 'گزارش خرید تامین کنندگان',
          builder: (_) => const OrderReportPage(type: TxnType.purchase),
        ),
      ],
      if (perms.canSeeChequeIncomeReport)
        _DeskTool(
          id: 'cheque-income-report',
          title: 'گزارش تاخیر تادیه چک',
          subtitle: 'گردش درآمد کارمزد چک‌های مدت‌دار، تغییر سررسید و برگشت',
          icon: Icons.request_quote_rounded,
          color: ShopColors.teal,
          category: _DeskCat.reports,
          keywords: 'تاخیر تادیه سود چک کارمزد چک',
          builder: (_) => const ChequeIncomeReportPage(),
        ),
      if (perms.canSeeKardex) ...[
        _DeskTool(
          id: 'kardex-qty',
          title: 'کاردکس تعدادی کالا',
          subtitle: 'رهگیری خط‌به‌خط وارده، صادره و مانده فیزیکی کالا',
          icon: Icons.list_alt_rounded,
          color: ShopColors.accent,
          category: _DeskCat.reports,
          keywords: 'کاردکس تعدادی گردش کالا',
          builder: (_) => const KardexPage(),
        ),
        _DeskTool(
          id: 'kardex-rial',
          title: 'کاردکس ریالی کالا',
          subtitle: 'فی تمام‌شده، ارزش دفتری و میانگین بهای مانده انبار',
          icon: Icons.currency_exchange_rounded,
          color: ShopColors.warn,
          category: _DeskCat.reports,
          keywords: 'کاردکس ریالی بهای تمام شده میانگین موزون',
          builder: (_) => const KardexPage(rial: true),
        ),
      ],
      if (perms.canSeeExpenses)
        _DeskTool(
          id: 'expense-report',
          title: 'گزارش هزینه‌ها',
          subtitle: 'تجمیع اسناد هزینه به تفکیک سرفصل و خروجی CSV',
          icon: Icons.receipt_long_rounded,
          color: ShopColors.danger,
          category: _DeskCat.reports,
          keywords: 'گزارش هزینه ها سرفصل',
          builder: (_) => const ExpenseReportPage(),
        ),
      if (perms.canSeeRepairs)
        _DeskTool(
          id: 'warranty-report',
          title: 'گزارش گارانتی',
          subtitle: 'پذیرش‌های تحویل‌شده، هزینه داخلی و سهم مشتری',
          icon: Icons.verified_user_rounded,
          color: ShopColors.indigo,
          category: _DeskCat.reports,
          keywords: 'گزارش گارانتی تعمیرات تحویل شده',
          builder: (_) => const WarrantyReportPage(),
        ),
      if (perms.canSeeVisRequestsReport)
        _DeskTool(
          id: 'vis-requests-report',
          title: 'گزارش تجمیع ویزیتوری',
          subtitle: 'تجمیع سفارش‌ها بر اساس کالا (کسری انبار)، ویزیتور و مشتری',
          icon: Icons.analytics_rounded,
          color: ShopColors.seed,
          category: _DeskCat.reports,
          keywords: 'گزارش تجمیع ویزیتوری کسری کالا ویزیتور',
          builder: (_) => const VisRequestsReportPage(),
        ),

      // ---- فروش و ویزیتوری ----
      if (perms.canSeeSalesVisit) ...[
        _DeskTool(
          id: 'my-visits',
          title: 'سفارش‌های ویزیتوری من',
          subtitle: 'پیگیری وضعیت سفارش‌های ثبت‌شده توسط ویزیتور',
          icon: Icons.assignment_rounded,
          color: ShopColors.seed,
          category: _DeskCat.visits,
          keywords: 'ویزیت سفارش های من ویزیتور',
          builder: (_) => const VisitsPage(),
        ),
        if (perms.canCreateVisit)
          _DeskTool(
            id: 'new-visit',
            title: 'ثبت سفارش ویزیتوری',
            subtitle: 'ثبت سریع سفارش میدانی برای مشتری',
            icon: Icons.add_box_rounded,
            color: ShopColors.ok,
            category: _DeskCat.visits,
            keywords: 'ثبت سفارش ویزیت جدید میدانی',
            builder: (_) => const VisitFormPage(),
          ),
        if (perms.canApproveVisits) ...[
          _DeskTool(
            id: 'vis-approvals',
            title: 'کارتابل تأیید مدیر فروش',
            subtitle: 'بررسی، تأیید، اصلاح یا رد سفارش‌های ویزیتورها',
            icon: Icons.verified_rounded,
            color: ShopColors.warn,
            category: _DeskCat.visits,
            keywords: 'تایید سفارش مدیر فروش کارتابل',
            builder: (_) => const VisApprovalsPage(),
          ),
          _DeskTool(
            id: 'vis-all-requests',
            title: 'همهٔ درخواست‌های ویزیت',
            subtitle: 'آرشیو و پایش تمام سفارش‌های ویزیتوری شرکت',
            icon: Icons.collections_bookmark_rounded,
            color: ShopColors.indigo,
            category: _DeskCat.visits,
            keywords: 'همه درخواست های ویزیتوری',
            builder: (_) => const VisRequestsPage(),
          ),
        ],
        if (perms.canFinanceVisit)
          _DeskTool(
            id: 'vis-finance',
            title: 'صف مالی ویزیتوری',
            subtitle: 'تأیید نحوه تسویه و صدور خودکار فاکتور فروش',
            icon: Icons.point_of_sale_rounded,
            color: ShopColors.teal,
            category: _DeskCat.visits,
            keywords: 'صف مالی ویزیتوری صدور فاکتور',
            builder: (_) => const VisFinanceQueuePage(),
          ),
      ],

      // ---- پایه، معرف‌ها و تنظیمات ----
      if (showParties)
        _DeskTool(
          id: 'parties',
          title: partiesLabel,
          subtitle: partiesSubtitle,
          icon: Icons.people_alt_rounded,
          color: ShopColors.seed,
          category: _DeskCat.settings,
          keywords: 'مشتری تامین کننده طرف حساب اشخاص کد ملی',
          builder: (_) => const PartiesPage(),
        ),
      if (perms.canSeePrintSettings)
        _DeskTool(
          id: 'print-settings',
          title: 'تنظیمات چاپ و فروشگاه',
          subtitle: 'قالب چاپ فاکتور، حساب‌های بانکی زیر فاکتور و سقف تخفیف',
          icon: Icons.print_rounded,
          color: ShopColors.indigo,
          category: _DeskCat.settings,
          keywords: 'تنظیمات چاپ فاکتور فروشگاه شبا سقف تخفیف',
          builder: (_) => const ShopPrintSettingsPage(),
        ),
      if (perms.canSeeReferrers)
        _DeskTool(
          id: 'referrers',
          title: 'معرف‌ها و بازاریاب‌ها',
          subtitle: 'تعریف معرف‌ها و درصد پورسانت کالا و خدمات',
          icon: Icons.badge_rounded,
          color: ShopColors.teal,
          category: _DeskCat.settings,
          keywords: 'معرف بازاریاب پورسانت',
          builder: (_) => const ReferrersPage(),
        ),
      if (perms.canSeeReferrerWallets)
        _DeskTool(
          id: 'referrer-wallets',
          title: 'کیف پول معرف‌ها',
          subtitle: 'مانده پورسانت و ثبت اسناد تسویه با معرف‌ها',
          icon: Icons.wallet_rounded,
          color: ShopColors.ok,
          category: _DeskCat.settings,
          keywords: 'کیف پول معرف پورسانت تسویه',
          builder: (_) => const ReferrerWalletsPage(),
        ),
      if (isRef) ...[
        _DeskTool(
          id: 'ref-my-wallet',
          title: 'کیف پول من (معرف)',
          subtitle: 'مانده پورسانت و پرداخت‌های دریافتی من',
          icon: Icons.account_balance_wallet_rounded,
          color: ShopColors.ok,
          category: _DeskCat.settings,
          builder: (_) => const MyWalletPage(),
        ),
        _DeskTool(
          id: 'ref-my-products',
          title: 'کالاهای موجود روز',
          subtitle: 'مشاهده کالاهای موجود و قیمت فروش روز',
          icon: Icons.inventory_2_rounded,
          color: ShopColors.seed,
          category: _DeskCat.settings,
          builder: (_) => const MyProductsPage(),
        ),
        _DeskTool(
          id: 'ref-my-card',
          title: 'کارت ویزیت دیجیتال من',
          subtitle: 'پیش‌نمایش کارت شناسایی معرف',
          icon: Icons.contact_page_rounded,
          color: ShopColors.indigo,
          category: _DeskCat.settings,
          builder: (_) => const MyCardPage(),
        ),
      ],
      if (perms.canSeeGuide)
        _DeskTool(
          id: 'guide',
          title: 'راهنمای میز کار کایر',
          subtitle: 'آموزش گام‌به‌گام گردش‌کارهای فروشگاهی',
          icon: Icons.menu_book_rounded,
          color: ShopColors.accent,
          category: _DeskCat.settings,
          keywords: 'راهنما آموزش مستندات',
          builder: (_) => const ShopGuidePage(),
        ),
    ];
  }

  // -------------------- ساخت بدنهٔ اصلی پوستهٔ میز کار --------------------

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final perms = ShopPerms(auth.session);
    final isRef = isReferrerSession(auth);
    final allTools = _buildTools(perms, isRef);

    final activeIdx = _activeTabId == _homeTabId
        ? 0
        : (_openTabs.indexWhere((t) => t.id == _activeTabId) + 1);
    final safeStackIdx = activeIdx.clamp(0, _openTabs.length);

    return PopScope(
      canPop: _activeTabId == _homeTabId,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_activeTabId != _homeTabId) {
          final currentTab = _openTabs
              .where((t) => t.id == _activeTabId)
              .firstOrNull;
          final nav = currentTab?.navKey.currentState;
          if (nav != null && nav.canPop()) {
            nav.pop();
            return;
          }
          setState(() => _activeTabId = _homeTabId);
        }
      },
      child: Scaffold(
        backgroundColor: ShopColors.bg,
        body: Column(
          children: [
            _buildWorkspaceTopChrome(context, allTools),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: IndexedStack(
                  index: safeStackIdx,
                  children: [
                    _buildWorkbenchHome(context, auth, perms, allTools),
                    for (final tab in _openTabs)
                      _WorkspaceTabViewport(
                        key: ValueKey('${tab.id}-v${tab.reloadVersion}'),
                        navKey: tab.navKey,
                        builder: tab.builder,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- نوار تب‌های بالای میز کار (Workspace Tab Bar) --------------------

  Widget _buildWorkspaceTopChrome(
    BuildContext context,
    List<_DeskTool> allTools,
  ) {
    final homeActive = _activeTabId == _homeTabId;
    return Container(
      decoration: const BoxDecoration(
        color: ShopColors.deep,
        boxShadow: [
          BoxShadow(
            color: Color(0x1f0f172a),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              const SizedBox(width: 6),
              // دکمه خروج از میز کار فروشگاهی به صفحه خانه اصلی اپ
              Tooltip(
                message: 'بازگشت به خانه اصلی برنامه',
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 19,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // نوار اسکرول افقی تب‌ها (تب سنجاق‌شده «میز کار» + تب‌های باز)
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: [
                    // تب ثابت میز کار
                    GestureDetector(
                      onTap: () => setState(() => _activeTabId = _homeTabId),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: homeActive
                              ? ShopColors.bg
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.space_dashboard_rounded,
                              size: 15,
                              color: homeActive
                                  ? ShopColors.seed
                                  : Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'میز کار',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: homeActive
                                    ? ShopColors.ink
                                    : Colors.white,
                              ),
                            ),
                            if (_openTabs.isNotEmpty) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: homeActive
                                      ? ShopColors.seed.withValues(alpha: 0.14)
                                      : Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  numFa(_openTabs.length),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: homeActive
                                        ? ShopColors.seed
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // تب‌های باز شده توسط کاربر
                    for (final tab in _openTabs) ...[
                      const SizedBox(width: 6),
                      _buildTabChip(tab),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // دکمه پرش سریع / باز کردن تب جدید
              if (allTools.isNotEmpty)
                Tooltip(
                  message: 'باز کردن بخش جدید در میز کار',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _openQuickSwitcherSheet(allTools),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabChip(_OpenWorkspaceTab tab) {
    final active = _activeTabId == tab.id;
    return GestureDetector(
      onTap: () => setState(() => _activeTabId = tab.id),
      onLongPress: () => _showTabActions(tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(6, 0, 10, 0),
        decoration: BoxDecoration(
          color: active ? ShopColors.bg : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              tab.pinned ? Icons.push_pin_rounded : tab.icon,
              size: 14,
              color: active ? tab.color : Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 118),
              child: Text(
                tab.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  color: active ? ShopColors.ink : Colors.white,
                ),
              ),
            ),
            if (!tab.pinned) ...[
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _closeTab(tab.id),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: active
                        ? ShopColors.inkSoft
                        : Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // -------------------- صفحهٔ اصلی «میز کار فروشگاهی کایر» --------------------

  Widget _buildWorkbenchHome(
    BuildContext context,
    AuthController auth,
    ShopPerms perms,
    List<_DeskTool> allTools,
  ) {
    if (allTools.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: ShopEmpty(
          icon: Icons.lock_outline_rounded,
          title: 'دسترسی به بخش‌های فروشگاهی ندارید',
          subtitle:
              'هیچ‌یک از بخش‌های «فروشگاهی کایر» برای نقش شما فعال نشده است.',
        ),
      );
    }

    // دسته‌هایی که حداقل یک ابزار برای این کاربر دارند
    final availableCats = <_DeskCat>[
      _DeskCat.all,
      for (final c in _DeskCat.values.where((x) => x != _DeskCat.all))
        if (allTools.any((t) => t.category == c)) c,
    ];
    final effectiveCat = availableCats.contains(_selectedCat)
        ? _selectedCat
        : _DeskCat.all;

    final q = _searchCtrl.text.trim().toLowerCase();
    final visibleTools = allTools.where((t) {
      if (effectiveCat != _DeskCat.all && t.category != effectiveCat) {
        return false;
      }
      if (q.isEmpty) return true;
      return t.title.toLowerCase().contains(q) ||
          t.subtitle.toLowerCase().contains(q) ||
          t.keywords.toLowerCase().contains(q);
    }).toList();

    final alerts = _buildWorkQueueAlerts(perms, allTools);
    final quickActions = _buildQuickActions(perms);
    final userName = (auth.session?.displayName ?? '').trim();

    return RefreshIndicator(
      onRefresh: _loadLiveMetrics,
      child: CustomScrollView(
        slivers: [
          // ۱) بنر میز کار + جستجوی فوری
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              decoration: const BoxDecoration(
                gradient: ShopColors.heroGradient,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.point_of_sale_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'میز کار فروشگاهی کایر',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${userName.isEmpty ? 'کاربر سامانه' : userName} · امروز ${jalaliLong(DateTime.now())}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.84),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _loadingLive ? null : _loadLiveMetrics,
                        tooltip: 'بروزرسانی شاخص‌های میز کار',
                        icon: _loadingLive
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.refresh_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // کادر جستجوی سریع میز کار
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText:
                          'جستجوی فوری در میز کار (فاکتور، چک، کاردکس، کالا...)',
                      hintStyle: const TextStyle(
                        fontSize: 11.5,
                        color: ShopColors.inkFaint,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 19,
                        color: ShopColors.seed,
                      ),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 17),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ۲) پیشخوان ثبت سریع (Quick Action Dock)
          if (quickActions.isNotEmpty && q.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          size: 16,
                          color: ShopColors.seed,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'پیشخوان ثبت سریع سند',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: ShopColors.ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: quickActions.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, idx) => quickActions[idx],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ۳) شاخص‌های زندهٔ ۳۰ روز اخیر روی میز کار
          if (q.isEmpty && _hasAnyKpiData)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              sliver: SliverToBoxAdapter(
                child: _buildLiveKpiGrid(allTools),
              ),
            ),

          // ۴) کارتابل پیگیری‌های فوری روی میز کار
          if (q.isEmpty && alerts.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
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
                          const Icon(
                            Icons.notifications_active_rounded,
                            size: 16,
                            color: ShopColors.warn,
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'کارتابل پیگیری‌های فوری میز کار',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: ShopColors.ink,
                              ),
                            ),
                          ),
                          ShopPill(
                            text: '${numFa(alerts.length)} مورد',
                            color: ShopColors.warn,
                          ),
                        ],
                      ),
                      const Divider(height: 12),
                      ...alerts,
                    ],
                  ),
                ),
              ),
            ),

          // ۵) فیلتر دسته‌ای میز کار
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: availableCats.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (_, idx) {
                    final cat = availableCats[idx];
                    final sel = cat == effectiveCat;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCat = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: sel ? ShopColors.seed : ShopColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? ShopColors.seed : ShopColors.line,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              cat.icon,
                              size: 14,
                              color: sel ? Colors.white : ShopColors.inkSoft,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              cat.label,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: sel ? Colors.white : ShopColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // ۶) شبکهٔ دو‌ستونهٔ کاشی‌های میز کار (Bento Workbench Grid)
          if (visibleTools.isEmpty)
            const SliverPadding(
              padding: EdgeInsets.all(20),
              sliver: SliverToBoxAdapter(
                child: ShopEmpty(
                  icon: Icons.search_off_rounded,
                  title: 'ابزاری با این عبارت در میز کار پیدا نشد.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 28),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 108,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, idx) {
                    final tool = visibleTools[idx];
                    final openTab = _openTabs
                        .where((t) => t.id == tool.id)
                        .firstOrNull;
                    return _WorkbenchTileCard(
                      tool: tool,
                      isOpen: openTab != null,
                      isPinned: openTab?.pinned ?? false,
                      onTap: () => _openToolInTab(tool),
                      onLongPress: openTab != null
                          ? () => _showTabActions(openTab)
                          : null,
                    );
                  },
                  childCount: visibleTools.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // -------------------- پیشخوان ثبت سریع --------------------

  List<Widget> _buildQuickActions(ShopPerms perms) {
    return <Widget>[
      if (perms.canManageSale)
        _QuickDockButton(
          label: 'فاکتور فروش',
          icon: Icons.add_shopping_cart_rounded,
          color: ShopColors.ok,
          onTap: () => _pushQuickModal(const OrderFormPage(type: TxnType.sale)),
        ),
      if (perms.canManageSale)
        _QuickDockButton(
          label: 'پیش‌فاکتور',
          icon: Icons.description_outlined,
          color: ShopColors.indigo,
          onTap: () => _pushQuickModal(
            const OrderFormPage(type: TxnType.sale, isProforma: true),
          ),
        ),
      if (perms.canManagePurchase)
        _QuickDockButton(
          label: 'رسید خرید',
          icon: Icons.shopping_bag_rounded,
          color: ShopColors.seed,
          onTap: () =>
              _pushQuickModal(const OrderFormPage(type: TxnType.purchase)),
        ),
      if (perms.canManageSettlement) ...[
        _QuickDockButton(
          label: 'سند دریافت',
          icon: Icons.south_west_rounded,
          color: ShopColors.teal,
          onTap: () =>
              _pushQuickModal(const TrsVoucherFormPage(kind: TrsKind.receipt)),
        ),
        _QuickDockButton(
          label: 'سند پرداخت',
          icon: Icons.north_east_rounded,
          color: ShopColors.warn,
          onTap: () =>
              _pushQuickModal(const TrsVoucherFormPage(kind: TrsKind.payment)),
        ),
      ],
      if (perms.canCreateVisit)
        _QuickDockButton(
          label: 'سفارش ویزیت',
          icon: Icons.directions_walk_rounded,
          color: ShopColors.accent,
          onTap: () => _pushQuickModal(const VisitFormPage()),
        ),
    ];
  }

  // -------------------- شاخص‌های زندهٔ میز کار --------------------

  bool get _hasAnyKpiData =>
      _opsDash != null || _trsDash != null || _creditSum != null;

  Widget _buildLiveKpiGrid(List<_DeskTool> tools) {
    void jumpTo(String id, {WidgetBuilder? customBuilder}) {
      final tool = tools.where((t) => t.id == id).firstOrNull;
      if (tool != null) {
        _openToolInTab(tool, customBuilder: customBuilder);
      }
    }

    final cards = <Widget>[
      if (_opsDash != null)
        _MiniWorkbenchKpi(
          title: 'فروش ۳۰ روز اخیر',
          value: '${money(_opsDash!.saleTotal)} ریال',
          sub: '${numFa(_opsDash!.saleCount)} فاکتور فروش ثبت‌شده',
          icon: Icons.trending_up_rounded,
          color: ShopColors.ok,
          onTap: () => jumpTo('sale'),
        ),
      if (_trsDash != null)
        _MiniWorkbenchKpi(
          title: 'نقدینگی کل خزانه',
          value: '${money(_trsDash!.totalBalance)} ریال',
          sub: 'بانک: ${money(_trsDash!.totalBankBalance)}',
          icon: Icons.account_balance_wallet_rounded,
          color: ShopColors.teal,
          onTap: () => jumpTo('trs-dashboard'),
        ),
      if (_creditSum != null)
        _MiniWorkbenchKpi(
          title: 'چک‌های در جریان',
          value: '${money(_creditSum!.inHandChequesTotal)} ریال',
          sub: _creditSum!.bouncedChequesCount > 0
              ? '${numFa(_creditSum!.bouncedChequesCount)} چک برگشتی!'
              : '${numFa(_creditSum!.inHandChequesCount)} فقره چک باز',
          icon: Icons.credit_card_rounded,
          color: _creditSum!.bouncedChequesCount > 0
              ? ShopColors.danger
              : ShopColors.seed,
          onTap: () => jumpTo(
            'credit-mgmt',
            customBuilder: (_) => const ShopCreditPage(initialTab: 0),
          ),
        ),
      if (_creditSum != null)
        _MiniWorkbenchKpi(
          title: 'اقساط باز مشتریان',
          value: '${money(_creditSum!.pendingInstallmentsTotal)} ریال',
          sub: _creditSum!.overdueInstallmentsCount > 0
              ? '${numFa(_creditSum!.overdueInstallmentsCount)} قسط معوق!'
              : '${numFa(_creditSum!.pendingInstallmentsCount)} نوبت قسط باز',
          icon: Icons.event_note_rounded,
          color: _creditSum!.overdueInstallmentsCount > 0
              ? ShopColors.warn
              : ShopColors.indigo,
          onTap: () => jumpTo(
            'credit-mgmt',
            customBuilder: (_) => const ShopCreditPage(initialTab: 1),
          ),
        ),
    ];

    if (cards.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 8));
      rows.add(
        Row(
          children: [
            Expanded(child: cards[i]),
            const SizedBox(width: 8),
            Expanded(
              child: i + 1 < cards.length ? cards[i + 1] : const SizedBox(),
            ),
          ],
        ),
      );
    }
    return Column(children: rows);
  }

  // -------------------- کارتابل پیگیری‌های فوری --------------------

  List<Widget> _buildWorkQueueAlerts(ShopPerms perms, List<_DeskTool> tools) {
    final items = <Widget>[];

    void openById(String id, {WidgetBuilder? customBuilder}) {
      final tool = tools.where((t) => t.id == id).firstOrNull;
      if (tool != null) _openToolInTab(tool, customBuilder: customBuilder);
    }

    if (_creditSum != null && _creditSum!.bouncedChequesCount > 0) {
      items.add(
        _WorkQueueRow(
          icon: Icons.report_gmailerrorred_rounded,
          color: ShopColors.danger,
          text:
              '${numFa(_creditSum!.bouncedChequesCount)} فقره چک برگشتی (${money(_creditSum!.bouncedChequesTotal)} ریال)',
          actionLabel: 'پیگیری چک‌ها',
          onTap: () => openById(
            'credit-mgmt',
            customBuilder: (_) => const ShopCreditPage(
              initialTab: 0,
              initialQuickFilter: 'bounced',
            ),
          ),
        ),
      );
    }

    if (_creditSum != null && _creditSum!.overdueInstallmentsCount > 0) {
      items.add(
        _WorkQueueRow(
          icon: Icons.schedule_rounded,
          color: ShopColors.warn,
          text:
              '${numFa(_creditSum!.overdueInstallmentsCount)} قسط معوق سررسید گذشته (${money(_creditSum!.overdueInstallmentsTotal)} ریال)',
          actionLabel: 'دفترچه اقساط',
          onTap: () => openById(
            'credit-mgmt',
            customBuilder: (_) => const ShopCreditPage(
              initialTab: 1,
              initialQuickFilter: 'pending',
            ),
          ),
        ),
      );
    }

    if (_trsDash != null && _trsDash!.draftCount > 0) {
      items.add(
        _WorkQueueRow(
          icon: Icons.pending_actions_rounded,
          color: ShopColors.indigo,
          text:
              '${numFa(_trsDash!.draftCount)} سند خزانه در حالت پیش‌نویس منتظر قطعی‌شدن',
          actionLabel: 'اسناد خزانه',
          onTap: () => openById('settlement'),
        ),
      );
    }

    if (_visStats != null &&
        perms.canApproveVisits &&
        _visStats!.submitted > 0) {
      items.add(
        _WorkQueueRow(
          icon: Icons.verified_rounded,
          color: ShopColors.seed,
          text:
              '${numFa(_visStats!.submitted)} سفارش ویزیتوری در انتظار تأیید مدیر فروش',
          actionLabel: 'بررسی و تأیید',
          onTap: () => openById('vis-approvals'),
        ),
      );
    }

    if (_visStats != null && perms.canFinanceVisit && _visStats!.approved > 0) {
      items.add(
        _WorkQueueRow(
          icon: Icons.point_of_sale_rounded,
          color: ShopColors.teal,
          text:
              '${numFa(_visStats!.approved)} سفارش تأییدشده در صف مالی آماده صدور فاکتور',
          actionLabel: 'صف مالی',
          onTap: () => openById('vis-finance'),
        ),
      );
    }

    if (_opsDash != null &&
        perms.canSeeRepairs &&
        _opsDash!.openRepairCount > 0) {
      items.add(
        _WorkQueueRow(
          icon: Icons.build_circle_rounded,
          color: ShopColors.accent,
          text:
              '${numFa(_opsDash!.openRepairCount)} دستگاه باز در کارگاه تعمیرات (${numFa(_opsDash!.openReadyCount)} آماده تحویل)',
          actionLabel: 'کارگاه',
          onTap: () => openById('repairs'),
        ),
      );
    }

    return items;
  }
}

// ============================================================
//  پوستهٔ مستقل هر تب باز با Navigator اختصاصی برای حفظ کامل وضعیت
// ============================================================

class _WorkspaceTabViewport extends StatelessWidget {
  const _WorkspaceTabViewport({
    super.key,
    required this.navKey,
    required this.builder,
  });

  final GlobalKey<NavigatorState> navKey;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navKey,
      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: builder),
    );
  }
}

// ============================================================
//  اجزای بصری میز کار
// ============================================================

class _QuickDockButton extends StatelessWidget {
  const _QuickDockButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                '+ $label',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniWorkbenchKpi extends StatelessWidget {
  const _MiniWorkbenchKpi({
    required this.title,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ShopColors.line),
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
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: ShopColors.inkSoft,
                      ),
                    ),
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 14, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: ShopColors.inkFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkQueueRow extends StatelessWidget {
  const _WorkQueueRow({
    required this.icon,
    required this.color,
    required this.text,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String text;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
          child: Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: ShopColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  actionLabel,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkbenchTileCard extends StatelessWidget {
  const _WorkbenchTileCard({
    required this.tool,
    required this.isOpen,
    required this.isPinned,
    required this.onTap,
    this.onLongPress,
  });

  final _DeskTool tool;
  final bool isOpen;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOpen
                  ? tool.color.withValues(alpha: 0.55)
                  : ShopColors.line,
              width: isOpen ? 1.4 : 1,
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
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tool.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(tool.icon, size: 18, color: tool.color),
                  ),
                  const Spacer(),
                  if (isPinned)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.push_pin_rounded,
                        size: 13,
                        color: tool.color,
                      ),
                    ),
                  if (isOpen)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: ShopColors.ok.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'تب باز',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: ShopColors.ok,
                        ),
                      ),
                    )
                  else
                    const Icon(
                      Icons.north_west_rounded,
                      size: 14,
                      color: ShopColors.inkFaint,
                    ),
                ],
              ),
              const Spacer(),
              Text(
                tool.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tool.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: ShopColors.inkFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
