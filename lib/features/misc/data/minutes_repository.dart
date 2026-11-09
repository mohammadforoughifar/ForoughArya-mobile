// ============================================================
//  مخزن دادهٔ صورتجلسه‌ها — زیرمجموعهٔ «فرم‌های متفرقه»
//  مسیر سرور: /api/meeting-minutes  (هدر X-Company-Id الزامی است)
// ============================================================

import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../home/models/home_models.dart';
import '../models/minutes_models.dart';

class MinutesRepository {
  MinutesRepository(this._api);

  final ApiClient _api;
  static const _root = '/api/meeting-minutes';

  ApiClient get api => _api;

  /// تضمین ست‌بودن هدر `X-Company-Id` پیش از فراخوانی کنترلر صورتجلسه
  Future<int?> ensureCompany() => _api.ensureCompanyId();

  /// خواندن فهرست شرکت‌های مجاز کاربر و همگام‌سازی شرکت فعال
  Future<CompanyContext> fetchCompanies() async {
    final r = await _api.get<dynamic>('/api/company-context');
    final d = r.data;
    if (d is Map) {
      final ctx = CompanyContext.fromJson(Map<String, dynamic>.from(d));
      if ((_api.companyId == null || _api.companyId! <= 0) &&
          ctx.activeCompanyId != null &&
          ctx.activeCompanyId! > 0) {
        await _api.setCompanyId(ctx.activeCompanyId);
      }
      return ctx;
    }
    return CompanyContext.empty;
  }

  Future<void> selectCompany(int companyId) => _api.setCompanyId(companyId);

  // ================== فهرست و جزئیات ==================

