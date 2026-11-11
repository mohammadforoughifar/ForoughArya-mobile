// ============================================================
//  «ثبت دستی سیستم» — فاز ۹-ج
//  آینهٔ `Pages/ItAssets/SystemManualCreate.razor` (مسیر وب: /system-id/manual)
//
//  سه کارت بخش، عیناً مثل وب:
//    ۱) «محل استقرار و مسئول سیستم» → شرکت* / واحد / کاربر تحویل‌گیرنده
//    ۲) «شناسه و مشخصات اصلی» → نام یا کد سیستم* / مدل دستگاه / CPU /
//       حجم RAM / نوع RAM / مادربرد / سیستم‌عامل
//    ۳) «تجهیزات و شبکه» → هارد / کارت گرافیک / مانیتور / IP
//  + پیام‌های اعتبارسنجی و خطای سرور، عیناً همان متن‌های وب
//  + در پایان: هدایت به «شناسنامهٔ سیستم» تازه‌ساخته‌شده
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/system_repository.dart';
import '../models/system_models.dart';
import 'system_style.dart';

class SystemManualPage extends StatefulWidget {
  const SystemManualPage({super.key});

  @override
  State<SystemManualPage> createState() => _SystemManualPageState();
}

class _SystemManualPageState extends State<SystemManualPage> {
  late final SystemRepository _repo;

  bool _loading = true;
  bool _saving = false;
  String _error = '';

  List<SystemCompanyRow> _companies = const [];
  List<SystemDepartmentRow> _departments = const [];
  List<SystemUserRow> _users = const [];

