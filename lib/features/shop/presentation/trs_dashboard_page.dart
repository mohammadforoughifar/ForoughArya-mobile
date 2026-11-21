// ============================================================
//  داشبورد خزانه‌داری و نقدینگی (فاز ۳)
//  آینهٔ صفحهٔ وب: /trs/dashboard → Pages/Treasury/TrsDashboardPage.razor
//
//  • شاخص کل نقدینگی (صندوق + بانک) و تفکیک موجودی نقد و بانک
//  • گردش ورودی/خروجی دوره انتخابی + هشدار اسناد پیش‌نویس
//  • خلاصه چک‌های دریافتی/پرداختی باز و چک‌های سررسید گذشته
//  • فهرست حساب‌های خزانه با مانده لحظه‌ای و پرش مستقیم به گردش حساب
//  • چک‌های در آستانه سررسید + میانبر ثبت دریافت/پرداخت/انتقال وجه
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/shop_perms.dart';
import '../data/shop_repository.dart';
import '../models/treasury_models.dart';
import 'shop_style.dart';
import 'trs_accounts_page.dart';
import 'trs_cheques_page.dart';
import 'trs_flow_page.dart';
import 'trs_voucher_form_page.dart';
import 'trs_vouchers_page.dart';

class TrsDashboardPage extends StatefulWidget {
  const TrsDashboardPage({super.key});

  @override
  State<TrsDashboardPage> createState() => _TrsDashboardPageState();
}

class _TrsDashboardPageState extends State<TrsDashboardPage> {
  late final ShopRepository _repo;
  late final ShopPerms _perms;

