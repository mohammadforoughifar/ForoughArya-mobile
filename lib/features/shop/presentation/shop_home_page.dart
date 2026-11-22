// ============================================================
//  «فروشگاهی کایر» — پوستهٔ ساختاریافته و چندتبی (Structured ERP Menu + Multi-Tab)
//  ساختار منویی دقیقاً منطبق بر وب (`Layout/NavMenu.razor` + `ShopSections.cs`):
//    ۱) اطلاعات پایه و تعاریف
//    ۲) عملیات روزانه و انبار
//    ۳) خزانه‌داری، چک و تسویه
//    ۴) گزارش‌ها و داشبوردها
//    ۵) فروش ویزیتوری و معرف‌ها
//    ۶) تنظیمات و راهنما
//  به‌همراه نوار تب‌های زنده (`IndexedStack`) برای حفظ وضعیت فرم‌های باز.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/utils/fa.dart';
import '../data/shop_perms.dart';
import '../models/order_models.dart';
import '../models/treasury_models.dart';
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
import 'reorder_report_page.dart';
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

enum _ShopGroup {
  basicInfo(
    title: 'اطلاعات پایه',
    subtitle: 'کالاها، قیمت‌گذاری، انبارها، طرف‌حساب‌ها، معرف‌ها و بانک/POS',
    icon: Icons.dns_rounded,
    color: ShopColors.seed,
  ),
  operations(
    title: 'عملیات',
    subtitle: 'فروش، خرید، بیجک، موجودی انبار، تعمیرات، گارانتی، تعویض و هزینه',
    icon: Icons.bolt_rounded,
    color: ShopColors.ok,
  ),
  treasury(
    title: 'خزانه‌داری، چک و تسویه',
    subtitle: 'تسویه فاکتورها، مدیریت اقساط و چک‌ها، چک خزانه و مانده اول دوره',
    icon: Icons.account_balance_wallet_rounded,
    color: ShopColors.teal,
  ),
  reports(
    title: 'گزارش‌ها و داشبورد',
    subtitle: 'داشبوردها، کاردکس، نقطه سفارش، گزارش خرید/فروش و صورت‌حساب اشخاص',
    icon: Icons.bar_chart_rounded,
    color: ShopColors.indigo,
  ),
  visits(
    title: 'فروش ویزیتوری و معرف‌ها',
    subtitle: 'سفارش‌های میدانی، کارتابل تأیید، صف مالی و کیف پول معرف‌ها',
    icon: Icons.directions_walk_rounded,
    color: ShopColors.warn,
  ),
  settings(
    title: 'تنظیمات و راهنما',
    subtitle: 'تنظیمات چاپ، سقف تخفیف ویزیتورها و راهنمای سامانه فروشگاهی',
    icon: Icons.tune_rounded,
    color: ShopColors.accent,
  );

