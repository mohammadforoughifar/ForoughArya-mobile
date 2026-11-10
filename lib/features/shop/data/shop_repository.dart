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

import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/order_models.dart';
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

  // ------------------------------------------------------------
  //  فاز ۲ — اطلاعات پایه: کالا، گروه، واحد، انبار + موجودی
  // ------------------------------------------------------------

  /// `GET /api/products?search&below&page&pageSize`
  Future<ShopPage<Product>> products({
    String? search,
    bool below = false,
    int page = 1,
    int pageSize = 12,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/products',
      query: {
        'search': (search ?? '').trim(),
        'below': below,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return ShopPage.parse(r.data, Product.fromJson);
  }

  /// `GET /api/products/lookups` — فقط کد و نام، برای انتخابگرها
  Future<List<ShopLookup>> productLookups() async {
    final r = await _api.get<dynamic>('/api/products/lookups');
    return ShopPage.parse(r.data, ShopLookup.fromJson).items;
  }

  Future<Product> saveProduct(Product p) async {
    final r = await _api.post<dynamic>('/api/products', p.toJson());
    final d = r.data;
    return d is Map ? Product.fromJson(Map<String, dynamic>.from(d)) : p;
  }

  Future<void> deleteProduct(int id) => _api.delete<dynamic>('/api/products/$id');

  /// `GET /api/products/import/template` — فایل اکسل نمونه
  Future<Uint8List> productTemplate() =>
      _api.getBytes('/api/products/import/template');

  /// `POST /api/products/import?warehouseId=…` با فایل xlsx
  Future<Map<String, dynamic>> importProducts(
    Uint8List bytes,
    String fileName, {
    required int warehouseId,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    final r = await _api.postForm<dynamic>(
      '/api/products/import?warehouseId=$warehouseId',
      form,
    );
    final d = r.data;
    return d is Map ? Map<String, dynamic>.from(d) : const {};
  }

  /// `GET /api/categories?activeOnly`
  Future<List<ProductCategory>> categories({bool activeOnly = false}) async {
    final r = await _api.get<dynamic>(
      '/api/categories',
      query: {'activeOnly': activeOnly},
    );
    return ShopPage.parse(r.data, ProductCategory.fromJson).items;
  }

  Future<ProductCategory> saveCategory(ProductCategory c) async {
    final r = await _api.post<dynamic>('/api/categories', c.toJson());
    final d = r.data;
    return d is Map ? ProductCategory.fromJson(Map<String, dynamic>.from(d)) : c;
  }

  Future<void> deleteCategory(int id) =>
      _api.delete<dynamic>('/api/categories/$id');

  /// `GET /api/units?activeOnly&search`
  Future<ShopPage<MeasureUnit>> units({
    bool activeOnly = false,
    String? search,
    int skip = 0,
    int take = 200,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/units',
      query: {
        'activeOnly': activeOnly,
        'skip': skip,
        'take': take,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return ShopPage.parse(r.data, MeasureUnit.fromJson);
  }

  Future<MeasureUnit> saveUnit(MeasureUnit u) async {
    final r = await _api.post<dynamic>('/api/units', u.toJson());
    final d = r.data;
    return d is Map ? MeasureUnit.fromJson(Map<String, dynamic>.from(d)) : u;
  }

  Future<void> deleteUnit(int id) => _api.delete<dynamic>('/api/units/$id');

  /// `GET /api/warehouses?skip&take`
  Future<ShopPage<Warehouse>> warehouses({
    int skip = 0,
    int take = 200,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/warehouses',
      query: {'skip': skip, 'take': take},
    );
    return ShopPage.parse(r.data, Warehouse.fromJson);
  }

  Future<Warehouse> saveWarehouse(Warehouse w) async {
    final r = await _api.post<dynamic>('/api/warehouses', w.toJson());
    final d = r.data;
    return d is Map ? Warehouse.fromJson(Map<String, dynamic>.from(d)) : w;
  }

  Future<void> deleteWarehouse(int id) =>
      _api.delete<dynamic>('/api/warehouses/$id');

  /// `GET /api/stock?warehouseId&search&below&page&pageSize`
  Future<ShopPage<StockItem>> stock({
    int? warehouseId,
    String? search,
    bool below = false,
    int page = 1,
    int pageSize = 15,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/stock',
      query: {
        if (warehouseId != null && warehouseId > 0) 'warehouseId': warehouseId,
        'search': (search ?? '').trim(),
        'below': below,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return ShopPage.parse(r.data, StockItem.fromJson);
  }

  /// `POST /api/stock/adjust` — تعدیل انبارگردانی
  Future<void> adjustStock({
    required int warehouseId,
    required int productId,
    required double quantity,
    DateTime? date,
    String? description,
  }) => _api.post<dynamic>('/api/stock/adjust', {
    'warehouseId': warehouseId,
    'productId': productId,
    'quantity': quantity,
    'date': (date ?? DateTime.now()).toIso8601String(),
    'description': _nullIfEmptyStr(description),
  });

  static String? _nullIfEmptyStr(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();

  // ------------------------------------------------------------
  //  فاز ۳ — اسناد خرید و فروش (api/orders)
  // ------------------------------------------------------------

  /// `GET /api/orders?type&from&to&partyId&warehouseId&page&pageSize`
  Future<ShopPage<ShopOrder>> orders({
    required int type,
    DateTime? from,
    DateTime? to,
    int? partyId,
    int? warehouseId,
    int page = 1,
    int pageSize = 15,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/orders',
      query: {
        'type': type,
        if (from != null) 'from': _dateOnly(from),
        if (to != null) 'to': _dateOnly(to),
        if (partyId != null && partyId > 0) 'partyId': partyId,
        if (warehouseId != null && warehouseId > 0) 'warehouseId': warehouseId,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return ShopPage.parse(r.data, ShopOrder.fromJson);
  }

  /// `GET /api/orders/{id}` — سند کامل همراه اقلام/چک‌ها/اقساط
  Future<ShopOrder?> order(int id) async {
    final r = await _api.get<dynamic>('/api/orders/$id');
    final d = r.data;
    return d is Map ? ShopOrder.fromJson(Map<String, dynamic>.from(d)) : null;
  }

  /// `POST /api/orders` — ثبت سند جدید
  Future<ShopOrder> createOrder(Map<String, dynamic> cmd) async {
    final r = await _api.post<dynamic>('/api/orders', cmd);
    final d = r.data;
    return d is Map ? ShopOrder.fromJson(Map<String, dynamic>.from(d)) : ShopOrder();
  }

  /// `PUT /api/orders/{id}` — ویرایش سند
  Future<ShopOrder> updateOrder(int id, Map<String, dynamic> cmd) async {
    final r = await _api.put<dynamic>('/api/orders/$id', cmd);
    final d = r.data;
    return d is Map ? ShopOrder.fromJson(Map<String, dynamic>.from(d)) : ShopOrder();
  }

  Future<void> deleteOrder(int id) => _api.delete<dynamic>('/api/orders/$id');

  /// `GET /api/orders/last-purchase?productId`
  Future<ShopOrder?> lastPurchase(int productId) async {
    final r = await _api.get<dynamic>(
      '/api/orders/last-purchase',
      query: {'productId': productId},
    );
    final d = r.data;
    return d is Map ? ShopOrder.fromJson(Map<String, dynamic>.from(d)) : null;
  }

  // ---------- حساب‌های خزانه (برای بخش پرداخت سند) ----------

  /// `GET /api/trs/accounts?activeOnly`
  Future<List<TrsAccount>> trsAccounts({bool activeOnly = true}) async {
    final r = await _api.get<dynamic>(
      '/api/trs/accounts',
      query: {'activeOnly': activeOnly, 'withBalances': false},
    );
    return ShopPage.parse(r.data, TrsAccount.fromJson).items;
  }

  /// `POST /api/trs/accounts` — تعریف سریع بانک/صندوق از داخل فرم سند
  Future<TrsAccount> saveTrsAccount(TrsAccount a) async {
    final r = await _api.post<dynamic>('/api/trs/accounts', a.toJson());
    final d = r.data;
    return d is Map ? TrsAccount.fromJson(Map<String, dynamic>.from(d)) : a;
  }
}
