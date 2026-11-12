import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/html_text.dart';
import '../../../core/utils/jalali_picker.dart';
import '../../../core/widgets/common.dart';
import '../data/work_order_repository.dart';
import '../models/work_order.dart';
import 'wo_style.dart';
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
  late final _scrollCtrl = ScrollController();

  /// ایندکس تب جاری — برای همگام‌سازی تب کشویی با TabBarView
  int _tabIndex = 0;

  WorkOrder? _order;
  List<dynamic> _checklist = [], _comments = [], _attachments = [], _logs = [];
  bool _loading = true, _busy = false;
  String? _error;
  final _comment = TextEditingController();
  int? _replyTo;
  final _checklistText = TextEditingController();

  WorkOrderRepository get repo => context.read<WorkOrderRepository>();

  /// دسترسی از سرور (`my-access`)؛ شناسهٔ نشست فقط پشتیبان است.
  WoAccess _access = const WoAccess.empty();

  int get _sessionUserId =>
      context.read<AuthController>().session?.userId ?? 0;

  int get myId => _access.userId > 0 ? _access.userId : _sessionUserId;

  /// آیا من دستوردهندهٔ این دستور کار هستم؟ (شرط بستن/تمدید/بازگشایی)
  bool get isOwner {
    final o = _order;
    if (o == null || o.ownerUserId <= 0) return false;
    final me = myId;
    return me > 0 && o.ownerUserId == me;
  }

  @override
  void initState() {
    super.initState();
    // هر تغییر تب (سوایپ یا لمس تب کشویی) را به UI اطلاع می‌دهد
    _tabs.addListener(() {
      if (_tabs.index != _tabIndex && mounted) {
        setState(() => _tabIndex = _tabs.index);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _scrollCtrl.dispose();
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
      // دسترسی از سرور؛ بدون آن «دستوردهنده» بودن قابل تشخیص نیست.
      final access = await repo.myAccess();
      if (mounted) setState(() => _access = access);
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

  @override
  Widget build(BuildContext context) {
    final o = _order;
    final canEdit =
        o != null &&
        isOwner &&
        o.isOpen &&
        o.assignees.every((a) => a.seenAt == null && a.repliedAt == null);
    final canReply =
        o != null && o.isOpen && o.assignees.any((a) => a.userId == myId);

    return Scaffold(
      backgroundColor: WoColors.bg,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: WoColors.deep,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 4,
        title: Text(
          o?.number ?? 'جزئیات دستور کار',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: 'ویرایش',
              onPressed: _edit,
              icon: const Icon(Icons.edit_outlined),
            ),
          if (o != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
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
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'assignees',
                    child: ListTile(
                      leading: Icon(Icons.group_add_outlined),
                      title: Text('افزودن گیرنده'),
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'close',
                    child: ListTile(
                      leading: Icon(Icons.lock_outline),
                      title: Text('بستن نهایی'),
                      dense: true,
                    ),
                  ),
                ],
                if (isOwner && !o.isOpen)
                  const PopupMenuItem(
                    value: 'reopen',
                    child: ListTile(
                      leading: Icon(Icons.lock_open_outlined),
                      title: Text('بازگشایی'),
                      dense: true,
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text('حذف'),
                    dense: true,
                  ),
                ),
              ],
            ),
        ],
        bottom: o == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(58),
                child: Container(
                  color: WoColors.deep,
                  padding: const EdgeInsets.only(bottom: 6),
                  child: SlidingTabs(
                    height: 54,
                    pillColor: Colors.white,
                    items: const [
                      (label: 'جزئیات', icon: Icons.info_outline, key: 'd'),
                      (label: 'چک‌لیست', icon: Icons.checklist_rtl, key: 'c'),
                      (label: 'گفتگو', icon: Icons.forum_outlined, key: 'm'),
                      (label: 'پیوست', icon: Icons.attach_file, key: 'a'),
                      (label: 'تاریخچه', icon: Icons.history, key: 'l'),
                    ],
                    index: _indexForTab(),
                    showCounts: true,
                    counts: {
                      'c': _checklist.length,
                      'm': _comments.length,
                      'a': _attachments.length,
                      'l': _logs.length,
                    },
                    onChanged: (i) {
                      setState(() => _tabIndex = i);
                      _tabs.animateTo(i);
                    },
                  ),
                ),
              ),
      ),
      body: _loading
          ? const ShimmerList(count: 4)
          : _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : Column(
              children: [
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
                if (canReply)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueGrey.withValues(alpha: .10),
                          blurRadius: 16,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        child: SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: WoColors.seed,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _busy ? null : _reply,
                            icon: const Icon(Icons.reply, size: 19),
                            label: const Text('ثبت پاسخ من'),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  int _indexForTab() => _tabIndex;

  // ============================================================
  //  تب جزئیات — چیدمان کارت‌محور با هدر گرادیانی
  // ============================================================

  Widget _overview() {
    final o = _order!;
    final progress = o.checklistTotal == 0
        ? 0.0
        : o.checklistDone / o.checklistTotal;

    return RefreshIndicator(
      color: WoColors.seed,
      onRefresh: _load,
      child: ListView(
        controller: _scrollCtrl,
        padding: EdgeInsets.zero,
        children: [
          DetailHero(
            order: o,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _heroBadge(
                      !o.isOpen
                          ? 'بسته'
                          : o.isOverdue
                          ? 'دیرکرد'
                          : 'در جریان',
                      !o.isOpen
                          ? Colors.white24
                          : o.isOverdue
                          ? WoColors.overdue
                          : WoColors.open,
                      icon: !o.isOpen
                          ? Icons.lock_outline
                          : o.isOverdue
                          ? Icons.warning_amber_rounded
                          : Icons.play_circle_outline,
                    ),
                    const SizedBox(width: 6),
                    _heroBadge(
                      Fa.priority(o.priority),
                      Colors.white24,
                      icon: Icons.flag_outlined,
                    ),
                    if (o.recurrence > 0) ...[
                      const SizedBox(width: 6),
                      _heroBadge(
                        Fa.recurrence(o.recurrence),
                        Colors.white24,
                        icon: Icons.repeat,
                      ),
                    ],
                    const Spacer(),
                    _heroBadge(
                      Fa.digits(o.number),
                      Colors.white24,
                      icon: Icons.tag,
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Text(
                  o.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.45,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Colors.white.withValues(alpha: .8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      o.ownerName,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: .9),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Icon(
                      Icons.event_outlined,
                      size: 14,
                      color: Colors.white.withValues(alpha: .8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      Fa.date(o.dueAt, time: false),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: o.isOverdue
                            ? const Color(0xffffd7d7)
                            : Colors.white.withValues(alpha: .9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
            child: Column(
              children: [
                // ---------- خلاصهٔ آماری ----------
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: WoColors.line),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      RingStat(
                        value: progress,
                        label: 'چک‌لیست',
                        color: WoColors.open,
                      ),
                      _statDivider(),
                      _miniStat(
                        Icons.people_outline,
                        o.assignees.length,
                        'گیرنده',
                      ),
                      _statDivider(),
                      _miniStat(
                        Icons.chat_bubble_outline,
                        o.commentCount,
                        'گفتگو',
                      ),
                      _statDivider(),
                      _miniStat(
                        Icons.attach_file,
                        o.attachmentCount,
                        'پیوست',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ---------- شرح دستور ----------
                GlassCard(
                  title: 'شرح دستور کار',
                  icon: Icons.article_outlined,
                  children: [
                    SelectableText(
                      o.description.isEmpty
                          ? 'شرحی برای این دستور کار ثبت نشده است.'
                          : o.description,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.95,
                        color: o.description.isEmpty
                            ? Colors.blueGrey.shade400
                            : null,
                      ),
                    ),
                  ],
                ),

                // ---------- مشخصات ----------
                GlassCard(
                  title: 'مشخصات',
                  icon: Icons.badge_outlined,
                  children: [
                    InfoTile(
                      icon: Icons.person_outline,
                      label: 'دستوردهنده',
                      value: o.ownerName,
                    ),
                    InfoTile(
                      icon: Icons.event_outlined,
                      label: 'مهلت انجام',
                      value: Fa.date(o.dueAt),
                      color: o.isOverdue ? WoColors.overdue : null,
                    ),
                    InfoTile(
                      icon: Icons.add_box_outlined,
                      label: 'تاریخ ثبت',
                      value: Fa.date(o.createdAt),
                    ),
                    if (o.extensionCount > 0)
                      InfoTile(
                        icon: Icons.more_time,
                        label: 'تعداد تمدید',
                        value: '${Fa.digits(o.extensionCount)} بار',
                        color: WoColors.urgent,
                      ),
                    if (o.projectName != null)
                      InfoTile(
                        icon: Icons.account_tree_outlined,
                        label: 'پروژه',
                        value: '${o.projectCode ?? ''} ${o.projectName}'.trim(),
                      ),
                    if (o.parentOrderId != null)
                      InfoTile(
                        icon: Icons.subdirectory_arrow_left,
                        label: 'دستور مادر',
                        value: '#${Fa.digits(o.parentOrderId!)}',
                      ),
                    if (o.closeNote?.isNotEmpty == true)
                      InfoTile(
                        icon: Icons.lock_outline,
                        label: 'یادداشت بستن',
                        value: o.closeNote!,
                        color: WoColors.closed,
                      ),
                  ],
                ),

                // ---------- عملیات دستوردهنده (مطابق وب) ----------
                if (isOwner && o.isOpen)
                  GlassCard(
                    title: 'عملیات دستوردهنده',
                    icon: Icons.admin_panel_settings_outlined,
                    color: Colors.deepPurple,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy || o.extensionCount >= 5
                                  ? null
                                  : _extend,
                              icon: const Icon(Icons.more_time, size: 16),
                              label: Text(
                                o.extensionCount >= 5
                                    ? 'تمدید مهلت (سقف ۵ بار)'
                                    : 'تمدید مهلت (${Fa.digits(o.extensionCount)} از ۵)',
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 40),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _busy ? null : _close,
                              icon: const Icon(Icons.lock_outline, size: 16),
                              label: const Text(
                                'بستن دستور کار',
                                style: TextStyle(fontSize: 11.5),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                minimumSize: const Size(0, 40),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'بستن نهایی فقط توسط دستوردهنده انجام می‌شود و پس از آن پاسخ‌دهی و '
                        'گفت‌وگو قفل می‌شود. اگر زیر-دستورِ باز وجود داشته باشد، ابتدا آن‌ها '
                        'باید بسته شوند.',
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.85,
                          color: Colors.blueGrey.shade400,
                        ),
                      ),
                    ],
                  ),

                // ---------- بسته‌شده + بازگشایی ----------
                if (!o.isOpen && isOwner)
                  GlassCard(
                    title: 'این دستور کار بسته شده است',
                    icon: Icons.lock_outline,
                    color: Colors.green.shade700,
                    children: [
                      if (o.closeNote?.isNotEmpty == true)
                        Text(
                          'یادداشت بستن: ${o.closeNote}',
                          style: const TextStyle(fontSize: 11.5, height: 1.85),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _reopen,
                          icon: const Icon(Icons.lock_open_outlined, size: 16),
                          label: const Text(
                            'بازگشایی و برگشت به گردش',
                            style: TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ),
                    ],
                  ),

                // ---------- برچسب‌ها ----------
                if (o.tags.isNotEmpty)
                  GlassCard(
                    title: 'برچسب‌ها',
                    icon: Icons.sell_outlined,
                    color: WoColors.accent,
                    children: [
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: o.tags
                            .map(
                              (t) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: WoColors.accent.withValues(alpha: .08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: WoColors.accent.withValues(alpha: .2),
                                  ),
                                ),
                                child: Text(
                                  '#$t',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: WoColors.accent,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),

                // ---------- گیرندگان ----------
                GlassCard(
                  title: 'گیرندگان (${Fa.digits(o.assignees.length)})',
                  icon: Icons.people_alt_outlined,
                  children: [
                    if (o.assignees.isEmpty)
                      Text(
                        'گیرینده‌ای ثبت نشده است.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.blueGrey.shade400,
                        ),
                      )
                    else
                      ...o.assignees.map((a) => _assigneeTile(a, o)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() => Container(
    width: 1,
    height: 34,
    color: WoColors.line,
  );

  Widget _miniStat(IconData icon, int value, String label) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: WoColors.seed.withValues(alpha: .08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 17, color: WoColors.seed),
      ),
      const SizedBox(height: 5),
      Text(
        Fa.digits(value),
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
      ),
      Text(
        label,
        style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade500),
      ),
    ],
  );

  Widget _heroBadge(String text, Color color, {IconData? icon}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: Colors.white.withValues(alpha: .28)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 3),
        ],
        Text(
          text,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );

  /// کارت گیرنده با وضعیت رنگی و دکمه‌های تأیید/رد
  Widget _assigneeTile(Assignee a, WorkOrder o) {
    final (statusColor, statusLabel, statusIcon) = switch (a) {
      Assignee(ownerDecision: 'Approved') => (
        WoColors.open,
        'تأیید شده',
        Icons.verified_outlined,
      ),
      Assignee(ownerDecision: 'Rejected') => (
        WoColors.overdue,
        'رد شده',
        Icons.cancel_outlined,
      ),
      Assignee(done: true) => (
        WoColors.open,
        'انجام شد',
        Icons.check_circle_outline,
      ),
      Assignee(done: false) => (
        WoColors.overdue,
        'انجام نشد',
        Icons.highlight_off,
      ),
      Assignee(seenAt: != null) => (
        const Color(0xff2a6bd4),
        'رویت شده',
        Icons.visibility_outlined,
      ),
      _ => (WoColors.urgent, 'در انتظار رویت', Icons.hourglass_empty),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: WoColors.gradientFor(o),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  a.name.isEmpty ? '؟' : a.name.characters.first,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  a.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 3),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (a.replyText?.isNotEmpty == true)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 9),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: WoColors.bg,
                borderRadius: BorderRadius.circular(10),
                border: const Border(
                  right: BorderSide(color: WoColors.seed, width: 3),
                ),
              ),
              child: SelectableText(
                a.replyText!,
                style: const TextStyle(fontSize: 12, height: 1.7),
              ),
            ),
          if (a.repliedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 12,
                    color: Colors.blueGrey.shade400,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'پاسخ: ${Fa.date(a.repliedAt)}',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.blueGrey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          if (a.ownerDecisionNote?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                'یادداشت شما: ${a.ownerDecisionNote}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blueGrey.shade600,
                ),
              ),
            ),
          if (isOwner && o.isOpen && a.repliedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: WoColors.overdue,
                        side: BorderSide(
                          color: WoColors.overdue.withValues(alpha: .4),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _decide(a, false),
                      icon: const Icon(Icons.close, size: 15),
                      label: const Text(
                        'رد',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: WoColors.open,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _decide(a, true),
                      icon: const Icon(Icons.check, size: 15),
                      label: const Text(
                        'تأیید',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
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
    // تقویم شمسی
    final d = await showJalaliDatePicker(
      context,
      initial: initial,
      title: 'انتخاب تاریخ (شمسی)',
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

  /// بستن نهایی — فقط دستوردهنده (سرور: `wo.OwnerUserId != MyUserId → 403`).
  /// دکمهٔ تایید همیشه فعال است تا «یادداشت خالی» با «انصراف» قاطی نشود
  /// (قبلاً با promptText، یادداشت خالی دکمهٔ تایید را غیرفعال می‌کرد).
  Future<void> _close() async {
    final o = _order;
    if (o == null) return;
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('بستن نهایی دستور کار'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '«${o.number} — ${o.title}» نهایی و بسته شود؟',
              style: const TextStyle(fontSize: 12.5, height: 1.8),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: note,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'یادداشت بستن (اختیاری)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'پس از بستن، پاسخ‌دهی و گفت‌وگو قفل می‌شود و همهٔ گیرندگان اعلان می‌گیرند. '
              'اگر زیر-دستور باز وجود داشته باشد، سرور اجازهٔ بستن نمی‌دهد.',
              style: TextStyle(fontSize: 10.5, height: 1.85, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('بستن دستور کار'),
          ),
        ],
      ),
    );
    final text = note.text.trim();
    note.dispose();
    if (ok == true) {
      await _run(() => repo.close(widget.id, text), 'دستور کار بسته شد.');
    }
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

  Widget _checklistTab() {
    final o = _order!;
    final done = _checklist
        .where((e) => e is Map && e['isDone'] == true)
        .length;
    final progress = _checklist.isEmpty ? 0.0 : done / _checklist.length;

    return Column(
      children: [
        if (_checklist.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: WoColors.line),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.checklist_rtl, size: 16, color: WoColors.open),
                      const SizedBox(width: 6),
                      const Text(
                        'پیشرفت کار',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        '${Fa.digits(done)} از ${Fa.digits(_checklist.length)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: WoColors.open,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 850),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => LinearProgressIndicator(
                        value: v,
                        minHeight: 8,
                        backgroundColor: WoColors.line,
                        valueColor: AlwaysStoppedAnimation(
                          progress >= 1 ? WoColors.open : WoColors.seed,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (o.isOpen)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _checklistText,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'زیرکار جدید…',
                      hintStyle: TextStyle(
                        fontSize: 12.5,
                        color: Colors.blueGrey.shade300,
                      ),
                      isDense: true,
                      suffixIcon: const Icon(Icons.playlist_add, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 46,
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: WoColors.seed,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    onPressed: () {
                      if (_checklistText.text.trim().isNotEmpty) {
                        final t = _checklistText.text.trim();
                        _checklistText.clear();
                        _run(() => repo.addChecklist(widget.id, t));
                      }
                    },
                    child: const Icon(Icons.add),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _checklist.isEmpty
              ? const EmptyView(
                  message: 'زیرکاری ثبت نشده است.',
                  icon: Icons.checklist_rtl,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    itemCount: _checklist.length,
                    itemBuilder: (_, i) {
                      final c = Map<String, dynamic>.from(_checklist[i] as Map);
                      final id = (c['id'] as num).toInt();
                      final checked = c['isDone'] == true;
                      return FadeSlideIn(
                        index: i,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: checked
                                ? WoColors.open.withValues(alpha: .05)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: checked
                                  ? WoColors.open.withValues(alpha: .25)
                                  : WoColors.line,
                            ),
                          ),
                          child: Row(
                            children: [
                              Transform.scale(
                                scale: .92,
                                child: Checkbox(
                                  value: checked,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  onChanged: o.isOpen
                                      ? (_) => _run(
                                          () => repo.toggleChecklist(
                                            widget.id,
                                            id,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  htmlToText(c['text']?.toString()),
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.6,
                                    decoration: checked
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: checked
                                        ? Colors.blueGrey.shade400
                                        : null,
                                  ),
                                ),
                              ),
                              if (o.isOpen)
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Colors.red.shade300,
                                  ),
                                  onPressed: () => _run(
                                    () => repo.deleteChecklist(widget.id, id),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
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
              ? const EmptyView(
                  message: 'گفتگویی ثبت نشده است.',
                  icon: Icons.forum_outlined,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                  itemCount: _comments.length,
                  itemBuilder: (_, i) {
                    final c = Map<String, dynamic>.from(_comments[i] as Map);
                    final mine = (c['authorUserId'] as num?)?.toInt() == myId;
                    final deleted = c['isDeleted'] == true;
                    return FadeSlideIn(
                      index: i,
                      child: Align(
                        alignment: mine
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 340),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
                          decoration: BoxDecoration(
                            gradient: mine
                                ? LinearGradient(
                                    colors: [
                                      WoColors.seed.withValues(alpha: .10),
                                      WoColors.seed.withValues(alpha: .04),
                                    ],
                                  )
                                : null,
                            color: mine ? null : Colors.white,
                            borderRadius: BorderRadius.only(
                              topRight: const Radius.circular(16),
                              topLeft: const Radius.circular(16),
                              bottomLeft: Radius.circular(mine ? 16 : 4),
                              bottomRight: Radius.circular(mine ? 4 : 16),
                            ),
                            border: Border.all(
                              color: mine
                                  ? WoColors.seed.withValues(alpha: .18)
                                  : WoColors.line,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 11,
                                    backgroundColor: mine
                                        ? WoColors.seed
                                        : Colors.blueGrey.shade300,
                                    child: Text(
                                      (c['authorName']?.toString() ?? '؟')
                                          .characters
                                          .first,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    c['authorName']?.toString() ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              SelectableText(
                                deleted
                                    ? 'این پیام حذف شده است.'
                                    : htmlToText(c['text']?.toString()),
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.75,
                                  fontStyle: deleted ? FontStyle.italic : null,
                                  color: deleted
                                      ? Colors.blueGrey.shade300
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Text(
                                    Fa.date(c['createdAt']?.toString()),
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: Colors.blueGrey.shade400,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (!deleted && o.isOpen)
                                    _commentAction(
                                      Icons.reply,
                                      'پاسخ',
                                      () => setState(
                                        () => _replyTo =
                                            (c['id'] as num).toInt(),
                                      ),
                                    ),
                                  if (!deleted && o.isOpen && mine)
                                    _commentAction(
                                      Icons.edit_outlined,
                                      'ویرایش',
                                      () async {
                                        final t = await promptText(
                                          context,
                                          'ویرایش پیام',
                                          initial: htmlToTextOrNull(
                                            c['text']?.toString(),
                                          ),
                                        );
                                        if (t != null && t.isNotEmpty) {
                                          _run(
                                            () => repo.editComment(
                                              (c['id'] as num).toInt(),
                                              t,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  if (!deleted && (mine || isOwner))
                                    _commentAction(
                                      Icons.delete_outline,
                                      'حذف',
                                      () => _run(
                                        () => repo.deleteComment(
                                          (c['id'] as num).toInt(),
                                        ),
                                      ),
                                      color: Colors.red.shade300,
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
        if (_replyTo != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: InputChip(
                label: Text(
                  'در حال پاسخ به پیام ${Fa.digits(_replyTo!)}',
                  style: const TextStyle(fontSize: 11),
                ),
                onDeleted: () => setState(() => _replyTo = null),
              ),
            ),
          ),
        if (o.isOpen)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: WoColors.line),
                      ),
                      child: TextField(
                        controller: _comment,
                        minLines: 1,
                        maxLines: 4,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'نوشتن پیام…',
                          hintStyle: TextStyle(
                            fontSize: 12.5,
                            color: Colors.blueGrey.shade300,
                          ),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: WoColors.seed,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
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
                      child: const Icon(Icons.send, size: 19),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _commentAction(
    IconData icon,
    String tooltip,
    VoidCallback onTap, {
    Color? color,
  }) => IconButton(
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
    padding: EdgeInsets.zero,
    tooltip: tooltip,
    onPressed: onTap,
    icon: Icon(
      icon,
      size: 15,
      color: color ?? Colors.blueGrey.shade400,
    ),
  );

  Widget _attachmentsTab() => Column(
    children: [
      if (_order!.isOpen)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: _uploadButton(
                  Icons.attach_file,
                  'انتخاب فایل',
                  () => _upload(),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _uploadButton(
                  Icons.camera_alt_outlined,
                  'دوربین',
                  () => _upload(camera: true),
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
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
                  itemCount: _attachments.length,
                  itemBuilder: (_, i) {
                    final a = Map<String, dynamic>.from(
                      _attachments[i] as Map,
                    );
                    return FadeSlideIn(
                      index: i,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 9),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: WoColors.line),
                        ),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          onTap: () => _download(a),
                          leading: Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: WoColors.seed.withValues(alpha: .09),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(
                              Icons.insert_drive_file_outlined,
                              size: 19,
                              color: WoColors.seed,
                            ),
                          ),
                          title: Text(
                            a['fileName']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${a['uploaderName'] ?? ''} • ${Fa.bytes((a['size'] as num?)?.toInt() ?? 0)}'
                            '\n${Fa.date(a['uploadedAt']?.toString())}',
                            style: const TextStyle(fontSize: 10.5),
                          ),
                          isThreeLine: true,
                          trailing: const Icon(
                            Icons.download_rounded,
                            size: 20,
                            color: WoColors.seed,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    ],
  );

  Widget _uploadButton(IconData icon, String label, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: WoColors.seed.withValues(alpha: .3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: WoColors.seed),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: WoColors.seed,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _logsTab() => _logs.isEmpty
      ? const EmptyView(
          message: 'سابقه‌ای ثبت نشده است.',
          icon: Icons.history,
        )
      : RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
            itemCount: _logs.length,
            itemBuilder: (_, i) {
              final l = _logs[i] as Map;
              final last = i == _logs.length - 1;
              return FadeSlideIn(
                index: i,
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: WoColors.seed.withValues(alpha: .1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.history,
                              size: 13,
                              color: WoColors.seed,
                            ),
                          ),
                          if (!last)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: WoColors.line,
                                margin: const EdgeInsets.symmetric(vertical: 3),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          margin: EdgeInsets.only(bottom: last ? 0 : 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: WoColors.line),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                htmlToText(
                                  l['text']?.toString() ??
                                      l['action']?.toString(),
                                ),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.6,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 11,
                                    color: Colors.blueGrey.shade400,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    l['actorName']?.toString() ?? '',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.blueGrey.shade500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    Fa.date(l['createdAt']?.toString()),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blueGrey.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              );
            },
          ),
        );
}
