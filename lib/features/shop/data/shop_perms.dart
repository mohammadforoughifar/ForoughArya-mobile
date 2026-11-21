// ============================================================
//  مجوزهای «فروشگاهی کایر» — آینهٔ دقیق وب:
//    Inventory.Shared/ShopSections.cs
//    Inventory.Client/Services/ShopAccess.cs
//    Inventory.Client/Services/ModuleAccess.cs
//    Inventory.Client/Layout/NavMenu.razor
//
//  قواعد کلیدی:
//    ۱) هر بخش فروشگاهی مجوز `Shop.{Key}.View` و (در صورت عملیاتی‌بودن)
//       `Shop.{Key}.Manage` دارد.
//    ۲) مجوز `Shop.Sale.*` هرگز به `Shop.Purchase.*` نشت نمی‌کند.
//    ۳) برای سازگاری با سرورها/نقش‌های قدیمی که هنوز فقط مجوز ماژول‌های
//       قدیمی (`Orders.Read`، `Products.Read` و ...) را دارند، فقط به مجوز
//       خام (`hasDirect`) همان ماژول رجوع می‌شود؛ بخش‌های جدید `PrintSettings`
//       و `Pricing` مطابق کنترلر سرور فقط با `Admin` یا `Shop.{Key}.*` باز می‌شوند.
// ============================================================

import '../../../core/auth/auth_session.dart';

/// تعریف یک بخش از «فروشگاهی کایر» — معادل رکورد `ShopSection` در سی‌شارپ
class ShopSectionDef {
  const ShopSectionDef({
    required this.key,
    required this.title,
    required this.writable,
    this.legacyModules = const [],
  });

  final String key;
  final String title;
  final bool writable;

  /// ماژول‌های قدیمی سازگار (صرفاً با `hasDirect` بررسی می‌شوند تا نشت رخ ندهد)
  final List<String> legacyModules;

  String get viewPermission => 'Shop.$key.View';
  String get managePermission => 'Shop.$key.Manage';
}

/// فهرست ۲۳ بخش استاندارد «فروشگاهی کایر» (ترتیب و کلیدها دقیقاً مطابق `ShopSections.cs`)
class ShopSections {
  const ShopSections._();

  static const List<ShopSectionDef> all = [
    ShopSectionDef(
      key: 'Dashboard',
      title: 'داشبورد عملیاتی (خرید، فروش و تعمیرات)',
      writable: false,
      legacyModules: ['Orders', 'Repairs'],
    ),
    ShopSectionDef(
      key: 'Purchase',
      title: 'خرید (رسید خرید)',
      writable: true,
      legacyModules: ['Orders'],
    ),
    ShopSectionDef(
      key: 'Sale',
      title: 'فروش (فاکتور فروش)',
      writable: true,
      legacyModules: ['Orders'],
    ),
    ShopSectionDef(
      key: 'GoodsIssue',
      title: 'بیجک (حوالهٔ تحویل کالا)',
      writable: true,
      legacyModules: ['GoodsIssues'],
    ),
    ShopSectionDef(
      key: 'Repairs',
      title: 'تعمیرات',
      writable: true,
      legacyModules: ['Repairs'],
    ),
    ShopSectionDef(
      key: 'Expenses',
      title: 'هزینه‌ها',
      writable: true,
      legacyModules: ['Expenses'],
    ),
    ShopSectionDef(
      key: 'Installments',
      title: 'مدیریت اقساط و چک‌ها',
      writable: true,
      legacyModules: ['Orders', 'TrsVouchers'],
    ),
    ShopSectionDef(
      key: 'OpeningBalance',
      title: 'افتتاح حساب و مانده‌های اولیه',
      writable: true,
      legacyModules: ['Orders', 'TrsVouchers'],
    ),
    ShopSectionDef(
      key: 'Settlement',
      title: 'تسویه فاکتورها',
      writable: true,
      legacyModules: ['TrsVouchers'],
    ),
    ShopSectionDef(
      key: 'Kardex',
      title: 'کاردکس کالا (تعداد و ریالی)',
      writable: false,
      legacyModules: ['ReportPages'],
    ),
    ShopSectionDef(
      key: 'OrderReports',
      title: 'گزارش خرید و فروش',
      writable: false,
      legacyModules: ['Orders'],
    ),
    ShopSectionDef(
      key: 'PartyStatements',
      title: 'گزارش طلب و بدهی اشخاص',
      writable: false,
      legacyModules: ['Parties', 'Customers', 'Suppliers'],
    ),
    ShopSectionDef(
      key: 'Products',
      title: 'کالاها',
      writable: true,
      legacyModules: ['Products'],
    ),
    ShopSectionDef(
      key: 'Categories',
      title: 'گروه‌های کالا',
      writable: true,
      legacyModules: ['Products', 'Categories'],
    ),
    ShopSectionDef(
      key: 'Units',
      title: 'واحدهای شمارش',
      writable: true,
      legacyModules: ['Products', 'Units'],
    ),
    ShopSectionDef(
      key: 'Warehouses',
      title: 'انبارها',
      writable: true,
      legacyModules: ['Warehouses'],
    ),
    ShopSectionDef(
      key: 'Parties',
      title: 'طرف حساب‌ها (مشتری و تأمین‌کننده)',
      writable: true,
      legacyModules: ['Parties'],
    ),
    ShopSectionDef(
      key: 'PrintSettings',
      title: 'تنظیمات فروشگاه',
      writable: true,
    ),
    ShopSectionDef(
      key: 'Pricing',
      title: 'قیمت‌گذاری و حداقل سود',
      writable: true,
    ),
    ShopSectionDef(
      key: 'Referrers',
      title: 'معرف‌ها',
      writable: true,
      legacyModules: ['Referrers'],
    ),
    ShopSectionDef(
      key: 'Banks',
      title: 'بانک، صندوق و کارتخوان (POS)',
      writable: true,
      legacyModules: ['TrsAccounts'],
    ),
    ShopSectionDef(
      key: 'SalesVisit',
      title: 'فروش و ویزیتوری (سفارش میدانی)',
      writable: true,
      legacyModules: ['SalesVisit'],
    ),
    ShopSectionDef(
      key: 'Guide',
      title: 'راهنمای سامانه فروشگاهی',
      writable: false,
      legacyModules: ['ShopGuide'],
    ),
  ];

