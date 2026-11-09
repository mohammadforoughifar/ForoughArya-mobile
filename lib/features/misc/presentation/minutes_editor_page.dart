// ============================================================
//  صفحهٔ ثبت و ویرایش صورتجلسه
//  مسیر سرور: POST /api/meeting-minutes  +  GET /api/meeting-minutes/user-options
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../data/minutes_repository.dart';
import '../models/minutes_models.dart';
import 'misc_style.dart';

class MinutesEditorPage extends StatefulWidget {
  const MinutesEditorPage({super.key, this.initial});

  final MinutesDetail? initial;

  @override
  State<MinutesEditorPage> createState() => _MinutesEditorPageState();
}

class _DraftItem {
  _DraftItem({
    this.id = 0,
    required this.description,
    this.dueDate,
    this.responsibleUserId,
    this.followUpDate,
    this.followUpUserId,
  });

  int id;
  String description;
  DateTime? dueDate;
  int? responsibleUserId;
  DateTime? followUpDate;
  int? followUpUserId;

  SaveMinutesItemInput toInput() => SaveMinutesItemInput(
    id: id,
    description: description,
    dueDate: dueDate,
    responsibleUserId: responsibleUserId,
    followUpDate: followUpDate,
    followUpUserId: followUpUserId,
  );
}

class _MinutesEditorPageState extends State<MinutesEditorPage> {
  late final MinutesRepository _repo =
      Provider.of<MinutesRepository?>(context, listen: false) ??
      MinutesRepository(context.read<ApiClient>());

  late final TextEditingController _titleCtrl;
  late DateTime _meetingDate;
  final List<int> _attendeeIds = [];
  final List<int> _absentIds = [];
  final List<_DraftItem> _items = [];

