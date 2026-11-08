import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/fa.dart';
import '../../../core/widgets/common.dart';
import '../data/work_order_repository.dart';

class WorkOrderStatsView extends StatefulWidget {
  const WorkOrderStatsView({super.key});
  @override
  State<WorkOrderStatsView> createState() => _WorkOrderStatsViewState();
}

class _WorkOrderStatsViewState extends State<WorkOrderStatsView>
    with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  @override
  bool get wantKeepAlive => true;
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
      final d = await context.read<WorkOrderRepository>().stats();
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
    super.build(context);
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    final cards = Map<String, dynamic>.from(_data!['cards'] as Map? ?? {});
    final status = Map<String, dynamic>.from(_data!['byStatus'] as Map? ?? {});
    final people = _data!['perAssignee'] as List? ?? [];
    final months = _data!['months'] as List? ?? [];
    final metrics = [
      ('کل دستورها', 'total', Icons.work_outline, Colors.indigo),
      ('باز', 'open', Icons.play_circle_outline, Colors.blue),
      ('دیرکرد', 'overdue', Icons.alarm, Colors.red),
      ('مهلت امروز', 'dueToday', Icons.today_outlined, Colors.orange),
      ('به‌موقع', 'doneOnTime', Icons.check_circle_outline, Colors.green),
      ('با تأخیر', 'doneLate', Icons.history, Colors.deepOrange),
      ('در انتظار پاسخ', 'pendingReply', Icons.hourglass_empty, Colors.purple),
      ('بستهٔ بی‌نتیجه', 'closedNoDone', Icons.lock_outline, Colors.blueGrey),
    ];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.65,
            mainAxisSpacing: 9,
            crossAxisSpacing: 9,
            children: metrics
                .map(
                  (m) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(m.$3, color: m.$4),
                          Text(
                            Fa.digits(cards[m.$2] ?? 0),
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: m.$4,
                            ),
                          ),
                          Text(m.$1, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          const Text(
            'توزیع وضعیت',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 10),
          ...[
            ('باز', 'open', Colors.blue),
            ('باز دیرکرد', 'overdueOpen', Colors.red),
            ('انجام به‌موقع', 'onTime', Colors.green),
            ('انجام با تأخیر', 'lateDone', Colors.orange),
            ('بستهٔ بی‌نتیجه', 'closedNoDone', Colors.blueGrey),
          ].map(
            (x) => _ProgressRow(
              label: x.$1,
              value: (status[x.$2] as num?)?.toInt() ?? 0,
              total: (cards['total'] as num?)?.toInt() ?? 0,
              color: x.$3,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'عملکرد گیرندگان',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          if (people.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('داده‌ای وجود ندارد.'),
            ),
          ...people.whereType<Map>().map(
            (p) => Card(
              margin: const EdgeInsets.only(top: 8),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(p['name'].toString().characters.first),
                ),
                title: Text(p['name'].toString()),
                subtitle: Text(
                  'کل ${Fa.digits(p['total'])} • انجام ${Fa.digits(p['done'])} • به‌موقع ${Fa.digits(p['onTime'])} • در انتظار ${Fa.digits(p['pending'])}',
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'روند شش ماه اخیر',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          ...months.whereType<Map>().map(
            (m) => ListTile(
              dense: true,
              title: Text('${Fa.digits(m['year'])}/${Fa.digits(m['month'])}'),
              subtitle: Text(
                'ایجاد ${Fa.digits(m['created'])} • باز ${Fa.digits(m['open'])} • به‌موقع ${Fa.digits(m['onTime'])} • تأخیر ${Fa.digits(m['late'])}',
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });
  final String label;
  final int value, total;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              Fa.digits(value),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: total == 0 ? 0 : value / total,
          color: color,
          minHeight: 8,
          borderRadius: BorderRadius.circular(5),
        ),
      ],
    ),
  );
}

class WorkOrderPerformanceView extends StatefulWidget {
  const WorkOrderPerformanceView({super.key});
  @override
  State<WorkOrderPerformanceView> createState() =>
      _WorkOrderPerformanceViewState();
}

class _WorkOrderPerformanceViewState extends State<WorkOrderPerformanceView>
    with AutomaticKeepAliveClientMixin {
  int _days = 30;
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];
  @override
  bool get wantKeepAlive => true;
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
      final d = await context.read<WorkOrderRepository>().performance(_days);
      if (mounted)
        setState(() {
          _items = d;
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

  Future<void> _export(String format) async {
    try {
      final f = await context.read<WorkOrderRepository>().exportPerformance(
        format,
        _days,
      );
      await SharePlus.instance.share(
        ShareParams(files: [XFile(f.path)], text: 'گزارش عملکرد دستور کار'),
      );
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
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _days,
                  decoration: const InputDecoration(labelText: 'بازهٔ گزارش'),
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('۷ روز اخیر')),
                    DropdownMenuItem(value: 30, child: Text('۳۰ روز اخیر')),
                    DropdownMenuItem(value: 90, child: Text('۹۰ روز اخیر')),
                    DropdownMenuItem(value: 365, child: Text('یک سال اخیر')),
                    DropdownMenuItem(value: 0, child: Text('همه')),
                  ],
                  onChanged: (v) {
                    _days = v ?? 30;
                    _load();
                  },
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.download_outlined),
                onSelected: _export,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'xlsx', child: Text('خروجی Excel')),
                  PopupMenuItem(value: 'pdf', child: Text('خروجی PDF')),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const LoadingView()
              : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _items.isEmpty
              ? const EmptyView()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final p = _items[i] as Map;
                      final percent =
                          (p['onTimePercent'] as num?)?.toInt() ?? 0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 9),
                        child: Padding(
                          padding: const EdgeInsets.all(13),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.indigo.shade50,
                                    child: Text(Fa.digits(p['rank'])),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      p['name'].toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${Fa.digits(percent)}٪ به‌موقع',
                                    style: TextStyle(
                                      color: percent >= 80
                                          ? Colors.green
                                          : Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: percent / 100,
                                minHeight: 7,
                              ),
                              const SizedBox(height: 9),
                              Wrap(
                                spacing: 15,
                                runSpacing: 6,
                                children: [
                                  Text('کل ${Fa.digits(p['total'])}'),
                                  Text('انجام ${Fa.digits(p['done'])}'),
                                  Text('با تأخیر ${Fa.digits(p['doneLate'])}'),
                                  Text('انجام‌نشده ${Fa.digits(p['notDone'])}'),
                                  Text('در انتظار ${Fa.digits(p['pending'])}'),
                                  Text(
                                    'میانگین تأخیر ${Fa.digits(p['avgDelayHours'])} ساعت',
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
        ),
      ],
    );
  }
}
