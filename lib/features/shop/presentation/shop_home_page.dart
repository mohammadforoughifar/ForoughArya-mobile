// ============================================================
//  ماژول «فروشگاهی کایر» در موبایل
//  ساختار منو، نام‌گذاری و گیت‌های دسترسی دقیقاً آینهٔ
//  `Layout/NavMenu.razor`، `ShopAccess.cs` و `ShopSections.cs` در وب است.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/shop_perms.dart';
import '../models/order_models.dart';
import 'categories_page.dart';
import 'expenses_page.dart';
import 'goods_issues_page.dart';
import 'kardex_page.dart';
import 'opening_balance_page.dart';
import 'ops_dashboard_page.dart';
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
import 'shop_pricing_page.dart';
import 'shop_print_settings_page.dart';
import 'shop_style.dart';
import 'stock_page.dart';
import 'trs_accounts_page.dart';
import 'trs_cheques_page.dart';
import 'trs_vouchers_page.dart';
import 'units_page.dart';
import 'vis_approvals_page.dart';
import 'vis_finance_queue_page.dart';
import 'vis_requests_page.dart';
import 'visit_form_page.dart';
import 'visits_page.dart';
import 'warehouses_page.dart';

class ShopHomePage extends StatelessWidget {
  const ShopHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    final perms = ShopPerms(auth.session);
    final isRef = isReferrerSession(auth);

    // ---- گیت‌های منو، عیناً مثل NavMenu.razor ----
    final showParties = perms.anyPartyAccess;
    final partiesLabel = perms.partiesMenuLabel;
    final partiesSubtitle = perms.canSeeCustomers && perms.canSeeSuppliers
        ? 'مشتریان و تأمین‌کنندگان'
        : (perms.canSeeCustomers
              ? 'خریداران حقیقی و حقوقی'
              : 'فروشندگان کالا و خدمات');

    final reportItems = <_Item>[
      if (perms.canSeePartyStatements)
        _Item(
          'گزارش طلب و بدهی اشخاص',
          'گردش حساب، مانده افتتاحیه و ریز صورت‌حساب',
          Icons.account_balance_wallet_rounded,
          onTap: () => _push(context, const PartyStatementsPage()),
        ),
      if (perms.canSeeOrderReports) ...[
        _Item(
          'گزارش خرید',
          'تحلیل روند، رتبه‌بندی تأمین‌کنندگان و مقادیر',
          Icons.shopping_bag_rounded,
          onTap: () =>
              _push(context, const OrderReportPage(type: TxnType.purchase)),
        ),
        _Item(
          'گزارش فروش',
          'تحلیل روند، رتبه‌بندی مشتریان و مقادیر',
          Icons.shopping_cart_rounded,
          onTap: () =>
              _push(context, const OrderReportPage(type: TxnType.sale)),
        ),
      ],
      if (perms.canSeeKardex) ...[
        _Item(
          'کاردکس تعداد کالاها',
          'رهگیری خط‌به‌خط وارده/صادره و مانده فیزیکی کالا',
          Icons.list_alt_rounded,
          onTap: () => _push(context, const KardexPage()),
        ),
        _Item(
          'کاردکس ریالی کالاها',
          'فی تمام‌شده، ارزش دفتری و میانگین بهای مانده',
          Icons.currency_exchange_rounded,
          onTap: () => _push(context, const KardexPage(rial: true)),
        ),
      ],
    ];

