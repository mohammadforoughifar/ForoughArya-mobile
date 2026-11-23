import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../../shop/data/fa_num.dart';
import '../../shop/data/shop_identifier_rules.dart';
import '../data/moadian_perms.dart';
import '../data/moadian_repository.dart';
import '../models/moadian_models.dart';
import 'moadian_style.dart';

class MoadianBasicInfoTab extends StatefulWidget {
  const MoadianBasicInfoTab({
    super.key,
    required this.companies,
    required this.activeCpInfoId,
    required this.onSelectCompany,
    required this.onReloadShell,
    this.externalSectionIndex,
    this.externalSignal = 0,
  });

  final List<MoadianCpInfo> companies;
  final int activeCpInfoId;
  final ValueChanged<MoadianCpInfo> onSelectCompany;
  final Future<void> Function() onReloadShell;
  final int? externalSectionIndex;
  final int externalSignal;

  @override
  State<MoadianBasicInfoTab> createState() => _MoadianBasicInfoTabState();
}

class _MoadianBasicInfoTabState extends State<MoadianBasicInfoTab> {
  late final MoadianRepository _repo = MoadianRepository(
    context.read<ApiClient>(),
  );

  int _section = 0; // 0: شرکت و سال مالی، 1: اتصال، 2: کالا، 3: مشتری، 4: واحد

  // داده‌های بخش‌ها
  List<MoadianFiscalYear> _fiscalYears = const [];
  MoadianConnection? _conn;
  MoadianPagedList<MoadianGood> _goods = MoadianPagedList.empty();
  List<MoadianCustomer> _customers = const [];
  MoadianPagedList<MoadianUnit> _units = MoadianPagedList.empty();
  List<MoadianUnit> _unitsCombo = const [];

  bool _loading = false;
  String? _error;

  String _goodsSearch = '';
  int _goodsPage = 1;
  String _custSearch = '';
  final String _unitSearch = '';
  final int _unitPage = 1;

  // فرم اتصال
  final TextEditingController _wsUrlCtrl = TextEditingController(
    text: 'https://tp.tax.gov.ir/req/api',
  );
  final TextEditingController _taxMemoryCtrl = TextEditingController();
  MoadianKeyFile? _pickedKeyFile;
  bool _connBusy = false;
  String? _connResultMsg;
  bool? _connResultOk;

  static const List<({String name, String code})> _officialUnitPresets = [
    (name: 'عدد / فقره', code: '164'),
    (name: 'کیلوگرم', code: '161'),
    (name: 'بسته', code: '165'),
    (name: 'متر', code: '1627'),
    (name: 'متر مربع', code: '1646'),
    (name: 'لیتر', code: '1631'),
    (name: 'ساعت (خدمت)', code: '1628'),
    (name: 'کارواحد / سرویس', code: '1654'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.externalSectionIndex != null) {
      _section = widget.externalSectionIndex!.clamp(0, 4);
    }
    _loadCurrentSection();
  }

