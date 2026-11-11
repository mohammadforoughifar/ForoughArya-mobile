import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../../../core/widgets/common.dart';
import '../data/work_order_repository.dart';
import '../models/work_order.dart';

class WorkOrderEditorPage extends StatefulWidget {
  const WorkOrderEditorPage({
    super.key,
    this.order,
    this.prefillTitle,
    this.prefillDescription,
    this.prefillAssigneeIds = const [],
    this.prefillTags = const [],
    this.prefillDue,
    this.sourceLabel,
    this.sourceModule,
    this.sourceId,
  });

  final WorkOrder? order;

  /// پیش‌پر کردن فرم از مبدأ (مثلاً یک بند صورتجلسه یا کل صورتجلسه)
  final String? prefillTitle;
  final String? prefillDescription;
  final List<int> prefillAssigneeIds;
  final List<String> prefillTags;
  final DateTime? prefillDue;
  final String? sourceLabel;

  /// مبدأ سند (آینهٔ وب): مثلاً `Document` + شناسهٔ مدرک
  final String? sourceModule;
  final int? sourceId;
  @override
  State<WorkOrderEditorPage> createState() => _WorkOrderEditorPageState();
}

class _WorkOrderEditorPageState extends State<WorkOrderEditorPage> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.order?.title ?? '');
  late final _description = TextEditingController(
    text: widget.order?.description ?? '',
  );
  final _tag = TextEditingController();
  final _checklist = TextEditingController();
  late DateTime _due =
      DateTime.tryParse(widget.order?.dueAt ?? '')?.toLocal() ??
      DateTime.now().add(const Duration(days: 1));
  late int _priority = widget.order?.priority ?? 1;
  late int _recurrence = widget.order?.recurrence ?? 0;
  late int _weight = widget.order?.weight ?? 1;
  late final List<String> _tags = [
    ...?widget.order?.tags,
    ...widget.prefillTags.where((t) => (t).trim().isNotEmpty),
  ];
  final List<String> _checklistItems = [];
  late final Set<int> _targets = {...widget.prefillAssigneeIds};
  List<TargetUser> _users = [];
  List<dynamic> _templates = [];
  final List<PlatformFile> _files = [];
  bool _sms = false, _loading = true, _saving = false;
  String? _error;
  final _requestId = const Uuid().v4();

  bool get editing => widget.order != null;

  @override
  void initState() {
    super.initState();
    _targets.addAll((widget.order?.assignees ?? []).map((e) => e.userId));
    if (widget.order == null) {
      if ((widget.prefillTitle ?? '').trim().isNotEmpty) {
        _title.text = widget.prefillTitle!.trim();
      }
      if ((widget.prefillDescription ?? '').trim().isNotEmpty) {
        _description.text = widget.prefillDescription!.trim();
      }
      if (widget.prefillDue != null) _due = widget.prefillDue!;
    }
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<WorkOrderRepository>();
    try {
      final results = await Future.wait([repo.targets(), repo.templates()]);
      if (!mounted) return;
      setState(() {
        _users = results[0] as List<TargetUser>;
        _templates = results[1];
        _loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _tag.dispose();
    _checklist.dispose();
    super.dispose();
  }

  /// انتخاب مهلت با تقویم شمسی.
  /// انتخابگر ساعت پیش‌فرض فلاتر میلادی/۲۴ساعته نمایش داده و در بعضی
  /// گوشی‌ها گیج‌کننده بود؛ اینجا فقط تاریخ شمسی انتخاب می‌شود و ساعت
  /// همان ساعتِ فعلی (یا ساعت قبلی) حفظ می‌شود.
  Future<void> _pickDue() async {
    final date = await showJalaliDatePicker(
      context,
      initial: _due,
      title: 'مهلت انجام (شمسی)',
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    setState(
      () => _due = DateTime(
        date.year,
        date.month,
        date.day,
        _due.hour,
        _due.minute,
      ),
    );
  }

  /// انتخاب ساعت با چیدمان فارسی (بدون انتخابگر میلادی فلاتر)
  Future<void> _pickDueTime() async {
    final hour = ValueNotifier<int>(_due.hour);
    final minute = ValueNotifier<int>(_due.minute);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text(
          'ساعت مهلت',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              child: ValueListenableBuilder<int>(
                valueListenable: hour,
                builder: (_, v, _) => DropdownButtonFormField<int>(
                  initialValue: v,
                  decoration: const InputDecoration(labelText: 'ساعت'),
                  items: [
                    for (var h = 0; h < 24; h++)
                      DropdownMenuItem(value: h, child: Text(Fa.digits(h))),
                  ],
                  onChanged: (x) => hour.value = x ?? v,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 80,
              child: ValueListenableBuilder<int>(
                valueListenable: minute,
                builder: (_, v, _) => DropdownButtonFormField<int>(
                  initialValue: v,
                  decoration: const InputDecoration(labelText: 'دقیقه'),
                  items: [
                    for (var m = 0; m < 60; m += 5)
                      DropdownMenuItem(value: m, child: Text(Fa.digits(m))),
                  ],
                  onChanged: (x) => minute.value = x ?? v,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('تأیید'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(
      () => _due = DateTime(
        _due.year,
        _due.month,
        _due.day,
        hour.value,
        minute.value,
      ),
    );
  }

  Future<void> _chooseTargets() async {
    final selected = Set<int>.from(_targets);
    final search = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setSheet) {
          final q = search.text.trim().toLowerCase();
          final users = _users
              .where((u) => u.username.toLowerCase().contains(q))
              .toList();
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(c).size.height * .72,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'انتخاب گیرندگان',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(c),
                          child: Text('تأیید (${Fa.digits(selected.length)})'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: search,
                      onChanged: (_) => setSheet(() {}),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'جستجوی شخص',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (_, i) {
                        final u = users[i];
                        return CheckboxListTile(
                          value: selected.contains(u.id),
                          title: Text(u.username),
                          secondary: CircleAvatar(
                            child: Text(u.username.characters.first),
                          ),
                          onChanged: (v) => setSheet(
                            () => v == true
                                ? selected.add(u.id)
                                : selected.remove(u.id),
                          ),
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
    );
    search.dispose();
    if (mounted)
      setState(
        () => _targets
          ..clear()
          ..addAll(selected),
      );
  }

  Future<void> _chooseFiles() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;
    setState(() {
      for (final f in files) {
        if ((f.lengthSync() ?? 0) > 10 * 1024 * 1024) {
          showMessage(
            context,
            'حجم «${f.name}» بیش از ۱۰ مگابایت است.',
            error: true,
          );
        } else if (f.path != null)
          _files.add(f);
      }
    });
  }

  Future<void> _applyTemplate(Map<String, dynamic> t) async {
    setState(() {
      _title.text = t['title']?.toString() ?? '';
      _description.text = t['description']?.toString() ?? '';
      _priority = (t['priority'] as num?)?.toInt() ?? 1;
      _recurrence = (t['recurrence'] as num?)?.toInt() ?? 0;
      _targets
        ..clear()
        ..addAll(
          (t['assigneeUserIds'] as List? ?? []).map((e) => (e as num).toInt()),
        );
      _tags
        ..clear()
        ..addAll((t['tags'] as List? ?? []).map((e) => e.toString()));
      _checklistItems
        ..clear()
        ..addAll((t['checklistItems'] as List? ?? []).map((e) => e.toString()));
    });
    await context.read<WorkOrderRepository>().templateUsed(
      (t['id'] as num).toInt(),
    );
  }

  Future<void> _saveAsTemplate() async {
    if (_title.text.trim().isEmpty) {
      showMessage(
        context,
        'برای ذخیرهٔ قالب ابتدا عنوان را وارد کنید.',
        error: true,
      );
      return;
    }
    final name = await promptText(
      context,
      'نام قالب',
      hint: 'مثلاً بررسی هفتگی تجهیزات',
      maxLines: 1,
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await context.read<WorkOrderRepository>().saveTemplate(
        _body()..['name'] = name,
      );
      if (mounted) showMessage(context, 'قالب ذخیره شد.');
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Map<String, dynamic> _body() => {
    'title': _title.text.trim(),
    'description': _description.text.trim(),
    'dueAt': _due.toIso8601String(),
    'assigneeUserIds': _targets.toList(),
    'sendSms': _sms,
    'priority': _priority,
    'recurrence': _recurrence,
    'checklistItems': _checklistItems,
    'tags': _tags,
    'projectId': widget.order?.projectId,
    'parentOrderId': widget.order?.parentOrderId,
    'weight': _weight,
    'clientRequestId': _requestId,
    if ((widget.sourceModule ?? '').trim().isNotEmpty && (widget.sourceId ?? 0) > 0)
      'sourceModule': widget.sourceModule!.trim(),
    if ((widget.sourceModule ?? '').trim().isNotEmpty && (widget.sourceId ?? 0) > 0)
      'sourceId': widget.sourceId,
  };

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_targets.isEmpty) {
      showMessage(context, 'حداقل یک گیرنده انتخاب کنید.', error: true);
      return;
    }
    setState(() => _saving = true);
    final repo = context.read<WorkOrderRepository>();
    try {
      final result = await repo.save(_body(), id: widget.order?.id);
      final id = (result['id'] as num?)?.toInt() ?? widget.order?.id;
      if (id != null) {
        for (final f in _files) {
          await repo.upload(id, f.path!, f.name);
        }
      }
      if (mounted) {
        showMessage(
          context,
          editing ? 'دستور کار ویرایش شد.' : 'دستور کار با موفقیت ثبت شد.',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(editing ? 'ویرایش دستور کار' : 'دستور کار جدید'),
      actions: [
        if (!editing)
          IconButton(
            tooltip: 'ذخیره به‌عنوان قالب',
            onPressed: _saveAsTemplate,
            icon: const Icon(Icons.bookmark_add_outlined),
          ),
      ],
    ),
    body: _loading
        ? const LoadingView()
        : _error != null
        ? ErrorView(message: _error!, onRetry: _load)
        : Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!editing && _templates.isNotEmpty) ...[
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'شروع از قالب آماده',
                      prefixIcon: Icon(Icons.bookmarks_outlined),
                    ),
                    items: _templates.whereType<Map>().map((raw) {
                      final t = Map<String, dynamic>.from(raw);
                      return DropdownMenuItem(
                        value: (t['id'] as num).toInt(),
                        child: Text(t['name']?.toString() ?? ''),
                      );
                    }).toList(),
                    onChanged: (id) {
                      final t = _templates
                          .whereType<Map>()
                          .map((e) => Map<String, dynamic>.from(e))
                          .firstWhere((e) => e['id'] == id);
                      _applyTemplate(t);
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _title,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'عنوان دستور کار *',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'عنوان را وارد کنید.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    labelText: 'شرح و توضیحات',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    onTap: _pickDue,
                    leading: const Icon(Icons.event_available_outlined),
                    title: const Text('مهلت انجام (شمسی)'),
                    subtitle: Text(
                      // همیشه شمسی با اعداد فارسی — بدون تاریخ میلادی
                      '${Fa.date(_due.toIso8601String(), time: false)}  ساعت '
                      '${Fa.digits(_due.hour.toString().padLeft(2, '0'))}:${Fa.digits(_due.minute.toString().padLeft(2, '0'))}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'ساعت',
                          onPressed: _pickDueTime,
                          icon: const Icon(
                            Icons.schedule_rounded,
                            size: 20,
                          ),
                        ),
                        const Icon(Icons.edit_calendar_outlined),
                      ],
                    ),
                  ),
                ),
                if (!editing)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 4),
                    child: Text(
                      'تاریخ ثبت: ${Fa.date(DateTime.now().toIso8601String())}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xff64748b),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _priority,
                        decoration: const InputDecoration(labelText: 'اولویت'),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('کم')),
                          DropdownMenuItem(value: 1, child: Text('عادی')),
                          DropdownMenuItem(value: 2, child: Text('بالا')),
                          DropdownMenuItem(value: 3, child: Text('فوری')),
                        ],
                        onChanged: (v) => setState(() => _priority = v ?? 1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _recurrence,
                        decoration: const InputDecoration(labelText: 'تکرار'),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('ندارد')),
                          DropdownMenuItem(value: 1, child: Text('روزانه')),
                          DropdownMenuItem(value: 2, child: Text('هفتگی')),
                          DropdownMenuItem(value: 3, child: Text('ماهانه')),
                        ],
                        onChanged: (v) => setState(() => _recurrence = v ?? 0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _weight,
                  decoration: const InputDecoration(
                    labelText: 'وزن دستور در پیشرفت پروژه',
                  ),
                  items: List.generate(
                    11,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(i == 0 ? 'بدون تأثیر' : Fa.digits(i)),
                    ),
                  ),
                  onChanged: (v) => setState(() => _weight = v ?? 1),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    onTap: _chooseTargets,
                    leading: const Icon(Icons.group_add_outlined),
                    title: Text('گیرندگان (${Fa.digits(_targets.length)} نفر)'),
                    subtitle: Text(
                      _targets.isEmpty
                          ? 'انتخاب گیرنده الزامی است'
                          : _users
                                .where((u) => _targets.contains(u.id))
                                .map((u) => u.username)
                                .join('، '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_left),
                  ),
                ),
                SwitchListTile(
                  value: _sms,
                  onChanged: editing ? null : (v) => setState(() => _sms = v),
                  title: const Text('ارسال پیامک به گیرندگان'),
                  subtitle: const Text('پس از ثبت موفق دستور کار'),
                ),
                const SizedBox(height: 8),
                _Section(
                  title: 'برچسب‌ها',
                  action: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      final v = _tag.text.trim();
                      if (v.isNotEmpty &&
                          _tags.length < 5 &&
                          !_tags.contains(v))
                        setState(() {
                          _tags.add(v);
                          _tag.clear();
                        });
                    },
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _tag,
                        maxLength: 30,
                        decoration: const InputDecoration(
                          hintText: 'حداکثر ۵ برچسب',
                          counterText: '',
                        ),
                        onSubmitted: (_) => setState(() {
                          if (_tag.text.trim().isNotEmpty && _tags.length < 5) {
                            _tags.add(_tag.text.trim());
                            _tag.clear();
                          }
                        }),
                      ),
                      Wrap(
                        spacing: 7,
                        children: _tags
                            .map(
                              (t) => Chip(
                                label: Text(t),
                                onDeleted: () =>
                                    setState(() => _tags.remove(t)),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Section(
                  title: 'چک‌لیست',
                  action: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      if (_checklist.text.trim().isNotEmpty)
                        setState(() {
                          _checklistItems.add(_checklist.text.trim());
                          _checklist.clear();
                        });
                    },
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _checklist,
                        decoration: const InputDecoration(
                          hintText: 'زیرکار جدید',
                        ),
                      ),
                      ..._checklistItems.asMap().entries.map(
                        (e) => ListTile(
                          dense: true,
                          leading: Text(Fa.digits(e.key + 1)),
                          title: Text(e.value),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                setState(() => _checklistItems.removeAt(e.key)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    onTap: _chooseFiles,
                    leading: const Icon(Icons.attach_file),
                    title: Text('پیوست‌ها (${Fa.digits(_files.length)})'),
                    subtitle: const Text('هر فایل حداکثر ۱۰ مگابایت'),
                  ),
                ),
                ..._files.map(
                  (f) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(
                      f.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(Fa.bytes(f.lengthSync() ?? 0)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _files.remove(f)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(editing ? 'ذخیره تغییرات' : 'ثبت دستور کار'),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.action});
  final String title;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (action != null) action!,
            ],
          ),
          child,
        ],
      ),
    ),
  );
}
