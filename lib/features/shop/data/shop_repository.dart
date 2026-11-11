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
import '../models/ops_models.dart';
import '../models/order_models.dart';
import '../models/report_models.dart';
import '../models/treasury_models.dart';
import '../models/visit_models.dart';
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

  // ------------------------------------------------------------
  //  فاز ۴ — بیجک، تعمیرات، هزینه‌ها و گزارش‌های عملیات
  // ------------------------------------------------------------

  // ---------- بیجک (حوالهٔ تحویل کالا) ----------

  /// `GET /api/goods-issues?partyId&from&to&search` — پاسخ آرایه است
  Future<List<GoodsIssue>> goodsIssues({
    int? partyId,
    DateTime? from,
    DateTime? to,
    String? search,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/goods-issues',
      query: {
        if (partyId != null && partyId > 0) 'partyId': partyId,
        if (from != null) 'from': _dateOnly(from),
        if (to != null) 'to': _dateOnly(to),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return ShopPage.parse(r.data, GoodsIssue.fromJson).items;
  }

  /// `GET /api/goods-issues/{id}`
  Future<GoodsIssue?> goodsIssue(int id) async {
    final r = await _api.get<dynamic>('/api/goods-issues/$id');
    final d = r.data;
    return d is Map ? GoodsIssue.fromJson(Map<String, dynamic>.from(d)) : null;
  }

  /// `POST /api/goods-issues` — همان متد برای ثبت و ویرایش (Id در بدنه)
  Future<GoodsIssue> saveGoodsIssue(Map<String, dynamic> cmd) async {
    final r = await _api.post<dynamic>('/api/goods-issues', cmd);
    final d = r.data;
    return d is Map
        ? GoodsIssue.fromJson(Map<String, dynamic>.from(d))
        : GoodsIssue();
  }

  Future<void> deleteGoodsIssue(int id) =>
      _api.delete<dynamic>('/api/goods-issues/$id');

  // ---------- تعمیرات ----------

  /// `GET /api/repairs?search&status&technicianId&page&pageSize`
  Future<ShopPage<RepairOrder>> repairs({
    String? search,
    int? status,
    int? technicianId,
    int page = 1,
    int pageSize = 15,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/repairs',
      query: {
        'search': (search ?? '').trim(),
        if (status != null && status >= 0) 'status': status,
        if (technicianId != null && technicianId > 0)
          'technicianId': technicianId,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return ShopPage.parse(r.data, RepairOrder.fromJson);
  }

  /// `GET /api/repairs/{id}`
  Future<RepairOrder?> repair(int id) async {
    final r = await _api.get<dynamic>('/api/repairs/$id');
    final d = r.data;
    return d is Map ? RepairOrder.fromJson(Map<String, dynamic>.from(d)) : null;
  }

  /// `POST /api/repairs` — همان `RepairOrderDto` برای ثبت و ویرایش
  Future<RepairOrder> saveRepair(RepairOrder r0) async {
    final r = await _api.post<dynamic>('/api/repairs', r0.toJson());
    final d = r.data;
    return d is Map
        ? RepairOrder.fromJson(Map<String, dynamic>.from(d))
        : RepairOrder();
  }

  Future<void> deleteRepair(int id) => _api.delete<dynamic>('/api/repairs/$id');

  /// `POST /api/repairs/{id}/status/{status}`
  Future<RepairOrder> setRepairStatus(int id, int status) async {
    final r = await _api.post<dynamic>('/api/repairs/$id/status/$status');
    final d = r.data;
    return d is Map
        ? RepairOrder.fromJson(Map<String, dynamic>.from(d))
        : RepairOrder();
  }

  /// `POST /api/repairs/{id}/invoice` — صدور فاکتور فروش + تحویل دستگاه
  Future<RepairOrder> invoiceRepair(int id, Map<String, dynamic> request) async {
    final r = await _api.post<dynamic>('/api/repairs/$id/invoice', request);
    final d = r.data;
    return d is Map
        ? RepairOrder.fromJson(Map<String, dynamic>.from(d))
        : RepairOrder();
  }

  /// `GET /api/technicians?activeOnly` — پاسخ آرایه/صفحه
  Future<List<Technician>> technicians({bool activeOnly = false}) async {
    final r = await _api.get<dynamic>(
      '/api/technicians',
      query: {'activeOnly': activeOnly},
    );
    return ShopPage.parse(r.data, Technician.fromJson).items;
  }

  Future<Technician> saveTechnician(Technician t) async {
    final r = await _api.post<dynamic>('/api/technicians', t.toJson());
    final d = r.data;
    return d is Map ? Technician.fromJson(Map<String, dynamic>.from(d)) : t;
  }

  Future<void> deleteTechnician(int id) =>
      _api.delete<dynamic>('/api/technicians/$id');

  // ---------- هزینه‌ها ----------

  /// `GET /api/expenses?search&categoryId&from&to&page&pageSize`
  Future<ShopPage<ShopExpense>> expenses({
    String? search,
    int? categoryId,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 15,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/expenses',
      query: {
        'search': (search ?? '').trim(),
        if (categoryId != null && categoryId > 0) 'categoryId': categoryId,
        if (from != null) 'from': _dateOnly(from),
        if (to != null) 'to': _dateOnly(to),
        'page': page,
        'pageSize': pageSize,
      },
    );
    return ShopPage.parse(r.data, ShopExpense.fromJson);
  }

  Future<ShopExpense> saveExpense(ShopExpense e) async {
    final r = await _api.post<dynamic>('/api/expenses', e.toJson());
    final d = r.data;
    return d is Map ? ShopExpense.fromJson(Map<String, dynamic>.from(d)) : e;
  }

  Future<void> deleteExpense(int id) => _api.delete<dynamic>('/api/expenses/$id');

  /// `GET /api/expense-categories?activeOnly`
  Future<List<ExpenseCategory>> expenseCategories({
    bool activeOnly = false,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/expense-categories',
      query: {'activeOnly': activeOnly},
    );
    return ShopPage.parse(r.data, ExpenseCategory.fromJson).items;
  }

  Future<ExpenseCategory> saveExpenseCategory(ExpenseCategory c) async {
    final r = await _api.post<dynamic>('/api/expense-categories', c.toJson());
    final d = r.data;
    return d is Map
        ? ExpenseCategory.fromJson(Map<String, dynamic>.from(d))
        : c;
  }

  Future<void> deleteExpenseCategory(int id) =>
      _api.delete<dynamic>('/api/expense-categories/$id');

  // ---------- گزارش‌های عملیات ----------

  /// `GET /api/operations/reports/orders?type&from&to&partyId&warehouseId`
  Future<OrderReport> orderReport({
    required int type,
    DateTime? from,
    DateTime? to,
    int? partyId,
    int? warehouseId,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/operations/reports/orders',
      query: {
        'type': type,
        if (from != null) 'from': _dateOnly(from),
        if (to != null) 'to': _dateOnly(to),
        if (partyId != null && partyId > 0) 'partyId': partyId,
        if (warehouseId != null && warehouseId > 0) 'warehouseId': warehouseId,
      },
    );
    final d = r.data;
    return d is Map
        ? OrderReport.fromJson(Map<String, dynamic>.from(d))
        : const OrderReport();
  }

  /// `GET /api/operations/reports/dashboard?from&to`
  Future<OpsDashboard> opsDashboard({DateTime? from, DateTime? to}) async {
    final r = await _api.get<dynamic>(
      '/api/operations/reports/dashboard',
      query: {
        if (from != null) 'from': _dateOnly(from),
        if (to != null) 'to': _dateOnly(to),
      },
    );
    final d = r.data;
    return d is Map
        ? OpsDashboard.fromJson(Map<String, dynamic>.from(d))
        : const OpsDashboard();
  }

  // ------------------------------------------------------------
  //  فاز ۵ — خزانه، چک، اقساط و مانده‌های اولیه
  // ------------------------------------------------------------

  // ---------- صندوق / بانک / کارتخوان / تنخواه ----------

  /// `GET /api/trs/accounts?activeOnly&withBalances`
  Future<List<TreasuryAccount>> treasuryAccounts({
    bool activeOnly = false,
    bool withBalances = true,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/trs/accounts',
      query: {'activeOnly': activeOnly, 'withBalances': withBalances},
    );
    return ShopPage.parse(r.data, TreasuryAccount.fromJson).items;
  }

  /// `POST /api/trs/accounts`
  Future<TreasuryAccount> saveTreasuryAccount(TreasuryAccount a) async {
    final r = await _api.post<dynamic>('/api/trs/accounts', a.toJson());
    final d = r.data;
    return d is Map
        ? TreasuryAccount.fromJson(Map<String, dynamic>.from(d))
        : a;
  }

  /// `DELETE /api/trs/accounts/{id}`
  Future<void> deleteTreasuryAccount(int id) =>
      _api.delete<dynamic>('/api/trs/accounts/$id');

  /// `GET /api/acc/accounts/lookups?search` — حساب‌های معین قابل انتخاب
  Future<List<AccLookup>> accAccountLookups({String? search}) async {
    final r = await _api.get<dynamic>(
      '/api/acc/accounts/lookups',
      query: {if (search != null && search.isNotEmpty) 'search': search},
    );
    return ShopPage.parse(r.data, AccLookup.fromJson).items;
  }

  // ---------- اسناد دریافت / پرداخت / انتقال ----------

  /// `GET /api/trs/vouchers?kind&status&partyId&trsAccountId&search&from&to&page&pageSize`
  Future<ShopPage<TreasuryVoucher>> treasuryVouchers({
    int? kind,
    int? status,
    int? partyId,
    int? trsAccountId,
    String? search,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 15,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/trs/vouchers',
      query: {
        if (kind != null) 'kind': kind,
        if (status != null) 'status': status,
        if (partyId != null && partyId > 0) 'partyId': partyId,
        if (trsAccountId != null && trsAccountId > 0)
          'trsAccountId': trsAccountId,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (from != null) 'from': _dateOnly(from),
        if (to != null) 'to': _dateOnly(to),
        'page': page,
        'pageSize': pageSize,
      },
    );
    return ShopPage.parse(r.data, TreasuryVoucher.fromJson);
  }

  /// `GET /api/trs/vouchers/new?kind` — سند خالی با شمارهٔ بعدی از سرور
  Future<TreasuryVoucher> newVoucher({int kind = 0}) async {
    final r = await _api.get<dynamic>(
      '/api/trs/vouchers/new',
      query: {'kind': kind},
    );
    return TreasuryVoucher.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// `GET /api/trs/vouchers/settle/{invoiceId}` — سند تسویهٔ آمادهٔ فاکتور
  Future<TreasuryVoucher> settleVoucher(int invoiceId) async {
    final r = await _api.get<dynamic>('/api/trs/vouchers/settle/$invoiceId');
    return TreasuryVoucher.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// `GET /api/trs/vouchers/open-invoices?partyId&kind`
  Future<List<SettlementInvoice>> openInvoices({
    required int partyId,
    int kind = 0,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/trs/vouchers/open-invoices',
      query: {'partyId': partyId, 'kind': kind},
    );
    return ShopPage.parse(r.data, SettlementInvoice.fromJson).items;
  }

  /// `GET /api/trs/vouchers/{id}`
  Future<TreasuryVoucher?> treasuryVoucher(int id) async {
    try {
      final r = await _api.get<dynamic>('/api/trs/vouchers/$id');
      final d = r.data;
      return d is Map
          ? TreasuryVoucher.fromJson(Map<String, dynamic>.from(d))
          : null;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// `POST /api/trs/vouchers`
  Future<TreasuryVoucher> saveVoucher(TreasuryVoucher v) async {
    final r = await _api.post<dynamic>('/api/trs/vouchers', v.toJson());
    return TreasuryVoucher.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// `POST /api/trs/vouchers/{id}/confirm`
  Future<TreasuryVoucher> confirmVoucher(int id) async {
    final r = await _api.post<dynamic>('/api/trs/vouchers/$id/confirm', {});
    return TreasuryVoucher.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// `POST /api/trs/vouchers/{id}/unconfirm`
  Future<TreasuryVoucher> unconfirmVoucher(int id) async {
    final r = await _api.post<dynamic>('/api/trs/vouchers/$id/unconfirm', {});
    return TreasuryVoucher.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// `POST /api/trs/vouchers/{id}/cancel`
  Future<TreasuryVoucher> cancelVoucher(int id) async {
    final r = await _api.post<dynamic>('/api/trs/vouchers/$id/cancel', {});
    return TreasuryVoucher.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// `DELETE /api/trs/vouchers/{id}`
  Future<void> deleteVoucher(int id) =>
      _api.delete<dynamic>('/api/trs/vouchers/$id');

  // ---------- چک‌های خزانه ----------

  /// `GET /api/trs/cheques?kind&status&partyId&trsAccountId&search&from&to&onlyOpen&page&pageSize`
  Future<ShopPage<TreasuryCheque>> treasuryCheques({
    int? kind,
    int? status,
    int? partyId,
    int? trsAccountId,
    String? search,
    DateTime? from,
    DateTime? to,
    bool onlyOpen = false,
    int page = 1,
    int pageSize = 15,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/trs/cheques',
      query: {
        if (kind != null) 'kind': kind,
        if (status != null) 'status': status,
        if (partyId != null && partyId > 0) 'partyId': partyId,
        if (trsAccountId != null && trsAccountId > 0)
          'trsAccountId': trsAccountId,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (from != null) 'from': _dateOnly(from),
        if (to != null) 'to': _dateOnly(to),
        'onlyOpen': onlyOpen,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return ShopPage.parse(r.data, TreasuryCheque.fromJson);
  }

  /// `GET /api/trs/cheques/{id}`
  Future<TreasuryCheque?> treasuryCheque(int id) async {
    try {
      final r = await _api.get<dynamic>('/api/trs/cheques/$id');
      final d = r.data;
      return d is Map
          ? TreasuryCheque.fromJson(Map<String, dynamic>.from(d))
          : null;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// `POST /api/trs/cheques`
  Future<TreasuryCheque> saveCheque(TreasuryCheque c) async {
    final r = await _api.post<dynamic>('/api/trs/cheques', c.toJson());
    return TreasuryCheque.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// `POST /api/trs/cheques/action` — واگذاری/وصول/برگشت/خرج/ابطال
  Future<TreasuryCheque> runChequeAction({
    required int chequeId,
    required int status,
    DateTime? date,
    int? trsAccountId,
    String? description,
  }) async {
    final r = await _api.post<dynamic>('/api/trs/cheques/action', {
      'chequeId': chequeId,
      'status': status,
      'date': (date ?? DateTime.now()).toIso8601String(),
      if (trsAccountId != null && trsAccountId > 0) 'trsAccountId': trsAccountId,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    });
    return TreasuryCheque.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// `DELETE /api/trs/cheques/{id}`
  Future<void> deleteCheque(int id) =>
      _api.delete<dynamic>('/api/trs/cheques/$id');

  // ---------- گزارش‌های خزانه ----------

  /// `GET /api/trs/reports/flow?trsAccountId&from&to`
  Future<FlowResult> treasuryFlow({
    required int trsAccountId,
    DateTime? from,
    DateTime? to,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/trs/reports/flow',
      query: {
        'trsAccountId': trsAccountId,
        if (from != null) 'from': _dateOnly(from),
        if (to != null) 'to': _dateOnly(to),
      },
    );
    return FlowResult.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// `GET /api/trs/reports/dashboard?from&to`
  Future<TreasuryDashboard> treasuryDashboard({
    DateTime? from,
    DateTime? to,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/trs/reports/dashboard',
      query: {
        if (from != null) 'from': _dateOnly(from),
        if (to != null) 'to': _dateOnly(to),
      },
    );
    return TreasuryDashboard.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  // ---------- مدیریت چک و اقساط فروشگاهی ----------

  /// `GET /api/dashboard/shop-credit/summary`
  Future<ShopCreditSummary> shopCreditSummary() async {
    final r = await _api.get<dynamic>('/api/dashboard/shop-credit/summary');
    return ShopCreditSummary.fromJson(
      Map<String, dynamic>.from(r.data as Map),
    );
  }

  /// `GET /api/dashboard/shop-credit/cheques?status&txnType&search`
  Future<List<ShopCheque>> shopCheques({
    int? status,
    int? txnType,
    String? search,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/dashboard/shop-credit/cheques',
      query: {
        if (status != null) 'status': status,
        if (txnType != null) 'txnType': txnType,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return ShopPage.parse(r.data, ShopCheque.fromJson).items;
  }

  /// `GET /api/dashboard/shop-credit/installments?isPaid&search`
  Future<List<ShopInstallment>> shopInstallments({
    bool? isPaid,
    String? search,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/dashboard/shop-credit/installments',
      query: {
        if (isPaid != null) 'isPaid': isPaid,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return ShopPage.parse(r.data, ShopInstallment.fromJson).items;
  }

  /// `POST /api/dashboard/cheques/{id}/clear`
  Future<void> clearShopCheque(int id) =>
      _api.post<dynamic>('/api/dashboard/cheques/$id/clear', {});

  /// `POST /api/dashboard/cheques/{id}/bounce?reason=…`
  Future<void> bounceShopCheque(int id, String reason) =>
      _api.post<dynamic>('/api/dashboard/cheques/$id/bounce', null, {
        'reason': reason,
      });

  /// `POST /api/dashboard/cheques/{id}/reset`
  Future<void> resetShopCheque(int id) =>
      _api.post<dynamic>('/api/dashboard/cheques/$id/reset', {});

  /// `POST /api/dashboard/installments/{id}/pay`
  Future<void> payInstallment(int id) =>
      _api.post<dynamic>('/api/dashboard/installments/$id/pay', {});

  /// `POST /api/dashboard/installments/{id}/unpay`
  Future<void> unpayInstallment(int id) =>
      _api.post<dynamic>('/api/dashboard/installments/$id/unpay', {});

  // ---------- پنل معرف (نقش Referrer) ----------

  /// `GET /api/my/dashboard` — داشبورد معرف
  Future<ReferrerDashboard> myReferrerDashboard() async {
    final r = await _api.get<dynamic>('/api/my/dashboard');
    return r.data is Map
        ? ReferrerDashboard.fromJson(Map<String, dynamic>.from(r.data as Map))
        : const ReferrerDashboard();
  }

  /// `GET /api/my/payments?skip&take` — اسناد دریافت پورسانت
  Future<ShopPage<ReferrerPaymentRow>> myReferrerPayments({
    int skip = 0,
    int take = 50,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/my/payments',
      query: {'skip': skip, 'take': take},
    );
    return ShopPage.parse(r.data, ReferrerPaymentRow.fromJson);
  }

  /// `GET /api/my/products?search` — کالاهای موجود برای معرف
  Future<List<ReferrerProductItem>> myReferrerProducts({String? search}) async {
    final r = await _api.get<dynamic>(
      '/api/my/products',
      query: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return ShopPage.parse(r.data, ReferrerProductItem.fromJson).items;
  }

  // ------------------------------------------------------------
  //  فاز ۷ — گزارش کاردکس (تعدادی و ریالی)
  // ------------------------------------------------------------

  /// `GET /api/kardex?productId&warehouseId&from&to` — کاردکس تعدادی
  Future<List<KardexRow>> kardexQuantity({
    required int productId,
    int? warehouseId,
    DateTime? from,
    DateTime? to,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/kardex',
      query: {
        'productId': productId,
        if (warehouseId != null && warehouseId > 0)
          'warehouseId': warehouseId,
        if (from != null) 'from': _dateOnly(from),
        if (to != null) 'to': _dateOnly(to),
      },
    );
    final d = r.data;
    if (d is! List) return const [];
    return d
        .whereType<Map>()
        .map((e) => KardexRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// `GET /api/inv/reports/kardex?productId&warehouseId&from&to` — کاردکس ریالی
  Future<KardexRialResult> kardexRial({
    required int productId,
    int? warehouseId,
    DateTime? from,
    DateTime? to,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/inv/reports/kardex',
      query: {
        'productId': productId,
        if (warehouseId != null && warehouseId > 0)
          'warehouseId': warehouseId,
        if (from != null) 'from': _dateOnly(from),
        if (to != null) 'to': _dateOnly(to),
      },
    );
    final d = r.data;
    return d is Map
        ? KardexRialResult.fromJson(Map<String, dynamic>.from(d))
        : const KardexRialResult();
  }

  /// `GET /api/warehouses/lookups` — انتخابگر انبار
  Future<List<ShopLookup>> warehouseLookups() async {
    final r = await _api.get<dynamic>('/api/warehouses/lookups');
    return ShopPage.parse(r.data, ShopLookup.fromJson).items;
  }

  // ------------------------------------------------------------
  //  فاز ۶ — فروش و ویزیتوری (سفارش میدانی) و معرف‌ها
  // ------------------------------------------------------------

  /// `GET /api/sales-visit/me` — توان‌های کاربر در ماژول ویزیتوری
  Future<VisActor> visMe() async {
    final r = await _api.get<dynamic>('/api/sales-visit/me');
    return VisActor.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// `GET /api/sales-visit?status&partyId&from&to&search`
  Future<List<VisOrder>> visOrders({
    int? status,
    int? partyId,
    DateTime? from,
    DateTime? to,
    String? search,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/sales-visit',
      query: {
        if (status != null) 'status': status,
        if (partyId != null && partyId > 0) 'partyId': partyId,
        if (from != null) 'from': _dateOnly(from),
        if (to != null) 'to': _dateOnly(to),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return ShopPage.parse(r.data, VisOrder.fromJson).items;
  }

  /// `GET /api/sales-visit/approvals` — صف تأیید مدیر با هشدار کسری
  Future<List<VisApprovalItem>> visApprovals() async {
    final r = await _api.get<dynamic>('/api/sales-visit/approvals');
    return ShopPage.parse(r.data, VisApprovalItem.fromJson).items;
  }

  /// `GET /api/sales-visit/finance-queue` — صف مالی
  Future<List<VisOrder>> visFinanceQueue() async {
    final r = await _api.get<dynamic>('/api/sales-visit/finance-queue');
    return ShopPage.parse(r.data, VisOrder.fromJson).items;
  }

  /// `GET /api/sales-visit/stats`
  Future<VisStats> visStats() async {
    final r = await _api.get<dynamic>('/api/sales-visit/stats');
    return VisStats.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// `GET /api/sales-visit/{id}`
  Future<VisOrder?> visOrder(int id) async {
    try {
      final r = await _api.get<dynamic>('/api/sales-visit/$id');
      final d = r.data;
      return d is Map ? VisOrder.fromJson(Map<String, dynamic>.from(d)) : null;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// `GET /api/sales-visit/customers?search`
  Future<List<VisCustomer>> visCustomers({String? search}) async {
    final r = await _api.get<dynamic>(
      '/api/sales-visit/customers',
      query: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return ShopPage.parse(r.data, VisCustomer.fromJson).items;
  }

  /// `POST /api/sales-visit/customers` — ثبت سریع مشتری توسط ویزیتور
  Future<VisCustomer?> visCreateCustomer({
    required String name,
    String? phone,
    String? mobile,
    String? address,
  }) async {
    final r = await _api.post<dynamic>('/api/sales-visit/customers', {
      'name': name.trim(),
      'phone': phone,
      'mobile': mobile,
      'address': address,
    });
    final d = r.data;
    return d is Map ? VisCustomer.fromJson(Map<String, dynamic>.from(d)) : null;
  }

  /// `GET /api/sales-visit/products?warehouseId&search`
  Future<List<VisProduct>> visProducts({
    int? warehouseId,
    String? search,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/sales-visit/products',
      query: {
        if (warehouseId != null && warehouseId > 0) 'warehouseId': warehouseId,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return ShopPage.parse(r.data, VisProduct.fromJson).items;
  }

  /// `GET /api/sales-visit/warehouses`
  Future<List<VisWarehouse>> visWarehouses() async {
    final r = await _api.get<dynamic>('/api/sales-visit/warehouses');
    return ShopPage.parse(r.data, VisWarehouse.fromJson).items;
  }

  /// `POST /api/sales-visit` — ثبت/ویرایش پیش‌نویس (با گزینهٔ ارسال فوری)
  Future<VisOrder> visSave(Map<String, dynamic> cmd) async {
    final r = await _api.post<dynamic>('/api/sales-visit', cmd);
    return VisOrder.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// `POST /api/sales-visit/{id}/submit`
  Future<VisOrder> visSubmit(int id) async {
    final r = await _api.post<dynamic>('/api/sales-visit/$id/submit', {});
    return VisOrder.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// `POST /api/sales-visit/{id}/approve` — تصمیم مدیر + تاریخ نهایی تحویل
  Future<VisOrder> visApprove(
    int id, {
    String? comment,
    DateTime? finalDeliveryDate,
  }) async {
    final r = await _api.post<dynamic>('/api/sales-visit/$id/approve', {
      'comment': comment,
      'finalDeliveryDate': finalDeliveryDate?.toIso8601String(),
    });
    return VisOrder.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// `POST /api/sales-visit/{id}/return`
  Future<VisOrder> visReturn(int id, String comment) async {
    final r = await _api.post<dynamic>('/api/sales-visit/$id/return', {
      'comment': comment,
    });
    return VisOrder.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// `POST /api/sales-visit/{id}/reject`
  Future<VisOrder> visReject(int id, String comment) async {
    final r = await _api.post<dynamic>('/api/sales-visit/$id/reject', {
      'comment': comment,
    });
    return VisOrder.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// `POST /api/sales-visit/{id}/cancel`
  Future<VisOrder> visCancel(int id, {String? comment}) async {
    final r = await _api.post<dynamic>('/api/sales-visit/$id/cancel', {
      'comment': comment,
    });
    return VisOrder.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// `POST /api/sales-visit/{id}/finance-approve` — ثبت فروش فروشگاه از سفارش
  Future<VisOrder> visFinanceApprove(
    int id,
    Map<String, dynamic> cmd,
  ) async {
    final r = await _api.post<dynamic>(
      '/api/sales-visit/$id/finance-approve',
      cmd,
    );
    return VisOrder.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// `POST /api/sales-visit/{id}/sync-invoice`
  Future<VisOrder> visSyncInvoice(int id) async {
    final r = await _api.post<dynamic>(
      '/api/sales-visit/$id/sync-invoice',
      {},
    );
    return VisOrder.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  // ---------- معرف‌ها ----------

  /// `GET /api/referrers?activeOnly&search`
  Future<List<ShopReferrer>> referrerList({
    bool activeOnly = false,
    String? search,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/referrers',
      query: {
        'activeOnly': activeOnly,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return ShopPage.parse(r.data, ShopReferrer.fromJson).items;
  }

  /// `POST /api/referrers`
  Future<ShopReferrer> saveReferrer(ShopReferrer r0) async {
    final r = await _api.post<dynamic>('/api/referrers', r0.toJson());
    return ShopReferrer.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// `DELETE /api/referrers/{id}`
  Future<void> deleteReferrer(int id) =>
      _api.delete<dynamic>('/api/referrers/$id');

  /// `GET /api/referrers/wallets?search&sortBy&desc`
  Future<List<ShopReferrer>> referrerWallets({
    String? search,
    String sortBy = 'balance',
    bool desc = false,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/referrers/wallets',
      query: {
        'sortBy': sortBy,
        'desc': desc,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return ShopPage.parse(r.data, ShopReferrer.fromJson).items;
  }

  /// `GET /api/referrers/payments?referrerId`
  Future<List<ReferrerPayment>> referrerPayments({int? referrerId}) async {
    final r = await _api.get<dynamic>(
      '/api/referrers/payments',
      query: {
        if (referrerId != null && referrerId > 0) 'referrerId': referrerId,
      },
    );
    return ShopPage.parse(r.data, ReferrerPayment.fromJson).items;
  }

  /// `POST /api/referrers/payments`
  Future<ReferrerPayment> addReferrerPayment(ReferrerPayment p) async {
    final r = await _api.post<dynamic>('/api/referrers/payments', p.toJson());
    return ReferrerPayment.fromJson(
      Map<String, dynamic>.from(r.data as Map),
    );
  }

  /// `DELETE /api/referrers/payments/{id}`
  Future<void> deleteReferrerPayment(int id) =>
      _api.delete<dynamic>('/api/referrers/payments/$id');
}
