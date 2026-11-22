// ============================================================
//  مدل‌های صفحهٔ اصلی و «میز کار حرفه‌ای»
//  ساختار داده‌ها مستقیماً از پاسخ‌های واقعی API گرفته شده است:
//    • CompanyContext        ← GET  /api/company-context
//    • CartableEntry         ← GET  /api/cartable/me (+ تجمیع ماژول‌ها)
//    • NotificationPageResult← GET  /api/notifications/page
//    • NotificationItem      ← GET  /api/notifications
//    • WidgetData            ← GET  /api/my-dashboards/widget-data/{key}
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/utils/html_text.dart';

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

/// یک آیتم در «کارتابل یکپارچه و میز اقدام» (آینهٔ `CartableItemDto` وب + منابع زنده).
class CartableEntry {
  const CartableEntry({
    required this.source,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.moduleLabel = '',
    this.link = '',
    this.targetKey = '',
    this.badgeCount,
    this.actionable = true,
    this.priority = 1,
    this.dueAt,
  });

  final String source;
  final String kind;
  final String title;
  final String subtitle;
  final String moduleLabel;
  final String link;
  final String targetKey;
  final IconData icon;
  final Color color;
  final int? badgeCount;
  final bool actionable;

  /// ۰ عادی · ۱ مهم · ۲ فوری
  final int priority;
  final DateTime? dueAt;

  static Color _parseHex(String? hex, Color fallback) {
    final clean = (hex ?? '').trim().replaceAll('#', '');
    if (clean.length == 6) {
      final v = int.tryParse('FF$clean', radix: 16);
      if (v != null) return Color(v);
    }
    return fallback;
  }

  static IconData _mapBootstrapIcon(String? bi) {
    final s = (bi ?? '').toLowerCase();
    if (s.contains('exclamation') || s.contains('warning')) {
      return Icons.warning_amber_rounded;
    }
    if (s.contains('patch-check') || s.contains('check')) {
      return Icons.verified_outlined;
    }
    if (s.contains('receipt') || s.contains('cash')) {
      return Icons.receipt_long_rounded;
    }
    if (s.contains('cart') || s.contains('bag')) {
      return Icons.shopping_bag_outlined;
    }
    if (s.contains('arrow-return')) {
      return Icons.assignment_return_outlined;
    }
    if (s.contains('pencil')) {
      return Icons.edit_note_rounded;
    }
    if (s.contains('envelope') || s.contains('mail')) {
      return Icons.mark_email_unread_outlined;
    }
    if (s.contains('tools') || s.contains('headset')) {
      return Icons.support_agent_rounded;
    }
    return Icons.bolt_rounded;
  }

  static int _parsePriority(dynamic p) {
    if (p is num) return p.toInt();
    final s = (p ?? '').toString().toLowerCase();
    if (s.contains('urgent') || s.contains('critical')) return 3;
    if (s.contains('high')) return 2;
    return 1;
  }

  factory CartableEntry.fromServerJson(Map<String, dynamic> j) {
    T? pick<T>(String a, String b) => (j[a] ?? j[b]) as T?;
    final link = (pick<String>('link', 'Link') ?? '').trim();
    final source = (pick<String>('source', 'Source') ?? 'cartable').trim();
    final kind = (pick<String>('kind', 'Kind') ?? '').trim();
    String targetKey = '';
    if (link.contains('sales/approvals')) {
      targetKey = 'vis-approvals';
    } else if (link.contains('sales/finance-queue')) {
      targetKey = 'vis-finance';
    } else if (link.contains('sales/visits')) {
      targetKey = 'vis-orders';
    } else if (link.contains('orders/sale')) {
      targetKey = 'sale-orders';
    }
    return CartableEntry(
      source: source,
      kind: kind,
      title: (pick<String>('title', 'Title') ?? '').trim(),
      subtitle: (pick<String>('subtitle', 'Subtitle') ?? '').trim(),
      moduleLabel: source == 'sales-visit' ? 'فروشگاهی کایر' : 'کارتابل یکپارچه',
      link: link,
      targetKey: targetKey,
      icon: _mapBootstrapIcon(pick<String>('icon', 'Icon')),
      color: _parseHex(
        pick<String>('color', 'Color'),
        const Color(0xff2547a8),
      ),
      badgeCount:
          (j['badgeCount'] as num?)?.toInt() ??
          (j['BadgeCount'] as num?)?.toInt(),
      actionable: (j['actionable'] ?? j['Actionable']) != false,
      priority: _parsePriority(j['priority'] ?? j['Priority']),
      dueAt: DateTime.tryParse(
        (pick<String>('dueAt', 'DueAt') ?? '').toString(),
      )?.toLocal(),
    );
  }
}

