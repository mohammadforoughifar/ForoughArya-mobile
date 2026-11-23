// ============================================================
//  گیت‌های مجوز «مدیریت سیستم و سخت‌افزار» — عیناً مثل وب
//  منبع: Layout/NavMenu.razor (ShowAdminGroup) و ModuleAccess.cs
// ============================================================

import '../../../core/auth/auth_session.dart';

class ItPerms {
  ItPerms(this._session);
  final AuthSession? _session;

  bool has(String permission) => _session?.has(permission) ?? false;

  bool get isAdmin => _session?.isAdmin ?? false;

  /// معادل `HasModule` وب: هر مجوزی که با «Module.» شروع شود
  bool hasModule(String module) => _session?.hasModule(module) ?? false;

  /// معادل دقیق `ModuleAccess.CanSee(Auth, module)` وب:
  /// برای ماژول‌های استاندارد فقط `.View` / `.Read` / `.Access` منو را باز می‌کند
  /// و برای ماژول‌های بخشی (`ItRequests` و...) هر مجوزی از همان ماژول کافی است.
  bool canSeeModule(String module) => _session?.canSee(module) ?? false;

  // ---------------- داشبوردهای مدیریتی و سخت‌افزار ----------------
  bool get canSeeHardwareDashboard => has('Dashboards.Hardware');
  bool get canSeeManagementDashboard => has('Dashboards.Management');

  // ---------------- گروه «مدیریت سیستم» ----------------
  bool get canSeeItRequests => canSeeModule('ItRequests');
  bool get canSeeSystemUsers => canSeeModule('SystemUsers');

  /// زیرآیتم «شرکت‌های راه‌دور» فقط برای مدیر دارای `ItRequests`
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

  // ---------------- مجوزهای دانه‌ای ----------------
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
