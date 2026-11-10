// ============================================================
//  اسکلت ماژول «سامانه فروشگاهی» در موبایل
//  ساختار منو دقیقاً از Layout/NavMenu.razor وب گرفته شده است.
//
//  فاز ۱ (اکنون): «اطلاعات پایه ← طرف حساب‌ها» + «گزارش ← طلب و بدهی اشخاص».
//  بقیهٔ آیتم‌های منو همان‌جا فهرست می‌شوند و با آمدن هر فاز وصل می‌شوند؛
//  تا آن روز به‌جای کلیک بی‌اثر، پیام «در فاز بعدی» نشان داده می‌شود.
//  هیچ آیتمی خارج از منوی وب ساخته نشده است.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/shop_perms.dart';
import '../models/order_models.dart';
import 'categories_page.dart';
import 'opening_balance_page.dart';
import 'expenses_page.dart';
import 'goods_issues_page.dart';
import 'parties_page.dart';
import 'party_statements_page.dart';
import 'order_report_page.dart';
import 'products_page.dart';
import 'shop_credit_page.dart';
import 'repairs_page.dart';
import 'trs_accounts_page.dart';
import 'trs_cheques_page.dart';
import 'trs_vouchers_page.dart';
import 'sale_orders_page.dart';
import 'shop_style.dart';
import 'stock_page.dart';
import 'units_page.dart';
import 'warehouses_page.dart';

class ShopHomePage extends StatelessWidget {
  const ShopHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final perms = ShopPerms(context.read<AuthController>().session);

    // ---- گیت‌های منو، عیناً مثل NavMenu.razor ----
    final showParties = perms.canSeeCustomers || perms.canSeeSuppliers;
    final partiesLabel = perms.canSeeSuppliers && !perms.canSeeCustomers
        ? 'تأمین‌کنندگان'
        : perms.canSeeCustomers && !perms.canSeeSuppliers
        ? 'مشتریان'
        : 'طرف حساب‌ها';