    final catalogItems = <_Item>[
      if (showParties)
        _Item(
          partiesLabel,
          partiesSubtitle,
          Icons.people_alt_rounded,
          onTap: () => _push(context, const PartiesPage()),
        ),
      if (perms.canSeeProducts)
        _Item(
          'کالاها',
          'تعریف کالا و خدمات، ارزش افزوده، ورود اکسل و نقطه سفارش',
          Icons.inventory_2_rounded,
          onTap: () => _push(context, const ProductsPage()),
        ),
      if (perms.canSeeCategories)
        _Item(
          'گروه‌های کالا',
          'تعریف و مدیریت دسته‌بندی کالاها',
          Icons.sell_rounded,
          onTap: () => _push(context, const ProductCategoriesPage()),
        ),
      if (perms.canSeeUnits)
        _Item(
          'واحدهای شمارش',
          'تعریف واحدهای اندازه‌گیری کالا',
          Icons.straighten_rounded,
          onTap: () => _push(context, const UnitsPage()),
        ),
      if (perms.canSeeWarehouses)
        _Item(
          'انبارها',
          'تعریف انبارها و مراکز نگهداری کالا',
          Icons.warehouse_rounded,
          onTap: () => _push(context, const WarehousesPage()),
        ),
      if (perms.canSeeStock)
        _Item(
          'موجودی انبار',
          'موجودی لحظه‌ای و تعدیل انبارگردانی',
          Icons.inventory_rounded,
          onTap: () => _push(context, const StockPage()),
        ),
      if (perms.canSeePrintSettings)
        _Item(
          'تنظیمات فروشگاه',
          'سقف تخفیف ویزیتورها و کارت‌ها/شباهای فروشنده در چاپ فاکتور',
          Icons.print_rounded,
          onTap: () => _push(context, const ShopPrintSettingsPage()),
        ),
      if (perms.canSeePricing)
        _Item(
          'قیمت‌گذاری و حداقل سود',
          'کنترل حداقل سود فروش، اصلاح گروهی قیمت و سابقه تغییرات',
          Icons.price_change_rounded,
          onTap: () => _push(context, const ShopPricingPage()),
        ),
      if (perms.canSeeBanks)
        _Item(
          'بانک، صندوق و کارتخوان (POS)',
          'حساب‌های خزانه با مانده جاری، شماره شبا و مالک شرکت',
          Icons.account_balance_rounded,
          onTap: () => _push(context, const TrsAccountsPage()),
        ),
      if (perms.canSeeReferrers)
        _Item(
          'معرف‌ها',
          'بازاریاب‌ها و درصد پورسانت فروش کالا و خدمات',
          Icons.badge_rounded,
          onTap: () => _push(context, const ReferrersPage()),
        ),
      if (perms.canSeeReferrerWallets)
        _Item(
          'کیف پول معرف‌ها',
          'مانده پورسانت، پرداخت‌ها و اسناد پرداخت هر معرف',
          Icons.account_balance_wallet_rounded,
          onTap: () => _push(context, const ReferrerWalletsPage()),
        ),
    ];

    final opsItems = <_Item>[
      if (perms.canSeePurchase)
        _Item(
          'خرید',
          'رسید خرید، ارزش افزوده، بروزرسانی فی فروش و چاپ رسید',
          Icons.shopping_bag_rounded,
          onTap: () =>
              _push(context, const SaleOrdersPage(type: TxnType.purchase)),
        ),
      if (perms.canSeeSale)
        _Item(
          'فروش',
          'فاکتور و پیش‌فاکتور فروش، چاپ، نسیه و برگشت چکی',
          Icons.shopping_cart_rounded,
          onTap: () => _push(context, const SaleOrdersPage(type: TxnType.sale)),
        ),
      if (perms.canSeeGoodsIssue)
        _Item(
          'بیجک',
          'حوالهٔ خروج کالا — فقط مقدار، بدون قیمت',
          Icons.local_shipping_rounded,
          onTap: () => _push(context, const GoodsIssuesPage()),
        ),
      if (perms.canSeeRepairs)
        _Item(
          'تعمیرات',
          'پذیرش، کارها و قطعات، تبدیل به فروش',
          Icons.build_rounded,
          onTap: () => _push(context, const RepairsPage()),
        ),
      if (perms.canSeeExpenses)
        _Item(
          'هزینه‌ها',
          'ثبت اسناد هزینه و انواع هزینه',
          Icons.payments_rounded,
          onTap: () => _push(context, const ExpensesPage()),
        ),
      if (perms.canSeeInstallments)
        _Item(
          'مدیریت اقساط و چک‌ها',
          'وصول چک، برگشت چک و تسویه اقساط',
          Icons.event_note_rounded,
          onTap: () => _push(context, const ShopCreditPage()),
        ),
      if (perms.canSeeOpeningBalance)
        _Item(
          'افتتاح حساب و مانده‌های اولیه',
          'طلب/بدهی اولیه، چک‌های اول دوره، اقساط و موجودی',
          Icons.savings_rounded,
          onTap: () => _push(context, const OpeningBalancePage()),
        ),
      if (perms.canSeeCheques)
        _Item(
          'چک‌های خزانه',
          'صدور، واگذاری، وصول و برگشت چک',
          Icons.credit_card_rounded,
          onTap: () => _push(context, const TrsChequesPage()),
        ),
      if (perms.canSeeSettlement)
        _Item(
          'تسویه فاکتورها',
          'اسناد دریافت، پرداخت و انتقال بین حساب‌ها',
          Icons.swap_horiz_rounded,
          onTap: () => _push(context, const TrsVouchersPage()),
        ),
    ];

