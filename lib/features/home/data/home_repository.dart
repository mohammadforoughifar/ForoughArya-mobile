// ============================================================
//  منبع دادهٔ صفحهٔ اصلی و «میز کار حرفه‌ای»
//  همهٔ مسیرها endpoint واقعی بک‌اند (Inventory.Api) هستند
//  و نام‌های نمایشی ماژول‌ها ۱۰۰٪ با نسخهٔ وب هم‌تراز شده‌اند:
//    • اتوماسیون اداری توکا
//    • دستورکار رایکا
//    • فروشگاهی کایر
//    • پیام رسان میها
//    • ERP فیکا
//    • مودیان تیسا
//    • مدیریت سیستم / آرشیو اسناد و مدارک / کارتابل آرشیو / صورتجلسه
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../models/home_models.dart';

/// نتیجهٔ بارگذاری صفحهٔ اصلی.
class HomeData {
  const HomeData({
    required this.companies,
    required this.unreadCount,
    this.error,
  });

  final CompanyContext companies;
  final int unreadCount;
  final String? error;

  bool get hasError => error != null;
}

class HomeRepository {
  HomeRepository(this._api);

  final ApiClient _api;

  /// فهرست شرکت‌های مجاز کاربر + شرکت فعال.
  /// `GET /api/company-context`
  Future<CompanyContext> fetchCompanies() async {
    final r = await _api.get<dynamic>('/api/company-context');
    final d = r.data;
    if (d is Map) {
      return CompanyContext.fromJson(Map<String, dynamic>.from(d));
    }
    return CompanyContext.empty;
  }

  /// تعداد اعلان‌های خوانده‌نشده — `GET /api/notifications/unread-count`
  Future<int> fetchUnreadCount() async {
    final r = await _api.get<dynamic>('/api/notifications/unread-count');
    final d = r.data;
    if (d is Map) return (d['count'] as num?)?.toInt() ?? 0;
    return 0;
  }

