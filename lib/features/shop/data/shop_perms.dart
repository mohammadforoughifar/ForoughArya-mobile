// ============================================================
//  مجوزهای «سامانه فروشگاهی» — دقیقاً همان قاعدهٔ وب (Parties.razor)
//    CanSeeCustomers = Has("Parties.Read") || HasModule("Customers")
//    CanSeeSuppliers = Has("Parties.Read") || HasModule("Suppliers")
//    CanCreateCurrent = Has("Parties.Create") || Has("{Module}.Create")
//  ⚠️ این فقط برای پنهان/نمایش دکمه است؛ سنجش نهایی سمت سرور است.
// ============================================================

import '../../../core/auth/auth_session.dart';

class ShopPerms {
  ShopPerms(this._session);
  final AuthSession? _session;

  bool has(String permission) => _session?.has(permission) ?? false;

  /// معادل `HasModule`: هر مجوزی که با «Module.» شروع شود
  bool hasModule(String module) {
    final s = _session;
    if (s == null) return false;
    if (s.role == 'Admin') return true;
    final prefix = '${module.toLowerCase()}.';
    return s.permissions.any((p) => p.toLowerCase().startsWith(prefix));
  }

  // ---------------- طرف حساب‌ها ----------------
  bool get canSeeCustomers => has('Parties.Read') || hasModule('Customers');
  bool get canSeeSuppliers => has('Parties.Read') || hasModule('Suppliers');
  bool get anyPartyAccess => canSeeCustomers || canSeeSuppliers;

  String moduleOf(int type) => type == 1 ? 'Suppliers' : 'Customers';

  bool canCreateParty(int type) =>
      has('Parties.Create') || has('${moduleOf(type)}.Create');
  bool canUpdateParty(int type) =>
      has('Parties.Update') || has('${moduleOf(type)}.Update');
  bool canDeleteParty(int type) =>
      has('Parties.Delete') || has('${moduleOf(type)}.Delete');

  /// عنوان صفحه مثل وب: اگر فقط تأمین‌کننده می‌بیند → «تأمین‌کنندگان»
  String get partyPageTitle =>
      canSeeSuppliers && !canSeeCustomers ? 'تأمین‌کنندگان' : 'طرف حساب‌ها';
}
