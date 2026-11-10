// ============================================================
//  منبع دادهٔ صفحهٔ اصلی
//  همهٔ مسیرها endpoint واقعی بک‌اند (Inventory.Api) هستند.
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

  /// علامت‌گذاری یک اعلان به خوانده‌شده — `POST /api/notifications/{id}/read`
  Future<void> markRead(int id) => _api.post<dynamic>('/api/notifications/$id/read');

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

  /// خواندن همزمان دادهٔ چند ویجت — هرکدام مستقل، خطای یکی بقیه را خراب نمی‌کند.
  Future<Map<String, WidgetData>> fetchWidgets(Iterable<String> keys) async {
    final entries = await Future.wait(
      keys.map((k) async {
        final v = await fetchWidgetData(k);
        return v == null ? null : MapEntry(k, v);
      }),
    );
    return {for (final e in entries) if (e != null) e.key: e.value};
  }

  /// ثبت شرکت فعال کاربر — `PUT /api/company-context/users/{userId}`
  Future<void> setUserCompanies(int userId, List<int> companyIds) => _api.put(
    '/api/company-context/users/$userId',
    {'companyIds': companyIds},
  );
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
        .map((r) => (r['cells'] as List? ?? const [])
            .map((c) => c?.toString() ?? '')
            .toList())
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

/// کارت‌های گزارش روزانه — کلیدها از `WidgetCatalog.cs` سرور.
///
/// ترتیب این فهرست همان ترتیب کارت‌ها در کاروسل است.
List<HomeKpi> buildKpiCards() => const [
  HomeKpi(
    widgetKey: 'fac-sales-today',
    moduleName: 'فروش و فاکتور',
    moduleSubtitle: 'سامانه فروشگاهی',
    icon: Icons.point_of_sale_rounded,
    from: Color(0xff4f7ce8),
    to: Color(0xff2547a8),
    unit: 'میلیون ریال',
    rows: [
      KpiRow('تعداد فاکتور', '۰', hint: 'سند'),
      KpiRow('برترین طرف حساب', '—'),
      KpiRow('زیر نقطه سفارش', '۰', hint: 'قلم'),
    ],
  ),
  HomeKpi(
    widgetKey: 'off-letters-count',
    moduleName: 'دبیرخانه و نامه‌ها',
    moduleSubtitle: 'اتوماسیون اداری',
    icon: Icons.mail_outline_rounded,
    from: Color(0xff2fa8b8),
    to: Color(0xff0d7d8c),
    unit: 'نامه',
    rows: [
      KpiRow('وارده', '۰', hint: 'نامه'),
      KpiRow('صادره', '۰', hint: 'نامه'),
      KpiRow('ارجاع نخوانده', '۰', hint: 'مورد'),
    ],
  ),
  HomeKpi(
    widgetKey: 'wo-open',
    moduleName: 'دستور کار',
    moduleSubtitle: 'پشتیبانی و IT',
    icon: Icons.build_rounded,
    from: Color(0xfff3a33c),
    to: Color(0xffd2691e),
    unit: 'دستور کار باز',
    rows: [
      KpiRow('معوق', '۰', hint: 'مورد'),
      KpiRow('تکمیل‌شده امروز', '۰', hint: 'مورد'),
      KpiRow('در انتظار تأیید', '۰', hint: 'مورد'),
    ],
  ),
  HomeKpi(
    widgetKey: 'trs-receipt-period',
    moduleName: 'خزانه و چک',
    moduleSubtitle: 'مالی',
    icon: Icons.account_balance_rounded,
    from: Color(0xff3fb27f),
    to: Color(0xff1a7f37),
    unit: 'میلیون ریال',
    rows: [
      KpiRow('دریافتی امروز', '۰', hint: 'م.ر'),
      KpiRow('پرداختی امروز', '۰', hint: 'م.ر'),
      KpiRow('چک سررسیدنزدیک', '۰', hint: 'فقره'),
    ],
  ),
  HomeKpi(
    widgetKey: 'fa-att-today',
    moduleName: 'تردد و مرخصی',
    moduleSubtitle: 'منابع انسانی',
    icon: Icons.schedule_rounded,
    from: Color(0xff8b7bff),
    to: Color(0xff5b47d6),
    unit: 'تردد امروز',
    rows: [
      KpiRow('پرسنل فعال', '۰', hint: 'نفر'),
      KpiRow('مرخصی در جریان', '۰', hint: 'درخواست'),
      KpiRow('غیبت ثبت‌شده', '۰', hint: 'مورد'),
    ],
  ),
  HomeKpi(
    widgetKey: 'inv-doc-count',
    moduleName: 'انبار و موجودی',
    moduleSubtitle: 'کاتالوگ',
    icon: Icons.inventory_2_outlined,
    from: Color(0xffe08a4f),
    to: Color(0xffc2410c),
    unit: 'سند انبار',
    rows: [
      KpiRow('ارزش موجودی', '۰', hint: 'م.ر'),
      KpiRow('رسید', '۰', hint: 'سند'),
      KpiRow('حواله', '۰', hint: 'سند'),
    ],
  ),
  HomeKpi(
    widgetKey: 'off-erja-unread',
    moduleName: 'ارجاع‌های من',
    moduleSubtitle: 'کارتابل نامه',
    icon: Icons.forward_to_inbox_rounded,
    from: Color(0xffe05357),
    to: Color(0xffa4262c),
    unit: 'ارجاع نخوانده',
    rows: [
      KpiRow('فوری', '۰', hint: 'مورد'),
      KpiRow('از مهلت گذشته', '۰', hint: 'مورد'),
      KpiRow('در انتظار پاسخ', '۰', hint: 'مورد'),
    ],
  ),
  HomeKpi(
    widgetKey: 'it-open',
    moduleName: 'درخواست‌های IT',
    moduleSubtitle: 'دارایی‌های IT',
    icon: Icons.dns_rounded,
    from: Color(0xff5b8def),
    to: Color(0xff1e3a8a),
    unit: 'درخواست باز',
    rows: [
      KpiRow('تخصیص‌یافته به من', '۰', hint: 'مورد'),
      KpiRow('در انتظار قطعه', '۰', hint: 'مورد'),
      KpiRow('بسته‌شده امروز', '۰', hint: 'مورد'),
    ],
  ),
];

