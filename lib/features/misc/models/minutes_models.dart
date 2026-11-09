// ============================================================
//  مدل‌های صورتجلسه — زیرمجموعهٔ ماژول «فرم‌های متفرقه»
//  منطبق بر MeetingMinutesDtos.cs در Inventory.Shared
// ============================================================

import '../../../core/utils/fa.dart';

/// وضعیت کلی صورتجلسه
enum MinutesStatus {
  inReview('InReview', 'در حال بررسی'),
  closed('Closed', 'اتمام نهایی');

  const MinutesStatus(this.code, this.label);
  final String code;
  final String label;

  static MinutesStatus fromCode(String? raw) =>
      (raw ?? '').toLowerCase() == 'closed' ? closed : inReview;
}

/// وضعیت هر بند صورتجلسه
enum MinutesItemState {
  inProgress('InProgress', 'در جریان'),
  done('Done', 'انجام شد'),
  rejected('Rejected', 'رد شده');

  const MinutesItemState(this.code, this.label);
  final String code;
  final String label;

  static MinutesItemState fromCode(String? raw) =>
      switch ((raw ?? '').toLowerCase()) {
        'done' => done,
        'rejected' => rejected,
        _ => inProgress,
      };
}

dynamic _pick(Map<String, dynamic> j, String camel, String pascal) =>
    j.containsKey(camel) ? j[camel] : j[pascal];

String _str(Map<String, dynamic> j, String camel, String pascal, [String def = '']) =>
    _pick(j, camel, pascal)?.toString() ?? def;

int _int(Map<String, dynamic> j, String camel, String pascal, [int def = 0]) =>
    Fa.digitInt(_pick(j, camel, pascal)) ?? def;

bool _bool(Map<String, dynamic> j, String camel, String pascal, [bool def = false]) {
  final v = _pick(j, camel, pascal);
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.toLowerCase() == 'true' || v == '1';
  return def;
}

