// ============================================================
//  فرم صدور/ویرایش فاکتور فروش (و خرید)
//  آینهٔ فرم وب: Pages/Orders/OrderForm.razor
//
//  • انبار* · مشتری/تأمین‌کننده* (+ «مشتری جدید» با همان فرم طرف حساب) ·
//    تاریخ سند* · توضیحات · نمایش معرف مشتری
//  • «روش پرداخت (ترکیبی)»: چهار جزء نقدی/چک/اقساطی/نسیه با همان
//    محاسبهٔ باقی‌مانده‌ها، نوار خلاصه، نوع دریافت نقدی و بانک/صندوق
//    (+ «تعریف بانک» با همان مودال وب)، ماشین‌حساب اقساط با سود
//  • اقلام: کالا (با موجودی همان انبار) · مقدار (۲ اعشار) · قیمت واحد ·
//    تخفیف (تا ۱۰۰ = درصد، بالاتر = ریال) · مبلغ کل · سود · پورسانت ·
//    «آخرین فاکتور خرید این کالا»
//  • جمع‌ها: جمع ناخالص، تخفیف کل، مبلغ نهایی، سود کل، پورسانت
//  • همان اعتبارسنجی‌های وب با همان پیام‌ها
//  • دکمهٔ «ثبت و چاپ» هم‌تراز با وب (پنجرهٔ چاپ و اشتراک‌گذاری فاکتور)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/fa_num.dart';
import '../data/shop_perms.dart';
import '../data/shop_repository.dart';
import '../models/order_models.dart';
import '../models/shop_models.dart';
import 'party_form_page.dart';
import 'shop_invoice_print_sheet.dart';
import 'shop_style.dart';

class OrderFormPage extends StatefulWidget {
  const OrderFormPage({
    super.key,
    required this.type,
    this.source,
    this.copyTemplate,
    this.isProforma = false,
    this.convertingProforma,
  });

  final int type;
  final ShopOrder? source;
  final ShopOrder? copyTemplate;
  final bool isProforma;
  final SalesProforma? convertingProforma;

  @override
  State<OrderFormPage> createState() => _OrderFormPageState();
}

/// سطر قابل ویرایش فرم
class _Line {
  _Line() : qty = '1', price = '', discount = '', vat = '', newSalePrice = '';
  int id = 0;
  int productId = 0;
  double? originalQty;
  String qty;
  String price;
  String discount;
  String vat;
  String newSalePrice;
  String unit = '';
  double discountPercent = 0;
  double discountAmount = 0;
  bool discountIsAmount = false;
  bool manualPrice = false;
  String? priceSource;
  MinimumProfitBasis? minProfit;

  double get qtyValue => parseNum(qty);
  double get priceValue => parseNum(price);
  double get vatValue => parseNum(vat).clamp(0, OrderLineAmounts.maxVatValue).toDouble();
  double get newSalePriceValue => parseNum(newSalePrice);
  double get gross => OrderLineAmounts.gross(qtyValue, priceValue);
  double get afterDiscount => (gross - discountAmount) < 0 ? 0 : gross - discountAmount;
  double get vatAmount => OrderLineAmounts.vat(afterDiscount, vatValue);
  double get total => afterDiscount + vatAmount;
}

/// چک فرم
class _ChequeRow {
  int id = 0;
  String number = '';
  String bankName = '';
  String owner = '';
  String amount = '';
  DateTime? dueDate;
  int? trsAccountId;
  double get amountValue => parseNum(amount);
}

/// قسط فرم
class _InstRow {
  int id = 0;
  int no = 1;
  String amount = '';
  DateTime? dueDate;
  double get amountValue => parseNum(amount);
}

class _OrderFormPageState extends State<OrderFormPage> {
  late final ShopRepository _repo;
  late final ShopPerms _perms;

  bool get _isSale => widget.type == TxnType.sale;
  bool get _isEdit => (widget.source?.id ?? 0) > 0;
  bool get _isProforma => widget.isProforma;
  bool get _isConvertingProforma => widget.convertingProforma != null;
  bool _serverProfitAccess = false;
  bool _canUpdateSalePrice = false;
  bool get _canSeeProfit => _perms.canViewProfit || _serverProfitAccess;

  final _descCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _cashTrackingCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  // انتخاب‌ها
  int _warehouseId = 0;
  int _partyId = 0;
  int _referrerId = 0;
  DateTime? _date;
  List<Warehouse> _warehouses = const [];
  List<Party> _parties = const [];
  List<Referrer> _referrers = const [];
  List<Product> _products = const [];
  Map<int, double> _warehouseStocks = {};
  Map<int, double> _sellableStocks = {};

  final List<_Line> _lines = [_Line()];

  // پرداخت
  bool _useCash = true, _useCheque = false, _useInst = false, _useCredit = false;
  String _cashType = '0';
  final _cashAmountCtrl = TextEditingController();
  int? _trsAccountId;
  DateTime? _creditDue;
  List<TrsAccount> _accounts = const [];
  SaleChequeChargeInput? _chequeCharge;
  double _saleChequeIncome = 0;
  double _chargeInvoiceBase = 0;