/// کاشی‌های گرید ماژول‌ها — برگرفته از `MODULES.md` و `NavMenu.razor`.
List<ModuleTile> buildModuleTiles({required Set<int> openTabs}) => [
  ModuleTile(
    name: 'دستور کار',
    subtitle: 'پشتیبانی و تعمیر',
    icon: Icons.build_rounded,
    color: const Color(0xffd2691e),
    tabIndex: 1,
  ),
  ModuleTile(
    name: 'اتوماسیون اداری',
    subtitle: 'دبیرخانه و نامه',
    icon: Icons.account_balance_rounded,
    color: const Color(0xff2547a8),
    tabIndex: 2,
  ),
  ModuleTile(
    name: 'پست الکترونیک',
    subtitle: 'ایمیل سازمانی',
    icon: Icons.alternate_email_rounded,
    color: const Color(0xff0e7490),
    tabIndex: 3,
  ),
  ModuleTile(
    // ماژول مستقل «صورتجلسه» — ورود مستقیم به فهرست صورتجلسه‌ها
    name: 'صورتجلسه',
    subtitle: 'مصوبات و امضای جلسات',
    icon: Icons.description_rounded,
    color: const Color(0xff0f766e),
    onTapName: 'minutes',
  ),
  ModuleTile(
    name: 'فرم‌های متفرقه',
    subtitle: 'فرم‌های داخلی سازمان',
    icon: Icons.library_books_rounded,
    color: const Color(0xff0b7285),
    onTapName: 'misc',
  ),
  ModuleTile(
    name: 'فروش',
    subtitle: 'فاکتور و سفارش',
    icon: Icons.point_of_sale_rounded,
    color: const Color(0xff4f7ce8),
    badge: 'به‌زودی',
    onTapName: 'sales',
  ),
  ModuleTile(
    name: 'انبار و موجودی',
    subtitle: 'رسید و حواله',
    icon: Icons.inventory_2_outlined,
    color: const Color(0xffc2410c),
    badge: 'به‌زودی',
    onTapName: 'inventory',
  ),
  ModuleTile(
    name: 'خزانه',
    subtitle: 'چک و اقساط',
    icon: Icons.account_balance_wallet_rounded,
    color: const Color(0xff1a7f37),
    badge: 'به‌زودی',
    onTapName: 'treasury',
  ),
  ModuleTile(
    name: 'منابع انسانی',
    subtitle: 'پرسنل و احکام',
    icon: Icons.groups_rounded,
    color: const Color(0xff5b47d6),
    badge: 'به‌زودی',
    onTapName: 'hr',
  ),
  ModuleTile(
    name: 'تردد و مرخصی',
    subtitle: 'کارتزنی',
    icon: Icons.schedule_rounded,
    color: const Color(0xff7c3aed),
    badge: 'به‌زودی',
    onTapName: 'attendance',
  ),
  ModuleTile(
    name: 'سامانه مودیان',
    subtitle: 'صورتحساب الکترونیک',
    icon: Icons.receipt_long_rounded,
    color: const Color(0xffd13438),
    badge: 'به‌زودی',
    onTapName: 'moadian',
  ),
  ModuleTile(
    name: 'دارایی‌های IT',
    subtitle: 'سیستم و شبکه',
    icon: Icons.dns_rounded,
    color: const Color(0xff1e3a8a),
    badge: 'به‌زودی',
    onTapName: 'it-assets',
  ),
  ModuleTile(
    name: 'دوربین مداربسته',
    subtitle: 'دوربین و NVR',
    icon: Icons.videocam_rounded,
    color: const Color(0xff0d7d8c),
    badge: 'به‌زودی',
    onTapName: 'cctv',
  ),
  ModuleTile(
    name: 'آرشیو اسناد',
    subtitle: 'پوشه و مدارک',
    icon: Icons.folder_special_rounded,
    color: const Color(0xff6b7a90),
    badge: 'به‌زودی',
    onTapName: 'archive',
  ),
  ModuleTile(
    name: 'گزارش‌ساز',
    subtitle: 'گزارش دلخواه',
    icon: Icons.insights_rounded,
    color: const Color(0xff2a6bd4),
    badge: 'به‌زودی',
    onTapName: 'reports',
  ),
  ModuleTile(
    name: 'پروژه‌ها',
    subtitle: 'کارفرما و گزارش',
    icon: Icons.layers_rounded,
    color: const Color(0xff1a7f37),
    badge: 'به‌زودی',
    onTapName: 'projects',
  ),
];