    return Scaffold(
      backgroundColor: ShopColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ShopHeader(
              title: 'سامانه فروشگاهی',
              subtitle: 'عملیات خرید و فروش، اطلاعات پایه، گزارش‌ها و ویزیتوری',
              icon: Icons.point_of_sale_rounded,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
            sliver: SliverList.list(
              children: [
                // ---------- گزارش‌ها (اکنون) ----------
                _group(
                  context,
                  'گزارش‌ها',
                  Icons.insights_rounded,
                  [
                    _Item(
                      'گزارش طلب و بدهی اشخاص',
                      'گردش حساب، مانده افتتاحیه و ریز صورت‌حساب',
                      Icons.account_balance_wallet_rounded,
                      enabled: true,
                      onTap: () => _push(context, const PartyStatementsPage()),
                    ),
                    // مثل وب: گزارش خرید/فروش زیر گیت CanSee("Orders")
                    if (perms.canSeeModule('Orders')) ...[
                      _Item(
                        'گزارش خرید',
                        'تحلیل روند، رتبه‌بندی تأمین‌کنندگان و مقادیر',
                        Icons.shopping_bag_rounded,
                        enabled: true,
                        onTap: () => _push(
                          context,
                          const OrderReportPage(type: TxnType.purchase),
                        ),
                      ),
                      _Item(
                        'گزارش فروش',
                        'تحلیل روند، رتبه‌بندی مشتریان و مقادیر',
                        Icons.shopping_cart_rounded,
                        enabled: true,
                        onTap: () => _push(
                          context,
                          const OrderReportPage(type: TxnType.sale),
                        ),
                      ),
                    ],
                  ],
                ),
                // ---------- اطلاعات پایه ----------
                _group(
                  context,
                  'اطلاعات پایه',
                  Icons.dataset_rounded,
                  [
                    if (showParties)
                      _Item(
                        partiesLabel,
                        perms.canSeeCustomers && perms.canSeeSuppliers
                            ? 'مشتریان و تأمین‌کنندگان'
                            : (perms.canSeeCustomers
                                  ? 'خریداران حقیقی و حقوقی'
                                  : 'فروشندگان کالا و خدمات'),
                        Icons.people_alt_rounded,
                        enabled: true,
                        onTap: () => _push(context, const PartiesPage()),
                      ),
                    _Item(
                      'کالاها',
                      'تعریف کالا، قیمت و نقطه سفارش',
                      Icons.inventory_2_rounded,
                      enabled: true,
                      onTap: () => _push(context, const ProductsPage()),
                    ),
                    _Item(
                      'گروه‌های کالا',
                      'تعریف و مدیریت دسته‌بندی کالاها',
                      Icons.sell_rounded,
                      enabled: true,
                      onTap: () => _push(context, const ProductCategoriesPage()),
                    ),
                    _Item(
                      'واحدهای شمارش',
                      'تعریف واحدهای اندازه‌گیری کالا',
                      Icons.straighten_rounded,
                      enabled: true,
                      onTap: () => _push(context, const UnitsPage()),
                    ),
                    _Item(
                      'انبارها',
                      'تعریف انبارها و مراکز نگهداری کالا',
                      Icons.warehouse_rounded,
                      enabled: true,
                      onTap: () => _push(context, const WarehousesPage()),
                    ),
                    // مثل وب: «موجودی انبار» زیرمجموعهٔ اطلاعات پایه است
                    if (perms.canSeeModule('Stock'))
                      _Item(
                        'موجودی انبار',
                        'موجودی لحظه‌ای و تعدیل انبارگردانی',
                        Icons.inventory_rounded,
                        enabled: true,
                        onTap: () => _push(context, const StockPage()),
                      ),
                    // وب: «بانک، صندوق و کارتخوان (POS)» در اطلاعات پایه
                    if (perms.canSeeModule('TrsAccounts'))
                      _Item(
                        'بانک، صندوق و کارتخوان (POS)',
                        'حساب‌های خزانه با مانده جاری و گردش',
                        Icons.account_balance_rounded,
                        enabled: true,
                        onTap: () => _push(context, const TrsAccountsPage()),
                      ),
                    const _Item(
                      'معرف‌ها',
                      'بازاریابان و پروندهٔ فروش',
                      Icons.badge_rounded,
                      phase: 6,
                    ),
                    const _Item(
                      'بانک، صندوق و کارتخوان (POS)',
                      'حساب‌های خزانه',
                      Icons.account_balance_rounded,
                      phase: 5,
                    ),
                  ],
                ),
                // ---------- عملیات ----------
                _group(
                  context,
                  'عملیات',
                  Icons.receipt_long_rounded,
                  [
                    // مثل وب: هر دو زیر گیت `CanSee("Orders")`
                    if (perms.canSeeModule('Orders')) ...[
                      _Item(
                        'خرید',
                        'سفارش/فاکتور خرید',
                        Icons.shopping_bag_rounded,
                        enabled: true,
                        onTap: () => _push(
                          context,
                          const SaleOrdersPage(type: TxnType.purchase),
                        ),
                      ),
                      _Item(
                        'فروش',
                        'سفارش/فاکتور فروش',
                        Icons.shopping_cart_rounded,
                        enabled: true,
                        onTap: () => _push(
                          context,
                          const SaleOrdersPage(type: TxnType.sale),
                        ),
                      ),
                    ],
                    if (!perms.canSeeModule('Orders'))
                      const _Item(
                        'خرید و فروش',
                        'سفارش/فاکتور خرید و فروش',
                        Icons.receipt_long_rounded,
                        phase: 3,
                      ),
                    // وب: هر سه زیر گیت مستقل خودشان هستند
                    if (perms.canSeeModule('GoodsIssues'))
                      _Item(
                        'بیجک',
                        'حوالهٔ خروج کالا — فقط مقدار، بدون قیمت',
                        Icons.local_shipping_rounded,
                        enabled: true,
                        onTap: () => _push(context, const GoodsIssuesPage()),
                      )
                    else
                      const _Item(
                        'بیجک',
                        'حوالهٔ خروج کالا',
                        Icons.local_shipping_rounded,
                        phase: 4,
                      ),
                    if (perms.canSeeModule('Repairs'))
                      _Item(
                        'تعمیرات',
                        'پذیرش، کارها و قطعات، تبدیل به فروش',
                        Icons.build_rounded,
                        enabled: true,
                        onTap: () => _push(context, const RepairsPage()),
                      )
                    else
                      const _Item(
                        'تعمیرات',
                        'سفارش‌های تعمیرات',
                        Icons.build_rounded,
                        phase: 4,
                      ),
                    if (perms.canSeeModule('Expenses'))
                      _Item(
                        'هزینه‌ها',
                        'ثبت اسناد هزینه و انواع هزینه',
                        Icons.payments_rounded,
                        enabled: true,
                        onTap: () => _push(context, const ExpensesPage()),
                      )
                    else
                      const _Item(
                        'هزینه‌ها',
                        'ثبت هزینه‌ها',
                        Icons.payments_rounded,
                        phase: 4,
                      ),
                    if (perms.canSeeModule('Orders') ||
                        perms.canSeeModule('TrsVouchers'))
                      _Item(
                        'مدیریت اقساط و چک‌ها',
                        'وصول چک، برگشت چک و تسویه اقساط',
                        Icons.event_note_rounded,
                        enabled: true,
                        onTap: () => _push(context, const ShopCreditPage()),
                      )
                    else
                      const _Item(
                        'مدیریت اقساط و چک‌ها',
                        'اقساط و چک‌های دریافتی/پرداختی',
                        Icons.event_note_rounded,
                        phase: 5,
                      ),
                    if (perms.canSeeModule('Orders') ||
                        perms.canSeeModule('TrsVouchers'))
                      _Item(
                        'افتتاح حساب و مانده‌های اولیه',
                        'طلب/بدهی اولیه، چک‌های اول دوره، اقساط و موجودی',
                        Icons.savings_rounded,
                        enabled: true,
                        onTap: () => _push(context, const OpeningBalancePage()),
                      )
                    else
                      const _Item(
                        'افتتاح حساب و مانده‌های اولیه',
                        'مانده اول دورهٔ اشخاص',
                        Icons.savings_rounded,
                        phase: 5,
                      ),
                    if (perms.canSeeModule('TrsCheques'))
                      _Item(
                        'چک‌های خزانه',
                        'صدور، واگذاری، وصول و برگشت چک',
                        Icons.credit_card_rounded,
                        enabled: true,
                        onTap: () => _push(context, const TrsChequesPage()),
                      ),
                    if (perms.canSeeModule('TrsVouchers'))
                      _Item(
                        'تسویه فاکتورها',
                        'اسناد دریافت، پرداخت و انتقال بین حساب‌ها',
                        Icons.swap_horiz_rounded,
                        enabled: true,
                        onTap: () => _push(context, const TrsVouchersPage()),
                      )
                    else
                      const _Item(
                        'تسویه فاکتورها',
                        'دریافت/پرداخت و تسویه',
                        Icons.swap_horiz_rounded,
                        phase: 5,
                      ),
                  ],
                ),
                // ---------- ویزیت فروش ----------
                _group(
                  context,
                  'فروش و ویزیتوری',
                  Icons.directions_walk_rounded,
                  const [
                    _Item(
                      'سفارش‌های من',
                      'سفارش‌های ثبت‌شدهٔ ویزیتور',
                      Icons.assignment_rounded,
                      phase: 6,
                    ),
                    _Item(
                      'ثبت سفارش جدید',
                      'ثبت سفارش میدانی',
                      Icons.add_box_rounded,
                      phase: 6,
                    ),
                    _Item(
                      'تأیید سفارش‌ها',
                      'بررسی و تأیید مدیر فروش',
                      Icons.verified_rounded,
                      phase: 6,
                    ),
                    _Item(
                      'همهٔ درخواست‌ها',
                      'فهرست کامل درخواست‌ها',
                      Icons.collections_rounded,
                      phase: 6,
                    ),
                    _Item(
                      'صف مالی سفارش‌ها',
                      'تأیید مالی سفارش‌ها',
                      Icons.receipt_rounded,
                      phase: 6,
                    ),
                  ],
                ),
                // ---------- راهنما ----------
                _group(
                  context,
                  'راهنما',
                  Icons.help_outline_rounded,
                  const [
                    _Item(
                      'راهنمای سامانه',
                      'آموزش گام‌به‌گام سامانه فروشگاهی',
                      Icons.menu_book_rounded,
                      phase: 6,
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

  void _push(BuildContext context, Widget page) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
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
            for (final it in items) _row(context, it),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, _Item it) {
    final on = it.enabled;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: on
          ? it.onTap
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '«${it.title}» در فاز ${_faDigits(it.phase)} همین ماژول اضافه می‌شود.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (on ? ShopColors.seed : ShopColors.inkFaint).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                it.icon,
                size: 17,
                color: on ? ShopColors.seed : ShopColors.inkFaint,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    it.title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: on ? ShopColors.ink : ShopColors.inkSoft,
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
            if (on)
              const Icon(
                Icons.chevron_left_rounded,
                size: 18,
                color: ShopColors.inkFaint,
              )
            else
              ShopTag(text: 'فاز ${_faDigits(it.phase)}', color: ShopColors.warn),
          ],
        ),
      ),
    );
  }

  static String _faDigits(int? n) {
    const en = '0123456789';
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    return (n ?? 0).toString().split('').map((c) {
      final i = en.indexOf(c);
      return i < 0 ? c : fa[i];
    }).join();
  }
}

class _Item {
  const _Item(
    this.title,
    this.subtitle,
    this.icon, {
    this.enabled = false,
    this.onTap,
    this.phase = 2,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;
  final int phase;
}
