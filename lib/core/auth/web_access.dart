// ============================================================
//  موتور یکپارچهٔ کنترل دسترسی اندروید — آینهٔ ۱۰۰٪ دقیق نسخهٔ وب
//  مراجع مستقیم در TotallCollectionSoftware:
//    • Inventory.Client/Services/AuthState.cs
//    • Inventory.Client/Services/ModuleAccess.cs
//    • Inventory.Client/Services/ShopAccess.cs
//    • Inventory.Shared/ShopSections.cs
//    • Inventory.Client/Layout/NavMenu.razor
//    • Inventory.Client/Pages/RootLanding.razor
//    • Inventory.Api/Controllers/Dashboards/DashboardsController.cs
//    • Inventory.Api/Services/Dashboards/WidgetCatalog.cs
//    • Inventory.Client/Services/ErpNavigation.cs
//    • Inventory.Client/Services/HrNavigation.cs
//    • Inventory.Client/Services/ForoughAryaHrNavigation.cs
// ============================================================

import '../../features/moadian/data/moadian_perms.dart';
import '../../features/shop/data/shop_perms.dart';
import 'auth_session.dart';

class WebAccess {
  WebAccess(this.session, {this.unrestrictedWhenNull = false})
    : shop = ShopPerms(session);

  /// در اجرای واقعی اپ (`App`)، پوسته و میز کار فقط پس از ورود (`session != null`)
  /// ساخته می‌شوند؛ فلگ [unrestrictedWhenNull] صرفاً برای سازگاری با تست‌های
  /// ویجت ایزوله‌ای است که بدون نشست احراز هویت `HomePage`/`HomeShell` را سوار می‌کنند.
  final AuthSession? session;
  final bool unrestrictedWhenNull;
  final ShopPerms shop;

  bool get _openPreview => session == null && unrestrictedWhenNull;

  bool get isAdmin => _openPreview || (session?.isAdmin ?? false);
  bool get isUnrestricted =>
      _openPreview || (session?.isUnrestrictedAdmin ?? false);
  bool get isReferrer => session?.isReferrer ?? false;
  bool get isSalesManager => _openPreview || (session?.isSalesManager ?? false);

  bool has(String permission) =>
      _openPreview || (session?.has(permission) ?? false);

  bool hasDirect(String permission) =>
      _openPreview || (session?.hasDirect(permission) ?? false);

  bool hasModule(String module) =>
      _openPreview || (session?.hasModule(module) ?? false);

  bool canSee(String module) =>
      _openPreview || (session?.canSee(module) ?? false);

  bool canSeeAny(Iterable<String> modules) =>
      _openPreview || (session?.canSeeAny(modules) ?? false);

  // ================== پنل معرف (MainLayout.razor + MyDashboard.razor) ==================

  bool get canSeeRefWallet => has('ReferrerPanel.MyWallet');
  bool get canSeeRefProducts => has('ReferrerPanel.MyProducts');
  bool get canSeeRefCard => has('ReferrerPanel.MyCard');

  // ================== ریشه، کارتابل و داشبوردها (RootLanding + NavMenu) ==================

  /// مطابق `RootLanding.razor` و `NavMenu.razor`: کارتابل من با `MyCartable` باز می‌شود
  /// و برای نقش معرف نمایش داده نمی‌شود.
  bool get canSeeMyCartable =>
      !isReferrer && (_openPreview || canSee('MyCartable'));

  bool get canSeeMyArchive => !isReferrer && canSee('MyArchive');

  /// داشبورد شخصی (`MyDashboards.View`) — طبق `SIDEBAR-PERMISSIONS-FA.md` بدون تیک
  /// صریح حتی برای نقش‌های مدیریتی نمایش داده نمی‌شود.
  bool get canSeeMyDashboards => !isReferrer && canSee('MyDashboards');

  /// داشبورد مالی فروشگاه (`/dashboard` — `AdminHome.razor` و `DashboardController.cs`)
  bool get canSeeFinancialDashboard =>
      !isReferrer && hasDirect('Dashboards.Financial');

  /// داشبورد مدیریت بلادرنگ (`/dashboard-cctv` — `DashboardLive.razor`)
  bool get canSeeManagementDashboard =>
      !isReferrer && hasDirect('Dashboards.Management');

  /// داشبورد سخت‌افزار (`/dashboard-hardware` — `DashboardHardware.razor`)
  bool get canSeeHardwareDashboard =>
      !isReferrer && hasDirect('Dashboards.Hardware');