  TreasuryDashboard? _data;
  bool _loading = true;
  String? _error;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _repo = ShopRepository(context.read<ApiClient>());
    _perms = ShopPerms(context.read<AuthController>().session);
    final range = currentMonthRange();
    _from = range.from;
    _to = range.to;
    _load();
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _repo.treasuryDashboard(from: _from, to: _to);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _clean(e);
        _loading = false;
      });
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final p = await showJalaliDatePicker(
      context,
      initial: (isFrom ? _from : _to) ?? DateTime.now(),
      title: isFrom ? 'از تاریخ' : 'تا تاریخ',
    );
    if (p == null) return;
    setState(() {
      if (isFrom) {
        _from = p;
      } else {
        _to = p;
      }
    });
    _load();
  }

  Future<void> _openNewVoucher(int kind) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TrsVoucherFormPage(kind: kind)),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      backgroundColor: ShopColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ShopHeader(
                title: 'داشبورد خزانه و نقدینگی',
                subtitle:
                    'مانده صندوق‌ها و بانک‌ها، جریان نقدی دوره و چک‌های سررسید نزدیک',
                icon: Icons.account_balance_wallet_rounded,
                badge: jalaliRangeLabel(_from, _to),
                actions: [
                  if (_perms.canManageSettlement) ...[
                    ShopHeaderButton(
                      label: 'دریافت جدید',
                      icon: Icons.south_west_rounded,
                      filled: true,
                      onTap: () => _openNewVoucher(TrsKind.receipt),
                    ),
                    const SizedBox(width: 8),
                    ShopHeaderButton(
                      label: 'پرداخت جدید',
                      icon: Icons.north_east_rounded,
                      onTap: () => _openNewVoucher(TrsKind.payment),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ShopHeaderButton(
                    label: 'بازخوانی',
                    icon: Icons.refresh_rounded,
                    onTap: _load,
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(isFrom: true),
                        icon: const Icon(Icons.event_rounded, size: 16),
                        label: Text(
                          'از: ${_from == null ? 'ابتدا' : jalaliShort(_from!)}',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(isFrom: false),
                        icon: const Icon(Icons.event_rounded, size: 16),
                        label: Text(
                          'تا: ${_to == null ? 'امروز' : jalaliShort(_to!)}',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ShopEmpty(
                    icon: Icons.error_outline_rounded,
                    title: _error!,
                    actionLabel: 'تلاش دوباره',
                    onAction: _load,
                  ),
                ),
              )
            else if (d != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                sliver: SliverList.list(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ShopKpi(
                            title: 'کل نقدینگی خزانه',
                            value: money(d.totalBalance),
                            unit: 'ریال',
                            icon: Icons.savings_rounded,
                            color: ShopColors.seed,
                            footer: '${numFa(d.accounts.length)} حساب فعال',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ShopKpi(
                            title: 'موجودی بانک‌ها و کارتخوان',
                            value: money(d.totalBankBalance),
                            unit: 'ریال',
                            icon: Icons.account_balance_rounded,
                            color: ShopColors.indigo,
                            footer: 'صندوق نقد: ${money(d.totalCashBalance)}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ShopKpi(
                            title: 'دریافتی قطعی دوره',
                            value: money(d.periodIn),
                            unit: 'ریال',
                            icon: Icons.trending_up_rounded,
                            color: ShopColors.ok,
                            footer: '${numFa(d.receiptCount)} سند دریافت',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ShopKpi(
                            title: 'پرداختی قطعی دوره',
                            value: money(d.periodOut),
                            unit: 'ریال',
                            icon: Icons.trending_down_rounded,
                            color: ShopColors.danger,
                            footer: '${numFa(d.paymentCount)} سند پرداخت',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ShopKpi(
                            title: 'چک‌های دریافتی باز',
                            value: money(d.receivedChequeTotal),
                            unit: 'ریال',
                            icon: Icons.call_received_rounded,
                            color: ShopColors.teal,
                            footer: '${numFa(d.receivedChequeCount)} فقره',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ShopKpi(
                            title: 'چک‌های پرداختی باز',
                            value: money(d.issuedChequeTotal),
                            unit: 'ریال',
                            icon: Icons.call_made_rounded,
                            color: ShopColors.warn,
                            footer: '${numFa(d.issuedChequeCount)} فقره',
                          ),
                        ),
                      ],
                    ),
                    if (d.draftCount > 0 || d.overdueChequeCount > 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ShopColors.warn.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: ShopColors.warn.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (d.draftCount > 0)
                              InkWell(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const TrsVouchersPage(),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.pending_actions_rounded,
                                      size: 18,
                                      color: ShopColors.warn,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${numFa(d.draftCount)} سند پیش‌نویس منتظر قطعی‌شدن در اسناد خزانه وجود دارد.',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: ShopColors.ink,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.chevron_left_rounded),
                                  ],
                                ),
                              ),
                            if (d.draftCount > 0 && d.overdueChequeCount > 0)
                              const Divider(height: 14),
                            if (d.overdueChequeCount > 0)
                              InkWell(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const TrsChequesPage(),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.notification_important_rounded,
                                      size: 18,
                                      color: ShopColors.danger,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${numFa(d.overdueChequeCount)} چک سررسید گذشته به مبلغ ${money(d.overdueChequeTotal)} ریال نیازمند تعیین تکلیف است.',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: ShopColors.danger,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.chevron_left_rounded),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _sectionCard(
                      title: 'مانده لحظه‌ای صندوق‌ها و بانک‌ها',
                      icon: Icons.account_balance_rounded,
                      trailing: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const TrsAccountsPage(),
                          ),
                        ),
                        child: const Text('مدیریت حساب‌ها'),
                      ),
                      children: [
                        if (d.accounts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'هنوز صندوق یا بانکی ثبت نشده است.',
                              style: TextStyle(color: ShopColors.inkFaint),
                            ),
                          )
                        else
                          for (final a in d.accounts)
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              dense: true,
                              leading: CircleAvatar(
                                radius: 17,
                                backgroundColor: ShopColors.seed.withValues(
                                  alpha: 0.1,
                                ),
                                child: Icon(
                                  a.kind == 0
                                      ? Icons.point_of_sale_rounded
                                      : Icons.account_balance_rounded,
                                  size: 17,
                                  color: ShopColors.seed,
                                ),
                              ),
                              title: Text(
                                a.displayName,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                '${a.kindTitle} · ${numFa(a.moveCount)} گردش',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: ShopColors.inkFaint,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${money(a.balance)} ریال',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                      color: a.balance < 0
                                          ? ShopColors.danger
                                          : ShopColors.ink,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.chevron_left_rounded,
                                    size: 18,
                                    color: ShopColors.inkFaint,
                                  ),
                                ],
                              ),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => TrsFlowPage(account: a),
                                ),
                              ),
                            ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _sectionCard(
                      title: 'چک‌های در آستانه سررسید',
                      icon: Icons.event_note_rounded,
                      trailing: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const TrsChequesPage(),
                          ),
                        ),
                        child: const Text('همه چک‌ها'),
                      ),
                      children: [
                        if (d.upcomingCheques.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'چک سررسید نزدیکی وجود ندارد.',
                              style: TextStyle(color: ShopColors.inkFaint),
                            ),
                          )
                        else
                          for (final c in d.upcomingCheques)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  ShopPill(
                                    text: c.kind == ChequeKind.received
                                        ? 'دریافتی'
                                        : 'پرداختی',
                                    color: c.kind == ChequeKind.received
                                        ? ShopColors.ok
                                        : ShopColors.warn,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${Fa.digits(c.number)} · ${c.partyName ?? '—'}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (c.dueDate != null)
                                          Text(
                                            'سررسید: ${jalaliShort(c.dueDate!)}',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              color: ShopColors.inkFaint,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${money(c.amount)} ریال',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: ShopColors.seed),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.ink,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const Divider(height: 12),
          ...children,
        ],
      ),
    );
  }
}
