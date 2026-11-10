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
import 'wo_style.dart';
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

  /// شمارندهٔ سبک برای بج تب‌ها (تعداد دستورهای باز)
  Map<String, dynamic> _counts = {};

  static const _views = <({String label, IconData icon, String key})>[
    (label: 'دستورهای من', icon: Icons.outbox_outlined, key: 'mine'),
    (label: 'محول به من', icon: Icons.inbox_outlined, key: 'assigned'),
    (label: 'بایگانی', icon: Icons.archive_outlined, key: 'archive'),
    (label: 'کانبان', icon: Icons.view_kanban_outlined, key: 'kanban'),
    (label: 'تقویم', icon: Icons.calendar_month_outlined, key: 'calendar'),
    (label: 'آمار', icon: Icons.insights_outlined, key: 'stats'),
    (label: 'عملکرد', icon: Icons.leaderboard_outlined, key: 'performance'),
  ];

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final c = await context.read<WorkOrderRepository>().counts();
      if (mounted) setState(() => _counts = c);
    } catch (_) {
      // سرورهای قدیمی بدون این مسیر کار می‌کنند
    }
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

  Future<void> _newOrder() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const WorkOrderEditorPage()),
    );
    if (result == true) {
      setState(() => _version++);
      _loadCounts();
    }
  }

  Future<void> _account() async {
    final auth = context.read<AuthController>();
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: WoColors.seed.withValues(alpha: .12),
                child: Text(
                  auth.session!.displayName.characters.first,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: WoColors.seed,
                  ),
                ),
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
                style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500),
              ),
              const SizedBox(height: 18),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(Icons.password),
                title: const Text('تغییر رمز عبور'),
                onTap: () {
                  Navigator.pop(c);
                  _changePassword();
                },
              ),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
  Widget build(BuildContext context) {
    final companyName = _companies
        .whereType<Map>()
        .firstWhere(
          (c) => (c['id'] as num?)?.toInt() == _companyId,
          orElse: () => const {},
        )['name']
        ?.toString();

    return Scaffold(
      backgroundColor: WoColors.bg,
      appBar: AppBar(
        backgroundColor: WoColors.bg,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: WoColors.heroGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.assignment_outlined,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'دستور کار',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                  if (companyName != null && companyName.isNotEmpty)
                    Text(
                      companyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w400,
                        color: Colors.blueGrey.shade500,
                      ),
                    ),
                ],
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
            onPressed: () {
              setState(() => _version++);
              _loadCounts();
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'حساب کاربری',
            onPressed: _account,
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: SlidingTabs(
            items: _views,
            index: _view,
            showCounts: true,
            counts: {
              'mine': (Fa.digitInt(_counts['mine']) ??
                  Fa.digitInt(_counts['open']) ??
                  0),
              'assigned': Fa.digitInt(_counts['assigned']) ?? 0,
              'archive': Fa.digitInt(_counts['archive']) ?? 0,
            },
            onChanged: (i) => setState(() => _view = i),
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
        backgroundColor: WoColors.seed,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('دستور جدید'),
      ),
    );
  }
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
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => WorkOrderDetailPage(id: o.id)),
    );
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
        _searchRow(),
        _filterRow(),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          child: _selected.isEmpty
              ? const SizedBox(width: double.infinity)
              : _bulkBar(),
        ),
        Expanded(
          child: _loading
              ? const ShimmerList()
              : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _data!.items.isEmpty
              ? const EmptyView(message: 'دستور کاری برای نمایش نیست.')
              : RefreshIndicator(
                  color: WoColors.seed,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 92),
                    itemCount: _data!.items.length + 1,
                    itemBuilder: (_, i) {
                      if (i == _data!.items.length) return _pager();
                      final o = _data!.items[i];
                      return GlowWorkOrderCard(
                        order: o,
                        index: i,
                        selected: _selected.contains(o.id),
                        onSelect: (v) => setState(
                          () => v ? _selected.add(o.id) : _selected.remove(o.id),
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

  Widget _searchRow() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
    child: Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: WoColors.line),
            ),
            child: TextField(
              controller: _search,
              style: const TextStyle(fontSize: 13),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 450), () {
                  _page = 1;
                  _load();
                });
              },
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: Colors.blueGrey.shade400,
                ),
                hintText: 'شماره، عنوان، شخص یا برچسب',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: Colors.blueGrey.shade300,
                ),
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ),
        const SizedBox(width: 7),
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
  );

  Widget _filterRow() => SizedBox(
    height: 40,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        _filterPill(
          label: _priority == null
              ? 'همه اولویت‌ها'
              : Fa.priority(_priority!),
          icon: Icons.flag_outlined,
          active: _priority != null,
          onTap: () => _pickPriority(),
        ),
        ...['approved', 'rejected', 'undecided', 'awaiting'].map(
          (d) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _filterPill(
              label: switch (d) {
                'approved' => 'تأییدشده',
                'rejected' => 'ردشده',
                'undecided' => 'بی‌تصمیم',
                _ => 'در انتظار پاسخ',
              },
              icon: Icons.rule,
              active: _decision == d,
              onTap: () {
                setState(() {
                  _decision = _decision == d ? null : d;
                  _page = 1;
                });
                _load();
              },
            ),
          ),
        ),
      ],
    ),
  );

  void _pickPriority() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            for (final e in <int?>[null, 0, 1, 2, 3])
              ListTile(
                leading: Icon(
                  e == null ? Icons.clear_all : Icons.flag_outlined,
                  color: e == 3
                      ? WoColors.urgent
                      : e == null
                      ? Colors.blueGrey
                      : WoColors.seed,
                ),
                title: Text(e == null ? 'همه اولویت‌ها' : Fa.priority(e)),
                trailing: _priority == e
                    ? const Icon(Icons.check, color: WoColors.seed)
                    : null,
                onTap: () {
                  Navigator.pop(c);
                  setState(() {
                    _priority = e;
                    _page = 1;
                  });
                  _load();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _filterPill({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? WoColors.seed : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? WoColors.seed : WoColors.line,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: active ? Colors.white : Colors.blueGrey.shade400,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? Colors.white : Colors.blueGrey.shade700,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _bulkBar() => Container(
    margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: WoColors.seed.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: WoColors.seed.withValues(alpha: .2)),
    ),
    child: Row(
      children: [
        Icon(Icons.check_circle, size: 17, color: WoColors.seed),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            '${Fa.digits(_selected.length)} مورد انتخاب شد',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        if (widget.tab != 'archive')
          TextButton(
            onPressed: () => _bulk('archive'),
            child: const Text('بایگانی', style: TextStyle(fontSize: 12)),
          ),
        TextButton(
          onPressed: () => _bulk('delete'),
          child: const Text(
            'حذف',
            style: TextStyle(fontSize: 12, color: Colors.red),
          ),
        ),
      ],
    ),
  );

  Widget _pager() => Padding(
    padding: const EdgeInsets.fromLTRB(0, 10, 0, 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _pagerButton(
          icon: Icons.chevron_right,
          enabled: _page > 1,
          onTap: () {
            _page--;
            _load();
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              Text(
                'صفحه ${Fa.digits(_page)} از ${Fa.digits(_data!.pages)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              Text(
                '${Fa.digits(_data!.totalCount)} مورد',
                style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.blueGrey.shade500,
                ),
              ),
            ],
          ),
        ),
        _pagerButton(
          icon: Icons.chevron_left,
          enabled: _page < _data!.pages,
          onTap: () {
            _page++;
            _load();
          },
        ),
      ],
    ),
  );

  Widget _pagerButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.white.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WoColors.line),
      ),
      child: Icon(
        icon,
        size: 20,
        color: enabled ? WoColors.seed : Colors.blueGrey.shade200,
      ),
    ),
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
            ? const ShimmerList()
            : _error != null
            ? ErrorView(message: _error!, onRetry: _load)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 85),
                  children: [0, 1, 2, 3].map((p) {
                    final items = _items.where((o) => o.priority == p).toList();
                    final color = switch (p) {
                      3 => WoColors.urgent,
                      2 => WoColors.seed,
                      0 => WoColors.open,
                      _ => const Color(0xff55637a),
                    };
                    return Container(
                      width: 310,
                      margin: const EdgeInsets.only(left: 10),
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .05),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: color.withValues(alpha: .12)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  Fa.priority(p),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: .12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    Fa.digits(items.length),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: items.isEmpty
                                ? Center(
                                    child: Text(
                                      'خالی',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blueGrey.shade300,
                                      ),
                                    ),
                                  )
                                : ListView(
                                    children: items
                                        .map(
                                          (o) => GlowWorkOrderCard(
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
                                          ),
                                        )
                                        .toList(),
                                  ),
                          ),
                          if (_scope == 'mine')
                            Align(
                              alignment: Alignment.centerLeft,
                              child: PopupMenuButton<int>(
                                icon: const Icon(Icons.more_horiz, size: 18),
                                tooltip: 'تغییر اولویت',
                                onSelected: (v) => _setPriority(
                                  items.isNotEmpty ? items.first : _items.first,
                                  v,
                                ),
                                itemBuilder: (_) => [0, 1, 2, 3]
                                    .map(
                                      (v) => PopupMenuItem(
                                        value: v,
                                        child: Text(Fa.priority(v)),
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
    return _loading
        ? const ShimmerList()
        : _error != null
        ? ErrorView(message: _error!, onRetry: _load)
        : WorkOrderCalendarBody(
            month: _month,
            data: _data!,
            onPrev: () {
              setState(() => _month = DateTime(_month.year, _month.month - 1));
              _load();
            },
            onNext: () {
              setState(() => _month = DateTime(_month.year, _month.month + 1));
              _load();
            },
            onOpen: (o) async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkOrderDetailPage(id: o.id),
                ),
              );
              _load();
            },
          );
  }
}