  /// نگاشت دقیق کلید ویجت‌های میز کار به ماژول RBAC در `WidgetCatalog.cs`.
  static String? widgetModuleOf(String widgetKey) =>
      switch (widgetKey.trim().toLowerCase()) {
        'fac-sales-today' ||
        'fac-sales-period' ||
        'fac-purchase-period' ||
        'fac-invoice-count' ||
        'fac-sales-trend' ||
        'fac-sales-vs-purchase' ||
        'fac-top-parties' ||
        'fac-top-products' => 'FacInvoices',
        'inv-stock-value' ||
        'inv-doc-count' ||
        'inv-doc-trend' => 'InvDocs',
        'prod-reorder-count' ||
        'prod-reorder-list' ||
        'prod-stock-by-warehouse' => 'Products',
        'acc-voucher-count' || 'acc-voucher-trend' => 'AccVouchers',
        'trs-receipt-period' ||
        'trs-payment-period' ||
        'trs-flow-trend' => 'TrsVouchers',
        'trs-cheques-amount' || 'trs-cheques-due' => 'TrsCheques',
        'exp-period' || 'exp-by-category' => 'Expenses',
        'off-letters-count' ||
        'off-letters-by-type' ||
        'off-letters-trend' ||
        'off-letters-by-status' ||
        'off-letters-by-urgency' ||
        'off-erja-unread' ||
        'off-out-count' ||
        'off-inner-count' ||
        'off-inner-overdue' => 'InnerLetters',
        'wo-open' || 'wo-overdue' || 'wo-by-status' => 'WorkOrders',
        'wp-my-progress' => 'WorkProjects',
        'it-open' => 'ItRequests',
        'hr-employees' => 'HrCore',
        'fa-att-today' => 'FaAtt',
        'doc-expiring' => 'DocArchive',
        _ => null,
      };

  /// مطابق `DashboardsController.Catalog` و `DashboardsController.WidgetData`:
  /// کاربر هم باید مجوز `MyDashboards.View` داشته باشد و هم مجوز مشاهدهٔ ماژول ویجت
  /// (`Read` / `View` / `Access`).
  bool canSeeWidget(String widgetKey) {
    if (_openPreview) return true;
    if (!canSeeMyDashboards) return false;
    if (isUnrestricted) return true;
    final mod = widgetModuleOf(widgetKey);
    if (mod == null || mod.isEmpty) return true;
    return hasDirect('$mod.Read') ||
        hasDirect('$mod.View') ||
        hasDirect('$mod.Access');
  }

  // ================== ماژول‌های اصلی ناوبری (NavMenu.razor) ==================

  bool get canSeeChat => !isReferrer && canSee('Chat');
  bool get canSeeMessenger => canSeeChat;

  // --- دستورکار رایکا ---
  bool get canSeeWorkOrders => !isReferrer && canSee('WorkOrders');
  bool get canCreateWorkOrder => !isReferrer && has('WorkOrders.Create');
  bool get canDeleteWorkOrder => !isReferrer && has('WorkOrders.Delete');
  bool get canAssignOthersWorkOrder =>
      !isReferrer && has('WorkOrders.AssignOthers');

  // --- اتوماسیون اداری توکا و ایمیل ---
  bool get canSeeInnerLetters => !isReferrer && canSee('InnerLetters');
  bool get canSeeOutgoingLetters => !isReferrer && canSee('OutgoingLetters');
  bool get canSeeIncomingLetters => !isReferrer && canSee('IncomingLetters');
  bool get canSeeLettersAny =>
      canSeeInnerLetters || canSeeOutgoingLetters || canSeeIncomingLetters;
  bool get canSeeOfficeAutomation => canSeeLettersAny || canSeeMinutes;

  bool get canCreateInnerLetter => !isReferrer && has('InnerLetters.Create');
  bool get canCreateOutgoingLetter =>
      !isReferrer && has('OutgoingLetters.Create');
  bool get canCreateIncomingLetter =>
      !isReferrer && has('IncomingLetters.Create');
  bool get canCreateAnyLetter =>
      canCreateInnerLetter ||
      canCreateOutgoingLetter ||
      canCreateIncomingLetter;

  bool get canSeeEmail => !isReferrer && canSee('Email');
  bool get canCreateEmail => !isReferrer && has('Email.Create');
  bool get canDeleteEmail => !isReferrer && has('Email.Delete');
  bool get canSeePersonalEmail => !isReferrer && has('Email.Personal');
  bool get canSeeEmailAny => canSeeEmail || canSeePersonalEmail;

  bool get canSeeOfficeGroup => canSeeLettersAny || canSeeEmail;

  // --- صورتجلسه ---
  bool get canSeeMinutes => !isReferrer && canSee('MeetingMinutes');
  bool get canCreateMinutes => !isReferrer && has('MeetingMinutes.Create');
  bool get canUpdateMinutes => !isReferrer && has('MeetingMinutes.Update');
  bool get canDeleteMinutes => !isReferrer && has('MeetingMinutes.Delete');
  bool get canSignMinutes => !isReferrer && has('MeetingMinutes.Sign');
  bool get canPrintMinutes => !isReferrer && has('MeetingMinutes.Print');

  // --- آرشیو اسناد و مدارک ---
  bool get canSeeDocArchive => !isReferrer && canSee('DocArchive');

