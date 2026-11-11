// ============================================================
//  مدل‌های «گاوصندوق رمزهای تجهیزات» — فاز ۹-ه
//  منبع: `Inventory.Api/Controllers/ItAssets/ItVaultController.cs` (api/it-vault)
//        و `Inventory.Client/Pages/ItAssets/ItVault.razor` (/it-vault)
//  رمزها هرگز در لیست برنمی‌گردند؛ فقط با /reveal و توکن باز بودن.
// ============================================================

int _i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
int? _ni(Object? v) {
  if (v == null) return null;
  final n = v is num ? v.toInt() : int.tryParse('$v');
  return (n == null || n <= 0) ? null : n;
}

bool _b(Object? v) => v == true || v == 1 || '$v'.toLowerCase() == 'true';
String _s(Object? v) => v == null ? '' : '$v';
String? _ns(Object? v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

DateTime? _dt(Object? v) {
  final s = _ns(v);
  if (s == null) return null;
  return DateTime.tryParse(s);
}

// ============================================================
//  انواع تجهیز — عیناً `Categories` وب
// ============================================================

class VaultCategory {
  const VaultCategory({
    required this.key,
    required this.title,
    required this.colorValue,
    required this.titleHint,
    required this.portHint,
  });
  final String key;
  final String title;
  final int colorValue;
  final String titleHint;
  final String portHint;
}

const List<VaultCategory> kVaultCategories = [
  VaultCategory(
    key: 'Server',
    title: 'سرور',
    colorValue: 0xff2563eb,
    titleHint: 'مثلاً: سرور فایل / DC01',
    portHint: '22 / 3389',
  ),
  VaultCategory(
    key: 'Switch',
    title: 'سوییچ منیجبل',
    colorValue: 0xff0891b2,
    titleHint: 'مثلاً: سوییچ کور طبقه ۲',
    portHint: '22 / 80',
  ),
  VaultCategory(
    key: 'Mikrotik',
    title: 'میکروتیک',
    colorValue: 0xff7c3aed,
    titleHint: 'مثلاً: روتر اصلی میکروتیک',
    portHint: '8291',
  ),
  VaultCategory(
    key: 'Firewall',
    title: 'فایروال',
    colorValue: 0xffdc2626,
    titleHint: 'مثلاً: فورتی‌گیت / سوفوس',
    portHint: '443',
  ),
  VaultCategory(
    key: 'System',
    title: 'سامانه',
    colorValue: 0xff059669,
    titleHint: 'مثلاً: سامانهٔ مودیان / پنل پیامک',
    portHint: '443',
  ),
  VaultCategory(
    key: 'Other',
    title: 'سایر',
    colorValue: 0xff64748b,
    titleHint: 'مثلاً: NAS / پرینتر شبکه',
    portHint: '',
  ),
];

VaultCategory vaultCat(String? key) => kVaultCategories.firstWhere(
  (c) => c.key == key,
  orElse: () => kVaultCategories.last,
);

/// روش‌های اتصال — عیناً `AccessMethods` وب
const List<String> kVaultAccessMethods = [
  'SSH',
  'Telnet',
  'Web',
  'HTTPS',
  'Winbox',
  'RDP',
  'VNC',
  'Console',
  'API',
  'FTP',
  'SFTP',
];

// ============================================================
//  ردیف‌ها
// ============================================================

class VaultCompanyRow {
  const VaultCompanyRow({this.id = 0, this.name = '', this.count = 0});
  final int id;
  final String name;
  final int count;

  factory VaultCompanyRow.fromJson(Map<String, dynamic> j) => VaultCompanyRow(
    id: _i(j['id']),
    name: _s(j['name']),
    count: _i(j['count']),
  );

  VaultCompanyRow copyWith({int? count}) =>
      VaultCompanyRow(id: id, name: name, count: count ?? this.count);
}

class VaultRow {
  const VaultRow({
    this.id = 0,
    this.companyId = 0,
    this.category = 'Server',
    this.title = '',
    this.host,
    this.port,
    this.accessMethod,
    this.url,
    this.username,
    this.hasPassword = false,
    this.hasExtraSecret = false,
    this.location,
    this.notes,
    this.isActive = true,
    this.passwordChangedAt,
    this.createdAt,
    this.updatedAt,
    this.updatedByName,
  });

  final int id;
  final int companyId;
  final String category;
  final String title;
  final String? host;
  final int? port;
  final String? accessMethod;
  final String? url;
  final String? username;
  final bool hasPassword;
  final bool hasExtraSecret;
  final String? location;
  final String? notes;
  final bool isActive;
  final DateTime? passwordChangedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? updatedByName;

  factory VaultRow.fromJson(Map<String, dynamic> j) => VaultRow(
    id: _i(j['id']),
    companyId: _i(j['companyId']),
    category: _s(j['category']).isEmpty ? 'Server' : _s(j['category']),
    title: _s(j['title']),
    host: _ns(j['host']),
    port: _ni(j['port']),
    accessMethod: _ns(j['accessMethod']),
    url: _ns(j['url']),
    username: _ns(j['username']),
    hasPassword: _b(j['hasPassword']),
    hasExtraSecret: _b(j['hasExtraSecret']),
    location: _ns(j['location']),
    notes: _ns(j['notes']),
    isActive: j['isActive'] == null ? true : _b(j['isActive']),
    passwordChangedAt: _dt(j['passwordChangedAt']),
    createdAt: _dt(j['createdAt']),
    updatedAt: _dt(j['updatedAt']),
    updatedByName: _ns(j['updatedByName']),
  );

  VaultCategory get meta => vaultCat(category);

  /// `HostText()` وب
  String get hostText =>
      (host ?? '') + ((port ?? 0) > 0 ? ':${port ?? ''}' : '');

  /// آدرس نمایشی کارت موبایل: host یا url یا «—»
  String get addressCell {
    if ((host ?? '').isNotEmpty) return hostText;
    return (url ?? '').isEmpty ? '—' : url!;
  }

  /// جستجوی وب (`Match`) — عنوان/آی‌پی/کاربری/آدرس/محل/روش اتصال/توضیحات
  bool matches(String q) {
    final t = q.toLowerCase();
    bool has(String? s) => (s ?? '').toLowerCase().contains(t);
    return title.toLowerCase().contains(t) ||
        has(host) ||
        has(username) ||
        has(url) ||
        has(location) ||
        has(accessMethod) ||
        has(notes);
  }

  bool get canOpenUrl => (url ?? '').trim().isNotEmpty;
}

/// `SafeUrl()` وب — فقط http/https؛ ورودی بدون طرح با http:// تکمیل می‌شود
String vaultSafeUrl(String url) {
  final u = url.trim();
  final low = u.toLowerCase();
  if (low.startsWith('http://') || low.startsWith('https://')) return u;
  if (u.contains(':') && !u.contains('.')) return '';
  return 'http://$u';
}

// ============================================================
//  رمزها و توکن باز بودن
// ============================================================

/// پاسخ `POST api/it-vault/unlock`
class VaultUnlockResult {
  const VaultUnlockResult({
    this.token = '',
    this.expiresAt,
    this.minutes = 10,
  });
  final String token;
  final DateTime? expiresAt;
  final int minutes;

  factory VaultUnlockResult.fromJson(Map<String, dynamic> j) => VaultUnlockResult(
    token: _s(j['token']),
    expiresAt: _dt(j['expiresAt']),
    minutes: j['minutes'] == null ? 10 : _i(j['minutes']),
  );
}

/// پاسخ `POST api/it-vault/{id}/reveal`
class VaultSecret {
  const VaultSecret({this.password, this.extraSecret});
  final String? password;
  final String? extraSecret;

  factory VaultSecret.fromJson(Map<String, dynamic> j) => VaultSecret(
    password: _ns(j['password']),
    extraSecret: _ns(j['extraSecret']),
  );
}

/// ردیف لاگ دسترسی
class VaultLogRow {
  const VaultLogRow({
    this.id = 0,
    this.credentialId = 0,
    this.userName,
    this.action = '',
    this.clientIp,
    this.details,
    this.at,
    this.title,
  });
  final int id;
  final int credentialId;
  final String? userName;
  final String action;
  final String? clientIp;
  final String? details;
  final DateTime? at;
  final String? title;

  factory VaultLogRow.fromJson(Map<String, dynamic> j) => VaultLogRow(
    id: _i(j['id']),
    credentialId: _i(j['credentialId']),
    userName: _ns(j['userName']),
    action: _s(j['action']),
    clientIp: _ns(j['clientIp']),
    details: _ns(j['details']),
    at: _dt(j['at']),
    title: _ns(j['title']),
  );

  /// `ActionMeta()` وب
  String get actionLabel => switch (action) {
    'Reveal' => 'نمایش رمز',
    'Copy' => 'کپی رمز',
    'Create' => 'ایجاد',
    'Update' => 'ویرایش',
    'Delete' => 'حذف',
    'UnlockFailed' => 'رمز ورود اشتباه',
    _ => action,
  };

  /// رنگ برچسب (معادل کلاس بوت‌استرپ وب)
  int get actionColor => switch (action) {
    'Reveal' || 'Copy' => 0xffd97706,
    'Create' => 0xff1a7f37,
    'Update' => 0xff2563eb,
    'Delete' || 'UnlockFailed' => 0xffd13438,
    _ => 0xff64748b,
  };
}

// ============================================================
//  فرم افزودن/ویرایش — همان `SaveDto`
// ============================================================

class VaultSaveRequest {
  const VaultSaveRequest({
    this.companyId = 0,
    this.category = 'Server',
    this.title = '',
    this.host,
    this.port,
    this.accessMethod,
    this.url,
    this.username,
    this.password,
    this.clearPassword = false,
    this.extraSecret,
    this.clearExtraSecret = false,
    this.location,
    this.notes,
    this.isActive = true,
  });

  final int companyId;
  final String category;
  final String title;
  final String? host;
  final int? port;
  final String? accessMethod;
  final String? url;
  final String? username;

  /// در ویرایش: خالی = رمز قبلی حفظ می‌شود
  final String? password;
  final bool clearPassword;
  final String? extraSecret;
  final bool clearExtraSecret;
  final String? location;
  final String? notes;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'companyId': companyId,
    'category': category,
    'title': title,
    'host': host,
    'port': port,
    'accessMethod': accessMethod,
    'url': url,
    'username': username,
    'password': password,
    'clearPassword': clearPassword,
    'extraSecret': extraSecret,
    'clearExtraSecret': clearExtraSecret,
    'location': location,
    'notes': notes,
    'isActive': isActive,
  };
}

