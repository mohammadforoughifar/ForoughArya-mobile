// ============================================================
//  صفحهٔ اصلی ماژول اتوماسیون اداری
//  داشبورد گرادیانی + کارتابل‌های داخلی/صادره/وارده + دبیرخانه + امضا
//  طراحی هم‌زبان با ماژول دستور کار (office_style.dart)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/widgets/common.dart';
import '../../misc/presentation/minutes_list_page.dart';
import '../data/office_repository.dart';
import '../models/letter_models.dart';
import '../models/office_common.dart';
import 'letter_detail_page.dart';
import 'letter_editor_page.dart';
import 'email_page.dart';
import 'letter_mailbox_page.dart';
import 'office_style.dart';

class OfficeAutomationPage extends StatefulWidget {
  const OfficeAutomationPage({super.key});

  @override
  State<OfficeAutomationPage> createState() => _OfficeAutomationPageState();
}

class _OfficeAutomationPageState extends State<OfficeAutomationPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  OfficeAutomationRepository get _repo =>
      context.read<OfficeAutomationRepository>();

  AutomationStats _stats = const AutomationStats();
  bool _statsLoading = true;

  final _scroll = <String, ScrollController>{};
  final _items = <String, List<LetterListItem>>{};
  final _loading = <String, bool>{};
  final _error = <String, String?>{};
  final _page = <String, int>{};
  final _hasMore = <String, bool>{};
  final _search = <String, String>{};

  /// تب جاری برای همگام‌سازی تب کشویی با TabBarView
  int _tabIndex = 0;

  // هر ماژول (داخلی / صادره / وارده) یک تب کامل است و کارتابل‌های خودش را
  // داخل همان صفحه دارد: دریافتی، ارسالی، پیش‌نویس، بایگانی (+ امضا و دبیرخانه برای صادره).
  // دیگر «کارتابل داخلی / صادره / وارده / بایگانی / پیش‌نویس» به‌صورت تب‌های
  // پراکنده و تکراری وجود ندارد.
  static const _tabsDef = [
    (label: 'داشبورد', icon: Icons.dashboard_outlined, key: 'dashboard'),
    (label: 'داخلی', icon: Icons.edit_note, key: 'inner'),
    (label: 'صادره', icon: Icons.north_east, key: 'outgoing'),
    (label: 'وارده', icon: Icons.south_west, key: 'incoming'),
    (label: 'ایمیل سازمانی', icon: Icons.alternate_email, key: 'email_corporate'),
    (label: 'ایمیل شخصی', icon: Icons.person_outline, key: 'email_personal'),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabsDef.length, vsync: this);
    _tabs.addListener(() {
      if (_tabs.index != _tabIndex && mounted) {
        setState(() => _tabIndex = _tabs.index);
      }
      if (_tabs.indexIsChanging) return;
      if (_tabKey(_tabs.index).startsWith('email_')) return;
      _ensureLoaded(_tabKey(_tabs.index));
    });
    _loadStats();
    _ensureLoaded('inner_inbox');
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in _scroll.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _tabKey(int index) => switch (index) {
    1 => 'inner_inbox',
    2 => 'outgoing_inbox',
    3 => 'incoming_inbox',
    4 => 'signing',
    5 => 'dabirkhane',
    8 => 'email_corporate',
    9 => 'email_personal',
    _ => 'inner_inbox',
  };

  /// شمارندهٔ روی هر تب کشویی
  Map<String, int> get _counts => {
    'inner_inbox': _stats.inbox,
    'outgoing_inbox': _stats.sent,
    // شمارندهٔ نامهٔ وارده در آمار سرور موجود نیست → بج نمایش داده نمی‌شود
    'signing': _stats.signingPending,
    'dabirkhane': _stats.dabirkhane,
    'archive': _stats.archive,
    'drafts': _stats.pishnevis,
  };

  Future<void> _loadStats() async {
    if (mounted) setState(() => _statsLoading = true);
    final s = await _repo.dashboardStats();
    if (!mounted) return;
    setState(() {
      _stats = s;
      _statsLoading = false;
    });
  }

  void _ensureLoaded(String key) {
    if (_items.containsKey(key) || _loading[key] == true) return;
    _load(key, reset: true);
  }

  Future<void> _load(String key, {bool reset = false}) async {
    if (_loading[key] == true) return;
    setState(() {
      _loading[key] = true;
      if (reset) {
        _error[key] = null;
        _page[key] = 1;
        _hasMore[key] = true;
        _items[key] = [];
      }
    });
    final page = _page[key] ?? 1;
    final q = _search[key];
    try {
      final Paged<LetterListItem> result = switch (key) {
        'inner_inbox' => await _repo.innerInbox(page: page, search: q),
        'outgoing_inbox' => await _repo.outgoingInbox(page: page, search: q),
        'incoming_inbox' => await _repo.incomingInbox(page: page, search: q),
        'signing' => await _repo.signingInbox(page: page, search: q),
        'dabirkhane' => await _repo.dabirkhane(page: page, search: q),
        _ => await _repo.innerInbox(page: page, search: q),
      };
      if (!mounted) return;
      setState(() {
        _items[key] = [...(_items[key] ?? []), ...result.items];
        _hasMore[key] =
            result.items.length >= (result.pageSize == 0 ? 20 : result.pageSize) &&
            result.items.isNotEmpty;
        _page[key] = page + 1;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error[key] = e.message);
    } catch (e) {
      if (mounted) setState(() => _error[key] = 'خطا در دریافت کارتابل: $e');
    } finally {
      if (mounted) setState(() => _loading[key] = false);
    }
  }

  LetterKind _kindOf(String key) => switch (key) {
    'outgoing_inbox' || 'signing' || 'dabirkhane' => LetterKind.outgoing,
    'incoming_inbox' => LetterKind.incoming,
    _ => LetterKind.inner,
  };

  Future<void> _openDetail(LetterListItem item, String key) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LetterDetailPage(
          kind: _kindOf(key),
          letterId: item.letterId,
          erjaId: item.erjaId,
        ),
      ),
    );
    if (changed == true) {
      setState(() => _items.remove(key));
      _load(key, reset: true);
      _loadStats();
    }
  }

  Future<void> _newLetter(LetterKind kind) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => LetterEditorPage(kind: kind)),
    );
    if (created == true) {
      final key = switch (kind) {
        LetterKind.inner => 'inner_inbox',
        LetterKind.outgoing => 'outgoing_inbox',
        LetterKind.incoming => 'incoming_inbox',
      };
      setState(() => _items.remove(key));
      _load(key, reset: true);
      _loadStats();
    }
  }

  Future<void> _toggleNeshan(String key, LetterListItem item) async {
    try {
      final kind = _kindOf(key);
      if (item.erjaId != null) {
        await _repo.toggleErjaNeshan(kind, item.erjaId!);
      } else if (kind == LetterKind.incoming) {
        await _repo.toggleIncomingNeshan(item.letterId);
      } else {
        await _repo.toggleInnerNeshan(item.letterId);
      }
      setState(() => _items.remove(key));
      _load(key, reset: true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  void _goTab(int i) {
    _tabs.animateTo(i);
    if (_tabKey(i).startsWith('email_')) return;
    _ensureLoaded(_tabKey(i));
  }

  // ============================================================
  //  ساختار صفحه
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final name = auth.session?.displayName ?? '';

    return Scaffold(
      backgroundColor: OfficeColors.bg,
      body: Column(
        children: [
          // ---------- هدر گرادیانی ----------
          Container(
            decoration: BoxDecoration(
              gradient: OfficeColors.heroGradient,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
              boxShadow: [
                BoxShadow(
                  color: OfficeColors.deep.withValues(alpha: .25),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
              child: SafeArea(
                bottom: false,
                child: Stack(
                  children: [
                    Positioned(
                      left: -40,
                      top: -60,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [Colors.white.withValues(alpha: .08), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Colors.white24, Colors.white10],
                                  ),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: const Icon(
                                  Icons.account_balance_outlined,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'اتوماسیون اداری',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      name.isEmpty ? 'فروغ آریا' : name,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: .75),
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _HeaderBtn(
                                icon: Icons.refresh,
                                tooltip: 'به‌روزرسانی',
                                onTap: () {
                                  setState(() => _items.clear());
                                  _loadStats();
                                  if (!_tabKey(_tabs.index).startsWith('email_')) {
                                    _ensureLoaded(_tabKey(_tabs.index));
                                  }
                                },
                              ),
                              _HeaderBtn(
                                icon: Icons.add_circle_outline,
                                tooltip: 'نامهٔ جدید',
                                onTap: () => _newLetterSheet(),
                              ),
                              _HeaderBtn(
                                icon: Icons.account_circle_outlined,
                                tooltip: 'حساب کاربری',
                                onTap: () => _accountSheet(auth),
                              ),
                            ],
                          ),
                        ),
                        OfficeSlidingTabs(
                          items: _tabsDef,
                          index: _tabIndex,
                          onChanged: _goTab,
                          background: Colors.transparent,
                          pillColor: OfficeColors.seed,
                          showCounts: true,
                          counts: _counts,
                          accentFor: (i) => switch (i) {
                            1 => OfficeColors.inner,
                            2 => OfficeColors.outgoing,
                            3 => OfficeColors.incoming,
                            4 => OfficeColors.email,
                            5 => OfficeColors.emailPersonal,
                            _ => OfficeColors.seed,
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ---------- بدنهٔ تب‌ها ----------
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _dashboardTab(),
                const LetterMailboxPage(
                  kind: LetterKind.inner,
                  embedded: true,
                ),
                const LetterMailboxPage(
                  kind: LetterKind.outgoing,
                  embedded: true,
                ),
                const LetterMailboxPage(
                  kind: LetterKind.incoming,
                  embedded: true,
                ),
                const EmailPage(initialScope: EmailScope.corporate, embedded: true),
                const EmailPage(initialScope: EmailScope.personal, embedded: true),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabKey(_tabIndex).startsWith('email_')
          ? null
          : FloatingActionButton.extended(
              heroTag: 'office_new_letter_fab',
              onPressed: () => _newLetter(_kindOf(_tabKey(_tabs.index))),
              backgroundColor: OfficeColors.seed,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('نامهٔ جدید', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
    );
  }

  /// برد سه ماژول نامه؛ داخل هر کارت، چهار کارتابل واقعی همان ماژول
  Widget _buildModuleBoard() {
    return Column(
      children: [
        _ModuleCard(
          title: 'نامهٔ داخلی',
          subtitle: 'ارتباط درون‌سازمانی',
          icon: Icons.edit_note,
          color: OfficeColors.inner,
          boxes: const [
            LetterBox.inbox,
            LetterBox.sent,
            LetterBox.drafts,
            LetterBox.archive,
          ],
          onOpenBox: (b) => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LetterMailboxPage(
                kind: LetterKind.inner,
                initialBox: b,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _ModuleCard(
          title: 'نامهٔ صادره',
          subtitle: 'مکاتبات برون‌سازمانی و امضا',
          icon: Icons.north_east,
          color: OfficeColors.outgoing,
          boxes: const [
            LetterBox.inbox,
            LetterBox.sent,
            LetterBox.signing,
            LetterBox.dabirkhane,
            LetterBox.archive,
          ],
          onOpenBox: (b) => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LetterMailboxPage(
                kind: LetterKind.outgoing,
                initialBox: b,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _ModuleCard(
          title: 'نامهٔ وارده',
          subtitle: 'ثبت و ارجاع نامه‌های رسیده',
          icon: Icons.south_west,
          color: OfficeColors.incoming,
          boxes: const [
            LetterBox.inbox,
            LetterBox.sent,
            LetterBox.drafts,
            LetterBox.archive,
          ],
          onOpenBox: (b) => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LetterMailboxPage(
                kind: LetterKind.incoming,
                initialBox: b,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  //  داشبورد
  // ============================================================

  Widget _dashboardTab() {
    final s = _stats;
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
        children: [
          // --- کارت قهرمان ---
          OFadeSlideIn(
            index: 0,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: OfficeColors.heroGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: OfficeColors.seed.withValues(alpha: .26),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: -30,
                    bottom: -50,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [Colors.white.withValues(alpha: .09), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.mark_email_unread_outlined,
                                size: 15, color: Colors.white.withValues(alpha: .8)),
                            const SizedBox(width: 6),
                            Text(
                              'کارتابل امروز',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .85),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            HeroBadge(
                              label: Fa.date(DateTime.now().toIso8601String(), time: false),
                              icon: Icons.today_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _statsLoading
                              ? 'در حال دریافت…'
                              : '${Fa.digits(s.inboxUnread)} نامهٔ خوانده‌نشده در انتظار شماست',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            height: 1.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            OfficeRing(
                              value: s.inbox == 0
                                  ? 0
                                  : (s.inbox - s.inboxUnread) / s.inbox,
                              label: 'خوانده‌شده',
                              color: Colors.white,
                              size: 58,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Row(
                                children: [
                                  _heroStat('دریافتی', s.inbox),
                                  _heroStat('ارسالی', s.sent),
                                  _heroStat('بایگانی', s.archive),
                                  _heroStat('امضا', s.signingPending),
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
          ),
          const SizedBox(height: 16),

          // --- ماژول‌های نامه: هر ماژول با کارتابل‌های واقعی خودش ---
          const _SectionLabel(title: 'ماژول‌های نامه', icon: Icons.folder_copy_outlined),
          OFadeSlideIn(index: 1, child: _buildModuleBoard()),
          const SizedBox(height: 14),

          // --- دسترسی سریع ---
          const _SectionLabel(title: 'دسترسی سریع', icon: Icons.bolt),
          OFadeSlideIn(
            index: 2,
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: .82,
              children: [
                _QuickTile(
                  label: 'نامهٔ داخلی',
                  icon: Icons.edit_note,
                  color: OfficeColors.inner,
                  onTap: () => _newLetter(LetterKind.inner),
                ),
                _QuickTile(
                  label: 'نامهٔ صادره',
                  icon: Icons.north_east,
                  color: OfficeColors.outgoing,
                  onTap: () => _newLetter(LetterKind.outgoing),
                ),
                _QuickTile(
                  label: 'نامهٔ وارده',
                  icon: Icons.south_west,
                  color: OfficeColors.incoming,
                  onTap: () => _newLetter(LetterKind.incoming),
                ),
                _QuickTile(
                  label: 'صورتجلسه',
                  icon: Icons.description_outlined,
                  color: OfficeColors.minutes,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MinutesListPage(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // --- شمارنده‌ها ---
          const _SectionLabel(title: 'شمارنده‌ها', icon: Icons.insights_outlined),
          OFadeSlideIn(
            index: 2,
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.35,
              mainAxisSpacing: 9,
              crossAxisSpacing: 9,
              children: [
                _StatCard(
                  label: 'دریافتی داخلی',
                  value: s.inbox,
                  sub: '${Fa.digits(s.inboxUnread)} خوانده‌نشده',
                  icon: Icons.inbox_outlined,
                  color: OfficeColors.inner,
                  onTap: () => _goTab(1),
                ),
                _StatCard(
                  label: 'ارسالی',
                  value: s.sent,
                  sub: 'نامهٔ صادره',
                  icon: Icons.outbox_outlined,
                  color: OfficeColors.outgoing,
                  onTap: () => _goTab(2),
                ),
                _StatCard(
                  label: 'نشان‌شده',
                  value: s.neshan,
                  sub: 'ستاره‌دار',
                  icon: Icons.star_outline,
                  color: OfficeColors.gold,
                ),
                _StatCard(
                  label: 'پیش‌نویس',
                  value: s.pishnevis,
                  sub: 'ذخیره‌شده',
                  icon: Icons.drafts_outlined,
                  color: const Color(0xffb04fbf),
                  onTap: () => _goTab(7),
                ),
                _StatCard(
                  label: 'در انتظار امضا',
                  value: s.signingPending,
                  sub: 'نیازمند اقدام',
                  icon: Icons.draw_outlined,
                  color: OfficeColors.signing,
                  onTap: () => _goTab(4),
                ),
                _StatCard(
                  label: 'دبیرخانه',
                  value: s.dabirkhane,
                  sub: 'در صف ارسال',
                  icon: Icons.account_balance_outlined,
                  color: OfficeColors.dabirkhane,
                  onTap: () => _goTab(5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, int value) => Expanded(
    child: Column(
      children: [
        Text(
          Fa.digits(value),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .78),
            fontSize: 10,
          ),
        ),
      ],
    ),
  );

  // ============================================================
  //  کارتابل‌ها
  // ============================================================

  void _newLetterSheet() => showModalBottomSheet(
    context: context,
    backgroundColor: OfficeColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'نامهٔ جدید',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _SheetAction(
              icon: Icons.edit_note,
              color: OfficeColors.inner,
              title: 'نامهٔ داخلی',
              subtitle: 'مکاتبهٔ درون‌سازمانی بین کاربران و گروه‌ها',
              onTap: () {
                Navigator.pop(c);
                _newLetter(LetterKind.inner);
              },
            ),
            _SheetAction(
              icon: Icons.north_east,
              color: OfficeColors.outgoing,
              title: 'نامهٔ صادره',
              subtitle: 'نامهٔ خروجی با شمارهٔ صادره و دبیرخانه',
              onTap: () {
                Navigator.pop(c);
                _newLetter(LetterKind.outgoing);
              },
            ),
            _SheetAction(
              icon: Icons.south_west,
              color: OfficeColors.incoming,
              title: 'نامهٔ وارده',
              subtitle: 'ثبت نامهٔ رسیده از سازمان بیرونی',
              onTap: () {
                Navigator.pop(c);
                _newLetter(LetterKind.incoming);
              },
            ),
          ],
        ),
      ),
    ),
  );

  void _filterSheet(String key, LetterKind kind) => showModalBottomSheet(
    context: context,
    backgroundColor: OfficeColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'مرتب‌سازی و فیلتر',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              'برای اعمال فیلتر، کلمهٔ کلیدی را در نوار جست‌وجو وارد کنید. '
              'فیلترهای پیشرفته (محرمانگی، فوریت، بازهٔ تاریخ) در نسخهٔ بعدی به این شیت اضافه می‌شوند.',
              style: TextStyle(
                fontSize: 12,
                height: 1.85,
                color: Colors.blueGrey.shade600,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(c);
                      setState(() => _search.remove(key));
                      _load(key, reset: true);
                    },
                    icon: const Icon(Icons.refresh, size: 17),
                    label: const Text('بازنشانی'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(c),
                    style: FilledButton.styleFrom(
                      backgroundColor: OfficeColors.forKind(kind),
                    ),
                    child: const Text('بستن'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  void _accountSheet(AuthController auth) {
    final name = auth.session?.displayName ?? '';
    showModalBottomSheet(
      context: context,
      backgroundColor: OfficeColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: OfficeColors.heroGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: OfficeColors.seed.withValues(alpha: .3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  name.isNotEmpty ? name.characters.first : '؟',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                '${auth.session?.username ?? ''} • ${(auth.session?.roleNames ?? []).join('، ')}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: Colors.blueGrey.shade500),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: OfficeColors.line),
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  leading: const Icon(Icons.logout, color: OfficeColors.danger),
                  title: const Text(
                    'خروج از حساب',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(c);
                    auth.logout();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  ویجت‌های کوچک محلی
// ============================================================

class _HeaderBtn extends StatelessWidget {
  const _HeaderBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Icon(icon, size: 21, color: Colors.white.withValues(alpha: .92)),
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
    child: Row(
      children: [
        Icon(icon, size: 15, color: OfficeColors.seed),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _QuickTile extends StatefulWidget {
  const _QuickTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_QuickTile> createState() => _QuickTileState();
}

class _QuickTileState extends State<_QuickTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (d) => setState(() => _pressed = true),
    onTapUp: (d) => setState(() => _pressed = false),
    onTapCancel: () => setState(() => _pressed = false),
    onTap: widget.onTap,
    child: AnimatedScale(
      scale: _pressed ? .94 : 1,
      duration: const Duration(milliseconds: 120),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: OfficeColors.line),
          boxShadow: [
            BoxShadow(
              color: Colors.blueGrey.withValues(alpha: .05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.color.withValues(alpha: .18),
                    widget.color.withValues(alpha: .07),
                  ],
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(widget.icon, size: 18, color: widget.color),
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final int value;
  final String sub;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OfficeColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withValues(alpha: .05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: .18),
                  color.withValues(alpha: .06),
                ],
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      Fa.digits(value),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9.5, color: Colors.blueGrey.shade400),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _SquareBtn extends StatelessWidget {
  const _SquareBtn({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OfficeColors.line),
      ),
      child: Icon(icon, size: 19, color: color),
    ),
  );
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: OfficeColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: .20),
                    color.withValues(alpha: .08),
                  ],
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.6,
                      color: Colors.blueGrey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left, size: 19, color: Colors.blueGrey.shade300),
          ],
        ),
      ),
    ),
  );
}

// ============================================================
//  کارت ماژول نامه در داشبورد — با کارتابل‌های واقعی هر ماژول
// ============================================================

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.boxes,
    required this.onOpenBox,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<LetterBox> boxes;
  final ValueChanged<LetterBox> onOpenBox;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OfficeColors.line),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, Color.lerp(color, Colors.black, 0.22)!],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: OfficeColors.ink,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: OfficeColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final b in boxes)
                Material(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(100),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(100),
                    onTap: () => onOpenBox(b),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: color.withValues(alpha: 0.22)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(b.icon, size: 14, color: color),
                          const SizedBox(width: 5),
                          Text(
                            b.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