  static final Map<String, ShopSectionDef> _byKey = {
    for (final s in all) s.key.toLowerCase(): s,
  };

  static ShopSectionDef? byKey(String? key) =>
      key == null ? null : _byKey[key.trim().toLowerCase()];
}

class ShopPerms {
  ShopPerms(this._session);
  final AuthSession? _session;

  static const Set<String> _perSectionModules = {
    'itrequests',
    'referrerpanel',
    'leaverequests',
    'attendance',
    'dashboards',
    'reportpages',
  };

  bool get isAdmin =>
      (_session?.role ?? '').trim().toLowerCase() == 'admin';

  /// نقش «مدیر فروش» — دقیقاً مطابق `AuthState.IsSalesManager` در وب
  bool get isSalesManager =>
      isAdmin ||
      (_session?.roleNames.any(
            (r) => r.trim().toLowerCase() == 'salesmanager',
          ) ??
          false);

  /// بررسی دقیق تک‌مجوز بدون بسط کلیدهای کلی ماژول (معادل `IAuthState.HasDirect`)
  bool hasDirect(String permission) {
    final s = _session;
    if (s == null) return false;
    if (isAdmin) return true;
    final target = permission.trim().toLowerCase();
    return s.permissions.any((p) => p.trim().toLowerCase() == target);
  }

  /// بررسی استاندارد مجوز (همراه با سازگاری `.Manage` / `.Full` برای ماژول‌های ۲بخشی)
  bool has(String permission) {
    final s = _session;
    if (s == null) return false;
    if (isAdmin) return true;
    if (hasDirect(permission)) return true;
    final parts = permission.trim().split('.');
    // برای مجوزهای ۳بخشی `Shop.{Key}.View` نباید `Shop.Manage` کلید بی‌ربط بسازد
    if (parts.length == 2) {
      final mod = parts.first.toLowerCase();
      return s.permissions.any((p) {
        final low = p.trim().toLowerCase();
        return low == '$mod.manage' || low == '$mod.full';
      });
    }
    return false;
  }

  /// معادل `HasModuleDirect`: داشتن حداقل یک مجوز با پیشوند `{module}.`
  bool hasModuleDirect(String module) {
    final s = _session;
    if (s == null) return false;
    if (isAdmin) return true;
    final prefix = '${module.trim().toLowerCase()}.';
    return s.permissions.any((p) => p.trim().toLowerCase().startsWith(prefix));
  }

  bool hasModule(String module) => hasModuleDirect(module);

