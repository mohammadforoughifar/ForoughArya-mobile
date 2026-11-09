// ============================================================
//  ریپازیتوری پست الکترونیک — اتصال به api/email بک‌اند
// ============================================================

import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/email_models.dart';
import '../models/office_common.dart';

class EmailRepository {
  const EmailRepository(this._api);

  final ApiClient _api;

  List<Map<String, dynamic>> _items(dynamic data) {
    if (data is List) {
      return data.whereType<Map>().map(asMap).toList();
    }
    final m = asMap(data);
    final raw = m['items'] ?? m['Items'] ?? m['data'] ?? m['Data'];
    if (raw is List) {
      return raw.whereType<Map>().map(asMap).toList();
    }
    return const [];
  }

  // ------------------------------------------------------------
  //  حساب‌های ایمیل (سازمانی / شخصی)
  // ------------------------------------------------------------

  Future<List<EmailAccount>> accounts({int skip = 0, int take = 100}) async {
    final r = await _api.get<dynamic>(
      'api/email/accounts',
      query: {'skip': skip, 'take': take},
    );
    return _items(r.data).map(EmailAccount.fromJson).toList();
  }

  Future<List<EmailAccount>> dabirkhaneAccounts() async {
    final r = await _api.get<dynamic>('api/email/dabirkhane-accounts');
    return _items(r.data).map(EmailAccount.fromJson).toList();
  }

  Future<EmailAccount> saveAccount(
    EmailAccount account, {
    String? password,
  }) async {
    final r = await _api.post<dynamic>(
      'api/email/accounts',
      account.toSavePayload(password: password),
    );
    final m = asMap(r.data);
    return m.isEmpty ? account : EmailAccount.fromJson(m);
  }

  Future<void> deleteAccount(int id) async {
    await _api.delete<dynamic>('api/email/accounts/$id');
  }

  Future<EmailTestResult> testAccount(
    EmailAccount account, {
    String? password,
  }) async {
    final r = await _api.post<dynamic>(
      'api/email/test',
      account.toSavePayload(password: password),
    );
    return EmailTestResult.fromJson(r.data);
  }

  // ------------------------------------------------------------
  //  همگام‌سازی (Sync)
  // ------------------------------------------------------------

  Future<EmailSyncResult> syncAccount(int id, {String box = EmailBox.inbox}) async {
    final r = await _api.post<dynamic>(
      'api/email/accounts/$id/sync',
      null,
      {'box': box},
    );
    return EmailSyncResult.fromJson(r.data);
  }

  Future<EmailSyncResult> syncInbox({bool personal = false}) async {
    final r = await _api.post<dynamic>(
      'api/email/sync-inbox',
      null,
      {'personal': personal},
    );
    return EmailSyncResult.fromJson(r.data);
  }

  Future<EmailSyncResult> syncSent({bool personal = false}) async {
    final r = await _api.post<dynamic>(
      'api/email/sync-sent',
      null,
      {'personal': personal},
    );
    return EmailSyncResult.fromJson(r.data);
  }

  // ------------------------------------------------------------
  //  کارتابل‌های دریافتی / ارسالی / بایگانی
  // ------------------------------------------------------------

