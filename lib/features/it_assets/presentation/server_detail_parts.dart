// ============================================================
//  شیت‌های کمکی «مدیریت سرورها» — فاز ۹-د
//  • ServerFormSheet      → مودال XL ثبت/ویرایش سرور (همان ۲۰ فیلد وب)
//  • ServerHardwareSheet  → مودال «سخت‌افزار و سلامت» (قطعات + رخدادها)
//  • IloCertificateSheet  → شیت «گواهی iLO» با تأیید/حذف تأیید اثر انگشت
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/server_repository.dart';
import '../models/server_models.dart';
import 'system_style.dart';

String _clean(Object e) => e
    .toString()
    .replaceFirst('ApiException: ', '')
    .replaceFirst('Exception: ', '')
    .trim();

InputDecoration _dec([String? hint]) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
  isDense: true,
  filled: true,
  fillColor: const Color(0xfff9fbfe),
  contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
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
    borderSide: const BorderSide(color: ShopColors.seed, width: 1.2),
  ),
);

// ============================================================
//  فرم سرور
// ============================================================

class ServerFormSheet extends StatefulWidget {
  const ServerFormSheet({
    super.key,
    required this.repo,
    required this.companyId,
    required this.credentials,
    required this.responsibles,
    this.server,
    this.canUseCredentials = false,
  });

  final ServerRepository repo;
  final int companyId;
  final List<ServerCredentialRow> credentials;
  final List<ServerResponsibleRow> responsibles;
  final ServerRow? server;
  final bool canUseCredentials;

  @override
  State<ServerFormSheet> createState() => _ServerFormSheetState();
}

class _ServerFormSheetState extends State<ServerFormSheet> {
  final _name = TextEditingController();
  final _manufacturer = TextEditingController(text: 'HPE');
  final _model = TextEditingController();
  final _serial = TextEditingController();
  final _assetTag = TextEditingController();
  final _ilo = TextEditingController();
  final _port = TextEditingController(text: '443');
  final _role = TextEditingController();
  final _environment = TextEditingController();
  final _rack = TextEditingController();
  final _rackUnit = TextEditingController();
  final _os = TextEditingController();
  final _notes = TextEditingController();
  final _interval = TextEditingController(text: '15');
  final _maintenanceNote = TextEditingController();

  String _criticality = 'Normal';
  String _status = 'Active';
  int? _credentialId;
  int? _responsibleId;
  bool _monitoring = false;
  bool _notify = false;
  DateTime? _warranty;
  DateTime? _maintenanceUntil;
  bool _saving = false;
  String? _error;

