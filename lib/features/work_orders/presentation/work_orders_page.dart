import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/widgets/common.dart';
import '../data/work_order_repository.dart';
import '../models/work_order.dart';
import 'work_order_detail_page.dart';
import 'work_order_editor_page.dart';
import 'work_order_reports.dart';

class WorkOrdersPage extends StatefulWidget {
  const WorkOrdersPage({super.key});
  @override
  State<WorkOrdersPage> createState() => _WorkOrdersPageState();
}

class _WorkOrdersPageState extends State<WorkOrdersPage> {
  int _view = 0, _version = 0;
  int? _companyId;
  List<dynamic> _companies = [];

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    final api = context.read<ApiClient>();
    try {
      final r = await api.get('/api/company-context');
      final data = Map<String, dynamic>.from(r.data as Map);
      _companies = data['companies'] as List? ?? [];
      _companyId = (data['activeCompanyId'] as num?)?.toInt();
      if (_companyId != null) {
        await api.setCompanyId(_companyId!);
      }
      if (mounted) setState(() {});
    } catch (_) {
      // Legacy single-company servers work without the company-context endpoint.
    }
  }

  static const _views = [
    ('دستورهای من', Icons.outbox_outlined),
    ('محول به من', Icons.inbox_outlined),
    ('بایگانی', Icons.archive_outlined),
    ('کانبان', Icons.view_kanban_outlined),
    ('تقویم', Icons.calendar_month_outlined),
    ('آمار', Icons.insights_outlined),
    ('عملکرد', Icons.leaderboard_outlined),
  ];

  Future<void> _newOrder() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const WorkOrderEditorPage()),
    );
    if (result == true) setState(() => _version++);
  }

  Future<void> _account() async {
    final auth = context.read<AuthController>();
    await showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 30,
                child: Text(auth.session!.displayName.characters.first),
              ),
              const SizedBox(height: 10),
              Text(
                auth.session!.displayName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${auth.session!.username} • ${auth.session!.roleNames.join('، ')}',
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: const Icon(Icons.password),
                title: const Text('تغییر رمز عبور'),
                onTap: () {
                  Navigator.pop(c);
                  _changePassword();
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('خروج از حساب'),
                onTap: () {
                  Navigator.pop(c);
                  auth.logout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changePassword() async {
    final current = TextEditingController(),
        replacement = TextEditingController();
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تغییر رمز عبور'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'رمز فعلی'),
                validator: (v) =>
                    v?.isEmpty == true ? 'رمز فعلی را وارد کنید.' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: replacement,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'رمز جدید'),
                validator: (v) => (v?.length ?? 0) < 6
                    ? 'رمز جدید حداقل ۶ کاراکتر باشد.'
                    : null,
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
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(c, true);
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await context.read<AuthController>().changePassword(
          current.text,
          replacement.text,
        );
        if (mounted) showMessage(context, 'رمز عبور تغییر کرد.');
      } catch (e) {
        if (mounted) showMessage(context, e.toString(), error: true);
      }
    }
    current.dispose();
    replacement.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'دستور کار',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          if (_companyId != null && _companies.isNotEmpty)
            Text(
              _companies
                      .whereType<Map>()
                      .firstWhere(
                        (c) => (c['id'] as num?)?.toInt() == _companyId,
                        orElse: () => const {},
                      )['name']
                      ?.toString() ??
                  '',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
      actions: [
        if (_companies.length > 1)
          PopupMenuButton<int>(
            tooltip: 'شرکت فعال',
            icon: const Icon(Icons.business_outlined),
            onSelected: (id) async {
              await context.read<ApiClient>().setCompanyId(id);
              setState(() {
                _companyId = id;
                _version++;
              });
            },
            itemBuilder: (_) => _companies
                .whereType<Map>()
                .map(
                  (c) => PopupMenuItem(
                    value: (c['id'] as num).toInt(),
                    child: Row(
                      children: [
                        if ((c['id'] as num).toInt() == _companyId)
                          const Icon(Icons.check, size: 18)
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 7),
                        Text(c['name']?.toString() ?? ''),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        IconButton(
          tooltip: 'به‌روزرسانی',
          onPressed: () => setState(() => _version++),
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: 'حساب کاربری',
          onPressed: _account,
          icon: const Icon(Icons.account_circle_outlined),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(55),
        child: SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _views.length,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (_, i) => ChoiceChip(
              selected: _view == i,
              avatar: Icon(_views[i].$2, size: 17),
              label: Text(_views[i].$1),
              onSelected: (_) => setState(() => _view = i),
            ),
          ),
        ),
      ),
    ),
    body: IndexedStack(
      index: _view,
      children: [
        WorkOrderListView(key: ValueKey('mine-$_version'), tab: 'mine'),
        WorkOrderListView(key: ValueKey('assigned-$_version'), tab: 'assigned'),
        WorkOrderListView(key: ValueKey('archive-$_version'), tab: 'archive'),
        WorkOrderKanbanView(key: ValueKey('kanban-$_version')),
        WorkOrderCalendarView(key: ValueKey('calendar-$_version')),
        WorkOrderStatsView(key: ValueKey('stats-$_version')),
        WorkOrderPerformanceView(key: ValueKey('performance-$_version')),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _newOrder,
      icon: const Icon(Icons.add),
      label: const Text('دستور جدید'),
    ),
  );
}

class WorkOrderListView extends StatefulWidget {
  const WorkOrderListView({super.key, required this.tab});
  final String tab;
  @override
  State<WorkOrderListView> createState() => _WorkOrderListViewState();
}

class _WorkOrderListViewState extends State<WorkOrderListView>
    with AutomaticKeepAliveClientMixin {
  WorkOrderPageData? _data;
  bool _loading = true, _exporting = false;
  String? _error;
  int _page = 1;
  int? _priority;
  String? _decision;
  final _search = TextEditingController();
  Timer? _debounce;
  final Set<int> _selected = {};
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await context.read<WorkOrderRepository>().list(
        widget.tab,
        page: _page,
        q: _search.text,
        priority: _priority,
        decision: _decision,
      );
      if (mounted)
        setState(() {
          _data = d;
          _loading = false;
          _selected.clear();
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  Future<void> _open(WorkOrder o) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => WorkOrderDetailPage(id: o.id)),
    );
    if (result == true)
      _load();
    else
      _load();
  }

  Future<void> _export(String format) async {
    setState(() => _exporting = true);
    try {
      final f = await context.read<WorkOrderRepository>().exportList(
        format,
        widget.tab,
        q: _search.text,
        priority: _priority,
      );
      await SharePlus.instance.share(
        ShareParams(files: [XFile(f.path)], text: 'گزارش دستور کار'),
      );
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _bulk(String action) async {
    try {
      await context.read<WorkOrderRepository>().bulk(
        _selected.toList(),
        action,
      );
      if (mounted) showMessage(context, 'عملیات گروهی انجام شد.');
      _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 5),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 450), () {
                      _page = 1;
                      _load();
                    });
                  },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'شماره، عنوان، شخص یا برچسب',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              PopupMenuButton<String>(
                tooltip: 'خروجی',
                icon: _exporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                onSelected: _export,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'xlsx', child: Text('خروجی Excel')),
                  PopupMenuItem(value: 'pdf', child: Text('خروجی PDF')),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 43,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 7),
                child: DropdownButton<int?>(
                  value: _priority,
                  hint: const Text('همه اولویت‌ها'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('همه اولویت‌ها')),
                    DropdownMenuItem(value: 0, child: Text('کم')),
                    DropdownMenuItem(value: 1, child: Text('عادی')),
                    DropdownMenuItem(value: 2, child: Text('بالا')),
                    DropdownMenuItem(value: 3, child: Text('فوری')),
                  ],
                  onChanged: (v) {
                    _priority = v;
                    _page = 1;
                    _load();
                  },
                ),
              ),
              ...['approved', 'rejected', 'undecided', 'awaiting'].map(
                (d) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: FilterChip(
                    selected: _decision == d,
                    label: Text(switch (d) {
                      'approved' => 'تأییدشده',
                      'rejected' => 'ردشده',
                      'undecided' => 'بی‌تصمیم',
                      _ => 'در انتظار پاسخ',
                    }),
                    onSelected: (v) {
                      _decision = v ? d : null;
                      _page = 1;
                      _load();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_selected.isNotEmpty)
          Material(
            color: Colors.indigo.shade50,
            child: ListTile(
              title: Text('${Fa.digits(_selected.length)} مورد انتخاب شده'),
              trailing: OverflowBar(
                children: [
                  if (widget.tab != 'archive')
                    TextButton(
                      onPressed: () => _bulk('archive'),
                      child: const Text('بایگانی'),
                    ),
                  TextButton(
                    onPressed: () => _bulk('delete'),
                    child: const Text(
                      'حذف',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: _loading
              ? const LoadingView()
              : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _data!.items.isEmpty
              ? const EmptyView()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 7, 12, 85),
                    itemCount: _data!.items.length + 1,
                    itemBuilder: (_, i) {
                      if (i == _data!.items.length) return _pager();
                      final o = _data!.items[i];
                      return WorkOrderCard(
                        order: o,
                        selected: _selected.contains(o.id),
                        onSelect: (v) => setState(
                          () =>
                              v ? _selected.add(o.id) : _selected.remove(o.id),
                        ),
                        onTap: () => _open(o),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _pager() => Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.outlined(
          onPressed: _page > 1
              ? () {
                  _page--;
                  _load();
                }
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'صفحه ${Fa.digits(_page)} از ${Fa.digits(_data!.pages)} • ${Fa.digits(_data!.totalCount)} مورد',
          ),
        ),
        IconButton.outlined(
          onPressed: _page < _data!.pages
              ? () {
                  _page++;
                  _load();
                }
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
      ],
    ),
  );
}

class WorkOrderCard extends StatelessWidget {
  const WorkOrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.selected = false,
    this.onSelect,
    this.trailing,
  });
  final WorkOrder order;
  final VoidCallback onTap;
  final bool selected;
  final ValueChanged<bool>? onSelect;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final color = !order.isOpen
        ? Colors.blueGrey
        : order.isOverdue
        ? Colors.red
        : order.priority == 3
        ? Colors.deepOrange
        : Colors.indigo;
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? Colors.indigo : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onLongPress: onSelect == null ? null : () => onSelect!(!selected),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (onSelect != null)
                    SizedBox(
                      width: 26,
                      child: Checkbox(
                        value: selected,
                        onChanged: (v) => onSelect!(v ?? false),
                      ),
                    ),
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    margin: const EdgeInsets.only(left: 9),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.number,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blueGrey.shade500,
                          ),
                        ),
                        Text(
                          order.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _miniChip(
                    order.isOpen
                        ? order.isOverdue
                              ? 'دیرکرد'
                              : 'باز'
                        : 'بسته',
                    color,
                  ),
                  _miniChip(Fa.priority(order.priority), color),
                  if (order.recurrence > 0)
                    _miniChip(Fa.recurrence(order.recurrence), Colors.teal),
                  ...order.tags
                      .take(3)
                      .map((t) => _miniChip('#$t', Colors.blueGrey)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.event, size: 16, color: Colors.blueGrey),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      Fa.date(order.dueAt),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    order.ownerName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (order.checklistTotal > 0) ...[
                    const Icon(
                      Icons.checklist,
                      size: 17,
                      color: Colors.blueGrey,
                    ),
                    Text(
                      ' ${Fa.digits(order.checklistDone)}/${Fa.digits(order.checklistTotal)}',
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (order.commentCount > 0) ...[
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 16,
                      color: Colors.blueGrey,
                    ),
                    Text(' ${Fa.digits(order.commentCount)}'),
                    const SizedBox(width: 12),
                  ],
                  if (order.attachmentCount > 0) ...[
                    const Icon(
                      Icons.attach_file,
                      size: 17,
                      color: Colors.blueGrey,
                    ),
                    Text(' ${Fa.digits(order.attachmentCount)}'),
                    const SizedBox(width: 12),
                  ],
                  const Spacer(),
                  const Icon(
                    Icons.people_outline,
                    size: 17,
                    color: Colors.blueGrey,
                  ),
                  Text(' ${Fa.digits(order.assignees.length)}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text, style: TextStyle(fontSize: 11, color: color)),
  );
}

class WorkOrderKanbanView extends StatefulWidget {
  const WorkOrderKanbanView({super.key});
  @override
  State<WorkOrderKanbanView> createState() => _WorkOrderKanbanViewState();
}

class _WorkOrderKanbanViewState extends State<WorkOrderKanbanView> {
  String _scope = 'mine';
  List<WorkOrder> _items = [];
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
    try {
      final d = await context.read<WorkOrderRepository>().list(
        _scope,
        pageSize: 100,
      );
      if (mounted)
        setState(() {
          _items = d.items;
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

  Future<void> _setPriority(WorkOrder o, int p) async {
    try {
      await context.read<WorkOrderRepository>().priority(o.id, p);
      _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'mine', label: Text('دستورهای من')),
            ButtonSegment(value: 'assigned', label: Text('محول به من')),
          ],
          selected: {_scope},
          onSelectionChanged: (v) {
            _scope = v.first;
            _load();
          },
        ),
      ),
      Expanded(
        child: _loading
            ? const LoadingView()
            : _error != null
            ? ErrorView(message: _error!, onRetry: _load)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 85),
                  children: [0, 1, 2, 3].map((p) {
                    final items = _items.where((o) => o.priority == p).toList();
                    return Container(
                      width: 310,
                      margin: const EdgeInsets.only(left: 10),
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withValues(alpha: .06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(
                              Fa.priority(p),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: CircleAvatar(
                              radius: 13,
                              child: Text(
                                Fa.digits(items.length),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                          Expanded(
                            child: items.isEmpty
                                ? const EmptyView()
                                : ListView(
                                    children: items
                                        .map(
                                          (o) => WorkOrderCard(
                                            order: o,
                                            onTap: () async {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      WorkOrderDetailPage(
                                                        id: o.id,
                                                      ),
                                                ),
                                              );
                                              _load();
                                            },
                                            trailing: _scope == 'mine'
                                                ? PopupMenuButton<int>(
                                                    onSelected: (v) =>
                                                        _setPriority(o, v),
                                                    itemBuilder: (_) =>
                                                        [0, 1, 2, 3]
                                                            .map(
                                                              (
                                                                v,
                                                              ) => PopupMenuItem(
                                                                value: v,
                                                                child: Text(
                                                                  Fa.priority(
                                                                    v,
                                                                  ),
                                                                ),
                                                              ),
                                                            )
                                                            .toList(),
                                                  )
                                                : null,
                                          ),
                                        )
                                        .toList(),
                                  ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
      ),
    ],
  );
}

class WorkOrderCalendarView extends StatefulWidget {
  const WorkOrderCalendarView({super.key});
  @override
  State<WorkOrderCalendarView> createState() => _WorkOrderCalendarViewState();
}

class _WorkOrderCalendarViewState extends State<WorkOrderCalendarView> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  WorkOrderPageData? _data;
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
    try {
      final d = await context.read<WorkOrderRepository>().calendar(
        _month,
        DateTime(_month.year, _month.month + 1).add(const Duration(days: 1)),
      );
      if (mounted)
        setState(() {
          _data = d;
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
  Widget build(BuildContext context) {
    final items = _data?.items ?? [];
    final groups = <String, List<WorkOrder>>{};
    for (final o in items) {
      final d = DateTime.tryParse(o.dueAt ?? '')?.toLocal();
      final key = d == null ? 'بدون تاریخ' : '${d.year}-${d.month}-${d.day}';
      groups.putIfAbsent(key, () => []).add(o);
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.outlined(
                onPressed: () {
                  _month = DateTime(_month.year, _month.month - 1);
                  _load();
                },
                icon: const Icon(Icons.chevron_right),
              ),
              TextButton(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _month,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) {
                    _month = DateTime(d.year, d.month);
                    _load();
                  }
                },
                child: Text(
                  Fa.date(
                    _month.toIso8601String(),
                    time: false,
                  ).substring(0, 8),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton.outlined(
                onPressed: () {
                  _month = DateTime(_month.year, _month.month + 1);
                  _load();
                },
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const LoadingView()
              : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : items.isEmpty
              ? const EmptyView(message: 'در این ماه دستور کاری وجود ندارد.')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 85),
                    children: groups.entries.map((g) {
                      final first = g.value.first;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              Fa.date(first.dueAt, time: false),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                          ),
                          ...g.value.map(
                            (o) => WorkOrderCard(
                              order: o,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WorkOrderDetailPage(id: o.id),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }
}