  // فرم (همان `ManualSystemForm` وب)
  int _companyId = 0;
  int? _departmentId;
  int? _userId;
  final _agentId = TextEditingController();
  final _computerModel = TextEditingController();
  final _cpu = TextEditingController();
  final _totalRam = TextEditingController();
  final _ram = TextEditingController();
  final _motherboard = TextEditingController();
  final _osName = TextEditingController();
  final _hardDisk = TextEditingController();
  final _graphics = TextEditingController();
  final _monitor = TextEditingController();
  final _ip = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo = SystemRepository(context.read<ApiClient>());
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _agentId,
      _computerModel,
      _cpu,
      _totalRam,
      _ram,
      _motherboard,
      _osName,
      _hardDisk,
      _graphics,
      _monitor,
      _ip,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait<dynamic>([
        _repo.companies(),
        _repo.departments(),
        _repo.users(),
      ]);
      if (!mounted) return;
      setState(() {
        _companies = r[0] as List<SystemCompanyRow>;
        _departments = r[1] as List<SystemDepartmentRow>;
        _users = r[2] as List<SystemUserRow>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'دریافت شرکت‌ها، واحدها یا کاربران با خطا روبه‌رو شد. صفحه را دوباره بارگذاری کنید.';
      });
    }
  }

  List<SystemDepartmentRow> get _availableDepartments => _departments
      .where((d) => d.isActive && d.companyId == _companyId)
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  List<SystemUserRow> get _availableUsers => _users
      .where((u) => u.isActive && u.companyId == _companyId)
      .toList()
    ..sort((a, b) {
      final c = a.firstName.compareTo(b.firstName);
      return c != 0 ? c : a.lastName.compareTo(b.lastName);
    });

  Future<void> _save() async {
    setState(() => _error = '');
    if (_companyId <= 0) {
      setState(() => _error = 'شرکت را انتخاب کنید.');
      return;
    }
    if (_agentId.text.trim().isEmpty) {
      setState(() => _error = 'نام یا کد سیستم را وارد کنید.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _repo.createManual(
        ManualSystemRequest(
          agentId: _agentId.text.trim(),
          companyId: _companyId,
          departmentId: _departmentId,
          userId: _userId,
          computerModel: _trim(_computerModel.text),
          motherboard: _trim(_motherboard.text),
          cpu: _trim(_cpu.text),
          totalRamGb: int.tryParse(_totalRam.text.trim()) ?? 0,
          ram: _trim(_ram.text),
          hardDisk: _trim(_hardDisk.text),
          graphics: _trim(_graphics.text),
          monitor: _trim(_monitor.text),
          osName: _trim(_osName.text),
          ip: _trim(_ip.text),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'سیستم ثبت شد.',
            style: TextStyle(fontSize: 11.5),
          ),
          backgroundColor: ShopColors.ok,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e
            .toString()
            .replaceFirst('ApiException: ', '')
            .replaceFirst('Exception: ', '')
            .trim();
        if (_error.isEmpty) _error = 'ثبت سیستم ناموفق بود.';
      });
    }
  }

  static String? _trim(String s) {
    final v = s.trim();
    return v.isEmpty ? null : v;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: const Text(
          'ثبت دستی سیستم',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text(
                    'در حال دریافت اطلاعات پایه…',
                    style: TextStyle(fontSize: 11, color: ShopColors.inkFaint),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 30),
              children: [
                const ShopHeader(
                  title: 'ثبت دستی سیستم',
                  subtitle:
                      'ثبت شناسنامهٔ سیستم‌هایی که هنوز توسط ایجنت شناسایی نشده‌اند.',
                  icon: Icons.desktop_windows_rounded,
                  badge: 'IT',
                ),
                const SizedBox(height: 12),
                if (_companies.where((c) => c.isActive).isEmpty)
                  const SystemNote(
                    text:
                        'ابتدا باید حداقل یک شرکت فعال تعریف کنید؛ سپس ثبت دستی سیستم را انجام دهید.',
                    color: ShopColors.warn,
                    icon: Icons.domain_disabled_rounded,
                  )
                else ...[
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SystemNote(
                        text: _error,
                        color: ShopColors.danger,
                        icon: Icons.error_outline_rounded,
                      ),
                    ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: SystemNote(
                      text:
                          'این رکورد با وضعیت تأییدشده ثبت می‌شود. در صورت اجرای ایجنت روی همین دستگاه، کد سیستم واردشده در این فرم باید با شناسهٔ ایجنت یکسان باشد تا تغییرات در همان شناسنامه ثبت شوند.',
                      color: ShopColors.seed,
                      icon: Icons.info_outline_rounded,
                    ),
                  ),

                  // ---------- ۱) محل استقرار و مسئول سیستم ----------
                  SystemCard(
                    title: 'محل استقرار و مسئول سیستم',
                    icon: Icons.account_tree_rounded,
                    child: Column(
                      children: [
                        _dropdown<int>(
                          label: 'شرکت',
                          required: true,
                          value: _companyId > 0 ? _companyId : null,
                          hint: '— انتخاب شرکت —',
                          items: [
                            for (final c in _companies
                                .where((c) => c.isActive)
                                .toList()
                              ..sort((a, b) => a.name.compareTo(b.name)))
                              DropdownMenuItem(
                                value: c.id,
                                child: Text(
                                  '${c.name}'
                                  '${(c.code ?? '').isEmpty ? '' : ' (${c.code})'}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() {
                            _companyId = v ?? 0;
                            _departmentId = null;
                            _userId = null;
                          }),
                        ),
                        _dropdown<int>(
                          label: 'واحد / دپارتمان',
                          value: _departmentId,
                          hint: '— بدون واحد —',
                          enabled: _companyId > 0,
                          items: [
                            for (final d in _availableDepartments)
                              DropdownMenuItem(
                                value: d.id,
                                child: Text(
                                  d.name,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => _departmentId = v),
                        ),
                        _dropdown<int>(
                          label: 'کاربر تحویل‌گیرنده',
                          value: _userId,
                          hint: '— فعلاً تخصیص داده نشود —',
                          enabled: _companyId > 0,
                          items: [
                            for (final u in _availableUsers)
                              DropdownMenuItem(
                                value: u.id,
                                child: Text(
                                  u.lookupLabel,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() => _userId = v),
                        ),
                      ],
                    ),
                  ),

                  // ---------- ۲) شناسه و مشخصات اصلی ----------
                  SystemCard(
                    title: 'شناسه و مشخصات اصلی',
                    icon: Icons.qr_code_scanner_rounded,
                    child: Column(
                      children: [
                        _field(
                          label: 'نام یا کد سیستم',
                          required: true,
                          controller: _agentId,
                          hint: 'مثلاً PC-ACC-01 یا شماره اموال',
                          maxLength: 150,
                          note: 'شناسه باید یکتا باشد.',
                        ),
                        _field(
                          label: 'مدل دستگاه / کیس',
                          controller: _computerModel,
                          hint: 'مثلاً Dell OptiPlex 7090',
                          maxLength: 200,
                        ),
                        _field(
                          label: 'پردازنده (CPU)',
                          controller: _cpu,
                          hint: 'مثلاً Intel Core i5-10500',
                          maxLength: 300,
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _field(
                                label: 'حجم RAM (گیگابایت)',
                                controller: _totalRam,
                                hint: '16',
                                keyboardType: TextInputType.number,
                                ltr: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _field(
                                label: 'نوع / توضیح RAM',
                                controller: _ram,
                                hint: 'مثلاً DDR4',
                                maxLength: 200,
                              ),
                            ),
                          ],
                        ),
                        _field(
                          label: 'مادربرد',
                          controller: _motherboard,
                          hint: 'مدل مادربرد',
                          maxLength: 300,
                        ),
                        _field(
                          label: 'سیستم‌عامل',
                          controller: _osName,
                          hint: 'مثلاً Windows 11 Pro',
                          maxLength: 200,
                        ),
                      ],
                    ),
                  ),

                  // ---------- ۳) تجهیزات و شبکه ----------
                  SystemCard(
                    title: 'تجهیزات و شبکه',
                    icon: Icons.storage_rounded,
                    child: Column(
                      children: [
                        _field(
                          label: 'هارد / فضای ذخیره‌سازی',
                          controller: _hardDisk,
                          hint: 'مثلاً 512GB NVMe SSD',
                          maxLength: 300,
                        ),
                        _field(
                          label: 'کارت گرافیک',
                          controller: _graphics,
                          hint: 'در صورت وجود',
                          maxLength: 300,
                        ),
                        _field(
                          label: 'مانیتور',
                          controller: _monitor,
                          hint: 'مدل مانیتور',
                          maxLength: 300,
                        ),
                        _field(
                          label: 'IP',
                          controller: _ip,
                          hint: '192.168.1.10',
                          maxLength: 50,
                          ltr: true,
                          keyboardType: TextInputType.text,
                        ),
                      ],
                    ),
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 42),
                            foregroundColor: ShopColors.inkSoft,
                            side: const BorderSide(color: ShopColors.line),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(21),
                            ),
                          ),
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text(
                            'انصراف',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: ShopColors.seed,
                            minimumSize: const Size(0, 42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(21),
                            ),
                          ),
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                ),
                          label: Text(
                            _saving ? 'در حال ثبت…' : 'ثبت سیستم',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
                      foregroundColor: ShopColors.inkSoft,
                      side: const BorderSide(color: ShopColors.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                    label: const Text(
                      'بازگشت به لیست سیستم‌ها',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    int? maxLength,
    bool required = false,
    bool ltr = false,
    String? note,
    TextInputType? keyboardType,
  }) {
    return ShopField(
      label: label,
      required: required,
      hint: note,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
        textAlign: ltr ? TextAlign.right : TextAlign.right,
        style: const TextStyle(fontSize: 11.5, color: ShopColors.ink),
        decoration: InputDecoration(
          hintText: hint,
          counterText: '',
          hintStyle: const TextStyle(
            fontSize: 10.5,
            color: ShopColors.inkFaint,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 11,
          ),
          filled: true,
          fillColor: const Color(0xfff7f9fd),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ShopColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ShopColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ShopColors.accent),
          ),
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    bool required = false,
    bool enabled = true,
  }) {
    return ShopField(
      label: label,
      required: required,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isDense: true,
        isExpanded: true,
        style: const TextStyle(fontSize: 11, color: ShopColors.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 10.5,
            color: ShopColors.inkFaint,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 11,
          ),
          filled: true,
          fillColor: const Color(0xfff7f9fd),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ShopColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ShopColors.line),
          ),
        ),
        items: items,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}
