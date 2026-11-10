// ============================================================
//  گردش صندوق/بانک
//  آینهٔ صفحهٔ وب: /trs/reports/flow?accountId=…
//                 → Pages/Treasury/TrsFlow.razor
//
//  • انتخاب بازهٔ شمسی + پاک کردن فیلتر
//  • کارت‌های مانده ابتدای بازه، جمع وارده، جمع صادره، مانده پایان بازه
//  • جدول گردش با مانده تجمعی هر سطر
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/shop_repository.dart';
import '../models/treasury_models.dart';
import 'shop_style.dart';

class TrsFlowPage extends StatefulWidget {
  const TrsFlowPage({super.key, required this.account});

  final TreasuryAccount account;

  @override
  State<TrsFlowPage> createState() => _TrsFlowPageState();
}

class _TrsFlowPageState extends State<TrsFlowPage> {
  late final ShopRepository _repo;

  FlowResult? _result;
  bool _loading = true;
  String? _error;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _repo.treasuryFlow(
        trsAccountId: widget.account.id,
        from: _from,
        to: _to,
      );
      if (!mounted) return;
      setState(() {
        _result = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e
            .toString()
            .replaceFirst('ApiException: ', '')
            .replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _pick(bool isFrom) async {
    final picked = await showJalaliDatePicker(
      context,
      initial: isFrom ? _from : _to,
      title: isFrom ? 'از تاریخ' : 'تا تاریخ',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: Text(
          'گردش ${widget.account.name}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
          children: [
            Row(
              children: [
                Expanded(
                  child: _dateBox(
                    'از تاریخ',
                    _from,
                    () => _pick(true),
                    () {
                      setState(() => _from = null);
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _dateBox(
                    'تا تاریخ',
                    _to,
                    () => _pick(false),
                    () {
                      setState(() => _to = null);
                      _load();
                    },
                  ),
                ),
                if (_from != null || _to != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _from = null;
                        _to = null;
                      });
                      _load();
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: ShopColors.line),
                      minimumSize: const Size(42, 42),
                    ),
                    icon: const Icon(
                      Icons.filter_alt_off_rounded,
                      size: 17,
                      color: ShopColors.inkSoft,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              ShopEmpty(
                title: 'دریافت گردش ناموفق بود',
                subtitle: _error,
                icon: Icons.error_outline_rounded,
              )
            else if (_result != null) ...[
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2.0,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: [
                  ShopKpi(
                    title: 'مانده ابتدای بازه',
                    value: Fa.number(_result!.openingBalance),
                    unit: 'ریال',
                    icon: Icons.play_circle_outline_rounded,
                    color: ShopColors.inkSoft,
                  ),
                  ShopKpi(
                    title: 'جمع وارده',
                    value: Fa.number(_result!.totalIn),
                    unit: 'ریال',
                    icon: Icons.south_west_rounded,
                    color: ShopColors.ok,
                  ),
                  ShopKpi(
                    title: 'جمع صادره',
                    value: Fa.number(_result!.totalOut),
                    unit: 'ریال',
                    icon: Icons.north_east_rounded,
                    color: ShopColors.danger,
                  ),
                  ShopKpi(
                    title: 'مانده پایان بازه',
                    value: Fa.number(_result!.closingBalance),
                    unit: 'ریال',
                    icon: Icons.account_balance_wallet_rounded,
                    color: ShopColors.seed,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_result!.rows.isEmpty)
                const ShopEmpty(
                  title: 'گردشی در این بازه ثبت نشده است',
                  icon: Icons.inbox_rounded,
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: ShopColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ShopColors.line),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < _result!.rows.length; i++)
                        _row(_result!.rows[i], i),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(FlowRow r, int index) {
    final isIn = r.inAmount > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: index == 0
            ? null
            : const Border(top: BorderSide(color: ShopColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: (isIn ? ShopColors.ok : ShopColors.danger).withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  isIn ? Icons.south_west_rounded : Icons.north_east_rounded,
                  size: 15,
                  color: isIn ? ShopColors.ok : ShopColors.danger,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${TrsKind.title(r.kind)} شماره ${Fa.number(r.number)} · ${r.method}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      [
                        if (r.date != null) jalaliShort(r.date!),
                        if ((r.partyName ?? '').isNotEmpty) r.partyName!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Fa.number(isIn ? r.inAmount : r.out),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isIn ? ShopColors.ok : ShopColors.danger,
                    ),
                  ),
                  Text(
                    'مانده ${Fa.number(r.balance)}',
                    style: const TextStyle(
                      fontSize: 9,
                      color: ShopColors.inkFaint,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if ((r.description ?? '').isNotEmpty ||
              (r.refNumber ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 38),
              child: Text(
                [
                  if ((r.description ?? '').isNotEmpty) r.description!,
                  if ((r.refNumber ?? '').isNotEmpty) 'عطف: ${r.refNumber}',
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9.5,
                  color: ShopColors.inkFaint,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dateBox(
    String label,
    DateTime? value,
    VoidCallback onTap,
    VoidCallback onClear,
  ) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ShopColors.line),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_month_rounded,
            size: 15,
            color: ShopColors.inkFaint,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value == null ? label : jalaliShort(value),
              style: TextStyle(
                fontSize: 11.5,
                color: value == null ? ShopColors.inkFaint : ShopColors.ink,
              ),
            ),
          ),
          if (value != null)
            InkWell(
              onTap: onClear,
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: ShopColors.inkFaint,
              ),
            ),
        ],
      ),
    ),
  );
}
