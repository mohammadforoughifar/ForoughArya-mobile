import 'dart:io';

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_client.dart';
import '../models/work_order.dart';
import '../../../core/utils/html_text.dart';

class WorkOrderRepository {
  WorkOrderRepository(this._api);
  final ApiClient _api;
  static const _root = '/api/workorders';

  List<dynamic> rows(dynamic data) {
    if (data is List) return data;
    if (data is Map)
      return (data['items'] ?? data['Items'] ?? data['data'] ?? []) as List? ??
          [];
    return [];
  }

  Map<String, dynamic> map(dynamic data) =>
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

  Future<WorkOrderPageData> list(
    String tab, {
    int page = 1,
    int pageSize = 20,
    String? q,
    int? priority,
    String? tag,
    String? decision,
    int? userId,
    DateTime? dueFrom,
    DateTime? dueTo,
  }) async {
    final r = await _api.get<Map<String, dynamic>>(
      '$_root/$tab',
      query: {
        'page': page,
        'pageSize': pageSize,
        if (q?.trim().isNotEmpty == true) 'q': q!.trim(),
        if (priority != null) 'priority': priority,
        if (tag?.isNotEmpty == true) 'tag': tag,
        if (decision?.isNotEmpty == true) 'decision': decision,
        if (userId != null) 'userId': userId,
        if (dueFrom != null) 'dueFrom': dueFrom.toIso8601String(),
        if (dueTo != null) 'dueTo': dueTo.toIso8601String(),
      },
    );
    return WorkOrderPageData.fromJson(r.data ?? {});
  }

  Future<Map<String, dynamic>> counts() async =>
      map((await _api.get('$_root/counts')).data);
  Future<List<TargetUser>> targets() async =>
      rows((await _api.get('$_root/targets', query: {'take': 500})).data)
          .whereType<Map>()
          .map((e) => TargetUser.fromJson(Map<String, dynamic>.from(e)))
          .toList();
  Future<WorkOrder> detail(int id) async =>
      WorkOrder.fromJson(map((await _api.get('$_root/$id')).data));
  Future<String> fullDescription(int id) async {
    final d = map((await _api.get('$_root/$id/description')).data);
    return htmlToText(d['description']?.toString());
  }

  Future<WorkOrderPageData> calendar(DateTime from, DateTime to) async =>
      WorkOrderPageData.fromJson(
        map(
          (await _api.get(
            '$_root/calendar',
            query: {
              'from': from.toIso8601String(),
              'to': to.toIso8601String(),
              'take': 500,
            },
          )).data,
        ),
      );
  Future<Map<String, dynamic>> stats() async =>
      map((await _api.get('$_root/stats')).data);
  Future<List<dynamic>> performance(int days) async => rows(
    (await _api.get(
      '$_root/performance',
      query: {'days': days, 'take': 100},
    )).data,
  );
  Future<List<dynamic>> templates() async =>
      rows((await _api.get('$_root/templates', query: {'take': 20})).data);
  Future<List<String>> tags() async =>
      rows((await _api.get('$_root/my-tags')).data)
          .map(
            (e) => e is Map
                ? (e['tag'] ?? e['name'] ?? '').toString()
                : e.toString(),
          )
          .where((e) => e.isNotEmpty)
          .toList();

  Future<Map<String, dynamic>> save(
    Map<String, dynamic> body, {
    int? id,
  }) async {
    final r = id == null
        ? await _api.post(_root, body)
        : await _api.put('$_root/$id', body);
    return map(r.data);
  }

