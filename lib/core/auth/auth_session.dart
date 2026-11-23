class AuthSession {
  const AuthSession({
    required this.userId,
    required this.token,
    required this.username,
    required this.role,
    required this.displayName,
    this.referrerId,
    this.roleNames = const [],
    this.permissions = const [],
  });

  /// ماژول‌هایی که مجوزها در آن‌ها به صورت بخش‌به‌بخش تعریف شده‌اند و داشتن هر
  /// مجوز با پیشوند `{Module}.` به معنای دسترسی مشاهده به آن ماژول است
  /// (آینهٔ دقیق `ModuleAccess.PerSectionModules` در وب).
  static const Set<String> perSectionModules = {
    'itrequests',
    'referrerpanel',
    'leaverequests',
    'attendance',
    'dashboards',
    'reportpages',
  };

  final int userId;
  final String token;
  final String username;
  final String role;
  final String displayName;
  final int? referrerId;
  final List<String> roleNames;
  final List<String> permissions;

  factory AuthSession.fromJson(Map<String, dynamic> j) => AuthSession(
    userId: ((j['userId'] ?? j['UserId']) as num?)?.toInt() ?? 0,
    token: (j['token'] ?? j['Token'])?.toString() ?? '',
    username: (j['username'] ?? j['Username'])?.toString() ?? '',
    role: (j['role'] ?? j['Role'])?.toString() ?? '',
    displayName:
        (j['displayName'] ?? j['DisplayName'])?.toString() ??
        (j['username'] ?? j['Username'])?.toString() ??
        '',
    referrerId: ((j['referrerId'] ?? j['ReferrerId']) as num?)?.toInt(),
    roleNames: ((j['roleNames'] ?? j['RoleNames']) as List? ?? [])
        .map((e) => e.toString())
        .toList(),
    permissions: ((j['permissions'] ?? j['Permissions']) as List? ?? [])
        .map((e) => e.toString())
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'token': token,
    'username': username,
    'role': role,
    'displayName': displayName,
    'referrerId': referrerId,
    'roleNames': roleNames,
    'permissions': permissions,
  };

  /// معادل `IAuthState.IsAdmin` در وب.
  bool get isAdmin => role.trim().toLowerCase() == 'admin';

  /// معادل `IAuthState.IsReferrer` در وب.
  bool get isReferrer => role.trim().toLowerCase() == 'referrer';

  /// معادل `IAuthState.IsSalesManager` در وب.
  bool get isSalesManager =>
      isAdmin ||
      roleNames.any((r) => r.trim().toLowerCase() == 'salesmanager');

  /// مدیر قدیمی بدون نقش RBAC یا توکن تست دارای wildcard (`*`) —
  /// مطابق `EffectivePermissions.IsLegacyAdminAsync` در وب، اگر کاربر نقش RBAC
  /// فعال داشته باشد (`roleNames` یا `permissions` پر شده باشد)، فقط مجوزهای
  /// واقعی همان نقش‌ها ملاک است تا برداشتن تیک یک دسترسی واقعاً اعمال شود.
  bool get isUnrestrictedAdmin =>
      permissions.any((p) => p.trim() == '*') ||
      (isAdmin && roleNames.isEmpty && permissions.isEmpty);

  /// بررسی دقیق تک‌مجوز بدون هیچ‌گونه بسط ضمنی — معادل `AuthState.HasDirect` وب.
  bool hasDirect(String permission) {
    final target = permission.trim().toLowerCase();
    if (target.isEmpty) return false;
    if (isUnrestrictedAdmin) return true;
    return permissions.any((p) => p.trim().toLowerCase() == target);
  }

  /// معادل `AuthState.Has` در وب (`ShopSections.AliasAllows` روی وب همیشه false است
  /// تا مجوز فروشگاهی به ماژول‌های ERP نشت نکند).
  bool has(String permission) => hasDirect(permission);

  /// معادل `AuthState.HasModuleDirect` در وب: داشتن حداقل یک مجوز با پیشوند `{module}.`
  bool hasModuleDirect(String module) {
    final m = module.trim().toLowerCase();
    if (m.isEmpty) return false;
    if (isUnrestrictedAdmin) return true;
    final prefix = '$m.';
    return permissions.any((p) => p.trim().toLowerCase().startsWith(prefix));
  }

  /// معادل `AuthState.HasModule` در وب.
  bool hasModule(String module) => hasModuleDirect(module);

  /// معادل دقیق `ModuleAccess.CanSee(auth, module)` در وب:
  /// عمداً `isAdmin` را دور نمی‌زند تا اگر تیک «مشاهده» از نقش برداشته شد،
  /// منو واقعاً پنهان شود.
  bool canSee(String module) {
    final m = module.trim();
    if (m.isEmpty) return false;
    if (isUnrestrictedAdmin) return true;
    if (hasDirect('$m.View') ||
        hasDirect('$m.Read') ||
        hasDirect('$m.Access')) {
      return true;
    }
    return perSectionModules.contains(m.toLowerCase()) && hasModuleDirect(m);
  }

  /// معادل `ModuleAccess.CanSeeAny` در وب.
  bool canSeeAny(Iterable<String> modules) => modules.any(canSee);
}