  Map<String, dynamic> _listQuery({
    int? emailId,
    String? search,
    int page = 1,
    int pageSize = 25,
    int? folderId,
    bool? spam,
    bool? starred,
    bool personal = false,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) => {
    if (emailId != null && emailId > 0) 'emailId': emailId,
    if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    'page': page,
    'pageSize': pageSize,
    if (folderId != null) 'folderId': folderId,
    if (spam != null) 'spam': spam,
    if (starred != null) 'starred': starred,
    'personal': personal,
    if (dateFrom != null) 'dateFrom': dateFrom.toIso8601String(),
    if (dateTo != null) 'dateTo': dateTo.toIso8601String(),
  };

  Future<EmailListResult> inbox({
    int? emailId,
    String? search,
    int page = 1,
    int pageSize = 25,
    int? folderId,
    bool? spam,
    bool? starred,
    bool personal = false,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final r = await _api.get<dynamic>(
      'api/email/inbox',
      query: _listQuery(
        emailId: emailId,
        search: search,
        page: page,
        pageSize: pageSize,
        folderId: folderId,
        spam: spam,
        starred: starred,
        personal: personal,
        dateFrom: dateFrom,
        dateTo: dateTo,
      ),
    );
    return EmailListResult.fromJson(r.data);
  }

  Future<EmailListResult> sent({
    int? emailId,
    String? search,
    int page = 1,
    int pageSize = 25,
    bool personal = false,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final r = await _api.get<dynamic>(
      'api/email/sent',
      query: _listQuery(
        emailId: emailId,
        search: search,
        page: page,
        pageSize: pageSize,
        personal: personal,
        dateFrom: dateFrom,
        dateTo: dateTo,
      ),
    );
    return EmailListResult.fromJson(r.data);
  }

  Future<EmailListResult> archive({
    int? emailId,
    String? search,
    int page = 1,
    int pageSize = 25,
    int? folderId,
    bool personal = false,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final r = await _api.get<dynamic>(
      'api/email/archive',
      query: _listQuery(
        emailId: emailId,
        search: search,
        page: page,
        pageSize: pageSize,
        folderId: folderId,
        personal: personal,
        dateFrom: dateFrom,
        dateTo: dateTo,
      ),
    );
    return EmailListResult.fromJson(r.data);
  }

  // ------------------------------------------------------------
  //  جزئیات پیام و عملیات روی پیام
  // ------------------------------------------------------------

  Future<EmailMessageDetail> message(String box, int id) async {
    final b = EmailBox.normalize(box);
    final r = await _api.get<dynamic>('api/email/message/$b/$id');
    return EmailMessageDetail.fromJson(asMap(r.data));
  }

  Future<void> markRead(String box, int id, {bool isRead = true}) async {
    final b = EmailBox.normalize(box);
    await _api.post<dynamic>('api/email/message/$b/$id/read', {'isRead': isRead});
  }

  Future<bool> toggleNeshan(String box, int id) async {
    final b = EmailBox.normalize(box);
    final r = await _api.post<dynamic>('api/email/message/$b/$id/neshan');
    final m = asMap(r.data);
    return pickBool(m, ['isNeshan', 'IsNeshan'], true);
  }

  Future<bool> toggleSpam(String box, int id) async {
    final b = EmailBox.normalize(box);
    final r = await _api.post<dynamic>('api/email/message/$b/$id/spam');
    final m = asMap(r.data);
    return pickBool(m, ['isSpam', 'IsSpam'], true);
  }

  Future<void> moveToFolder({
    required String box,
    required int id,
    required int folderId,
  }) async {
    await _api.post<dynamic>('api/email/archive', {
      'box': EmailBox.normalize(box),
      'id': id,
      'folderId': folderId,
    });
  }

  Future<Uint8List> downloadAttachment(int attachmentId) =>
      _api.getBytes('api/email/attachments/$attachmentId/download');

  // ------------------------------------------------------------
  //  پوشه‌های بایگانی
  // ------------------------------------------------------------

  Future<List<EmailFolder>> folders() async {
    final r = await _api.get<dynamic>('api/email/folders');
    return _items(r.data).map(EmailFolder.fromJson).toList();
  }

  Future<EmailFolder> createFolder(String title) async {
    final r = await _api.post<dynamic>('api/email/folders', {'title': title.trim()});
    return EmailFolder.fromJson(asMap(r.data));
  }

  Future<void> deleteFolder(int folderId) async {
    await _api.delete<dynamic>('api/email/folders/$folderId');
  }

  // ------------------------------------------------------------
  //  ارسال ایمیل (multipart/form-data با پیوست تا ۲۰MB)
  // ------------------------------------------------------------

  Future<void> send({
    required int emailAccountId,
    required String to,
    String cc = '',
    required String subject,
    required String body,
    List<({String name, Uint8List bytes, String? mimeType})> attachments = const [],
  }) async {
    final map = <String, dynamic>{
      'emailAccountId': emailAccountId.toString(),
      'to': to.trim(),
      if (cc.trim().isNotEmpty) 'cc': cc.trim(),
      'subject': subject.trim(),
      'body': body,
    };
    final form = FormData.fromMap(map);
    for (final a in attachments) {
      form.files.add(
        MapEntry(
          'files',
          MultipartFile.fromBytes(
            a.bytes,
            filename: a.name,
            contentType: a.mimeType != null ? DioMediaType.parse(a.mimeType!) : null,
          ),
        ),
      );
    }
    await _api.postForm<dynamic>('api/email/send', form);
  }
}