  List<MinutesUserOption> _users = const [];
  bool _loadingUsers = true;
  bool _saving = false;
  Object? _loadError;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _titleCtrl = TextEditingController(text: init?.title ?? '');
    _meetingDate = init?.meetingDate ?? DateTime.now();
    if (init != null) {
      _attendeeIds.addAll(init.attendees.map((p) => p.userId));
      _absentIds.addAll(init.absentees.map((p) => p.userId));
      for (final i in init.items) {
        _items.add(
          _DraftItem(
            id: i.id,
            description: i.description,
            dueDate: i.dueDate,
            responsibleUserId: i.responsibleUserId,
            followUpDate: i.followUpDate,
            followUpUserId: i.followUpUserId,
          ),
        );
      }
    } else {
      final myId = context.read<AuthController>().session?.userId ?? 0;
      if (myId > 0) _attendeeIds.add(myId);
    }
    _loadUsers();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loadingUsers = true;
      _loadError = null;
    });
    try {
      final list = await _repo.fetchUserOptions();
      if (!mounted) return;
      setState(() {
        _users = list;
        _loadingUsers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingUsers = false;
        _loadError = e;
      });
    }
  }

  String _userName(int? id) {
    if (id == null || id <= 0) return 'انتخاب نشده';
    for (final u in _users) {
      if (u.id == id) return u.name;
    }
    if (widget.initial != null) {
      for (final p in widget.initial!.participants) {
        if (p.userId == id) return p.name;
      }
    }
    final sess = context.read<AuthController>().session;
    if (sess != null && sess.userId == id) return sess.displayName;
    return 'کاربر #${Fa.digits(id)}';
  }

  Future<void> _pickAttendees() async {
    final res = await pickMultiUsersSheet(
      context,
      title: 'انتخاب حاضرین جلسه',
      users: _users,
      initialSelected: _attendeeIds,
    );
    if (res == null) return;
    setState(() {
      _attendeeIds
        ..clear()
        ..addAll(res);
      _absentIds.removeWhere(_attendeeIds.contains);
    });
  }

  Future<void> _pickAbsentees() async {
    final res = await pickMultiUsersSheet(
      context,
      title: 'انتخاب غایبین جلسه',
      users: _users,
      initialSelected: _absentIds,
    );
    if (res == null) return;
    setState(() {
      _absentIds
        ..clear()
        ..addAll(res);
      _attendeeIds.removeWhere(_absentIds.contains);
    });
  }

  Future<void> _editOrAddItem({_DraftItem? existing, int? index}) async {
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    DateTime? dueDate = existing?.dueDate;
    int? respId = existing?.responsibleUserId;
    DateTime? followDate = existing?.followUpDate;
    int? followId = existing?.followUpUserId;

    final saved = await showModalBottomSheet<_DraftItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) {
            String nameOf(int? id) => id == null || id <= 0
                ? 'انتخاب همکار…'
                : _userName(id);

            return SafeArea(
              top: false,
              child: Container(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 14,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                decoration: const BoxDecoration(
                  color: MiscColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: MiscColors.line,
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      ),
                      Text(
                        existing == null ? 'افزودن بند جدید' : 'ویرایش بند',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'شرح بند / تصمیم گرفته‌شده *',
                          hintText: 'مثلاً: بررسی موجودی پایان دوره و ارسال گزارش…',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _PickerTile(
                              label: 'مسئول اجرا',
                              value: nameOf(respId),
                              icon: Icons.person_outline_rounded,
                              onTap: () async {
                                final p = await pickSingleUserSheet(
                                  ctx,
                                  title: 'انتخاب مسئول اجرا',
                                  users: _users,
                                  selectedId: respId,
                                );
                                if (p != null) {
                                  setS(() => respId = p.id == 0 ? null : p.id);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PickerTile(
                              label: 'مهلت انجام',
                              value: dueDate == null
                                  ? 'بدون مهلت'
                                  : formatJalaliDate(dueDate),
                              icon: Icons.event_available_rounded,
                              onClear: dueDate == null
                                  ? null
                                  : () => setS(() => dueDate = null),
                              onTap: () async {
                                final d = await showJalaliDatePicker(
                                  ctx,
                                  initial: dueDate,
                                  title: 'مهلت انجام بند',
                                );
                                if (d != null) setS(() => dueDate = d);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _PickerTile(
                              label: 'مسئول پیگیری',
                              value: nameOf(followId),
                              icon: Icons.verified_user_outlined,
                              onTap: () async {
                                final p = await pickSingleUserSheet(
                                  ctx,
                                  title: 'انتخاب مسئول پیگیری',
                                  users: _users,
                                  selectedId: followId,
                                );
                                if (p != null) {
                                  setS(
                                    () => followId = p.id == 0 ? null : p.id,
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PickerTile(
                              label: 'تاریخ پیگیری',
                              value: followDate == null
                                  ? 'تعیین نشده'
                                  : formatJalaliDate(followDate),
                              icon: Icons.schedule_rounded,
                              onClear: followDate == null
                                  ? null
                                  : () => setS(() => followDate = null),
                              onTap: () async {
                                final d = await showJalaliDatePicker(
                                  ctx,
                                  initial: followDate,
                                  title: 'تاریخ پیگیری بند',
                                );
                                if (d != null) setS(() => followDate = d);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('انصراف'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () {
                              final txt = descCtrl.text.trim();
                              if (txt.isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('شرح بند الزامی است.'),
                                  ),
                                );
                                return;
                              }
                              Navigator.of(ctx).pop(
                                _DraftItem(
                                  id: existing?.id ?? 0,
                                  description: txt,
                                  dueDate: dueDate,
                                  responsibleUserId: respId,
                                  followUpDate: followDate,
                                  followUpUserId: followId,
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: MiscColors.teal,
                            ),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('ثبت بند'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    if (saved == null || !mounted) return;
    setState(() {
      if (index != null) {
        _items[index] = saved;
      } else {
        _items.add(saved);
      }
    });
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('عنوان صورتجلسه الزامی است.')),
      );
      return;
    }
    if (_attendeeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حداقل یک حاضر برای جلسه انتخاب کنید.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final id = await _repo.save(
        SaveMinutesInput(
          id: widget.initial?.id ?? 0,
          title: title,
          meetingDate: _meetingDate,
          attendeeUserIds: _attendeeIds,
          absentUserIds: _absentIds,
          items: _items.map((e) => e.toInput()).toList(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: MiscColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: MiscColors.bg,
        appBar: AppBar(
          backgroundColor: MiscColors.teal,
          foregroundColor: Colors.white,
          title: Text(
            _isEdit
                ? 'ویرایش صورتجلسه #${Fa.digits(widget.initial!.id)}'
                : 'ثبت صورتجلسه جدید',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: MiscColors.teal,
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded, size: 17),
                label: Text(
                  _isEdit ? 'ذخیره' : 'ثبت',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
        body: _loadError != null
            ? Center(
                child: MinutesAccessDiagnosticCard(
                  error: _loadError!,
                  onRetry: _loadUsers,
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  // --- کارت مشخصات جلسه ---
                  _SectionCard(
                    title: 'مشخصات کلی جلسه',
                    icon: Icons.article_outlined,
                    child: Column(
                      children: [
                        TextField(
                          controller: _titleCtrl,
                          maxLength: 300,
                          decoration: InputDecoration(
                            labelText: 'عنوان صورتجلسه *',
                            hintText: 'مثلاً: جلسه هماهنگی فروش و انبار',
                            filled: true,
                            fillColor: MiscColors.bg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _PickerTile(
                          label: 'تاریخ برگزاری جلسه *',
                          value: formatJalaliDate(_meetingDate),
                          icon: Icons.calendar_month_rounded,
                          onTap: () async {
                            final d = await showJalaliDatePicker(
                              context,
                              initial: _meetingDate,
                              title: 'تاریخ برگزاری جلسه',
                            );
                            if (d != null) setState(() => _meetingDate = d);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // --- کارت شرکت‌کنندگان ---
                  _SectionCard(
                    title: 'شرکت‌کنندگان جلسه',
                    icon: Icons.groups_2_outlined,
                    trailing: _loadingUsers
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ParticipantsSelectorBox(
                          label: 'حاضرین جلسه *',
                          emptyHint: 'حداقل یک نفر حاضر انتخاب کنید',
                          ids: _attendeeIds,
                          nameResolver: _userName,
                          tone: MiscColors.ok,
                          onAddTap: _loadingUsers ? null : _pickAttendees,
                          onRemove: (id) =>
                              setState(() => _attendeeIds.remove(id)),
                        ),
                        const SizedBox(height: 12),
                        _ParticipantsSelectorBox(
                          label: 'غایبین جلسه (اختیاری)',
                          emptyHint: 'بدون غایب',
                          ids: _absentIds,
                          nameResolver: _userName,
                          tone: MiscColors.danger,
                          onAddTap: _loadingUsers ? null : _pickAbsentees,
                          onRemove: (id) =>
                              setState(() => _absentIds.remove(id)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // --- کارت بندها و مصوبات ---
                  _SectionCard(
                    title:
                        'بندها و تصمیمات (${Fa.digits(_items.length)} مورد)',
                    icon: Icons.checklist_rtl_rounded,
                    trailing: TextButton.icon(
                      onPressed: () => _editOrAddItem(),
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('افزودن بند'),
                    ),
                    child: _items.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.playlist_add_rounded,
                                  size: 34,
                                  color: MiscColors.inkFaint.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'هنوز بندی ثبت نشده است. با «افزودن بند» مصوبات جلسه را اضافه کنید.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: MiscColors.inkFaint,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < _items.length; i++) ...[
                                if (i > 0) const Divider(height: 18),
                                _DraftItemTile(
                                  index: i + 1,
                                  item: _items[i],
                                  nameResolver: _userName,
                                  onEdit: () => _editOrAddItem(
                                    existing: _items[i],
                                    index: i,
                                  ),
                                  onDelete: () =>
                                      setState(() => _items.removeAt(i)),
                                ),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: MiscColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: MiscColors.line),
      boxShadow: [
        BoxShadow(
          color: MiscColors.ink.withValues(alpha: 0.03),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 19, color: MiscColors.teal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: MiscColors.ink,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: MiscColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MiscColors.line),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: MiscColors.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: MiscColors.inkFaint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: MiscColors.ink,
                  ),
                ),
              ],
            ),
          ),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: MiscColors.inkFaint,
              ),
            ),
        ],
      ),
    ),
  );
}

class _ParticipantsSelectorBox extends StatelessWidget {
  const _ParticipantsSelectorBox({
    required this.label,
    required this.emptyHint,
    required this.ids,
    required this.nameResolver,
    required this.tone,
    required this.onAddTap,
    required this.onRemove,
  });

  final String label;
  final String emptyHint;
  final List<int> ids;
  final String Function(int?) nameResolver;
  final Color tone;
  final VoidCallback? onAddTap;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: MiscColors.bg,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: MiscColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$label (${Fa.digits(ids.length)})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: MiscColors.ink,
                ),
              ),
            ),
            const SizedBox(width: 6),
            TextButton.icon(
              onPressed: onAddTap,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
              label: const Text('انتخاب', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (ids.isEmpty)
          Text(
            emptyHint,
            style: const TextStyle(fontSize: 11.5, color: MiscColors.inkFaint),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in ids)
                Chip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: tone.withValues(alpha: 0.1),
                  side: BorderSide(color: tone.withValues(alpha: 0.25)),
                  label: Text(
                    nameResolver(id),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: tone,
                    ),
                  ),
                  deleteIconColor: tone,
                  onDeleted: () => onRemove(id),
                ),
            ],
          ),
      ],
    ),
  );
}

class _DraftItemTile extends StatelessWidget {
  const _DraftItemTile({
    required this.index,
    required this.item,
    required this.nameResolver,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final _DraftItem item;
  final String Function(int?) nameResolver;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: MiscColors.teal.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          Fa.digits(index),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: MiscColors.teal,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.description,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MiscColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                if ((item.responsibleUserId ?? 0) > 0)
                  Text(
                    'مسئول: ${nameResolver(item.responsibleUserId)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: MiscColors.inkSoft,
                    ),
                  ),
                if (item.dueDate != null)
                  Text(
                    'مهلت: ${formatJalaliDate(item.dueDate)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: MiscColors.inkSoft,
                    ),
                  ),
                if ((item.followUpUserId ?? 0) > 0)
                  Text(
                    'پیگیری: ${nameResolver(item.followUpUserId)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: MiscColors.inkSoft,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: onEdit,
        icon: const Icon(Icons.edit_outlined, size: 18),
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: onDelete,
        color: MiscColors.danger,
        icon: const Icon(Icons.delete_outline_rounded, size: 18),
      ),
    ],
  );
}