  /// معادل `ModuleAccess.CanSeeDirect` وب
  bool canSeeModuleDirect(String module) {
    final m = module.trim();
    if (m.isEmpty) return false;
    if (isAdmin) return true;
    if (hasDirect('$m.View') ||
        hasDirect('$m.Read') ||
        hasDirect('$m.Access')) {
      return true;
    }
    if (m.toLowerCase() == 'reportpages') {
      return hasDirect('ReportPages.Kardex') ||
          hasDirect('ReportPages.Reorder');
    }
    return _perSectionModules.contains(m.toLowerCase()) &&
        hasModuleDirect(m);
  }

  /// سازگاری عقب‌رو با کدهای قبلی صفحات موبایل:
  /// اگر نام ماژول معادل یکی از بخش‌های فروشگاهی هم باشد، آن را نیز می‌سنجد.
  bool canSeeModule(String module) {
    if (canSeeModuleDirect(module)) return true;
    return switch (module.trim().toLowerCase()) {
      'orders' =>
        canSeeSection('Sale') ||
            canSeeSection('Purchase') ||
            canSeeSection('OrderReports'),
      'products' => canSeeSection('Products'),
      'categories' => canSeeSection('Categories'),
      'units' => canSeeSection('Units'),
      'warehouses' => canSeeSection('Warehouses'),
      'goodsissues' => canSeeSection('GoodsIssue'),
      'repairs' => canSeeSection('Repairs'),
      'expenses' => canSeeSection('Expenses'),
      'referrers' => canSeeSection('Referrers'),
      'trsaccounts' => canSeeSection('Banks'),
      'trsvouchers' => canSeeSection('Settlement'),
      'salesvisit' => canSeeSection('SalesVisit'),
      'shopguide' => canSeeSection('Guide'),
      'reportpages' => canSeeSection('Kardex'),
      _ => hasModule(module),
    };
  }

  /// معادل دقیق `ShopAccess.CanSee(Auth, key)` در وب (همراه با سازگاری مجوزهای خام قدیمی)
  bool canSeeSection(String key) {
    if (isAdmin) return true;
    final sec = ShopSections.byKey(key);
    if (sec == null) return false;
    if (hasDirect(sec.viewPermission)) return true;
    if (sec.writable && hasDirect(sec.managePermission)) return true;

    if (sec.key == 'Kardex') {
      return hasDirect('ReportPages.Kardex');
    }
    for (final legacy in sec.legacyModules) {
      if (canSeeModuleDirect(legacy)) return true;
    }
    return false;
  }

  /// معادل دقیق `ShopAccess.CanManage(Auth, key)` در وب
  bool canManageSection(String key) {
    final sec = ShopSections.byKey(key);
    if (sec == null || !sec.writable) return false;
    if (isAdmin) return true;
    if (hasDirect(sec.managePermission)) return true;

    for (final legacy in sec.legacyModules) {
      if (hasDirect('$legacy.Create') ||
          hasDirect('$legacy.Update') ||
          hasDirect('$legacy.Delete') ||
          hasDirect('$legacy.Manage') ||
          hasDirect('$legacy.Full')) {
        return true;
      }
    }
    return false;
  }

  bool canSeeAnySection(Iterable<String> keys) =>
      keys.any((k) => canSeeSection(k));

  // ---------------- میانبرهای کاربردی بخش‌های فروشگاهی کایر ----------------
  bool get canSeeDashboard =>
      canSeeSection('Dashboard') || hasDirect('Dashboards.Financial');

  bool get canSeePartyStatements =>
      canSeeSection('PartyStatements') || anyPartyAccess;

  bool get canSeeOrderReports => canSeeSection('OrderReports');
  bool get canSeeKardex => canSeeSection('Kardex');

  bool get canSeeProducts => canSeeSection('Products');
  bool get canManageProducts => canManageSection('Products');
  bool get canDeleteProduct =>
      canManageSection('Products') || has('Products.Delete');

  bool get canSeePricing => canSeeSection('Pricing');
  bool get canManagePricing => isAdmin || hasDirect('Shop.Pricing.Manage');

  bool get canSeePrintSettings => canSeeSection('PrintSettings');
  bool get canManagePrintSettings =>
      isAdmin || hasDirect('Shop.PrintSettings.Manage');

  bool get canSeeCategories => canSeeSection('Categories');
  bool get canManageCategories => canManageSection('Categories');

  bool get canSeeUnits => canSeeSection('Units');
  bool get canManageUnits => canManageSection('Units');

  bool get canSeeWarehouses => canSeeSection('Warehouses');
  bool get canManageWarehouses => canManageSection('Warehouses');

  bool get canSeeStock => canSeeModuleDirect('Stock');