    final visitItems = <_Item>[
      _Item(
        'سفارش‌های من',
        'سفارش‌های ثبت‌شدهٔ ویزیتور',
        Icons.assignment_rounded,
        onTap: () => _push(context, const VisitsPage()),
      ),
      if (perms.canCreateVisit)
        _Item(
          'ثبت سفارش جدید',
          'ثبت سفارش میدانی',
          Icons.add_box_rounded,
          onTap: () => _push(context, const VisitFormPage()),
        ),
      // وب: «تأیید سفارش‌ها» و «همهٔ درخواست‌ها» نیازمند نقش SalesManager + مجوز SalesVisit.Approve
      if (perms.canApproveVisits) ...[
        _Item(
          'تأیید سفارش‌ها',
          'بررسی و تأیید مدیر فروش',
          Icons.verified_rounded,
          onTap: () => _push(context, const VisApprovalsPage()),
        ),
        _Item(
          'همهٔ درخواست‌ها',
          'فهرست کامل درخواست‌ها',
          Icons.collections_rounded,
          onTap: () => _push(context, const VisRequestsPage()),
        ),
      ],
      if (perms.canFinanceVisit)
        _Item(
          'صف مالی سفارش‌ها',
          'تأیید شیوه تسویه و ثبت فروش فروشگاه',
          Icons.receipt_rounded,
          onTap: () => _push(context, const VisFinanceQueuePage()),
        ),
    ];

    final hasAnySection =
        reportItems.isNotEmpty ||
        perms.canSeeDashboard ||
        catalogItems.isNotEmpty ||
        opsItems.isNotEmpty ||
        perms.canSeeSalesVisit ||
        isRef ||
        perms.canSeeGuide;

    return Scaffold(
      backgroundColor: ShopColors.bg,
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: ShopHeader(
              title: 'فروشگاهی کایر',
              subtitle:
                  'عملیات خرید و فروش، اطلاعات پایه، قیمت‌گذاری، گزارش‌ها و ویزیتوری',
              icon: Icons.point_of_sale_rounded,
            ),
          ),
          if (!hasAnySection)
            const SliverPadding(
              padding: EdgeInsets.all(14),
              sliver: SliverToBoxAdapter(
                child: ShopEmpty(
                  icon: Icons.lock_outline_rounded,
                  title: 'دسترسی به بخش‌های فروشگاهی ندارید',
                  subtitle:
                      'هیچ‌یک از بخش‌های «فروشگاهی کایر» برای نقش شما فعال نشده است.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
              sliver: SliverList.list(
                children: [
                  if (reportItems.isNotEmpty)
                    _group(context, 'گزارش‌ها', Icons.insights_rounded, reportItems),
                  if (perms.canSeeDashboard)
                    _group(context, 'داشبورد', Icons.speed_rounded, [
                      _Item(
                        'داشبورد عملیاتی (خرید، فروش و تعمیرات)',
                        'تحلیل زنده خرید، فروش، خدمات تعمیراتی، سودآوری و معرف‌ها',
                        Icons.bar_chart_rounded,
                        onTap: () => _push(context, const OpsDashboardPage()),
                      ),
                    ]),
                  if (catalogItems.isNotEmpty)
                    _group(
                      context,
                      'اطلاعات پایه',
                      Icons.dataset_rounded,
                      catalogItems,
                    ),
                  if (opsItems.isNotEmpty)
                    _group(
                      context,
                      'عملیات',
                      Icons.receipt_long_rounded,
                      opsItems,
                    ),
                  if (perms.canSeeSalesVisit)
                    _group(
                      context,
                      'فروش و ویزیتوری',
                      Icons.directions_walk_rounded,
                      visitItems,
                    ),
                  if (isRef)
                    _group(context, 'پنل معرف', Icons.badge_rounded, [
                      _Item(
                        'کیف پول من',
                        'مانده پورسانت و اسناد دریافت',
                        Icons.account_balance_wallet_rounded,
                        onTap: () => _push(context, const MyWalletPage()),
                      ),
                      _Item(
                        'کالاهای موجود',
                        'فهرست کالاهای دارای موجودی — قیمت فروش روز',
                        Icons.inventory_2_rounded,
                        onTap: () => _push(context, const MyProductsPage()),
                      ),
                      _Item(
                        'کارت ویزیت من',
                        'پیش‌نمایش کارت معرف',
                        Icons.contact_page_rounded,
                        onTap: () => _push(context, const MyCardPage()),
                      ),
                    ]),
                  if (perms.canSeeGuide)
                    _group(context, 'راهنما', Icons.help_outline_rounded, [
                      _Item(
                        'راهنمای سامانه',
                        'آموزش گام‌به‌گام فروشگاهی کایر',
                        Icons.menu_book_rounded,
                        onTap: () => _push(context, const ShopGuidePage()),
                      ),
                    ]),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Widget _group(
    BuildContext context,
    String title,
    IconData icon,
    List<_Item> items,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
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
                Icon(icon, size: 15, color: ShopColors.seed),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final it in items) _row(it),
          ],
        ),
      ),
    );
  }

  Widget _row(_Item it) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: it.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ShopColors.seed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(it.icon, size: 17, color: ShopColors.seed),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    it.title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: ShopColors.ink,
                    ),
                  ),
                  Text(
                    it.subtitle,
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

class _Item {
  const _Item(
    this.title,
    this.subtitle,
    this.icon, {
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}
