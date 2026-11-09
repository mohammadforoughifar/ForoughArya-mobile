// ============================================================
//  مدل‌های صفحهٔ اصلی
//  ساختار داده‌ها مستقیماً از پاسخ‌های واقعی API گرفته شده است:
//    • CompanyContext  ← GET  /api/company-context
//    • NotificationItem ← GET  /api/notifications
//    • WidgetData      ← GET  /api/my-dashboards/widget-data/{key}
// ============================================================

import 'package:flutter/material.dart';

/// یک شرکت مجاز برای کاربر (از `UserCompanyAccess` در سرور).
class CompanyOption {
  const CompanyOption({
    required this.id,
    required this.name,
    this.code,
    this.phone,
    this.isActive = true,
  });

  final int id;
  final String name;
  final String? code;
  final String? phone;
  final bool isActive;

  /// دو حرف اول نام برای ساخت نشان اختصاری (avatar).
  String get initials {
    final parts = name
        .replaceAll(RegExp(r'(شرکت|سهامی|خاص|عام|موسسه|مؤسسه)'), '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '؟';
    if (parts.length == 1) {
      final w = parts.first;
      return w.length <= 2 ? w : w.substring(0, 2);
    }
    return '${parts[0].characters.first}${parts[1].characters.first}';
  }

  factory CompanyOption.fromJson(Map<String, dynamic> j) => CompanyOption(
    id: (j['id'] as num?)?.toInt() ?? 0,
    name: j['name']?.toString() ?? '—',
    code: j['code']?.toString(),
    phone: j['phone']?.toString(),
    isActive: j['isActive'] != false,
  );
}

/// پاسخ `GET /api/company-context` — فهرست شرکت‌ها + شرکت فعال فعلی.
class CompanyContext {
  const CompanyContext({required this.companies, this.activeCompanyId});

  final List<CompanyOption> companies;
  final int? activeCompanyId;

  CompanyOption? get active {
    for (final c in companies) {
      if (c.id == activeCompanyId) return c;
    }
    return null;
  }

  int get activeCount => companies.where((c) => c.isActive).length;

  static CompanyContext fromJson(Map<String, dynamic> j) => CompanyContext(
    activeCompanyId: (j['activeCompanyId'] as num?)?.toInt(),
    companies: (j['companies'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => CompanyOption.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );

  static const empty = CompanyContext(companies: []);
}

/// یک اعلان (از `AppNotifications`).
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    this.body,
    this.fromName,
    this.formName,
    this.link,
    this.isRead = false,
    this.createdAt,
  });

  final int id;
  final String title;
  final String? body;
  final String? fromName;
  final String? formName;
  final String? link;
  final bool isRead;
  final DateTime? createdAt;

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
    id: (j['id'] as num?)?.toInt() ?? 0,
    title: j['title']?.toString() ?? '',
    body: j['body']?.toString(),
    fromName: j['fromName']?.toString(),
    formName: j['formName']?.toString(),
    link: j['link']?.toString(),
    isRead: j['isRead'] == true,
    createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
  );
}

/// یک ردیف ریز داخل کارت گزارش روزانه.
class KpiRow {
  const KpiRow(this.label, this.value, {this.hint});
  final String label;
  final String value;
  final String? hint;
}

/// یک کارت «گزارش روزانه» — یک ماژول با شمارش امروز.
///
/// کلید [widgetKey] همان کلید ویجت در `WidgetCatalog.cs` سرور است
/// (مثل `fac-sales-today`) تا دادهٔ واقعی از همان endpoint خوانده شود.
class HomeKpi {
  const HomeKpi({
    required this.widgetKey,
    required this.moduleName,
    required this.moduleSubtitle,
    required this.icon,
    required this.from,
    required this.to,
    required this.unit,
    required this.rows,
    this.spark = const [],
    this.value = 0,
    this.deltaPercent,
  });

  final String widgetKey;
  final String moduleName;
  final String moduleSubtitle;
  final IconData icon;
  final Color from;
  final Color to;
  final String unit;
  final List<KpiRow> rows;
  final List<double> spark;
  final double value;
  final double? deltaPercent;

  LinearGradient get gradient => LinearGradient(
    colors: [from, to],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  HomeKpi copyWith({double? value, double? deltaPercent, List<double>? spark}) =>
      HomeKpi(
        widgetKey: widgetKey,
        moduleName: moduleName,
        moduleSubtitle: moduleSubtitle,
        icon: icon,
        from: from,
        to: to,
        unit: unit,
        rows: rows,
        spark: spark ?? this.spark,
        value: value ?? this.value,
        deltaPercent: deltaPercent ?? this.deltaPercent,
      );
}

/// یک کاشی در گرید ماژول‌ها.
class ModuleTile {
  const ModuleTile({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.badge,
    this.locked = false,
    this.tabIndex,
    this.onTapName,
  });

  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? badge;

  /// کاربر مجوز این ماژول را ندارد — فقط نمایش، بدون ورود.
  final bool locked;

  /// اگر مقدار داشته باشد، با زدن روی کاشی به همان تب در پوسته می‌رویم.
  final int? tabIndex;

  /// کلید ناوبری برای ماژول‌هایی که صفحهٔ مستقل دارند.
  final String? onTapName;
}
