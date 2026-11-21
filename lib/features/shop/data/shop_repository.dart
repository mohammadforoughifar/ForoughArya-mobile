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

import 'dart:math' as math;
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

  /// `GET /api/products/import/template?kind=…` — فایل اکسل نمونه (کالا یا خدمات)
  Future<Uint8List> productTemplate({
    int kind = ProductImportKind.goods,
  }) => _api.getBytes('/api/products/import/template', query: {'kind': kind});

  /// `POST /api/products/import?warehouseId=…&kind=…` با فایل xlsx
  Future<Map<String, dynamic>> importProducts(
    Uint8List bytes,
    String fileName, {
    int? warehouseId,
    int kind = ProductImportKind.goods,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    final qs = <String>['kind=$kind'];
    if (warehouseId != null && warehouseId > 0) {
      qs.add('warehouseId=$warehouseId');
    }
    final r = await _api.postForm<dynamic>(
      '/api/products/import?${qs.join('&')}',
      form,
    );
    final d = r.data;
    return d is Map ? Map<String, dynamic>.from(d) : const {};
  }

  /// خروجی اکسل/PDF گزارش‌ها — همان `GET /api/exp/report/{reportKey}?format=…`
  Future<Uint8List> exportReportBytes(
    String reportKey, {
    required String format,
    Map<String, dynamic>? query,
  }) => _api.getBytes(
    '/api/exp/report/$reportKey',
    query: {'format': format, ...?query},
  );

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

  // ---------- لوکاپ‌های اختصاصی فاکتور و قیمت‌گذاری تاریخ‌دار ----------

  /// `GET /api/orders/invoice-warehouses`
  Future<List<Warehouse>> invoiceWarehouses() async {
    final r = await _api.get<dynamic>('/api/orders/invoice-warehouses');
    return ShopPage.parse(r.data, Warehouse.fromJson).items;
  }

  /// `GET /api/orders/invoice-parties?type=`
  Future<List<Party>> invoiceParties({int? type}) async {
    final r = await _api.get<dynamic>(
      '/api/orders/invoice-parties',
      query: {if (type != null) 'type': type},
    );
    return ShopPage.parse(r.data, Party.fromJson).items;
  }

  /// `GET /api/orders/invoice-products`
  Future<List<Product>> invoiceProducts() async {
    final r = await _api.get<dynamic>('/api/orders/invoice-products');
    return ShopPage.parse(r.data, Product.fromJson).items;
  }

  /// `GET /api/orders/profit-access`
  Future<bool> orderProfitAccess() async {
    try {
      final r = await _api.get<dynamic>('/api/orders/profit-access');
      final d = r.data;
      return d is Map && d['canViewProfit'] == true;
    } catch (_) {
      return false;
    }
  }

  /// `GET /api/orders/pricing-access`
  Future<bool> orderPricingAccess() async {
    try {
      final r = await _api.get<dynamic>('/api/orders/pricing-access');
      final d = r.data;
      return d is Map && d['canUpdateSalePrice'] == true;
    } catch (_) {
      return false;
    }
  }

  /// `GET /api/orders/warehouse-stock?warehouseId=&asOf=`
  Future<List<InvoiceStockItem>> invoiceWarehouseStock(
    int warehouseId,
    DateTime asOf,
  ) async {
    final r = await _api.get<dynamic>(
      '/api/orders/warehouse-stock',
      query: {
        'warehouseId': warehouseId,
        'asOf': asOf.toIso8601String(),
      },
    );
    return ShopPage.parse(r.data, InvoiceStockItem.fromJson).items;
  }

  /// `GET /api/orders/dated-sale-price?productId=&date=`
  Future<DatedSalePrice> datedSalePrice(int productId, DateTime date) async {
    final r = await _api.get<dynamic>(
      '/api/orders/dated-sale-price',
      query: {
        'productId': productId,
        'date': date.toIso8601String(),
      },
    );
    final d = r.data;
    return d is Map
        ? DatedSalePrice.fromJson(Map<String, dynamic>.from(d))
        : const DatedSalePrice();
  }

  /// `GET /api/orders/minimum-profit-basis?productId=&date=&saleId=`
  Future<MinimumProfitBasis> minimumProfitBasis(
    int productId,
    DateTime date, {
    int? saleId,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/orders/minimum-profit-basis',
      query: {
        'productId': productId,
        'date': date.toIso8601String(),
        if (saleId != null && saleId > 0) 'saleId': saleId,
      },
    );
    final d = r.data;
    return d is Map
        ? MinimumProfitBasis.fromJson(Map<String, dynamic>.from(d))
        : const MinimumProfitBasis();
  }

  // ---------- پیش‌فاکتورهای فروش (`api/orders/proformas`) ----------

  /// `GET /api/orders/proformas?from=&to=&partyId=&warehouseId=`
  Future<List<SalesProforma>> proformas({
    DateTime? from,
    DateTime? to,
    int? partyId,
    int? warehouseId,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/orders/proformas',
      query: {
        if (from != null) 'from': _dateOnly(from),
        if (to != null) 'to': _dateOnly(to),
        if (partyId != null && partyId > 0) 'partyId': partyId,
        if (warehouseId != null && warehouseId > 0) 'warehouseId': warehouseId,
      },
    );
    return ShopPage.parse(r.data, SalesProforma.fromJson).items;
  }

  /// `POST /api/orders/proformas`
  Future<SalesProforma> createProforma(SalesProformaCommand cmd) async {
    final r = await _api.post<dynamic>('/api/orders/proformas', cmd.toJson());
    final d = r.data;
    return d is Map
        ? SalesProforma.fromJson(Map<String, dynamic>.from(d))
        : SalesProforma(
            id: '',
            number: '',
            partyName: '',
            warehouseName: '',
            document: cmd,
          );
  }

  /// `POST /api/orders/proformas/{id}/convert`
  Future<ShopOrder> convertProforma(String id, Map<String, dynamic> cmd) async {
    final r = await _api.post<dynamic>('/api/orders/proformas/$id/convert', cmd);
    final d = r.data;
    return d is Map
        ? ShopOrder.fromJson(Map<String, dynamic>.from(d))
        : ShopOrder();
  }

  // ---------- نسیه، برگشت فاکتور چکی، تعیین‌تکلیف بستانکاری و ابطال ----------

  static String newOperationId() {
    final rnd = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String h(int b) => b.toRadixString(16).padLeft(2, '0');
    return '${h(bytes[0])}${h(bytes[1])}${h(bytes[2])}${h(bytes[3])}-'
        '${h(bytes[4])}${h(bytes[5])}-'
        '${h(bytes[6])}${h(bytes[7])}-'
        '${h(bytes[8])}${h(bytes[9])}-'
        '${h(bytes[10])}${h(bytes[11])}${h(bytes[12])}${h(bytes[13])}${h(bytes[14])}${h(bytes[15])}';
  }

  /// `GET /api/orders/{id}/credit-receipts`
  Future<ShopOrderCreditState> orderCreditState(int orderId) async {
    final r = await _api.get<dynamic>('/api/orders/$orderId/credit-receipts');
    final d = r.data;
    return d is Map
        ? ShopOrderCreditState.fromJson(Map<String, dynamic>.from(d))
        : const ShopOrderCreditState();
  }

  /// `POST /api/orders/{id}/credit-receipts`
  Future<ShopOrderCreditState> addOrderCreditReceipt(
    int orderId, {
    required double amount,
    required int trsAccountId,
    required DateTime date,
    String? operationId,
  }) async {
    final r = await _api.post<dynamic>(
      '/api/orders/$orderId/credit-receipts',
      {
        'operationId': operationId ?? newOperationId(),
        'amount': amount,
        'trsAccountId': trsAccountId,
        'date': date.toIso8601String(),
      },
    );
    final d = r.data;
    return d is Map
        ? ShopOrderCreditState.fromJson(Map<String, dynamic>.from(d))
        : const ShopOrderCreditState();
  }

  /// `POST /api/orders/{id}/credit-receipts/{receiptId}/reversal`
  Future<ShopOrderCreditState> reverseOrderCreditReceipt(
    int orderId,
    int receiptId, {
    required DateTime date,
    String? operationId,
  }) async {
    final r = await _api.post<dynamic>(
      '/api/orders/$orderId/credit-receipts/$receiptId/reversal',
      {
        'operationId': operationId ?? newOperationId(),
        'date': date.toIso8601String(),
      },
    );
    final d = r.data;
    return d is Map
        ? ShopOrderCreditState.fromJson(Map<String, dynamic>.from(d))
        : const ShopOrderCreditState();
  }

  /// `POST /api/orders/{id}/cheque-return-preview`
  Future<SaleChequeReturnPreview> previewChequeReturn(
    int orderId, {
    required DateTime date,
    required List<Map<String, dynamic>> lines,
    int decision = ChequeReturnDecision.none,
    OrderCheque? replacementCheque,
    String? note,
  }) async {
    final r = await _api.post<dynamic>(
      '/api/orders/$orderId/cheque-return-preview',
      {
        'date': date.toIso8601String(),
        'lines': lines,
        'decision': decision,
        if (replacementCheque != null)
          'replacementCheque': replacementCheque.toJson(),
        if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
      },
    );
    final d = r.data;
    return d is Map
        ? SaleChequeReturnPreview.fromJson(Map<String, dynamic>.from(d))
        : const SaleChequeReturnPreview();
  }

  /// `POST /api/orders/{id}/cheque-return`
  Future<ShopOrder> submitChequeReturn(
    int orderId, {
    required DateTime date,
    required List<Map<String, dynamic>> lines,
    int decision = ChequeReturnDecision.none,
    OrderCheque? replacementCheque,
    String? note,
    String? operationId,
  }) async {
    final r = await _api.post<dynamic>(
      '/api/orders/$orderId/cheque-return',
      {
        'operationId': operationId ?? newOperationId(),
        'date': date.toIso8601String(),
        'lines': lines,
        'decision': decision,
        if (replacementCheque != null)
          'replacementCheque': replacementCheque.toJson(),
        if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
      },
    );
    final d = r.data;
    return d is Map
        ? ShopOrder.fromJson(Map<String, dynamic>.from(d))
        : ShopOrder();
  }

  /// `POST /api/orders/{id}/cheque-cancel`
  Future<ShopOrder> cancelChequeOrder(
    int orderId, {
    required DateTime date,
    String? note,
    String? operationId,
  }) async {
    final r = await _api.post<dynamic>(
      '/api/orders/$orderId/cheque-cancel',
      {
        'operationId': operationId ?? newOperationId(),
        'date': date.toIso8601String(),
        if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
      },
    );
    final d = r.data;
    return d is Map
        ? ShopOrder.fromJson(Map<String, dynamic>.from(d))
        : ShopOrder();
  }

  /// `POST /api/orders/{id}/credit-refund`
  Future<ShopOrder> refundCustomerCredit(
    int orderId, {
    required double amount,
    required int trsAccountId,
    required DateTime date,
    String? note,
    String? operationId,
  }) async {
    final r = await _api.post<dynamic>(
      '/api/orders/$orderId/credit-refund',
      {
        'operationId': operationId ?? newOperationId(),
        'amount': amount,
        'trsAccountId': trsAccountId,
        'date': date.toIso8601String(),
        if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
      },
    );
    final d = r.data;
    return d is Map
        ? ShopOrder.fromJson(Map<String, dynamic>.from(d))
        : ShopOrder();
  }

  /// `POST /api/orders/{id}/credit-allocation`
  Future<ShopOrder> allocateCustomerCredit(
    int orderId, {
    required int targetOrderId,
    required double amount,
    required DateTime date,
    String? note,
    String? operationId,
  }) async {
    final r = await _api.post<dynamic>(
      '/api/orders/$orderId/credit-allocation',
      {
        'operationId': operationId ?? newOperationId(),
        'targetOrderId': targetOrderId,
        'amount': amount,
        'date': date.toIso8601String(),
        if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
      },
    );
    final d = r.data;
    return d is Map
        ? ShopOrder.fromJson(Map<String, dynamic>.from(d))
        : ShopOrder();
  }

  // ---------- حساب‌های خزانه (برای بخش پرداخت سند) ----------

  /// `GET /api/orders/active-treasury-accounts` با fallback به `GET /api/trs/accounts`
  Future<List<TrsAccount>> trsAccounts({
    bool activeOnly = true,
    int? kind,
  }) async {
    if (activeOnly) {
      try {
        final r = await _api.get<dynamic>(
          '/api/orders/active-treasury-accounts',
          query: {if (kind != null) 'kind': kind},
        );
        return ShopPage.parse(r.data, TrsAccount.fromJson).items;
      } catch (_) {}
    }
    final r = await _api.get<dynamic>(
      '/api/trs/accounts',
      query: {
        'activeOnly': activeOnly,
        'withBalances': false,
        if (kind != null) 'kind': kind,
      },
    );
    return ShopPage.parse(r.data, TrsAccount.fromJson).items;
  }

  /// `POST /api/trs/accounts/shop` — تعریف سریع بانک/صندوق از داخل فرم سند
  Future<TrsAccount> saveTrsAccount(TrsAccount a) async {
    final r = await _api.post<dynamic>('/api/trs/accounts/shop', a.toJson());
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

  /// `POST /api/trs/accounts/shop` — مسیر اختصاصی فروشگاهی (با اعتبارسنجی کارت/شبا و مجوز `Shop.Banks.Manage`)
  Future<TreasuryAccount> saveTreasuryAccount(TreasuryAccount a) async {
    final r = await _api.post<dynamic>('/api/trs/accounts/shop', a.toJson());
    final d = r.data;
    return d is Map
        ? TreasuryAccount.fromJson(Map<String, dynamic>.from(d))
        : a;
  }

  /// فهرست شرکت‌های مجاز کاربر از `GET /api/company-context` (برای انتخاب مالک حساب خزانه در چندشرکتی)
  Future<({List<ShopLookup> companies, int? activeCompanyId})>
  shopCompanies() async {
    try {
      final r = await _api.get<dynamic>('/api/company-context');
      final d = r.data;
      if (d is Map) {
        final active = (d['activeCompanyId'] as num?)?.toInt();
        final raw = d['companies'];
        final list = raw is List
            ? raw
                  .whereType<Map>()
                  .where((e) => e['isActive'] != false)
                  .map((e) => ShopLookup.fromJson(Map<String, dynamic>.from(e)))
                  .toList()
            : const <ShopLookup>[];
        return (companies: list, activeCompanyId: active);
      }
    } catch (_) {}
    return (companies: const <ShopLookup>[], activeCompanyId: null);
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

  // ------------------------------------------------------------
  //  تنظیمات فروشگاه (`/api/shop-print-settings` و `/api/company-profile`)
  // ------------------------------------------------------------

  Future<ShopCompanyProfile> companyProfile() async {
    final r = await _api.get<dynamic>('/api/company-profile');
    final d = r.data;
    return d is Map
        ? ShopCompanyProfile.fromJson(Map<String, dynamic>.from(d))
        : const ShopCompanyProfile();
  }

  Future<ShopPrintSettings> shopPrintSettings() async {
    final r = await _api.get<dynamic>('/api/shop-print-settings');
    final d = r.data;
    return d is Map
        ? ShopPrintSettings.fromJson(Map<String, dynamic>.from(d))
        : const ShopPrintSettings();
  }

  Future<ShopPrintSettings> saveShopPrintSettings(
    ShopPrintSettings settings,
  ) async {
    final r = await _api.put<dynamic>(
      '/api/shop-print-settings',
      settings.toJson(),
    );
    final d = r.data;
    return d is Map
        ? ShopPrintSettings.fromJson(Map<String, dynamic>.from(d))
        : settings;
  }

  Future<List<ShopVisitorDiscount>> shopVisitorDiscounts() async {
    final r = await _api.get<dynamic>('/api/shop-print-settings/visitors');
    return ShopPage.parse(r.data, ShopVisitorDiscount.fromJson).items;
  }

  Future<ShopVisitorDiscount> saveShopVisitorDiscount(
    ShopVisitorDiscount visitor,
  ) async {
    final r = await _api.put<dynamic>(
      '/api/shop-print-settings/visitors/${visitor.userId}',
      visitor.toJson(),
    );
    final d = r.data;
    return d is Map
        ? ShopVisitorDiscount.fromJson(Map<String, dynamic>.from(d))
        : visitor;
  }

  // ------------------------------------------------------------
  //  قیمت‌گذاری و حداقل سود (`/api/shop-pricing`)
  // ------------------------------------------------------------

  Future<ShopPricingPolicy> pricingPolicy() async {
    final r = await _api.get<dynamic>('/api/shop-pricing/policy');
    final d = r.data;
    return d is Map
        ? ShopPricingPolicy.fromJson(Map<String, dynamic>.from(d))
        : ShopPricingPolicy();
  }

  Future<ShopPricingPolicy> savePricingPolicy(ShopPricingPolicy policy) async {
    final r = await _api.put<dynamic>(
      '/api/shop-pricing/policy',
      policy.toJson(),
    );
    final d = r.data;
    return d is Map
        ? ShopPricingPolicy.fromJson(Map<String, dynamic>.from(d))
        : policy;
  }

  Future<List<ShopLookup>> pricingCategories() async {
    final r = await _api.get<dynamic>('/api/shop-pricing/categories');
    return ShopPage.parse(r.data, ShopLookup.fromJson).items;
  }

  Future<ShopPriceAdjustmentPreview> previewPriceAdjustment(
    ShopPriceAdjustmentRequest request,
  ) async {
    final r = await _api.post<dynamic>(
      '/api/shop-pricing/preview',
      request.toJson(),
    );
    final d = r.data;
    return d is Map
        ? ShopPriceAdjustmentPreview.fromJson(Map<String, dynamic>.from(d))
        : const ShopPriceAdjustmentPreview();
  }

  Future<ShopPriceAdjustmentPreview> applyPriceAdjustment(
    ShopPriceAdjustmentRequest request, {
    required String previewHash,
    required String operationId,
  }) async {
    final r = await _api.post<dynamic>('/api/shop-pricing/apply', {
      ...request.toJson(),
      'previewHash': previewHash,
      'operationId': operationId,
    });
    final d = r.data;
    return d is Map
        ? ShopPriceAdjustmentPreview.fromJson(Map<String, dynamic>.from(d))
        : const ShopPriceAdjustmentPreview();
  }

  Future<List<ShopPriceHistoryItem>> pricingHistory({
    int? productId,
    int take = 200,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/shop-pricing/history',
      query: {
        'take': take,
        if (productId != null && productId > 0) 'productId': productId,
      },
    );
    return ShopPage.parse(r.data, ShopPriceHistoryItem.fromJson).items;
  }

  // ------------------------------------------------------------
  //  فاز ۳ — ویرایش فاکتور چکی، عملیات پیشرفتهٔ چک/قسط و گزارش‌های عملیاتی
  // ------------------------------------------------------------

  /// `PUT /api/orders/{saleId}/cheque-edit`
  Future<ShopOrder> editChequeOrder(
    int saleId,
    Map<String, dynamic> cmd,
  ) async {
    final r = await _api.put<dynamic>('/api/orders/$saleId/cheque-edit', cmd);
    final d = r.data;
    return d is Map
        ? ShopOrder.fromJson(Map<String, dynamic>.from(d))
        : ShopOrder(id: saleId);
  }

  /// `PUT /api/orders/cheques/{chequeId}/receipt`
  Future<void> receiveShopCheque(
    int chequeId, {
    required String operationId,
    required int trsAccountId,
    required DateTime date,
  }) async {
    await _api.put<dynamic>('/api/orders/cheques/$chequeId/receipt', {
      'operationId': operationId,
      'trsAccountId': trsAccountId,
      'date': _dateOnly(date),
    });
  }

  /// `PUT /api/orders/cheques/{chequeId}/receipt-reversal`
  Future<void> reverseShopChequeReceipt(
    int chequeId, {
    required String operationId,
    required DateTime date,
  }) async {
    await _api.put<dynamic>('/api/orders/cheques/$chequeId/receipt-reversal', {
      'operationId': operationId,
      'date': _dateOnly(date),
    });
  }

  /// `PUT /api/orders/cheques/{chequeId}/status`
  Future<void> changeShopChequeStatus(
    int chequeId, {
    required String operationId,
    required bool bounced,
    String? reason,
  }) async {
    await _api.put<dynamic>('/api/orders/cheques/$chequeId/status', {
      'operationId': operationId,
      'bounced': bounced,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  /// `GET /api/orders/cheques/{chequeId}/status-history`
  Future<List<SaleChequeStatusHistoryItem>> chequeStatusHistory(
    int chequeId,
  ) async {
    final r = await _api.get<dynamic>(
      '/api/orders/cheques/$chequeId/status-history',
    );
    return ShopPage.parse(r.data, SaleChequeStatusHistoryItem.fromJson).items;
  }

  /// `GET /api/orders/cheques/{chequeId}/reschedule-preview`
  Future<SaleChequeReschedulePreview> previewChequeReschedule(
    int chequeId, {
    required DateTime expectedDueDate,
    required DateTime newDueDate,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/orders/cheques/$chequeId/reschedule-preview',
      query: {
        'expectedDueDate': _dateOnly(expectedDueDate),
        'newDueDate': _dateOnly(newDueDate),
      },
    );
    final d = r.data;
    return d is Map
        ? SaleChequeReschedulePreview.fromJson(Map<String, dynamic>.from(d))
        : const SaleChequeReschedulePreview();
  }

  /// `PUT /api/orders/cheques/{chequeId}/reschedule`
  Future<SaleChequeReschedulePreview> rescheduleShopCheque(
    int chequeId, {
    required String operationId,
    required DateTime expectedDueDate,
    required DateTime newDueDate,
    required DateTime operationDate,
    required double confirmedIncomeDelta,
  }) async {
    final r = await _api.put<dynamic>(
      '/api/orders/cheques/$chequeId/reschedule',
      {
        'operationId': operationId,
        'expectedDueDate': _dateOnly(expectedDueDate),
        'newDueDate': _dateOnly(newDueDate),
        'operationDate': _dateOnly(operationDate),
        'confirmedIncomeDelta': confirmedIncomeDelta,
      },
    );
    final d = r.data;
    return d is Map
        ? SaleChequeReschedulePreview.fromJson(Map<String, dynamic>.from(d))
        : const SaleChequeReschedulePreview();
  }

  /// `PUT /api/orders/cheques/{chequeId}/replace`
  Future<void> replaceShopCheque(
    int chequeId, {
    required String operationId,
    required DateTime operationDate,
    required String number,
    required double amount,
    required DateTime dueDate,
    String? bankName,
    String? ownerName,
    String? accountInfo,
    String? reason,
  }) async {
    await _api.put<dynamic>('/api/orders/cheques/$chequeId/replace', {
      'operationId': operationId,
      'operationDate': _dateOnly(operationDate),
      'number': number.trim(),
      'amount': amount,
      'dueDate': _dateOnly(dueDate),
      if (bankName != null && bankName.trim().isNotEmpty)
        'bankName': bankName.trim(),
      if (ownerName != null && ownerName.trim().isNotEmpty)
        'ownerName': ownerName.trim(),
      if (accountInfo != null && accountInfo.trim().isNotEmpty)
        'accountInfo': accountInfo.trim(),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  /// `PUT /api/orders/installments/{installmentId}/receipt`
  Future<void> receiveShopInstallment(
    int installmentId, {
    required String operationId,
    required int trsAccountId,
    required DateTime date,
  }) async {
    await _api.put<dynamic>(
      '/api/orders/installments/$installmentId/receipt',
      {
        'operationId': operationId,
        'trsAccountId': trsAccountId,
        'date': _dateOnly(date),
      },
    );
  }

  /// `PUT /api/orders/installments/{installmentId}/receipt-reversal`
  Future<void> reverseShopInstallmentReceipt(
    int installmentId, {
    required String operationId,
    required DateTime date,
  }) async {
    await _api.put<dynamic>(
      '/api/orders/installments/$installmentId/receipt-reversal',
      {
        'operationId': operationId,
        'date': _dateOnly(date),
      },
    );
  }

  /// `GET /api/operations/reports/cheque-income?from&to&partyId`
  Future<ChequeIncomeReport> chequeIncomeReport({
    DateTime? from,
    DateTime? to,
    int? partyId,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/operations/reports/cheque-income',
      query: {
        if (from != null) 'from': _dateOnly(from),
        if (to != null) 'to': _dateOnly(to),
        if (partyId != null && partyId > 0) 'partyId': partyId,
      },
    );
    final d = r.data;
    return d is Map
        ? ChequeIncomeReport.fromJson(Map<String, dynamic>.from(d))
        : const ChequeIncomeReport();
  }

  /// `GET /api/expenses/report?categoryId&from&to`
  Future<ExpenseReport> expenseReport({
    int? categoryId,
    DateTime? from,
    DateTime? to,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/expenses/report',
      query: {
        if (categoryId != null && categoryId > 0) 'categoryId': categoryId,
        if (from != null) 'from': _dateOnly(from),
        if (to != null) 'to': _dateOnly(to),
      },
    );
    final d = r.data;
    return d is Map
        ? ExpenseReport.fromJson(Map<String, dynamic>.from(d))
        : const ExpenseReport();
  }

  /// `GET /api/shop-warranties/report?from&to`
  Future<List<ShopWarrantyReportRow>> warrantyReport({
    DateTime? from,
    DateTime? to,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/shop-warranties/report',
      query: {
        if (from != null) 'from': _dateOnly(from),
        if (to != null) 'to': _dateOnly(to),
      },
    );
    return ShopPage.parse(r.data, ShopWarrantyReportRow.fromJson).items;
  }

  /// `GET /api/sales-visit/requests-report?from&to&includeCanceled`
  Future<VisRequestsReport> visRequestsReport({
    required DateTime from,
    required DateTime to,
    bool includeCanceled = false,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/sales-visit/requests-report',
      query: {
        'from': _dateOnly(from),
        'to': _dateOnly(to),
        'includeCanceled': includeCanceled ? 'true' : 'false',
      },
    );
    final d = r.data;
    return d is Map
        ? VisRequestsReport.fromJson(Map<String, dynamic>.from(d))
        : const VisRequestsReport();
  }

  // ------------------------------------------------------------
  //  فاز ۴ — تعمیرات تکمیلی، گارانتی، طرح تعویض و نقطه سفارش
  // ------------------------------------------------------------

  /// `GET /api/repairs/accounts`
  Future<List<TreasuryAccount>> repairAccounts() async {
    final r = await _api.get<dynamic>('/api/repairs/accounts');
    return ShopPage.parse(r.data, TreasuryAccount.fromJson).items;
  }

  /// `GET /api/repairs/{id}/invoice-detail`
  Future<ShopOrder?> repairLinkedInvoice(int id) async {
    try {
      final r = await _api.get<dynamic>('/api/repairs/$id/invoice-detail');
      final d = r.data;
      return d is Map
          ? ShopOrder.fromJson(Map<String, dynamic>.from(d))
          : null;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// `GET /api/repairs/{id}/warranty-credit`
  Future<ShopOrderCreditState> repairWarrantyCreditState(int id) async {
    final r = await _api.get<dynamic>('/api/repairs/$id/warranty-credit');
    final d = r.data;
    return d is Map
        ? ShopOrderCreditState.fromJson(Map<String, dynamic>.from(d))
        : const ShopOrderCreditState();
  }

  /// `POST /api/repairs/{id}/warranty-credit-receipts`
  Future<void> receiveRepairWarrantyCredit(
    int id, {
    required double amount,
    required int trsAccountId,
    required DateTime date,
    String? operationId,
  }) async {
    await _api.post<dynamic>('/api/repairs/$id/warranty-credit-receipts', {
      'operationId': operationId ?? newOperationId(),
      'trsAccountId': trsAccountId,
      'amount': amount,
      'date': _dateOnly(date),
    });
  }

  /// `POST /api/repairs/{id}/warranty-credit-receipts/{receiptId}/reverse`
  Future<void> reverseRepairWarrantyCredit(
    int id,
    int receiptId, {
    required DateTime date,
    String? operationId,
  }) async {
    await _api.post<dynamic>(
      '/api/repairs/$id/warranty-credit-receipts/$receiptId/reverse',
      {
        'operationId': operationId ?? newOperationId(),
        'date': _dateOnly(date),
      },
    );
  }

  // ---------- گارانتی فروشگاهی (`/api/shop-warranties`) ----------

  /// `GET /api/shop-warranties`
  Future<List<ShopWarranty>> shopWarranties() async {
    final r = await _api.get<dynamic>('/api/shop-warranties');
    return ShopPage.parse(r.data, ShopWarranty.fromJson).items;
  }

  /// `GET /api/shop-warranties/lookups`
  Future<ShopWarrantyLookups> shopWarrantyLookups() async {
    final r = await _api.get<dynamic>('/api/shop-warranties/lookups');
    final d = r.data;
    return d is Map
        ? ShopWarrantyLookups.fromJson(Map<String, dynamic>.from(d))
        : const ShopWarrantyLookups();
  }

  /// `POST /api/shop-warranties`
  Future<ShopWarranty> saveShopWarranty(ShopWarranty dto) async {
    final payload = dto.toJson();
    if ((payload['operationId']?.toString() ?? '').trim().isEmpty) {
      payload['operationId'] = newOperationId();
    }
    final r = await _api.post<dynamic>('/api/shop-warranties', payload);
    return ShopWarranty.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// `POST /api/shop-warranties/{id}/finalize`
  Future<ShopWarranty> finalizeShopWarranty(int id) async {
    final r = await _api.post<dynamic>('/api/shop-warranties/$id/finalize', {});
    return ShopWarranty.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// `GET /api/shop-warranties/accounts`
  Future<List<TreasuryAccount>> shopWarrantyAccounts() async {
    final r = await _api.get<dynamic>('/api/shop-warranties/accounts');
    return ShopPage.parse(r.data, TreasuryAccount.fromJson).items;
  }

  /// `GET /api/shop-warranties/{id}/credit`
  Future<ShopOrderCreditState> shopWarrantyCreditState(int id) async {
    final r = await _api.get<dynamic>('/api/shop-warranties/$id/credit');
    final d = r.data;
    return d is Map
        ? ShopOrderCreditState.fromJson(Map<String, dynamic>.from(d))
        : const ShopOrderCreditState();
  }

  /// `POST /api/shop-warranties/{id}/credit-receipts`
  Future<void> receiveShopWarrantyCredit(
    int id, {
    required double amount,
    required int trsAccountId,
    required DateTime date,
    String? operationId,
  }) async {
    await _api.post<dynamic>('/api/shop-warranties/$id/credit-receipts', {
      'operationId': operationId ?? newOperationId(),
      'trsAccountId': trsAccountId,
      'amount': amount,
      'date': _dateOnly(date),
    });
  }

  /// `POST /api/shop-warranties/{id}/credit-receipts/{receiptId}/reverse`
  Future<void> reverseShopWarrantyCredit(
    int id,
    int receiptId, {
    required DateTime date,
    String? operationId,
  }) async {
    await _api.post<dynamic>(
      '/api/shop-warranties/$id/credit-receipts/$receiptId/reverse',
      {
        'operationId': operationId ?? newOperationId(),
        'date': _dateOnly(date),
      },
    );
  }

  // ---------- طرح تعویض (`/api/shop-trade-ins`) ----------

  /// `GET /api/shop-trade-ins`
  Future<List<ShopTradeIn>> shopTradeIns() async {
    final r = await _api.get<dynamic>('/api/shop-trade-ins');
    return ShopPage.parse(r.data, ShopTradeIn.fromJson).items;
  }

  /// `GET /api/shop-trade-ins/customers`
  Future<List<ShopLookup>> shopTradeInCustomers() async {
    final r = await _api.get<dynamic>('/api/shop-trade-ins/customers');
    return ShopPage.parse(r.data, ShopLookup.fromJson).items;
  }

  /// `GET /api/shop-trade-ins/target-sales/{partyId}`
  Future<List<ShopTradeInTargetSale>> shopTradeInTargetSales(
    int partyId,
  ) async {
    final r = await _api.get<dynamic>(
      '/api/shop-trade-ins/target-sales/$partyId',
    );
    return ShopPage.parse(r.data, ShopTradeInTargetSale.fromJson).items;
  }

  /// `POST /api/shop-trade-ins`
  Future<ShopTradeIn> saveShopTradeIn(ShopTradeIn dto) async {
    final payload = dto.toJson();
    if ((payload['operationId']?.toString() ?? '').trim().isEmpty) {
      payload['operationId'] = newOperationId();
    }
    final r = await _api.post<dynamic>('/api/shop-trade-ins', payload);
    return ShopTradeIn.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// `POST /api/shop-trade-ins/{id}/finalize`
  Future<ShopTradeIn> finalizeShopTradeIn(int id, {DateTime? date}) async {
    final r = await _api.post<dynamic>('/api/shop-trade-ins/$id/finalize', {
      'date': _dateOnly(date ?? DateTime.now()),
    });
    return ShopTradeIn.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// `POST /api/shop-trade-ins/{id}/use`
  Future<void> useShopTradeIn(
    int id, {
    required int kind,
    required double amount,
    required DateTime date,
    int? targetSaleId,
    int? trsAccountId,
    String? note,
    String? operationId,
  }) async {
    await _api.post<dynamic>('/api/shop-trade-ins/$id/use', {
      'operationId': operationId ?? newOperationId(),
      'kind': kind,
      'amount': amount,
      'date': _dateOnly(date),
      if (targetSaleId != null && targetSaleId > 0)
        'targetSaleId': targetSaleId,
      if (trsAccountId != null && trsAccountId > 0)
        'trsAccountId': trsAccountId,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  // ---------- گزارش نقطه سفارش (`/api/reorder`) ----------

  /// `GET /api/reorder?warehouseId&skip&take`
  Future<ShopPage<ReorderItem>> reorderItems({
    int? warehouseId,
    int skip = 0,
    int take = 20,
  }) async {
    final r = await _api.get<dynamic>(
      '/api/reorder',
      query: {
        'skip': skip,
        'take': take,
        if (warehouseId != null && warehouseId > 0) 'warehouseId': warehouseId,
      },
    );
    return ShopPage.parse(r.data, ReorderItem.fromJson);
  }
}
