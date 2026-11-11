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
/// استخراج شناسهٔ رکورد مقصد از کلیدهای مستقیم یا از انتهای `link`.
int? parseEntityId(Map<String, dynamic> j) {
  for (final k in const [
    'entityId',
    'EntityId',
    'workOrderId',
    'WorkOrderId',
    'minutesId',
    'MinutesId',
    'meetingMinutesId',
    'letterId',
    'LetterId',
    'innerLetterId',
    'outgoingLetterId',
    'incomingLetterId',
    'erjaId',
    'ErjaId',
    'messageId',
    'referenceId',
    'refId',
    'objectId',
  ]) {
    final v = j[k];
    if (v is num) return v.toInt();
    if (v is String) {
      final n = int.tryParse(v);
      if (n != null) return n;
    }
  }
  // از link: /workorders/123 ، /minutes/45 ، /letters/9 یا ?id=7
  final link = (j['link'] ?? j['Link'] ?? j['url'] ?? '').toString();
  if (link.isEmpty) return null;
  // erjaId از letterId مهم‌تر است (ارجاع، رکورد دقیق‌تری است)
  final q = RegExp(r'[?&](?:erjaId|ErjaId|erja)=(\d+)').firstMatch(link) ??
      RegExp(r'[?&](?:id|Id|ID)=(\d+)').firstMatch(link);
  if (q != null) return int.tryParse(q.group(1)!);
  final seg = link.split('/').where((e) => e.isNotEmpty).toList();
  for (final s in seg.reversed) {
    final n = int.tryParse(s.split('?').first);
    if (n != null) return n;
  }
  return null;
}

/// تعیین نوع مقصد از فیلدهای صریح یا از متن/link اعلان.
String? parseEntityKind(Map<String, dynamic> j) {
  final explicit = (j['entityKind'] ?? j['EntityKind'] ?? j['kindName'] ?? '')
      .toString()
      .toLowerCase();
  if (explicit.isNotEmpty) {
    if (explicit.contains('work')) return 'wo';
    if (explicit.contains('minute')) return 'minutes';
    if (explicit.contains('letter')) return 'letter';
    if (explicit.contains('mail') || explicit.contains('email')) return 'email';
  }
  final hay = [
    j['title'],
    j['body'],
    j['formName'],
    j['link'],
  ].map((e) => e?.toString() ?? '').join(' ').toLowerCase();
  if (hay.contains('workorder') || hay.contains('work-order') ||
      hay.contains('دستور کار') || hay.contains('دستورکار')) {
    return 'wo';
  }
  if (hay.contains('minute') || hay.contains('صورت‌جلسه') ||
      hay.contains('صورتجلسه') || hay.contains('meeting')) {
    return 'minutes';
  }
  if (hay.contains('letter') || hay.contains('نامه') || hay.contains('ارجاع') ||
      hay.contains('کارتابل')) {
    return 'letter';
  }
  if (hay.contains('mail') || hay.contains('email') || hay.contains('ایمیل')) {
    return 'email';
  }
  return null;
}

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
    this.entityId,
    this.entityKind,
  });

  final int id;
  final String title;
  final String? body;
  final String? fromName;
  final String? formName;
  final String? link;
  final bool isRead;
  final DateTime? createdAt;

  /// شناسهٔ رکورد مقصد (دستور کار / صورت‌جلسه / نامه) — از سرور یا از link
  final int? entityId;

  /// نوع مقصد: wo | minutes | letter | email | null
  final String? entityKind;

  /// مسیر وب اعلان — برای استخراج شناسه وقتی فیلد مستقیم نیامده
  String? get targetLink => link;

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
    id: (j['id'] as num?)?.toInt() ?? 0,
    title: j['title']?.toString() ?? '',
    body: j['body']?.toString(),
    fromName: j['fromName']?.toString(),
    formName: j['formName']?.toString(),
    link: j['link']?.toString(),
    isRead: j['isRead'] == true,
    createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
    entityId: parseEntityId(j),
    entityKind: parseEntityKind(j),
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