/// پاسخ صفحه‌بندی‌شدهٔ اعلان‌های کارتابل (`GET /api/notifications/page`).
class NotificationPageResult {
  const NotificationPageResult({
    this.items = const [],
    this.total = 0,
    this.unread = 0,
    this.filteredTotal = 0,
    this.mainTotal = 0,
    this.mainUnread = 0,
    this.subTotal = 0,
    this.subUnread = 0,
    this.hasMore = false,
  });

  final List<NotificationItem> items;
  final int total;
  final int unread;
  final int filteredTotal;
  final int mainTotal;
  final int mainUnread;
  final int subTotal;
  final int subUnread;
  final bool hasMore;

  factory NotificationPageResult.fromJson(Map<String, dynamic> j) {
    int numOf(String a, String b) =>
        (j[a] as num?)?.toInt() ?? (j[b] as num?)?.toInt() ?? 0;
    final raw = (j['items'] ?? j['Items']) as List? ?? const [];
    return NotificationPageResult(
      items: raw
          .whereType<Map>()
          .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      total: numOf('total', 'Total'),
      unread: numOf('unread', 'Unread'),
      filteredTotal: numOf('filteredTotal', 'FilteredTotal'),
      mainTotal: numOf('mainTotal', 'MainTotal'),
      mainUnread: numOf('mainUnread', 'MainUnread'),
      subTotal: numOf('subTotal', 'SubTotal'),
      subUnread: numOf('subUnread', 'SubUnread'),
      hasMore: j['hasMore'] == true || j['HasMore'] == true,
    );
  }
}

/// خلاصهٔ نبض زندهٔ میز کار (شمارنده‌های تجمیعی بالای صفحه و بج ماژول‌ها).
class WorkbenchPulse {
  const WorkbenchPulse({
    this.actionableCount = 0,
    this.unreadLetters = 0,
    this.signingLetters = 0,
    this.openWorkOrders = 0,
    this.overdueWorkOrders = 0,
    this.unreadNotifications = 0,
    this.unreadChats = 0,
    this.openItRequests = 0,
    this.pendingArchiveTasks = 0,
  });

  final int actionableCount;
  final int unreadLetters;
  final int signingLetters;
  final int openWorkOrders;
  final int overdueWorkOrders;
  final int unreadNotifications;
  final int unreadChats;
  final int openItRequests;
  final int pendingArchiveTasks;
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
  final q =
      RegExp(r'[?&](?:erjaId|ErjaId|erja)=(\d+)').firstMatch(link) ??
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
  if (hay.contains('workorder') ||
      hay.contains('work-order') ||
      hay.contains('دستور کار') ||
      hay.contains('دستورکار')) {
    return 'wo';
  }
  if (hay.contains('minute') ||
      hay.contains('صورت‌جلسه') ||
      hay.contains('صورتجلسه') ||
      hay.contains('meeting')) {
    return 'minutes';
  }
  if (hay.contains('letter') ||
      hay.contains('نامه') ||
      hay.contains('ارجاع') ||
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
    this.companyId,
    this.companyName,
    this.category,
  });

  final int id;
  final String title;
  final String? body;
  final String? fromName;
  final String? formName;
  final String? link;
  final bool isRead;
  final DateTime? createdAt;
  final int? entityId;
  final String? entityKind;
  final int? companyId;
  final String? companyName;

  /// main = اقدام اصلی | sub = پیگیری فرعی
  final String? category;

  String? get targetLink => link;

  String get displayTitle {
    final t = title.trim();
    if (t.isNotEmpty) return t;
    final f = (formName ?? '').trim();
    if (f.isNotEmpty) return f;
    final b = (body ?? '').trim();
    if (b.isNotEmpty) return b;
    return 'اعلان سازمانی';
  }

  String? get displayBody {
    final b = (body ?? '').trim();
    if (b.isNotEmpty) return b;
    final f = (fromName ?? '').trim();
    return f.isEmpty ? null : f;
  }

  /// تشخیص سمت کلاینت برای سرورهایی که فیلد category را نمی‌فرستند.
  bool get isFollowUp {
    final c = (category ?? '').toLowerCase();
    if (c == 'sub') return true;
    if (c == 'main') return false;
    final hay = '$title ${body ?? ''}'.toLowerCase();
    return hay.contains('تأیید') ||
        hay.contains('تایید') ||
        hay.contains('رد شد') ||
        hay.contains('پاسخ') ||
        hay.contains('کامنت') ||
        hay.contains('بسته شد') ||
        hay.contains('تمدید') ||
        hay.contains('وضعیت');
  }

  factory NotificationItem.fromJson(Map<String, dynamic> j) {
    T? pick<T>(String a, String b) => (j[a] ?? j[b]) as T?;
    return NotificationItem(
      id: (j['id'] as num?)?.toInt() ?? (j['Id'] as num?)?.toInt() ?? 0,
      title: htmlToText((pick<String>('title', 'Title') ?? '').toString()),
      body: htmlToTextOrNull(pick<String>('body', 'Body')?.toString()),
      fromName: pick<String>('fromName', 'FromName')?.toString(),
      formName: pick<String>('formName', 'FormName')?.toString(),
      link: pick<String>('link', 'Link')?.toString(),
      isRead: j['isRead'] == true || j['IsRead'] == true,
      createdAt: DateTime.tryParse(
        (pick<String>('createdAt', 'CreatedAt') ?? '').toString(),
      )?.toLocal(),
      entityId: parseEntityId(j),
      entityKind: parseEntityKind(j),
      companyId:
          (j['companyId'] as num?)?.toInt() ??
          (j['CompanyId'] as num?)?.toInt(),
      companyName: pick<String>('companyName', 'CompanyName')?.toString(),
      category: pick<String>('category', 'Category')?.toString(),
    );
  }

  NotificationItem asRead() => NotificationItem(
    id: id,
    title: title,
    body: body,
    fromName: fromName,
    formName: formName,
    link: link,
    isRead: true,
    createdAt: createdAt,
    entityId: entityId,
    entityKind: entityKind,
    companyId: companyId,
    companyName: companyName,
    category: category,
  );

  @override
  bool operator ==(Object other) => other is NotificationItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// یک ردیف ریز داخل کارت گزارش عملکرد.