/// اعتبارسنجی فرم — ترتیب و متن‌های `Save()` وب
String? validateVaultForm(VaultSaveRequest d) {
  if (d.title.trim().isEmpty) {
    return 'عنوان را وارد کنید.';
  }
  if (!kVaultCategories.any((c) => c.key == d.category)) {
    return 'نوع تجهیز نامعتبر است.';
  }
  if (d.companyId <= 0) {
    return 'شرکت را انتخاب کنید.';
  }
  if (d.port != null && (d.port! < 1 || d.port! > 65535)) {
    return 'پورت باید بین ۱ تا ۶۵۵۳۵ باشد.';
  }
  if ((d.password ?? '').length > 1000 || (d.extraSecret ?? '').length > 4000) {
    return 'طول رمز/اطلاعات محرمانه بیش از حد مجاز است.';
  }
  return null;
}

// ============================================================
//  ساخت رمز قوی و سنجش قدرت — عیناً وب
// ============================================================

const _lowerChars = 'abcdefghijkmnopqrstuvwxyz';
const _upperChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const _digitChars = '23456789';
const _symbolChars = '!@#\$%^&*-_=+?';

/// رمز ۱۶ کاراکتری با حداقل یک حرف کوچک/بزرگ/رقم/نماد.
String generateStrongPassword([int seed = -1]) {
  final all = _lowerChars + _upperChars + _digitChars + _symbolChars;
  final rnd = _FastRnd(seed);
  final chars = <String>[
    _lowerChars[rnd.next(_lowerChars.length)],
    _upperChars[rnd.next(_upperChars.length)],
    _digitChars[rnd.next(_digitChars.length)],
    _symbolChars[rnd.next(_symbolChars.length)],
  ];
  while (chars.length < 16) {
    chars.add(all[rnd.next(all.length)]);
  }
  for (var i = chars.length - 1; i > 0; i--) {
    final j = rnd.next(i + 1);
    final t = chars[i];
    chars[i] = chars[j];
    chars[j] = t;
  }
  return chars.join();
}

class _FastRnd {
  _FastRnd(int seed) : _s = seed < 0 ? DateTime.now().microsecondsSinceEpoch : seed;
  int _s;
  int next(int max) {
    _s = (_s * 1103515245 + 12345) & 0x7fffffff;
    return max <= 0 ? 0 : _s % max;
  }
}

/// `Strength()` وب — برچسب و رنگ
(String, int) passwordStrength(String p) {
  var score = 0;
  if (p.length >= 8) score++;
  if (p.length >= 12) score++;
  final hasLower = p.contains(RegExp('[a-z]'));
  final hasUpper = p.contains(RegExp('[A-Z]'));
  final hasDigit = p.contains(RegExp('[0-9]'));
  final hasSymbol = p.contains(RegExp('[^A-Za-z0-9]'));
  if (hasLower && hasUpper) score++;
  if (hasDigit) score++;
  if (hasSymbol) score++;
  if (score <= 2) return ('ضعیف', 0xffdc2626);
  if (score == 3) return ('متوسط', 0xffd97706);
  if (score == 4) return ('خوب', 0xff2563eb);
  return ('قوی', 0xff059669);
}