  // --- مدیریت سیستم و سخت‌افزار (`ShowAdminGroup` در `NavMenu.razor`) ---
  bool get canSeeAdminGroup =>
      !isReferrer &&
      canSeeAny(const [
        'ItRequests',
        'SystemUsers',
        'CctvCameras',
        'CctvNvrs',
        'ItVault',
        'Servers',
        'Ipam',
      ]);

  bool get canSeeItSystemTile =>
      canSeeAdminGroup ||
      canSeeHardwareDashboard ||
      canSeeManagementDashboard;

  bool get canSeeItRequests => !isReferrer && canSee('ItRequests');
  bool get canCreateItRequest =>
      !isReferrer && (has('ItRequests.Create') || has('ItRequests.Manage'));
  bool get canSeeServers => !isReferrer && canSee('Servers');
  bool get canSeeIpam => !isReferrer && canSee('Ipam');
  bool get canSeeItVault => !isReferrer && canSee('ItVault');
  bool get canSeeCctvCameras => !isReferrer && canSee('CctvCameras');
  bool get canSeeCctvNvrs => !isReferrer && canSee('CctvNvrs');
  bool get canSeeSystemUsers => !isReferrer && canSee('SystemUsers');

  // --- فروشگاهی کایر (`ShowOpsGroup` + `ShowReportsGroup` در `NavMenu.razor`) ---
  bool get canSeeShopGroup {
    if (isReferrer) return false;
    if (_openPreview) return true;
    return shop.canSeeShopGroup;
  }

  bool get canCreateSale => !isReferrer && (_openPreview || shop.canManageSale);
  bool get canCreatePurchase =>
      !isReferrer && (_openPreview || shop.canManagePurchase);
  bool get canCreateSettlement =>
      !isReferrer && (_openPreview || shop.canManageSettlement);

  // --- مودیان تیسا (`CanSeeMoadian` + `CanSeeMoadianBasicInfo` در `NavMenu.razor`) ---
  bool get canSeeMoadianOverview =>
      !isReferrer && (_openPreview || isAdmin || canSee('Moadian'));

  bool get canSeeMoadianGroup =>
      !isReferrer &&
      (_openPreview ||
          canSeeMoadianOverview ||
          MoadianPerms.canAnyBasicInfo(session));

  bool get canCreateMoadianInvoice =>
      !isReferrer &&
      (_openPreview || MoadianPerms.can(session, MoadianPerms.invoiceCreate));

  // --- ERP فیکا (`ErpNavigation.CanEnter(Auth.HasModule)`) ---
  static const List<String> _erpModules = [
    'Products',
    'Warehouses',
    'InvDocTypes',
    'InvDocs',
    'AccAccounts',
    'AccVouchers',
    'FacInvoices',
    'TrsCheques',
    'TrsAccounts',
    'StkSessions',
    'StkBarcodes',
  ];

  bool get canSeeErp => !isReferrer && _erpModules.any(hasModule);

  // --- منابع انسانی اصلی (`HrNavigation.CanEnter(Auth.Has, Auth.IsAdmin)`) ---
  static const List<String> _hrMainModules = [
    'FaAtt',
    'FaPay',
    'FaCom',
    'FaLms',
    'HrCore',
    'HrMain',
  ];

  bool get canSeeHrMain =>
      !isReferrer && (isAdmin || _hrMainModules.any(hasModule));

  // --- منابع انسانی فروغ آریا (`ForoughAryaHrNavigation.CanEnter`) ---
  static const List<String> _hrForoughPermissions = [
    'Attendance.SelfCheckin',
    'Attendance.ViewAll',
    'Attendance.ManageShifts',
    'LeaveRequests.Request',
    'LeaveRequests.Approve',
    'LeaveRequests.Report',
    'HrPay.Read',
    'HrPay.Manage',
  ];

  bool get canSeeHrForough =>
      !isReferrer && (isAdmin || _hrForoughPermissions.any(has));

  // --- منابع انسانی بن‌سازه (`Auth.HasModule("RadisHr")`) ---
  bool get canSeeHrBonsaze => !isReferrer && hasModule('RadisHr');

  /// گیت واحد برای تک‌تک کاشی‌های `buildModuleTiles` در صفحهٔ اصلی (`HomePage`).
  bool canSeeModuleTile(String tileId) => switch (tileId) {
    'financial-dashboard' => canSeeFinancialDashboard,
    'letters' => canSeeLettersAny,
    'email' => canSeeEmail,
    'workorders' => canSeeWorkOrders,
    'shop' => canSeeShopGroup,
    'chat' => canSeeChat,
    'minutes' => canSeeMinutes,
    'it-assets' => canSeeItSystemTile,
    'doc-archive' => canSeeDocArchive,
    'doc-cartable' => canSeeDocArchive,
    'moadian' => canSeeMoadianGroup,
    'erp' => canSeeErp,
    'hr-main' => canSeeHrMain,
    'hr-forough' => canSeeHrForough,
    'hr-bonsaze' => canSeeHrBonsaze,
    _ => false,
  };
}
