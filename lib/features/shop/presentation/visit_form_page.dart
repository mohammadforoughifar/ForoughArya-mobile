// ============================================================
//  ثبت / ویرایش سفارش ویزیتوری
//  آینهٔ صفحهٔ وب: /sales/visits/new و /sales/visits/{Id}/edit
//                 → Pages/SalesVisit/VisitForm.razor
//
//  • سربرگ: شرکت مجاز کاربر (VisActor.CompanyName)
//  • انتخاب مشتری (فهرست مجاز کاربر + ثبت سریع مشتری جدید)
//  • انتخاب انبار → کالاها با قیمت و «استعلام برخط موجودی»
//  • سطرها: کالا، مقدار (۲ رقم اعشار)، قیمت، تخفیف درصدی/ریالی
//  • سقف تخفیف مجاز ویزیتور با همان پیام وب
//  • تاریخ دریافت محصول (اجباری)
//  • دکمه‌ها: «ذخیره پیش‌نویس» و «ذخیره و ارسال برای تأیید»
//  اعتبارسنجی‌ها عیناً وب (رجوع به کامنت‌های کنار هر شرط).
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/fa_num.dart';
import '../data/shop_repository.dart';
import '../models/visit_models.dart';
import 'shop_style.dart';

class VisitFormPage extends StatefulWidget {
  const VisitFormPage({super.key, this.orderId});

  /// > ۰ یعنی ویرایش سفارش موجود
  final int? orderId;

  @override
  State<VisitFormPage> createState() => _VisitFormPageState();
}

class _VisitFormPageState extends State<VisitFormPage> {
  late final ShopRepository _repo;

  VisActor? _me;
  List<VisWarehouse> _warehouses = const [];
  List<VisProduct> _products = const [];

  int? _partyId;
  String? _partyName;
  int _warehouseId = 0;
  int _paymentMethod = 0;
  DateTime _date = DateTime.now();
  DateTime? _deliveryDate;
  final _noteCtrl = TextEditingController();
  final List<_LineVm> _lines = [];

  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => (widget.orderId ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');

  /// عدد اعشاری فارسی بدون صفرهای اضافی (معادل Fa.Digits وب)
  static String _dec(double v) {
    final t = v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    return Fa.digits(t);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await _repo.visMe();
      List<VisWarehouse> whs = const [];
      try {
        whs = await _repo.visWarehouses();
      } catch (_) {}

      VisOrder? order;
      if (_isEdit) {
        order = await _repo.visOrder(widget.orderId!);
        if (order == null) throw Exception('سفارش یافت نشد.');
        // همان قاعدهٔ وب: فقط پیش‌نویس/ارسال‌شده/برگشتی قابل ویرایش است
        final canEditThis =
            (me.canApprove || me.isAdmin) || VisStatus.canEdit(order.status);
        if (!VisStatus.canEdit(order.status) && !me.isAdmin) {
          throw Exception(
            canEditThis
                ? 'این سفارش در وضعیتی نیست که قابل ویرایش باشد.'
                : 'این سفارش در وضعیتی نیست که قابل ویرایش باشد.',
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _me = me;
        _warehouses = whs;
        if (order != null) {
          _partyId = order.partyId;
          _partyName = order.partyName;
          _warehouseId = order.warehouseId;
          _paymentMethod = order.paymentMethod;
          _date = order.date ?? DateTime.now();
          _deliveryDate = order.deliveryDate;
          _noteCtrl.text = order.note ?? '';
          _lines
            ..clear()
            ..addAll(order.lines.map(_LineVm.fromModel));
        } else {
          _warehouseId = me.defaultWarehouseId > 0
              ? me.defaultWarehouseId
              : (whs.isEmpty ? 0 : whs.first.id);
          _deliveryDate = DateTime.now();
        }
        _loading = false;
      });
      if (_warehouseId > 0) _loadProducts();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _clean(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadProducts() async {
    if (_warehouseId <= 0) {
      setState(() => _products = const []);
      return;
    }
    try {
      final list = await _repo.visProducts(warehouseId: _warehouseId);
      if (!mounted) return;
      setState(() => _products = list);
    } catch (_) {}
  }

  void _toast(String msg, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        backgroundColor: ok ? ShopColors.ok : null,
      ),
    );
  }

  Future<void> _pickCustomer() async {
    final picked = await showModalBottomSheet<VisCustomer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _VisCustomerSheet(repo: _repo),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _partyId = picked.id;
      _partyName = picked.name;
    });
  }

