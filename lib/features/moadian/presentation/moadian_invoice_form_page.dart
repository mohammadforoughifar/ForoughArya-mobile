import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../../shop/data/fa_num.dart';
import '../data/moadian_calc.dart';
import '../data/moadian_perms.dart';
import '../data/moadian_repository.dart';
import '../models/moadian_models.dart';
import 'moadian_style.dart';

enum MoadianFormMode { create, edit, copy, eslahi }

class MoadianInvoiceFormPage extends StatefulWidget {
  const MoadianInvoiceFormPage({
    super.key,
    this.mode = MoadianFormMode.create,
    this.invoiceId,
    this.initialCpInfoId,
  });

  final MoadianFormMode mode;
  final int? invoiceId;
  final int? initialCpInfoId;

  @override
  State<MoadianInvoiceFormPage> createState() => _MoadianInvoiceFormPageState();
}

class _MoadianInvoiceFormPageState extends State<MoadianInvoiceFormPage> {
  late final MoadianRepository _repo = MoadianRepository(
    context.read<ApiClient>(),
  );

  List<MoadianCpInfo> _companies = const [];
  List<MoadianCustomer> _customers = const [];
  List<MoadianGood> _goods = const [];
  List<MoadianFiscalYear> _fiscalYears = const [];

  int _cpInfoId = 0;
  int? _nextInvoiceNo;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  late MoadianInvoice _vm = MoadianInvoice(
    id: 0,
    dateOrder: DateTime.now(),
    typePattern: 'نوع اول',
    paymentType: 'نقدی',
    subject: 'اصلی',
    statusSentToSystem: '0',
    statusSentToSystemInt: '0',
    isNew: true,
    items: [MoadianInvoiceItem()],
  );

  final TextEditingController _descCtrl = TextEditingController();

  bool get _isNewLike =>
      widget.mode == MoadianFormMode.create ||
      widget.mode == MoadianFormMode.copy;

  String get _title => switch (widget.mode) {
    MoadianFormMode.create => 'صدور صورتحساب جدید',
    MoadianFormMode.edit =>
      'ویرایش صورتحساب #${Fa.digits(widget.invoiceId ?? 0)}',
    MoadianFormMode.copy =>
      'کپی صورتحساب #${Fa.digits(widget.invoiceId ?? 0)}',
    MoadianFormMode.eslahi =>
      'صدور صورتحساب اصلاحی (#${Fa.digits(widget.invoiceId ?? 0)})',
  };

  String get _subtitle => switch (widget.mode) {
    MoadianFormMode.create => 'ثبت پیش‌نویس صورتحساب الکترونیکی با اقلام CPC',
    MoadianFormMode.edit => 'اصلاح اطلاعات و اقلام پیش از ارسال به سامانه',
    MoadianFormMode.copy => 'ذخیره به‌عنوان پیش‌نویس جدید با شماره مستقل',
    MoadianFormMode.eslahi => 'صدور سند اصلاحی (Ins=2) بر پایهٔ شماره مرجع',
  };

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final companies = await _repo.getCpInfos();
      int resolvedCp = widget.initialCpInfoId ?? 0;
      if (resolvedCp <= 0) {
        resolvedCp = await _repo.loadSavedCpInfoId() ?? 0;
      }
      if (resolvedCp <= 0 && companies.isNotEmpty) {
        resolvedCp = companies.first.cpInfoId;
      }