/// بدنهٔ تقویم دستور کار — گروه‌بندی بر اساس روز، با استایل جدید
class WorkOrderCalendarBody extends StatelessWidget {
  const WorkOrderCalendarBody({
    super.key,
    required this.month,
    required this.data,
    required this.onPrev,
    required this.onNext,
    required this.onOpen,
  });

  final DateTime month;
  final WorkOrderPageData data;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final void Function(WorkOrder) onOpen;

  @override
  Widget build(BuildContext context) {
    final items = data.items;
    final groups = <String, List<WorkOrder>>{};
    for (final o in items) {
      final d = DateTime.tryParse(o.dueAt ?? '')?.toLocal();
      final key = d == null ? 'بدون تاریخ' : '${d.year}-${d.month}-${d.day}';
      groups.putIfAbsent(key, () => []).add(o);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: WoColors.line),
            ),
            child: Row(
              children: [
                _monthButton(Icons.chevron_right, onPrev),
                Expanded(
                  child: Text(
                    Fa.date(month.toIso8601String(), time: false).substring(0, 8),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _monthButton(Icons.chevron_left, onNext),
              ],
            ),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const EmptyView(message: 'در این ماه دستور کاری وجود ندارد.')
              : RefreshIndicator(
                  onRefresh: () async {},
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 104),
                    children: groups.entries.map((g) {
                      final first = g.value.first;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 15,
                                  decoration: BoxDecoration(
                                    color: WoColors.seed,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  Fa.date(first.dueAt, time: false),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    color: WoColors.seed,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: WoColors.seed.withValues(alpha: .1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    Fa.digits(g.value.length),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: WoColors.seed,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...g.value.asMap().entries.map(
                            (e) => GlowWorkOrderCard(
                              order: e.value,
                              index: e.key,
                              onTap: () => onOpen(e.value),
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

  Widget _monthButton(IconData icon, VoidCallback onTap) => IconButton(
    onPressed: onTap,
    icon: Icon(icon, size: 20),
    style: IconButton.styleFrom(
      backgroundColor: WoColors.bg,
      foregroundColor: WoColors.seed,
    ),
  );
}