  Future<void> _addLine() async {
    if (_warehouseId <= 0) {
      _toast('ابتدا انبار را انتخاب کنید.');
      return;
    }
    final picked = await showModalBottomSheet<VisProduct>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _VisProductSheet(
        items: _products,
        onSearch: (q) async {
          try {
            final list = await _repo.visProducts(
              warehouseId: _warehouseId,
              search: q,
            );
            setState(() => _products = list);
            return list;
          } catch (_) {
            return const <VisProduct>[];
          }
        },
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _lines.add(
        _LineVm(
          productId: picked.id,
          productName: picked.name,
          unit: picked.unit,
          unitPrice: picked.salePrice,
          stock: picked.stock,
        ),
      );
    });
  }

  /// همان محاسبهٔ وب: تخفیف ریالی ↔ درصدی
  void _recalc(_LineVm l) {
    setState(() {
      if (l.discountIsAmount) {
        l.discountPercent = l.gross <= 0
            ? 0
            : (l.discountAmount / l.gross) * 100;
        if (l.discountPercent > 100) l.discountPercent = 100;
      } else {
        l.discountAmount = l.gross * (l.discountPercent / 100);
      }
      l.lineTotal = l.computeTotal();
    });
  }

  double get _netTotal => _lines.fold<double>(0, (s, l) => s + l.computeTotal());

  double get _grossTotal => _lines.fold<double>(0, (s, l) => s + l.gross);

  /// همان `SaveAsync` وب با تمام اعتبارسنجی‌ها
  Future<void> _save({required bool submit}) async {
    if ((_partyId ?? 0) <= 0) {
      _toast('مشتری را انتخاب کنید.');
      return;
    }
    if (_warehouseId <= 0) {
      _toast('انبار را انتخاب کنید.');
      return;
    }
    if (_lines.isEmpty) {
      _toast('حداقل یک کالا اضافه کنید.');
      return;
    }
    if (_lines.any((l) => l.productId <= 0)) {
      _toast('در هر سطر یک کالا انتخاب کنید (یا سطر خالی را حذف کنید).');
      return;
    }
    if (_lines.any((l) => l.qtyValue <= 0)) {
      _toast('مقدار هر سطر باید بزرگ‌تر از صفر باشد.');
      return;
    }
    if (_deliveryDate == null) {
      _toast('تاریخ دریافت محصول را انتخاب کنید.');
      return;
    }
    // سقف تخفیف مجاز — همان شرط و پیام وب
    final me = _me!;
    if (me.enforcesDiscountCap) {
      final over = _lines.where(
        (l) => l.discountPercent > me.maxDiscountPercent,
      );
      if (over.isNotEmpty) {
        _toast(
          'درصد تخفیف سطر «${over.first.productName}» '
          '(${_dec(over.first.discountPercent)}٪) بیش از سقف مجاز شما '
          '(${_dec(me.maxDiscountPercent)}٪) است.',
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final cmd = <String, dynamic>{
        'id': widget.orderId ?? 0,
        'date': _date.toIso8601String(),
        'deliveryDate': _deliveryDate!.toIso8601String(),
        'partyId': _partyId,
        'warehouseId': _warehouseId,
        'paymentMethod': _paymentMethod,
        'note': _noteCtrl.text.trim(),
        'submitAfterSave': submit,
        'lines': [
          for (final l in _lines)
            {
              'id': l.id,
              'productId': l.productId,
              'quantity': l.qtyValue,
              'unitPrice': l.priceValue,
              'discountPercent': l.discountPercent,
              'discountAmount': l.discountAmount,
              'discountIsAmount': l.discountIsAmount,
              'note': l.note(),
            },
        ],
      };
      final saved = await _repo.visSave(cmd);
      if (!mounted) return;
      _toast(
        submit ? 'سفارش ثبت و برای تأیید مدیر فروش ارسال شد.' : 'پیش‌نویس ذخیره شد.',
        ok: true,
      );
      Navigator.pop(context, true);
      // برای جلوگیری از هشدار «استفاده نشده» در تحلیل
      assert(saved.id >= 0);
    } catch (e) {
      if (!mounted) return;
      _toast(_clean(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: Text(
          _isEdit ? 'ویرایش سفارش ویزیتوری' : 'ثبت سفارش ویزیتوری جدید',
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ShopEmpty(
              title: 'بارگذاری سفارش ناموفق بود',
              subtitle: _error,
              icon: Icons.error_outline_rounded,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 110),
              children: [
                if ((_me?.companyName ?? '').isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: ShopColors.seed.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.business_rounded,
                          size: 14,
                          color: ShopColors.seed,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'شرکت مجاز: ${_me!.companyName}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: ShopColors.seed,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                _headCard(),
                const SizedBox(height: 10),
                _linesCard(),
                const SizedBox(height: 10),
                _totalsCard(),
              ],
            ),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => _save(submit: false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 46),
                          foregroundColor: ShopColors.seed,
                          side: BorderSide(
                            color: ShopColors.seed.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Text(
                          'ذخیره پیش‌نویس',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : () => _save(submit: true),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 46),
                          backgroundColor: ShopColors.ok,
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 16),
                        label: const Text(
                          'ذخیره و ارسال برای تأیید',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _headCard() => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      children: [
        ShopField(
          label: 'مشتری',
          required: true,
          child: InkWell(
            onTap: _pickCustomer,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
              decoration: BoxDecoration(
                border: Border.all(color: ShopColors.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _partyName ?? 'انتخاب مشتری…',
                      style: TextStyle(
                        fontSize: 12,
                        color: _partyName == null
                            ? ShopColors.inkFaint
                            : ShopColors.ink,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: ShopColors.inkFaint,
                  ),
                ],
              ),
            ),
          ),
        ),
        ShopField(
          label: 'انبار',
          required: true,
          child: DropdownButtonFormField<int>(
            initialValue: _warehouseId == 0 ? null : _warehouseId,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            style: const TextStyle(fontSize: 12, color: ShopColors.ink),
            items: [
              const DropdownMenuItem<int>(
                value: 0,
                child: Text('انتخاب انبار…'),
              ),
              for (final w in _warehouses)
                DropdownMenuItem<int>(value: w.id, child: Text(w.name)),
            ],
            onChanged: (v) {
              setState(() {
                _warehouseId = v ?? 0;
                _products = const [];
                _lines.clear();
              });
              _loadProducts();
            },
          ),
        ),
        Row(
          children: [
            Expanded(
              child: ShopField(
                label: 'تاریخ سفارش',
                child: _dateBtn(_date, (d) => setState(() => _date = d)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ShopField(
                label: 'تاریخ دریافت محصول',
                required: true,
                child: _dateBtn(
                  _deliveryDate ?? DateTime.now(),
                  (d) => setState(() => _deliveryDate = d),
                ),
              ),
            ),
          ],
        ),
        ShopField(
          label: 'روش پرداخت اعلامی',
          child: DropdownButtonFormField<int>(
            initialValue: _paymentMethod,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            style: const TextStyle(fontSize: 12, color: ShopColors.ink),
            items: const [
              DropdownMenuItem(value: 0, child: Text('نقدی')),
              DropdownMenuItem(value: 1, child: Text('نسیه')),
              DropdownMenuItem(value: 2, child: Text('چک')),
              DropdownMenuItem(value: 3, child: Text('اقساطی')),
            ],
            onChanged: (v) => setState(() => _paymentMethod = v ?? 0),
          ),
        ),
        ShopField(
          label: 'توضیحات',
          child: TextField(
            controller: _noteCtrl,
            maxLines: 2,
            style: const TextStyle(fontSize: 12.5),
            decoration: const InputDecoration(isDense: true),
          ),
        ),
      ],
    ),
  );

  Widget _linesCard() {
    final me = _me!;
    return Container(
      padding: const EdgeInsets.all(13),
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
              const Expanded(
                child: Text(
                  'اقلام سفارش',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed: _addLine,
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text(
                  'افزودن کالا',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          if (me.maxDiscountPercent > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'سقف تخفیف مجاز شما: ${_dec(me.maxDiscountPercent)} درصد '
                '(تخفیف بالاتر نیازمند تأیید مدیر است).',
                style: const TextStyle(
                  fontSize: 9.5,
                  color: ShopColors.inkFaint,
                ),
              ),
            ),
          if (_lines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'هنوز کالایی اضافه نشده است.',
                style: TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
              ),
            ),
          for (var i = 0; i < _lines.length; i++) _lineCard(i, _lines[i]),
        ],
      ),
    );
  }

  Widget _lineCard(int index, _LineVm l) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ShopColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: ShopColors.seed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'سطر ${Fa.number(index + 1)}',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: ShopColors.seed,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _lines.removeAt(index);
                    l.dispose();
                  });
                },
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: ShopColors.danger,
                ),
              ),
            ],
          ),
          Text(
            l.unit == null || l.unit!.isEmpty
                ? 'موجودی انبار: ${Fa.number(l.stock, decimals: 2)}'
                : '${l.unit} · موجودی: ${Fa.number(l.stock, decimals: 2)}',
            style: TextStyle(
              fontSize: 9.5,
              color: l.stock < l.qtyValue
                  ? ShopColors.danger
                  : ShopColors.inkFaint,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: l.qtyCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _recalc(l),
                  style: const TextStyle(fontSize: 11.5),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'مقدار',
                    hintStyle: TextStyle(fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: l.priceCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _recalc(l),
                  style: const TextStyle(fontSize: 11.5),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'قیمت واحد',
                    hintStyle: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: l.discountCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) {
                    if (l.discountIsAmount) {
                      l.discountAmount = parseNum(l.discountCtrl.text);
                    } else {
                      l.discountPercent = parseNum(l.discountCtrl.text);
                    }
                    _recalc(l);
                  },
                  style: const TextStyle(fontSize: 11.5),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l.discountIsAmount ? 'تخفیف (ریال)' : 'تخفیف (٪)',
                    hintStyle: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  setState(() => l.discountIsAmount = !l.discountIsAmount);
                  l.syncDiscountText();
                  _recalc(l);
                },
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: l.discountIsAmount
                        ? ShopColors.seed.withValues(alpha: 0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: ShopColors.line),
                  ),
                  child: Text(
                    l.discountIsAmount ? 'ریال' : '٪',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: l.discountIsAmount
                          ? ShopColors.seed
                          : ShopColors.inkSoft,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Fa.number(l.computeTotal()),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'جمع سطر',
                    style: TextStyle(fontSize: 8.5, color: ShopColors.inkFaint),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalsCard() => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: ShopColors.seed,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Row(
          children: [
            const Text(
              'مبلغ خالص سفارش',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            Text(
              '${Fa.number(_netTotal)} ریال',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                'جمع کل: ${Fa.number(_grossTotal)}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
            Text(
              'تخفیف: ${Fa.number(_grossTotal - _netTotal)}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _dateBtn(DateTime value, ValueChanged<DateTime> onPick) => InkWell(
    onTap: () async {
      final d = await showJalaliDatePicker(
        context,
        initial: value,
        title: 'انتخاب تاریخ',
      );
      if (d != null) onPick(d);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      decoration: BoxDecoration(
        border: Border.all(color: ShopColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_month_rounded,
            size: 14,
            color: ShopColors.inkFaint,
          ),
          const SizedBox(width: 5),
          Text(jalaliShort(value), style: const TextStyle(fontSize: 11.5)),
        ],
      ),
    ),
  );
}

/// یک سطر فرم سفارش
class _LineVm {
  _LineVm({
    this.id = 0,
    this.productId = 0,
    this.productName = '',
    this.unit,
    this.unitPrice = 0,
    this.stock = 0,
  });

  int id;
  int productId;
  String productName;
  String? unit;
  double unitPrice;
  double stock;
  double discountPercent = 0;
  double discountAmount = 0;
  bool discountIsAmount = false;
  double lineTotal = 0;

  final qtyCtrl = TextEditingController(text: '1');
  final priceCtrl = TextEditingController();
  final discountCtrl = TextEditingController();

  double get qtyValue => parseNum(qtyCtrl.text);

  double get priceValue => parseNum(priceCtrl.text);

  double get gross => qtyValue * priceValue;

  double computeTotal() => discountIsAmount
      ? (gross - discountAmount) < 0
            ? 0
            : gross - discountAmount
      : gross * (1 - discountPercent / 100);

  String? note() => null;

  void syncDiscountText() {
    discountCtrl.text = discountIsAmount
        ? (discountAmount == 0 ? '' : discountAmount.toStringAsFixed(0))
        : (discountPercent == 0
              ? ''
              : discountPercent.toStringAsFixed(2));
  }

  static _LineVm fromModel(VisLine l) {
    final vm = _LineVm(
      id: l.id,
      productId: l.productId,
      productName: l.productName,
      unit: l.unit,
    );
    vm.qtyCtrl.text = l.quantity == 0
        ? ''
        : l.quantity.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
    vm.priceCtrl.text = l.unitPrice == 0
        ? ''
        : l.unitPrice.toStringAsFixed(0);
    vm.discountPercent = l.discountPercent;
    vm.discountAmount = l.discountAmount;
    vm.discountIsAmount = l.discountIsAmount;
    vm.lineTotal = l.lineTotal;
    vm.syncDiscountText();
    return vm;
  }

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
    discountCtrl.dispose();
  }
}

/// انتخاب/جستجوی مشتری + ثبت سریع مشتری جدید
class _VisCustomerSheet extends StatefulWidget {
  const _VisCustomerSheet({required this.repo});

  final ShopRepository repo;

  @override
  State<_VisCustomerSheet> createState() => _VisCustomerSheetState();
}

class _VisCustomerSheetState extends State<_VisCustomerSheet> {
  final _q = TextEditingController();
  List<VisCustomer> _items = const [];
  bool _loading = true;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final list = await widget.repo.visCustomers(search: _q.text);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _createNew() async {
    final name = TextEditingController(text: toEnDigits(_q.text).trim());
    final mobile = TextEditingController();
    final address = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ثبت سریع مشتری جدید', style: TextStyle(fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              style: const TextStyle(fontSize: 12.5),
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'نام مشتری *',
                labelStyle: TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: mobile,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 12.5),
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'موبایل',
                labelStyle: TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: address,
              maxLines: 2,
              style: const TextStyle(fontSize: 12.5),
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'آدرس',
                labelStyle: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ثبت'),
          ),
        ],
      ),
    );
    final n = name.text.trim();
    final m = mobile.text.trim();
    final a = address.text.trim();
    name.dispose();
    mobile.dispose();
    address.dispose();
    if (ok != true || !mounted) return;
    if (n.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('نام مشتری را وارد کنید.', style: TextStyle(fontSize: 12)),
        ),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      final c = await widget.repo.visCreateCustomer(
        name: n,
        mobile: m.isEmpty ? null : m,
        address: a.isEmpty ? null : a,
      );
      if (!mounted) return;
      if (c != null) {
        Navigator.pop(context, c);
      } else {
        _search();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e
                .toString()
                .replaceFirst('ApiException: ', '')
                .replaceFirst('Exception: ', ''),
            style: const TextStyle(fontSize: 12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ShopColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'انتخاب مشتری',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              controller: _q,
              onChanged: (_) => _search(),
              style: const TextStyle(fontSize: 12.5),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'جستجوی نام یا موبایل مشتری…',
                hintStyle: TextStyle(fontSize: 12),
                prefixIcon: Icon(Icons.search_rounded, size: 18),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _creating ? null : _createNew,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  side: const BorderSide(color: ShopColors.line),
                  foregroundColor: ShopColors.seed,
                ),
                icon: const Icon(Icons.person_add_alt_rounded, size: 15),
                label: const Text(
                  'مشتری جدید ثبت کن',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const Center(
                    child: Text(
                      'مشتری‌ای یافت نشد',
                      style: TextStyle(
                        fontSize: 12,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: ShopColors.line),
                    itemBuilder: (_, i) {
                      final c = _items[i];
                      return ListTile(
                        dense: true,
                        title: Text(
                          c.name,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                        subtitle: Text(
                          [
                            if ((c.mobile ?? '').isNotEmpty) c.mobile!,
                            if (c.ownedByMe) 'در پروندهٔ من',
                            'مانده: ${Fa.number(c.balance)}',
                          ].join(' · '),
                          style: const TextStyle(fontSize: 10),
                        ),
                        trailing: (c.referrerName ?? '').isEmpty
                            ? null
                            : Text(
                                c.referrerName!,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  color: ShopColors.inkFaint,
                                ),
                              ),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// انتخاب کالا با موجودی همان انبار
class _VisProductSheet extends StatefulWidget {
  const _VisProductSheet({required this.items, required this.onSearch});

  final List<VisProduct> items;
  final Future<List<VisProduct>> Function(String) onSearch;

  @override
  State<_VisProductSheet> createState() => _VisProductSheetState();
}

class _VisProductSheetState extends State<_VisProductSheet> {
  final _q = TextEditingController();
  late List<VisProduct> _list;

  @override
  void initState() {
    super.initState();
    _list = widget.items;
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ShopColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'انتخاب کالا',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              controller: _q,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) async {
                final list = await widget.onSearch(v);
                if (!mounted) return;
                setState(() => _list = list);
              },
              style: const TextStyle(fontSize: 12.5),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'جستجوی کد یا نام کالا…',
                hintStyle: TextStyle(fontSize: 12),
                prefixIcon: Icon(Icons.search_rounded, size: 18),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _list.isEmpty
                ? const Center(
                    child: Text(
                      'کالایی یافت نشد',
                      style: TextStyle(
                        fontSize: 12,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _list.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: ShopColors.line),
                    itemBuilder: (_, i) {
                      final p = _list[i];
                      return ListTile(
                        dense: true,
                        title: Text(
                          p.name,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                        subtitle: Text(
                          '${p.code} · ${Fa.number(p.salePrice)} ریال · '
                          'موجودی ${Fa.number(p.stock, decimals: 2)}',
                          style: const TextStyle(fontSize: 10),
                        ),
                        trailing: p.isService
                            ? const ShopTag(
                                text: 'خدمت',
                                color: ShopColors.indigo,
                              )
                            : null,
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