  const _ShopGroup({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _DeskTool {
  const _DeskTool({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.group,
    required this.builder,
    this.keywords = '',
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final _ShopGroup group;
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
  int reloadVersion = 0;
  final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
}

class ShopHomePage extends StatefulWidget {
  const ShopHomePage({super.key});

  @override
  State<ShopHomePage> createState() => _ShopHomePageState();
}

class _ShopHomePageState extends State<ShopHomePage> {
  static const String _homeTabId = '__menu__';

  final List<_OpenWorkspaceTab> _openTabs = [];
  String _activeTabId = _homeTabId;
  _ShopGroup? _expandedGroup;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // -------------------- مدیریت تب‌های باز --------------------

  void _openToolInTab(_DeskTool tool, {WidgetBuilder? customBuilder}) {
    HapticFeedback.selectionClick();
    final existingIdx = _openTabs.indexWhere((t) => t.id == tool.id);
    setState(() {
      if (existingIdx >= 0) {
        if (customBuilder != null) {
          _openTabs[existingIdx].builder = customBuilder;
          _openTabs[existingIdx].reloadVersion++;
        }
        _activeTabId = _openTabs[existingIdx].id;
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

  void _closeTab(String id) {
    final idx = _openTabs.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    HapticFeedback.lightImpact();
    setState(() {
      _openTabs.removeAt(idx);
      if (_activeTabId == id) {
        if (_openTabs.isEmpty) {
          _activeTabId = _homeTabId;
        } else {
          final nextIdx = idx >= _openTabs.length ? _openTabs.length - 1 : idx;
          _activeTabId = _openTabs[nextIdx].id;
        }
      }
    });
  }

  void _closeAllTabs() {
    setState(() {
      _openTabs.clear();
      _activeTabId = _homeTabId;
    });
  }

  Future<void> _pushQuickForm(Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<dynamic>(builder: (_) => page));
  }

  // -------------------- تعریف فهرست ابزارها به تفکیک سرفصل وب --------------------

  List<_DeskTool> _buildTools(ShopPerms perms, bool isRef) {
    final showParties = perms.anyPartyAccess;
    final partiesLabel = perms.partiesMenuLabel;
    final partiesSubtitle = perms.canSeeCustomers && perms.canSeeSuppliers
        ? 'تعریف مشتریان و تأمین‌کنندگان'
        : (perms.canSeeCustomers ? 'تعریف مشتریان' : 'تعریف تأمین‌کنندگان');

    return <_DeskTool>[
      // ============ ۱) اطلاعات پایه ============
      if (perms.canSeeProducts)
        _DeskTool(
          id: 'products',
          title: 'کالاها و خدمات',
          subtitle: 'تعریف کالا، بارکد، ارزش افزوده، اکسل و نقطه سفارش',
          icon: Icons.inventory_2_rounded,
          color: ShopColors.seed,
          group: _ShopGroup.basicInfo,
          keywords: 'کالا خدمات بارکد اکسل فی فروش اطلاعات پایه',
          builder: (_) => const ProductsPage(),
        ),
      if (perms.canSeePricing)
        _DeskTool(
          id: 'pricing',
          title: 'قیمت‌گذاری و حداقل سود',
          subtitle: 'سیاست کف سود فروش، اصلاح گروهی قیمت و تاریخچه قیمت',
          icon: Icons.price_change_rounded,
          color: ShopColors.ok,
          group: _ShopGroup.basicInfo,
          keywords: 'قیمت گذاری حداقل سود افزایش قیمت گروهی',
          builder: (_) => const ShopPricingPage(),
        ),
      if (perms.canSeeCategories)
        _DeskTool(
          id: 'categories',
          title: 'گروه‌های کالا',
          subtitle: 'دسته‌بندی و گروه‌بندی کالاها',
          icon: Icons.sell_rounded,
          color: ShopColors.accent,
          group: _ShopGroup.basicInfo,
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
          group: _ShopGroup.basicInfo,
          keywords: 'واحد شمارش اندازه گیری',
          builder: (_) => const UnitsPage(),
        ),
      if (perms.canSeeWarehouses)
        _DeskTool(
          id: 'warehouses',
          title: 'انبارها',
          subtitle: 'تعریف انبارها و مراکز نگهداری کالا',
          icon: Icons.warehouse_rounded,
          color: ShopColors.indigo,
          group: _ShopGroup.basicInfo,
          keywords: 'انبار مراکز نگهداری',
          builder: (_) => const WarehousesPage(),
        ),
      if (showParties)
        _DeskTool(
          id: 'parties',
          title: partiesLabel,
          subtitle: partiesSubtitle,
          icon: Icons.people_alt_rounded,
          color: ShopColors.seed,
          group: _ShopGroup.basicInfo,
          keywords: 'مشتری تامین کننده طرف حساب اشخاص کد ملی',
          builder: (_) => const PartiesPage(),
        ),
      if (perms.canSeeReferrers)
        _DeskTool(
          id: 'referrers',
          title: 'معرف‌ها',
          subtitle: 'تعریف معرف‌ها و درصد پورسانت کالا و خدمات',
          icon: Icons.badge_rounded,
          color: ShopColors.teal,
          group: _ShopGroup.basicInfo,
          keywords: 'معرف بازاریاب پورسانت',
          builder: (_) => const ReferrersPage(),
        ),
      if (perms.canSeeBanks)
        _DeskTool(
          id: 'banks',
          title: 'بانک، صندوق و کارتخوان (POS)',
          subtitle: 'حساب‌های خزانه با مانده جاری، شبا، کارتخوان و گردش حساب',
          icon: Icons.account_balance_rounded,
          color: ShopColors.deep,
          group: _ShopGroup.basicInfo,
          keywords: 'بانک صندوق کارتخوان شبا حساب گردش',
          builder: (_) => const TrsAccountsPage(),
        ),

      // ============ ۲) عملیات ============
      if (perms.canSeeSale)
        _DeskTool(
          id: 'sale',
          title: 'فروش (فاکتور و پیش‌فاکتور)',
          subtitle: 'ثبت فاکتور فروش، پیش‌فاکتور، چاپ، نسیه و برگشت از فروش',
          icon: Icons.shopping_cart_rounded,
          color: ShopColors.ok,
          group: _ShopGroup.operations,
          keywords: 'فاکتور فروش پیش فاکتور مشتری برگشت از فروش',
          builder: (_) => const SaleOrdersPage(type: TxnType.sale),
        ),
      if (perms.canSeePurchase)
        _DeskTool(
          id: 'purchase',
          title: 'خرید (رسید خرید)',
          subtitle: 'ثبت رسید خرید، بروزرسانی فی فروش و چاپ رسید خرید',
          icon: Icons.shopping_bag_rounded,
          color: ShopColors.seed,
          group: _ShopGroup.operations,
          keywords: 'فاکتور خرید رسید تامین کننده',
          builder: (_) => const SaleOrdersPage(type: TxnType.purchase),
        ),
      if (perms.canSeeGoodsIssue)
        _DeskTool(
          id: 'goods-issue',
          title: 'بیجک (حوالهٔ تحویل کالا)',
          subtitle: 'ثبت و چاپ حواله خروج کالا بدون مبلغ (A4 / A5)',
          icon: Icons.local_shipping_rounded,
          color: ShopColors.teal,
          group: _ShopGroup.operations,
          keywords: 'بیجک حواله خروج ارسال بار',
          builder: (_) => const GoodsIssuesPage(),
        ),
      if (perms.canSeeStock)
        _DeskTool(
          id: 'stock',
          title: 'موجودی انبار و انبارگردانی',
          subtitle: 'موجودی لحظه‌ای به تفکیک انبار و ثبت تعدیل موجودی',
          icon: Icons.inventory_rounded,
          color: ShopColors.teal,
          group: _ShopGroup.operations,
          keywords: 'موجودی انبار کسری انبارگردانی تعدیل',
          builder: (_) => const StockPage(),
        ),
      if (perms.canSeeRepairs) ...[
        _DeskTool(
          id: 'repairs',
          title: 'تعمیرات',
          subtitle: 'پذیرش دستگاه، کارها و قطعات، چاپ قبض/فیش تحویل و فاکتور',
          icon: Icons.build_rounded,
          color: ShopColors.indigo,
          group: _ShopGroup.operations,
          keywords: 'تعمیر پذیرش دستگاه تکنسین فیش تحویل قبض',
          builder: (_) => const RepairsPage(),
        ),
        _DeskTool(
          id: 'warranty',
          title: 'پذیرش گارانتی',
          subtitle: 'بررسی گارانتی، ردیف‌های رایگان/ردشده و تسویه بدهی گارانتی',
          icon: Icons.verified_user_rounded,
          color: ShopColors.teal,
          group: _ShopGroup.operations,
          keywords: 'گارانتی پذیرش گارانتی تصمیم گارانتی تسویه',
          builder: (_) => const RepairsPage(initialTab: 1),
        ),
        _DeskTool(
          id: 'trade-in',
          title: 'طرح تعویض کالای کارکرده',
          subtitle: 'پذیرش دستگاه کارکرده، ثبت اعتبار مشتری و مصرف در فروش',
          icon: Icons.swap_horizontal_circle_rounded,
          color: ShopColors.accent,
          group: _ShopGroup.operations,
          keywords: 'طرح تعویض کالای کارکرده اعتبار مشتری دست دوم',
          builder: (_) => const RepairsPage(initialTab: 2),
        ),
      ],
      if (perms.canSeeExpenses)
        _DeskTool(
          id: 'expenses',
          title: 'هزینه‌ها',
          subtitle: 'ثبت اسناد هزینه جاری و مدیریت سرفصل‌های هزینه',
          icon: Icons.payments_rounded,
          color: ShopColors.danger,
          group: _ShopGroup.operations,
          keywords: 'هزینه تنخواه سرفصل',
          builder: (_) => const ExpensesPage(),
        ),

      // ============ ۳) خزانه‌داری، چک و تسویه ============
      if (perms.canSeeSettlement)
        _DeskTool(
          id: 'settlement',
          title: 'تسویه فاکتورها',
          subtitle: 'اسناد دریافت، پرداخت و انتقال بین حساب‌ها',
          icon: Icons.swap_horiz_rounded,
          color: ShopColors.seed,
          group: _ShopGroup.treasury,
          keywords: 'دریافت پرداخت انتقال تسویه سند خزانه',
          builder: (_) => const TrsVouchersPage(),
        ),
      if (perms.canSeeInstallments)
        _DeskTool(
          id: 'credit-mgmt',
          title: 'مدیریت اقساط و چک‌ها',
          subtitle: 'وصول به بانک، تغییر سررسید، تعویض چک، برگشت و دفترچه اقساط',
          icon: Icons.event_note_rounded,
          color: ShopColors.warn,
          group: _ShopGroup.treasury,
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
          group: _ShopGroup.treasury,
          keywords: 'چک خزانه صیادی واگذاری خرج چک',
          builder: (_) => const TrsChequesPage(),
        ),
      if (perms.canSeeOpeningBalance)
        _DeskTool(
          id: 'opening-balance',
          title: 'افتتاح حساب و مانده‌های اولیه',
          subtitle: 'طلب/بدهی اولیه اشخاص، چک‌ها، اقساط و موجودی اول دوره',
          icon: Icons.savings_rounded,
          color: ShopColors.accent,
          group: _ShopGroup.treasury,
          keywords: 'افتتاح حساب مانده اولیه اول دوره',
          builder: (_) => const OpeningBalancePage(),
        ),

      // ============ ۴) گزارش‌ها و داشبورد ============
      if (perms.canSeeDashboard)
        _DeskTool(
          id: 'ops-dashboard',
          title: 'داشبورد عملیاتی (خرید، فروش و تعمیرات)',
          subtitle: 'تحلیل نموداری خرید، فروش، خدمات تعمیراتی و معرف‌ها',
          icon: Icons.bar_chart_rounded,
          color: ShopColors.seed,
          group: _ShopGroup.reports,
          keywords: 'داشبورد عملیاتی نمودار سود',
          builder: (_) => const OpsDashboardPage(),
        ),
      if (perms.canSeeSettlement || perms.canSeeBanks || perms.canSeeCheques)
        _DeskTool(
          id: 'trs-dashboard',
          title: 'داشبورد خزانه',
          subtitle: 'نقدینگی کل، ورودی/خروجی دوره و چک‌های سررسید نزدیک',
          icon: Icons.account_balance_wallet_rounded,
          color: ShopColors.teal,
          group: _ShopGroup.reports,
          keywords: 'داشبورد خزانه نقدینگی موجودی بانک صندوق',
          builder: (_) => const TrsDashboardPage(),
        ),
      if (perms.canSeePartyStatements)
        _DeskTool(
          id: 'party-statements',
          title: 'گزارش طلب و بدهی اشخاص',
          subtitle: 'گردش حساب، مانده اشخاص و چاپ رسمی صورت‌حساب',
          icon: Icons.account_balance_wallet_outlined,
          color: ShopColors.indigo,
          group: _ShopGroup.reports,
          keywords: 'صورتحساب گردش حساب معین اشخاص بدهکار بستانکار',
          builder: (_) => const PartyStatementsPage(),
        ),
      if (perms.canSeeOrderReports) ...[
        _DeskTool(
          id: 'sale-report',
          title: 'گزارش فروش',
          subtitle: 'روند فروش، مشتریان برتر، سود و پورسانت و چاپ گزارش',
          icon: Icons.trending_up_rounded,
          color: ShopColors.ok,
          group: _ShopGroup.reports,
          keywords: 'گزارش فروش سود مشتریان برتر',
          builder: (_) => const OrderReportPage(type: TxnType.sale),
        ),
        _DeskTool(
          id: 'purchase-report',
          title: 'گزارش خرید',
          subtitle: 'تحلیل خرید دوره‌ای، تأمین‌کنندگان برتر و چاپ گزارش',
          icon: Icons.shopping_bag_outlined,
          color: ShopColors.seed,
          group: _ShopGroup.reports,
          keywords: 'گزارش خرید تامین کنندگان',
          builder: (_) => const OrderReportPage(type: TxnType.purchase),
        ),
      ],
      if (perms.canSeeKardex) ...[
        _DeskTool(
          id: 'kardex-qty',
          title: 'کاردکس تعدادی کالاها',
          subtitle: 'رهگیری خط‌به‌خط وارده، صادره و مانده فیزیکی کالا',
          icon: Icons.list_alt_rounded,
          color: ShopColors.accent,
          group: _ShopGroup.reports,
          keywords: 'کاردکس تعدادی گردش کالا',
          builder: (_) => const KardexPage(),
        ),
        _DeskTool(
          id: 'kardex-rial',
          title: 'کاردکس ریالی کالاها',
          subtitle: 'فی تمام‌شده، ارزش دفتری و میانگین بهای مانده انبار',
          icon: Icons.currency_exchange_rounded,
          color: ShopColors.warn,
          group: _ShopGroup.reports,
          keywords: 'کاردکس ریالی بهای تمام شده میانگین موزون',
          builder: (_) => const KardexPage(rial: true),
        ),
      ],
      if (perms.canSeeReorder)
        _DeskTool(
          id: 'reorder',
          title: 'نقطه سفارش و کسری کالا',
          subtitle: 'کالاهای زیر نقطه سفارش، مقدار کسری و پیشنهاد خرید مجدد',
          icon: Icons.production_quantity_limits_rounded,
          color: ShopColors.warn,
          group: _ShopGroup.reports,
          keywords: 'نقطه سفارش کسری موجودی خرید مجدد حداقل موجودی',
          builder: (_) => const ReorderReportPage(),
        ),
      if (perms.canSeeChequeIncomeReport)
        _DeskTool(
          id: 'cheque-income-report',
          title: 'گزارش تاخیر تادیه چک',
          subtitle: 'گردش درآمد کارمزد چک‌های مدت‌دار، تغییر سررسید و برگشت',
          icon: Icons.request_quote_rounded,
          color: ShopColors.teal,
          group: _ShopGroup.reports,
          keywords: 'تاخیر تادیه سود چک کارمزد چک',
          builder: (_) => const ChequeIncomeReportPage(),
        ),
      if (perms.canSeeRepairs)
        _DeskTool(
          id: 'warranty-report',
          title: 'گزارش گارانتی',
          subtitle: 'پذیرش‌های تحویل‌شده، هزینه داخلی و سهم مشتری',
          icon: Icons.verified_user_outlined,
          color: ShopColors.indigo,
          group: _ShopGroup.reports,
          keywords: 'گزارش گارانتی تعمیرات تحویل شده',
          builder: (_) => const WarrantyReportPage(),
        ),
      if (perms.canSeeExpenses)
        _DeskTool(
          id: 'expense-report',
          title: 'گزارش هزینه‌ها',
          subtitle: 'تجمیع اسناد هزینه به تفکیک سرفصل و خروجی CSV',
          icon: Icons.receipt_long_rounded,
          color: ShopColors.danger,
          group: _ShopGroup.reports,
          keywords: 'گزارش هزینه ها سرفصل',
          builder: (_) => const ExpenseReportPage(),
        ),
      if (perms.canSeeVisRequestsReport)
        _DeskTool(
          id: 'vis-requests-report',
          title: 'گزارش تجمیع سفارش‌ها',
          subtitle: 'تجمیع سفارش‌های ویزیتوری بر اساس کالا، ویزیتور و مشتری',
          icon: Icons.analytics_rounded,
          color: ShopColors.seed,
          group: _ShopGroup.reports,
          keywords: 'گزارش تجمیع ویزیتوری کسری کالا ویزیتور',
          builder: (_) => const VisRequestsReportPage(),
        ),

      // ============ ۵) فروش ویزیتوری و معرف‌ها ============
      if (perms.canSeeSalesVisit) ...[
        _DeskTool(
          id: 'my-visits',
          title: 'سفارش‌های من',
          subtitle: 'پیگیری وضعیت سفارش‌های ثبت‌شده توسط ویزیتور',
          icon: Icons.assignment_rounded,
          color: ShopColors.seed,
          group: _ShopGroup.visits,
          keywords: 'ویزیت سفارش های من ویزیتور',
          builder: (_) => const VisitsPage(),
        ),
        if (perms.canCreateVisit)
          _DeskTool(
            id: 'new-visit',
            title: 'ثبت سفارش ویزیتوری جدید',
            subtitle: 'ثبت سریع سفارش میدانی برای مشتری',
            icon: Icons.add_box_rounded,
            color: ShopColors.ok,
            group: _ShopGroup.visits,
            keywords: 'ثبت سفارش ویزیت جدید میدانی',
            builder: (_) => const VisitFormPage(),
          ),
        if (perms.canApproveVisits) ...[
          _DeskTool(
            id: 'vis-approvals',
            title: 'تأیید سفارش‌ها',
            subtitle: 'کارتابل مدیر فروش برای بررسی، تأیید یا رد سفارش‌ها',
            icon: Icons.verified_rounded,
            color: ShopColors.warn,
            group: _ShopGroup.visits,
            keywords: 'تایید سفارش مدیر فروش کارتابل',
            builder: (_) => const VisApprovalsPage(),
          ),
          _DeskTool(
            id: 'vis-all-requests',
            title: 'همهٔ درخواست‌ها',
            subtitle: 'آرشیو و پایش تمام سفارش‌های ویزیتوری شرکت',
            icon: Icons.collections_bookmark_rounded,
            color: ShopColors.indigo,
            group: _ShopGroup.visits,
            keywords: 'همه درخواست های ویزیتوری',
            builder: (_) => const VisRequestsPage(),
          ),
        ],
        if (perms.canFinanceVisit)
          _DeskTool(
            id: 'vis-finance',
            title: 'صف مالی سفارش‌ها',
            subtitle: 'تأیید تسویه و صدور خودکار فاکتور فروش از سفارش ویزیتوری',
            icon: Icons.point_of_sale_rounded,
            color: ShopColors.teal,
            group: _ShopGroup.visits,
            keywords: 'صف مالی ویزیتوری صدور فاکتور',
            builder: (_) => const VisFinanceQueuePage(),
          ),
      ],
      if (perms.canSeeReferrerWallets)
        _DeskTool(
          id: 'referrer-wallets',
          title: 'کیف پول معرف‌ها',
          subtitle: 'مانده پورسانت و ثبت اسناد تسویه با معرف‌ها',
          icon: Icons.wallet_rounded,
          color: ShopColors.ok,
          group: _ShopGroup.visits,
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
          group: _ShopGroup.visits,
          builder: (_) => const MyWalletPage(),
        ),
        _DeskTool(
          id: 'ref-my-products',
          title: 'کالاهای موجود روز',
          subtitle: 'مشاهده کالاهای موجود و قیمت فروش روز',
          icon: Icons.inventory_2_rounded,
          color: ShopColors.seed,
          group: _ShopGroup.visits,
          builder: (_) => const MyProductsPage(),
        ),
        _DeskTool(
          id: 'ref-my-card',
          title: 'کارت ویزیت دیجیتال من',
          subtitle: 'پیش‌نمایش کارت شناسایی معرف',
          icon: Icons.contact_page_rounded,
          color: ShopColors.indigo,
          group: _ShopGroup.visits,
          builder: (_) => const MyCardPage(),
        ),
      ],

      // ============ ۶) تنظیمات و راهنما ============
      if (perms.canSeePrintSettings)
        _DeskTool(
          id: 'print-settings',
          title: 'تنظیمات فروشگاه',
          subtitle: 'شماره کارت و شبای چاپ فاکتور و سقف تخفیف ویزیتورها',
          icon: Icons.settings_rounded,
          color: ShopColors.indigo,
          group: _ShopGroup.settings,
          keywords: 'تنظیمات چاپ فاکتور فروشگاه شبا سقف تخفیف',
          builder: (_) => const ShopPrintSettingsPage(),
        ),
      if (perms.canSeeGuide)
        _DeskTool(
          id: 'guide',
          title: 'راهنمای سامانه',
          subtitle: 'آموزش گام‌به‌گام بخش‌های فروشگاهی کایر',
          icon: Icons.menu_book_rounded,
          color: ShopColors.accent,
          group: _ShopGroup.settings,
          keywords: 'راهنما آموزش مستندات',
          builder: (_) => const ShopGuidePage(),
        ),
    ];
  }

  // -------------------- ساخت پوستهٔ اصلی --------------------

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
        appBar: AppBar(
          backgroundColor: ShopColors.surface,
          foregroundColor: ShopColors.ink,
          elevation: 0.5,
          titleSpacing: 4,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'فروشگاهی کایر',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              Text(
                'دسته‌بندی ساختاریافته بر اساس اطلاعات پایه، عملیات و گزارش‌ها',
                style: TextStyle(fontSize: 10, color: ShopColors.inkFaint),
              ),
            ],
          ),
          actions: [
            if (_openTabs.isNotEmpty)
              TextButton.icon(
                onPressed: _closeAllTabs,
                icon: const Icon(Icons.clear_all_rounded, size: 17),
                label: Text(
                  'بستن تب‌ها (${Fa.digits(_openTabs.length)})',
                  style: const TextStyle(fontSize: 11),
                ),
                style: TextButton.styleFrom(foregroundColor: ShopColors.inkSoft),
              ),
          ],
        ),
        body: Column(
          children: [
            if (_openTabs.isNotEmpty) _buildTabBar(),
            Expanded(
              child: IndexedStack(
                index: safeStackIdx,
                children: [
                  _buildStructuredMenu(perms, allTools),
                  for (final tab in _openTabs)
                    KeyedSubtree(
                      key: ValueKey('${tab.id}:${tab.reloadVersion}'),
                      child: Navigator(
                        key: tab.navKey,
                        onGenerateRoute: (_) =>
                            MaterialPageRoute<dynamic>(builder: tab.builder),
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

  Widget _buildTabBar() {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: ShopColors.surface,
        border: Border(bottom: BorderSide(color: ShopColors.line)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        children: [
          _tabChip(
            label: 'فهرست بخش‌ها',
            icon: Icons.folder_copy_rounded,
            selected: _activeTabId == _homeTabId,
            color: ShopColors.seed,
            onTap: () => setState(() => _activeTabId = _homeTabId),
          ),
          for (final t in _openTabs) ...[
            const SizedBox(width: 6),
            _tabChip(
              label: t.title,
              icon: t.icon,
              selected: _activeTabId == t.id,
              color: t.color,
              onTap: () => setState(() => _activeTabId = t.id),
              onClose: () => _closeTab(t.id),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tabChip({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    VoidCallback? onClose,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          onClose == null ? 10 : 6,
          0,
          10,
          0,
        ),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : ShopColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : ShopColors.line,
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? color : ShopColors.inkSoft,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? color : ShopColors.ink,
              ),
            ),
            if (onClose != null) ...[
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onClose,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: ShopColors.inkFaint,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // -------------------- نمای ساختاریافته و خلوت بخش‌ها --------------------

  Widget _buildStructuredMenu(ShopPerms perms, List<_DeskTool> allTools) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final isSearching = query.isNotEmpty;

    final filtered = isSearching
        ? allTools.where((t) {
            return t.title.toLowerCase().contains(query) ||
                t.subtitle.toLowerCase().contains(query) ||
                t.keywords.toLowerCase().contains(query) ||
                t.group.title.toLowerCase().contains(query);
          }).toList()
        : allTools;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        // ۱) جستجوی فوری جمع‌وجور
        TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: ShopColors.surface,
            hintText: 'جستجو در بخش‌ها (مثلاً کالا، فاکتور فروش، کاردکس، چک…)',
            hintStyle: const TextStyle(
              fontSize: 11.5,
              color: ShopColors.inkFaint,
            ),
            prefixIcon: const Icon(Icons.search_rounded, size: 19),
            suffixIcon: isSearching
                ? IconButton(
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded, size: 17),
                  )
                : null,
          ),
          style: const TextStyle(fontSize: 12.5),
        ),
        const SizedBox(height: 10),

        // ۲) ردیف جمع‌وجور ثبت سریع (فقط وقتی جستجو خالی است)
        if (!isSearching) ...[
          _buildQuickStrip(perms),
          const SizedBox(height: 12),
        ],

        // ۳) نتایج جستجو یا سرفصل‌های درختی ساختاریافته
        if (allTools.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: ShopEmpty(
              icon: Icons.lock_outline_rounded,
              title: 'بخشی برای حساب شما فعال نیست',
              subtitle: 'دسترسی‌های فروشگاهی را از مدیریت نقش‌ها بررسی کنید.',
            ),
          )
        else if (isSearching)
          filtered.isEmpty
              ? const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: ShopEmpty(
                    icon: Icons.search_off_rounded,
                    title: 'بخشی با این عبارت یافت نشد',
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: ShopColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ShopColors.line),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < filtered.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            indent: 52,
                            color: ShopColors.line,
                          ),
                        _buildMenuRow(filtered[i], showGroupBadge: true),
                      ],
                    ],
                  ),
                )
        else
          for (final group in _ShopGroup.values)
            Builder(
              builder: (_) {
                final items = allTools.where((t) => t.group == group).toList();
                if (items.isEmpty) return const SizedBox.shrink();
                final expanded = _expandedGroup == group;
                return _buildGroupFolder(
                  group: group,
                  items: items,
                  expanded: expanded,
                  onToggle: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _expandedGroup = expanded ? null : group;
                    });
                  },
                );
              },
            ),
      ],
    );
  }

  Widget _buildQuickStrip(ShopPerms perms) {
    final actions = <(String, IconData, Color, VoidCallback)>[
      if (perms.canManageSection('Sale'))
        (
          'فاکتور فروش',
          Icons.add_shopping_cart_rounded,
          ShopColors.ok,
          () => _pushQuickForm(const OrderFormPage(type: TxnType.sale)),
        ),
      if (perms.canManageSection('Purchase'))
        (
          'رسید خرید',
          Icons.shopping_bag_rounded,
          ShopColors.seed,
          () => _pushQuickForm(const OrderFormPage(type: TxnType.purchase)),
        ),
      if (perms.canManageSection('Settlement'))
        (
          'دریافت / پرداخت',
          Icons.payments_rounded,
          ShopColors.teal,
          () => _pushQuickForm(
            const TrsVoucherFormPage(kind: TrsKind.receipt),
          ),
        ),
      if (perms.canSeeRepairs)
        (
          'تعمیرات',
          Icons.build_rounded,
          ShopColors.indigo,
          () => _pushQuickForm(const RepairsPage()),
        ),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: actions[i].$4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: ShopColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ShopColors.line),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(actions[i].$2, size: 18, color: actions[i].$3),
                    const SizedBox(height: 4),
                    Text(
                      actions[i].$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: ShopColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGroupFolder({
    required _ShopGroup group,
    required List<_DeskTool> items,
    required bool expanded,
    required VoidCallback onToggle,
  }) {
    final openInGroup = items
        .where((it) => _openTabs.any((t) => t.id == it.id))
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: expanded ? group.color.withValues(alpha: 0.5) : ShopColors.line,
          width: expanded ? 1.3 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom: Radius.circular(expanded ? 0 : 16),
            ),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: group.color.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(group.icon, size: 21, color: group.color),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              group.title,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: ShopColors.ink,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: ShopColors.bg,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '${Fa.digits(items.length)} بخش',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: ShopColors.inkSoft,
                                ),
                              ),
                            ),
                            if (openInGroup > 0) ...[
                              const SizedBox(width: 5),
                              ShopTag(
                                text: '${Fa.digits(openInGroup)} باز',
                                color: group.color,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          group.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: ShopColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: expanded ? group.color : ShopColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: ShopColors.line),
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                const Divider(height: 1, indent: 52, color: ShopColors.line),
              _buildMenuRow(items[i]),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMenuRow(_DeskTool tool, {bool showGroupBadge = false}) {
    final isOpen = _openTabs.any((t) => t.id == tool.id);
    return InkWell(
      onTap: () => _openToolInTab(tool),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: tool.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(tool.icon, size: 17, color: tool.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          tool.title,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: ShopColors.ink,
                          ),
                        ),
                      ),
                      if (showGroupBadge) ...[
                        const SizedBox(width: 6),
                        ShopTag(text: tool.group.title, color: tool.group.color),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    tool.subtitle,
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
            if (isOpen)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: ShopTag(text: 'تب باز', color: tool.color),
              ),
            const Icon(
              Icons.chevron_left_rounded,
              size: 18,
              color: ShopColors.inkFaint,
            ),
          ],
        ),
      ),
    );
  }
}