  /// فهرست اعلان‌ها — `GET /api/notifications`
  Future<List<NotificationItem>> fetchNotifications({int take = 50}) async {
    final r = await _api.get<dynamic>(
      '/api/notifications',
      query: {'take': take, 'skip': 0},
    );
    final d = r.data;
    if (d is! List) return const [];
    return d
        .whereType<Map>()
        .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// صفحهٔ دسته‌بندی‌شدهٔ اعلان‌های کارتابل (`main` = اقدامات اصلی | `sub` = پیگیری‌ها)
  /// مطابق `Cartable.razor` در وب (`GET /api/notifications/page`) با fallback خودکار.
  Future<NotificationPageResult> fetchNotificationPage({
    int take = 8,
    int skip = 0,
    String category = 'main',
    bool unreadOnly = false,
  }) async {
    try {
      final r = await _api.get<dynamic>(
        '/api/notifications/page',
        query: {
          'take': take,
          'skip': skip,
          'category': category,
          if (unreadOnly) 'unreadOnly': true,
        },
      );
      final d = r.data;
      if (d is Map) {
        return NotificationPageResult.fromJson(Map<String, dynamic>.from(d));
      }
    } catch (_) {
      // سرور قدیمی‌تر بدون /page — از فهرست استاندارد تفکیک می‌کنیم
    }
    try {
      final all = await fetchNotifications(take: 60);
      final mains = all.where((n) => !n.isFollowUp).toList();
      final subs = all.where((n) => n.isFollowUp).toList();
      final source = category == 'sub' ? subs : mains;
      final filtered = unreadOnly
          ? source.where((n) => !n.isRead).toList()
          : source;
      final sliced = filtered.skip(skip).take(take).toList();
      return NotificationPageResult(
        items: sliced,
        total: all.length,
        unread: all.where((n) => !n.isRead).length,
        filteredTotal: filtered.length,
        mainTotal: mains.length,
        mainUnread: mains.where((n) => !n.isRead).length,
        subTotal: subs.length,
        subUnread: subs.where((n) => !n.isRead).length,
        hasMore: skip + sliced.length < filtered.length,
      );
    } catch (_) {
      return const NotificationPageResult();
    }
  }

  /// کارتابل یکپارچهٔ سرور — `GET /api/cartable/me`
  Future<List<CartableEntry>> fetchUnifiedCartable() async {
    try {
      final r = await _api.get<dynamic>('/api/cartable/me');
      final d = r.data;
      if (d is Map) {
        final raw = (d['items'] ?? d['Items']) as List? ?? const [];
        return raw
            .whereType<Map>()
            .map(
              (e) => CartableEntry.fromServerJson(Map<String, dynamic>.from(e)),
            )
            .where((e) => e.title.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  /// علامت‌گذاری یک اعلان به خوانده‌شده — `POST /api/notifications/{id}/read`
  Future<void> markRead(int id) =>
      _api.post<dynamic>('/api/notifications/$id/read');

  /// پاک کردن یک اعلان — چند مسیر رایج بک‌اند امتحان می‌شود.
  Future<void> deleteNotification(int id) async {
    final attempts = <Future<void> Function()>[
      () => _api.delete<dynamic>('/api/notifications/$id'),
      () => _api.post<dynamic>('/api/notifications/$id/delete'),
      () => _api.post<dynamic>('/api/notifications/delete/$id'),
    ];
    Object? last;
    for (final a in attempts) {
      try {
        await a();
        return;
      } catch (e) {
        last = e;
      }
    }
    throw last ?? Exception('اعلان پاک نشد.');
  }

  /// حذف اعلان‌های کاربر در شرکت فعال و اعلان‌های عمومی.
  Future<void> clearNotifications() async {
    await _api.delete<dynamic>('/api/notifications/clear-all');
  }

  /// دادهٔ یک ویجت داشبورد — `GET /api/my-dashboards/widget-data/{key}`
  ///
  /// [range] مطابق enum `DashRange` سرور: ۰=امروز، ۱=هفته، ۲=ماه.
  Future<WidgetData?> fetchWidgetData(String key, {int range = 0}) async {
    try {
      final r = await _api.get<dynamic>(
        '/api/my-dashboards/widget-data/$key',
        query: {'range': range},
      );
      final d = r.data;
      if (d is! Map) return null;
      return WidgetData.fromJson(Map<String, dynamic>.from(d));
    } on ApiException {
      // نبود مجوز برای یک ویجت نباید کل صفحهٔ اصلی را از کار بیندازد.
      return null;
    }
  }

  /// خواندن همزمان دادهٔ چند ویجت در بازهٔ انتخابی (`۰=امروز · ۱=هفته · ۲=ماه`).
  Future<Map<String, WidgetData>> fetchWidgets(
    Iterable<String> keys, {
    int range = 0,
  }) async {
    final entries = await Future.wait(
      keys.map((k) async {
        final v = await fetchWidgetData(k, range: range);
        return v == null ? null : MapEntry(k, v);
      }),
    );
    return {for (final e in entries) if (e != null) e.key: e.value};
  }

  /// ثبت شرکت فعال کاربر — `PUT /api/company-context/users/{userId}`
  Future<void> setUserCompanies(int userId, List<int> companyIds) =>
      _api.put('/api/company-context/users/$userId', {'companyIds': companyIds});
}

/// پاسخ `WidgetDataDto` سرور.
class WidgetData {
  const WidgetData({
    required this.key,
    this.title,
    this.value,
    this.unit,
    this.deltaText,
    this.deltaUp,
    this.subValue,
    this.subLabel,
    this.rows = const [],
    this.error,
    this.series = const [],
  });

  final String key;
  final String? title;
  final double? value;
  final String? unit;
  final String? deltaText;
  final bool? deltaUp;
  final double? subValue;
  final String? subLabel;
  final List<List<String>> rows;
  final String? error;

  /// سری اول نمودار — برای sparkline کارت استفاده می‌شود.
  final List<double> series;

  factory WidgetData.fromJson(Map<String, dynamic> j) => WidgetData(
    key: j['key']?.toString() ?? '',
    title: j['title']?.toString(),
    value: (j['value'] as num?)?.toDouble(),
    unit: j['unit']?.toString(),
    deltaText: j['deltaText']?.toString(),
    deltaUp: j['deltaUp'] as bool?,
    subValue: (j['subValue'] as num?)?.toDouble(),
    subLabel: j['subLabel']?.toString(),
    error: j['error']?.toString(),
    rows: (j['rows'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (r) => (r['cells'] as List? ?? const [])
              .map((c) => c?.toString() ?? '')
              .toList(),
        )
        .toList(),
    series: ((j['series'] as List? ?? const [])
                .whereType<Map>()
                .firstOrNull?['values'] as List? ??
            const [])
        .whereType<num>()
        .map((e) => e.toDouble())
        .toList(),
  );
}

/// کارت‌های شاخص کلیدی عملکرد — کلیدها از `WidgetCatalog.cs` سرور و نام‌ها هم‌تراز با وب.
List<HomeKpi> buildKpiCards() => const [
  HomeKpi(
    widgetKey: 'fac-sales-today',
    moduleName: 'فروش و فاکتور',
    moduleSubtitle: 'فروشگاهی کایر',
    targetKey: 'shop-ops',
    icon: Icons.point_of_sale_rounded,
    from: Color(0xff3b82f6),
    to: Color(0xff1d4ed8),
    unit: 'میلیون ریال',
    rows: [
      KpiRow('فاکتور فروش', '۰', hint: 'سند'),
      KpiRow('فاکتور خرید', '۰', hint: 'سند'),
      KpiRow('زیر نقطه سفارش', '۰', hint: 'قلم'),
    ],
  ),
  HomeKpi(
    widgetKey: 'off-letters-count',
    moduleName: 'دبیرخانه و نامه‌ها',
    moduleSubtitle: 'اتوماسیون اداری توکا',
    targetKey: 'tab-2',
    icon: Icons.mark_email_unread_rounded,
    from: Color(0xff14b8a6),
    to: Color(0xff0f766e),
    unit: 'نامه',
    rows: [
      KpiRow('وارده', '۰', hint: 'نامه'),
      KpiRow('صادره', '۰', hint: 'نامه'),
      KpiRow('ارجاع نخوانده', '۰', hint: 'مورد'),
    ],
  ),
  HomeKpi(
    widgetKey: 'wo-open',
    moduleName: 'دستورکار رایکا',
    moduleSubtitle: 'پیگیری، مهلت و عملکرد',
    targetKey: 'tab-1',
    icon: Icons.assignment_turned_in_rounded,
    from: Color(0xfff59e0b),
    to: Color(0xffd97706),
    unit: 'دستور کار باز',
    rows: [
      KpiRow('معوق', '۰', hint: 'مورد'),
      KpiRow('انجام‌شده', '۰', hint: 'مورد'),
      KpiRow('محول به من', '۰', hint: 'مورد'),
    ],
  ),
  HomeKpi(
    widgetKey: 'trs-receipt-period',
    moduleName: 'خزانه و چک',
    moduleSubtitle: 'فروشگاهی کایر • مالی',
    targetKey: 'shop-trs',
    icon: Icons.account_balance_wallet_rounded,
    from: Color(0xff10b981),
    to: Color(0xff047857),
    unit: 'میلیون ریال',
    rows: [
      KpiRow('دریافت دوره', '۰', hint: 'م.ر'),
      KpiRow('پرداخت دوره', '۰', hint: 'م.ر'),
      KpiRow('چک سررسیدشده', '۰', hint: 'فقره'),
    ],
  ),
  HomeKpi(
    widgetKey: 'off-erja-unread',
    moduleName: 'ارجاع‌های من',
    moduleSubtitle: 'اتوماسیون اداری توکا',
    targetKey: 'tab-2',
    icon: Icons.forward_to_inbox_rounded,
    from: Color(0xffef4444),
    to: Color(0xffb91c1c),
    unit: 'ارجاع نخوانده',
    rows: [
      KpiRow('پیش‌نویس', '۰', hint: 'نامه'),
      KpiRow('در انتظار امضا', '۰', hint: 'نامه'),
      KpiRow('صف دبیرخانه', '۰', hint: 'نامه'),
    ],
  ),
  HomeKpi(
    widgetKey: 'it-open',
    moduleName: 'درخواست خدمت IT',
    moduleSubtitle: 'مدیریت سیستم',
    targetKey: 'it-requests',
    icon: Icons.support_agent_rounded,
    from: Color(0xff6366f1),
    to: Color(0xff4338ca),
    unit: 'درخواست باز',
    rows: [
      KpiRow('درخواست‌های من', '۰', hint: 'مورد'),
      KpiRow('کارتابل کارشناس', '۰', hint: 'مورد'),
      KpiRow('منتظر تصمیم', '۰', hint: 'مورد'),
    ],
  ),
  HomeKpi(
    widgetKey: 'inv-doc-count',
    moduleName: 'انبار و موجودی',
    moduleSubtitle: 'ERP فیکا • انبارداری',
    targetKey: 'shop-stock',
    icon: Icons.inventory_2_rounded,
    from: Color(0xfff97316),
    to: Color(0xffc2410c),
    unit: 'سند / قلم',
    rows: [
      KpiRow('اقلام زیر نقطه سفارش', '۰', hint: 'قلم'),
      KpiRow('رسید انبار', '۰', hint: 'سند'),
      KpiRow('حواله انبار', '۰', hint: 'سند'),
    ],
  ),
  HomeKpi(
    widgetKey: 'fa-att-today',
    moduleName: 'تردد و مرخصی',
    moduleSubtitle: 'منابع انسانی فروغ آریا',
    targetKey: '',
    icon: Icons.schedule_rounded,
    from: Color(0xff8b5cf6),
    to: Color(0xff6d28d9),
    unit: 'تردد امروز',
    rows: [
      KpiRow('پرسنل فعال', '۰', hint: 'نفر'),
      KpiRow('مرخصی در جریان', '۰', hint: 'درخواست'),
      KpiRow('غیبت ثبت‌شده', '۰', hint: 'مورد'),
    ],
  ),
];

/// کاشی‌های گرید ماژول‌ها — ۱۰۰٪ هم‌تراز با نام‌های مصوب نسخهٔ وب (`MODULE-BRANDING-FA.md` و `NavMenu.razor`).
List<ModuleTile> buildModuleTiles({required Set<int> openTabs}) => [
  ModuleTile(
    id: 'letters',
    name: 'اتوماسیون اداری توکا',
    subtitle: 'نامه‌های داخلی، وارده، صادره و دبیرخانه',
    icon: Icons.mark_email_read_rounded,
    color: const Color(0xff2547a8),
    gradientEnd: const Color(0xff1e3a8a),
    category: 'office',
    keywords: const [
      'اتوماسیون',
      'توکا',
      'نامه',
      'دبیرخانه',
      'کارتابل',
      'ارجاع',
      'وارده',
      'صادره',
    ],
    tabIndex: 2,
  ),
  ModuleTile(
    id: 'workorders',
    name: 'دستورکار رایکا',
    subtitle: 'دستورهای کار، تقویم، کانبان و عملکرد',
    icon: Icons.assignment_turned_in_rounded,
    color: const Color(0xffd97706),
    gradientEnd: const Color(0xffb45309),
    category: 'tech',
    keywords: const [
      'دستور کار',
      'دستورکار',
      'رایکا',
      'وظیفه',
      'پشتیبانی',
      'تقویم',
      'کانبان',
    ],
    tabIndex: 1,
  ),
  ModuleTile(
    id: 'shop',
    name: 'فروشگاهی کایر',
    subtitle: 'خرید، فروش، خزانه‌داری، انبار و ویزیتوری',
    icon: Icons.storefront_rounded,
    color: const Color(0xff2563eb),
    gradientEnd: const Color(0xff1d4ed8),
    category: 'commerce',
    keywords: const [
      'فروشگاه',
      'کایر',
      'فاکتور',
      'خرید',
      'فروش',
      'چک',
      'انبار',
      'خزانه',
      'تعمیرات',
      'ویزیتور',
    ],
    onTapName: 'sales',
  ),
  ModuleTile(
    id: 'chat',
    name: 'پیام رسان میها',
    subtitle: 'گفت‌وگوی سازمانی، فایل و پیام صوتی',
    icon: Icons.forum_rounded,
    color: const Color(0xff0d9488),
    gradientEnd: const Color(0xff0f766e),
    category: 'office',
    keywords: const ['پیام رسان', 'پیام‌رسان', 'میها', 'چت', 'گفتگو', 'صوتی'],
    tabIndex: 4,
  ),
  ModuleTile(
    id: 'email',
    name: 'ایمیل سازمانی',
    subtitle: 'صندوق پست الکترونیکی سازمانی و شخصی',
    icon: Icons.alternate_email_rounded,
    color: const Color(0xff0284c7),
    gradientEnd: const Color(0xff0369a1),
    category: 'office',
    keywords: const ['ایمیل', 'پست الکترونیکی', 'mail', 'email'],
    tabIndex: 3,
  ),
  ModuleTile(
    id: 'minutes',
    name: 'صورتجلسه',
    subtitle: 'فرم‌های متفرقه، مصوبات و امضای جلسات',
    icon: Icons.description_rounded,
    color: const Color(0xff059669),
    gradientEnd: const Color(0xff047857),
    category: 'office',
    keywords: const ['صورتجلسه', 'جلسه', 'مصوبات', 'فرم‌های متفرقه', 'امضا'],
    onTapName: 'minutes',
  ),
  ModuleTile(
    id: 'it-assets',
    name: 'مدیریت سیستم',
    subtitle: 'سخت‌افزار، سرورها، شبکه، دوربین و IT',
    icon: Icons.dns_rounded,
    color: const Color(0xff4f46e5),
    gradientEnd: const Color(0xff3730a3),
    category: 'tech',
    keywords: const [
      'مدیریت سیستم',
      'مدیریت سخت‌افزار',
      'سخت افزار',
      'سرور',
      'شبکه',
      'دوربین',
      'آی‌پی',
      'گاوصندوق',
      'IT',
    ],
    onTapName: 'it-assets',
  ),
  ModuleTile(
    id: 'doc-archive',
    name: 'آرشیو اسناد و مدارک',
    subtitle: 'پوشه‌ها، نسخه‌بندی، تگ و جستجوی هوشمند',
    icon: Icons.folder_special_rounded,
    color: const Color(0xff3b82f6),
    gradientEnd: const Color(0xff1d4ed8),
    category: 'office',
    keywords: const ['آرشیو', 'اسناد', 'مدارک', 'پوشه', 'بایگانی'],
    onTapName: 'doc-archive',
  ),
  ModuleTile(
    id: 'doc-cartable',
    name: 'کارتابل آرشیو',
    subtitle: 'تأیید، بازبینی و گردش مدارک سازمانی',
    icon: Icons.move_to_inbox_rounded,
    color: const Color(0xffea580c),
    gradientEnd: const Color(0xffc2410c),
    category: 'office',
    keywords: const ['کارتابل آرشیو', 'گردش مدرک', 'تایید مدرک'],
    onTapName: 'doc-archive-cartable',
  ),
  ModuleTile(
    id: 'erp',
    name: 'ERP فیکا',
    subtitle: 'حسابداری، انبارداری، خزانه و انبارگردانی',
    icon: Icons.layers_rounded,
    color: const Color(0xff0891b2),
    gradientEnd: const Color(0xff0e7490),
    category: 'commerce',
    keywords: const ['ERP', 'فیکا', 'حسابداری', 'انبارداری', 'دفتر کل', 'سند'],
    badge: 'نسخه وب',
    onTapName: 'erp',
  ),
  ModuleTile(
    id: 'moadian',
    name: 'مودیان تیسا',
    subtitle: 'صورتحساب الکترونیکی و کارپوشه مالیاتی',
    icon: Icons.receipt_long_rounded,
    color: const Color(0xffdc2626),
    gradientEnd: const Color(0xffb91c1c),
    category: 'commerce',
    keywords: const ['مودیان', 'تیسا', 'مالیات', 'صورتحساب الکترونیکی'],
    badge: 'به‌زودی',
    onTapName: 'moadian',
  ),
  ModuleTile(
    id: 'hr-main',
    name: 'منابع انسانی اصلی',
    subtitle: 'ساختار سازمانی، احکام، قراردادها و حقوق',
    icon: Icons.badge_rounded,
    color: const Color(0xff7c3aed),
    gradientEnd: const Color(0xff5b21b6),
    category: 'hr',
    keywords: const ['منابع انسانی اصلی', 'پرسنل', 'احکام', 'حقوق', 'قرارداد'],
    badge: 'به‌زودی',
    onTapName: 'hr-main',
  ),
  ModuleTile(
    id: 'hr-forough',
    name: 'منابع انسانی فروغ آریا',
    subtitle: 'حضور و غیاب، تردد، مرخصی و مأموریت',
    icon: Icons.groups_rounded,
    color: const Color(0xff6366f1),
    gradientEnd: const Color(0xff4338ca),
    category: 'hr',
    keywords: const ['منابع انسانی فروغ آریا', 'تردد', 'مرخصی', 'حضور و غیاب'],
    badge: 'به‌زودی',
    onTapName: 'hr-forough',
  ),
  ModuleTile(
    id: 'hr-bonsaze',
    name: 'منابع انسانی بن‌سازه',
    subtitle: 'پرسنل، تولید روزانه، دستمزد و HSE',
    icon: Icons.groups_2_rounded,
    color: const Color(0xff9333ea),
    gradientEnd: const Color(0xff6b21a8),
    category: 'hr',
    keywords: const ['منابع انسانی بن‌سازه', 'بن سازه', 'HSE', 'دستمزد'],
    badge: 'به‌زودی',
    onTapName: 'hr-bonsaze',
  ),
];