  final List<_ChequeRow> _cheques = [];
  final List<_InstRow> _insts = [];
  int _instCount = 3;
  int _instInterval = 30;
  DateTime? _instFirstDue;

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _perms = ShopPerms(context.read<AuthController>().session);
    _instFirstDue = DateTime.now().add(const Duration(days: 30));
    _bootstrap();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _barcodeCtrl.dispose();
    _cashTrackingCtrl.dispose();
    _cashAmountCtrl.dispose();
    super.dispose();
  }

  bool get _hasNonCash => _useCheque || _useInst || _useCredit;
  bool get _hasChequeIncomeArticle =>
      _isSale &&
      (_chequeCharge != null ||
          (_isEdit && (widget.source?.hasChequeCharge ?? false)) ||
          _saleChequeIncome > 0);

  Iterable<_Line> get _validLines =>
      _lines.where((l) => l.productId > 0 && l.qtyValue > 0);

  double get _goodsTotal => _lines.fold(0, (s, l) => s + l.total);
  double get _grandTotal => _goodsTotal + (_isSale ? _saleChequeIncome : 0);
  double get _cashPart => !_hasNonCash ? _grandTotal : parseNum(_cashAmountCtrl.text);
  double get _chequeSum =>
      !_useCheque ? 0 : _cheques.fold<double>(0, (s, c) => s + c.amountValue);
  double get _instSum =>
      !_useInst ? 0 : _insts.fold<double>(0, (s, i) => s + i.amountValue);
  double get _finalRemaining =>
      _grandTotal - _cashPart - _chequeSum - _instSum;
  double get _remainingAfterCash => _grandTotal - _cashPart;

  double _remainingAfterCheque(int i) {
    if (_cheques.isEmpty) return _remainingAfterCash;
    final upto = i.clamp(0, _cheques.length - 1);
    var s = _cashPart;
    for (var k = 0; k <= upto; k++) {
      s += _cheques[k].amountValue;
    }
    return _grandTotal - s;
  }

  double _remainingAfterInst(int i) {
    if (_insts.isEmpty) return _remainingAfterCash - _chequeSum;
    final upto = i.clamp(0, _insts.length - 1);
    var s = _cashPart + _chequeSum;
    for (var k = 0; k <= upto; k++) {
      s += _insts[k].amountValue;
    }
    return _grandTotal - s;
  }

  int get _cashKind => int.tryParse(_cashType) ?? 0;

  /// همان قاعدهٔ وب: حساب‌های مجاز هر نوع دریافت
  List<TrsAccount> get _accountsForCashType => switch (_cashKind) {
    CashKind.cash => _accounts
        .where(
          (a) => a.kind == AccountKind.cash || a.kind == AccountKind.pettyCash,
        )
        .toList(),
    CashKind.cardReader => _accounts
        .where((a) => a.kind == AccountKind.pos || a.kind == AccountKind.bank)
        .toList(),
    CashKind.cardTransfer => _accounts
        .where((a) => a.kind == AccountKind.pos || a.kind == AccountKind.bank)
        .toList(),
    _ => _accounts,
  };

  double _lineProfit(_Line l) {
    final p = _productOf(l.productId);
    if (p == null) return 0;
    if (p.isService) return l.afterDiscount;
    final cost = p.avgCost > 0 ? p.avgCost : p.purchasePrice;
    return l.afterDiscount - cost * l.qtyValue;
  }

  double _lineCommission(_Line l) {
    if (_referrerId <= 0) return 0;
    final r = _referrers.where((x) => x.id == _referrerId).firstOrNull;
    if (r == null) return 0;
    final p = _productOf(l.productId);
    if (p == null) return 0;
    final percent = p.isService ? r.serviceCommissionPercent : r.goodsCommissionPercent;
    if (percent <= 0) return 0;
    if (p.isService) return (l.afterDiscount * percent / 100).roundToDouble();
    final profit = _lineProfit(l);
    return profit > 0 ? (profit * percent / 100).roundToDouble() : 0;
  }

  double get _totalProfit => _lines
      .where((l) => l.productId > 0 && l.qtyValue > 0)
      .fold(0, (s, l) => s + _lineProfit(l));
  double get _totalCommission => _lines
      .where((l) => l.productId > 0 && l.qtyValue > 0)
      .fold(0, (s, l) => s + _lineCommission(l));

  Product? _productOf(int id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ---------------- بارگذاری اولیه ----------------
  Future<void> _bootstrap() async {
    try {
      List<Warehouse> whs = const [];
      List<Party> parties = const [];
      List<TrsAccount> accounts = const [];
      List<Referrer> referrers = const [];
      List<Product> products = const [];
      bool profitAccess = false;
      bool pricingAccess = false;

      try {
        whs = (await _repo.invoiceWarehouses()).where((w) => w.isActive).toList();
      } catch (_) {
        try {
          whs = (await _repo.warehouses()).items.where((w) => w.isActive).toList();
        } catch (_) {}
      }
      try {
        parties = await _repo.invoiceParties(
          type: _isSale ? PartyType.customer : PartyType.supplier,
        );
      } catch (_) {
        try {
          parties = (await _repo.parties(
            type: _isSale ? PartyType.customer : PartyType.supplier,
            take: 1000,
          )).items;
        } catch (_) {}
      }
      try {
        products = (await _repo.invoiceProducts())
            .where((p) => p.isActive && (_isSale || !p.isService))
            .toList();
      } catch (_) {
        try {
          products = (await _repo.products(pageSize: 10000)).items
              .where((p) => p.isActive && (_isSale || !p.isService))
              .toList();
        } catch (_) {}
      }
      if (!_isProforma) {
        try {
          accounts = await _repo.trsAccounts();
        } catch (_) {}
      }
      if (_isSale) {
        profitAccess = await _repo.orderProfitAccess();
        try {
          referrers = await _repo.referrers();
        } catch (_) {}
      } else {
        pricingAccess = await _repo.orderPricingAccess();
      }

      if (!mounted) return;
      setState(() {
        _warehouses = whs;
        _parties = parties;
        _products = products;
        _accounts = accounts;
        _referrers = referrers;
        _serverProfitAccess = profitAccess;
        _canUpdateSalePrice = pricingAccess;
      });

      final src = widget.source;
      final tpl = widget.copyTemplate ?? widget.convertingProforma?.toOrder();
      if (src != null) {
        // ---- پر کردن فرم از سند موجود (ویرایش) ----
        _warehouseId = src.warehouseId;
        _partyId = src.partyId;
        _referrerId = src.referrerId ?? 0;
        _date = src.date ?? DateTime.now();
        _descCtrl.text = src.description;
        _cashType = (src.cashType ?? 0).toString();
        _cashTrackingCtrl.text = src.cashTrackingNumber ?? '';
        _trsAccountId = src.trsAccountId;
        _creditDue = src.dueDate;
        _chequeCharge = src.chequeChargeSnapshot;
        _saleChequeIncome = src.chequeIncomeAmount;
        _useCheque =
            src.cheques.isNotEmpty || src.paymentMethod == PayMethod.cheque;
        _useInst = src.installments.isNotEmpty ||
            src.paymentMethod == PayMethod.installment;
        final loadedCash = src.paymentMethod == PayMethod.cash
            ? src.totalAmount
            : src.cashAmount;
        _useCash = loadedCash > 0 ||
            (src.cheques.isEmpty &&
                src.installments.isEmpty &&
                src.paymentMethod != PayMethod.cheque &&
                src.paymentMethod != PayMethod.installment);
        if (loadedCash > 0 &&
            (src.cheques.isNotEmpty ||
                src.installments.isNotEmpty ||
                src.paymentMethod != PayMethod.cash)) {
          _cashAmountCtrl.text = formatNumText(loadedCash.toStringAsFixed(0));
        }
        final loadedCredit = src.totalAmount -
            loadedCash -
            src.cheques.fold<double>(0, (s, c) => s + c.amount) -
            src.installments.fold<double>(0, (s, i) => s + i.amount);
        _useCredit = loadedCredit > 1 || src.paymentMethod == PayMethod.credit;

        _cheques
          ..clear()
          ..addAll(src.cheques.map((c) {
            final r = _ChequeRow()
              ..id = c.id
              ..number = c.number
              ..bankName = c.bankName ?? ''
              ..owner = c.ownerName ?? ''
              ..amount = formatNumText(c.amount.toStringAsFixed(0))
              ..dueDate = c.dueDate
              ..trsAccountId = c.trsAccountId;
            return r;
          }));
        _insts
          ..clear()
          ..addAll(src.installments.map((i) {
            final r = _InstRow()
              ..id = i.id
              ..no = i.no
              ..amount = formatNumText(i.amount.toStringAsFixed(0))
              ..dueDate = i.dueDate;
            return r;
          }));
        _instCount = _insts.isEmpty ? 3 : _insts.length;
        _populateLinesFrom(src.lines, keepLineId: true);
        _chargeInvoiceBase = _goodsTotal;
        _ensureInactiveLookups(src);
      } else if (tpl != null) {
        // ---- کپی از فاکتور قبلی یا تبدیل پیش‌فاکتور به فروش ----
        _warehouseId = tpl.warehouseId;
        _partyId = tpl.partyId;
        _referrerId = tpl.referrerId ?? 0;
        _date = widget.convertingProforma != null
            ? (tpl.date ?? DateTime.now())
            : DateTime.now();
        _descCtrl.text = tpl.description;
        final def = _accounts.where((a) => a.isDefault).firstOrNull ??
            _accounts.firstOrNull;
        _trsAccountId = def?.id;
        _populateLinesFrom(tpl.lines, keepLineId: false);
        _ensureInactiveLookups(tpl);
      } else {
        _date = DateTime.now();
        final def = _accounts.where((a) => a.isDefault).firstOrNull ??
            _accounts.firstOrNull;
        _trsAccountId = def?.id;
      }
      await _loadWarehouseStocks();
      if (_isSale) {
        for (final l in _lines.where((x) => x.productId > 0)) {
          _refreshLinePricingHints(l, updatePriceIfAuto: false);
        }
      }
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _populateLinesFrom(List<OrderLine> sourceLines, {required bool keepLineId}) {
    _lines.clear();
    for (final l in sourceLines) {
      final vm = _Line()
        ..id = keepLineId ? l.id : 0
        ..productId = l.productId
        ..originalQty = keepLineId ? l.quantity : null
        ..qty = l.quantity.toString().replaceAll(RegExp(r'\.0$'), '')
        ..price = formatNumText(l.price.toStringAsFixed(0))
        ..manualPrice = true
        ..unit = l.unit
        ..discountPercent = l.discountPercent
        ..discountAmount = l.discountAmount
        ..discountIsAmount = l.discountIsAmount
        ..vat = l.vatValue > 0
            ? (l.vatValue <= 100
                  ? l.vatValue.toStringAsFixed(l.vatValue % 1 == 0 ? 0 : 2)
                  : formatNumText(l.vatValue.toStringAsFixed(0)))
            : '';
      vm.discount = vm.discountIsAmount
          ? (vm.discountAmount > 0
                ? formatNumText(vm.discountAmount.toStringAsFixed(0))
                : '')
          : (vm.discountPercent > 0
                ? vm.discountPercent.toStringAsFixed(
                    vm.discountPercent % 1 == 0 ? 0 : 2,
                  )
                : '');
      _lines.add(vm);
    }
    if (_lines.isEmpty) _lines.add(_Line());
  }

  void _ensureInactiveLookups(ShopOrder src) {
    if (_warehouseId > 0 && !_warehouses.any((w) => w.id == _warehouseId)) {
      _warehouses = [
        ..._warehouses,
        Warehouse(id: _warehouseId, name: src.warehouseName ?? 'انبار'),
      ];
    }
    if (_partyId > 0 && !_parties.any((p) => p.id == _partyId)) {
      _parties = [
        ..._parties,
        Party(id: _partyId, name: src.partyName ?? 'طرف حساب'),
      ];
    }
    for (final l in src.lines) {
      if (!_products.any((p) => p.id == l.productId)) {
        _products = [
          ..._products,
          Product(
            id: l.productId,
            name: l.productName,
            unit: l.unit,
            isService: l.isService,
          ),
        ];
      }
    }
  }

  Future<void> _loadWarehouseStocks() async {
    _warehouseStocks = {};
    _sellableStocks = {};
    if (_warehouseId <= 0) return;
    try {
      final items = await _repo.invoiceWarehouseStock(
        _warehouseId,
        _date ?? DateTime.now(),
      );
      _warehouseStocks = {for (final s in items) s.productId: s.quantity};
      _sellableStocks = {
        for (final s in items) s.productId: s.sellableQuantity,
      };
      return;
    } catch (_) {}
    try {
      final res = await _repo.stock(
        warehouseId: _warehouseId,
        page: 1,
        pageSize: 10000,
      );
      _warehouseStocks = {for (final s in res.items) s.productId: s.quantity};
      _sellableStocks = Map<int, double>.from(_warehouseStocks);
    } catch (_) {}
  }

  /// همان فیلتر وب: در فروش فقط کالاهای موجود/متعلق به این انبار + خدمات،
  /// در خرید کالاهای این انبار یا بدون انبار اختصاصی.
  List<Product> get _selectableProducts {
    if (_warehouseId <= 0) return _products;
    return _products.where((p) {
      if (p.isService) return _isSale;
      if ((p.warehouseId ?? 0) > 0 && p.warehouseId != _warehouseId) {
        return false;
      }
      if (_isSale) {
        return p.warehouseId == _warehouseId ||
            _warehouseStocks.containsKey(p.id);
      }
      return p.warehouseId == null || p.warehouseId == _warehouseId;
    }).toList();
  }

  Future<void> _onWarehouseChanged(int? v) async {
    setState(() => _warehouseId = v ?? 0);
    await _loadWarehouseStocks();
    if (!mounted) return;
    final valid = _selectableProducts.map((p) => p.id).toSet();
    setState(() {
      for (final l in _lines.where((x) => x.productId > 0)) {
        if (!valid.contains(l.productId)) {
          final p = _productOf(l.productId);
          l
            ..productId = 0
            ..unit = ''
            ..price = ''
            ..discount = ''
            ..discountAmount = 0
            ..discountPercent = 0;
          _toast(
            'کالای «${p?.name ?? 'انتخاب‌شده'}» در این انبار موجود/مجاز نیست و از سطرها حذف شد.',
          );
        }
      }
    });
  }

  void _onPartyChanged(int? v) {
    setState(() {
      _partyId = v ?? 0;
      if (!_isSale) return;
      // معرف مشتری خودکار تعیین می‌شود (مثل وب)
      final c = _parties.where((p) => p.id == v).firstOrNull;
      final rid = c?.referrerId ?? 0;
      _referrerId = _referrers.any((r) => r.id == rid) ? rid : 0;
    });
  }

  // ---------------- محاسبهٔ تخفیف سطر ----------------
  void _recalcDiscount(_Line l) {
    final gross = l.gross;
    if (l.discountIsAmount) {
      var amount = l.discountAmount.roundToDouble().clamp(0, gross < 0 ? 0 : gross);
      l.discountAmount = amount.toDouble();
      l.discountPercent = gross > 0
          ? double.parse((amount * 100 / gross).toStringAsFixed(2))
          : 0;
    } else {
      l.discountPercent = l.discountPercent.clamp(0, 100).toDouble();
      l.discountAmount = (gross * l.discountPercent / 100).roundToDouble();
    }
  }

  void _onDiscountInput(_Line l, String raw) {
    l.discount = raw;
    final val = parseNum(raw);
    if (l.discountIsAmount || val > 100) {
      l.discountIsAmount = true;
      l.discountAmount = val < 0 ? 0 : val;
      l.discountPercent = 0;
    } else {
      l.discountIsAmount = false;
      l.discountPercent = val < 0 ? 0 : val;
      l.discountAmount = 0;
    }
    _recalcDiscount(l);
  }

  void _toggleDiscountMode(_Line l) {
    setState(() {
      l.discountIsAmount = !l.discountIsAmount;
      final val = parseNum(l.discount);
      if (l.discountIsAmount) {
        l.discountAmount = val < 0 ? 0 : val;
        l.discountPercent = 0;
      } else {
        final pct = val.clamp(0, 100).toDouble();
        l.discountPercent = pct;
        l.discountAmount = 0;
        if (val > 100) l.discount = pct.toStringAsFixed(0);
      }
      _recalcDiscount(l);
    });
  }

  void _onProductPicked(_Line l, int id) {
    setState(() {
      if (l.productId != id) {
        l.originalQty = null;
        l.id = 0;
        l.manualPrice = false;
      }
      l.productId = id;
      final p = _productOf(id);
      if (p != null) {
        l.unit = p.unit;
        final price = _isSale ? p.salePrice : p.purchasePrice;
        if (price > 0) l.price = formatNumText(price.toStringAsFixed(0));
        if (!_isSale && _canUpdateSalePrice && p.salePrice > 0) {
          l.newSalePrice = formatNumText(p.salePrice.toStringAsFixed(0));
        }
        final defVat = p.invoiceVatValue ?? 0;
        l.vat = defVat > 0
            ? (defVat <= 100
                  ? defVat.toStringAsFixed(defVat % 1 == 0 ? 0 : 2)
                  : formatNumText(defVat.toStringAsFixed(0)))
            : '';
      }
      _recalcDiscount(l);
    });
    if (_isSale && id > 0) {
      _refreshLinePricingHints(l, updatePriceIfAuto: true);
    }
  }

  Future<void> _refreshLinePricingHints(
    _Line l, {
    required bool updatePriceIfAuto,
  }) async {
    final pid = l.productId;
    final dt = _date ?? DateTime.now();
    if (!_isSale || pid <= 0) return;
    final p = _productOf(pid);
    try {
      final dated = await _repo.datedSalePrice(pid, dt);
      if (!mounted || l.productId != pid) return;
      setState(() {
        l.priceSource = dated.source;
        if (updatePriceIfAuto && !l.manualPrice && (dated.price ?? 0) > 0) {
          l.price = formatNumText(dated.price!.toStringAsFixed(0));
          _recalcDiscount(l);
        }
      });
    } catch (_) {}

    if (p != null && !p.isService) {
      try {
        final basis = await _repo.minimumProfitBasis(
          pid,
          dt,
          saleId: _isEdit ? widget.source?.id : null,
        );
        if (!mounted || l.productId != pid) return;
        setState(() => l.minProfit = basis);
      } catch (_) {}
    }
  }

  Future<void> _onInvoiceDateChanged(DateTime d) async {
    setState(() => _date = d);
    await _loadWarehouseStocks();
    if (_isSale) {
      for (final l in _lines.where((x) => x.productId > 0)) {
        _refreshLinePricingHints(l, updatePriceIfAuto: !l.manualPrice);
      }
    }
  }

  void _addByBarcode([String? rawInput]) {
    final code = toEnDigits((rawInput ?? _barcodeCtrl.text).trim()).toLowerCase();
    if (code.isEmpty) return;
    final pool = _selectableProducts;
    final match = pool.where((p) {
      final bc = toEnDigits((p.barcode ?? '').trim()).toLowerCase();
      final pc = toEnDigits(p.code.trim()).toLowerCase();
      return (bc.isNotEmpty && bc == code) || (pc.isNotEmpty && pc == code);
    }).firstOrNull;
    if (match == null) {
      _toast('کالایی با بارکد یا کد «$code» در این انبار یافت نشد.');
      return;
    }
    _barcodeCtrl.clear();
    final existing = _lines.where((l) => l.productId == match.id).firstOrNull;
    if (existing != null) {
      setState(() {
        final nextQty = existing.qtyValue + 1;
        existing.qty = nextQty.toString().replaceAll(RegExp(r'\.0$'), '');
        _recalcDiscount(existing);
      });
      return;
    }
    final emptyLine = _lines.where((l) => l.productId == 0).firstOrNull;
    if (emptyLine != null) {
      _onProductPicked(emptyLine, match.id);
    } else {
      final nl = _Line();
      setState(() => _lines.add(nl));
      _onProductPicked(nl, match.id);
    }
  }

  // ---------------- اجزای پرداخت ----------------
  void _toggleCash() {
    setState(() {
      _useCash = !_useCash;
      if (!_useCash && !_hasNonCash) _useCash = true;
    });
  }

  void _toggleCheque() {
    setState(() {
      _useCheque = !_useCheque;
      if (_useCheque && _cheques.isEmpty) _addCheque();
      if (!_useCheque) {
        _chequeCharge = null;
        if (!_isEdit) _saleChequeIncome = 0;
      }
    });
  }

  void _removeSaleChequeCharge() {
    setState(() {
      _chequeCharge = null;
      _saleChequeIncome = 0;
      _chargeInvoiceBase = 0;
    });
  }

  void _toggleInst() {
    setState(() {
      _useInst = !_useInst;
      if (_useInst && _insts.isEmpty) _buildInsts(silent: true);
    });
  }

  void _toggleCredit() {
    setState(() {
      _useCredit = !_useCredit;
      if (_useCredit && _creditDue == null) {
        _creditDue = DateTime.now().add(const Duration(days: 30));
      }
    });
  }

  void _addCheque() {
    final rest = _finalRemaining;
    _cheques.add(
      _ChequeRow()
        ..amount = rest > 0 ? formatNumText(rest.toStringAsFixed(0)) : '',
    );
  }

  void _removeCheque(int i) {
    setState(() => _cheques.removeAt(i));
  }

  /// همان BuildInstallments وب
  void _buildInsts({bool silent = false}) {
    if (_instCount < 1) {
      if (!silent) _toast('تعداد قسط را وارد کنید.');
      return;
    }
    if (_instFirstDue == null) {
      if (!silent) _toast('تاریخ اولین قسط را وارد کنید.');
      return;
    }
    final totalDue = _grandTotal - _cashPart - _chequeSum;
    if (totalDue <= 0) {
      if (!silent) _toast('ابتدا اقلام فاکتور را وارد کنید.');
      return;
    }
    setState(() {
      _insts.clear();
      const roundUnit = 10000.0;
      final baseAmount = totalDue >= roundUnit * _instCount
          ? (totalDue / _instCount / roundUnit).floorToDouble() * roundUnit
          : (totalDue / _instCount).floorToDouble();
      for (var i = 0; i < _instCount; i++) {
        final amount = i == _instCount - 1
            ? totalDue - baseAmount * (_instCount - 1)
            : baseAmount;
        _insts.add(
          _InstRow()
            ..no = i + 1
            ..amount = formatNumText(amount.toStringAsFixed(0))
            ..dueDate = _instFirstDue!.add(Duration(days: i * _instInterval)),
        );
      }
    });
  }

  int get _declaredMethod {
    if (!_hasNonCash) return PayMethod.cash;
    final activeParts = [
      if (_cashPart > 0) 1,
      if (_useCheque) 1,
      if (_useInst) 1,
      if (_useCredit) 1,
    ].length;
    if (activeParts > 1) return PayMethod.mixed;
    if (_useCheque) return PayMethod.cheque;
    if (_useInst) return PayMethod.installment;
    return PayMethod.credit;
  }

  // ---------------- ذخیره ----------------
  Future<void> _save({bool printAfter = false}) async {
    // همان اعتبارسنجی‌های وب، با همان متن‌ها
    if (_warehouseId == 0) {
      _toast('انبار را انتخاب کنید.');
      return;
    }
    if (_partyId == 0) {
      _toast('طرف حساب را انتخاب کنید.');
      return;
    }
    if (_date == null) {
      _toast('تاریخ سند را وارد کنید.');
      return;
    }
    final validLines =
        _lines.where((l) => l.productId > 0 && l.qtyValue > 0).toList();
    if (validLines.isEmpty) {
      _toast('حداقل یک سطر کالای معتبر وارد کنید.');
      return;
    }
    for (final l in validLines) {
      final rounded = double.parse(l.qtyValue.toStringAsFixed(2));
      if (l.qtyValue != rounded &&
          (l.originalQty == null || l.qtyValue != l.originalQty)) {
        _toast('مقدار هر سطر حداکثر تا دو رقم اعشار قابل ثبت است.');
        return;
      }
    }

    // ---------- حالت ثبت پیش‌فاکتور فروش ----------
    if (_isProforma) {
      final proformaCmd = SalesProformaCommand(
        warehouseId: _warehouseId,
        partyId: _partyId,
        date: _date!,
        description: _descCtrl.text.trim(),
        referrerId: _referrerId > 0 ? _referrerId : null,
        lines: [
          for (final l in validLines)
            SalesProformaLine(
              productId: l.productId,
              productName: _productOf(l.productId)?.name ?? '',
              unit: l.unit,
              isService: _productOf(l.productId)?.isService ?? false,
              quantity: l.qtyValue,
              price: l.priceValue,
              discountPercent: l.discountPercent,
              discountAmount: l.discountAmount,
              discountIsAmount: l.discountIsAmount,
              vatValue: l.vatValue,
            ),
        ],
      );
      setState(() => _saving = true);
      try {
        final created = await _repo.createProforma(proformaCmd);
        if (!mounted) return;
        if (printAfter) {
          await showShopInvoicePrintSheet(
            context,
            repo: _repo,
            order: created.toOrder(),
            isProforma: true,
          );
        }
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } catch (e) {
        if (!mounted) return;
        setState(() => _saving = false);
        _toast(e.toString());
      }
      return;
    }

    final cmd = <String, dynamic>{
      'warehouseId': _warehouseId,
      'partyId': _partyId,
      'type': widget.type,
      'date': _date!.toIso8601String(),
      'description': _descCtrl.text.trim(),
      if (_isSale && _referrerId > 0) 'referrerId': _referrerId,
      'lines': [
        for (final l in validLines)
          {
            'id': l.id,
            'productId': l.productId,
            'quantity': l.qtyValue,
            'price': l.priceValue,
            if (!_isSale && _canUpdateSalePrice && l.newSalePriceValue > 0)
              'newSalePrice': l.newSalePriceValue,
            'discountPercent': l.discountPercent,
            'discountAmount': l.discountAmount,
            'discountIsAmount': l.discountIsAmount,
            'vatValue': l.vatValue,
          },
      ],
    };

    // ---------- پرداخت (همان منطق وب) ----------
    if (_hasNonCash && _cashPart > 0 && _cashPart >= _grandTotal) {
      _toast(
        'مبلغ نقدی نمی‌تواند برابر یا بیشتر از مبلغ سند باشد؛ در این صورت فقط «نقدی» را فعال کنید.',
      );
      return;
    }
    final cash = _hasNonCash ? _cashPart : _grandTotal;

    if (_isSale &&
        cash > 0 &&
        _cashKind == CashKind.cardTransfer &&
        _cashTrackingCtrl.text.trim().isEmpty) {
      _toast('کد رهگیری کارت به کارت را وارد کنید.');
      return;
    }

    cmd['paymentMethod'] = _declaredMethod;
    cmd['cashType'] = _cashKind;
    if (_cashKind == CashKind.cardTransfer &&
        _cashTrackingCtrl.text.trim().isNotEmpty) {
      cmd['cashTrackingNumber'] = _cashTrackingCtrl.text.trim();
    }
    if (_trsAccountId != null && _trsAccountId! > 0) {
      cmd['trsAccountId'] = _trsAccountId;
    }
    cmd['cashAmount'] = _hasNonCash ? cash : 0;

    final chequeList = <Map<String, dynamic>>[];
    if (_useCheque) {
      if (_cheques.isEmpty) {
        _toast('حداقل یک چک ثبت کنید.');
        return;
      }
      for (var i = 0; i < _cheques.length; i++) {
        final c = _cheques[i];
        if (c.number.trim().isEmpty) {
          _toast('شماره چک ردیف ${Fa.digits(i + 1)} را وارد کنید.');
          return;
        }
        if (c.dueDate == null) {
          _toast('سررسید چک ردیف ${Fa.digits(i + 1)} را وارد کنید.');
          return;
        }
        if (c.amountValue <= 0) {
          _toast('مبلغ چک ردیف ${Fa.digits(i + 1)} را وارد کنید.');
          return;
        }
        chequeList.add({
          'id': c.id,
          'number': c.number.trim(),
          'trsAccountId': c.trsAccountId,
          'bankName': c.bankName.trim().isEmpty ? null : c.bankName.trim(),
          'ownerName': c.owner.trim().isEmpty ? null : c.owner.trim(),
          'amount': c.amountValue,
          'dueDate': c.dueDate!.toIso8601String(),
          'isCleared': false,
        });
      }
    }

    final instList = <Map<String, dynamic>>[];
    if (_useInst) {
      if (_insts.isEmpty) {
        _toast('ابتدا دفترچه اقساط را بسازید.');
        return;
      }
      for (var i = 0; i < _insts.length; i++) {
        final r = _insts[i];
        if (r.dueDate == null) {
          _toast('سررسید قسط ${Fa.digits(i + 1)} را وارد کنید.');
          return;
        }
        if (r.amountValue <= 0) {
          _toast('مبلغ قسط ${Fa.digits(i + 1)} را وارد کنید.');
          return;
        }
        instList.add({
          'id': r.id,
          'no': i + 1,
          'amount': r.amountValue,
          'dueDate': r.dueDate!.toIso8601String(),
          'isPaid': false,
        });
      }
    }

    cmd['cheques'] = chequeList;
    cmd['installments'] = instList;
    if (_isSale && _useCheque && _chequeCharge != null) {
      cmd['chequeCharge'] = _chequeCharge!.toJson();
    }

    final paid = cash +
        chequeList.fold<double>(0, (s, c) => s + (c['amount'] as double)) +
        instList.fold<double>(0, (s, c) => s + (c['amount'] as double));
    final remainder = _grandTotal - paid;
    if (remainder > 1) {
      if (!_useCredit || _creditDue == null) {
        _toast(
          'جمع پرداخت‌ها (${Fa.number(paid)}) کمتر از مبلغ سند (${Fa.number(_grandTotal)}) است؛ '
          'باقی‌ماندهٔ ${Fa.number(remainder)} ریال به نسیه می‌رود — جزء «نسیه» را فعال و تاریخ سررسید را وارد کنید.',
        );
        return;
      }
      cmd['dueDate'] = _creditDue!.toIso8601String();
    }

    setState(() => _saving = true);
    try {
      final ShopOrder savedOrder;
      if (_isConvertingProforma) {
        savedOrder = await _repo.convertProforma(
          widget.convertingProforma!.id,
          cmd,
        );
      } else if (_isEdit) {
        savedOrder = widget.source!.hasChequeCharge
            ? await _repo.editChequeOrder(widget.source!.id, cmd)
            : await _repo.updateOrder(widget.source!.id, cmd);
      } else {
        savedOrder = await _repo.createOrder(cmd);
      }
      if (!mounted) return;
      if (printAfter && savedOrder.id > 0) {
        await showShopInvoicePrintSheet(
          context,
          repo: _repo,
          order: savedOrder,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.toString());
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ShopColors.danger,
      ),
    );
  }

  // ---------------- انتخاب‌گرها ----------------
  Future<void> _pickDate({required String title, required ValueChanged<DateTime> onPicked}) async {
    final picked = await showJalaliDatePicker(context, title: title);
    if (picked == null || !mounted) return;
    setState(() => onPicked(picked));
  }

  Future<void> _pickProduct(_Line l) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductPickerSheet(
        products: _selectableProducts,
        warehouseStocks: _warehouseStocks,
        warehouseSelected: _warehouseId > 0,
        sale: _isSale,
      ),
    );
    if (picked != null) _onProductPicked(l, picked);
  }

  Future<void> _openNewParty() async {
    // همان فرم طرف حساب (فیلدها یک‌به‌یک مثل مودال وب)
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PartyFormPage(
          type: _isSale ? PartyType.customer : PartyType.supplier,
        ),
      ),
    );
    if (saved != true) return;
    try {
      final list = (await _repo.parties(
        type: _isSale ? PartyType.customer : PartyType.supplier,
        take: 1000,
      )).items;
      if (!mounted) return;
      setState(() => _parties = list);
      // انتخاب خودکار آخرین طرف حساب افزوده‌شده
      final newest = list.isEmpty ? null : list.reduce((a, b) => a.id > b.id ? a : b);
      if (newest != null) {
        _onPartyChanged(newest.id);
        _toast('«${newest.name}» افزوده و انتخاب شد.');
      }
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _openQuickBank({int? chequeIndex, int? initialKind}) async {
    final defaultKind = initialKind ??
        (chequeIndex != null
            ? AccountKind.bank
            : (_cashKind == CashKind.cash
                  ? AccountKind.cash
                  : AccountKind.bank));
    final created = await showModalBottomSheet<TrsAccount>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickBankSheet(repo: _repo, initialKind: defaultKind),
    );
    if (created == null || !mounted) return;
    setState(() {
      if (!_accounts.any((a) => a.id == created.id)) {
        _accounts = [..._accounts, created];
      }
      if (chequeIndex != null && chequeIndex < _cheques.length) {
        _cheques[chequeIndex].trsAccountId = created.id;
        _cheques[chequeIndex].bankName =
            created.bankName ?? created.name;
      } else {
        _trsAccountId = created.id;
      }
    });
    _toast('حساب «${created.name}» ثبت و انتخاب شد.');
  }

  Future<void> _showLastPurchase(int productId) async {
    ShopOrder? order;
    String? err;
    try {
      order = await _repo.lastPurchase(productId);
    } catch (e) {
      err = e.toString();
    }
    if (!mounted) return;
    if (err != null) {
      _toast(err);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LastPurchaseSheet(order: order, productId: productId),
    );
  }

  /// همان دکمهٔ «آخرین خرید کالاها (F8)» در بالای جدول اقلام وب
  Future<void> _showAllLastPurchases() async {
    final ids = _lines
        .map((l) => l.productId)
        .where((id) => id > 0 && !(_productOf(id)?.isService ?? false))
        .toSet()
        .toList();
    if (ids.isEmpty) {
      _toast('ابتدا حداقل یک کالای غیرخدماتی در اقلام فاکتور انتخاب کنید.');
      return;
    }
    if (ids.length == 1) {
      await _showLastPurchase(ids.first);
      return;
    }
    final items = <({Product product, ShopOrder? order})>[];
    for (final id in ids) {
      final prod = _productOf(id);
      if (prod == null) continue;
      ShopOrder? ord;
      try {
        ord = await _repo.lastPurchase(id);
      } catch (_) {}
      items.add((product: prod, order: ord));
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
          decoration: const BoxDecoration(
            color: ShopColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ShopColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'آخرین خرید کالاهای فاکتور',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 10, color: ShopColors.line),
                  itemBuilder: (_, idx) {
                    final e = items[idx];
                    final line = e.order?.lines
                        .where((x) => x.productId == e.product.id)
                        .firstOrNull;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${e.product.code} — ${e.product.name}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: ShopColors.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (e.order == null || line == null)
                            const Text(
                              'فاکتور خریدی برای این کالا ثبت نشده است.',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: ShopColors.inkFaint,
                              ),
                            )
                          else
                            Text(
                              'فاکتور ${Fa.digits(e.order!.number)} · ${e.order!.partyName} · '
                              '${e.order!.date != null ? jalaliShort(e.order!.date!) : '—'} · '
                              'فی خرید: ${Fa.number(line.price)} ریال · مقدار: ${Fa.number(line.quantity)}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: ShopColors.inkSoft,
                                height: 1.6,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCalc(bool forCheque, {bool interestOnly = false}) async {
    final cashWithoutAll = _hasNonCash ? parseNum(_cashAmountCtrl.text) : 0.0;
    final rawRemain = forCheque
        ? _goodsTotal - cashWithoutAll - _instSum
        : _grandTotal - _cashPart - _chequeSum;
    final baseRemain = rawRemain < 0 ? 0.0 : rawRemain;
    final result = await showModalBottomSheet<_CalcResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CalcSheet(
        initialBase: baseRemain,
        initialStart:
            _instFirstDue ?? DateTime.now().add(const Duration(days: 30)),
        initialInterval: _instInterval,
        initialMonths: interestOnly && _cheques.isNotEmpty
            ? _cheques.length
            : 3,
        interestOnly: interestOnly,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (forCheque) {
        if (!interestOnly) {
          _cheques.clear();
          for (var i = 0; i < result.months; i++) {
            _cheques.add(
              _ChequeRow()
                ..amount = formatNumText(result.amounts[i].toStringAsFixed(0))
                ..dueDate = result.start.add(
                  Duration(days: i * result.interval),
                ),
            );
          }
        }
        if (_isSale) {
          _chequeCharge = SaleChequeChargeInput(
            calculatorBaseAmount: result.baseAmount,
            calculatorRatePercent: result.ratePercent,
            calculatorMonths: result.months,
            adjustmentRatePercent: result.ratePercent,
            adjustmentPeriodDays: result.interval > 0 ? result.interval : 30,
          );
          _saleChequeIncome = result.interest;
          _chargeInvoiceBase = _goodsTotal;
        }
      } else {
        _insts.clear();
        for (var i = 0; i < result.months; i++) {
          _insts.add(
            _InstRow()
              ..no = i + 1
              ..amount = formatNumText(result.amounts[i].toStringAsFixed(0))
              ..dueDate = result.start.add(Duration(days: i * result.interval)),
          );
        }
        _instCount = result.months;
        _instInterval = result.interval;
        _instFirstDue = result.start;
      }
    });
    _toast(
      forCheque
          ? (interestOnly
                ? 'تاخیر تادیه چک (${Fa.number(result.interest)} ریال) محاسبه و به مبلغ نهایی فاکتور افزوده شد.'
                : '${Fa.number(result.months)} چک ساخته شد — مبلغ نهایی ${Fa.number(result.total)} ریال (شامل ${Fa.number(result.interest)} سود). شماره و بانک هر چک را تکمیل کنید.')
          : 'دفترچه ${Fa.number(result.months)} قسطی ساخته شد — مبلغ نهایی ${Fa.number(result.total)} ریال (شامل ${Fa.number(result.interest)} سود).',
    );
  }

  // ================= UI =================
  String get _screenTitle {
    if (_isProforma) return 'صدور پیش‌فاکتور فروش';
    if (_isConvertingProforma) {
      return 'تبدیل پیش‌فاکتور ${Fa.digits(widget.convertingProforma!.number)} به فروش';
    }
    if (widget.copyTemplate != null) {
      return _isSale ? 'کپی و صدور فاکتور فروش' : 'کپی و ثبت فاکتور خرید';
    }
    if (_isEdit) {
      return _isSale
          ? 'ویرایش فاکتور فروش ${Fa.digits(widget.source!.number)}'
          : 'ویرایش فاکتور خرید ${Fa.digits(widget.source!.number)}';
    }
    return _isSale ? 'صدور فاکتور فروش' : 'ثبت فاکتور خرید';
  }

  @override
  Widget build(BuildContext context) {
    final primaryBtnLabel = _isProforma
        ? 'ثبت پیش‌فاکتور'
        : _isEdit
        ? 'ذخیره تغییرات'
        : (_isSale ? 'ثبت فاکتور فروش' : 'ثبت فاکتور خرید');
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: Text(
          _screenTitle,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              children: [
                // ۱. اطلاعات فاکتور (سربرگ) — هم در خرید و هم در فروش مثل وب
                _headerCard(),
                const SizedBox(height: 10),
                // ۲. اقلام فاکتور (کالاها و خدمات) — بالاتر از روش پرداخت هم در خرید و هم در فروش
                _linesCard(),
                if (_isSale && (_canSeeProfit || _referrerId > 0))
                  _profitBox(),
                // ۳. خلاصهٔ فاکتور و روش پرداخت ترکیبی — پایین‌تر از بخش کالا مثل وب
                if (!_isProforma) ...[
                  const SizedBox(height: 10),
                  _paymentCard(),
                ],
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: ShopColors.surface,
            border: Border(top: BorderSide(color: ShopColors.line)),
          ),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  foregroundColor: ShopColors.inkSoft,
                  side: const BorderSide(color: ShopColors.line),
                ),
                child: const Text('انصراف', style: TextStyle(fontSize: 12)),
              ),
              if (!_isProforma) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : () => _save(printAfter: true),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: ShopColors.teal,
                      side: const BorderSide(color: ShopColors.teal),
                    ),
                    icon: const Icon(Icons.print_rounded, size: 17),
                    label: Text(
                      _isEdit ? 'ذخیره و چاپ' : 'ثبت و چاپ',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : () => _save(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: ShopColors.seed,
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    primaryBtnLabel,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Text(
          t,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: ShopColors.inkFaint,
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(
              fontSize: 11,
              color: ShopColors.danger,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    ),
  );

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isProforma
                ? 'اطلاعات پیش‌فاکتور'
                : (_isSale ? 'اطلاعات فاکتور فروش' : 'اطلاعات فاکتور خرید'),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: ShopColors.ink,
            ),
          ),
          if (widget.copyTemplate != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: ShopColors.teal.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: ShopColors.teal.withValues(alpha: 0.35),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.copy_all_rounded,
                    size: 15,
                    color: ShopColors.teal,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'این فاکتور جدید است؛ اقلام را بازبینی کنید. اطلاعات پرداخت و گردش فاکتور قبلی کپی نشده است.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: ShopColors.inkSoft,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          _label('انبار', required: true),
          DropdownButtonFormField<int>(
            initialValue: _warehouseId == 0 ? null : _warehouseId,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            hint: const Text(
              'انتخاب انبار…',
              style: TextStyle(fontSize: 11.5),
            ),
            style: const TextStyle(fontSize: 12.5, color: ShopColors.ink),
            items: [
              for (final w in _warehouses)
                DropdownMenuItem<int>(value: w.id, child: Text(w.name)),
            ],
            onChanged: _onWarehouseChanged,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _label(_isSale ? 'مشتری' : 'تأمین‌کننده', required: true)),
              GestureDetector(
                onTap: _openNewParty,
                child: Row(
                  children: [
                    const Icon(
                      Icons.add_circle_rounded,
                      size: 14,
                      color: ShopColors.ok,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isSale ? 'مشتری جدید' : 'تأمین‌کننده جدید',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: ShopColors.ok,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          DropdownButtonFormField<int>(
            initialValue: _partyId == 0 ? null : _partyId,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            hint: const Text(
              'انتخاب طرف حساب…',
              style: TextStyle(fontSize: 11.5),
            ),
            style: const TextStyle(fontSize: 12.5, color: ShopColors.ink),
            items: [
              for (final p in _parties.where((p) => p.isActive))
                DropdownMenuItem<int>(
                  value: p.id,
                  child: Text(
                    _isSale
                        ? '${p.name} — ${(p.referrerName ?? '').isEmpty ? 'بدون معرف' : 'معرف: ${p.referrerName}'}'
                        : p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _onPartyChanged,
          ),
          const SizedBox(height: 10),
          _label('تاریخ سند', required: true),
          InkWell(
            onTap: () => _pickDate(
              title: 'تاریخ سند',
              onPicked: _onInvoiceDateChanged,
            ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ShopColors.line),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: ShopColors.inkFaint,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _date == null ? 'انتخاب تاریخ' : jalaliShort(_date!),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _label('توضیحات'),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'اختیاری',
              hintStyle: TextStyle(fontSize: 11.5, color: ShopColors.inkFaint),
            ),
            style: const TextStyle(fontSize: 12.5),
          ),
          if (_isSale && _referrerId > 0) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: ShopColors.seed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.badge_rounded,
                    size: 14,
                    color: ShopColors.seed,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'معرف این مشتری: ${_referrers.where((r) => r.id == _referrerId).map((r) => r.name).firstOrNull ?? '—'}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: ShopColors.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paymentCard() {
    final partyName =
        _parties.where((p) => p.id == _partyId).map((p) => p.name).firstOrNull ??
        '—';
    final whName =
        _warehouses
            .where((w) => w.id == _warehouseId)
            .map((w) => w.name)
            .firstOrNull ??
        '—';
    final instLabel = _isSale ? 'اقساط' : 'اعلامیه پرداخت';
    final instTabLabel = _isSale ? 'اقساطی' : 'اعلامیه پرداخت';
    final remainLabel = _finalRemaining > 1
        ? (_useCredit ? 'مانده نسیه' : 'باقی‌مانده')
        : _finalRemaining < -1
        ? 'مازاد پرداخت'
        : 'باقی‌مانده';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- خلاصهٔ فاکتور و پرداخت (هم‌تراز با purchase-summary وب) ----------
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ShopColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ShopColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _summaryMeta(
                        _isSale ? 'مشتری' : 'تأمین‌کننده',
                        partyName,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _summaryMeta('انبار', whName)),
                    const SizedBox(width: 8),
                    _summaryMeta(
                      'اقلام',
                      '${Fa.number(_validLines.length)} سطر',
                    ),
                  ],
                ),
                const Divider(height: 12, color: ShopColors.line),
                _sumLine(
                  'مبلغ نهایی فاکتور',
                  '${Fa.number(_grandTotal)} ریال',
                  ShopColors.seed,
                  bold: true,
                ),
                if (_hasChequeIncomeArticle)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'کالا با ارزش افزوده ${Fa.number(_goodsTotal)} + تاخیر تادیه چک ${Fa.number(_saleChequeIncome)} ریال',
                      style: const TextStyle(
                        fontSize: 10,
                        color: ShopColors.inkSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                _sumLine('نقد', Fa.number(_cashPart), ShopColors.ok),
                _sumLine('چک', Fa.number(_chequeSum), ShopColors.ink),
                _sumLine(instLabel, Fa.number(_instSum), ShopColors.ink),
                _sumLine(
                  remainLabel,
                  Fa.number(_finalRemaining.abs()),
                  _finalRemaining < -1
                      ? ShopColors.warn
                      : _finalRemaining > 1
                      ? ShopColors.danger
                      : ShopColors.ok,
                  bold: true,
                ),
                if (_finalRemaining.abs() > 1) ...[
                  const SizedBox(height: 4),
                  Text(
                    _finalRemaining < -1
                        ? 'جمع پرداخت‌ها بیشتر از مبلغ فاکتور است.'
                        : _useCredit
                        ? 'مانده فاکتور به نسیه می‌رود؛ تاریخ سررسید را بررسی کنید.'
                        : 'برای مانده فاکتور، پرداخت دیگری اضافه کنید یا نسیه و سررسید آن را مشخص کنید.',
                    style: TextStyle(
                      fontSize: 9.8,
                      color: _finalRemaining < -1
                          ? ShopColors.warn
                          : ShopColors.danger,
                      height: 1.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'روش پرداخت (ترکیبی)',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: ShopColors.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'می‌توانید چند جزء را هم‌زمان فعال کنید (نقد + چک + $instLabel + نسیه)؛ باقی‌ماندهٔ هر سطر بر اساس سطرهای قبلی و مبلغ نقدی محاسبه می‌شود.',
            style: const TextStyle(
              fontSize: 9.5,
              color: ShopColors.inkFaint,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _payTab('نقدی', Icons.payments_rounded, _useCash, _toggleCash),
              _payTab(
                'چک',
                Icons.account_balance_rounded,
                _useCheque,
                _toggleCheque,
              ),
              _payTab(
                instTabLabel,
                Icons.event_note_rounded,
                _useInst,
                _toggleInst,
              ),
              _payTab(
                'نسیه',
                Icons.hourglass_bottom_rounded,
                _useCredit,
                _toggleCredit,
              ),
            ],
          ),
          // ---------- جزء نقدی ----------
          if (_useCash) ...[
            const SizedBox(height: 10),
            if (_hasNonCash) ...[
              _label(
                _isSale
                    ? 'دریافت نقدی (بخشی از مبلغ)'
                    : 'پرداخت نقدی (بخشی از مبلغ)',
              ),
              TextField(
                controller: _cashAmountCtrl,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                onChanged: (v) {
                  final f = formatNumText(v);
                  if (f != v) {
                    _cashAmountCtrl.value = TextEditingValue(
                      text: f,
                      selection: TextSelection.collapsed(offset: f.length),
                    );
                  }
                  setState(() {});
                },
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '0',
                ),
                style: const TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 8),
            ],
            _label('نوع ${_isSale ? 'دریافت' : 'پرداخت'} نقدی'),
            DropdownButtonFormField<String>(
              initialValue: _cashType,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              style: const TextStyle(fontSize: 12, color: ShopColors.ink),
              items: const [
                DropdownMenuItem(value: '0', child: Text('وجه نقد')),
                DropdownMenuItem(value: '1', child: Text('کارت‌خوان (POS)')),
                DropdownMenuItem(value: '2', child: Text('کارت به کارت')),
              ],
              onChanged: (v) => setState(() {
                _cashType = v ?? '0';
                final valid = _accountsForCashType;
                if (_trsAccountId != null &&
                    !valid.any((a) => a.id == _trsAccountId)) {
                  _trsAccountId =
                      valid.where((a) => a.isDefault).firstOrNull?.id ??
                      valid.firstOrNull?.id;
                }
              }),
            ),
            const SizedBox(height: 8),
            _label('بانک/صندوق'),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    initialValue: _trsAccountId,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    hint: Text(
                      _cashKind == CashKind.cash
                          ? '— انتخاب صندوق —'
                          : '— انتخاب بانک —',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: ShopColors.ink,
                    ),
                    items: [
                      for (final a in _accountsForCashType)
                        DropdownMenuItem<int?>(
                          value: a.id,
                          child: Text(
                            a.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _trsAccountId = v),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: () => _openQuickBank(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: ShopColors.seed,
                    side: const BorderSide(color: ShopColors.line),
                  ),
                  child: Text(
                    _cashKind == CashKind.cash ? 'تعریف صندوق' : 'تعریف بانک',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            if (_cashKind == CashKind.cardTransfer) ...[
              const SizedBox(height: 8),
              _label('شماره پیگیری پرداخت', required: _isSale),
              TextField(
                controller: _cashTrackingCtrl,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _isSale
                      ? 'شماره پیگیری پرداخت (الزامی)'
                      : 'شماره پیگیری پرداخت (اختیاری)',
                  hintStyle: const TextStyle(
                    fontSize: 11,
                    color: ShopColors.inkFaint,
                  ),
                ),
                style: const TextStyle(fontSize: 12.5),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              _hasNonCash
                  ? 'باقی‌مانده پس از نقد: ${Fa.number(_remainingAfterCash)} ریال'
                  : 'تمام مبلغ نقدی است.',
              style: const TextStyle(fontSize: 10, color: ShopColors.inkFaint),
            ),
          ],
          // ---------- جزء چک ----------
          if (_useCheque) ...[
            const SizedBox(height: 10),
            Text(
              _isSale
                  ? 'چک‌های دریافتی از مشتری'
                  : 'چک‌های پرداختی به تأمین‌کننده',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: ShopColors.inkSoft,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (_isSale)
                  OutlinedButton.icon(
                    onPressed: () => _openCalc(true, interestOnly: true),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: const Icon(Icons.percent_rounded, size: 14),
                    label: const Text(
                      'محاسبه سود چک‌های دستی',
                      style: TextStyle(fontSize: 10.5),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _openCalc(true),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.calculate_rounded, size: 14),
                  label: const Text(
                    'محاسبه اقساطِ چک',
                    style: TextStyle(fontSize: 10.5),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(_addCheque),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 14),
                  label: const Text(
                    'افزودن چک',
                    style: TextStyle(fontSize: 10.5),
                  ),
                ),
              ],
            ),
            if (_cheques.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'هنوز چکی اضافه نشده است؛ با «افزودن چک» ردیف جدید با مبلغ باقی‌مانده ساخته می‌شود.',
                  style: TextStyle(fontSize: 10, color: ShopColors.inkFaint),
                ),
              ),
            for (var i = 0; i < _cheques.length; i++) _chequeRow(i),
            if (_hasChequeIncomeArticle) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: ShopColors.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ShopColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'تاخیر تادیه چک',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: ShopColors.ink,
                            ),
                          ),
                        ),
                        if (!_isEdit && _chequeCharge != null)
                          TextButton(
                            onPressed: _removeSaleChequeCharge,
                            style: TextButton.styleFrom(
                              foregroundColor: ShopColors.danger,
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'حذف ردیف سود',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'بدهکار مشتری: ${Fa.number(_saleChequeIncome)} ریال · بستانکار فروشگاه: ${Fa.number(_saleChequeIncome)} ریال',
                      style: const TextStyle(
                        fontSize: 10,
                        color: ShopColors.inkSoft,
                      ),
                    ),
                    if (_chequeCharge != null &&
                        (_chargeInvoiceBase - _goodsTotal).abs() > 1)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'مبلغ کالا تغییر کرده است؛ پیش از ثبت، تاخیر تادیه چک را دوباره محاسبه کنید.',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: ShopColors.danger,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
          // ---------- جزء اقساط / اعلامیه پرداخت ----------
          if (_useInst) ...[
            const SizedBox(height: 10),
            Text(
              _isSale ? 'دفترچه اقساط' : 'اعلامیه پرداخت',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: ShopColors.inkSoft,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('تعداد قسط'),
                      TextFormField(
                        initialValue: _instCount.toString(),
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        onChanged: (v) =>
                            _instCount = (int.tryParse(toEnDigits(v)) ?? 0),
                        decoration: const InputDecoration(isDense: true),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('فاصله (روز)'),
                      TextFormField(
                        initialValue: _instInterval.toString(),
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        onChanged: (v) => _instInterval =
                            int.tryParse(toEnDigits(v)) ?? _instInterval,
                        decoration: const InputDecoration(isDense: true),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _label('تاریخ اولین قسط'),
            InkWell(
              onTap: () => _pickDate(
                title: 'تاریخ اولین قسط',
                onPicked: (d) => _instFirstDue = d,
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ShopColors.line),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 15,
                      color: ShopColors.inkFaint,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _instFirstDue == null
                          ? 'انتخاب تاریخ'
                          : jalaliShort(_instFirstDue!),
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _buildInsts(),
                    icon: const Icon(Icons.playlist_add_rounded, size: 15),
                    label: const Text(
                      'ساخت دفترچه',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openCalc(false),
                    icon: const Icon(Icons.calculate_rounded, size: 15),
                    label: const Text(
                      'محاسبه با سود',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'رند اقساط: ۱۰٬۰۰۰ ریال؛ جمع دقیق حفظ می‌شود.',
              style: TextStyle(fontSize: 9.8, color: ShopColors.inkFaint),
            ),
            const SizedBox(height: 6),
            if (_insts.isEmpty)
              const Text(
                'با «ساخت دفترچه» اقساط بر اساس باقی‌ماندهٔ فعلی ساخته می‌شوند.',
                style: TextStyle(fontSize: 10, color: ShopColors.inkFaint),
              )
            else ...[
              for (var i = 0; i < _insts.length; i++) _instRow(i),
              Text(
                'جمع $instLabel: ${Fa.number(_instSum)} — باقی‌ماندهٔ تجمعی: ${Fa.number(_finalRemaining)}',
                style: const TextStyle(fontSize: 10, color: ShopColors.inkSoft),
              ),
            ],
          ],
          // ---------- جزء نسیه ----------
          if (_useCredit) ...[
            const SizedBox(height: 10),
            _label('تاریخ سررسید نسیه', required: true),
            InkWell(
              onTap: () => _pickDate(
                title: 'تاریخ سررسید نسیه',
                onPicked: (d) => _creditDue = d,
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ShopColors.line),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_rounded,
                      size: 15,
                      color: ShopColors.inkFaint,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _creditDue == null
                          ? 'انتخاب تاریخ'
                          : jalaliShort(_creditDue!),
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'مبلغ نسیه (باقی‌ماندهٔ نهایی): ${Fa.number(_finalRemaining < 0 ? 0 : _finalRemaining)} ریال',
              style: const TextStyle(fontSize: 10, color: ShopColors.danger),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _finalRemaining > 1
                ? 'جمع پرداخت‌ها ${Fa.number(_grandTotal - _finalRemaining)} ریال است؛ باقی‌ماندهٔ ${Fa.number(_finalRemaining)} ریال به‌صورت نسیه ثبت می‌شود.'
                : _finalRemaining < -1
                ? 'جمع پرداخت‌ها ${Fa.number(-_finalRemaining)} ریال بیشتر از مبلغ سند است (سود مدت‌دار).'
                : 'جمع اجزای پرداخت با مبلغ سند برابر است.',
            style: TextStyle(
              fontSize: 10,
              height: 1.7,
              color: _finalRemaining > 1
                  ? ShopColors.danger
                  : _finalRemaining < -1
                  ? ShopColors.warn
                  : ShopColors.ok,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryMeta(String k, String v) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        k,
        style: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
      ),
      const SizedBox(height: 1),
      Text(
        v,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: ShopColors.ink,
        ),
      ),
    ],
  );

  Widget _chequeRow(int i) {
    final c = _cheques[i];
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: ShopColors.bg,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'چک ${Fa.digits(i + 1)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: ShopColors.inkSoft,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _removeCheque(i),
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: ShopColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('شماره چک/صیاد', required: true),
                    TextField(
                      controller: TextEditingController(text: c.number)
                        ..selection = TextSelection.collapsed(
                          offset: c.number.length,
                        ),
                      onChanged: (v) => c.number = v,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(isDense: true),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('مبلغ (ریال)', required: true),
                    TextField(
                      controller: TextEditingController(text: c.amount)
                        ..selection = TextSelection.collapsed(
                          offset: c.amount.length,
                        ),
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      onChanged: (v) {
                        c.amount = formatNumText(v);
                        setState(() {});
                      },
                      decoration: const InputDecoration(isDense: true),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(
                      _isSale ? 'بانک' : 'بانک (حساب ما)',
                    ),
                    if (_isSale)
                      TextField(
                        controller: TextEditingController(text: c.bankName)
                          ..selection = TextSelection.collapsed(
                            offset: c.bankName.length,
                          ),
                        onChanged: (v) => c.bankName = v,
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'نام بانک…',
                          hintStyle: TextStyle(fontSize: 11),
                        ),
                        style: const TextStyle(fontSize: 12),
                      )
                    else
                      DropdownButtonFormField<int?>(
                        initialValue: c.trsAccountId,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true),
                        hint: const Text(
                          '— انتخاب حساب بانکی —',
                          style: TextStyle(fontSize: 11),
                        ),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: ShopColors.ink,
                        ),
                        items: [
                          for (final b in _accounts.where(
                            (a) => a.kind == AccountKind.bank,
                          ))
                            DropdownMenuItem<int?>(
                              value: b.id,
                              child: Text(
                                b.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() {
                          c.trsAccountId = v;
                          final acc =
                              _accounts.where((a) => a.id == v).firstOrNull;
                          c.bankName = acc?.bankName ?? acc?.name ?? '';
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                children: [
                  const SizedBox(height: 14),
                  IconButton(
                    onPressed: () => _openQuickBank(chequeIndex: i),
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 18,
                      color: ShopColors.seed,
                    ),
                    tooltip: 'تعریف بانک جدید',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(_isSale ? 'صاحب چک' : 'در وجه / گیرنده'),
                    TextField(
                      controller: TextEditingController(text: c.owner)
                        ..selection = TextSelection.collapsed(
                          offset: c.owner.length,
                        ),
                      onChanged: (v) => c.owner = v,
                      decoration: const InputDecoration(isDense: true),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('سررسید چک', required: true),
                    InkWell(
                      onTap: () => _pickDate(
                        title: 'سررسید چک',
                        onPicked: (d) => c.dueDate = d,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ShopColors.line),
                        ),
                        child: Text(
                          c.dueDate == null ? 'انتخاب تاریخ' : jalaliShort(c.dueDate!),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'باقی‌مانده پس از این چک: ${Fa.number(_remainingAfterCheque(i))} ریال',
            style: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
          ),
        ],
      ),
    );
  }

  Widget _instRow(int i) {
    final r = _insts[i];
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: ShopColors.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'قسط ${Fa.digits(i + 1)}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: ShopColors.inkSoft,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => setState(() => _insts.removeAt(i)),
                child: const Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: ShopColors.danger,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: r.amount)
                    ..selection = TextSelection.collapsed(
                      offset: r.amount.length,
                    ),
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  onChanged: (v) {
                    r.amount = formatNumText(v);
                    setState(() {});
                  },
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'مبلغ',
                    hintStyle: TextStyle(fontSize: 10.5),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(
                    title: 'سررسید قسط',
                    onPicked: (d) => r.dueDate = d,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ShopColors.line),
                    ),
                    child: Text(
                      r.dueDate == null ? 'سررسید' : jalaliShort(r.dueDate!),
                      style: const TextStyle(fontSize: 10.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'باقی‌مانده پس از این قسط: ${Fa.number(_remainingAfterInst(i))}',
            style: const TextStyle(fontSize: 9, color: ShopColors.inkFaint),
          ),
        ],
      ),
    );
  }

  Widget _payTab(String label, IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? ShopColors.seed.withValues(alpha: 0.12)
              : ShopColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? ShopColors.seed.withValues(alpha: 0.45) : ShopColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? ShopColors.seed : ShopColors.inkFaint,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: active ? ShopColors.seed : ShopColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sumLine(String k, String v, Color c, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1.5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            k,
            style: const TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
          ),
        ),
        Text(
          v,
          style: TextStyle(
            fontSize: bold ? 12.5 : 11.5,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: c,
          ),
        ),
      ],
    ),
  );

  Widget _linesCard() {
    final gross = _lines.fold<double>(0, (s, l) => s + l.gross);
    final lineDiscount = _lines.fold<double>(0, (s, l) => s + l.discountAmount);
    final vatSum = _lines.fold<double>(0, (s, l) => s + l.vatAmount);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _isProforma ? 'اقلام پیش‌فاکتور' : 'اقلام فاکتور',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.ink,
                  ),
                ),
              ),
              if (_isSale && _canSeeProfit)
                TextButton.icon(
                  onPressed: _showAllLastPurchases,
                  icon: const Icon(Icons.history_rounded, size: 15),
                  label: const Text(
                    'آخرین خرید کالاها',
                    style: TextStyle(fontSize: 10.8),
                  ),
                ),
              TextButton.icon(
                onPressed: () => setState(() => _lines.add(_Line())),
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text(
                  'افزودن سطر',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          if (_isSale)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'تغییر تاریخ، قیمت سطرهای موجود را خودکار عوض نمی‌کند.',
                style: TextStyle(fontSize: 9.8, color: ShopColors.inkFaint),
              ),
            ),
          // نوار افزودن سریع با بارکد یا کد کالا
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeCtrl,
                    textDirection: TextDirection.ltr,
                    onSubmitted: _addByBarcode,
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.qr_code_scanner_rounded, size: 17),
                      hintText: 'افزودن سریع با بارکد یا کد کالا + Enter',
                      hintStyle: TextStyle(
                        fontSize: 11,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  onPressed: _addByBarcode,
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                  tooltip: 'افزودن کالا با بارکد/کد',
                ),
              ],
            ),
          ),
          for (var i = 0; i < _lines.length; i++) _lineCard(i),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: ShopColors.bg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              children: [
                _sumLine(
                  'جمع اقلام (${Fa.number(_lines.length)} سطر)',
                  Fa.number(_lines.fold<double>(0, (s, l) => s + l.qtyValue)),
                  ShopColors.inkSoft,
                ),
                _sumLine('جمع ناخالص', '${Fa.number(gross)} ریال', ShopColors.ink),
                _sumLine(
                  'تخفیف کل اقلام',
                  lineDiscount > 0 ? '- ${Fa.number(lineDiscount)} ریال' : '۰',
                  lineDiscount > 0 ? ShopColors.danger : ShopColors.inkFaint,
                ),
                if (vatSum > 0)
                  _sumLine(
                    'جمع ارزش افزوده',
                    '${Fa.number(vatSum)} ریال',
                    ShopColors.teal,
                  ),
                const Divider(height: 10, color: ShopColors.line),
                _sumLine(
                  _isProforma
                      ? 'مبلغ نهایی پیش‌فاکتور'
                      : 'مبلغ کالا با ارزش افزوده',
                  '${Fa.number(_goodsTotal)} ریال',
                  ShopColors.seed,
                  bold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineCard(int i) {
    final l = _lines[i];
    final p = _productOf(l.productId);
    final avail = _warehouseStocks[l.productId] ?? 0;
    final sellable = _sellableStocks[l.productId] ?? avail;
    final showStock = l.productId > 0 && _warehouseId > 0 && !(p?.isService ?? false);
    final minRev = l.minProfit?.minimumProfitEnabled == true
        ? l.minProfit?.minimumUnitRevenue
        : null;
    final belowMinProfit =
        _isSale && minRev != null && l.priceValue > 0 && l.priceValue < minRev;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: ShopColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: belowMinProfit
            ? Border.all(color: ShopColors.danger.withValues(alpha: 0.6))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickProduct(l),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ShopColors.line),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.productId == 0
                                ? 'جستجوی کالا…'
                                : (p?.isService == true
                                      ? '${p!.code} — ${p.name} (خدمات)'
                                      : '${p?.code ?? ''} — ${p?.name ?? ''}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: l.productId == 0
                                  ? ShopColors.inkFaint
                                  : ShopColors.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.expand_more_rounded,
                          size: 16,
                          color: ShopColors.inkFaint,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              if (_isSale && l.productId > 0 && !(p?.isService ?? false))
                IconButton(
                  onPressed: () => _showLastPurchase(l.productId),
                  icon: const Icon(
                    Icons.receipt_long_rounded,
                    size: 17,
                    color: ShopColors.seed,
                  ),
                  tooltip: 'آخرین فاکتور خرید این کالا',
                ),
              IconButton(
                onPressed: () => setState(() {
                  _lines.removeAt(i);
                  if (_lines.isEmpty) _lines.add(_Line());
                }),
                icon: const Icon(
                  Icons.close_rounded,
                  size: 17,
                  color: ShopColors.danger,
                ),
              ),
            ],
          ),
          if (l.unit.isNotEmpty || showStock || minRev != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 3),
              child: Wrap(
                spacing: 8,
                runSpacing: 2,
                children: [
                  if (l.unit.isNotEmpty)
                    Text(
                      'واحد: ${l.unit}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                  if (showStock)
                    Text(
                      'موجودی به تاریخ سند: ${Fa.number(avail)}'
                      '${_isSale && sellable < avail ? ' (قابل فروش با توجه به فروش‌های آتی: ${Fa.number(sellable)})' : ''}'
                      '${avail <= 0 ? ' (ناموجود)' : ''}',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: avail <= 0 || (_isSale && l.qtyValue > sellable)
                            ? ShopColors.danger
                            : ShopColors.inkFaint,
                      ),
                    ),
                  if (minRev != null)
                    Text(
                      'کف مجاز فی فروش: ${Fa.number(minRev)} ریال',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: belowMinProfit
                            ? ShopColors.danger
                            : ShopColors.teal,
                      ),
                    ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('مقدار'),
                    TextField(
                      controller: TextEditingController(text: l.qty)
                        ..selection = TextSelection.collapsed(
                          offset: l.qty.length,
                        ),
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      onChanged: (v) {
                        l.qty = v;
                        _recalcDiscount(l);
                        setState(() {});
                      },
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: '1.25',
                        hintStyle: TextStyle(fontSize: 10.5),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('قیمت واحد'),
                    TextField(
                      controller: TextEditingController(text: l.price)
                        ..selection = TextSelection.collapsed(
                          offset: l.price.length,
                        ),
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      onChanged: (v) {
                        l.manualPrice = true;
                        l.price = formatNumText(v);
                        _recalcDiscount(l);
                        setState(() {});
                      },
                      decoration: const InputDecoration(isDense: true),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _toggleDiscountMode(l),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text(
                              l.discountIsAmount
                                  ? 'تخفیف (ریال)'
                                  : 'تخفیف (٪)',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: ShopColors.seed,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.swap_horiz_rounded,
                              size: 12,
                              color: ShopColors.seed,
                            ),
                          ],
                        ),
                      ),
                    ),
                    TextField(
                      controller: TextEditingController(text: l.discount)
                        ..selection = TextSelection.collapsed(
                          offset: l.discount.length,
                        ),
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      onChanged: (v) {
                        _onDiscountInput(l, v);
                        setState(() {});
                      },
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: '0',
                        hintStyle: TextStyle(fontSize: 10.5),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(l.vatValue > 100 ? 'ارزش افزوده (ریال)' : 'ارزش افزوده (٪)'),
                    TextField(
                      controller: TextEditingController(text: l.vat)
                        ..selection = TextSelection.collapsed(
                          offset: l.vat.length,
                        ),
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      onChanged: (v) {
                        final n = parseNum(v);
                        l.vat = n > 100 ? formatNumText(v) : v;
                        setState(() {});
                      },
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: '0',
                        hintStyle: TextStyle(fontSize: 10.5),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!_isSale && _canUpdateSalePrice && l.productId > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: Text(
                    'قیمت فروش جدید (اختیاری · ریال):',
                    style: TextStyle(fontSize: 10.5, color: ShopColors.inkSoft),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: l.newSalePrice)
                      ..selection = TextSelection.collapsed(
                        offset: l.newSalePrice.length,
                      ),
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    onChanged: (v) => l.newSalePrice = formatNumText(v),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'قیمت فروش جدید',
                      hintStyle: TextStyle(fontSize: 10.5),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (l.gross > 0 && (l.discountAmount > 0 || l.vatAmount > 0))
                Text(
                  'ناخالص: ${Fa.number(l.gross)}',
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: ShopColors.inkSoft,
                  ),
                ),
              if (l.discountAmount > 0) ...[
                Text(
                  'تخفیف: ${Fa.number(l.discountAmount)}',
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: ShopColors.danger,
                  ),
                ),
                Text(
                  'پس از تخفیف: ${Fa.number(l.afterDiscount)}',
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: ShopColors.inkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (l.vatAmount > 0)
                Text(
                  'ارزش افزوده: ${Fa.number(l.vatAmount)}',
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: ShopColors.teal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              Text(
                'کل پس از ارزش افزوده: ${Fa.number(l.total)} ریال',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: ShopColors.seed,
                ),
              ),
              if (_isSale && _canSeeProfit && l.productId > 0)
                Text(
                  'سود ${Fa.number(_lineProfit(l))}',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: _lineProfit(l) >= 0
                        ? ShopColors.ok
                        : ShopColors.danger,
                  ),
                ),
              if (_isSale && _referrerId > 0 && l.productId > 0)
                Text(
                  'پورسانت ${Fa.number(_lineCommission(l))}',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: ShopColors.indigo,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profitBox() {
    final net = _totalProfit - _totalCommission;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ShopColors.line),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          if (_canSeeProfit)
            Text(
              'سود تخمینی: ${Fa.number(_totalProfit)} ریال',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: _totalProfit >= 0 ? ShopColors.ok : ShopColors.danger,
              ),
            ),
          if (_referrerId > 0)
            Text(
              'پورسانت معرف: ${Fa.number(_totalCommission)} ریال',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: ShopColors.indigo,
              ),
            ),
          if (_canSeeProfit && _referrerId > 0)
            Text(
              'سود خالص: ${Fa.number(net)} ریال',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: net >= 0 ? ShopColors.ok : ShopColors.danger,
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
//  انتخاب‌گر کالا — با نمایش موجودی همان انبار (مثل SearchSelect وب)
// ============================================================
class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet({
    required this.products,
    required this.warehouseStocks,
    required this.warehouseSelected,
    required this.sale,
  });

  final List<Product> products;
  final Map<int, double> warehouseStocks;
  final bool warehouseSelected;
  final bool sale;

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _q = TextEditingController();

  List<Product> get _filtered {
    final q = _q.text.trim();
    if (q.isEmpty) return widget.products.take(60).toList();
    return widget.products
        .where(
          (p) =>
              p.name.contains(q) ||
              p.code.contains(q) ||
              (p.barcode ?? '').contains(q),
        )
        .take(80)
        .toList();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'انتخاب کالا',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'جستجوی نام، کد یا بارکد…',
                hintStyle: TextStyle(
                  fontSize: 11.5,
                  color: ShopColors.inkFaint,
                ),
                prefixIcon: Icon(Icons.search_rounded, size: 18),
              ),
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: _filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'کالایی با این مشخصات پیدا نشد.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: ShopColors.line),
                      itemBuilder: (_, i) {
                        final p = _filtered[i];
                        final qty = widget.warehouseStocks[p.id] ?? 0;
                        final info = p.isService
                            ? 'خدمات'
                            : widget.warehouseSelected
                            ? 'موجودی در این انبار: ${Fa.number(qty)} ${p.unit}'
                            : '';
                        return ListTile(
                          dense: true,
                          title: Text(
                            p.isService
                                ? '${p.code} — ${p.name} (خدمات)'
                                : '${p.code} — ${p.name}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: info.isEmpty
                              ? null
                              : Text(
                                  info,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: (!p.isService && qty <= 0)
                                        ? ShopColors.danger
                                        : ShopColors.inkFaint,
                                  ),
                                ),
                          trailing: Text(
                            Fa.number(
                              widget.sale ? p.salePrice : p.purchasePrice,
                            ),
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: ShopColors.inkFaint,
                            ),
                          ),
                          onTap: () => Navigator.pop(context, p.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  ماشین‌حساب اقساط/چک با سود — آینهٔ مودال وب
//  سود سادهٔ ماهانه: پایه × درصد × تعداد ماه
// ============================================================
class _CalcResult {
  _CalcResult({
    required this.baseAmount,
    required this.ratePercent,
    required this.months,
    required this.interval,
    required this.start,
    required this.interest,
    required this.total,
    required this.amounts,
  });
  final double baseAmount;
  final double ratePercent;
  final int months;
  final int interval;
  final DateTime start;
  final double interest;
  final double total;
  final List<double> amounts;
}

class _CalcSheet extends StatefulWidget {
  const _CalcSheet({
    required this.initialBase,
    required this.initialStart,
    required this.initialInterval,
    this.initialMonths = 3,
    this.interestOnly = false,
  });

  final double initialBase;
  final DateTime initialStart;
  final int initialInterval;
  final int initialMonths;
  final bool interestOnly;

  @override
  State<_CalcSheet> createState() => _CalcSheetState();
}

class _CalcSheetState extends State<_CalcSheet> {
  late final _base =
      TextEditingController(text: formatNumText(widget.initialBase.toStringAsFixed(0)));
  final _rate = TextEditingController(text: '');
  late int _months = widget.initialMonths < 1 ? 3 : widget.initialMonths;
  late int _interval = widget.initialInterval;
  late DateTime _start = widget.initialStart;

  @override
  void dispose() {
    _base.dispose();
    _rate.dispose();
    super.dispose();
  }

  double get _baseVal => parseNum(_base.text);
  double get _rateVal => parseNum(_rate.text);
  double get _interest => (_baseVal * _rateVal / 100 * _months).roundToDouble();
  double get _total => _baseVal + _interest;
  double get _perMonth {
    if (_months <= 0) return 0;
    const roundUnit = 10000.0;
    return _total >= roundUnit * _months
        ? (_total / _months / roundUnit).floorToDouble() * roundUnit
        : (_total / _months).floorToDouble();
  }

  void _apply() {
    if (_baseVal <= 0 || _months < 1) return;
    final per = _perMonth;
    final last = _total - per * (_months - 1);
    final amounts = [
      for (var i = 0; i < _months; i++) i == _months - 1 ? last : per,
    ];
    Navigator.pop(
      context,
      _CalcResult(
        baseAmount: _baseVal,
        ratePercent: _rateVal,
        months: _months,
        interval: _interval,
        start: _start,
        interest: _interest,
        total: _total,
        amounts: amounts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.interestOnly
                        ? 'محاسبه سود چک‌های دستی'
                        : 'محاسبه اقساط با سود',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            const Text(
              'مبلغ پایه (ریال)',
              style: TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
            ),
            TextField(
              controller: _base,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              onChanged: (v) {
                final f = formatNumText(v);
                if (f != v) {
                  _base.value = TextEditingValue(
                    text: f,
                    selection: TextSelection.collapsed(offset: f.length),
                  );
                }
                setState(() {});
              },
              decoration: const InputDecoration(isDense: true),
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 8),
            const Text(
              'درصد سود ماهانه (٪ در ماه)',
              style: TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
            ),
            TextField(
              controller: _rate,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(isDense: true, hintText: '0'),
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تعداد ماه/قسط',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                      TextFormField(
                        initialValue: _months.toString(),
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        onChanged: (v) =>
                            setState(() => _months = int.tryParse(toEnDigits(v)) ?? 1),
                        decoration: const InputDecoration(isDense: true),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'فاصله (روز)',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                      TextFormField(
                        initialValue: _interval.toString(),
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        onChanged: (v) => _interval =
                            int.tryParse(toEnDigits(v)) ?? _interval,
                        decoration: const InputDecoration(isDense: true),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'تاریخ شروع',
              style: TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
            ),
            InkWell(
              onTap: () async {
                final d = await showJalaliDatePicker(
                  context,
                  title: 'تاریخ شروع',
                  initial: _start,
                );
                if (d != null) setState(() => _start = d);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ShopColors.line),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 15,
                      color: ShopColors.inkFaint,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      jalaliShort(_start),
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: ShopColors.bg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Column(
                children: [
                  _row('سود محاسبه‌شده', '${Fa.number(_interest)} ریال'),
                  _row('مبلغ نهایی', '${Fa.number(_total)} ریال'),
                  _row(
                    'هر قسط (تقریبی)',
                    '${Fa.number(_perMonth)} ریال',
                    bold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      foregroundColor: ShopColors.inkSoft,
                      side: const BorderSide(color: ShopColors.line),
                    ),
                    child: const Text('انصراف'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _apply,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      backgroundColor: ShopColors.seed,
                    ),
                    child: const Text('اعمال و ساخت سطرها'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            k,
            style: const TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
          ),
        ),
        Text(
          v,
          style: TextStyle(
            fontSize: bold ? 12.5 : 11.5,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: ShopColors.ink,
          ),
        ),
      ],
    ),
  );
}

// ============================================================
//  تعریف سریع بانک/صندوق — آینهٔ QuickBankModal وب
// ============================================================
class QuickBankSheet extends StatefulWidget {
  const QuickBankSheet({
    super.key,
    required this.repo,
    this.initialKind = AccountKind.bank,
  });

  final ShopRepository repo;
  final int initialKind;

  @override
  State<QuickBankSheet> createState() => _QuickBankSheetState();
}

class _QuickBankSheetState extends State<QuickBankSheet> {
  /// همان فهرست بانک‌های پرکاربرد وب
  static const _popularBanks = [
    'بانک ملت',
    'بانک ملی ایران',
    'بانک صادرات ایران',
    'بانک تجارت',
    'بانک سپه',
    'بانک سامان',
    'بانک پاسارگاد',
    'بانک پارسیان',
    'بانک رسالت',
    'بانک مهر ایران',
    'بانک کشاورزی',
    'بانک مسکن',
    'بانک رفاه کارگران',
    'بانک آینده',
    'بانک شهر',
    'بانک سینا',
    'بانک دی',
    'بانک اقتصاد نوین',
    'بانک کارآفرین',
    'بانک سرمایه',
    'بانک گردشگری',
    'پست بانک ایران',
  ];

  final _name = TextEditingController();
  final _bank = TextEditingController();
  final _accountNumber = TextEditingController();
  final _card = TextEditingController();
  final _iban = TextEditingController();
  final _branchName = TextEditingController();
  final _branchCode = TextEditingController();
  final _opening = TextEditingController(text: '0');
  final _description = TextEditingController();

  late int _kind = widget.initialKind;
  bool _isDefault = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _bank,
      _accountNumber,
      _card,
      _iban,
      _branchName,
      _branchCode,
      _opening,
      _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _toast('لطفاً نام / عنوان حساب را وارد کنید.');
      return;
    }
    if (_kind == AccountKind.bank && _bank.text.trim().isEmpty) {
      _toast('لطفاً نام بانک را مشخص کنید.');
      return;
    }
    setState(() => _saving = true);
    var iban = _iban.text.trim().toUpperCase();
    if (iban.startsWith('IR')) iban = iban.substring(2);
    try {
      final saved = await widget.repo.saveTrsAccount(
        TrsAccount(
          name: _name.text.trim(),
          kind: _kind,
          bankName: _bank.text.trim().isEmpty ? null : _bank.text.trim(),
          accountNumber: _accountNumber.text.trim().isEmpty
              ? null
              : _accountNumber.text.trim(),
          cardNumber: _card.text.trim().isEmpty ? null : _card.text.trim(),
          iban: iban.isEmpty ? null : iban,
          branchName: _branchName.text.trim().isEmpty
              ? null
              : _branchName.text.trim(),
          branchCode: _branchCode.text.trim().isEmpty
              ? null
              : _branchCode.text.trim(),
          openingBalance: parseNum(_opening.text),
          isDefault: _isDefault,
          isActive: true,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.toString());
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ShopColors.danger,
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 11, color: ShopColors.inkFaint),
  );

  @override
  Widget build(BuildContext context) {
    final isBankLike = _kind == AccountKind.bank || _kind == AccountKind.pos;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'تعریف بانک و حساب جدید',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            ShopField(
              label: 'نوع حساب',
              required: true,
              child: Wrap(
                spacing: 6,
                children: [
                  for (final e in const [
                    MapEntry(AccountKind.bank, 'حساب بانکی'),
                    MapEntry(AccountKind.cash, 'صندوق نقدی'),
                    MapEntry(AccountKind.pos, 'کارتخوان'),
                    MapEntry(AccountKind.pettyCash, 'تنخواه‌گردان'),
                  ])
                    GestureDetector(
                      onTap: () => setState(() {
                        _kind = e.key;
                        if (_name.text.trim().isEmpty) {
                          _name.text = switch (e.key) {
                            AccountKind.cash => 'صندوق نقدی',
                            AccountKind.pos => 'دستگاه کارتخوان',
                            AccountKind.pettyCash => 'تنخواه‌گردان',
                            _ => '',
                          };
                        }
                      }),
                      child: ShopTag(
                        text: e.value,
                        color: _kind == e.key
                            ? ShopColors.seed
                            : ShopColors.inkFaint,
                      ),
                    ),
                ],
              ),
            ),
            ShopField(
              label: 'نام / عنوان حساب',
              required: true,
              child: TextField(
                controller: _name,
                decoration: _dec('مثال: بانک ملت - حساب جاری ۱۲۳'),
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
            if (isBankLike) ...[
              ShopField(
                label: 'نام بانک',
                required: _kind == AccountKind.bank,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _bank,
                      decoration: _dec('مثال: ملت، صادرات، ملی، سامان…'),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final b in _popularBanks.take(8))
                          GestureDetector(
                            onTap: () => setState(() {
                              _bank.text = b;
                              if (_name.text.trim().isEmpty ||
                                  _name.text.startsWith('بانک ') ||
                                  _name.text.startsWith('حساب ')) {
                                _name.text = '$b - جاری';
                              }
                            }),
                            child: ShopTag(text: b, color: ShopColors.inkSoft),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              ShopField(
                label: 'شماره حساب',
                child: TextField(
                  controller: _accountNumber,
                  textDirection: TextDirection.ltr,
                  decoration: _dec('شماره حساب بانکی'),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
              ShopField(
                label: 'شماره کارت (۱۶ رقم)',
                child: TextField(
                  controller: _card,
                  textDirection: TextDirection.ltr,
                  decoration: _dec('xxxx-xxxx-xxxx-xxxx'),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
              ShopField(
                label: 'شماره شبا (بدون IR)',
                child: TextField(
                  controller: _iban,
                  textDirection: TextDirection.ltr,
                  decoration: _dec('۲۴ رقم شبا'),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
              ShopField(
                label: 'نام شعبه',
                child: TextField(
                  controller: _branchName,
                  decoration: _dec('مثال: شعبه مرکزی'),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
              ShopField(
                label: 'کد شعبه',
                child: TextField(
                  controller: _branchCode,
                  textDirection: TextDirection.ltr,
                  decoration: _dec('کد عددی شعبه'),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ],
            ShopField(
              label: 'مانده ابتدای دوره (ریال)',
              child: TextField(
                controller: _opening,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                onChanged: (v) {
                  final f = formatNumText(v);
                  if (f != v) {
                    _opening.value = TextEditingValue(
                      text: f,
                      selection: TextSelection.collapsed(offset: f.length),
                    );
                  }
                },
                decoration: _dec('0'),
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
            Row(
              children: [
                Switch(
                  value: _isDefault,
                  onChanged: (v) => setState(() => _isDefault = v),
                ),
                const Text(
                  'حساب پیش‌فرض دریافت/پرداخت',
                  style: TextStyle(fontSize: 11, color: ShopColors.inkSoft),
                ),
              ],
            ),
            ShopField(
              label: 'توضیحات اختیاری',
              child: TextField(
                controller: _description,
                decoration: _dec('یادداشت یا توضیحات اضافی…'),
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      foregroundColor: ShopColors.inkSoft,
                      side: const BorderSide(color: ShopColors.line),
                    ),
                    child: const Text('انصراف'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      backgroundColor: ShopColors.seed,
                    ),
                    child: Text(
                      _saving ? 'در حال ثبت…' : 'ثبت و انتخاب بانک',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  «آخرین فاکتور خرید» — آینهٔ مودال وب
// ============================================================
class _LastPurchaseSheet extends StatelessWidget {
  const _LastPurchaseSheet({required this.order, required this.productId});

  final ShopOrder? order;
  final int productId;

  @override
  Widget build(BuildContext context) {
    final o = order;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'آخرین فاکتور خرید',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            if (o == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'برای این کالا فاکتور خریدی ثبت نشده است.',
                  style: TextStyle(fontSize: 11.5, color: ShopColors.inkFaint),
                ),
              )
            else ...[
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  Text(
                    'شماره: ${o.number}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: ShopColors.seed,
                    ),
                  ),
                  Text(
                    'تاریخ: ${Fa.date(o.date?.toIso8601String(), time: false)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: ShopColors.inkSoft,
                    ),
                  ),
                  Text(
                    'تأمین‌کننده: ${o.partyName ?? '—'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: ShopColors.inkSoft,
                    ),
                  ),
                  Text(
                    'انبار: ${o.warehouseName ?? '—'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: ShopColors.inkSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final l in o.lines)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: l.productId == productId
                        ? ShopColors.warn.withValues(alpha: 0.1)
                        : ShopColors.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.productName,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${Fa.number(l.quantity)} × ${Fa.number(l.price)}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: ShopColors.inkSoft,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Fa.number(l.total),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: ShopColors.seed,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  const Spacer(),
                  const Text(
                    'مبلغ کل: ',
                    style: TextStyle(fontSize: 11, color: ShopColors.inkFaint),
                  ),
                  Text(
                    '${Fa.number(o.totalAmount)} ریال',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: ShopColors.seed,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                foregroundColor: ShopColors.inkSoft,
                side: const BorderSide(color: ShopColors.line),
              ),
              child: const Text('بستن'),
            ),
          ],
        ),
      ),
    );
  }
}
