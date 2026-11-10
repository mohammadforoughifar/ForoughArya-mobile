import 'dart:typed_data';
// ============================================================
//  ماژول اتوماسیون اداری — لایهٔ دسترسی به API
//  مسیرها عیناً از کنترلرهای بک‌اند:
//    InnerLettersController     → /api/letters
//    OutgoingLettersController  → /api/outgoing-letters
//    IncomingLettersController  → /api/incoming-letters
//  (TotallCollectionSoftware/src/Inventory.Api/Controllers/Office)
// ============================================================

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/letter_models.dart';
import '../models/office_common.dart';

class OfficeAutomationRepository {
  OfficeAutomationRepository(this._api);
  final ApiClient _api;

  static const innerRoot = '/api/letters';
  static const outgoingRoot = '/api/outgoing-letters';
  static const incomingRoot = '/api/incoming-letters';

  // ------------------------------------------------------------
  //  کمکی‌ها
  // ------------------------------------------------------------

  /// پارامترهای استاندارد صفحه‌بندی بک‌اند (skip/take یا page/pageSize)
  Map<String, dynamic> _page({int page = 1, int pageSize = 20, String? search, bool? unreadOnly}) => {
    'page': page,
    'pageSize': pageSize,
    if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    if (unreadOnly == true) 'unreadOnly': true,
    'skip': (page - 1) * pageSize,
    'take': pageSize,
  };

  Paged<LetterListItem> _list(dynamic data) =>
      Paged.fromJson(data, LetterListItem.fromJson);