DateTime? _date(Map<String, dynamic> j, String camel, String pascal) {
  final raw = _pick(j, camel, pascal)?.toString();
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

/// آیتم فهرست صورتجلسه‌ها (`MinutesListItemDto`)
class MinutesListItem {
  const MinutesListItem({
    required this.id,
    required this.title,
    required this.meetingDate,
    required this.dateRegistered,
    required this.status,
    this.closedAt,
    required this.createdByUserId,
    required this.createdByName,
    this.attendeeCount = 0,
    this.absentCount = 0,
    this.itemCount = 0,
    this.itemDoneCount = 0,
    this.attachmentCount = 0,
  });

  final int id;
  final String title;
  final DateTime? meetingDate;
  final DateTime? dateRegistered;
  final MinutesStatus status;
  final DateTime? closedAt;
  final int createdByUserId;
  final String createdByName;
  final int attendeeCount;
  final int absentCount;
  final int itemCount;
  final int itemDoneCount;
  final int attachmentCount;

  bool get isClosed => status == MinutesStatus.closed;
  double get progress =>
      itemCount <= 0 ? 0.0 : (itemDoneCount / itemCount).clamp(0.0, 1.0);

  factory MinutesListItem.fromJson(Map<String, dynamic> j) => MinutesListItem(
    id: _int(j, 'id', 'Id'),
    title: _str(j, 'title', 'Title', 'بدون عنوان'),
    meetingDate: _date(j, 'meetingDate', 'MeetingDate'),
    dateRegistered: _date(j, 'dateRegistered', 'DateRegistered'),
    status: MinutesStatus.fromCode(_str(j, 'status', 'Status')),
    closedAt: _date(j, 'closedAt', 'ClosedAt'),
    createdByUserId: _int(j, 'createdByUserId', 'CreatedByUserId'),
    createdByName: _str(j, 'createdByName', 'CreatedByName', '—'),
    attendeeCount: _int(j, 'attendeeCount', 'AttendeeCount'),
    absentCount: _int(j, 'absentCount', 'AbsentCount'),
    itemCount: _int(j, 'itemCount', 'ItemCount'),
    itemDoneCount: _int(j, 'itemDoneCount', 'ItemDoneCount'),
    attachmentCount: _int(j, 'attachmentCount', 'AttachmentCount'),
  );
}

/// شرکت‌کنندهٔ جلسه (`MinutesParticipantDto`)
class MinutesParticipant {
  const MinutesParticipant({
    required this.id,
    required this.userId,
    required this.name,
    required this.kind,
    this.signatureData,
    this.signedAt,
  });

  final int id;
  final int userId;
  final String name;

  /// `Attendee` | `Absent`
  final String kind;
  final String? signatureData;
  final DateTime? signedAt;

  bool get isAttendee => kind.toLowerCase() != 'absent';
  bool get isAbsent => !isAttendee;
  bool get isSigned =>
      signedAt != null || (signatureData != null && signatureData!.trim().isNotEmpty);

  /// رشتهٔ خام base64 امضا (بدون پیشوند data:image/png;base64,)
  String? get cleanSignatureBase64 {
    final s = signatureData?.trim();
    if (s == null || s.isEmpty) return null;
    final idx = s.indexOf('base64,');
    return idx >= 0 ? s.substring(idx + 7) : s;
  }

  factory MinutesParticipant.fromJson(Map<String, dynamic> j) =>
      MinutesParticipant(
        id: _int(j, 'id', 'Id'),
        userId: _int(j, 'userId', 'UserId'),
        name: _str(j, 'name', 'Name', '—'),
        kind: _str(j, 'kind', 'Kind', 'Attendee'),
        signatureData: _pick(j, 'signatureData', 'SignatureData')?.toString(),
        signedAt: _date(j, 'signedAt', 'SignedAt'),
      );
}

/// بند صورتجلسه (`MinutesItemDto`)
class MinutesItem {
  const MinutesItem({
    required this.id,
    required this.rowNo,
    required this.description,
    this.dueDate,
    this.responsibleUserId,
    this.responsibleName,
    this.followUpDate,
    this.followUpUserId,
    this.followUpName,
    this.state = MinutesItemState.inProgress,
    this.respApproved = false,
    this.respApprovedAt,
    this.respNote,
    this.followUpDecision,
    this.followUpDecidedAt,
    this.followUpNote,
  });

  final int id;
  final int rowNo;
  final String description;
  final DateTime? dueDate;
  final int? responsibleUserId;
  final String? responsibleName;
  final DateTime? followUpDate;
  final int? followUpUserId;
  final String? followUpName;
  final MinutesItemState state;
  final bool respApproved;
  final DateTime? respApprovedAt;
  final String? respNote;

  /// `null` | `Approved` | `Rejected`
  final String? followUpDecision;
  final DateTime? followUpDecidedAt;
  final String? followUpNote;

  bool get isFollowUpApproved =>
      (followUpDecision ?? '').toLowerCase() == 'approved';
  bool get isFollowUpRejected =>
      (followUpDecision ?? '').toLowerCase() == 'rejected';

  String get followUpStatusLabel => switch ((followUpDecision ?? '').toLowerCase()) {
    'approved' => 'تأیید شده',
    'rejected' => 'رد شده',
    _ => 'بررسی نشده',
  };

  factory MinutesItem.fromJson(Map<String, dynamic> j) => MinutesItem(
    id: _int(j, 'id', 'Id'),
    rowNo: _int(j, 'rowNo', 'RowNo', 1),
    description: _str(j, 'description', 'Description'),
    dueDate: _date(j, 'dueDate', 'DueDate'),
    responsibleUserId: Fa.digitInt(
      _pick(j, 'responsibleUserId', 'ResponsibleUserId'),
    ),
    responsibleName: _pick(j, 'responsibleName', 'ResponsibleName')?.toString(),
    followUpDate: _date(j, 'followUpDate', 'FollowUpDate'),
    followUpUserId: Fa.digitInt(_pick(j, 'followUpUserId', 'FollowUpUserId')),
    followUpName: _pick(j, 'followUpName', 'FollowUpName')?.toString(),
    state: MinutesItemState.fromCode(_str(j, 'itemStatus', 'ItemStatus')),
    respApproved: _bool(j, 'respApproved', 'RespApproved'),
    respApprovedAt: _date(j, 'respApprovedAt', 'RespApprovedAt'),
    respNote: _pick(j, 'respNote', 'RespNote')?.toString(),
    followUpDecision: _pick(
      j,
      'followUpDecision',
      'FollowUpDecision',
    )?.toString(),
    followUpDecidedAt: _date(j, 'followUpDecidedAt', 'FollowUpDecidedAt'),
    followUpNote: _pick(j, 'followUpNote', 'FollowUpNote')?.toString(),
  );
}

/// جزئیات کامل صورتجلسه (`MinutesDetailDto`)
class MinutesDetail {
  const MinutesDetail({
    required this.id,
    required this.title,
    required this.meetingDate,
    required this.dateRegistered,
    required this.status,
    this.closedAt,
    required this.createdByUserId,
    required this.createdByName,
    this.participants = const [],
    this.items = const [],
  });

  final int id;
  final String title;
  final DateTime? meetingDate;
  final DateTime? dateRegistered;
  final MinutesStatus status;
  final DateTime? closedAt;
  final int createdByUserId;
  final String createdByName;
  final List<MinutesParticipant> participants;
  final List<MinutesItem> items;

  bool get isClosed => status == MinutesStatus.closed;
  List<MinutesParticipant> get attendees =>
      participants.where((p) => p.isAttendee).toList();
  List<MinutesParticipant> get absentees =>
      participants.where((p) => p.isAbsent).toList();
  int get doneCount =>
      items.where((i) => i.state == MinutesItemState.done).length;
  double get progress =>
      items.isEmpty ? 0.0 : (doneCount / items.length).clamp(0.0, 1.0);

  factory MinutesDetail.fromJson(Map<String, dynamic> j) {
    final rawParts = _pick(j, 'participants', 'Participants');
    final rawItems = _pick(j, 'items', 'Items');
    return MinutesDetail(
      id: _int(j, 'id', 'Id'),
      title: _str(j, 'title', 'Title', 'بدون عنوان'),
      meetingDate: _date(j, 'meetingDate', 'MeetingDate'),
      dateRegistered: _date(j, 'dateRegistered', 'DateRegistered'),
      status: MinutesStatus.fromCode(_str(j, 'status', 'Status')),
      closedAt: _date(j, 'closedAt', 'ClosedAt'),
      createdByUserId: _int(j, 'createdByUserId', 'CreatedByUserId'),
      createdByName: _str(j, 'createdByName', 'CreatedByName', '—'),
      participants: (rawParts is List ? rawParts : const [])
          .whereType<Map>()
          .map((e) => MinutesParticipant.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      items: (rawItems is List ? rawItems : const [])
          .whereType<Map>()
          .map((e) => MinutesItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// گزینهٔ کاربر سبک (`UserLookupItemDto` — بدون نیاز به SystemUsers)
class MinutesUserOption {
  const MinutesUserOption({required this.id, required this.name});

  final int id;
  final String name;

  factory MinutesUserOption.fromJson(Map<String, dynamic> j) =>
      MinutesUserOption(
        id: _int(j, 'id', 'Id'),
        name: _str(j, 'name', 'Name', 'کاربر'),
      );
}

/// پیوست صورتجلسه (`/api/attachments/MeetingMinutes/{id}`)
class MinutesAttachment {
  const MinutesAttachment({
    required this.id,
    required this.fileName,
    this.uploaderName = '',
    this.uploaderUserId = 0,
    this.uploadedAt,
    this.size = 0,
    this.contentType,
    this.canPreview = false,
    this.canDownload = true,
    this.canDelete = false,
  });

  final int id;
  final String fileName;
  final String uploaderName;
  final int uploaderUserId;
  final DateTime? uploadedAt;
  final int size;
  final String? contentType;
  final bool canPreview;
  final bool canDownload;
  final bool canDelete;

  factory MinutesAttachment.fromJson(Map<String, dynamic> j) =>
      MinutesAttachment(
        id: _int(j, 'id', 'Id'),
        fileName: _str(j, 'fileName', 'FileName', 'file'),
        uploaderName: _str(j, 'uploaderName', 'UploaderName'),
        uploaderUserId: _int(j, 'uploaderUserId', 'UploaderUserId'),
        uploadedAt: _date(j, 'uploadedAt', 'UploadedAt'),
        size: _int(j, 'size', 'Size'),
        contentType: _pick(j, 'contentType', 'ContentType')?.toString(),
        canPreview: _bool(j, 'canPreview', 'CanPreview'),
        canDownload: _bool(j, 'canDownload', 'CanDownload', true),
        canDelete: _bool(j, 'canDelete', 'CanDelete'),
      );
}

/// ورودی ساخت/ویرایش یک بند (`SaveMinutesItemDto`)
class SaveMinutesItemInput {
  const SaveMinutesItemInput({
    this.id = 0,
    required this.description,
    this.dueDate,
    this.responsibleUserId,
    this.followUpDate,
    this.followUpUserId,
  });

  final int id;
  final String description;
  final DateTime? dueDate;
  final int? responsibleUserId;
  final DateTime? followUpDate;
  final int? followUpUserId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description.trim(),
    'dueDate': dueDate?.toIso8601String(),
    'responsibleUserId': (responsibleUserId ?? 0) > 0 ? responsibleUserId : null,
    'followUpDate': followUpDate?.toIso8601String(),
    'followUpUserId': (followUpUserId ?? 0) > 0 ? followUpUserId : null,
  };
}

/// ورودی ساخت/ویرایش صورتجلسه (`SaveMinutesDto`)
class SaveMinutesInput {
  const SaveMinutesInput({
    this.id = 0,
    required this.title,
    required this.meetingDate,
    required this.attendeeUserIds,
    this.absentUserIds = const [],
    this.items = const [],
  });

  final int id;
  final String title;
  final DateTime meetingDate;
  final List<int> attendeeUserIds;
  final List<int> absentUserIds;
  final List<SaveMinutesItemInput> items;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title.trim(),
    'meetingDate': meetingDate.toIso8601String(),
    'attendeeUserIds': attendeeUserIds,
    'absentUserIds': absentUserIds,
    'items': items.map((e) => e.toJson()).toList(),
  };
}

/// خروجی صفحه‌بندی‌شدهٔ فهرست صورتجلسه‌ها
class MinutesPagedResult {
  const MinutesPagedResult({required this.items, required this.total});

  final List<MinutesListItem> items;
  final int total;
}