  bool get _isEdit => (widget.server?.id ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    final s = widget.server;
    if (s != null) {
      _name.text = s.name;
      _manufacturer.text = s.manufacturer ?? 'HPE';
      _model.text = s.model ?? '';
      _serial.text = s.serialNumber ?? '';
      _assetTag.text = s.assetTag ?? '';
      _ilo.text = s.iloAddress;
      _port.text = '${s.iloPort}';
      _role.text = s.role ?? '';
      _environment.text = s.environment ?? '';
      _rack.text = s.rack ?? '';
      _rackUnit.text = (s.rackUnit ?? 0) > 0 ? '${s.rackUnit}' : '';
      _os.text = s.operatingSystem ?? '';
      _notes.text = s.notes ?? '';
      _interval.text = '${s.monitoringIntervalMinutes}';
      _maintenanceNote.text = s.maintenanceNote ?? '';
      _criticality = s.criticality;
      _status = s.status;
      _credentialId = s.credentialId;
      _responsibleId = s.responsibleUserId;
      _monitoring = s.monitoringEnabled;
      _notify = s.alertNotificationsEnabled;
      _warranty = s.warrantyEndDate;
      _maintenanceUntil = s.maintenanceUntil;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _manufacturer,
      _model,
      _serial,
      _assetTag,
      _ilo,
      _port,
      _role,
      _environment,
      _rack,
      _rackUnit,
      _os,
      _notes,
      _interval,
      _maintenanceNote,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  ServerSaveRequest _build() => ServerSaveRequest(
    companyId: widget.companyId,
    name: _name.text.trim(),
    manufacturer: _manufacturer.text.trim().isEmpty
        ? 'HPE'
        : _manufacturer.text.trim(),
    model: _model.text.trim().isEmpty ? null : _model.text.trim(),
    serialNumber: _serial.text.trim().isEmpty ? null : _serial.text.trim(),
    assetTag: _assetTag.text.trim().isEmpty ? null : _assetTag.text.trim(),
    iloAddress: _ilo.text.trim(),
    iloPort: int.tryParse(_port.text.trim()) ?? 0,
    credentialId: _credentialId,
    role: _role.text.trim().isEmpty ? null : _role.text.trim(),
    environment: _environment.text.trim().isEmpty
        ? null
        : _environment.text.trim(),
    criticality: _criticality,
    status: _status,
    rack: _rack.text.trim().isEmpty ? null : _rack.text.trim(),
    rackUnit: int.tryParse(_rackUnit.text.trim()),
    operatingSystem: _os.text.trim().isEmpty ? null : _os.text.trim(),
    warrantyEndDate: _warranty,
    notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    monitoringEnabled: _monitoring,
    monitoringIntervalMinutes: int.tryParse(_interval.text.trim()) ?? 0,
    responsibleUserId: _responsibleId,
    alertNotificationsEnabled: _notify,
    maintenanceUntil: _maintenanceUntil,
    maintenanceNote: _maintenanceNote.text.trim().isEmpty
        ? null
        : _maintenanceNote.text.trim(),
  );

  Future<void> _save() async {
    final d = _build();
    final err = validateServerForm(d);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repo.save(req: d, id: widget.server?.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _clean(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: ShopColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: const BoxDecoration(
              color: ShopColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: ShopColors.line)),
            ),
            child: Row(
              children: [
                Icon(
                  _isEdit ? Icons.edit_note_rounded : Icons.add_rounded,
                  size: 17,
                  color: ShopColors.seed,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _isEdit ? 'ویرایش سرور' : 'ثبت سرور جدید',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close_rounded, size: 19),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(14, 12, 14, 20 + insets),
              children: [
                if (_error != null) ...[
                  SystemNote(
                    text: _error!,
                    color: ShopColors.danger,
                    icon: Icons.error_outline_rounded,
                  ),
                  const SizedBox(height: 10),
                ],
                _section('شناسنامه'),
                ShopField(
                  label: 'نام سرور',
                  required: true,
                  child: TextField(
                    controller: _name,
                    style: const TextStyle(fontSize: 11.5),
                    decoration: _dec('مثال: SRV-DB-01'),
                  ),
                ),
                _row2(
                  ShopField(
                    label: 'سازنده',
                    hint: 'پیش‌فرض HPE',
                    child: TextField(
                      controller: _manufacturer,
                      style: const TextStyle(fontSize: 11.5),
                      decoration: _dec('HPE'),
                    ),
                  ),
                  ShopField(
                    label: 'مدل',
                    child: TextField(
                      controller: _model,
                      style: const TextStyle(fontSize: 11.5),
                      decoration: _dec('ProLiant DL380 Gen11'),
                    ),
                  ),
                ),
                _row2(
                  ShopField(
                    label: 'شمارهٔ سریال',
                    child: TextField(
                      controller: _serial,
                      style: const TextStyle(fontSize: 11.5),
                      textDirection: TextDirection.ltr,
                      decoration: _dec('CZ12345678'),
                    ),
                  ),
                  ShopField(
                    label: 'Asset Tag',
                    child: TextField(
                      controller: _assetTag,
                      style: const TextStyle(fontSize: 11.5),
                      textDirection: TextDirection.ltr,
                      decoration: _dec('AST-0001'),
                    ),
                  ),
                ),
                _section('اتصال iLO'),
                ShopField(
                  label: 'آدرس iLO',
                  required: true,
                  hint: 'فقط HTTPS — مثال: ilo-srv01.aryanet.local',
                  child: TextField(
                    controller: _ilo,
                    style: const TextStyle(fontSize: 11.5),
                    textDirection: TextDirection.ltr,
                    decoration: _dec('ilo-srv01.example.local'),
                  ),
                ),
                _row2(
                  ShopField(
                    label: 'پورت iLO',
                    child: TextField(
                      controller: _port,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontSize: 11.5),
                      decoration: _dec('443'),
                    ),
                  ),
                  ShopField(
                    label: 'Credential (گاوصندوق)',
                    hint: widget.canUseCredentials
                        ? 'رمز فقط در سرور خوانده می‌شود'
                        : 'نیازمند مجوز مشاهدهٔ گاوصندوق',
                    child: DropdownButtonFormField<int>(
                      initialValue: _credentialId,
                      isDense: true,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: ShopColors.ink,
                      ),
                      decoration: _dec('انتخاب Credential'),
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text(
                            '— بدون رمز —',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                        for (final c in widget.credentials)
                          DropdownMenuItem<int>(
                            value: c.id,
                            child: Text(
                              c.optionLabel,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                      onChanged: widget.canUseCredentials
                          ? (v) => setState(() => _credentialId = v)
                          : null,
                    ),
                  ),
                ),
                _row2(
                  ShopField(
                    label: 'نقش سرور',
                    child: TextField(
                      controller: _role,
                      style: const TextStyle(fontSize: 11.5),
                      decoration: _dec('Database / Web / Backup'),
                    ),
                  ),
                  ShopField(
                    label: 'محیط',
                    child: TextField(
                      controller: _environment,
                      style: const TextStyle(fontSize: 11.5),
                      decoration: _dec('Production'),
                    ),
                  ),
                ),
                _row2(
                  ShopField(
                    label: 'درجهٔ اهمیت',
                    child: DropdownButtonFormField<String>(
                      initialValue: _criticality,
                      isDense: true,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: ShopColors.ink,
                      ),
                      decoration: _dec(),
                      items: [
                        for (final c in kCriticalities)
                          DropdownMenuItem(
                            value: c.key,
                            child: Text(
                              c.value,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                      onChanged: (v) =>
                          setState(() => _criticality = v ?? 'Normal'),
                    ),
                  ),
                  ShopField(
                    label: 'چرخهٔ عمر',
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      isDense: true,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: ShopColors.ink,
                      ),
                      decoration: _dec(),
                      items: [
                        for (final s in kServerStatuses)
                          DropdownMenuItem(
                            value: s.key,
                            child: Text(
                              s.value,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? 'Active'),
                    ),
                  ),
                ),
                _row2(
                  ShopField(
                    label: 'رک',
                    child: TextField(
                      controller: _rack,
                      style: const TextStyle(fontSize: 11.5),
                      decoration: _dec('RACK-A'),
                    ),
                  ),
                  ShopField(
                    label: 'شمارهٔ U',
                    hint: '۱ تا ۱۰۰',
                    child: TextField(
                      controller: _rackUnit,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontSize: 11.5),
                      decoration: _dec('12'),
                    ),
                  ),
                ),
                _row2(
                  ShopField(
                    label: 'سیستم‌عامل',
                    child: TextField(
                      controller: _os,
                      style: const TextStyle(fontSize: 11.5),
                      decoration: _dec('Windows Server 2022'),
                    ),
                  ),
                  ShopField(
                    label: 'پایان گارانتی',
                    child: _dateBox(
                      _warranty,
                      () async {
                        final d = await showJalaliDatePicker(
                          context,
                          initial: _warranty,
                          title: 'پایان گارانتی',
                        );
                        if (d != null) setState(() => _warranty = d);
                      },
                      () => setState(() => _warranty = null),
                    ),
                  ),
                ),
                _section('پایش خودکار'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeThumbColor: ShopColors.seed,
                  value: _monitoring,
                  onChanged: (v) => setState(() => _monitoring = v),
                  title: const Text(
                    'پایش خودکار iLO',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: const Text(
                    'دریافت دوره‌ای سلامت و Inventory از Redfish',
                    style: TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
                  ),
                ),
                const SizedBox(height: 6),
                ShopField(
                  label: 'فاصلهٔ پایش (دقیقه)',
                  hint: '۵ تا ۱۴۴۰',
                  child: DropdownButtonFormField<int>(
                    initialValue: kMonitoringIntervals.contains(
                      int.tryParse(_interval.text.trim()),
                    )
                        ? int.tryParse(_interval.text.trim())
                        : 15,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: ShopColors.ink,
                    ),
                    decoration: _dec(),
                    items: [
                      for (final m in kMonitoringIntervals)
                        DropdownMenuItem(
                          value: m,
                          child: Text(
                            '${Fa.digits(m)} دقیقه',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(
                      () => _interval.text = '${v ?? 15}',
                    ),
                  ),
                ),
                _section('مسئولیت و گردش‌کار هشدار'),
                ShopField(
                  label: 'مسئول سرور',
                  child: DropdownButtonFormField<int>(
                    initialValue: _responsibleId,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: ShopColors.ink,
                    ),
                    decoration: _dec('انتخاب مسئول'),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text(
                          '— بدون مسئول —',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                      for (final r in widget.responsibles)
                        DropdownMenuItem<int>(
                          value: r.id,
                          child: Text(
                            r.optionLabel,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _responsibleId = v),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeThumbColor: ShopColors.seed,
                  value: _notify,
                  onChanged: (v) => setState(() => _notify = v),
                  title: const Text(
                    'اعلان هشدار به مسئول',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: const Text(
                    'ارسال اطلاع به مسئول هنگام باز شدن هشدار جدید',
                    style: TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
                  ),
                ),
                const SizedBox(height: 6),
                _row2(
                  ShopField(
                    label: 'در تعمیرات تا',
                    child: _dateBox(
                      _maintenanceUntil,
                      () async {
                        final d = await showJalaliDatePicker(
                          context,
                          initial: _maintenanceUntil,
                          title: 'پایان تعمیرات',
                        );
                        if (d != null) setState(() => _maintenanceUntil = d);
                      },
                      () => setState(() => _maintenanceUntil = null),
                    ),
                  ),
                  const SizedBox.shrink(),
                ),
                ShopField(
                  label: 'توضیح تعمیرات',
                  hint: 'حداکثر ۵۰۰ کاراکتر',
                  child: TextField(
                    controller: _maintenanceNote,
                    maxLines: 2,
                    maxLength: 500,
                    style: const TextStyle(fontSize: 11.5),
                    decoration: _dec('علت توقف یا تعویض قطعه…'),
                  ),
                ),
                _section('یادداشت'),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 11.5),
                  decoration: _dec('توضیحات داخلی این سرور…'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: ShopColors.seed,
                          minimumSize: const Size(0, 42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(21),
                          ),
                        ),
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isEdit ? 'ذخیره تغییرات' : 'ثبت سرور',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(21),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        'انصراف',
                        style: TextStyle(fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const SystemNote(
                  text:
                      'آدرس و پورت iLO باید به سرور برنامه دسترسی داشته باشد. تغییر آدرس یا پورت، گواهی تأییدشدهٔ قبلی را پاک می‌کند و باید دوباره تأیید شود.',
                  color: ShopColors.warn,
                  icon: Icons.info_outline_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Row(
      children: [
        Container(
          width: 3,
          height: 13,
          decoration: BoxDecoration(
            color: ShopColors.seed,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            color: ShopColors.ink,
          ),
        ),
      ],
    ),
  );

  Widget _row2(Widget a, Widget b) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: a),
      const SizedBox(width: 8),
      Expanded(child: b),
    ],
  );

  Widget _dateBox(DateTime? value, VoidCallback pick, VoidCallback clear) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              side: const BorderSide(color: ShopColors.line),
              foregroundColor: ShopColors.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: pick,
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  size: 14,
                  color: ShopColors.inkFaint,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    value == null
                        ? 'انتخاب تاریخ'
                        : Fa.date(value.toIso8601String(), time: false),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: value == null
                          ? ShopColors.inkFaint
                          : ShopColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (value != null)
          IconButton(
            onPressed: clear,
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.close_rounded,
              size: 15,
              color: ShopColors.danger,
            ),
          ),
      ],
    );
  }
}

// ============================================================
//  سخت‌افزار و سلامت
// ============================================================

class ServerHardwareSheet extends StatefulWidget {
  const ServerHardwareSheet({super.key, required this.repo, required this.server});
  final ServerRepository repo;
  final ServerRow server;

  @override
  State<ServerHardwareSheet> createState() => _ServerHardwareSheetState();
}

class _ServerHardwareSheetState extends State<ServerHardwareSheet> {
  ServerHardware? _hw;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final hw = await widget.repo.hardware(widget.server.id);
    if (!mounted) return;
    setState(() {
      _hw = hw;
      _loading = false;
      if (hw == null) _error = 'سخت‌افزاری برای این سرور ثبت نشده است.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: ShopColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: const BoxDecoration(
              color: ShopColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: ShopColors.line)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.memory_rounded,
                  size: 17,
                  color: ShopColors.teal,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'سخت‌افزار و سلامت — ${widget.server.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _load,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 19),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                    children: [
                      if (_error != null)
                        SystemNote(
                          text: _error!,
                          color: ShopColors.warn,
                          icon: Icons.info_outline_rounded,
                        )
                      else ...[
                        InfoRow(
                          label: 'زمان دریافت',
                          value: Fa.date(_hw?.capturedAt?.toIso8601String()),
                        ),
                        InfoRow(
                          label: 'آخرین Inventory',
                          value: Fa.date(
                            widget.server.lastInventoryAt?.toIso8601String(),
                          ),
                        ),
                        InfoRow(
                          label: 'وضعیت توان',
                          value: widget.server.lastPowerState ?? '—',
                          ltr: true,
                        ),
                        if ((widget.server.lastHealthMessage ?? '').isNotEmpty)
                          InfoRow(
                            label: 'پیام سلامت',
                            value: widget.server.lastHealthMessage!,
                          ),
                        if ((widget.server.lastConnectionError ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: SystemNote(
                              text: widget.server.lastConnectionError!,
                              color: ShopColors.danger,
                              icon: Icons.cloud_off_rounded,
                            ),
                          ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _count('سالم', _hw?.countHealth('OK') ?? 0, ShopColors.ok),
                            const SizedBox(width: 6),
                            _count(
                              'هشدار',
                              _hw?.countHealth('Warning') ?? 0,
                              ShopColors.warn,
                            ),
                            const SizedBox(width: 6),
                            _count(
                              'بحرانی',
                              _hw?.countHealth('Critical') ?? 0,
                              ShopColors.danger,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _card(
                          'قطعات',
                          Icons.developer_board_rounded,
                          (_hw?.components ?? const [])
                              .map(
                                (c) => _compRow(c),
                              )
                              .toList(),
                          empty: 'قطعه‌ای گزارش نشده است.',
                        ),
                        const SizedBox(height: 10),
                        _card(
                          'رخدادهای iLO',
                          Icons.notifications_active_rounded,
                          (_hw?.events ?? []).map((e) => _eventRow(e)).toList(),
                          empty: 'رخدادی گزارش نشده است.',
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _count(String label, int n, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            Fa.digits(n),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: color),
          ),
        ],
      ),
    ),
  );

  Widget _card(
    String title,
    IconData icon,
    List<Widget> children, {
    required String empty,
  }) => Container(
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
          decoration: const BoxDecoration(
            color: Color(0xfff7f9fd),
            borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            border: Border(bottom: BorderSide(color: ShopColors.line)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: ShopColors.inkSoft),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        if (children.isEmpty)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              empty,
              style: const TextStyle(fontSize: 10, color: ShopColors.inkFaint),
            ),
          )
        else
          ...children,
      ],
    ),
  );

  Widget _compRow(ServerHardwareComponent c) {
    final color = Color(ServerHealth.colorValue(c.health));
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ShopColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name.isEmpty ? c.typeFa : c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: ShopColors.ink,
                  ),
                ),
                Text(
                  '${c.typeFa} · ${c.modelCell}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    color: ShopColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            c.valueCell,
            style: const TextStyle(fontSize: 9.5, color: ShopColors.inkSoft),
          ),
          const SizedBox(width: 6),
          ShopTag(text: ServerHealth.title(c.health), color: color),
        ],
      ),
    );
  }

