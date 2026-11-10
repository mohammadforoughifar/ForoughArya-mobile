import 'package:shamsi_date/shamsi_date.dart';

class Assignee {
  Assignee.fromJson(Map<String, dynamic> j)
    : id = (j['id'] as num?)?.toInt() ?? 0,
      userId = (j['userId'] as num?)?.toInt() ?? 0,
      name = j['name']?.toString() ?? '',
      seenAt = j['seenAt']?.toString(),
      repliedAt = j['repliedAt']?.toString(),
      done = j['done'] as bool?,
      replyText = j['replyText']?.toString(),
      ownerDecision = j['ownerDecision']?.toString(),
      ownerDecisionNote = j['ownerDecisionNote']?.toString();
  final int id, userId;
  final String name;
  final String? seenAt, repliedAt, replyText, ownerDecisionNote;
  final bool? done;
  final String? ownerDecision;
}

class WorkOrder {
  WorkOrder.fromJson(Map<String, dynamic> j)
    : id = (j['id'] as num?)?.toInt() ?? 0,
      number = j['number']?.toString() ?? '',
      title = j['title']?.toString() ?? '',
      description = j['description']?.toString() ?? '',
      ownerUserId = (j['ownerUserId'] as num?)?.toInt() ?? 0,
      ownerName = j['ownerName']?.toString() ?? '',
      // سرور مهلت را گاهی شمسی («1404/08/20») و گاهی ISO می‌فرستد؛ همه‌جا
      // به ISO میلادی نرمال می‌شود تا Fa.date همیشه درست شمسی نشان دهد.
      dueAt = jalaliOrIsoToIso(
        j['dueAt'] ?? j['DueAt'] ?? j['dueDate'] ?? j['deadlineAnswer'],
      ),
      status = j['status']?.toString() ?? 'Open',
      closeNote = j['closeNote']?.toString(),
      createdAt = jalaliOrIsoToIso(j['createdAt'] ?? j['CreatedAt']),
      extensionCount = (j['extensionCount'] as num?)?.toInt() ?? 0,
      priority = (j['priority'] as num?)?.toInt() ?? 1,
      recurrence = (j['recurrence'] as num?)?.toInt() ?? 0,
      projectId = (j['projectId'] as num?)?.toInt(),
      projectName = j['projectName']?.toString(),
      projectCode = j['projectCode']?.toString(),
      weight = (j['weight'] as num?)?.toInt() ?? 1,
      checklistTotal = (j['checklistTotal'] as num?)?.toInt() ?? 0,
      checklistDone = (j['checklistDone'] as num?)?.toInt() ?? 0,
      attachmentCount = (j['attachmentCount'] as num?)?.toInt() ?? 0,
      commentCount = (j['commentCount'] as num?)?.toInt() ?? 0,
      parentOrderId = (j['parentOrderId'] as num?)?.toInt(),
      tags = (j['tags'] as List? ?? []).map((e) => e.toString()).toList(),
      assignees = (j['assignees'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Assignee.fromJson(Map<String, dynamic>.from(e)))
          .toList();

  final int id,
      ownerUserId,
      priority,
      recurrence,
      checklistTotal,
      checklistDone,
      attachmentCount,
      commentCount,
      extensionCount,
      weight;
  final int? projectId, parentOrderId;
  final String number, title, description, ownerName, status;
  final String? dueAt, closeNote, createdAt, projectName, projectCode;
  final List<String> tags;
  final List<Assignee> assignees;
  bool get isOpen => status == 'Open';
  bool get isOverdue =>
      isOpen &&
      DateTime.tryParse(dueAt ?? '')?.isBefore(DateTime.now()) == true;
}

class WorkOrderPageData {
  WorkOrderPageData.fromJson(Map<String, dynamic> j)
    : items = (j['items'] as List? ?? [])
          .whereType<Map>()
          .map((e) => WorkOrder.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      totalCount = (j['totalCount'] as num?)?.toInt() ?? 0,
      page = (j['page'] as num?)?.toInt() ?? 1,
      pageSize = (j['pageSize'] as num?)?.toInt() ?? 20;
  final List<WorkOrder> items;
  final int totalCount, page, pageSize;
  int get pages => totalCount == 0 ? 1 : (totalCount / pageSize).ceil();
}

class TargetUser {
  TargetUser.fromJson(Map<String, dynamic> j)
    : id = (j['id'] as num?)?.toInt() ?? 0,
      username = j['username']?.toString() ?? '';
  final int id;
  final String username;
}

/// تبدیل مقدار تاریخ سرور به ISO میلادی.
///   • ISO/UTC → همان (با toLocal)
///   • «1404/08/20» یا «۱۴۰۴-۰۸-۲۰ ۱۴:۳۰» (شمسی) → ISO میلادی معادل
///   • خالی/نامعتبر → null
String? jalaliOrIsoToIso(Object? raw) {
  final s = raw?.toString().trim();
  if (s == null || s.isEmpty || s == 'null') return null;
  final m = RegExp(r'^(1[34]\d{2})[-/](\d{1,2})[-/](\d{1,2})(?:[T ](\d{1,2}):(\d{2}))?')
      .firstMatch(s);
  if (m != null) {
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    if (mo >= 1 && mo <= 12 && d >= 1 && d <= 31 && y >= 1300 && y <= 1500) {
      try {
        final j = Jalali(y, mo, d);
        final g = j.toDateTime();
        final hh = int.tryParse(m.group(4) ?? '') ?? 0;
        final mm = int.tryParse(m.group(5) ?? '') ?? 0;
        return DateTime(g.year, g.month, g.day, hh, mm).toIso8601String();
      } catch (_) {
        return null;
      }
    }
  }
  final parsed = DateTime.tryParse(s);
  return parsed?.toIso8601String();
}
