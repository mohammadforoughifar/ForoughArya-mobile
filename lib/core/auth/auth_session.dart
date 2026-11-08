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

  final int userId;
  final String token;
  final String username;
  final String role;
  final String displayName;
  final int? referrerId;
  final List<String> roleNames;
  final List<String> permissions;

  factory AuthSession.fromJson(Map<String, dynamic> j) => AuthSession(
    userId: (j['userId'] as num?)?.toInt() ?? 0,
    token: j['token']?.toString() ?? '',
    username: j['username']?.toString() ?? '',
    role: j['role']?.toString() ?? '',
    displayName:
        j['displayName']?.toString() ?? j['username']?.toString() ?? '',
    referrerId: (j['referrerId'] as num?)?.toInt(),
    roleNames: (j['roleNames'] as List? ?? [])
        .map((e) => e.toString())
        .toList(),
    permissions: (j['permissions'] as List? ?? [])
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

  bool has(String permission) {
    if (role == 'Admin') return true;
    if (permissions.any((p) => p.toLowerCase() == permission.toLowerCase()))
      return true;
    final module = permission.split('.').first.toLowerCase();
    return permissions.any(
      (p) =>
          p.toLowerCase() == '$module.manage' ||
          p.toLowerCase() == '$module.full',
    );
  }
}
