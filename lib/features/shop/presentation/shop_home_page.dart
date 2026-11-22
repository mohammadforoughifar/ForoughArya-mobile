// ============================================================
//  «فروشگاهی کایر» — میز فرماندهی بازرگانی، انبار، خزانه و چندتبی
//  ساختار منویی ۱۰۰٪ منطبق بر وب (`Layout/NavMenu.razor` + `ShopSections.cs`):
//    ۱) اطلاعات پایه و تعاریف
//    ۲) عملیات روزانه و انبار
//    ۳) خزانه‌داری، چک و تسویه
//    ۴) گزارش‌ها و داشبوردها
//    ۵) فروش ویزیتوری و معرف‌ها
//    ۶) تنظیمات و راهنما
//  امکانات ویژهٔ طراحی جدید:
//    • سربرگ فرماندهی لوکس کایر با نبض زندهٔ فروش، خزانه، چک/تعمیرات و کسری انبار
//    • نوار تب‌های زنده (`IndexedStack`) برای حفظ کامل وضعیت فرم‌های باز
//    • میز ثبت فوری اسناد یک‌ضربه‌ای (فاکتور فروش، پیش‌فاکتور، خرید، دریافت/پرداخت و…)
//    • فرمان‌یار جستجوی سریع (`Command Sheet`)، سنجاق‌کردن بخش‌های منتخب و دو حالت نمایش
//      بنتو کارتی مدرن (۲ ستونی) و فهرست ساختاریافتهٔ پوشه‌ای.
// ============================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../data/shop_perms.dart';
import '../data/shop_repository.dart';
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
    shortTitle: 'اطلاعات پایه',
    subtitle: 'کالاها، قیمت‌گذاری، انبارها، طرف‌حساب‌ها، معرف‌ها و بانک/POS',
    icon: Icons.layers_rounded,
    color: Color(0xff2563eb),
    gradientEnd: Color(0xff4f46e5),
  ),
  operations(
    title: 'عملیات و انبار',
    shortTitle: 'عملیات',
    subtitle: 'فروش، خرید، بیجک، موجودی انبار، تعمیرات، گارانتی، تعویض و هزینه',
    icon: Icons.bolt_rounded,
    color: Color(0xff059669),
    gradientEnd: Color(0xff0d9488),
  ),
  treasury(
    title: 'خزانه‌داری، چک و تسویه',
    shortTitle: 'خزانه و چک',
    subtitle: 'تسویه فاکتورها، مدیریت اقساط و چک‌ها، چک خزانه و مانده اول دوره',
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xff0f766e),
    gradientEnd: Color(0xff0284c7),
  ),
  reports(
    title: 'گزارش‌ها و داشبورد',
    shortTitle: 'گزارش و داشبورد',
    subtitle: 'داشبوردها، کاردکس، نقطه سفارش، گزارش خرید/فروش و صورت‌حساب اشخاص',
    icon: Icons.insights_rounded,
    color: Color(0xff4338ca),
    gradientEnd: Color(0xff7c3aed),
  ),
  visits(
    title: 'فروش ویزیتوری و معرف‌ها',
    shortTitle: 'ویزیت و معرف',
    subtitle: 'سفارش‌های میدانی، کارتابل تأیید، صف مالی و کیف پول معرف‌ها',
    icon: Icons.directions_walk_rounded,
    color: Color(0xffd97706),
    gradientEnd: Color(0xffea580c),
  ),
  settings(
    title: 'تنظیمات و راهنما',
    shortTitle: 'تنظیمات',
    subtitle: 'تنظیمات چاپ، سقف تخفیف ویزیتورها و راهنمای سامانه فروشگاهی کایر',
    icon: Icons.tune_rounded,
    color: Color(0xff6d28d9),
    gradientEnd: Color(0xff9333ea),
  );

  const _ShopGroup({
    required this.title,
    required this.shortTitle,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.gradientEnd,
  });

  final String title;
  final String shortTitle;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color gradientEnd;

  LinearGradient get gradient => LinearGradient(
    colors: [color, gradientEnd],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
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
    this.gradientEnd,
    this.keywords = '',
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color? gradientEnd;
  final _ShopGroup group;
  final WidgetBuilder builder;
  final String keywords;

  LinearGradient get iconGradient => LinearGradient(
    colors: [color, gradientEnd ?? group.gradientEnd],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
}

class _ExpressAction {
  const _ExpressAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.gradientEnd,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color gradientEnd;
  final VoidCallback onTap;
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

class _KayerLiveStats {
  const _KayerLiveStats({
    this.loaded = false,
    this.todaySales = 0,
    this.todaySaleCount = 0,
    this.treasuryBalance = 0,
    this.overdueCheques = 0,
    this.openRepairs = 0,
    this.reorderCount = 0,
  });

  final bool loaded;
  final double todaySales;
  final int todaySaleCount;
  final double treasuryBalance;
  final int overdueCheques;
  final int openRepairs;
  final int reorderCount;
}

class ShopHomePage extends StatefulWidget {
  const ShopHomePage({super.key});

  @override
  State<ShopHomePage> createState() => _ShopHomePageState();
}

class _ShopHomePageState extends State<ShopHomePage> {
  static const String _homeTabId = '__menu__';
  static const String _prefsKey = 'kayer.ui.prefs.v1';
  static const List<String> _defaultPinned = [
    'sale',
    'purchase',
    'products',
    'stock',
    'settlement',
    'ops-dashboard',
  ];

  final _storage = const FlutterSecureStorage();
  final List<_OpenWorkspaceTab> _openTabs = [];
  String _activeTabId = _homeTabId;

  _ShopGroup? _selectedCategory;
  final Set<int> _expandedGroups = {0, 1};
  bool _bentoMode = true;
  List<String> _pinnedIds = List<String>.from(_defaultPinned);

  final _searchCtrl = TextEditingController();
  _KayerLiveStats _stats = const _KayerLiveStats();
  bool _statsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLiveStats());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    try {
      final raw = await _storage.read(key: _prefsKey);
      if (raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw);
      if (map is! Map) return;
      if (!mounted) return;
      setState(() {
        _bentoMode = map['bentoMode'] as bool? ?? true;
        final pins = map['pinnedIds'];
        if (pins is List) {
          _pinnedIds = pins.map((e) => e.toString()).toList();
        }
      });
    } catch (_) {}
  }

  Future<void> _savePrefs() async {
    try {
      await _storage.write(
        key: _prefsKey,
        value: jsonEncode({'bentoMode': _bentoMode, 'pinnedIds': _pinnedIds}),
      );
    } catch (_) {}
  }

  void _togglePin(String id) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_pinnedIds.contains(id)) {
        _pinnedIds = _pinnedIds.where((e) => e != id).toList();
      } else {
        _pinnedIds = [..._pinnedIds, id];
      }
    });
    _savePrefs();
  }

  Future<void> _loadLiveStats() async {
    if (!mounted || _statsLoading) return;
    ApiClient? api;
    AuthController? auth;
    try {
      api = Provider.of<ApiClient?>(context, listen: false);
      auth = Provider.of<AuthController?>(context, listen: false);
    } catch (_) {
      return;
    }
    if (api == null || auth == null) return;

    final perms = ShopPerms(auth.session);
    setState(() => _statsLoading = true);

    final repo = ShopRepository(api);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    double todaySales = 0;
    int todaySaleCount = 0;
    double treasuryBalance = 0;
    int overdueCheques = 0;
    int openRepairs = 0;
    int reorderCount = 0;

    await Future.wait<void>([
      if (perms.canSeeDashboard || perms.canSeeSale || perms.canSeeRepairs)
        () async {
          try {
            final ops = await repo.opsDashboard(from: todayStart, to: now);
            todaySales = ops.saleTotal;
            todaySaleCount = ops.saleCount;
            openRepairs = ops.openRepairCount;
          } catch (_) {}
        }(),
      if (perms.canSeeSettlement || perms.canSeeBanks || perms.canSeeCheques)
        () async {
          try {
            final trs = await repo.treasuryDashboard(from: todayStart, to: now);
            treasuryBalance = trs.totalBalance;
            overdueCheques = trs.overdueChequeCount;
          } catch (_) {}
        }(),
      if (perms.canSeeReorder || perms.canSeeStock || perms.canSeeProducts)
        () async {
          try {
            final ro = await repo.reorderItems(take: 1);
            reorderCount = ro.total ?? ro.items.length;
          } catch (_) {}
        }(),
    ]);

    if (!mounted) return;
    setState(() {
      _statsLoading = false;
      _stats = _KayerLiveStats(
        loaded: true,
        todaySales: todaySales,
        todaySaleCount: todaySaleCount,
        treasuryBalance: treasuryBalance,
        overdueCheques: overdueCheques,
        openRepairs: openRepairs,
        reorderCount: reorderCount,
      );
    });
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

  void _openToolById(List<_DeskTool> tools, String id) {
    final found = tools.where((t) => t.id == id).firstOrNull;
    if (found != null) {
      _openToolInTab(found);
    }
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
    HapticFeedback.mediumImpact();
    setState(() {
      _openTabs.clear();
      _activeTabId = _homeTabId;
    });
  }

  Future<void> _pushQuickForm(Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<dynamic>(builder: (_) => page));
    if (mounted) _loadLiveStats();
  }

  void _openCommandSheet(
    List<_DeskTool> allTools,
    List<_ExpressAction> expressActions,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _KayerCommandSheet(
        tools: allTools,
        expressActions: expressActions,
        onSelectTool: _openToolInTab,
      ),
    );
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
          subtitle: 'تعریف کالا، بارکدخوان، ارزش افزوده، اکسل و نقطه سفارش',
          icon: Icons.inventory_2_rounded,
          color: const Color(0xff2563eb),
          gradientEnd: const Color(0xff0284c7),
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
          color: const Color(0xff059669),
          gradientEnd: const Color(0xff10b981),
          group: _ShopGroup.basicInfo,
          keywords: 'قیمت گذاری حداقل سود افزایش قیمت گروهی',
          builder: (_) => const ShopPricingPage(),
        ),
      if (perms.canSeeCategories)
        _DeskTool(
          id: 'categories',
          title: 'گروه‌های کالا',
          subtitle: 'دسته‌بندی درختی و گروه‌بندی کالاها',
          icon: Icons.category_rounded,
          color: const Color(0xff7c3aed),
          gradientEnd: const Color(0xff6366f1),
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
          color: const Color(0xff475569),
          gradientEnd: const Color(0xff334155),
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
          color: const Color(0xff4338ca),
          gradientEnd: const Color(0xff2563eb),
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
          color: const Color(0xff0284c7),
          gradientEnd: const Color(0xff2563eb),
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
          color: const Color(0xff0d9488),
          gradientEnd: const Color(0xff059669),
          group: _ShopGroup.basicInfo,
          keywords: 'معرف بازاریاب پورسانت',
          builder: (_) => const ReferrersPage(),
        ),
      if (perms.canSeeBanks)
        _DeskTool(
          id: 'banks',
          title: 'بانک، صندوق و کارتخوان',
          subtitle: 'حساب‌های خزانه با مانده جاری، شبا، POS و گردش حساب',
          icon: Icons.account_balance_rounded,
          color: const Color(0xff1e3a8a),
          gradientEnd: const Color(0xff3b82f6),
          group: _ShopGroup.basicInfo,
          keywords: 'بانک صندوق کارتخوان شبا حساب گردش pos',
          builder: (_) => const TrsAccountsPage(),
        ),

      // ============ ۲) عملیات و انبار ============
      if (perms.canSeeSale)
        _DeskTool(
          id: 'sale',
          title: 'فروش و پیش‌فاکتور',
          subtitle: 'فاکتور فروش، پیش‌فاکتور، چاپ، نسیه و برگشت از فروش',
          icon: Icons.shopping_cart_checkout_rounded,
          color: const Color(0xff059669),
          gradientEnd: const Color(0xff10b981),
          group: _ShopGroup.operations,
          keywords: 'فاکتور فروش پیش فاکتور مشتری برگشت از فروش بارکد',
          builder: (_) => const SaleOrdersPage(type: TxnType.sale),
        ),
      if (perms.canSeePurchase)
        _DeskTool(
          id: 'purchase',
          title: 'خرید (رسید خرید)',
          subtitle: 'ثبت رسید خرید، بروزرسانی فی فروش و چاپ رسید خرید',
          icon: Icons.shopping_bag_rounded,
          color: const Color(0xff2563eb),
          gradientEnd: const Color(0xff4f46e5),
          group: _ShopGroup.operations,
          keywords: 'فاکتور خرید رسید تامین کننده بارکد',
          builder: (_) => const SaleOrdersPage(type: TxnType.purchase),
        ),
      if (perms.canSeeGoodsIssue)
        _DeskTool(
          id: 'goods-issue',
          title: 'بیجک (حوالهٔ خروج)',
          subtitle: 'ثبت و چاپ حواله تحویل کالا بدون مبلغ (A4 / A5)',
          icon: Icons.local_shipping_rounded,
          color: const Color(0xff0d9488),
          gradientEnd: const Color(0xff0284c7),
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
          color: const Color(0xff0f766e),
          gradientEnd: const Color(0xff059669),
          group: _ShopGroup.operations,
          keywords: 'موجودی انبار کسری انبارگردانی تعدیل',
          builder: (_) => const StockPage(),
        ),
      if (perms.canSeeRepairs) ...[
        _DeskTool(
          id: 'repairs',
          title: 'پذیرش و خدمات تعمیرات',
          subtitle: 'پذیرش دستگاه، قطعات و اجرت، چاپ قبض تحویل و فاکتور',
          icon: Icons.handyman_rounded,
          color: const Color(0xff4f46e5),
          gradientEnd: const Color(0xff7c3aed),
          group: _ShopGroup.operations,
          keywords: 'تعمیر پذیرش دستگاه تکنسین فیش تحویل قبض',
          builder: (_) => const RepairsPage(),
        ),
        _DeskTool(
          id: 'warranty',
          title: 'پذیرش گارانتی',
          subtitle: 'بررسی گارانتی، ردیف‌های رایگان/ردشده و تسویه گارانتی',
          icon: Icons.verified_user_rounded,
          color: const Color(0xff0284c7),
          gradientEnd: const Color(0xff0d9488),
          group: _ShopGroup.operations,
          keywords: 'گارانتی پذیرش گارانتی تصمیم گارانتی تسویه',
          builder: (_) => const RepairsPage(initialTab: 1),
        ),
        _DeskTool(
          id: 'trade-in',
          title: 'طرح تعویض کالای کارکرده',
          subtitle: 'پذیرش دستگاه کارکرده، ثبت اعتبار مشتری و مصرف در فروش',
          icon: Icons.published_with_changes_rounded,
          color: const Color(0xff7c3aed),
          gradientEnd: const Color(0xffc026d3),
          group: _ShopGroup.operations,
          keywords: 'طرح تعویض کالای کارکرده اعتبار مشتری دست دوم',
          builder: (_) => const RepairsPage(initialTab: 2),
        ),
      ],
      if (perms.canSeeExpenses)
        _DeskTool(
          id: 'expenses',
          title: 'ثبت هزینه‌های جاری',
          subtitle: 'ثبت اسناد هزینه عملیاتی و مدیریت سرفصل‌های هزینه',
          icon: Icons.receipt_long_rounded,
          color: const Color(0xffdc2626),
          gradientEnd: const Color(0xffea580c),
          group: _ShopGroup.operations,
          keywords: 'هزینه تنخواه سرفصل',
          builder: (_) => const ExpensesPage(),
        ),

      // ============ ۳) خزانه‌داری، چک و تسویه ============
      if (perms.canSeeSettlement)
        _DeskTool(
          id: 'settlement',
          title: 'اسناد تسویه و خزانه',
          subtitle: 'اسناد دریافت، پرداخت و انتقال وجه بین حساب‌ها',
          icon: Icons.currency_exchange_rounded,
          color: const Color(0xff0f766e),
          gradientEnd: const Color(0xff059669),
          group: _ShopGroup.treasury,
          keywords: 'دریافت پرداخت انتقال تسویه سند خزانه',
          builder: (_) => const TrsVouchersPage(),
        ),
      if (perms.canSeeInstallments)
        _DeskTool(
          id: 'credit-mgmt',
          title: 'مدیریت اقساط و چک‌ها',
          subtitle: 'وصول به بانک، تغییر سررسید، تعویض چک، برگشت و دفترچه اقساط',
          icon: Icons.event_repeat_rounded,
          color: const Color(0xffd97706),
          gradientEnd: const Color(0xffea580c),
          group: _ShopGroup.treasury,
          keywords: 'چک اقساط قسط سررسید برگشتی تعویض وصول',
          builder: (_) => const ShopCreditPage(),
        ),
      if (perms.canSeeCheques)
        _DeskTool(
          id: 'trs-cheques',
          title: 'چک‌های خزانه‌داری',
          subtitle: 'صدور، واگذاری به بانک، خرج کردن، وصول و برگشت چک',
          icon: Icons.payments_rounded,
          color: const Color(0xff4338ca),
          gradientEnd: const Color(0xff2563eb),
          group: _ShopGroup.treasury,
          keywords: 'چک خزانه صیادی واگذاری خرج چک',
          builder: (_) => const TrsChequesPage(),
        ),
      if (perms.canSeeOpeningBalance)
        _DeskTool(
          id: 'opening-balance',
          title: 'افتتاح حساب و مانده اولیه',
          subtitle: 'طلب/بدهی اولیه اشخاص، چک‌ها، اقساط و موجودی اول دوره',
          icon: Icons.savings_rounded,
          color: const Color(0xff6d28d9),
          gradientEnd: const Color(0xff4f46e5),
          group: _ShopGroup.treasury,
          keywords: 'افتتاح حساب مانده اولیه اول دوره',
          builder: (_) => const OpeningBalancePage(),
        ),

      // ============ ۴) گزارش‌ها و داشبورد ============
      if (perms.canSeeDashboard)
        _DeskTool(
          id: 'ops-dashboard',
          title: 'داشبورد عملیاتی کایر',
          subtitle: 'تحلیل نموداری خرید، فروش، خدمات تعمیراتی و معرف‌ها',
          icon: Icons.insights_rounded,
          color: const Color(0xff2563eb),
          gradientEnd: const Color(0xff7c3aed),
          group: _ShopGroup.reports,
          keywords: 'داشبورد عملیاتی نمودار سود',
          builder: (_) => const OpsDashboardPage(),
        ),
      if (perms.canSeeSettlement || perms.canSeeBanks || perms.canSeeCheques)
        _DeskTool(
          id: 'trs-dashboard',
          title: 'داشبورد خزانه و نقدینگی',
          subtitle: 'نقدینگی کل، ورودی/خروجی دوره و چک‌های سررسید نزدیک',
          icon: Icons.account_balance_wallet_rounded,
          color: const Color(0xff0d9488),
          gradientEnd: const Color(0xff0284c7),
          group: _ShopGroup.reports,
          keywords: 'داشبورد خزانه نقدینگی موجودی بانک صندوق',
          builder: (_) => const TrsDashboardPage(),
        ),
      if (perms.canSeePartyStatements)
        _DeskTool(
          id: 'party-statements',
          title: 'صورت‌حساب و مانده اشخاص',
          subtitle: 'گردش حساب، طلب و بدهی اشخاص و چاپ رسمی صورت‌حساب',
          icon: Icons.switch_account_rounded,
          color: const Color(0xff4338ca),
          gradientEnd: const Color(0xff2563eb),
          group: _ShopGroup.reports,
          keywords: 'صورتحساب گردش حساب معین اشخاص بدهکار بستانکار',
          builder: (_) => const PartyStatementsPage(),
        ),
      if (perms.canSeeOrderReports) ...[
        _DeskTool(
          id: 'sale-report',
          title: 'گزارش تحلیلی فروش',
          subtitle: 'روند فروش، مشتریان برتر، سود و پورسانت و چاپ گزارش',
          icon: Icons.trending_up_rounded,
          color: const Color(0xff059669),
          gradientEnd: const Color(0xff10b981),
          group: _ShopGroup.reports,
          keywords: 'گزارش فروش سود مشتریان برتر',
          builder: (_) => const OrderReportPage(type: TxnType.sale),
        ),
        _DeskTool(
          id: 'purchase-report',
          title: 'گزارش تحلیلی خرید',
          subtitle: 'تحلیل خرید دوره‌ای، تأمین‌کنندگان برتر و چاپ گزارش',
          icon: Icons.shopping_bag_outlined,
          color: const Color(0xff1d4ed8),
          gradientEnd: const Color(0xff0284c7),
          group: _ShopGroup.reports,
          keywords: 'گزارش خرید تامین کنندگان',
          builder: (_) => const OrderReportPage(type: TxnType.purchase),
        ),
      ],
      if (perms.canSeeKardex) ...[
        _DeskTool(
          id: 'kardex-qty',
          title: 'کاردکس تعدادی کالا',
          subtitle: 'رهگیری خط‌به‌خط وارده، صادره و مانده فیزیکی کالا',
          icon: Icons.list_alt_rounded,
          color: const Color(0xff6d28d9),
          gradientEnd: const Color(0xff4f46e5),
          group: _ShopGroup.reports,
          keywords: 'کاردکس تعدادی گردش کالا',
          builder: (_) => const KardexPage(),
        ),
        _DeskTool(
          id: 'kardex-rial',
          title: 'کاردکس ریالی کالا',
          subtitle: 'فی تمام‌شده، ارزش دفتری و میانگین بهای مانده انبار',
          icon: Icons.monetization_on_rounded,
          color: const Color(0xffd97706),
          gradientEnd: const Color(0xffb45309),
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
          color: const Color(0xffea580c),
          gradientEnd: const Color(0xffdc2626),
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
          color: const Color(0xff0f766e),
          gradientEnd: const Color(0xff0d9488),
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
          color: const Color(0xff4f46e5),
          gradientEnd: const Color(0xff6366f1),
          group: _ShopGroup.reports,
          keywords: 'گزارش گارانتی تعمیرات تحویل شده',
          builder: (_) => const WarrantyReportPage(),
        ),
      if (perms.canSeeExpenses)
        _DeskTool(
          id: 'expense-report',
          title: 'گزارش هزینه‌ها',
          subtitle: 'تجمیع اسناد هزینه به تفکیک سرفصل و خروجی CSV',
          icon: Icons.pie_chart_rounded,
          color: const Color(0xffdc2626),
          gradientEnd: const Color(0xffe11d48),
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
          color: const Color(0xff0284c7),
          gradientEnd: const Color(0xff2563eb),
          group: _ShopGroup.reports,
          keywords: 'گزارش تجمیع ویزیتوری کسری کالا ویزیتور',
          builder: (_) => const VisRequestsReportPage(),
        ),

      // ============ ۵) فروش ویزیتوری و معرف‌ها ============
      if (perms.canSeeSalesVisit) ...[
        _DeskTool(
          id: 'my-visits',
          title: 'سفارش‌های ویزیتوری من',
          subtitle: 'پیگیری وضعیت سفارش‌های ثبت‌شده توسط ویزیتور',
          icon: Icons.assignment_rounded,
          color: const Color(0xff2563eb),
          gradientEnd: const Color(0xff0284c7),
          group: _ShopGroup.visits,
          keywords: 'ویزیت سفارش های من ویزیتور',
          builder: (_) => const VisitsPage(),
        ),
        if (perms.canCreateVisit)
          _DeskTool(
            id: 'new-visit',
            title: 'ثبت سفارش ویزیتوری جدید',
            subtitle: 'ثبت سریع سفارش میدانی برای مشتری',
            icon: Icons.add_location_alt_rounded,
            color: const Color(0xff059669),
            gradientEnd: const Color(0xff10b981),
            group: _ShopGroup.visits,
            keywords: 'ثبت سفارش ویزیت جدید میدانی',
            builder: (_) => const VisitFormPage(),
          ),
        if (perms.canApproveVisits) ...[
          _DeskTool(
            id: 'vis-approvals',
            title: 'کارتابل تأیید سفارش‌ها',
            subtitle: 'بررسی موجودی، سقف تخفیف و تأیید/رد مدیر فروش',
            icon: Icons.verified_rounded,
            color: const Color(0xffd97706),
            gradientEnd: const Color(0xffea580c),
            group: _ShopGroup.visits,
            keywords: 'تایید سفارش مدیر فروش کارتابل',
            builder: (_) => const VisApprovalsPage(),
          ),
          _DeskTool(
            id: 'vis-all-requests',
            title: 'آرشیو همهٔ درخواست‌ها',
            subtitle: 'پایش کامل تمام سفارش‌های ویزیتوری شرکت',
            icon: Icons.collections_bookmark_rounded,
            color: const Color(0xff4338ca),
            gradientEnd: const Color(0xff6366f1),
            group: _ShopGroup.visits,
            keywords: 'همه درخواست های ویزیتوری',
            builder: (_) => const VisRequestsPage(),
          ),
        ],
        if (perms.canFinanceVisit)
          _DeskTool(
            id: 'vis-finance',
            title: 'صف مالی و صدور فاکتور',
            subtitle: 'تأیید تسویه و تبدیل خودکار سفارش ویزیتوری به فاکتور فروش',
            icon: Icons.point_of_sale_rounded,
            color: const Color(0xff0f766e),
            gradientEnd: const Color(0xff059669),
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
          color: const Color(0xff059669),
          gradientEnd: const Color(0xff0d9488),
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
          color: const Color(0xff059669),
          group: _ShopGroup.visits,
          builder: (_) => const MyWalletPage(),
        ),
        _DeskTool(
          id: 'ref-my-products',
          title: 'کالاهای موجود روز',
          subtitle: 'مشاهده کالاهای موجود و قیمت فروش روز',
          icon: Icons.inventory_2_rounded,
          color: const Color(0xff2563eb),
          group: _ShopGroup.visits,
          builder: (_) => const MyProductsPage(),
        ),
        _DeskTool(
          id: 'ref-my-card',
          title: 'کارت ویزیت دیجیتال من',
          subtitle: 'پیش‌نمایش کارت شناسایی معرف',
          icon: Icons.contact_page_rounded,
          color: const Color(0xff4338ca),
          group: _ShopGroup.visits,
          builder: (_) => const MyCardPage(),
        ),
      ],

      // ============ ۶) تنظیمات و راهنما ============
      if (perms.canSeePrintSettings)
        _DeskTool(
          id: 'print-settings',
          title: 'تنظیمات فروشگاه و چاپ',
          subtitle: 'شماره کارت و شبای چاپ فاکتور و سقف تخفیف ویزیتورها',
          icon: Icons.settings_suggest_rounded,
          color: const Color(0xff4338ca),
          gradientEnd: const Color(0xff6d28d9),
          group: _ShopGroup.settings,
          keywords: 'تنظیمات چاپ فاکتور فروشگاه شبا سقف تخفیف',
          builder: (_) => const ShopPrintSettingsPage(),
        ),
      if (perms.canSeeGuide)
        _DeskTool(
          id: 'guide',
          title: 'راهنمای جامع کایر',
          subtitle: 'آموزش گام‌به‌گام بخش‌های فروشگاهی کایر',
          icon: Icons.menu_book_rounded,
          color: const Color(0xff7c3aed),
          gradientEnd: const Color(0xff9333ea),
          group: _ShopGroup.settings,
          keywords: 'راهنما آموزش مستندات',
          builder: (_) => const ShopGuidePage(),
        ),
    ];
  }

  List<_ExpressAction> _buildExpressActions(
    ShopPerms perms,
    List<_DeskTool> allTools,
  ) {
    return <_ExpressAction>[
      if (perms.canManageSection('Sale'))
        _ExpressAction(
          title: 'فاکتور فروش',
          subtitle: 'ثبت فوری + بارکد',
          icon: Icons.add_shopping_cart_rounded,
          color: const Color(0xff059669),
          gradientEnd: const Color(0xff10b981),
          onTap: () => _pushQuickForm(const OrderFormPage(type: TxnType.sale)),
        ),
      if (perms.canManageSection('Sale'))
        _ExpressAction(
          title: 'پیش‌فاکتور',
          subtitle: 'صدور و چاپ سریع',
          icon: Icons.request_page_rounded,
          color: const Color(0xff0284c7),
          gradientEnd: const Color(0xff2563eb),
          onTap: () => _pushQuickForm(
            const OrderFormPage(type: TxnType.sale, isProforma: true),
          ),
        ),
      if (perms.canManageSection('Purchase'))
        _ExpressAction(
          title: 'رسید خرید',
          subtitle: 'ورود به انبار',
          icon: Icons.shopping_bag_rounded,
          color: const Color(0xff2563eb),
          gradientEnd: const Color(0xff4f46e5),
          onTap: () =>
              _pushQuickForm(const OrderFormPage(type: TxnType.purchase)),
        ),
      if (perms.canManageSection('Settlement'))
        _ExpressAction(
          title: 'دریافت وجه/چک',
          subtitle: 'سند دریافت خزانه',
          icon: Icons.south_west_rounded,
          color: const Color(0xff0d9488),
          gradientEnd: const Color(0xff059669),
          onTap: () =>
              _pushQuickForm(const TrsVoucherFormPage(kind: TrsKind.receipt)),
        ),
      if (perms.canManageSection('Settlement'))
        _ExpressAction(
          title: 'پرداخت وجه/چک',
          subtitle: 'سند پرداخت خزانه',
          icon: Icons.north_east_rounded,
          color: const Color(0xffd97706),
          gradientEnd: const Color(0xffea580c),
          onTap: () =>
              _pushQuickForm(const TrsVoucherFormPage(kind: TrsKind.payment)),
        ),
      if (perms.canSeeStock)
        _ExpressAction(
          title: 'موجودی انبار',
          subtitle: 'مشاهده و تعدیل',
          icon: Icons.inventory_rounded,
          color: const Color(0xff4f46e5),
          gradientEnd: const Color(0xff7c3aed),
          onTap: () => _openToolById(allTools, 'stock'),
        ),
      if (perms.canSeeSalesVisit && perms.canCreateVisit)
        _ExpressAction(
          title: 'ثبت ویزیت',
          subtitle: 'سفارش میدانی',
          icon: Icons.add_location_alt_rounded,
          color: const Color(0xffea580c),
          gradientEnd: const Color(0xffdc2626),
          onTap: () => _pushQuickForm(const VisitFormPage()),
        ),
      if (perms.canSeeRepairs)
        _ExpressAction(
          title: 'پذیرش تعمیرات',
          subtitle: 'ثبت دستگاه',
          icon: Icons.handyman_rounded,
          color: const Color(0xff6d28d9),
          gradientEnd: const Color(0xff4338ca),
          onTap: () => _openToolById(allTools, 'repairs'),
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
    final expressActions = _buildExpressActions(perms, allTools);

    final activeIdx = _activeTabId == _homeTabId
        ? 0
        : (_openTabs.indexWhere((t) => t.id == _activeTabId) + 1);
    final safeStackIdx = activeIdx.clamp(0, _openTabs.length);
    final inSubTab = safeStackIdx > 0;

    return PopScope(
      canPop: !inSubTab,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (inSubTab) {
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
            if (inSubTab)
              _buildSubTabTopWorkspaceBar(allTools, expressActions),
            Expanded(
              child: IndexedStack(
                index: safeStackIdx,
                children: [
                  _buildKayerCockpitHub(perms, allTools, expressActions),
                  for (final tab in _openTabs)
                    KeyedSubtree(
                      key: ValueKey('${tab.id}:${tab.reloadVersion}'),
                      child: MediaQuery.removePadding(
                        context: context,
                        removeTop: true,
                        child: Navigator(
                          key: tab.navKey,
                          onGenerateRoute: (_) =>
                              MaterialPageRoute<dynamic>(builder: tab.builder),
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

  // -------------------- نوار میز کار در زمان باز بودن تب‌های داخلی --------------------

  Widget _buildSubTabTopWorkspaceBar(
    List<_DeskTool> allTools,
    List<_ExpressAction> expressActions,
  ) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(10, topPad + 6, 10, 8),
      decoration: const BoxDecoration(
        color: ShopColors.kayerNavy,
        boxShadow: [
          BoxShadow(
            color: Color(0x33071126),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          ShopPressable(
            onTap: () => setState(() => _activeTabId = _homeTabId),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff059669), Color(0xff0284c7)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.dashboard_customize_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'میز کایر',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _openTabs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final t = _openTabs[i];
                  final active = _activeTabId == t.id;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _activeTabId = t.id);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        10,
                        0,
                        6,
                        0,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: active
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            t.icon,
                            size: 14,
                            color: active ? t.color : Colors.white70,
                          ),
                          const SizedBox(width: 5),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Text(
                              t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: active
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                                color: active ? ShopColors.ink : Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _closeTab(t.id),
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Icon(
                                Icons.close_rounded,
                                size: 13.5,
                                color: active
                                    ? ShopColors.inkSoft
                                    : Colors.white60,
                              ),
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
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _openCommandSheet(allTools, expressActions),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 19,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------- میز فرماندهی اصلی «فروشگاهی کایر» --------------------

  Widget _buildKayerCockpitHub(
    ShopPerms perms,
    List<_DeskTool> allTools,
    List<_ExpressAction> expressActions,
  ) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final isSearching = query.isNotEmpty;

    final filtered = isSearching
        ? allTools.where((t) {
            return t.title.toLowerCase().contains(query) ||
                t.subtitle.toLowerCase().contains(query) ||
                t.keywords.toLowerCase().contains(query) ||
                t.group.title.toLowerCase().contains(query);
          }).toList()
        : (_selectedCategory == null
              ? allTools
              : allTools.where((t) => t.group == _selectedCategory).toList());

    final pinnedTools = allTools
        .where((t) => _pinnedIds.contains(t.id))
        .toList();

    return RefreshIndicator(
      color: ShopColors.kayerEmerald,
      onRefresh: _loadLiveStats,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // ۱) سربرگ لوکس فرماندهی کایر + نبض زنده + جستجوی شیشه‌ای
          SliverToBoxAdapter(
            child: _buildHeroHeader(perms, allTools, expressActions),
          ),

          // ۲) نوار تب‌های باز (اگر تبی در پس‌زمینه باز است)
          if (_openTabs.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              sliver: SliverToBoxAdapter(child: _buildOpenTabsDock()),
            ),

          // ۳) میز ثبت فوری اسناد کایر
          if (!isSearching && expressActions.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.only(top: 16),
              sliver: SliverToBoxAdapter(
                child: _buildExpressRail(expressActions),
              ),
            ),

          // ۴) بخش‌های سنجاق‌شدهٔ منتخب کاربر
          if (!isSearching &&
              _selectedCategory == null &&
              pinnedTools.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
              sliver: SliverToBoxAdapter(
                child: _buildPinnedSection(pinnedTools),
              ),
            ),

          // ۵) نوار فیلتر دسته‌بندی‌های کایر
          if (!isSearching && allTools.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.only(top: 18),
              sliver: SliverToBoxAdapter(
                child: _buildCategoryFilterBar(allTools),
              ),
            ),

          // ۶) بدنهٔ بخش‌ها (نتایج جستجو | حالت بنتو ۲ستونی | حالت پوشه‌ای)
          if (allTools.isEmpty)
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(14, 24, 14, 36),
              sliver: SliverToBoxAdapter(
                child: ShopEmpty(
                  icon: Icons.lock_outline_rounded,
                  title: 'بخشی در فروشگاهی کایر برای حساب شما فعال نیست',
                  subtitle:
                      'دسترسی‌های فروشگاهی را از مدیریت نقش‌ها بررسی کنید.',
                ),
              ),
            )
          else if (isSearching)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 36),
              sliver: SliverToBoxAdapter(
                child: filtered.isEmpty
                    ? const ShopEmpty(
                        icon: Icons.search_off_rounded,
                        title: 'بخشی مطابق عبارت جستجو یافت نشد',
                        subtitle:
                            'نام دیگر مثلاً «فاکتور»، «چک»، «کاردکس» یا «انبار» را امتحان کنید.',
                      )
                    : _buildBentoGrid(filtered, showGroupBadge: true),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 36),
              sliver: SliverList.list(
                children: [
                  for (var gi = 0; gi < _ShopGroup.values.length; gi++)
                    if (_selectedCategory == null ||
                        _selectedCategory == _ShopGroup.values[gi])
                      Builder(
                        builder: (_) {
                          final group = _ShopGroup.values[gi];
                          final items = allTools
                              .where((t) => t.group == group)
                              .toList();
                          if (items.isEmpty) return const SizedBox.shrink();
                          return _bentoMode
                              ? _buildBentoGroupSection(group, items)
                              : _buildAccordionGroupFolder(
                                  group: group,
                                  groupIndex: gi,
                                  items: items,
                                );
                        },
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // -------------------- ۱) سربرگ لوکس کایر --------------------

  Widget _buildHeroHeader(
    ShopPerms perms,
    List<_DeskTool> allTools,
    List<_ExpressAction> expressActions,
  ) {
    final top = MediaQuery.of(context).padding.top;
    final canPop = Navigator.of(context).canPop();

    return Container(
      decoration: const BoxDecoration(
        gradient: ShopColors.kayerCockpitGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Color(0x28071126),
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: ShopGridPainter(opacity: 0.05)),
            ),
            Positioned(
              left: -45,
              top: -35,
              child: _glowOrb(170, const Color(0xff10b981), 0.22),
            ),
            Positioned(
              right: -40,
              top: 40,
              child: _glowOrb(150, const Color(0xff38bdf8), 0.18),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, top + 10, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ردیف بالا: بازگشت + برند کایر + دکمه‌های کنترلی
                  Row(
                    children: [
                      if (canPop) ...[
                        _heroIconBtn(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'بازگشت به میز کار',
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xff10b981), Color(0xff0284c7)],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xff10b981,
                              ).withValues(alpha: 0.32),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Colors.white,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Flexible(
                                  child: Text(
                                    'فروشگاهی کایر',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 17.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xff34d399,
                                    ).withValues(alpha: 0.20),
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(
                                      color: const Color(
                                        0xff6ee7b7,
                                      ).withValues(alpha: 0.38),
                                    ),
                                  ),
                                  child: Text(
                                    '${Fa.digits(allTools.length)} بخش فعال',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xffd1fae5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'میز فرماندهی بازرگانی، انبار، خزانه و ویزیت',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.78),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      _heroIconBtn(
                        icon: Icons.manage_search_rounded,
                        tooltip: 'فرمان‌یار کایر',
                        onTap: () =>
                            _openCommandSheet(allTools, expressActions),
                      ),
                      const SizedBox(width: 6),
                      _heroIconBtn(
                        icon: _bentoMode
                            ? Icons.view_agenda_outlined
                            : Icons.grid_view_rounded,
                        tooltip: _bentoMode ? 'نمای پوشه‌ای' : 'نمای کارتی',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _bentoMode = !_bentoMode);
                          _savePrefs();
                        },
                      ),
                      const SizedBox(width: 6),
                      _heroIconBtn(
                        icon: Icons.refresh_rounded,
                        tooltip: 'به‌روزرسانی شاخص‌ها',
                        spinning: _statsLoading,
                        onTap: _loadLiveStats,
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // نوار ۴ شاخص زندهٔ بازرگانی کایر
                  _buildLivePulseStrip(perms, allTools),

                  const SizedBox(height: 12),

                  // کادر جستجوی شیشه‌ای فوری
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchCtrl,
                    builder: (_, val, _) => Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                        cursorColor: Colors.white,
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          hintText:
                              'جستجو در کایر (کالا، فاکتور فروش، چک، کاردکس، انبار…)',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.68),
                            fontSize: 11.5,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 19,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          suffixIcon: val.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 17,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
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

  Widget _buildLivePulseStrip(ShopPerms perms, List<_DeskTool> allTools) {
    final thirdIsCheque =
        perms.canSeeCheques ||
        perms.canSeeInstallments ||
        _stats.overdueCheques > 0;
    final thirdCount = thirdIsCheque
        ? _stats.overdueCheques
        : _stats.openRepairs;
    final thirdLabel = thirdIsCheque ? 'چک سررسید' : 'تعمیرات باز';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _pulseCell(
                label: 'فروش امروز',
                value: _stats.loaded ? compactRial(_stats.todaySales) : '—',
                sub: _stats.todaySaleCount > 0
                    ? '${Fa.digits(_stats.todaySaleCount)} فاکتور'
                    : 'ریال',
                dotColor: const Color(0xff34d399),
                onTap: () => _openToolById(
                  allTools,
                  allTools.any((t) => t.id == 'ops-dashboard')
                      ? 'ops-dashboard'
                      : 'sale',
                ),
              ),
            ),
            _vDivider(),
            Expanded(
              child: _pulseCell(
                label: 'نقدینگی خزانه',
                value: _stats.loaded
                    ? compactRial(_stats.treasuryBalance)
                    : '—',
                sub: 'بانک و صندوق',
                dotColor: const Color(0xff38bdf8),
                onTap: () => _openToolById(
                  allTools,
                  allTools.any((t) => t.id == 'trs-dashboard')
                      ? 'trs-dashboard'
                      : 'banks',
                ),
              ),
            ),
            _vDivider(),
            Expanded(
              child: _pulseCell(
                label: thirdLabel,
                value: _stats.loaded ? Fa.digits(thirdCount) : '—',
                sub: 'مورد فعال',
                dotColor: thirdCount > 0
                    ? const Color(0xfffbbf24)
                    : const Color(0xff94a3b8),
                onTap: () => _openToolById(
                  allTools,
                  thirdIsCheque ? 'credit-mgmt' : 'repairs',
                ),
              ),
            ),
            _vDivider(),
            Expanded(
              child: _pulseCell(
                label: 'کسری انبار',
                value: _stats.loaded ? Fa.digits(_stats.reorderCount) : '—',
                sub: 'زیر نقطه سفارش',
                dotColor: _stats.reorderCount > 0
                    ? const Color(0xfff87171)
                    : const Color(0xff34d399),
                onTap: () => _openToolById(
                  allTools,
                  allTools.any((t) => t.id == 'reorder') ? 'reorder' : 'stock',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pulseCell({
    required String label,
    required String value,
    required String sub,
    required Color dotColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.8,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.86),
              ),
            ),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8.8,
                color: Colors.white.withValues(alpha: 0.58),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vDivider() => Container(
    width: 1,
    margin: const EdgeInsets.symmetric(vertical: 4),
    color: Colors.white.withValues(alpha: 0.12),
  );

  Widget _glowOrb(double size, Color color, double alpha) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    ),
  );

  Widget _heroIconBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool spinning = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: ShopPressable(
        onTap: onTap,
        scale: 0.92,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: spinning
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(icon, size: 19, color: Colors.white),
        ),
      ),
    );
  }

  // -------------------- ۲) داک تب‌های باز روی صفحهٔ اول کایر --------------------

  Widget _buildOpenTabsDock() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ShopColors.kayerEmerald.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: ShopColors.kayerEmerald.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: ShopColors.kayerEmerald,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'تب‌های باز در کایر (${Fa.digits(_openTabs.length)})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _closeAllTabs,
                child: const Text(
                  'بستن همه',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: ShopColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _openTabs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (_, i) {
                final t = _openTabs[i];
                return ShopPressable(
                  onTap: () => setState(() => _activeTabId = t.id),
                  child: Container(
                    padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 6, 0),
                    decoration: BoxDecoration(
                      color: t.color.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: t.color.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.icon, size: 15, color: t.color),
                        const SizedBox(width: 6),
                        Text(
                          t.title,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: t.color,
                          ),
                        ),
                        const SizedBox(width: 5),
                        GestureDetector(
                          onTap: () => _closeTab(t.id),
                          child: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: t.color.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // -------------------- ۳) میز ثبت فوری اسناد --------------------

  Widget _buildExpressRail(List<_ExpressAction> actions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ShopColors.kayerEmerald.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.flash_on_rounded,
                  size: 15,
                  color: ShopColors.kayerEmerald,
                ),
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'میز ثبت فوری اسناد',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'عملیات یک‌ضربه‌ای',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: ShopColors.inkFaint,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 98,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            scrollDirection: Axis.horizontal,
            itemCount: actions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 9),
            itemBuilder: (_, i) {
              final a = actions[i];
              return ShopPressable(
                onTap: a.onTap,
                child: Container(
                  width: 114,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: ShopColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: a.color.withValues(alpha: 0.20)),
                    boxShadow: [
                      BoxShadow(
                        color: a.color.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [a.color, a.gradientEnd],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: [
                            BoxShadow(
                              color: a.color.withValues(alpha: 0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(a.icon, size: 18, color: Colors.white),
                      ),
                      const Spacer(),
                      Text(
                        a.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: ShopColors.ink,
                        ),
                      ),
                      Text(
                        a.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // -------------------- ۴) بخش‌های سنجاق‌شدهٔ منتخب --------------------

  Widget _buildPinnedSection(List<_DeskTool> pinnedTools) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ShopColors.kayerGold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.push_pin_rounded,
                size: 14,
                color: ShopColors.kayerGold,
              ),
            ),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'دسترسی سریع منتخب من',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.ink,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${Fa.digits(pinnedTools.length)} سنجاق‌شده',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: ShopColors.inkFaint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildBentoGrid(pinnedTools, compact: true),
      ],
    );
  }

  // -------------------- ۵) نوار فیلتر دسته‌بندی‌ها --------------------

  Widget _buildCategoryFilterBar(List<_DeskTool> allTools) {
    final availableGroups = _ShopGroup.values
        .where((g) => allTools.any((t) => t.group == g))
        .toList();

    return SizedBox(
      height: 38,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        children: [
          _categoryChip(
            label: 'همهٔ بخش‌ها',
            count: allTools.length,
            icon: Icons.apps_rounded,
            color: ShopColors.seed,
            selected: _selectedCategory == null,
            onTap: () => setState(() => _selectedCategory = null),
          ),
          for (final g in availableGroups) ...[
            const SizedBox(width: 7),
            _categoryChip(
              label: g.shortTitle,
              count: allTools.where((t) => t.group == g).length,
              icon: g.icon,
              color: g.color,
              selected: _selectedCategory == g,
              onTap: () => setState(
                () => _selectedCategory = _selectedCategory == g ? null : g,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _categoryChip({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [color, color.withValues(alpha: 0.82)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                )
              : null,
          color: selected ? null : ShopColors.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? color : ShopColors.line,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.24),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14.5, color: selected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : ShopColors.ink,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.22)
                    : color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                Fa.digits(count),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- ۶) نمای بنتو کارتی مدرن (۲ ستونی) --------------------

  Widget _buildBentoGroupSection(_ShopGroup group, List<_DeskTool> items) {
    final openInGroup = items
        .where((it) => _openTabs.any((t) => t.id == it.id))
        .length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // سرفصل لوکس گروه
          Padding(
            padding: const EdgeInsets.only(bottom: 10, right: 2, left: 2),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: group.gradient,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: group.color.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(group.icon, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              group.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.8,
                                fontWeight: FontWeight.w900,
                                color: ShopColors.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ShopTag(
                            text: '${Fa.digits(items.length)} بخش',
                            color: group.color,
                          ),
                          if (openInGroup > 0) ...[
                            const SizedBox(width: 5),
                            ShopTag(
                              text: '${Fa.digits(openInGroup)} باز',
                              color: ShopColors.kayerEmerald,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
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
              ],
            ),
          ),
          _buildBentoGrid(items),
        ],
      ),
    );
  }

  Widget _buildBentoGrid(
    List<_DeskTool> items, {
    bool showGroupBadge = false,
    bool compact = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 640 ? 3 : 2;
        const gap = 10.0;
        final cardWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tool in items)
              SizedBox(
                width: cardWidth,
                child: _buildBentoCard(
                  tool,
                  showGroupBadge: showGroupBadge,
                  compact: compact,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBentoCard(
    _DeskTool tool, {
    bool showGroupBadge = false,
    bool compact = false,
  }) {
    final isOpen = _openTabs.any((t) => t.id == tool.id);
    final isPinned = _pinnedIds.contains(tool.id);

    return ShopPressable(
      onTap: () => _openToolInTab(tool),
      onLongPress: () => _togglePin(tool.id),
      child: Container(
        height: compact ? 104 : 122,
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isOpen
                ? ShopColors.kayerEmerald.withValues(alpha: 0.48)
                : (isPinned
                      ? tool.color.withValues(alpha: 0.28)
                      : ShopColors.line),
            width: isOpen ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: tool.color.withValues(alpha: isOpen ? 0.10 : 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 3,
              decoration: BoxDecoration(gradient: tool.iconGradient),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  11,
                  compact ? 8 : 10,
                  11,
                  compact ? 8 : 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: compact ? 34 : 38,
                          height: compact ? 34 : 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: tool.iconGradient,
                            borderRadius: BorderRadius.circular(
                              compact ? 10 : 12,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: tool.color.withValues(alpha: 0.26),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            tool.icon,
                            size: compact ? 17.5 : 19.5,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.topEnd,
                            child: isOpen
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6.5,
                                      vertical: 2.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ShopColors.kayerEmerald,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: const Text(
                                      'تب باز',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 8.8,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : (showGroupBadge
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: tool.group.color.withValues(
                                              alpha: 0.10,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              99,
                                            ),
                                          ),
                                          child: Text(
                                            tool.group.shortTitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 8.8,
                                              fontWeight: FontWeight.w800,
                                              color: tool.group.color,
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink()),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _togglePin(tool.id),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              isPinned
                                  ? Icons.push_pin_rounded
                                  : Icons.push_pin_outlined,
                              size: 14.5,
                              color: isPinned
                                  ? tool.color
                                  : ShopColors.inkFaint.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      tool.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.2,
                        fontWeight: FontWeight.w900,
                        color: ShopColors.ink,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 2),
                      Text(
                        tool.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9.8,
                          height: 1.35,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- ۷) نمای پوشه‌ای مدرن (در صورت انتخاب کاربر) --------------------

  Widget _buildAccordionGroupFolder({
    required _ShopGroup group,
    required int groupIndex,
    required List<_DeskTool> items,
  }) {
    final expanded = _expandedGroups.contains(groupIndex);
    final openInGroup = items
        .where((it) => _openTabs.any((t) => t.id == it.id))
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: expanded
              ? group.color.withValues(alpha: 0.42)
              : ShopColors.line,
          width: expanded ? 1.3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: group.color.withValues(alpha: expanded ? 0.08 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(20),
              bottom: Radius.circular(expanded ? 0 : 20),
            ),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (expanded) {
                  _expandedGroups.remove(groupIndex);
                } else {
                  _expandedGroups.add(groupIndex);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: group.gradient,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(group.icon, size: 21, color: Colors.white),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                group.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  color: ShopColors.ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            ShopTag(
                              text: '${Fa.digits(items.length)} بخش',
                              color: group.color,
                            ),
                            if (openInGroup > 0) ...[
                              const SizedBox(width: 5),
                              ShopTag(
                                text: '${Fa.digits(openInGroup)} باز',
                                color: ShopColors.kayerEmerald,
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
                const Divider(height: 1, indent: 56, color: ShopColors.line),
              _buildFolderRow(items[i]),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildFolderRow(_DeskTool tool) {
    final isOpen = _openTabs.any((t) => t.id == tool.id);
    final isPinned = _pinnedIds.contains(tool.id);

    return InkWell(
      onTap: () => _openToolInTab(tool),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10.5),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: tool.iconGradient,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(tool.icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tool.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: ShopColors.ink,
                    ),
                  ),
                  const SizedBox(height: 1.5),
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
              const Padding(
                padding: EdgeInsetsDirectional.only(end: 6),
                child: ShopTag(text: 'تب باز', color: ShopColors.kayerEmerald),
              ),
            GestureDetector(
              onTap: () => _togglePin(tool.id),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  size: 16,
                  color: isPinned ? tool.color : ShopColors.inkFaint,
                ),
              ),
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

// ============================================================
//  شیت فرمان‌یار و جستجوی سریع «فروشگاهی کایر»
// ============================================================

class _KayerCommandSheet extends StatefulWidget {
  const _KayerCommandSheet({
    required this.tools,
    required this.expressActions,
    required this.onSelectTool,
  });

  final List<_DeskTool> tools;
  final List<_ExpressAction> expressActions;
  final ValueChanged<_DeskTool> onSelectTool;

  @override
  State<_KayerCommandSheet> createState() => _KayerCommandSheetState();
}

class _KayerCommandSheetState extends State<_KayerCommandSheet> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _q.trim().toLowerCase();
    final matchedTools = query.isEmpty
        ? widget.tools
        : widget.tools.where((t) {
            return t.title.toLowerCase().contains(query) ||
                t.subtitle.toLowerCase().contains(query) ||
                t.keywords.toLowerCase().contains(query) ||
                t.group.title.toLowerCase().contains(query);
          }).toList();

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          decoration: const BoxDecoration(
            color: ShopColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: ShopColors.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: ShopColors.bg,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: ShopColors.seed.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.manage_search_rounded,
                        color: ShopColors.seed,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          autofocus: true,
                          onChanged: (v) => setState(() => _q = v),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText:
                                'پرش سریع به فرم یا گزارش کایر (مثلاً کاردکس، چک، فاکتور…)',
                            hintStyle: TextStyle(
                              fontSize: 11.5,
                              color: ShopColors.inkFaint,
                            ),
                          ),
                        ),
                      ),
                      if (_q.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _ctrl.clear();
                            setState(() => _q = '');
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: ShopColors.line),
              Flexible(
                child: matchedTools.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'موردی یافت نشد.',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: ShopColors.inkSoft,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                        itemCount: matchedTools.length,
                        itemBuilder: (_, i) {
                          final t = matchedTools[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Material(
                              color: ShopColors.surfaceSoft,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: ShopColors.line),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                dense: true,
                                onTap: () {
                                  Navigator.of(context).pop();
                                  widget.onSelectTool(t);
                                },
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    gradient: t.iconGradient,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    t.icon,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                title: Text(
                                  t.title,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: ShopColors.ink,
                                  ),
                                ),
                                subtitle: Text(
                                  '${t.group.shortTitle} • ${t.subtitle}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: ShopColors.inkFaint,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_left_rounded,
                                  size: 18,
                                  color: ShopColors.inkFaint,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