  List<LetterRecipient> _recipients(dynamic data) {
    final raw = data is List ? data : (asMap(data)['items'] ?? data);
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => LetterRecipient.fromJson(asMap(e))).toList();
  }

  // ------------------------------------------------------------
  //  آمار دقیق هر کارتابل — با خواندن صفحهٔ اول خودِ لیست
  //  (سرور همیشه totalCount را برمی‌گرداند؛ اگر نداد طول همان صفحه)
  // ------------------------------------------------------------

  Future<int> _count(Future<int> Function() f) async {
    try {
      return await f();
    } catch (_) {
      return 0;
    }
  }

  Future<int> _pagedCount(Future<Paged<dynamic>> Function() f) async {
    final p = await f();
    return p.totalCount > 0 ? p.totalCount : p.items.length;
  }

  /// شمارش واقعی هر کارتابل یک ماژول — از خودِ endpoint همان کارتابل.
  /// (آمار /stats سرور همهٔ کلیدها را برنمی‌گرداند؛ همین باعث صفر شدن
  /// عدد دریافتی/ارسالی روی کارت داشبورد شده بود.)
  Future<ModuleMailboxCounts> mailboxCounts(LetterKind kind) async {
    final inbox = _count(
      () => _pagedCount(() => switch (kind) {
        LetterKind.inner => innerInbox(pageSize: 50),
        LetterKind.outgoing => outgoingInbox(pageSize: 50),
        LetterKind.incoming => incomingInbox(pageSize: 50),
      }),
    );
    final sent = _count(
      () => _pagedCount(() => switch (kind) {
        LetterKind.inner => innerSent(pageSize: 50),
        LetterKind.outgoing => outgoingSent(pageSize: 50),
        LetterKind.incoming => incomingSent(pageSize: 50),
      }),
    );
    final draftsCount = _count(
      () => _pagedCount(() => drafts(kind)),
    );
    final archive = _count(
      () => _pagedCount(() => switch (kind) {
        LetterKind.inner => innerArchive(pageSize: 50),
        LetterKind.outgoing => outgoingArchive(pageSize: 50),
        LetterKind.incoming => incomingArchive(pageSize: 50),
      }),
    );
    final signing = kind == LetterKind.outgoing
        ? await _count(() => _pagedCount(() => signingInbox(pageSize: 50)))
        : 0;
    final dabir = kind == LetterKind.outgoing
        ? await _count(() => _pagedCount(() => dabirkhane(pageSize: 50)))
        : 0;
    return ModuleMailboxCounts(
      inbox: await inbox,
      sent: await sent,
      drafts: await draftsCount,
      archive: await archive,
      signing: signing,
      dabirkhane: dabir,
    );
  }

  // ------------------------------------------------------------
  //  آمار — GET /stats روی هر سه کارتابل
  // ------------------------------------------------------------

  Future<InboxStats> innerStats() async =>
      InboxStats.fromJson(asMap((await _api.get('$innerRoot/stats')).data));

  Future<InboxStats> outgoingStats() async =>
      InboxStats.fromJson(asMap((await _api.get('$outgoingRoot/stats')).data));

  Future<InboxStats> incomingStats() async =>
      InboxStats.fromJson(asMap((await _api.get('$incomingRoot/stats')).data));

  /// جمع آمار سه کارتابل — برای داشبورد؛ خطاها نادیده گرفته می‌شوند
  /// (اگر کاربر مجوز یک ماژول را نداشته باشد، بقیه باید نمایش داده شوند)
  Future<AutomationStats> dashboardStats() async {
    var total = const AutomationStats();
    Future<void> collect(Future<InboxStats> Function() f) async {
      try {
        total = total.merge(await f());
      } catch (_) {}
    }

    await Future.wait([collect(innerStats), collect(outgoingStats), collect(incomingStats)]);
    return total;
  }

  // ------------------------------------------------------------
  //  نامهٔ داخلی — /api/letters
  // ------------------------------------------------------------

  Future<Paged<LetterListItem>> innerInbox({
    int page = 1,
    int pageSize = 20,
    String? search,
    bool? unreadOnly,
  }) async => _list(
    (await _api.get('$innerRoot/inbox',
            query: _page(page: page, pageSize: pageSize, search: search, unreadOnly: unreadOnly)))
        .data,
  );

  Future<Paged<LetterListItem>> innerSent({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async => _list(
    (await _api.get('$innerRoot/sent',
            query: _page(page: page, pageSize: pageSize, search: search)))
        .data,
  );

  Future<Paged<LetterListItem>> innerArchive({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async => _list(
    (await _api.get('$innerRoot/archive',
            query: _page(page: page, pageSize: pageSize, search: search)))
        .data,
  );

  Future<InnerLetterDetail> innerDetail(int id) async =>
      InnerLetterDetail.fromJson(asMap((await _api.get('$innerRoot/$id')).data));

  /// پیش‌نمایش چاپ — GET /{id}/print (HTML یا PDF از سرور)
  Future<Response<List<int>>> innerPrint(int id, {String size = 'A4', bool withHamesh = false}) =>
      _api.request<List<int>>(
        'GET',
        '$innerRoot/$id/print',
        query: {'size': size, 'withHamesh': withHamesh},
        options: Options(responseType: ResponseType.bytes),
      );

  Future<int> createInner(Map<String, dynamic> body) async {
    final r = await _api.post(innerRoot, body);
    return _idOf(r.data);
  }

  Future<void> editInner(int id, Map<String, dynamic> body) =>
      _api.put('$innerRoot/$id', body);

  Future<void> deleteInner(int id) => _api.delete('$innerRoot/$id');

  Future<void> toggleInnerNeshan(int id) => _api.post('$innerRoot/$id/neshan');

  // ------------------------------------------------------------
  //  نامهٔ صادره — /api/outgoing-letters
  // ------------------------------------------------------------

  Future<Paged<LetterListItem>> outgoingInbox({
    int page = 1,
    int pageSize = 20,
    String? search,
    bool? unreadOnly,
  }) async => _list(
    (await _api.get('$outgoingRoot/inbox',
            query: _page(page: page, pageSize: pageSize, search: search, unreadOnly: unreadOnly)))
        .data,
  );

  /// کارتابل امضا — نامه‌هایی که باید امضا شوند
  Future<Paged<LetterListItem>> signingInbox({
    int page = 1,
    int pageSize = 20,
    String? search,
    bool unsignedOnly = true,
  }) async => _list(
    (await _api.get(outgoingRoot + '/signing-inbox',
            query: {
              ..._page(page: page, pageSize: pageSize, search: search),
              'unsignedOnly': unsignedOnly,
            }))
        .data,
  );

  Future<Paged<LetterListItem>> outgoingSent({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async => _list(
    (await _api.get('$outgoingRoot/sent',
            query: _page(page: page, pageSize: pageSize, search: search)))
        .data,
  );

  Future<Paged<LetterListItem>> outgoingArchive({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async => _list(
    (await _api.get('$outgoingRoot/archive',
            query: _page(page: page, pageSize: pageSize, search: search)))
        .data,
  );

  /// کارتابل دبیرخانه
  Future<Paged<LetterListItem>> dabirkhane({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async => _list(
    (await _api.get(outgoingRoot + '/dabirkhane',
            query: _page(page: page, pageSize: pageSize, search: search)))
        .data,
  );

  Future<OutgoingLetterDetail> outgoingDetail(int id) async =>
      OutgoingLetterDetail.fromJson(asMap((await _api.get('$outgoingRoot/$id')).data));

  Future<int> createOutgoing(Map<String, dynamic> body) async {
    final r = await _api.post(outgoingRoot, body);
    return _idOf(r.data);
  }

  Future<void> editOutgoing(int id, Map<String, dynamic> body) =>
      _api.put('$outgoingRoot/$id', body);

  Future<void> deleteOutgoing(int id) => _api.delete('$outgoingRoot/$id');

  Future<void> updateOutgoingStatus(int id, int status) =>
      _api.post('$outgoingRoot/$id/status', {'status': status});

  /// امضای نامه — POST /{id}/sign  (SadereNumber بعد از آخرین امضا صادر می‌شود)
  Future<void> signOutgoing(int id, {String? note}) =>
      _api.post('$outgoingRoot/$id/sign', {'signNote': note ?? ''});

  Future<List<OutgoingSigner>> signers(int id) async {
    final r = await _api.get('$outgoingRoot/$id/signers');
    final raw = r.data is List ? r.data : (asMap(r.data)['items'] ?? []);
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => OutgoingSigner.fromJson(asMap(e))).toList();
  }

  Future<List<CopyToPerson>> copyTos(int id) async {
    final r = await _api.get('$outgoingRoot/$id/copy-tos');
    final raw = r.data is List ? r.data : (asMap(r.data)['items'] ?? []);
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => CopyToPerson.fromJson(asMap(e))).toList();
  }

  /// امضاکنندگان مجاز — فقط کاربران دارای مجوز OutgoingLetters.Sign
  Future<List<LetterRecipient>> availableSigners({String? search}) async =>
      _recipients((await _api.get('$outgoingRoot/available-signers',
              query: {'take': 500, if (search != null) 'search': search}))
          .data);

  /// ثبت در دبیرخانه و ارسال
  Future<void> dabirkhaneRegister(int id, Map<String, dynamic> body) =>
      _api.post('$outgoingRoot/$id/dabirkhane', body);

  Future<Response<List<int>>> outgoingPrint(int id, {String size = 'A4', bool withCopy = true}) =>
      _api.request<List<int>>(
        'GET',
        '$outgoingRoot/$id/print',
        query: {'size': size, 'withCopy': withCopy},
        options: Options(responseType: ResponseType.bytes),
      );

  /// شرکت‌های صادرکننده (سربرگ چاپ)
  Future<List<Map<String, dynamic>>> companies() async {
    final r = await _api.get('$outgoingRoot/companies', query: {'take': 200});
    final raw = r.data is List ? r.data : (asMap(r.data)['items'] ?? []);
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => asMap(e)).toList();
  }

  // ------------------------------------------------------------
  //  نامهٔ وارده — /api/incoming-letters
  // ------------------------------------------------------------

  Future<Paged<LetterListItem>> incomingInbox({
    int page = 1,
    int pageSize = 20,
    String? search,
    bool? unreadOnly,
  }) async => _list(
    (await _api.get('$incomingRoot/inbox',
            query: _page(page: page, pageSize: pageSize, search: search, unreadOnly: unreadOnly)))
        .data,
  );

  Future<Paged<LetterListItem>> incomingSent({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async => _list(
    (await _api.get('$incomingRoot/sent',
            query: _page(page: page, pageSize: pageSize, search: search)))
        .data,
  );

  Future<Paged<LetterListItem>> incomingArchive({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async => _list(
    (await _api.get('$incomingRoot/archive',
            query: _page(page: page, pageSize: pageSize, search: search)))
        .data,
  );

  Future<Map<String, dynamic>> incomingDetailRaw(int id) async =>
      asMap((await _api.get('$incomingRoot/$id')).data);

  Future<int> createIncoming(Map<String, dynamic> body) async {
    final r = await _api.post(incomingRoot, body);
    return _idOf(r.data);
  }

  Future<void> finalizeIncoming(int id) => _api.post('$incomingRoot/$id/finalize');

  Future<void> editIncoming(int id, Map<String, dynamic> body) =>
      _api.put('$incomingRoot/$id', body);

  Future<void> deleteIncoming(int id) => _api.delete('$incomingRoot/$id');

  Future<void> toggleIncomingNeshan(int id) => _api.post('$incomingRoot/$id/neshan');

  Future<void> toggleIncomingBayegani(int id) => _api.post('$incomingRoot/$id/bayegani');

  /// رزرو شماره اندیکاتور — POST /reserve-number (typeForm: 1=داخلی 2=صادره 3=وارده)
  Future<String?> reserveNumber(int typeForm) async {
    final r = await _api.post('$incomingRoot/reserve-number', {
      'typeForm': typeForm,
      'sematId': null,
    });
    final j = asMap(r.data);
    return pickStrN(j, ['letterNumber', 'LetterNumber', 'number', 'Number']) ??
        (pick(j, ['numberSabt', 'NumberSabt']) ?? '').toString();
  }

  Future<List<Map<String, dynamic>>> reservations(int typeForm) async {
    final r = await _api.get('$incomingRoot/reservations', query: {'typeForm': typeForm});
    final raw = r.data is List ? r.data : (asMap(r.data)['items'] ?? []);
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => asMap(e)).toList();
  }

  // ------------------------------------------------------------
  //  ارجاع و گردش — مشترک هر سه نوع نامه
  //  مسیرها یکسان‌اند؛ فقط ریشه فرق می‌کند.
  // ------------------------------------------------------------

  String _rootOf(LetterKind kind) => switch (kind) {
    LetterKind.inner => innerRoot,
    LetterKind.outgoing => outgoingRoot,
    LetterKind.incoming => incomingRoot,
  };

  /// ثبت ارجاع جدید — POST /erja
  Future<void> addErja(
    LetterKind kind, {
    required int letterId,
    required List<int> receivers,
    List<int> hamesh = const [],
    List<int> groups = const [],
    List<int> groupsHamesh = const [],
    String text = '',
    int amalgarId = 1,
    DateTime? deadline,
    int? parentErjaId,
    bool allowDuplicates = false,
  }) => _api.post('${_rootOf(kind)}/erja', {
    'letterId': letterId,
    if (parentErjaId != null) 'parentErjaId': parentErjaId,
    'textErja': text,
    'amalgarId': amalgarId,
    'deadlineAnswer': deadline?.toIso8601String(),
    'allowDuplicateRecipients': allowDuplicates,
    'reciversGirandegan': receivers,
    'reciversHamesh': hamesh,
    'groupsGirandegan': groups,
    'groupsHamesh': groupsHamesh,
  });

  /// پاسخ به ارجاع — POST /erja/{erjaId}/answer
  Future<void> answerErja(
    LetterKind kind, {
    required int erjaId,
    required String answer,
    int typeTaeed = 0,
    bool showForAll = false,
  }) => _api.post('${_rootOf(kind)}/erja/$erjaId/answer', {
    'answer': answer,
    'typeTaeed': typeTaeed,
    'showForAll': showForAll,
  });

  Future<void> markErjaRead(LetterKind kind, int erjaId) =>
      _api.post('${_rootOf(kind)}/erja/$erjaId/read');

  Future<void> toggleErjaNeshan(LetterKind kind, int erjaId) =>
      _api.post('${_rootOf(kind)}/erja/$erjaId/neshan');

  Future<void> toggleErjaBayegani(LetterKind kind, int erjaId) =>
      _api.post('${_rootOf(kind)}/erja/$erjaId/bayegani');

  Future<void> batchBayegani(LetterKind kind, List<int> erjaIds, {String? description}) =>
      _api.post('${_rootOf(kind)}/erja/batch-bayegani', {
        'erjaIds': erjaIds,
        'description': description,
      });

  /// گردش نامه (درخت ارجاع‌ها) — GET /{id}/gardesh
  Future<List<GardeshNode>> gardesh(LetterKind kind, int letterId) async {
    final r = await _api.get('${_rootOf(kind)}/$letterId/gardesh', query: {'take': 500});
    final raw = r.data is List ? r.data : (asMap(r.data)['items'] ?? []);
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => GardeshNode.fromJson(asMap(e))).toList();
  }

  // ------------------------------------------------------------
  //  گیرندگان، گروه‌ها، عملگرها
  // ------------------------------------------------------------

  Future<List<LetterRecipient>> recipients(LetterKind kind, {String? search}) async =>
      _recipients((await _api.get('${_rootOf(kind)}/recivers',
              query: {'take': 1000, if (search != null) 'search': search}))
          .data);

  Future<List<LetterGroup>> groups(LetterKind kind) async {
    final r = await _api.get('${_rootOf(kind)}/groups', query: {'withMembers': true});
    final raw = r.data is List ? r.data : (asMap(r.data)['items'] ?? []);
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => LetterGroup.fromJson(asMap(e))).toList();
  }

  Future<List<Amalgar>> amalgars(LetterKind kind) async {
    final r = await _api.get('${_rootOf(kind)}/amalgars', query: {'take': 100});
    final raw = r.data is List ? r.data : (asMap(r.data)['items'] ?? []);
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Amalgar.fromJson(asMap(e))).toList();
  }

  // ------------------------------------------------------------
  //  پیوست‌ها — هر سه نوع
  // ------------------------------------------------------------

  Future<List<LetterAttachment>> attachments(LetterKind kind, int id) async {
    final r = await _api.get('${_rootOf(kind)}/$id/attachments', query: {'take': 200});
    final raw = r.data is List ? r.data : (asMap(r.data)['items'] ?? []);
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => LetterAttachment.fromJson(asMap(e))).toList();
  }

  /// آپلود پیوست — IFormFile، حداکثر ۲۰ مگابایت (قاعدهٔ سرور)
  Future<void> uploadAttachment(
    LetterKind kind,
    int id,
    String filePath,
    String fileName, {
    Uint8List? bytes,
  }) async {
    final file = bytes != null
        ? MultipartFile.fromBytes(bytes, filename: fileName)
        : await MultipartFile.fromFile(filePath, filename: fileName);
    final form = FormData.fromMap({'file': file});
    await _api.request('POST', '${_rootOf(kind)}/$id/attachments', data: form);
  }

  Future<List<int>> downloadAttachment(LetterKind kind, int attId) async {
    final r = await _api.request<List<int>>(
      'GET',
      '${_rootOf(kind)}/attachments/$attId/download',
      options: Options(responseType: ResponseType.bytes),
    );
    return r.data ?? const [];
  }

  Future<void> deleteAttachment(LetterKind kind, int attId) =>
      _api.delete('${_rootOf(kind)}/attachments/$attId');

  // ------------------------------------------------------------
  //  پیش‌نویس — GET/POST/DELETE /pishnevis
  // ------------------------------------------------------------

  Future<Paged<DraftLetter>> drafts(LetterKind kind, {String? search}) async =>
      Paged.fromJson(
        (await _api.get('${_rootOf(kind)}/pishnevis',
                query: {'take': 200, if (search != null) 'search': search}))
            .data,
        DraftLetter.fromJson,
      );

  Future<void> saveDraft(LetterKind kind, Map<String, dynamic> body) =>
      _api.post('${_rootOf(kind)}/pishnevis', body);

  Future<void> deleteDraft(LetterKind kind, int id) =>
      _api.delete('${_rootOf(kind)}/pishnevis/$id');

  // ------------------------------------------------------------
  //  بایگانی درختی — /bayegani/*
  // ------------------------------------------------------------

  Future<Response<dynamic>> archiveTree(LetterKind kind) =>
      _api.get('${_rootOf(kind)}/bayegani/tree', query: {'take': 2000});

  /// ایجاد پوشهٔ اصلی / زیرپوشه
  Future<void> addArchiveFolder(LetterKind kind, String title, {bool sub = false, int parentId = 0}) =>
      _api.post(
        '${_rootOf(kind)}/bayegani/${sub ? 'sub-category' : 'main-category'}',
        {'title': title, 'parentId': parentId, 'typeBayegani': 1},
      );

  Future<void> renameArchiveFolder(LetterKind kind, int id, String title) =>
      _api.put('${_rootOf(kind)}/bayegani/folder/$id', {
        'title': title,
        'parentId': 0,
        'typeBayegani': 1,
      });

  Future<void> deleteArchiveFolder(LetterKind kind, int id) =>
      _api.delete('${_rootOf(kind)}/bayegani/$id');

  /// بایگانی کردن نامه‌ها در پوشه
  Future<void> archiveLetters(
    LetterKind kind, {
    required int folderId,
    List<int> erjaIds = const [],
    List<int> letterIds = const [],
    String? title,
  }) => _api.post('${_rootOf(kind)}/bayegani/letters', {
    'folderId': folderId,
    'erjaIds': erjaIds,
    'letterIds': letterIds,
    'outgoingLetterIds': letterIds,
    if (title != null) 'title': title,
  });

  // ------------------------------------------------------------
  //  انتخاب نامه برای عطف/پیرو — GET /pick
  // ------------------------------------------------------------

  Future<Paged<LetterListItem>> pickLetters(
    LetterKind kind, {
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async => _list(
    (await _api.get('${_rootOf(kind)}/pick',
            query: _page(page: page, pageSize: pageSize, search: search)))
        .data,
  );

  // ------------------------------------------------------------
  //  کمکی
  // ------------------------------------------------------------

  int _idOf(dynamic data) {
    if (data is num) return data.toInt();
    final j = asMap(data);
    return pickInt(j, ['id', 'Id', 'letterId', 'LetterId', 'sourceId', 'SourceId']);
  }
}

/// نوع نامه — تعیین می‌کند کدام ریشهٔ API استفاده شود
enum LetterKind {
  inner('نامه داخلی', '/api/letters'),
  outgoing('نامه صادره', '/api/outgoing-letters'),
  incoming('نامه وارده', '/api/incoming-letters');

  const LetterKind(this.label, this.root);
  final String label;
  final String root;
}
