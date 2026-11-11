// ============================================================
//  گیت‌های مجوز «مدیریت سخت‌افزار» — عیناً مثل وب
//  منبع: Layout/NavMenu.razor (ShowAdminGroup) و تک‌تک صفحات ItAssets/Cctv
// ============================================================

import '../../../core/auth/auth_session.dart';

class ItPerms {
  ItPerms(this._session);
  final AuthSession? _session;

  bool has(String permission) => _session?.has(permission) ?? false;

  bool get isAdmin => (_session?.role ?? '') == 'Admin';

  /// معادل `HasModule` وب: هر مجوزی که با «Module.» شروع شود
  bool hasModule(String module) {
    final s = _session;
    if (s == null) return false;
    if (s.role == 'Admin') return true;
    final prefix = '${module.toLowerCase()}.';
    return s.permissions.any((p) => p.toLowerCase().startsWith(prefix));
  }

  /// معادل `CanSee("Module")` وب
  bool canSeeModule(String module) =>
      hasModule(module) || has('$module.Read');

  // ---------------- داشبورد سخت‌افزار ----------------
  bool get canSeeHardwareDashboard => has('Dashboards.Hardware');

  // ---------------- گروه «مدیریت سیستم» ----------------
  bool get canSeeItRequests => canSeeModule('ItRequests');
  bool get canSeeSystemUsers => canSeeModule('SystemUsers');

  /// زیرآیتم «شرکت‌های راه‌دور» فقط برای مدیر
  bool get canSeeRemoteCompanies => canSeeItRequests && isAdmin;
  bool get canSeeCctvCameras => canSeeModule('CctvCameras');
  bool get canSeeCctvNvrs => canSeeModule('CctvNvrs');
  bool get canSeeItVault => canSeeModule('ItVault');
  bool get canSeeServers => canSeeModule('Servers');
  bool get canSeeIpam => canSeeModule('Ipam');

  /// همان `ShowAdminGroup` وب
  bool get canSeeAdminGroup =>
      canSeeItRequests ||
      canSeeSystemUsers ||
      canSeeCctvCameras ||
      canSeeCctvNvrs ||
      canSeeItVault ||
      canSeeServers ||
      canSeeIpam;

  // ---------------- مجوزهای دانه‌ای (فازهای بعدی) ----------------
  bool get ipamCreate => has('Ipam.Create');
  bool get ipamUpdate => has('Ipam.Update');
  bool get ipamDelete => has('Ipam.Delete');
  bool get ipamScan => has('Ipam.Scan');

  bool get serversCreate => has('Servers.Create');
  bool get serversUpdate => has('Servers.Update');
  bool get serversDelete => has('Servers.Delete');
  bool get serversCollect => has('Servers.Collect');

  bool get vaultCreate => has('ItVault.Create');
  bool get vaultUpdate => has('ItVault.Update');
  bool get vaultDelete => has('ItVault.Delete');
  bool get vaultReveal => has('ItVault.Reveal');
  bool get vaultViewLog => has('ItVault.ViewLog');
}