      if (widget.mode != MoadianFormMode.create &&
          (widget.invoiceId ?? 0) > 0) {
        final loaded = await _repo.getInvoice(
          widget.invoiceId!,
          cpInfoId: resolvedCp,
        );
        if ((loaded.cpInfoId ?? 0) > 0) {
          resolvedCp = loaded.cpInfoId!;
        }
        if (widget.mode == MoadianFormMode.copy) {
          _vm = MoadianInvoice(
            id: 0,
            cpInfoId: resolvedCp,
            customerId: loaded.customerId,
            customerName: loaded.customerName,
            fiscalYearId: loaded.fiscalYearId,
            typePattern: loaded.typePattern,
            dateOrder: DateTime.now(),
            paymentType: loaded.paymentType,
            description: loaded.description,
            statusSentToSystem: '0',
            statusSentToSystemInt: '0',
            subject: 'اصلی',
            isNew: true,
            items: loaded.invoiceItems.isEmpty
                ? [MoadianInvoiceItem()]
                : loaded.invoiceItems.map((e) => e.copy()..invoiceId = null).toList(),
          );
        } else if (widget.mode == MoadianFormMode.eslahi) {
          final refTax = MoadianCalc.primaryTaxNumber(loaded);
          _vm = MoadianInvoice(
            id: loaded.effectiveId,
            numberInvoice: loaded.numberInvoice,
            cpInfoId: resolvedCp,
            customerId: loaded.customerId,
            customerName: loaded.customerName,
            fiscalYearId: loaded.fiscalYearId,
            typePattern: loaded.typePattern,
            dateOrder: loaded.dateOrder ?? DateTime.now(),
            paymentType: loaded.paymentType,
            description: loaded.description,
            statusSentToSystem: '1',
            statusSentToSystemInt: '1',
            taxNumber: refTax.isNotEmpty ? refTax : loaded.taxNumber,
            subject: 'اصلاحی',
            isNew: false,
            items: loaded.invoiceItems.isEmpty
                ? [MoadianInvoiceItem()]
                : loaded.invoiceItems.map((e) => e.copy()).toList(),
          );
        } else {
          _vm = loaded;
          _vm.isNew = false;
          if (_vm.invoiceItems.isEmpty) {
            _vm.invoiceItems.add(MoadianInvoiceItem());
          }
        }
        _descCtrl.text = _vm.description ?? '';
      } else {
        _vm.cpInfoId = resolvedCp;
      }