  /// دستورهای کارِ ساخته‌شده از یک مبدأ — `GET workorders/for-source`
  Future<List<Map<String, dynamic>>> forSource({
    required String module,
    required int sourceId,
  }) async {
    final r = await _api.get<dynamic>(
      '$_root/for-source',
      query: {'module': module, 'sourceId': sourceId},
    );
    final d = r.data;
    final list = d is List
        ? d
        : (d is Map && d['items'] is List ? d['items'] as List : const []);
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> seen(int id) async => _api.post('$_root/$id/seen');
  Future<void> reply(int id, bool done, String text) async =>
      _api.post('$_root/$id/reply', {'done': done, 'text': text});
  Future<void> decide(
    int id,
    int assigneeId,
    bool approved,
    String note,
  ) async => _api.post('$_root/$id/assignees/$assigneeId/decide', {
    'approved': approved,
    'note': note,
  });
  /// `GET /api/workorders/my-access` — منبع حقیقتِ «کی دستوردهنده است» و
  /// «چه کسی می‌تواند ببندد/حذف کند» (سرور بر اساس آن ۴۰۳ می‌دهد).
  /// قبلاً شناسهٔ کاربر از نشست خوانده می‌شد و خروجی این endpoint دور ریخته
  /// می‌شد؛ نتیجه: دکمهٔ «بستن دستور کار» برای دستوردهنده هم دیده نمی‌شد.
  Future<WoAccess> myAccess() async {
    try {
      final r = await _api.get<dynamic>('$_root/my-access');
      final m = map(r.data);
      if (m.isEmpty) return const WoAccess.empty();
      return WoAccess(
        userId: (m['userId'] as num?)?.toInt() ?? 0,
        canView: m['canView'] == true,
        canCreate: m['canCreate'] == true,
        canAssignOthers: m['canAssignOthers'] == true,
        canDelete: m['canDelete'] == true,
      );
    } catch (_) {
      return const WoAccess.empty();
    }
  }

  Future<void> extend(int id, DateTime due, String note) async => _api.post(
    '$_root/$id/extend',
    {'newDueAt': due.toIso8601String(), 'note': note},
  );
  Future<void> close(int id, String note) async =>
      _api.post('$_root/$id/close', {'note': note});
  Future<void> reopen(int id, String note, DateTime? due, bool reset) async =>
      _api.post('$_root/$id/reopen', {
        'note': note,
        'newDueAt': due?.toIso8601String(),
        'resetReplies': reset,
      });
  Future<void> remove(int id) async => _api.delete('$_root/$id');
  Future<void> bulk(List<int> ids, String action) async =>
      _api.post('$_root/bulk', {'ids': ids, 'action': action});
  Future<void> addAssignees(
    int id,
    List<int> ids,
    String note,
    bool sms,
  ) async => _api.post('$_root/$id/assignees', {
    'userIds': ids,
    'note': note,
    'sendSms': sms,
  });
  Future<void> priority(int id, int value) async =>
      _api.post('$_root/$id/priority', {'priority': value});

  Future<List<dynamic>> checklist(int id) async =>
      rows((await _api.get('$_root/$id/checklist')).data);
  Future<void> addChecklist(int id, String text) async =>
      _api.post('$_root/$id/checklist', {'text': text});
  Future<void> toggleChecklist(int id, int itemId) async =>
      _api.post('$_root/$id/checklist/$itemId/toggle');
  Future<void> deleteChecklist(int id, int itemId) async =>
      _api.delete('$_root/$id/checklist/$itemId');
  Future<void> reorderChecklist(int id, List<int> ids) async =>
      _api.post('$_root/$id/checklist/reorder', ids);

  Future<List<dynamic>> comments(int id) async =>
      rows((await _api.get('$_root/$id/comments', query: {'take': 500})).data);
  Future<void> addComment(int id, String text, {int? replyToId}) async =>
      _api.post('$_root/$id/comments', {'text': text, 'replyToId': replyToId});
  Future<void> editComment(int id, String text) async =>
      _api.put('$_root/comments/$id', {'text': text});
  Future<void> deleteComment(int id) async =>
      _api.delete('$_root/comments/$id');

  Future<List<dynamic>> attachments(int id) async => rows(
    (await _api.get('$_root/$id/attachments', query: {'take': 500})).data,
  );
  Future<void> upload(
    int id,
    String? path,
    String name, {
    Uint8List? bytes,
  }) async {
    final file = bytes != null
        ? MultipartFile.fromBytes(bytes, filename: name)
        : await MultipartFile.fromFile(path!, filename: name);
    await _api.post(
      '$_root/$id/attachments',
      FormData.fromMap({'file': file}),
    );
  }

  Future<List<dynamic>> logs(int id) async =>
      rows((await _api.get('$_root/$id/logs', query: {'take': 500})).data);

  /// نسخهٔ وب: بایت‌های پیوست (بدون پوشهٔ موقت)
  Future<Uint8List> attachmentBytes(int attachmentId) =>
      _api.getBytes('$_root/attachments/$attachmentId/download');

  Future<Uint8List> exportListBytes(
    String format,
    String tab, {
    String? q,
    int? priority,
    String? tag,
  }) => _api.getBytes(
    '$_root/export',
    query: {
      'format': format,
      'tab': tab,
      if (q?.isNotEmpty == true) 'q': q,
      if (priority != null) 'priority': priority,
      if (tag?.isNotEmpty == true) 'tag': tag,
    },
  );

  Future<Uint8List> exportPerformanceBytes(String format, int days) =>
      _api.getBytes(
        '$_root/performance/export',
        query: {'format': format, 'days': days},
      );

  Future<File> downloadAttachment(int attachmentId, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await _api.dio.download(
      '$_root/attachments/$attachmentId/download',
      file.path,
    );
    return file;
  }

  Future<File> exportList(
    String format,
    String tab, {
    String? q,
    int? priority,
    String? tag,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/work-orders-${DateTime.now().millisecondsSinceEpoch}.$format',
    );
    await _api.dio.download(
      '$_root/export',
      file.path,
      queryParameters: {
        'format': format,
        'tab': tab,
        if (q?.isNotEmpty == true) 'q': q,
        if (priority != null) 'priority': priority,
        if (tag?.isNotEmpty == true) 'tag': tag,
      },
    );
    return file;
  }

  Future<File> exportPerformance(String format, int days) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/work-order-performance-${DateTime.now().millisecondsSinceEpoch}.$format',
    );
    await _api.dio.download(
      '$_root/performance/export',
      file.path,
      queryParameters: {'format': format, 'days': days},
    );
    return file;
  }

  Future<void> saveTemplate(Map<String, dynamic> body) async =>
      _api.post('$_root/templates', body);
  Future<void> templateUsed(int id) async =>
      _api.post('$_root/templates/$id/used');
  Future<void> deleteTemplate(int id) async =>
      _api.delete('$_root/templates/$id');
}


/// دسترسی‌های کاربر جاری در ماژول دستور کار (پاسخ `my-access`).
class WoAccess {
  const WoAccess({
    required this.userId,
    this.canView = false,
    this.canCreate = false,
    this.canAssignOthers = false,
    this.canDelete = false,
  });

  const WoAccess.empty()
    : userId = 0,
      canView = false,
      canCreate = false,
      canAssignOthers = false,
      canDelete = false;

  final int userId;
  final bool canView, canCreate, canAssignOthers, canDelete;

  bool get isKnown => userId > 0;

  /// آیا این کاربر «دستوردهنده»ی این دستور کار است؟
  bool ownsOrder(int orderOwnerUserId) =>
      orderOwnerUserId > 0 && isKnown && userId == orderOwnerUserId;
}
