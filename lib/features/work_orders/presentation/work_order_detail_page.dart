import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/utils/fa.dart';
import '../../../core/widgets/common.dart';
import '../data/work_order_repository.dart';
import '../models/work_order.dart';
import 'work_order_editor_page.dart';

class WorkOrderDetailPage extends StatefulWidget {
  const WorkOrderDetailPage({super.key, required this.id});
  final int id;
  @override
  State<WorkOrderDetailPage> createState() => _WorkOrderDetailPageState();
}

class _WorkOrderDetailPageState extends State<WorkOrderDetailPage>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 5, vsync: this);
  WorkOrder? _order;
  List<dynamic> _checklist = [], _comments = [], _attachments = [], _logs = [];
  bool _loading = true, _busy = false;
  String? _error;
  final _comment = TextEditingController();
  int? _replyTo;
  final _checklistText = TextEditingController();

  WorkOrderRepository get repo => context.read<WorkOrderRepository>();
  int get myId => context.read<AuthController>().session?.userId ?? 0;
  bool get isOwner => _order?.ownerUserId == myId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _comment.dispose();
    _checklistText.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await repo.detail(widget.id);
      final values = await Future.wait([
        repo.checklist(widget.id),
        repo.comments(widget.id),
        repo.attachments(widget.id),
        repo.logs(widget.id),
      ]);
      if (order.assignees.any((a) => a.userId == myId && a.seenAt == null))
        await repo.seen(widget.id);
      if (!mounted) return;
      setState(() {
        _order = order;
        _checklist = values[0];
        _comments = values[1];
        _attachments = values[2];
        _logs = values[3];
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

  Future<void> _run(Future<void> Function() action, [String? success]) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (success != null && mounted) showMessage(context, success);
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reply() async {
    bool done = true;
    final text = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.of(c).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'ثبت پاسخ دستور کار',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('انجام شد'),
                    icon: Icon(Icons.check_circle_outline),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('انجام نشد'),
                    icon: Icon(Icons.cancel_outlined),
                  ),
                ],
                selected: {done},
                onSelectionChanged: (v) => setSheet(() => done = v.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: text,
                minLines: 3,
                maxLines: 6,
                maxLength: 4000,
                decoration: const InputDecoration(labelText: 'شرح پاسخ'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('ثبت پاسخ'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == true)
      await _run(
        () => repo.reply(widget.id, done, text.text.trim()),
        'پاسخ ثبت شد.',
      );
    text.dispose();
  }

  Future<void> _decide(Assignee a, bool approved) async {
    final note = await promptText(
      context,
      approved ? 'تأیید پاسخ ${a.name}' : 'رد پاسخ ${a.name}',
      hint: 'یادداشت (اختیاری)',
    );
    if (note != null)
      await _run(() => repo.decide(widget.id, a.id, approved, note));
  }

  Future<DateTime?> _pickDate(DateTime initial) async {
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (d == null || !mounted) return null;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    return t == null
        ? null
        : DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _extend() async {
    final due = await _pickDate(
      DateTime.tryParse(_order?.dueAt ?? '')?.add(const Duration(days: 1)) ??
          DateTime.now().add(const Duration(days: 1)),
    );
    if (due == null || !mounted) return;
    final note = await promptText(context, 'علت تمدید', hint: 'اختیاری');
    if (note != null)
      await _run(() => repo.extend(widget.id, due, note), 'مهلت تمدید شد.');
  }

  Future<void> _close() async {
    final note = await promptText(
      context,
      'بستن نهایی دستور کار',
      hint: 'یادداشت بستن (اختیاری)',
    );
    if (note != null)
      await _run(() => repo.close(widget.id, note), 'دستور کار بسته شد.');
  }

  Future<void> _reopen() async {
    bool reset = true;
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialog) => AlertDialog(
          title: const Text('بازگشایی دستور کار'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: note,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'علت بازگشایی'),
              ),
              CheckboxListTile(
                value: reset,
                onChanged: (v) => setDialog(() => reset = v ?? true),
                title: const Text('باطل‌کردن پاسخ‌های قبلی'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('بازگشایی'),
            ),
          ],
        ),
      ),
    );
    if (ok == true)
      await _run(
        () => repo.reopen(widget.id, note.text.trim(), null, reset),
        'دستور کار بازگشایی شد.',
      );
    note.dispose();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف دستور کار'),
        content: const Text(
          'این دستور کار حذف شود؟ سابقهٔ آن در سرور حفظ می‌شود.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await repo.remove(widget.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _addAssignees() async {
    final users = await repo.targets();
    final selected = <int>{};
    bool sms = false;
    final note = TextEditingController();
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialog) => AlertDialog(
          title: const Text('افزودن گیرنده'),
          content: SizedBox(
            width: 450,
            height: 430,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    children: users
                        .where(
                          (u) =>
                              !_order!.assignees.any((a) => a.userId == u.id),
                        )
                        .map(
                          (u) => CheckboxListTile(
                            value: selected.contains(u.id),
                            title: Text(u.username),
                            onChanged: (v) => setDialog(
                              () => v == true
                                  ? selected.add(u.id)
                                  : selected.remove(u.id),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'یادداشت'),
                ),
                SwitchListTile(
                  value: sms,
                  onChanged: (v) => setDialog(() => sms = v),
                  title: const Text('ارسال پیامک'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: selected.isEmpty ? null : () => Navigator.pop(c, true),
              child: const Text('افزودن'),
            ),
          ],
        ),
      ),
    );
    if (ok == true)
      await _run(
        () => repo.addAssignees(
          widget.id,
          selected.toList(),
          note.text.trim(),
          sms,
        ),
        'گیرندگان جدید اضافه شدند.',
      );
    note.dispose();
  }

  Future<void> _upload({bool camera = false}) async {
    try {
      if (camera) {
        final x = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
        if (x != null)
          await _run(
            () => repo.upload(widget.id, x.path, x.name),
            'تصویر پیوست شد.',
          );
      } else {
        final files = await FilePicker.pickFiles();
        for (final f in files) {
          if (f.path == null) continue;
          if ((f.lengthSync() ?? 0) > 10 * 1024 * 1024) {
            if (mounted)
              showMessage(
                context,
                '${f.name}: حداکثر حجم ۱۰ مگابایت است.',
                error: true,
              );
            continue;
          }
          await repo.upload(widget.id, f.path!, f.name);
        }
        await _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _download(Map<String, dynamic> a) async {
    try {
      final file = await repo.downloadAttachment(
        (a['id'] as num).toInt(),
        a['fileName']?.toString() ?? 'attachment',
      );
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        builder: (c) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('بازکردن فایل'),
                onTap: () {
                  Navigator.pop(c);
                  OpenFilex.open(file.path);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('اشتراک‌گذاری'),
                onTap: () {
                  Navigator.pop(c);
                  SharePlus.instance.share(
                    ShareParams(files: [XFile(file.path)]),
                  );
                },
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _edit() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => WorkOrderEditorPage(order: _order)),
    );
    if (result == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    final canEdit =
        o != null &&
        isOwner &&
        o.isOpen &&
        o.assignees.every((a) => a.seenAt == null && a.repliedAt == null);
    return Scaffold(
      appBar: AppBar(
        title: Text(o?.number ?? 'جزئیات دستور کار'),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: 'ویرایش',
              onPressed: _edit,
              icon: const Icon(Icons.edit_outlined),
            ),
          if (o != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'extend':
                    _extend();
                    break;
                  case 'close':
                    _close();
                    break;
                  case 'reopen':
                    _reopen();
                    break;
                  case 'assignees':
                    _addAssignees();
                    break;
                  case 'delete':
                    _delete();
                    break;
                }
              },
              itemBuilder: (_) => [
                if (isOwner && o.isOpen) ...const [
                  PopupMenuItem(
                    value: 'extend',
                    child: ListTile(
                      leading: Icon(Icons.more_time),
                      title: Text('تمدید مهلت'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'assignees',
                    child: ListTile(
                      leading: Icon(Icons.group_add_outlined),
                      title: Text('افزودن گیرنده'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'close',
                    child: ListTile(
                      leading: Icon(Icons.lock_outline),
                      title: Text('بستن نهایی'),
                    ),
                  ),
                ],
                if (isOwner && !o.isOpen)
                  const PopupMenuItem(
                    value: 'reopen',
                    child: ListTile(
                      leading: Icon(Icons.lock_open_outlined),
                      title: Text('بازگشایی'),
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text('حذف'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : Column(
              children: [
                Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabs: const [
                      Tab(text: 'جزئیات'),
                      Tab(text: 'چک‌لیست'),
                      Tab(text: 'گفتگو'),
                      Tab(text: 'پیوست'),
                      Tab(text: 'تاریخچه'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _overview(),
                      _checklistTab(),
                      _commentsTab(),
                      _attachmentsTab(),
                      _logsTab(),
                    ],
                  ),
                ),
                if (o!.isOpen && o.assignees.any((a) => a.userId == myId))
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _reply,
                          icon: const Icon(Icons.reply),
                          label: const Text('ثبت پاسخ'),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _overview() {
    final o = _order!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _statusChip(o),
              const SizedBox(width: 7),
              Chip(label: Text(Fa.priority(o.priority))),
              if (o.recurrence > 0) ...[
                const SizedBox(width: 7),
                Chip(
                  avatar: const Icon(Icons.repeat, size: 17),
                  label: Text(Fa.recurrence(o.recurrence)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            o.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          SelectableText(
            o.description.isEmpty ? 'بدون شرح' : o.description,
            style: const TextStyle(height: 1.8),
          ),
          const SizedBox(height: 18),
          _info(Icons.person_outline, 'دستوردهنده', o.ownerName),
          _info(Icons.event, 'مهلت انجام', Fa.date(o.dueAt)),
          _info(Icons.add_box_outlined, 'تاریخ ثبت', Fa.date(o.createdAt)),
          if (o.projectName != null)
            _info(
              Icons.account_tree_outlined,
              'پروژه',
              '${o.projectCode ?? ''} ${o.projectName}',
            ),
          if (o.closeNote?.isNotEmpty == true)
            _info(Icons.lock_outline, 'یادداشت بستن', o.closeNote!),
          if (o.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Wrap(
                spacing: 6,
                children: o.tags.map((e) => Chip(label: Text('#$e'))).toList(),
              ),
            ),
          const SizedBox(height: 14),
          Text(
            'گیرندگان (${Fa.digits(o.assignees.length)})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 8),
          ...o.assignees.map(
            (a) => Card(
              margin: const EdgeInsets.only(bottom: 9),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(child: Text(a.name.characters.first)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            a.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        _assigneeStatus(a),
                      ],
                    ),
                    if (a.replyText?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: SelectableText(a.replyText!),
                      ),
                    if (a.repliedAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'پاسخ: ${Fa.date(a.repliedAt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ),
                    if (a.ownerDecisionNote?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'یادداشت دستوردهنده: ${a.ownerDecisionNote}',
                        ),
                      ),
                    if (isOwner && o.isOpen && a.repliedAt != null)
                      OverflowBar(
                        children: [
                          TextButton.icon(
                            onPressed: () => _decide(a, true),
                            icon: const Icon(Icons.check, color: Colors.green),
                            label: const Text('تأیید'),
                          ),
                          TextButton.icon(
                            onPressed: () => _decide(a, false),
                            icon: const Icon(Icons.close, color: Colors.red),
                            label: const Text('رد'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }

  Widget _assigneeStatus(Assignee a) {
    if (a.ownerDecision == 'Approved')
      return const Chip(
        label: Text('تأیید شده'),
        backgroundColor: Color(0xffe3f7e9),
      );
    if (a.ownerDecision == 'Rejected')
      return const Chip(
        label: Text('رد شده'),
        backgroundColor: Color(0xffffe8e8),
      );
    if (a.done == true)
      return const Text('انجام شد', style: TextStyle(color: Colors.green));
    if (a.done == false)
      return const Text('انجام نشد', style: TextStyle(color: Colors.red));
    if (a.seenAt != null) return const Text('رویت شده');
    return const Text('در انتظار رویت');
  }

  Widget _statusChip(WorkOrder o) => Chip(
    label: Text(
      !o.isOpen
          ? 'بسته'
          : o.isOverdue
          ? 'باز • دیرکرد'
          : 'باز',
    ),
    backgroundColor: !o.isOpen
        ? Colors.blueGrey.shade100
        : o.isOverdue
        ? Colors.red.shade50
        : Colors.green.shade50,
  );

  Widget _info(IconData icon, String title, String value) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: Colors.blueGrey),
    title: Text(
      title,
      style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
    ),
    subtitle: Text(value, style: const TextStyle(fontSize: 15)),
  );

  Widget _checklistTab() {
    final o = _order!;
    final done = _checklist
        .where((e) => e is Map && e['isDone'] == true)
        .length;
    return Column(
      children: [
        if (_checklist.isNotEmpty)
          LinearProgressIndicator(
            value: _checklist.isEmpty ? 0 : done / _checklist.length,
          ),
        if (o.isOpen)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _checklistText,
                    decoration: const InputDecoration(hintText: 'زیرکار جدید'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () {
                    if (_checklistText.text.trim().isNotEmpty) {
                      final t = _checklistText.text.trim();
                      _checklistText.clear();
                      _run(() => repo.addChecklist(widget.id, t));
                    }
                  },
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        Expanded(
          child: _checklist.isEmpty
              ? const EmptyView(message: 'زیرکاری ثبت نشده است.')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: _checklist.whereType<Map>().map((raw) {
                      final c = Map<String, dynamic>.from(raw);
                      final id = (c['id'] as num).toInt();
                      final checked = c['isDone'] == true;
                      return CheckboxListTile(
                        value: checked,
                        onChanged: o.isOpen
                            ? (_) => _run(
                                () => repo.toggleChecklist(widget.id, id),
                              )
                            : null,
                        title: Text(
                          c['text']?.toString() ?? '',
                          style: TextStyle(
                            decoration: checked
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        secondary: o.isOpen
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _run(
                                  () => repo.deleteChecklist(widget.id, id),
                                ),
                              )
                            : null,
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _commentsTab() {
    final o = _order!;
    return Column(
      children: [
        Expanded(
          child: _comments.isEmpty
              ? const EmptyView(message: 'گفتگویی ثبت نشده است.')
              : ListView.builder(
                  reverse: false,
                  padding: const EdgeInsets.all(12),
                  itemCount: _comments.length,
                  itemBuilder: (_, i) {
                    final c = Map<String, dynamic>.from(_comments[i] as Map);
                    final mine = (c['authorUserId'] as num?)?.toInt() == myId;
                    final deleted = c['isDeleted'] == true;
                    return Align(
                      alignment: mine
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 360),
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: mine ? const Color(0xffe5edff) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c['authorName']?.toString() ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 5),
                            SelectableText(
                              deleted
                                  ? 'این پیام حذف شده است.'
                                  : c['text']?.toString() ?? '',
                              style: TextStyle(
                                fontStyle: deleted ? FontStyle.italic : null,
                                color: deleted ? Colors.grey : null,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              Fa.date(c['createdAt']?.toString()),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            if (!deleted && o.isOpen)
                              OverflowBar(
                                children: [
                                  TextButton(
                                    onPressed: () => setState(
                                      () => _replyTo = (c['id'] as num).toInt(),
                                    ),
                                    child: const Text('پاسخ'),
                                  ),
                                  if (mine)
                                    TextButton(
                                      onPressed: () async {
                                        final t = await promptText(
                                          context,
                                          'ویرایش پیام',
                                          initial: c['text']?.toString(),
                                        );
                                        if (t != null && t.isNotEmpty)
                                          _run(
                                            () => repo.editComment(
                                              (c['id'] as num).toInt(),
                                              t,
                                            ),
                                          );
                                      },
                                      child: const Text('ویرایش'),
                                    ),
                                  if (mine || isOwner)
                                    TextButton(
                                      onPressed: () => _run(
                                        () => repo.deleteComment(
                                          (c['id'] as num).toInt(),
                                        ),
                                      ),
                                      child: const Text(
                                        'حذف',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (o.isOpen)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  if (_replyTo != null)
                    Chip(
                      label: Text('در حال پاسخ به پیام ${Fa.digits(_replyTo)}'),
                      onDeleted: () => setState(() => _replyTo = null),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _comment,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'نوشتن پیام...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: () {
                          final t = _comment.text.trim();
                          if (t.isEmpty) return;
                          _comment.clear();
                          final replyTo = _replyTo;
                          _replyTo = null;
                          _run(
                            () => repo.addComment(
                              widget.id,
                              t,
                              replyToId: replyTo,
                            ),
                          );
                        },
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _attachmentsTab() => Column(
    children: [
      if (_order!.isOpen)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _upload(),
                  icon: const Icon(Icons.attach_file),
                  label: const Text('انتخاب فایل'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _upload(camera: true),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('دوربین'),
                ),
              ),
            ],
          ),
        ),
      Expanded(
        child: _attachments.isEmpty
            ? const EmptyView(
                message: 'پیوستی ثبت نشده است.',
                icon: Icons.attach_file,
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  children: _attachments.whereType<Map>().map((raw) {
                    final a = Map<String, dynamic>.from(raw);
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: ListTile(
                        onTap: () => _download(a),
                        leading: const Icon(Icons.insert_drive_file_outlined),
                        title: Text(
                          a['fileName']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${a['uploaderName'] ?? ''} • ${Fa.bytes((a['size'] as num?)?.toInt() ?? 0)}\n${Fa.date(a['uploadedAt']?.toString())}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.download_outlined),
                      ),
                    );
                  }).toList(),
                ),
              ),
      ),
    ],
  );

  Widget _logsTab() => _logs.isEmpty
      ? const EmptyView(message: 'سابقه‌ای ثبت نشده است.')
      : RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _logs.length,
            itemBuilder: (_, i) {
              final l = _logs[i] as Map;
              return Card(
                margin: const EdgeInsets.only(bottom: 7),
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(
                    l['text']?.toString() ?? l['action']?.toString() ?? '',
                  ),
                  subtitle: Text(
                    '${l['actorName'] ?? ''}\n${Fa.date(l['createdAt']?.toString())}',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        );
}