  bool get canSeeBanks => canSeeSection('Banks');
  bool get canManageBanks => canManageSection('Banks');

  bool get canSeeReferrers => canSeeSection('Referrers');
  bool get canManageReferrers => canManageSection('Referrers');
  bool get canSeeReferrerWallets =>
      canSeeModuleDirect('ReferrerWallets') || canSeeSection('Referrers');

  bool get canSeePurchase => canSeeSection('Purchase');
  bool get canManagePurchase => canManageSection('Purchase');

  bool get canSeeSale => canSeeSection('Sale');
  bool get canManageSale => canManageSection('Sale');

  bool get canSeeGoodsIssue => canSeeSection('GoodsIssue');
  bool get canManageGoodsIssue => canManageSection('GoodsIssue');

  bool get canSeeRepairs => canSeeSection('Repairs');
  bool get canManageRepairs => canManageSection('Repairs');

  bool get canSeeExpenses => canSeeSection('Expenses');
  bool get canManageExpenses => canManageSection('Expenses');

  bool get canSeeInstallments => canSeeSection('Installments');
  bool get canManageInstallments => canManageSection('Installments');

  bool get canSeeOpeningBalance => canSeeSection('OpeningBalance');
  bool get canManageOpeningBalance => canManageSection('OpeningBalance');

  bool get canSeeSettlement => canSeeSection('Settlement');
  bool get canManageSettlement => canManageSection('Settlement');

  bool get canSeeCheques =>
      canSeeModuleDirect('TrsCheques') || canSeeSection('Installments');

  bool get canSeeGuide => canSeeSection('Guide');

  bool get canSeeProfit => isAdmin || hasDirect('Orders.ViewProfit');
  bool get canViewProfit => canSeeProfit;

  // ---------------- فروش و ویزیتوری (مطابق NavMenu.razor) ----------------
  bool get canSeeSalesVisitGroup =>
      canSeeSection('SalesVisit') || canSeeModuleDirect('SalesVisit');
  bool get canSeeSalesVisit => canSeeSalesVisitGroup;

  bool get canCreateVisit =>
      canManageSection('SalesVisit') || hasDirect('SalesVisit.Create');

  /// در وب: فقط `IsAdmin || (IsSalesManager && Has("SalesVisit.Approve"))`
  bool get canApproveVisits =>
      isAdmin || (isSalesManager && hasDirect('SalesVisit.Approve'));

  bool get canSeeVisitFinance =>
      isAdmin || hasDirect('SalesVisit.FinanceView');
  bool get canFinanceVisit => canSeeVisitFinance;

  // ---------------- طرف حساب‌ها (دقیقاً مطابق Parties.razor و NavMenu.razor) ----------------
  bool get _canSeeCustomersMenu =>
      hasDirect('Parties.Read') || hasModuleDirect('Customers');
  bool get _canSeeSuppliersMenu =>
      hasDirect('Parties.Read') || hasModuleDirect('Suppliers');

  String get partiesMenuLabel =>
      _canSeeSuppliersMenu && !_canSeeCustomersMenu
      ? 'تأمین‌کنندگان'
      : _canSeeCustomersMenu && !_canSeeSuppliersMenu
      ? 'مشتریان'
      : 'طرف حساب‌ها';

  bool get canSeeCustomers =>
      canSeeSection('Parties') ||
      hasDirect('Parties.Read') ||
      hasModuleDirect('Customers');

  bool get canSeeSuppliers =>
      canSeeSection('Parties') ||
      hasDirect('Parties.Read') ||
      hasModuleDirect('Suppliers');

  bool get anyPartyAccess => canSeeCustomers || canSeeSuppliers;

  String moduleOf(int type) => type == 1 ? 'Suppliers' : 'Customers';

  bool canCreateParty(int type) =>
      canManageSection('Parties') ||
      hasDirect('Parties.Create') ||
      hasDirect('${moduleOf(type)}.Create');

  bool canUpdateParty(int type) =>
      canManageSection('Parties') ||
      hasDirect('Parties.Update') ||
      hasDirect('${moduleOf(type)}.Update');

  bool canDeleteParty(int type) =>
      canManageSection('Parties') ||
      hasDirect('Parties.Delete') ||
      hasDirect('${moduleOf(type)}.Delete');

  /// عنوان صفحه مثل وب: اگر فقط تأمین‌کننده می‌بیند → «تأمین‌کنندگان»
  String get partyPageTitle =>
      canSeeSuppliers && !canSeeCustomers ? 'تأمین‌کنندگان' : 'طرف حساب‌ها';
}