class KpiRow {
  const KpiRow(this.label, this.value, {this.hint});
  final String label;
  final String value;
  final String? hint;
}

/// یک کارت «شاخص کلیدی و گزارش عملکرد».
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
    this.targetKey = '',
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
  final String targetKey;
  final List<double> spark;
  final double value;
  final double? deltaPercent;

  LinearGradient get gradient => LinearGradient(
    colors: [from, to],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  HomeKpi copyWith({
    double? value,
    double? deltaPercent,
    List<double>? spark,
  }) => HomeKpi(
    widgetKey: widgetKey,
    moduleName: moduleName,
    moduleSubtitle: moduleSubtitle,
    icon: icon,
    from: from,
    to: to,
    unit: unit,
    rows: rows,
    targetKey: targetKey,
    spark: spark ?? this.spark,
    value: value ?? this.value,
    deltaPercent: deltaPercent ?? this.deltaPercent,
  );
}

/// یک کاشی در گرید ماژول‌های سازمان (هم‌نام با نسخهٔ وب).
class ModuleTile {
  const ModuleTile({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.gradientEnd,
    this.category = 'all',
    this.keywords = const [],
    this.badge,
    this.liveCount = 0,
    this.liveLabel,
    this.locked = false,
    this.tabIndex,
    this.onTapName,
  });

  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color? gradientEnd;

  /// office | commerce | tech | hr
  final String category;
  final List<String> keywords;
  final String? badge;
  final int liveCount;
  final String? liveLabel;

  /// کاربر مجوز این ماژول را ندارد — فقط نمایش، بدون ورود.
  final bool locked;

  /// اگر مقدار داشته باشد، با زدن روی کاشی به همان تب در پوسته می‌رویم.
  final int? tabIndex;

  /// کلید ناوبری برای ماژول‌هایی که صفحهٔ مستقل دارند.
  final String? onTapName;

  LinearGradient get iconGradient => LinearGradient(
    colors: [color, gradientEnd ?? Color.lerp(color, Colors.black, 0.22)!],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  ModuleTile copyWith({
    int? liveCount,
    String? liveLabel,
    String? badge,
    bool? locked,
  }) => ModuleTile(
    id: id,
    name: name,
    subtitle: subtitle,
    icon: icon,
    color: color,
    gradientEnd: gradientEnd,
    category: category,
    keywords: keywords,
    badge: badge ?? this.badge,
    liveCount: liveCount ?? this.liveCount,
    liveLabel: liveLabel ?? this.liveLabel,
    locked: locked ?? this.locked,
    tabIndex: tabIndex,
    onTapName: onTapName,
  );
}