      _companies = companies;
      _cpInfoId = resolvedCp;
      if (resolvedCp > 0) {
        await _loadProviderCatalogs(resolvedCp);
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadProviderCatalogs(int cpInfoId) async {
    List<MoadianCustomer> customers = const [];
    List<MoadianGood> goods = const [];
    List<MoadianFiscalYear> fys = const [];
    int? nextNo;

    await Future.wait<void>([
      () async {
        try {
          customers = await _repo.getCustomers(cpInfoId);
        } catch (_) {}
      }(),
      () async {
        try {
          goods = await _repo.getGoodsCombo(cpInfoId);
        } catch (_) {}
      }(),
      () async {
        try {
          fys = await _repo.getFiscalYears(cpInfoId);
        } catch (_) {}
      }(),
      if (_isNewLike)
        () async {
          try {
            nextNo = await _repo.nextInvoiceNumber(cpInfoId);
          } catch (_) {}
        }(),
    ]);

    _customers = customers;
    _goods = goods;
    _fiscalYears = fys;
    _nextInvoiceNo = nextNo;

    if (fys.isNotEmpty && _isNewLike) {
      final currentId = int.tryParse(_vm.fiscalYearId ?? '');
      final valid = currentId != null && fys.any((f) => f.id == currentId);
      if (!valid) {
        final dt = _vm.dateOrder ?? DateTime.now();
        final match = fys.where((f) => f.containsDate(dt)).firstOrNull ??
            fys.where((f) => f.isActive).firstOrNull ??
            fys.first;
        _vm.fiscalYearId = match.id.toString();
      }
    }
  }

  Future<void> _switchCpInfo(MoadianCpInfo c) async {
    if (c.cpInfoId == _cpInfoId) return;
    setState(() {
      _cpInfoId = c.cpInfoId;
      _vm.cpInfoId = c.cpInfoId;
      _vm.customerId = null;
      _vm.customerName = null;
      _vm.fiscalYearId = null;
      for (final r in _vm.invoiceItems) {
        r.goodsOrServicesId = 0;
        r.name = null;
        r.uniqueIdentifier = null;
        r.unitOfMeasurement = null;
      }
      _loading = true;
    });
    await _repo.saveActiveCpInfoId(c.cpInfoId);
    await _loadProviderCatalogs(c.cpInfoId);
    if (mounted) setState(() => _loading = false);
  }

  MoadianFiscalYear? get _selectedFy {
    final id = int.tryParse(_vm.fiscalYearId ?? '');
    if (id == null) return null;
    for (final f in _fiscalYears) {
      if (f.id == id) return f;
    }
    return null;
  }

  bool get _dateOutOfFiscalYear {
    final fy = _selectedFy;
    final dt = _vm.dateOrder;
    if (fy == null || dt == null) return false;
    return !fy.containsDate(dt);
  }

  Future<void> _pickCustomer() async {
    if (_customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'برای این شرکت هنوز مشتری ثبت نشده است؛ از تب اطلاعات پایه مشتری اضافه کنید.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    String q = '';
    final picked = await showModalBottomSheet<MoadianCustomer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) {
            final filtered = _customers.where((c) {
              if (q.trim().isEmpty) return true;
              final s = q.trim().toLowerCase();
              return c.name.toLowerCase().contains(s) ||
                  (c.nationalId ?? '').contains(s) ||
                  (c.economicNumber ?? '').contains(s) ||
                  (c.phone ?? '').contains(s);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.45,
              maxChildSize: 0.92,
              expand: false,
              builder: (_, sc) => Container(
                margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                decoration: BoxDecoration(
                  color: MoadianColors.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Text(
                      'انتخاب مشتری (خریدار)',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      autofocus: true,
                      onChanged: (v) => setS(() => q = toEnDigits(v)),
                      decoration: InputDecoration(
                        hintText: 'جستجو در نام، کد ملی/شناسه، کد اقتصادی…',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                        filled: true,
                        fillColor: MoadianColors.surfaceSoft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(
                            color: MoadianColors.line,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'مشتری مطابق جستجو یافت نشد.',
                                style: TextStyle(color: MoadianColors.inkSoft),
                              ),
                            )
                          : ListView.separated(
                              controller: sc,
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final c = filtered[i];
                                return ListTile(
                                  dense: true,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  leading: CircleAvatar(
                                    radius: 17,
                                    backgroundColor: MoadianColors.primary
                                        .withValues(alpha: 0.12),
                                    child: Icon(
                                      c.type == 'حقوقی'
                                          ? Icons.domain_rounded
                                          : Icons.person_rounded,
                                      size: 17,
                                      color: MoadianColors.primary,
                                    ),
                                  ),
                                  title: Text(
                                    c.displayLabel,
                                    style: const TextStyle(
                                      fontSize: 12.8,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  subtitle: Text(
                                    [
                                      if ((c.nationalId ?? '').isNotEmpty)
                                        'ملی/ثبت: ${Fa.digits(c.nationalId)}',
                                      if ((c.economicNumber ?? '').isNotEmpty)
                                        'اقتصادی: ${Fa.digits(c.economicNumber)}',
                                    ].join(' • '),
                                    style: const TextStyle(fontSize: 10.8),
                                  ),
                                  onTap: () => Navigator.pop(ctx, c),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _vm.customerId = picked.customerId;
        _vm.customerName = picked.name;
      });
    }
  }

  Future<void> _pickGoodForRow(MoadianInvoiceItem row) async {
    if (_goods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'کالایی برای این شرکت ثبت نشده است؛ از بخش «کالا و خدمات» اضافه کنید.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    String q = '';
    final picked = await showModalBottomSheet<MoadianGood>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) {
            final filtered = _goods.where((g) {
              if (q.trim().isEmpty) return true;
              final s = q.trim().toLowerCase();
              return g.name.toLowerCase().contains(s) ||
                  g.uniqueIdentifier.toLowerCase().contains(s);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.76,
              minChildSize: 0.45,
              maxChildSize: 0.92,
              expand: false,
              builder: (_, sc) => Container(
                margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                decoration: BoxDecoration(
                  color: MoadianColors.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Text(
                      'انتخاب کالا یا خدمت (شناسه CPC)',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      autofocus: true,
                      onChanged: (v) => setS(() => q = toEnDigits(v)),
                      decoration: InputDecoration(
                        hintText: 'جستجو با نام کالا یا کد ۱۳ رقمی CPC…',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                        filled: true,
                        fillColor: MoadianColors.surfaceSoft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(
                            color: MoadianColors.line,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text('کالا/خدمتی با این مشخصات یافت نشد.'),
                            )
                          : ListView.separated(
                              controller: sc,
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final g = filtered[i];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    g.name,
                                    style: const TextStyle(
                                      fontSize: 12.8,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'CPC: ${Fa.digits(g.uniqueIdentifier)} • واحد: ${g.unitOfMeasurement ?? '—'} • مالیات: ${Fa.number(g.valueAddedPercentage)}٪',
                                    style: const TextStyle(fontSize: 10.6),
                                  ),
                                  trailing: Text(
                                    '${Fa.number(g.price)} ریال',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: MoadianColors.primary,
                                    ),
                                  ),
                                  onTap: () => Navigator.pop(ctx, g),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        row.goodsOrServicesId = picked.goodsOrServicesId;
        row.name = picked.name;
        row.uniqueIdentifier = picked.uniqueIdentifier;
        row.priceUnit = picked.price;
        row.valueAddedPercentage = picked.valueAddedPercentage;
        row.unitOfMeasurement = picked.unitOfMeasurement;
        row.valueAddedAmount = null;
        row.calculatedPay = null;
      });
    }
  }

  Future<void> _editRowNumbers(MoadianInvoiceItem row, int index) async {
    final countCtrl = TextEditingController(
      text: row.count == row.count.roundToDouble()
          ? row.count.toInt().toString()
          : row.count.toString(),
    );
    final priceCtrl = TextEditingController(
      text: row.priceUnit.toInt().toString(),
    );
    final discCtrl = TextEditingController(
      text: row.discount.toInt().toString(),
    );
    final vatCtrl = TextEditingController(
      text: row.valueAddedPercentage == row.valueAddedPercentage.roundToDouble()
          ? row.valueAddedPercentage.toInt().toString()
          : row.valueAddedPercentage.toString(),
    );
    final descCtrl = TextEditingController(text: row.descriptionKala ?? '');

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: MoadianColors.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'ویرایش مقادیر ردیف ${Fa.digits(index + 1)} — ${row.name ?? 'کالا'}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: countCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'تعداد / مقدار',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: vatCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'ارزش افزوده (%)',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'فی واحد (ریال)',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: discCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'تخفیف ردیف (ریال)',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'شرح تکمیلی کالا در صورتحساب (اختیاری)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('انصراف'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: MoadianColors.primary,
                            ),
                            child: const Text('اعمال در ردیف'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (ok == true && mounted) {
      double parseNum(String s, double fallback) =>
          double.tryParse(toEnDigits(s).replaceAll(',', '').trim()) ?? fallback;
      setState(() {
        final c = parseNum(countCtrl.text, row.count);
        row.count = c <= 0 ? 1 : c;
        row.priceUnit = parseNum(priceCtrl.text, row.priceUnit);
        row.discount = parseNum(discCtrl.text, row.discount);
        row.valueAddedPercentage =
            parseNum(vatCtrl.text, row.valueAddedPercentage).clamp(0, 100);
        row.descriptionKala = descCtrl.text.trim().isEmpty
            ? null
            : descCtrl.text.trim();
        row.valueAddedAmount = null;
        row.calculatedPay = null;
      });
    }
    countCtrl.dispose();
    priceCtrl.dispose();
    discCtrl.dispose();
    vatCtrl.dispose();
    descCtrl.dispose();
  }

  Future<void> _save() async {
    if (_cpInfoId <= 0) {
      _toast('ابتدا یک پروندهٔ شرکت مودیان را انتخاب یا ثبت کنید.');
      return;
    }
    if (!_vm.isNoBuyerType && (_vm.customerId == null || _vm.customerId! <= 0)) {
      _toast('برای صورتحساب نوع اول انتخاب مشتری الزامی است.');
      return;
    }
    if (_vm.dateOrder == null) {
      _toast('تاریخ صورتحساب را انتخاب کنید.');
      return;
    }
    if ((_vm.fiscalYearId ?? '').trim().isEmpty) {
      _toast('سال مالی را انتخاب کنید.');
      return;
    }
    if (_vm.invoiceItems.isEmpty) {
      _toast('حداقل یک ردیف کالا یا خدمت وارد کنید.');
      return;
    }
    if (_vm.invoiceItems.any(
      (i) => (i.uniqueIdentifier ?? '').trim().isEmpty,
    )) {
      _toast('در همهٔ ردیف‌ها باید کالا/خدمت دارای کد CPC انتخاب شود.');
      return;
    }

    final grand = MoadianCalc.grandTotal(_vm.invoiceItems);
    _vm.cpInfoId = _cpInfoId;
    _vm.description = _descCtrl.text.trim();
    _vm.totalMoney = grand;
    if (_vm.isNoBuyerType) {
      _vm.customerId = null;
      _vm.paymentType = 'نقدی';
    }
    if (_vm.paymentType == 'نقدی') {
      _vm.priceNaghd = grand;
      _vm.priceNesye = 0;
    } else {
      _vm.priceNesye = grand;
      _vm.priceNaghd = 0;
    }
    if (_isNewLike) {
      _vm.isNew = true;
      _vm.id = 0;
      _vm.statusSentToSystem = '0';
      _vm.statusSentToSystemInt = '0';
      _vm.subject = 'اصلی';
    }

    setState(() => _saving = true);
    try {
      final res = widget.mode == MoadianFormMode.eslahi
          ? await _repo.eslahiInvoice(_vm)
          : await _repo.saveInvoice(_vm);
      if (!mounted) return;
      if (res.success) {
        HapticFeedback.mediumImpact();
        int? savedId;
        if (res.data is Map) {
          savedId = MoadianInvoice.fromJson(
            Map<String, dynamic>.from(res.data),
          ).effectiveId;
        }
        _toast(
          widget.mode == MoadianFormMode.eslahi
              ? 'صورتحساب اصلاحی با موفقیت ثبت و ارسال شد.'
              : 'صورتحساب ذخیره شد؛ برای ارسال به سامانه وارد جزئیات شوید.',
        );
        Navigator.of(context).pop(savedId ?? _vm.effectiveId);
      } else {
        _toast(res.message ?? 'ثبت صورتحساب ناموفق بود.');
      }
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthController>().session;
    final allowed = widget.mode == MoadianFormMode.create ||
            widget.mode == MoadianFormMode.copy
        ? MoadianPerms.can(session, MoadianPerms.invoiceCreate)
        : MoadianPerms.can(session, MoadianPerms.invoiceUpdate);

    final grand = MoadianCalc.grandTotal(_vm.invoiceItems);
    final totalVat = MoadianCalc.totalVat(_vm.invoiceItems);
    final totalDisc = MoadianCalc.totalDiscount(_vm.invoiceItems);

    return Scaffold(
      backgroundColor: MoadianColors.bg,
      body: Column(
        children: [
          MoadianPageHeader(title: _title, subtitle: _subtitle),
          if (!allowed && session != null)
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: MoadianEmptyCard(
                    icon: Icons.lock_outline_rounded,
                    title: 'عدم دسترسی به ثبت/ویرایش صورتحساب',
                    subtitle:
                        'شما مجوز لازم برای ایجاد یا ویرایش صورتحساب در مودیان تیسا را ندارید.',
                  ),
                ),
              ),
            )
          else if (_loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: MoadianColors.primary),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                children: [
                  if (_error != null) ...[
                    MoadianErrorBanner(message: _error!, onRetry: _loadInitial),
                    const SizedBox(height: 10),
                  ],

                  if (widget.mode == MoadianFormMode.create) ...[
                    MoadianCompanyBar(
                      companies: _companies,
                      activeCpInfoId: _cpInfoId,
                      onSelect: _switchCpInfo,
                    ),
                    const SizedBox(height: 10),
                  ],

                  if (widget.mode == MoadianFormMode.eslahi) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFCD34D)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.published_with_changes_rounded,
                                size: 18,
                                color: MoadianColors.warn,
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'صدور صورتحساب اصلاحی بر پایهٔ سند مرجع',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if ((_vm.taxNumber ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            MoadianCopyCodeRow(
                              label: 'کد مالیاتی مرجع',
                              code: _vm.taxNumber!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // کارت ۱: مشخصات سربرگ صورتحساب
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: MoadianColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: MoadianColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: MoadianSectionTitle(
                                title: 'مشخصات سربرگ صورتحساب',
                              ),
                            ),
                            MoadianSubjectBadge(subject: _vm.subject),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _InfoChipField(
                                label: 'شماره فاکتور داخلی',
                                value: _isNewLike
                                    ? (_nextInvoiceNo == null
                                          ? 'خودکار'
                                          : Fa.digits(_nextInvoiceNo))
                                    : Fa.digits(_vm.numberInvoice ?? _vm.id),
                                icon: Icons.tag_rounded,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  final d = await showJalaliDatePicker(
                                    context,
                                    initial: _vm.dateOrder ?? DateTime.now(),
                                    title: 'تاریخ صدور صورتحساب',
                                  );
                                  if (d != null && mounted) {
                                    setState(() => _vm.dateOrder = d);
                                  }
                                },
                                child: _InfoChipField(
                                  label: 'تاریخ صورتحساب *',
                                  value: jalaliShort(
                                    _vm.dateOrder ?? DateTime.now(),
                                  ),
                                  icon: Icons.event_rounded,
                                  interactive: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // نوع صورتحساب و روش تسویه
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                initialValue: const [
                                  'نوع اول',
                                  'نوع دوم',
                                  'نوع سوم',
                                ].contains(_vm.typePattern)
                                    ? _vm.typePattern
                                    : 'نوع اول',
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'نوع صورتحساب',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'نوع اول',
                                    child: Text(
                                      'نوع اول (با خریدار)',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'نوع دوم',
                                    child: Text(
                                      'نوع دوم (بی‌نام/نقدی)',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'نوع سوم',
                                    child: Text(
                                      'نوع سوم',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() {
                                    _vm.typePattern = v;
                                    if (_vm.isNoBuyerType) {
                                      _vm.customerId = null;
                                      _vm.customerName = null;
                                      _vm.paymentType = 'نقدی';
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                initialValue: _vm.isNoBuyerType
                                    ? 'نقدی'
                                    : (_vm.paymentType == 'نسیه'
                                          ? 'نسیه'
                                          : 'نقدی'),
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'نوع پرداخت',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: 'نقدی',
                                    child: Text(
                                      'نقدی',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  if (!_vm.isNoBuyerType)
                                    const DropdownMenuItem(
                                      value: 'نسیه',
                                      child: Text(
                                        'نسیه',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                ],
                                onChanged: _vm.isNoBuyerType
                                    ? null
                                    : (v) {
                                        if (v != null) {
                                          setState(() => _vm.paymentType = v);
                                        }
                                      },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // سال مالی
                        DropdownButtonFormField<String>(
                          initialValue: _fiscalYears.any(
                                (f) => f.id.toString() == _vm.fiscalYearId,
                              )
                              ? _vm.fiscalYearId
                              : null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'سال مالی *',
                            isDense: true,
                            border: const OutlineInputBorder(),
                            helperText: _fiscalYears.isEmpty
                                ? 'سال مالی برای این شرکت تعریف نشده است (از اطلاعات پایه ← شرکت تعریف کنید)'
                                : (_dateOutOfFiscalYear
                                      ? 'هشدار: تاریخ صورتحساب خارج از بازهٔ این سال مالی است!'
                                      : (_selectedFy == null
                                            ? null
                                            : 'بازه: ${jalaliShort(_selectedFy!.startDate)} تا ${jalaliShort(_selectedFy!.endDate)}')),
                            helperStyle: TextStyle(
                              fontSize: 10.2,
                              color: (_fiscalYears.isEmpty ||
                                      _dateOutOfFiscalYear)
                                  ? MoadianColors.danger
                                  : MoadianColors.inkSoft,
                            ),
                          ),
                          items: [
                            for (final fy in _fiscalYears)
                              DropdownMenuItem(
                                value: fy.id.toString(),
                                child: Text(
                                  fy.title.trim().isEmpty
                                      ? jalaliShort(fy.startDate).split('/').first
                                      : fy.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.2),
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() => _vm.fiscalYearId = v),
                        ),

                        // انتخاب مشتری (فقط در نوع اول)
                        if (!_vm.isNoBuyerType) ...[
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: _pickCustomer,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: MoadianColors.surfaceSoft,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: MoadianColors.line),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.person_search_rounded,
                                    size: 19,
                                    color: MoadianColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      (_vm.customerId ?? 0) > 0
                                          ? (_customers
                                                    .where(
                                                      (c) =>
                                                          c.customerId ==
                                                          _vm.customerId,
                                                    )
                                                    .firstOrNull
                                                    ?.displayLabel ??
                                                _vm.customerName ??
                                                'مشتری #${Fa.digits(_vm.customerId)}')
                                          : 'انتخاب مشتری (خریدار) *',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: (_vm.customerId ?? 0) > 0
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: (_vm.customerId ?? 0) > 0
                                            ? MoadianColors.ink
                                            : MoadianColors.inkSoft,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.expand_more_rounded,
                                    size: 19,
                                    color: MoadianColors.inkFaint,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 10),
                        TextField(
                          controller: _descCtrl,
                          decoration: const InputDecoration(
                            labelText: 'توضیحات صورتحساب (اختیاری)',
                            hintText: 'مثلاً: بابت فروش کالا طبق قرارداد',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // کارت ۲: ردیف‌های کالا و خدمت
                  MoadianSectionTitle(
                    title: 'اقلام صورتحساب (${Fa.digits(_vm.invoiceItems.length)} ردیف)',
                    subtitle: 'انتخاب کالا با شناسه ۱۳ رقمی CPC و محاسبه خودکار مالیات',
                    trailing: FilledButton.tonalIcon(
                      onPressed: () {
                        setState(() {
                          _vm.invoiceItems.add(MoadianInvoiceItem());
                        });
                      },
                      icon: const Icon(Icons.add_rounded, size: 17),
                      label: const Text(
                        'افزودن ردیف',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),

                  for (var i = 0; i < _vm.invoiceItems.length; i++) ...[
                    _InvoiceLineEditorCard(
                      index: i,
                      row: _vm.invoiceItems[i],
                      canRemove: _vm.invoiceItems.length > 1,
                      onPickGood: () => _pickGoodForRow(_vm.invoiceItems[i]),
                      onEditNumbers: () => _editRowNumbers(_vm.invoiceItems[i], i),
                      onRemove: () {
                        setState(() => _vm.invoiceItems.removeAt(i));
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),

          // نوار جمع نهایی و دکمه ذخیره چسبان در پایین
          if (!_loading && (allowed || session == null))
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: MoadianColors.surface,
                border: const Border(top: BorderSide(color: MoadianColors.line)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'تخفیف: ${Fa.number(totalDisc.round())} • ارزش افزوده: ${Fa.number(totalVat.round())}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.8,
                              color: MoadianColors.inkSoft,
                            ),
                          ),
                        ),
                        Text(
                          '${Fa.number(grand.round())} ریال',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: MoadianColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: MoadianColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: Text(
                          widget.mode == MoadianFormMode.eslahi
                              ? 'ثبت و ارسال صورتحساب اصلاحی'
                              : 'ذخیرهٔ صورتحساب در مودیان تیسا',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoChipField extends StatelessWidget {
  const _InfoChipField({
    required this.label,
    required this.value,
    required this.icon,
    this.interactive = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool interactive;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: interactive
          ? MoadianColors.primary.withValues(alpha: 0.06)
          : MoadianColors.surfaceSoft,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: interactive
            ? MoadianColors.primary.withValues(alpha: 0.3)
            : MoadianColors.line,
      ),
    ),
    child: Row(
      children: [
        Icon(icon, size: 17, color: MoadianColors.primary),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9.8,
                  color: MoadianColors.inkSoft,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.2,
                  fontWeight: FontWeight.w800,
                  color: MoadianColors.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InvoiceLineEditorCard extends StatelessWidget {
  const _InvoiceLineEditorCard({
    required this.index,
    required this.row,
    required this.canRemove,
    required this.onPickGood,
    required this.onEditNumbers,
    required this.onRemove,
  });

  final int index;
  final MoadianInvoiceItem row;
  final bool canRemove;
  final VoidCallback onPickGood;
  final VoidCallback onEditNumbers;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hasGood = (row.uniqueIdentifier ?? '').trim().isNotEmpty;
    final gross = MoadianCalc.lineGross(row);
    final vat = MoadianCalc.lineVat(row);
    final total = MoadianCalc.lineTotal(row);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MoadianColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasGood
              ? MoadianColors.primary.withValues(alpha: 0.3)
              : MoadianColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MoadianColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  Fa.digits(index + 1),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: MoadianColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: onPickGood,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasGood
                              ? (row.name ?? 'کالای انتخاب‌شده')
                              : 'انتخاب کالا / خدمت از فهرست مودیان *',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.6,
                            fontWeight: FontWeight.w800,
                            color: hasGood
                                ? MoadianColors.ink
                                : MoadianColors.primary,
                          ),
                        ),
                        if (hasGood)
                          Text(
                            'CPC: ${Fa.digits(row.uniqueIdentifier)} • واحد: ${row.unitOfMeasurement ?? '—'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.2,
                              color: MoadianColors.inkSoft,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'تغییر کالا',
                onPressed: onPickGood,
                icon: const Icon(
                  Icons.swap_horiz_rounded,
                  size: 19,
                  color: MoadianColors.primary,
                ),
              ),
              if (canRemove)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'حذف ردیف',
                  onPressed: onRemove,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 19,
                    color: MoadianColors.danger,
                  ),
                ),
            ],
          ),
          const Divider(height: 14),
          InkWell(
            onTap: onEditNumbers,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: MoadianColors.surfaceSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        Text(
                          'تعداد: ${Fa.number(row.count, decimals: row.count == row.count.roundToDouble() ? 0 : 2)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'فی: ${Fa.number(row.priceUnit.round())}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (row.discount > 0)
                          Text(
                            'تخفیف: ${Fa.number(row.discount.round())}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: MoadianColors.warn,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        Text(
                          'مالیات (${Fa.number(row.valueAddedPercentage)}٪): ${Fa.number(vat.round())}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: MoadianColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: MoadianColors.primary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'مبلغ پایه: ${Fa.number(gross.round())} ریال',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: MoadianColors.inkSoft,
                  ),
                ),
              ),
              Text(
                'جمع ردیف: ${Fa.number(total.round())} ریال',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: MoadianColors.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