  Widget _eventRow(ServerHardwareEvent e) {
    final color = Color(ServerHealth.colorValue(e.severity));
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ShopColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  e.message,
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.6,
                    color: ShopColors.inkSoft,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ShopTag(text: ServerHealth.title(e.severity), color: color),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${Fa.date(e.at?.toIso8601String())}${(e.origin ?? '').isEmpty ? '' : ' · ${e.origin}'}',
            style: const TextStyle(fontSize: 8.8, color: ShopColors.inkFaint),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  گواهی iLO
// ============================================================

class IloCertificateSheet extends StatefulWidget {
  const IloCertificateSheet({
    super.key,
    required this.repo,
    required this.server,
    this.initial,
    this.onTrusted,
  });
  final ServerRepository repo;
  final ServerRow server;
  final IloCertificateCheck? initial;
  final Future<void> Function()? onTrusted;

  @override
  State<IloCertificateSheet> createState() => _IloCertificateSheetState();
}

class _IloCertificateSheetState extends State<IloCertificateSheet> {
  IloCertificateCheck? _check;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check = widget.initial;
    if (_check != null) {
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.repo.certificate(widget.server.id);
      if (!mounted) return;
      setState(() {
        _check = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _clean(e);
      });
    }
  }

  Future<void> _trust() async {
    final tp = _check?.certificate?.thumbprint ?? '';
    if (tp.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.trustCertificate(widget.server.id, tp);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('گواهی iLO تأیید و ثبت شد.', style: TextStyle(fontSize: 11.5)),
          backgroundColor: ShopColors.ok,
        ),
      );
      await _load();
      if (widget.onTrusted != null) await widget.onTrusted!();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _clean(e);
      });
      return;
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _untrust() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'حذف تأیید گواهی',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'تأیید اثر انگشت گواهی iLO حذف شود؟ تا تأیید مجدد، دریافت اطلاعات از این سرور متوقف می‌ماند.',
          style: TextStyle(fontSize: 12, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ShopColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف تأیید'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.untrustCertificate(widget.server.id);
      if (!mounted) return;
      setState(() => _busy = false);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _clean(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _check?.certificate;
    final pinned = _check?.pinned;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: ShopColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: const BoxDecoration(
              color: ShopColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: ShopColors.line)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  size: 17,
                  color: ShopColors.accent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'گواهی iLO — ${widget.server.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : _load,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 19),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  if (_error != null) ...[
                    SystemNote(
                      text: _error!,
                      color: ShopColors.danger,
                      icon: Icons.error_outline_rounded,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if ((_check?.error ?? '').isNotEmpty)
                    SystemNote(
                      text: _check!.error!,
                      color: ShopColors.danger,
                      icon: Icons.cloud_off_rounded,
                    ),
                  if (c != null) ...[
                    _box(
                      c.systemTrusted
                          ? const ShopTag(
                              text: 'معتبر در مخزن سیستم',
                              color: ShopColors.ok,
                              icon: Icons.verified_rounded,
                            )
                          : const ShopTag(
                              text: 'خودامضا / خارج از مخزن سیستم',
                              color: ShopColors.warn,
                              icon: Icons.report_rounded,
                            ),
                      children: [
                        InfoRow(
                          label: 'اثر انگشت',
                          value: c.fingerprint,
                          ltr: true,
                        ),
                        InfoRow(label: 'موضوع گواهی', value: c.subject),
                        InfoRow(label: 'صادرکننده', value: c.issuer),
                        InfoRow(
                          label: 'اعتبار از',
                          value: Fa.date(c.notBefore?.toIso8601String()),
                        ),
                        InfoRow(
                          label: 'اعتبار تا',
                          value: Fa.date(c.notAfter?.toIso8601String()),
                          valueColor: c.expired ? ShopColors.danger : null,
                        ),
                        InfoRow(
                          label: 'همخوان با pin',
                          value: _check!.matchesPin ? 'بله' : 'خیر',
                          valueColor: _check!.matchesPin
                              ? ShopColors.ok
                              : ShopColors.warn,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ] else if (!_loading && _error == null)
                    const SystemNote(
                      text:
                          'گواهی iLO دریافت نشد. آدرس و پورت iLO را بررسی کنید.',
                      color: ShopColors.warn,
                      icon: Icons.info_outline_rounded,
                    ),
                  if (pinned != null) ...[
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: ShopColors.ok.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: ShopColors.ok.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.lock_rounded,
                                size: 14,
                                color: ShopColors.ok,
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'گواهی تأییدشدهٔ سرور',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: ShopColors.ok,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          InfoRow(
                            label: 'اثر انگشت',
                            value: pinned.fingerprint,
                            ltr: true,
                          ),
                          if ((pinned.subject ?? '').isNotEmpty)
                            InfoRow(label: 'موضوع', value: pinned.subject!),
                          InfoRow(
                            label: 'اعتبار تا',
                            value: Fa.date(pinned.notAfter?.toIso8601String()),
                          ),
                          InfoRow(
                            label: 'تأیید در',
                            value: Fa.date(pinned.trustedAt?.toIso8601String()),
                          ),
                          if ((pinned.trustedByName ?? '').isNotEmpty)
                            InfoRow(
                              label: 'تأیید کننده',
                              value: pinned.trustedByName!,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Row(
                      children: [
                        if ((_check?.canTrust ?? false) && c != null)
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: ShopColors.ok,
                                minimumSize: const Size(0, 40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              onPressed: _trust,
                              icon: const Icon(
                                Icons.verified_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                'تأیید این گواهی',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        if ((pinned != null)) ...[
                          if (_check?.canTrust ?? false)
                            const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 40),
                                foregroundColor: ShopColors.danger,
                                side: BorderSide(
                                  color: ShopColors.danger.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              onPressed: _untrust,
                              icon: const Icon(
                                Icons.link_off_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                'حذف تأیید',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  const SizedBox(height: 10),
                  const SystemNote(
                    text:
                        'تأیید گواهی یعنی اثر انگشت فعلی iLO به این سرور قفل می‌شود؛ اگر گواهی دستگاه بعداً تغییر کند، دریافت اطلاعات تا تأیید مجدد متوقف می‌ماند. این کار جایگزین بررسی کامل گواهی نیست.',
                    color: ShopColors.warn,
                    icon: Icons.shield_rounded,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _box(Widget tag, {required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [tag, const SizedBox(height: 6), ...children],
    ),
  );
}
