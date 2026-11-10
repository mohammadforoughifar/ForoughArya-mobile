// ============================================================
//  ریپازیتوری سامانه فروشگاهی — فقط همان چیزهایی که در وب هست
//
//  مسیرها دقیقاً از سورس سرور برداشته شده‌اند:
//    GET    /api/parties?type&skip&take          فهرست طرف حساب‌ها
//    POST   /api/parties                         ایجاد/ویرایش طرف حساب
//    DELETE /api/parties/{id}?type=…             حذف
//    GET    /api/parties/statements-summary      خلاصهٔ طلب و بدهی
//    GET    /api/parties/{id}/statement          گردش حساب یک شخص
//    GET    /api/referrers?…                     معرف‌ها (فقط برای انتخابگر فرم)
//
//  دسترسی‌ها سمت سرور اعمال می‌شوند (Customers/Suppliers/Parties)؛ کلاینت
//  هیچ دور زدنی ندارد و فقط خطای ۴۰۳ سرور را فارسی نشان می‌دهد.
// ============================================================

import '../../../core/network/api_client.dart';
import '../models/shop_models.dart';

/// پاسخ صفحه‌بندی‌شده: یا آرایه است یا { total, items } (وقتی skip/take بفرستیم)
class ShopPage<T> {
  const ShopPage({required this.items, this.total});
  final List<T> items;
  final int? total;

  bool get hasMore => total != null && items.length < total!;

  static ShopPage<T> parse<T>(
    dynamic data,
    T Function(Map<String, dynamic>) map,
  ) {
    if (data is List) {
      final items = data
          .whereType<Map>()
          .map((e) => map(Map<String, dynamic>.from(e)))
          .toList();
      return ShopPage(items: items, total: items.length);
    }
    if (data is Map) {
      final raw = data['items'] ?? data['Items'] ?? data['data'];
      final list = raw is List
          ? raw
                .whereType<Map>()
                .map((e) => map(Map<String, dynamic>.from(e)))
                .toList()
          : <T>[];
      final total = (data['total'] ?? data['Total'] as num?)?.toInt();
      return ShopPage(items: list, total: total);
    }
    return const ShopPage(items: [], total: 0);
  }
}

class ShopRepository {
  ShopRepository(this._api);

  final ApiClient _api;

  // ------------------------------------------------------------
  //  طرف حساب‌ها (مشتری / تأمین‌کننده)
  // ------------------------------------------------------------
  Future<ShopPage<Party>> parties({
    required int type,
    int skip = 0,
    int take = 50,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/parties',
      query: {'type': type, 'skip': skip, 'take': take},
    );
    return ShopPage.parse(r.data, Party.fromJson);
  }

  Future<Party> saveParty(Party p) async {
    final r = await _api.post<dynamic>('/api/parties', p.toJson());
    final d = r.data;
    return d is Map ? Party.fromJson(Map<String, dynamic>.from(d)) : p;
  }

  Future<void> deleteParty(int id, {required int type}) =>
      _api.delete<dynamic>('/api/parties/$id?type=$type');

  /// گزارش طلب و بدهی اشخاص — همان `GET /api/parties/statements-summary`
  /// پاسخ کامل (کارت‌های شاخص + فهرست اشخاص) برای صفحهٔ گزارش برگردانده می‌شود.
  Future<Map<String, dynamic>> statementReport({
    int? type,
    DateTime? from,
    DateTime? to,
    String? search,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/parties/statements-summary',
      query: {
        if (type != null) 'type': type,
        if (from != null) 'from': _dateOnly(from),
        if (to != null) 'to': _dateOnly(to),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    final d = r.data;
    return d is Map ? Map<String, dynamic>.from(d) : const {};
  }

  /// `yyyy-MM-dd` — سرور `DateTime?` می‌گیرد؛ ساعت نباید منطقهٔ زمانی را جابه‌جا کند.
  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// خلاصهٔ گزارش طلب و بدهی (برای سرصفحهٔ گزارش)
  Future<PartyStatementSummary> statementsSummary({
    int? type,
    DateTime? from,
    DateTime? to,
    String? search,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/parties/statements-summary',
      query: {
        if (type != null) 'type': type,
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    final d = r.data;
    return d is Map
        ? PartyStatementSummary.fromJson(Map<String, dynamic>.from(d))
        : const PartyStatementSummary();
  }

  /// گردش حساب یک شخص (صورتحساب) — همان صفحهٔ «گزارش طلب و بدهی» وب
  Future<Map<String, dynamic>> partyStatement(
    int id, {
    DateTime? from,
    DateTime? to,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/parties/$id/statement',
      query: {
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
      },
    );
    final d = r.data;
    return d is Map ? Map<String, dynamic>.from(d) : const {};
  }

  /// معرف‌ها — فقط برای پر کردن انتخابگر «معرف» در فرم مشتری
  Future<List<Referrer>> referrers({String? search}) async {
    try {
      final r = await _api.get<dynamic>(
        '/api/referrers',
        query: {
          'take': 200,
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
        },
      );
      final page = ShopPage.parse(r.data, Referrer.fromJson);
      return page.items;
    } on ApiException {
      // نبود مجوز «معرف‌ها» نباید ثبت مشتری را ببندد؛ سرور خودش
      // پروندهٔ معرفِ ویزیتور را تعیین می‌کند.
      return const [];
    }
  }
}