  @override
  void didUpdateWidget(covariant MoadianBasicInfoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.externalSignal != widget.externalSignal &&
        widget.externalSectionIndex != null) {
      _section = widget.externalSectionIndex!.clamp(0, 4);
      _loadCurrentSection();
    } else if (oldWidget.activeCpInfoId != widget.activeCpInfoId) {
      _pickedKeyFile = null;
      _connResultMsg = null;
      _loadCurrentSection();
    }
  }

  @override
  void dispose() {
    _wsUrlCtrl.dispose();
    _taxMemoryCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _loadCurrentSection() async {
    final cp = widget.activeCpInfoId;
    if (cp <= 0 && _section != 0) {
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      switch (_section) {
        case 0:
          if (cp > 0) {
            _fiscalYears = await _repo.getFiscalYears(cp);
          } else {
            _fiscalYears = const [];
          }
          break;
        case 1:
          final c = await _repo.getConnection(cp);
          _conn = c;
          if (c != null) {
            _wsUrlCtrl.text = c.webServiceAddress.trim().isEmpty
                ? 'https://tp.tax.gov.ir/req/api'
                : c.webServiceAddress.trim();
            _taxMemoryCtrl.text = c.taxMemoryId;
          } else {
            _wsUrlCtrl.text = 'https://tp.tax.gov.ir/req/api';
            _taxMemoryCtrl.clear();
          }
          break;
        case 2:
          final results = await Future.wait<dynamic>([
            _repo.getGoods(cpInfoId: cp, search: _goodsSearch, page: _goodsPage),
            _repo.getUnitsCombo(cp).catchError((_) => const <MoadianUnit>[]),
          ]);
          _goods = results[0] as MoadianPagedList<MoadianGood>;
          _unitsCombo = results[1] as List<MoadianUnit>;
          break;
        case 3:
          _customers = await _repo.getCustomers(cp);
          break;
        case 4:
          _units = await _repo.getUnits(
            cpInfoId: cp,
            search: _unitSearch,
            page: _unitPage,
          );
          break;
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  // ==================== ۰. فرم شرکت و سال مالی ====================

  Future<void> _openCpInfoEditor([MoadianCpInfo? existing]) async {
    String type = existing?.type ?? 'حقوقی';
    final faCtrl = TextEditingController(text: existing?.persianName ?? '');
    final enCtrl = TextEditingController(text: existing?.englishName ?? '');
    final natCtrl = TextEditingController(text: existing?.nationalId ?? '');
    final ecoCtrl = TextEditingController(text: existing?.economicNumber ?? '');
    final postCtrl = TextEditingController(text: existing?.postalCode ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
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
                        existing == null
                            ? 'ثبت پروندهٔ شرکت جدید در مودیان تیسا'
                            : 'ویرایش پروندهٔ شرکت مودیان',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'حقوقی', label: Text('حقوقی')),
                          ButtonSegment(value: 'حقیقی', label: Text('حقیقی')),
                        ],
                        selected: {type},
                        onSelectionChanged: (s) => setS(() => type = s.first),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: faCtrl,
                        decoration: const InputDecoration(
                          labelText: 'نام فارسی شرکت / مؤدی *',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: enCtrl,
                        decoration: const InputDecoration(
                          labelText: 'نام انگلیسی (اختیاری)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: natCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: type == 'حقوقی'
                              ? 'شناسه ملی ۱۱ رقمی *'
                              : 'کد ملی ۱۰ رقمی *',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: ecoCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'شماره اقتصادی (۱۱ تا ۱۴ رقم) *',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: postCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'کد پستی ۱۰ رقمی *',
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
                              style: FilledButton.styleFrom(
                                backgroundColor: MoadianColors.primary,
                              ),
                              onPressed: () async {
                                if (faCtrl.text.trim().isEmpty) {
                                  _toast('نام فارسی مؤدی الزامی است.');
                                  return;
                                }
                                final res = await _repo.saveCpInfo(
                                  MoadianCpInfo(
                                    cpInfoId: existing?.cpInfoId ?? 0,
                                    persianName: faCtrl.text.trim(),
                                    englishName: enCtrl.text.trim(),
                                    nationalId: toEnDigits(natCtrl.text.trim()),
                                    economicNumber: toEnDigits(
                                      ecoCtrl.text.trim(),
                                    ),
                                    postalCode: toEnDigits(
                                      postCtrl.text.trim(),
                                    ),
                                    type: type,
                                  ),
                                );
                                if (!ctx.mounted) return;
                                if (res.success) {
                                  Navigator.pop(ctx, true);
                                } else {
                                  _toast(res.message ?? 'ذخیره شرکت ناموفق بود.');
                                }
                              },
                              child: const Text('ذخیره پرونده'),
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
      ),
    );
    faCtrl.dispose();
    enCtrl.dispose();
    natCtrl.dispose();
    ecoCtrl.dispose();
    postCtrl.dispose();

    if (saved == true && mounted) {
      _toast('پرونده شرکت مودیان ذخیره شد.');
      await widget.onReloadShell();
      await _loadCurrentSection();
    }
  }

  Future<void> _openFiscalYearEditor([MoadianFiscalYear? existing]) async {
    if (widget.activeCpInfoId <= 0) return;
    final now = DateTime.now();
    DateTime start = existing?.startDate ?? DateTime(now.year, 3, 21);
    DateTime end = existing?.endDate ?? DateTime(now.year + 1, 3, 20);
    bool isActive = existing?.isActive ?? true;
    final titleCtrl = TextEditingController(
      text: existing?.title ?? 'سال مالی ${jalaliShort(start).split('/').first}',
    );

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MoadianColors.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      existing == null
                          ? 'تعریف سال مالی جدید'
                          : 'ویرایش سال مالی',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'عنوان سال مالی *',
                        hintText: 'مثلاً: سال مالی ۱۴۰۵',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final d = await showJalaliDatePicker(
                                ctx,
                                initial: start,
                                title: 'تاریخ شروع سال مالی',
                              );
                              if (d != null) setS(() => start = d);
                            },
                            icon: const Icon(Icons.event_rounded, size: 16),
                            label: Text('شروع: ${jalaliShort(start)}'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final d = await showJalaliDatePicker(
                                ctx,
                                initial: end,
                                title: 'تاریخ پایان سال مالی',
                              );
                              if (d != null) setS(() => end = d);
                            },
                            icon: const Icon(Icons.event_rounded, size: 16),
                            label: Text('پایان: ${jalaliShort(end)}'),
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: isActive,
                      onChanged: (v) => setS(() => isActive = v),
                      title: const Text(
                        'سال مالی فعال (پیش‌فرض در صدور صورتحساب)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                            style: FilledButton.styleFrom(
                              backgroundColor: MoadianColors.primary,
                            ),
                            onPressed: () async {
                              if (titleCtrl.text.trim().isEmpty) {
                                _toast('عنوان سال مالی را وارد کنید.');
                                return;
                              }
                              final res = await _repo.saveFiscalYear(
                                MoadianFiscalYear(
                                  id: existing?.id ?? 0,
                                  cpInfoId: widget.activeCpInfoId,
                                  title: titleCtrl.text.trim(),
                                  startDate: start,
                                  endDate: end,
                                  isActive: isActive,
                                ),
                              );
                              if (!ctx.mounted) return;
                              if (res.success) {
                                Navigator.pop(ctx, true);
                              } else {
                                _toast(res.message ?? 'ذخیره سال مالی ناموفق بود.');
                              }
                            },
                            child: const Text('ذخیره سال مالی'),
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
    titleCtrl.dispose();
    if (saved == true && mounted) {
      _toast('سال مالی ذخیره شد.');
      await widget.onReloadShell();
      await _loadCurrentSection();
    }
  }

  // ==================== ۱. اتصال و کلید خصوصی ====================

  Future<void> _pickPrivateKeyFromFile() async {
    try {
      final picked = await FilePicker.pickFiles();
      if (picked.isEmpty) return;
      final f = picked.first;
      final path = f.path;
      if (path == null) return;
      final bytes = await File(path).readAsBytes();
      setState(() {
        _pickedKeyFile = MoadianKeyFile(
          fileName: f.name,
          fileSize: bytes.length,
          fileType: 'application/x-pem-file',
          fileContentBase64: base64Encode(bytes),
        );
      });
      _toast('فایل کلید خصوصی «${f.name}» آمادهٔ ذخیره شد.');
    } catch (e) {
      _toast('خواندن فایل کلید انجام نشد: $e');
    }
  }

  Future<void> _pastePrivateKeyDialog() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'الصاق متنی کلید خصوصی (PEM)',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
          ),
          content: Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              controller: ctrl,
              maxLines: 7,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              decoration: const InputDecoration(
                hintText:
                    '-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBg...\n-----END PRIVATE KEY-----',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: MoadianColors.primary,
              ),
              child: const Text('ثبت متن کلید'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty && mounted) {
      final bytes = utf8.encode(ctrl.text.trim());
      setState(() {
        _pickedKeyFile = MoadianKeyFile(
          fileName: 'private_key.pem',
          fileSize: bytes.length,
          fileType: 'application/x-pem-file',
          fileContentBase64: base64Encode(bytes),
        );
      });
      _toast('متن کلید خصوصی آمادهٔ ذخیره شد.');
    }
    ctrl.dispose();
  }

  Future<void> _saveConn({required bool testOnly}) async {
    final mem = toEnDigits(_taxMemoryCtrl.text.trim()).toUpperCase();
    final ws = _wsUrlCtrl.text.trim();
    if (mem.length != 6) {
      _toast('شناسه یکتای حافظه مالیاتی دقیقاً ۶ کاراکتر است (مثلاً A12345).');
      return;
    }
    if (ws.isEmpty) {
      _toast('آدرس وب‌سرویس سامانه مودیان را وارد کنید.');
      return;
    }
    if (!testOnly &&
        _pickedKeyFile == null &&
        !(_conn?.hasStoredPrivateKey ?? false)) {
      _toast('فایل یا متن کلید خصوصی (PEM) را انتخاب کنید.');
      return;
    }

    setState(() {
      _connBusy = true;
      _connResultMsg = null;
    });
    try {
      final vm = MoadianConnection(
        id: _conn?.id ?? 0,
        cpInfoId: widget.activeCpInfoId,
        webServiceAddress: ws,
        taxMemoryId: mem,
        filePrivateKey: _pickedKeyFile,
      );
      final res = testOnly
          ? await _repo.testConnection(vm)
          : await _repo.saveConnection(vm);
      if (!mounted) return;
      setState(() {
        _connResultOk = res.success;
        _connResultMsg =
            res.message ??
            (res.success
                ? (testOnly
                      ? 'اتصال و امضای کلید خصوصی در سامانه مودیان تأیید شد.'
                      : 'تنظیمات اتصال ذخیره شد.')
                : 'عملیات ناموفق بود.');
      });
      if (!testOnly && res.success) {
        _pickedKeyFile = null;
        await widget.onReloadShell();
        await _loadCurrentSection();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connResultOk = false;
          _connResultMsg = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _connBusy = false);
    }
  }

  // ==================== ۲. فرم کالا و خدمات CPC ====================

  Future<void> _openGoodEditor([MoadianGood? existing]) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final cpcCtrl = TextEditingController(
      text: existing?.uniqueIdentifier ?? '',
    );
    final priceCtrl = TextEditingController(
      text: existing == null ? '' : existing.price.toInt().toString(),
    );
    final vatCtrl = TextEditingController(
      text: (existing?.valueAddedPercentage ?? 10).toString(),
    );
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    String unit =
        existing?.unitOfMeasurement ??
        (_unitsCombo.isNotEmpty ? _unitsCombo.first.name : 'عدد / فقره');

    final unitOptions = <String>{
      if (unit.isNotEmpty) unit,
      for (final u in _unitsCombo) u.name,
      for (final p in _officialUnitPresets) p.name,
    }.toList();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
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
                        existing == null
                            ? 'تعریف کالا یا خدمت جدید (CPC)'
                            : 'ویرایش کالا یا خدمت',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'عنوان کالا / خدمت *',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: cpcCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 13,
                        decoration: const InputDecoration(
                          labelText: 'شناسه ۱۳ رقمی کالا/خدمت (stuffid.tax.gov.ir) *',
                          counterText: '',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: priceCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'بهای واحد پیش‌فرض (ریال)',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: vatCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'نرخ ارزش افزوده (%)',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: unitOptions.contains(unit)
                            ? unit
                            : unitOptions.first,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'واحد اندازه‌گیری',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final u in unitOptions)
                            DropdownMenuItem(value: u, child: Text(u)),
                        ],
                        onChanged: (v) {
                          if (v != null) setS(() => unit = v);
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'توضیحات (اختیاری)',
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
                              style: FilledButton.styleFrom(
                                backgroundColor: MoadianColors.primary,
                              ),
                              onPressed: () async {
                                final cpc = toEnDigits(cpcCtrl.text.trim());
                                if (nameCtrl.text.trim().isEmpty ||
                                    cpc.length != 13) {
                                  _toast(
                                    'نام کالا و شناسهٔ دقیقاً ۱۳ رقمی CPC الزامی است.',
                                  );
                                  return;
                                }
                                final g = MoadianGood(
                                  goodsOrServicesId:
                                      existing?.goodsOrServicesId ?? 0,
                                  cpInfoId: widget.activeCpInfoId,
                                  name: nameCtrl.text.trim(),
                                  uniqueIdentifier: cpc,
                                  price:
                                      double.tryParse(
                                        toEnDigits(priceCtrl.text.trim()),
                                      ) ??
                                      0,
                                  valueAddedPercentage:
                                      double.tryParse(
                                        toEnDigits(vatCtrl.text.trim()),
                                      ) ??
                                      10,
                                  unitOfMeasurement: unit,
                                  description: descCtrl.text.trim(),
                                );
                                final res = existing == null
                                    ? await _repo.insertGood(g)
                                    : await _repo.updateGood(g);
                                if (!ctx.mounted) return;
                                if (res.success) {
                                  Navigator.pop(ctx, true);
                                } else {
                                  _toast(res.message ?? 'ذخیره کالا ناموفق بود.');
                                }
                              },
                              child: const Text('ذخیره کالا'),
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
      ),
    );
    nameCtrl.dispose();
    cpcCtrl.dispose();
    priceCtrl.dispose();
    vatCtrl.dispose();
    descCtrl.dispose();

    if (saved == true && mounted) {
      _toast('کالا/خدمت ذخیره شد.');
      await widget.onReloadShell();
      await _loadCurrentSection();
    }
  }

  // ==================== ۳. فرم مشتریان ====================

  Future<void> _openCustomerEditor([MoadianCustomer? existing]) async {
    String type = existing?.type ?? 'حقیقی';
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final natCtrl = TextEditingController(text: existing?.nationalId ?? '');
    final ecoCtrl = TextEditingController(text: existing?.economicNumber ?? '');
    final postCtrl = TextEditingController(text: existing?.postalCode ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final addrCtrl = TextEditingController(text: existing?.address ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) {
            final natHint = (type == 'حقوقی' || type == 'حقیقی')
                ? ShopIdentifierRules.validateTaxId(
                    natCtrl.text,
                    label: type == 'حقوقی' ? 'شناسه ملی' : 'کد ملی',
                  )
                : null;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(16),
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
                          existing == null
                              ? 'ثبت مشتری (خریدار) جدید'
                              : 'ویرایش اطلاعات مشتری',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: const [
                            'حقیقی',
                            'حقوقی',
                            'اتباع خارجی',
                            'مصرف‌کننده نهایی',
                          ].contains(type)
                              ? type
                              : 'حقیقی',
                          decoration: const InputDecoration(
                            labelText: 'نوع شخصیت خریدار',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'حقیقی',
                              child: Text('شخص حقیقی'),
                            ),
                            DropdownMenuItem(
                              value: 'حقوقی',
                              child: Text('شخص حقوقی (شرکت/سازمان)'),
                            ),
                            DropdownMenuItem(
                              value: 'اتباع خارجی',
                              child: Text('اتباع غیرایرانی'),
                            ),
                            DropdownMenuItem(
                              value: 'مصرف‌کننده نهایی',
                              child: Text('مصرف‌کننده نهایی'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setS(() => type = v);
                          },
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'نام و نام خانوادگی / نام شرکت *',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: natCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setS(() {}),
                          decoration: InputDecoration(
                            labelText: type == 'حقوقی'
                                ? 'شناسه ملی ۱۱ رقمی'
                                : 'کد ملی / کد فراگیر',
                            helperText: natHint,
                            helperStyle: const TextStyle(
                              fontSize: 10.2,
                              color: MoadianColors.warn,
                            ),
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: ecoCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'کد اقتصادی',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: postCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'کد پستی ۱۰ رقمی',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'شماره تماس',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: addrCtrl,
                          decoration: const InputDecoration(
                            labelText: 'نشانی',
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
                                style: FilledButton.styleFrom(
                                  backgroundColor: MoadianColors.primary,
                                ),
                                onPressed: () async {
                                  if (nameCtrl.text.trim().isEmpty) {
                                    _toast('نام مشتری الزامی است.');
                                    return;
                                  }
                                  final c = MoadianCustomer(
                                    customerId: existing?.customerId ?? 0,
                                    cpInfoId: widget.activeCpInfoId,
                                    type: type,
                                    name: nameCtrl.text.trim(),
                                    nationalId: toEnDigits(natCtrl.text.trim()),
                                    economicNumber: toEnDigits(
                                      ecoCtrl.text.trim(),
                                    ),
                                    postalCode: toEnDigits(
                                      postCtrl.text.trim(),
                                    ),
                                    phone: toEnDigits(phoneCtrl.text.trim()),
                                    address: addrCtrl.text.trim(),
                                  );
                                  final res = existing == null
                                      ? await _repo.insertCustomer(c)
                                      : await _repo.updateCustomer(c);
                                  if (!ctx.mounted) return;
                                  if (res.success) {
                                    Navigator.pop(ctx, true);
                                  } else {
                                    _toast(
                                      res.message ?? 'ثبت مشتری ناموفق بود.',
                                    );
                                  }
                                },
                                child: const Text('ذخیره مشتری'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    nameCtrl.dispose();
    natCtrl.dispose();
    ecoCtrl.dispose();
    postCtrl.dispose();
    phoneCtrl.dispose();
    addrCtrl.dispose();

    if (saved == true && mounted) {
      _toast('اطلاعات مشتری ذخیره شد.');
      await widget.onReloadShell();
      await _loadCurrentSection();
    }
  }

  // ==================== ۴. فرم واحدهای سنجش ====================

  Future<void> _openUnitEditor([MoadianUnit? existing]) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');

    final saved = await showModalBottomSheet<bool>(
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MoadianColors.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null
                        ? 'افزودن واحد سنجش رسمی'
                        : 'ویرایش واحد سنجش',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final p in _officialUnitPresets)
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            '${p.name} (${Fa.digits(p.code)})',
                            style: const TextStyle(fontSize: 10.5),
                          ),
                          onPressed: () {
                            nameCtrl.text = p.name;
                            codeCtrl.text = p.code;
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'نام واحد سنجش *',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: codeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'کد واحد در جدول سازمان امور مالیاتی *',
                      hintText: 'مثلاً 164 برای عدد، 161 برای کیلوگرم',
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
                          style: FilledButton.styleFrom(
                            backgroundColor: MoadianColors.primary,
                          ),
                          onPressed: () async {
                            if (nameCtrl.text.trim().isEmpty ||
                                codeCtrl.text.trim().isEmpty) {
                              _toast('نام و کد واحد سنجش الزامی است.');
                              return;
                            }
                            final u = MoadianUnit(
                              unitId: existing?.unitId ?? 0,
                              cpInfoId: widget.activeCpInfoId,
                              name: nameCtrl.text.trim(),
                              code: toEnDigits(codeCtrl.text.trim()),
                            );
                            final res = existing == null
                                ? await _repo.insertUnit(u)
                                : await _repo.updateUnit(u);
                            if (!ctx.mounted) return;
                            if (res.success) {
                              Navigator.pop(ctx, true);
                            } else {
                              _toast(res.message ?? 'ذخیره واحد ناموفق بود.');
                            }
                          },
                          child: const Text('ذخیره واحد'),
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
    );
    nameCtrl.dispose();
    codeCtrl.dispose();

    if (saved == true && mounted) {
      _toast('واحد سنجش ذخیره شد.');
      await _loadCurrentSection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthController>().session;
    final sections = <({int idx, String label, IconData icon})>[
      (idx: 0, label: 'شرکت و سال مالی', icon: Icons.domain_rounded),
      (idx: 1, label: 'اتصال و کلید', icon: Icons.vpn_key_rounded),
      (idx: 2, label: 'کالا و خدمات', icon: Icons.inventory_2_outlined),
      (idx: 3, label: 'مشتریان', icon: Icons.groups_2_outlined),
      (idx: 4, label: 'واحد سنجش', icon: Icons.straighten_rounded),
    ];

    return RefreshIndicator(
      color: MoadianColors.primary,
      onRefresh: _loadCurrentSection,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
        children: [
          MoadianCompanyBar(
            companies: widget.companies,
            activeCpInfoId: widget.activeCpInfoId,
            onSelect: widget.onSelectCompany,
            onManageCompanies: () {
              setState(() => _section = 0);
              _openCpInfoEditor();
            },
          ),
          const SizedBox(height: 10),

          // نوار بخش‌های ۵گانه اطلاعات پایه
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in sections)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      selected: _section == s.idx,
                      onSelected: (_) {
                        setState(() => _section = s.idx);
                        _loadCurrentSection();
                      },
                      selectedColor: MoadianColors.primary,
                      backgroundColor: MoadianColors.surface,
                      side: BorderSide(
                        color: _section == s.idx
                            ? MoadianColors.primary
                            : MoadianColors.line,
                      ),
                      avatar: Icon(
                        s.icon,
                        size: 15,
                        color: _section == s.idx
                            ? Colors.white
                            : MoadianColors.primary,
                      ),
                      label: Text(
                        s.label,
                        style: TextStyle(
                          fontSize: 11.2,
                          fontWeight: FontWeight.w800,
                          color: _section == s.idx
                              ? Colors.white
                              : MoadianColors.ink,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_error != null) ...[
            MoadianErrorBanner(
              message: _error!,
              onRetry: _loadCurrentSection,
            ),
            const SizedBox(height: 10),
          ],

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 42),
              child: Center(
                child: CircularProgressIndicator(color: MoadianColors.primary),
              ),
            )
          else if (widget.activeCpInfoId <= 0 && _section != 0)
            MoadianEmptyCard(
              icon: Icons.domain_add_rounded,
              title: 'ابتدا یک شرکت مودیان ثبت یا انتخاب کنید',
              subtitle:
                  'تنظیمات اتصال، کالاها و مشتریان به ازای هر پروندهٔ مودیان نگهداری می‌شوند.',
              actionLabel: 'ثبت شرکت مودیان',
              onAction: () {
                setState(() => _section = 0);
                _openCpInfoEditor();
              },
            )
          else
            switch (_section) {
              0 => _buildCompaniesAndFiscalSection(session),
              1 => _buildConnectionSection(session),
              2 => _buildGoodsSection(session),
              3 => _buildCustomersSection(session),
              _ => _buildUnitsSection(session),
            },
        ],
      ),
    );
  }

  Widget _buildCompaniesAndFiscalSection(dynamic session) {
    final canComp =
        session == null || MoadianPerms.can(session, MoadianPerms.company);
    final canFy =
        session == null || MoadianPerms.can(session, MoadianPerms.fiscalYear);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MoadianSectionTitle(
          title: 'پرونده‌های شرکت مودیان (${Fa.digits(widget.companies.length)})',
          trailing: canComp
              ? FilledButton.tonalIcon(
                  onPressed: () => _openCpInfoEditor(),
                  icon: const Icon(Icons.add_business_rounded, size: 16),
                  label: const Text('شرکت جدید'),
                )
              : null,
        ),
        if (widget.companies.isEmpty)
          MoadianEmptyCard(
            icon: Icons.account_balance_outlined,
            title: 'پرونده‌ای ثبت نشده است',
            subtitle:
                'مشخصات ثبتی، شناسه ملی و شماره اقتصادی شرکت خود را ثبت کنید.',
            actionLabel: canComp ? 'ثبت اولین شرکت' : null,
            onAction: canComp ? () => _openCpInfoEditor() : null,
          )
        else
          for (final c in widget.companies) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: MoadianColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: c.cpInfoId == widget.activeCpInfoId
                      ? MoadianColors.primary
                      : MoadianColors.line,
                  width: c.cpInfoId == widget.activeCpInfoId ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                c.persianName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (c.cpInfoId == widget.activeCpInfoId) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: MoadianColors.ok.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'فعال',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: MoadianColors.ok,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${c.type} • شناسه: ${Fa.digits(c.nationalId ?? '—')} • اقتصادی: ${Fa.digits(c.economicNumber ?? '—')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.6,
                            color: MoadianColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (c.cpInfoId != widget.activeCpInfoId)
                    TextButton(
                      onPressed: () => widget.onSelectCompany(c),
                      child: const Text('انتخاب'),
                    ),
                  if (canComp) ...[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _openCpInfoEditor(c),
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: MoadianColors.primary,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        final res = await _repo.deleteCpInfo(c.cpInfoId);
                        if (!mounted) return;
                        _toast(
                          res.message ??
                              (res.success
                                  ? 'شرکت حذف شد.'
                                  : 'امکان حذف این شرکت وجود ندارد.'),
                        );
                        if (res.success) {
                          await widget.onReloadShell();
                          await _loadCurrentSection();
                        }
                      },
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: MoadianColors.danger,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

        if (widget.activeCpInfoId > 0) ...[
          const SizedBox(height: 12),
          MoadianSectionTitle(
            title: 'سال‌های مالی پروندهٔ فعال (${Fa.digits(_fiscalYears.length)})',
            trailing: canFy
                ? FilledButton.tonalIcon(
                    onPressed: () => _openFiscalYearEditor(),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('سال مالی جدید'),
                  )
                : null,
          ),
          if (_fiscalYears.isEmpty)
            MoadianEmptyCard(
              icon: Icons.calendar_month_outlined,
              title: 'سال مالی برای این شرکت ثبت نشده است',
              subtitle:
                  'برای صدور صورتحساب، حداقل یک سال مالی منطبق بر تاریخ جاری تعریف کنید.',
              actionLabel: canFy ? 'تعریف سال مالی' : null,
              onAction: canFy ? () => _openFiscalYearEditor() : null,
            )
          else
            for (final fy in _fiscalYears)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: MoadianColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MoadianColors.line),
                ),
                child: Row(
                  children: [
                    Icon(
                      fy.isActive
                          ? Icons.check_circle_rounded
                          : Icons.calendar_today_outlined,
                      size: 19,
                      color: fy.isActive
                          ? MoadianColors.ok
                          : MoadianColors.inkFaint,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fy.title,
                            style: const TextStyle(
                              fontSize: 12.6,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${jalaliShort(fy.startDate)} تا ${jalaliShort(fy.endDate)}',
                            style: const TextStyle(
                              fontSize: 10.8,
                              color: MoadianColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canFy)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _openFiscalYearEditor(fy),
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: MoadianColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
        ],
      ],
    );
  }

  Widget _buildConnectionSection(dynamic session) {
    final storedKey = _conn?.hasStoredPrivateKey ?? false;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MoadianColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MoadianColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MoadianSectionTitle(
            title: 'حافظه مالیاتی و کلید خصوصی RSA',
            subtitle: 'امضای دیجیتال بسته‌های ارسالی به درگاه tp.tax.gov.ir',
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ActionChip(
                label: const Text(
                  'محیط عملیاتی (tp.tax.gov.ir)',
                  style: TextStyle(fontSize: 10.8),
                ),
                onPressed: () => setState(
                  () => _wsUrlCtrl.text = 'https://tp.tax.gov.ir/req/api',
                ),
              ),
              ActionChip(
                label: const Text(
                  'سندباکس آزمایشی',
                  style: TextStyle(fontSize: 10.8),
                ),
                onPressed: () => setState(
                  () =>
                      _wsUrlCtrl.text = 'https://sandboxrc.tax.gov.ir/req/api',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              controller: _wsUrlCtrl,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(
                labelText: 'WebService URL',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              controller: _taxMemoryCtrl,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              ],
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
              decoration: const InputDecoration(
                labelText: 'Tax Memory ID (6 chars, e.g. A12345)',
                counterText: '',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // وضعیت کلید خصوصی
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (_pickedKeyFile != null || storedKey)
                  ? MoadianColors.ok.withValues(alpha: 0.08)
                  : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (_pickedKeyFile != null || storedKey)
                    ? MoadianColors.ok.withValues(alpha: 0.3)
                    : const Color(0xFFFCD34D),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  (_pickedKeyFile != null || storedKey)
                      ? Icons.key_rounded
                      : Icons.key_off_rounded,
                  color: (_pickedKeyFile != null || storedKey)
                      ? MoadianColors.ok
                      : MoadianColors.warn,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _pickedKeyFile != null
                        ? 'کلید جدید آماده ذخیره: ${_pickedKeyFile!.fileName} (${Fa.number(_pickedKeyFile!.fileSize)} بایت)'
                        : (storedKey
                              ? 'کلید خصوصی در سرور ثبت شده است (${_conn!.filePrivateKey?.fileName ?? 'private.pem'}).'
                              : 'هنوز کلید خصوصی برای این پرونده بارگذاری نشده است.'),
                    style: const TextStyle(
                      fontSize: 11.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickPrivateKeyFromFile,
                  icon: const Icon(Icons.upload_file_rounded, size: 17),
                  label: const Text(
                    'انتخاب فایل کلید',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pastePrivateKeyDialog,
                  icon: const Icon(Icons.content_paste_rounded, size: 17),
                  label: const Text(
                    'الصاق متن PEM',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_connResultMsg != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: (_connResultOk == true
                        ? MoadianColors.ok
                        : MoadianColors.danger)
                    .withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: (_connResultOk == true
                          ? MoadianColors.ok
                          : MoadianColors.danger)
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _connResultMsg!,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.6,
                  fontWeight: FontWeight.w700,
                  color: _connResultOk == true
                      ? MoadianColors.ok
                      : MoadianColors.danger,
                ),
              ),
            ),
          ],

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _connBusy
                      ? null
                      : () => _saveConn(testOnly: true),
                  icon: const Icon(Icons.network_check_rounded, size: 18),
                  label: const Text('تست زنده اتصال'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _connBusy
                      ? null
                      : () => _saveConn(testOnly: false),
                  style: FilledButton.styleFrom(
                    backgroundColor: MoadianColors.primary,
                  ),
                  icon: _connBusy
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('ذخیره اتصال'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoodsSection(dynamic session) {
    final canManage =
        session == null || MoadianPerms.can(session, MoadianPerms.goods);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MoadianSectionTitle(
          title: 'کالا و خدمات دارای شناسه CPC (${Fa.number(_goods.totalCount)})',
          trailing: canManage
              ? FilledButton.tonalIcon(
                  onPressed: () => _openGoodEditor(),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('کالای جدید'),
                )
              : null,
        ),
        TextField(
          onSubmitted: (v) {
            _goodsSearch = toEnDigits(v.trim());
            _goodsPage = 1;
            _loadCurrentSection();
          },
          decoration: InputDecoration(
            hintText: 'جستجو با نام کالا یا کد ۱۳ رقمی CPC (Enter)…',
            prefixIcon: const Icon(Icons.search_rounded, size: 19),
            isDense: true,
            filled: true,
            fillColor: MoadianColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: MoadianColors.line),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_goods.items.isEmpty)
          MoadianEmptyCard(
            icon: Icons.inventory_2_outlined,
            title: 'کالا یا خدمتی ثبت نشده است',
            subtitle:
                'شناسهٔ ۱۳ رقمی کالا/خدمت را از سامانه stuffid.tax.gov.ir استخراج و ثبت کنید.',
            actionLabel: canManage ? 'ثبت اولین کالا' : null,
            onAction: canManage ? () => _openGoodEditor() : null,
          )
        else
          for (final g in _goods.items)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: MoadianColors.surface,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: MoadianColors.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.name,
                          style: const TextStyle(
                            fontSize: 12.8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'CPC: ${Fa.digits(g.uniqueIdentifier)} • واحد: ${g.unitOfMeasurement ?? '—'} • مالیات: ${Fa.number(g.valueAddedPercentage)}٪',
                          style: const TextStyle(
                            fontSize: 10.6,
                            color: MoadianColors.inkSoft,
                          ),
                        ),
                        Text(
                          'بهای پیش‌فرض: ${Fa.number(g.price.round())} ریال',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: MoadianColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canManage)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _openGoodEditor(g),
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: MoadianColors.primary,
                      ),
                    ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _buildCustomersSection(dynamic session) {
    final canManage =
        session == null || MoadianPerms.can(session, MoadianPerms.customers);

    final filtered = _customers.where((c) {
      if (_custSearch.trim().isEmpty) return true;
      final q = _custSearch.trim().toLowerCase();
      return c.name.toLowerCase().contains(q) ||
          (c.nationalId ?? '').contains(q) ||
          (c.economicNumber ?? '').contains(q) ||
          (c.phone ?? '').contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MoadianSectionTitle(
          title: 'مشتریان و خریداران (${Fa.number(filtered.length)})',
          trailing: canManage
              ? FilledButton.tonalIcon(
                  onPressed: () => _openCustomerEditor(),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  label: const Text('مشتری جدید'),
                )
              : null,
        ),
        TextField(
          onChanged: (v) => setState(() => _custSearch = toEnDigits(v)),
          decoration: InputDecoration(
            hintText: 'جستجو در نام، کد ملی/شناسه، کد اقتصادی یا تلفن…',
            prefixIcon: const Icon(Icons.search_rounded, size: 19),
            isDense: true,
            filled: true,
            fillColor: MoadianColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: MoadianColors.line),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (filtered.isEmpty)
          MoadianEmptyCard(
            icon: Icons.groups_2_outlined,
            title: 'مشتری ثبت نشده است',
            subtitle:
                'برای صدور صورتحساب نوع اول، خریداران حقیقی یا حقوقی خود را ثبت کنید.',
            actionLabel: canManage ? 'ثبت اولین مشتری' : null,
            onAction: canManage ? () => _openCustomerEditor() : null,
          )
        else
          for (final c in filtered)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: MoadianColors.surface,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: MoadianColors.line),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: MoadianColors.primary.withValues(
                      alpha: 0.1,
                    ),
                    child: Icon(
                      c.type == 'حقوقی'
                          ? Icons.domain_rounded
                          : Icons.person_outline_rounded,
                      size: 18,
                      color: MoadianColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.displayLabel,
                          style: const TextStyle(
                            fontSize: 12.8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if ((c.nationalId ?? '').isNotEmpty)
                              'شناسه: ${Fa.digits(c.nationalId)}',
                            if ((c.economicNumber ?? '').isNotEmpty)
                              'اقتصادی: ${Fa.digits(c.economicNumber)}',
                            if ((c.phone ?? '').isNotEmpty)
                              'تلفن: ${Fa.digits(c.phone)}',
                          ].join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.6,
                            color: MoadianColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canManage)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _openCustomerEditor(c),
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: MoadianColors.primary,
                      ),
                    ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _buildUnitsSection(dynamic session) {
    final canManage =
        session == null || MoadianPerms.can(session, MoadianPerms.units);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MoadianSectionTitle(
          title: 'واحدهای اندازه‌گیری رسمی (${Fa.number(_units.totalCount)})',
          trailing: canManage
              ? FilledButton.tonalIcon(
                  onPressed: () => _openUnitEditor(),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('واحد جدید'),
                )
              : null,
        ),
        if (_units.items.isEmpty)
          MoadianEmptyCard(
            icon: Icons.straighten_rounded,
            title: 'واحد سنجشی ثبت نشده است',
            subtitle:
                'کدهای استاندارد جدول واحدهای سازمان امور مالیاتی (مثل 164 عدد، 161 کیلوگرم) را ثبت کنید.',
            actionLabel: canManage ? 'افزودن واحد رسمی' : null,
            onAction: canManage ? () => _openUnitEditor() : null,
          )
        else
          for (final u in _units.items)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: MoadianColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MoadianColors.line),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: MoadianColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      Fa.digits(u.code),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: MoadianColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      u.name,
                      style: const TextStyle(
                        fontSize: 12.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (canManage) ...[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _openUnitEditor(u),
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: MoadianColors.primary,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        final res = await _repo.deleteUnit(
                          u.unitId,
                          cpInfoId: widget.activeCpInfoId,
                        );
                        if (!mounted) return;
                        _toast(
                          res.message ??
                              (res.success ? 'واحد حذف شد.' : 'حذف ناموفق بود.'),
                        );
                        if (res.success) await _loadCurrentSection();
                      },
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: MoadianColors.danger,
                      ),
                    ),
                  ],
                ],
              ),
            ),
      ],
    );
  }
}
