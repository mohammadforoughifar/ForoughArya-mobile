import '../../../core/auth/auth_session.dart';

/// ماتریس مجوزهای ۱۵گانه و قوانین وضعیت دکمه‌های «مودیان تیسا»
/// ۱۰۰٪ هم‌تراز با `MoadianPermissionFilter.cs` و `MoadianUi.cs` در وب.
class MoadianPerms {
  const MoadianPerms._();

  static const String view = 'Moadian.View';
  static const String company = 'Moadian.Company';
  static const String fiscalYear = 'Moadian.FiscalYear';
  static const String connection = 'Moadian.Connection';
  static const String goods = 'Moadian.Goods';
  static const String units = 'Moadian.Units';
  static const String customers = 'Moadian.Customers';
  static const String invoiceCreate = 'Moadian.InvoiceCreate';
  static const String invoiceUpdate = 'Moadian.InvoiceUpdate';
  static const String invoiceDelete = 'Moadian.InvoiceDelete';
  static const String invoiceSend = 'Moadian.InvoiceSend';
  static const String invoicePreview = 'Moadian.InvoicePreview';
  static const String invoiceStatus = 'Moadian.InvoiceStatus';
  static const String invoiceInquiry = 'Moadian.InvoiceInquiry';
  static const String diagnose = 'Moadian.Diagnose';

  static const List<String> allBasicInfo = [
    company,
    fiscalYear,
    connection,
    goods,
    units,
    customers,
  ];

  /// بررسی یک سطح دسترسی (پشتیبانی از نام کلیدهای وب `Moadian.X` و معادل‌های قدیمی `moadian.*.manage`).
  /// مطابق `MoadianPermissionFilter.cs` و `NavMenu.razor`:
  /// فقط مدیر قدیمی بدون نقش RBAC همه‌چیز را می‌بیند؛ اگر نقش RBAC فعال دارد،
  /// دقیقاً سطوح تیک‌خوردهٔ مودیان (و برای `Moadian.View` همچنین `isAdmin`) ملاک است.
  static bool can(AuthSession? session, String perm) {
    if (session == null) return false;
    if (session.isUnrestrictedAdmin) return true;
    if (perm == view && session.isAdmin) return true;
    if (session.hasDirect(perm)) return true;
    final alt = switch (perm) {
      company => 'moadian.company.manage',
      fiscalYear => 'moadian.fiscalyear.manage',
      connection => 'moadian.connection.manage',
      goods => 'moadian.goods.manage',
      units => 'moadian.units.manage',
      customers => 'moadian.customers.manage',
      invoiceCreate => 'moadian.invoice.create',
      invoiceUpdate => 'moadian.invoice.update',
      invoiceDelete => 'moadian.invoice.delete',
      invoiceSend => 'moadian.invoice.send',
      invoicePreview => 'moadian.invoice.preview',
      invoiceStatus => 'moadian.invoice.status',
      invoiceInquiry => 'moadian.invoice.inquiry',
      _ => '',
    };
    return alt.isNotEmpty && session.has(alt);
  }

  static bool canAnyBasicInfo(AuthSession? s) =>
      can(s, view) || allBasicInfo.any((p) => can(s, p));

  // ==================== برچسب‌ها و قواعد چرخهٔ وضعیت (۰ تا ۱۱) ====================

  static const String workFolderUrl = 'https://my.tax.gov.ir';

  static String statusLabel(String? code) => switch (code?.trim()) {
    '0' => 'ارسال نشده',
    '1' => 'ارسال شده در انتظار استعلام',
    '2' => 'در انتظار بررسی کارپوشه',
    '3' => 'ارسال شده',
    '4' => 'ارسال شده در انتظار واکنش',
    '5' => 'دارای خطا',
    '6' => 'بدون نیاز به واکنش',
    '7' => 'تأیید شده',
    '8' => 'رد شده',
    '9' => 'باطل',
    '10' => 'اصلاحی',
    '11' => 'تأیید سیستمی',
    null || '' => 'وضعیت نامشخص',
    final c => 'وضعیت ($c)',
  };

  static bool hasReference(String? referenceId) =>
      referenceId != null && referenceId.trim().isNotEmpty;

  /// ویرایش: فقط ارسال‌نشده (`0`) و خطای قطعی (`5`).
  static bool canEdit(String? code) => code == '0' || code == '5';

  /// ارسال / ارسال مجدد: فقط وضعیت‌های `0` و `5` به شرط فعال بودن `showButtons`.
  static bool canSend(String? code, bool showButtons) =>
      showButtons && (code == '0' || code == '5');

  /// پیش‌نمایش JSON قبل از ارسال.
  static bool canPreview(String? code, bool showButtons) =>
      showButtons && (code == '0' || code == '5');

  /// حذف پیش‌نویس: فقط وضعیت `0` (ارسال‌نشده).
  static bool canDelete(String? code, bool showButtons) =>
      showButtons && code == '0';

  /// استعلام وضعیت از سامانه مودیان.
  static bool canInquiry(String? code, String? referenceId) =>
      hasReference(referenceId) &&
      const {'1', '2', '3', '4', '5', '7', '8', '11'}.contains(code);

  /// ثبت دستی واکنش خریدار (تأیید شده `7` / رد شده `8` / تأیید سیستمی `11`).
  static bool canReactManually(String? code, String? referenceId) =>
      hasReference(referenceId) && const {'2', '3', '4'}.contains(code);

  /// نمایش خطاهای برگشتی سامانه.
  static bool canShowErrors(String? code, String? referenceId) =>
      code == '5' && hasReference(referenceId);

  /// صدور صورتحساب اصلاحی یا برگشت از فروش.
  static bool canReference(String? code, String? referenceId) =>
      hasReference(referenceId) &&
      const {'3', '4', '7', '8', '11'}.contains(code);

  /// ابطال صورتحساب مرجع.
  static bool canEbtal(String? code, String? referenceId) =>
      hasReference(referenceId) &&
      const {'2', '3', '4', '7', '8', '11'}.contains(code);
}