  Future<MinutesPagedResult> fetchList({
    String? search,
    String? status,
    int skip = 0,
    int take = 50,
  }) async {
    await ensureCompany();
    final q = <String, dynamic>{
      'skip': skip,
      'take': take,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
    };
    final r = await _api.get<dynamic>(_root, query: q);
    final data = r.data;
    if (data is List) {
      final list = data
          .whereType<Map>()
          .map((e) => MinutesListItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return MinutesPagedResult(items: list, total: list.length);
    }
    if (data is Map) {
      final rawItems = data['items'] ?? data['Items'] ?? const [];
      final list = (rawItems is List ? rawItems : const [])
          .whereType<Map>()
          .map((e) => MinutesListItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final total =
          Fa.digitInt(data['total'] ?? data['Total']) ?? list.length;
      return MinutesPagedResult(items: list, total: total);
    }
    return const MinutesPagedResult(items: [], total: 0);
  }

  Future<MinutesDetail> fetchDetail(int id) async {
    await ensureCompany();
    final r = await _api.get<dynamic>('$_root/$id');
    final data = r.data;
    if (data is Map) {
      return MinutesDetail.fromJson(Map<String, dynamic>.from(data));
    }
    throw ApiException('صورتجلسه پیدا نشد یا پاسخ سرور معتبر نیست.', 404);
  }

  /// کاربران فعال برای کمبوهای حاضرین / غایبین / مسئول / پیگیری (بدون نیاز به SystemUsers)
  Future<List<MinutesUserOption>> fetchUserOptions() async {
    await ensureCompany();
    final r = await _api.get<dynamic>('$_root/user-options');
    final data = r.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => MinutesUserOption.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  // ================== ثبت، ویرایش، ارسال به گردش، حذف ==================

  Future<int> save(SaveMinutesInput input) async {
    await ensureCompany();
    final r = await _api.post<dynamic>(_root, input.toJson());
    final data = r.data;
    if (data is Map) {
      return Fa.digitInt(data['id'] ?? data['Id']) ?? input.id;
    }
    return Fa.digitInt(data) ?? input.id;
  }

  Future<void> submit(int id, {bool includeAbsentees = true}) async {
    await ensureCompany();
    await _api.post<dynamic>('$_root/$id/submit', {
      'includeAbsentees': includeAbsentees,
    });
  }

  Future<void> deleteMinutes(int id) async {
    await ensureCompany();
    await _api.delete<dynamic>('$_root/$id');
  }

  // ================== بندها و تصمیمات ==================

  Future<MinutesItem> addItem(int minutesId, SaveMinutesItemInput item) async {
    await ensureCompany();
    final r = await _api.post<dynamic>('$_root/$minutesId/items', item.toJson());
    if (r.data is Map) {
      return MinutesItem.fromJson(Map<String, dynamic>.from(r.data as Map));
    }
    throw ApiException('پاسخ ثبت بند معتبر نیست.');
  }

  Future<MinutesItem> updateItem(int itemId, SaveMinutesItemInput item) async {
    await ensureCompany();
    final r = await _api.put<dynamic>('$_root/items/$itemId', item.toJson());
    if (r.data is Map) {
      return MinutesItem.fromJson(Map<String, dynamic>.from(r.data as Map));
    }
    throw ApiException('پاسخ ویرایش بند معتبر نیست.');
  }

  Future<void> deleteItem(int itemId) async {
    await ensureCompany();
    await _api.delete<dynamic>('$_root/items/$itemId');
  }

  Future<MinutesItem> respDecision(
    int itemId, {
    required bool approved,
    String? note,
  }) async {
    await ensureCompany();
    final r = await _api.post<dynamic>('$_root/items/$itemId/resp-decision', {
      'approved': approved,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    if (r.data is Map) {
      return MinutesItem.fromJson(Map<String, dynamic>.from(r.data as Map));
    }
    throw ApiException('پاسخ ثبت تصمیم مسئول معتبر نیست.');
  }

  Future<MinutesItem> followUpDecision(
    int itemId, {
    required String decision,
    String? note,
  }) async {
    await ensureCompany();
    final r = await _api.post<dynamic>(
      '$_root/items/$itemId/followup-decision',
      {
        'decision': decision,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    if (r.data is Map) {
      return MinutesItem.fromJson(Map<String, dynamic>.from(r.data as Map));
    }
    throw ApiException('پاسخ ثبت تصمیم پیگیری معتبر نیست.');
  }

  // ================== امضای الکترونیکی ==================

  Future<void> sign(int minutesId, String signatureBase64) async {
    await ensureCompany();
    await _api.post<dynamic>('$_root/$minutesId/sign', {
      'signatureBase64': signatureBase64,
    });
  }

  Future<void> removeSignature(int minutesId, int participantUserId) async {
    await ensureCompany();
    await _api.delete<dynamic>(
      '$_root/$minutesId/participants/$participantUserId/signature',
    );
  }

  // ================== تبدیل به نامه / ارسال ایمیل / چاپ PDF ==================

  Future<int> toInnerLetter(
    int minutesId, {
    int itemId = 0,
    String title = '',
    String? text,
    List<int> girande = const [],
    List<int> erja = const [],
    List<int> hamesh = const [],
  }) async {
    await ensureCompany();
    final r = await _api.post<dynamic>('$_root/$minutesId/to-inner-letter', {
      'itemId': itemId,
      'title': title.trim(),
      if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
      'reciversGirande': girande,
      'reciversErja': erja,
      'reciversHamesh': hamesh,
    });
    if (r.data is Map) {
      final m = r.data as Map;
      return Fa.digitInt(m['letterId'] ?? m['id']) ?? 0;
    }
    return 0;
  }

  Future<int> toOutgoingLetter(
    int minutesId, {
    required String receiverOrganization,
    String title = '',
    String? text,
    String? receiverName,
    String? receiverTitle,
    String? copyTo,
  }) async {
    await ensureCompany();
    final r = await _api.post<dynamic>('$_root/$minutesId/to-outgoing-letter', {
      'title': title.trim(),
      if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
      'receiverOrganization': receiverOrganization.trim(),
      if (receiverName != null && receiverName.trim().isNotEmpty)
        'receiverName': receiverName.trim(),
      if (receiverTitle != null && receiverTitle.trim().isNotEmpty)
        'receiverTitle': receiverTitle.trim(),
      if (copyTo != null && copyTo.trim().isNotEmpty)
        'copyTo': copyTo.trim(),
    });
    if (r.data is Map) {
      final m = r.data as Map;
      return Fa.digitInt(m['letterId'] ?? m['id']) ?? 0;
    }
    return 0;
  }

  Future<int> sendEmail(
    int minutesId, {
    required int emailAccountId,
    required String to,
    String? cc,
    String subject = '',
    String? body,
  }) async {
    await ensureCompany();
    final r = await _api.post<dynamic>('$_root/$minutesId/send-email', {
      'emailAccountId': emailAccountId,
      'to': to.trim(),
      if (cc != null && cc.trim().isNotEmpty) 'cc': cc.trim(),
      'subject': subject.trim(),
      if (body != null && body.trim().isNotEmpty) 'body': body.trim(),
    });
    if (r.data is Map) {
      final m = r.data as Map;
      return Fa.digitInt(m['emailId'] ?? m['id']) ?? 0;
    }
    return 0;
  }

  /// دریافت فایل PDF چاپی صورتجلسه با سربرگ شرکت فعال (`/api/meeting-minutes/{id}/print`)
  Future<Uint8List> downloadPrintPdf(int minutesId) async {
    await ensureCompany();
    final bytes = await _api.getBytes('$_root/$minutesId/print');
    if (bytes.isEmpty) {
      throw ApiException(
        'خروجی PDF از سرور دریافت نشد. لطفاً وضعیت سربرگ شرکت فعال را بررسی کنید.',
      );
    }
    return bytes;
  }

  // ================== پیوست‌ها (`/api/attachments/MeetingMinutes/{id}`) ==================

  Future<List<MinutesAttachment>> fetchAttachments(int minutesId) async {
    await ensureCompany();
    final r = await _api.get<dynamic>(
      '/api/attachments/MeetingMinutes/$minutesId',
    );
    final data = r.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => MinutesAttachment.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  Future<void> uploadAttachment(
    int minutesId, {
    required String fileName,
    required Uint8List bytes,
  }) async {
    await ensureCompany();
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    await _api.postForm<dynamic>(
      '/api/attachments/MeetingMinutes/$minutesId',
      form,
    );
  }

  Future<Uint8List> downloadAttachment(int attachmentId) async {
    await ensureCompany();
    final bytes = await _api.getBytes('/api/attachments/download/$attachmentId');
    if (bytes.isEmpty) {
      throw ApiException('فایل پیوست خالی است یا اجازهٔ دانلود ندارید.');
    }
    return bytes;
  }

  Future<void> deleteAttachment(int attachmentId) async {
    await ensureCompany();
    await _api.delete<dynamic>('/api/attachments/$attachmentId');
  }
}
