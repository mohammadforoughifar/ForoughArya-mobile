// ============================================================
//  پست الکترونیک — ایمیل سازمانی و شخصی
//  چیدمان عیناً همان ماژول اتوماسیون (هدر گرادیانی + تب کشویی +
//  کارت نامه‌مانند) تا زیبایی فرم تغییر نکند.
//  چهار کارتابل داخلی: دریافتی / ارسالی / بایگانی / پیش‌نویس
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/widgets/common.dart';
import '../data/email_draft_store.dart';
import '../data/email_repository.dart';
import '../models/email_models.dart';
import 'email_compose_page.dart';
import 'email_detail_page.dart';
import 'email_settings_page.dart';
import 'email_widgets.dart';
import 'office_style.dart';

/// محدودهٔ حساب‌ها — سازمانی (دبیرخانه) یا شخصی
enum EmailScope { corporate, personal }

extension EmailScopeX on EmailScope {
  String get label => switch (this) {
    EmailScope.corporate => 'سازمانی',
    EmailScope.personal => 'شخصی',
  };

  Color get color => switch (this) {
    EmailScope.corporate => OfficeColors.email,
    EmailScope.personal => OfficeColors.emailPersonal,
  };

  bool get isPersonal => this == EmailScope.personal;
}

class EmailPage extends StatefulWidget {
  const EmailPage({
    super.key,
    this.initialScope = EmailScope.corporate,
    this.embedded = false,
    this.prefillTo,
    this.prefillSubject,
    this.prefillBody,
    this.prefillAccountId,
  });

  /// پیش‌پر کردن فرم نگارش ایمیل از مبدأ (بند صورتجلسه / کل صورتجلسه)
  final String? prefillTo;
  final String? prefillSubject;
  final String? prefillBody;
  final int? prefillAccountId;

  final EmailScope initialScope;

  /// وقتی داخل `OfficeAutomationPage` قرار می‌گیرد، هدر گرادیانی تکراری رسم نمی‌شود
  /// و دقیقاً مانند `OfficeArchivePage` با نوار تب یکپارچه نمایش داده می‌شود.
  final bool embedded;

  @override
  State<EmailPage> createState() => _EmailPageState();
}

class _EmailPageState extends State<EmailPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  EmailRepository get _repo => context.read<EmailRepository>();
  EmailDraftStore get _draftStore => context.read<EmailDraftStore>();

  late EmailScope _scope = widget.initialScope;

  static const _tabsDef = [
    (label: 'دریافتی', icon: Icons.move_to_inbox_outlined, key: 'inbox'),
    (label: 'ارسالی', icon: Icons.outbox_outlined, key: 'sent'),
    (label: 'بایگانی', icon: Icons.account_tree_outlined, key: 'archive'),
    (label: 'پیش‌نویس', icon: Icons.drafts_outlined, key: 'draft'),
  ];

  static const _tabValues = [
    EmailTab.inbox,
    EmailTab.sent,
    EmailTab.archive,
    EmailTab.draft,
  ];

  final _items = <String, List<EmailMessage>>{};
  final _loading = <String, bool>{};
  final _error = <String, String?>{};
  final _page = <String, int>{};
  final _total = <String, int>{};
  final _unread = <String, int>{};
  final _search = <String, String>{};
  final _scroll = <String, ScrollController>{};

  final _accounts = <EmailAccount>[];
  bool _accountsLoading = false;
  String? _accountsError;
  int? _accountId;

  final _folders = <EmailFolder>[];
  int? _folderId;
  bool _starredOnly = false;
  bool _spamOnly = false;
  DateTimeRange? _dateRange;

  List<EmailDraft> _drafts = const [];
  bool _syncing = false;
  int _tabIndex = 0;

  int get _userId => context.read<AuthController>().session?.userId ?? 0;

  List<EmailAccount> get _scopedAccounts => _accounts
      .where((a) => _scope.isPersonal ? !a.isDabirkhane : a.isDabirkhane)
      .toList();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabsDef.length, vsync: this);
    _tabs.addListener(() {
      if (!mounted) return;
      if (_tabIndex != _tabs.index) {
        setState(() => _tabIndex = _tabs.index);
      }
      if (!_tabs.indexIsChanging) {
        _ensureLoaded(_keyAt(_tabs.index));
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bootstrap();
    });
  }

  @override
  void dispose() {
    for (final c in _scroll.values) {
      c.dispose();
    }
    _tabs.dispose();
    super.dispose();
  }

  String _keyAt(int i) => _tabsDef[i.clamp(0, _tabsDef.length - 1)].key;
  EmailTab _tabAt(int i) => _tabValues[i.clamp(0, _tabValues.length - 1)];

  Future<void> _bootstrap() async {
    final authed = context.read<AuthController>().isLoggedIn;
    await _loadDrafts();
    if (!authed) return;
    await Future.wait([_loadAccounts(), _loadFolders()]);
    if (!mounted) return;
    _ensureLoaded(_keyAt(_tabIndex));
  }

  Future<void> _loadDrafts() async {
    final list = await _draftStore.list(_userId);
    if (!mounted) return;
    setState(() => _drafts = list);
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _accountsLoading = true;
      _accountsError = null;
    });
    try {
      final list = await _repo.accounts();
      if (!mounted) return;
      setState(() {
        _accounts
          ..clear()
          ..addAll(list);
        _accountsLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _accountsLoading = false;
        _accountsError = _diagnose(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _accountsLoading = false;
        _accountsError = 'خطا در دریافت حساب‌های ایمیل: $e';
      });
    }
  }

  Future<void> _loadFolders() async {
    try {
      final list = await _repo.folders();
      if (!mounted) return;
      setState(() {
        _folders
          ..clear()
          ..addAll(list);
      });
    } catch (_) {
      // پوشه‌ها اختیاری‌اند؛ نبودشان بایگانی را از کار نمی‌اندازد
    }
  }

  void _ensureLoaded(String key) {
    if (key == 'draft') {
      _loadDrafts();
      return;
    }
    if (!context.read<AuthController>().isLoggedIn) return;
    if (_items.containsKey(key) || _loading[key] == true) return;
    _load(key, reset: true);
  }

  Future<void> _load(String key, {bool reset = false}) async {
    if (key == 'draft') return _loadDrafts();
    if (!context.read<AuthController>().isLoggedIn) return;
    if (_loading[key] == true) return;
    setState(() {
      _loading[key] = true;
      if (reset) {
        _error[key] = null;
        _page[key] = 1;
        _items[key] = [];
      }
    });
    final page = _page[key] ?? 1;
    final search = _search[key];
    try {
      final EmailListResult result = switch (key) {
        'inbox' => await _repo.inbox(
          emailId: _accountId,
          search: search,
          page: page,
          personal: _scope.isPersonal,
          starred: _starredOnly ? true : null,
          spam: _spamOnly ? true : null,
          dateFrom: _dateRange?.start,
          dateTo: _dateRange?.end,
        ),
        'sent' => await _repo.sent(
          emailId: _accountId,
          search: search,
          page: page,
          personal: _scope.isPersonal,
          dateFrom: _dateRange?.start,
          dateTo: _dateRange?.end,
        ),
        _ => await _repo.archive(
          emailId: _accountId,
          search: search,
          page: page,
          folderId: _folderId,
          personal: _scope.isPersonal,
          dateFrom: _dateRange?.start,
          dateTo: _dateRange?.end,
        ),
      };
      if (!mounted) return;
      setState(() {
        _items[key] = [...(_items[key] ?? []), ...result.items];
        _total[key] = result.totalCount;
        _unread[key] = result.unreadCount;
        _page[key] = page + 1;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error[key] = _diagnose(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error[key] = 'خطا در دریافت ایمیل‌ها: $e');
    } finally {
      if (mounted) setState(() => _loading[key] = false);
    }
  }

  bool _hasMore(String key) {
    final loaded = _items[key]?.length ?? 0;
    return loaded < (_total[key] ?? 0);
  }

  String _diagnose(ApiException e) => switch (e.statusCode) {
    401 => 'نشست شما منقضی شده است. دوباره وارد شوید.',
    403 => _scope.isPersonal
        ? 'مجوز «ایمیل شخصی» برای نقش شما فعال نیست. در دسکتاپ: مدیریت کاربران ← نقش ← دسترسی «ایمیل» ← «شخصی».'
        : 'مجوز «مشاهدهٔ ایمیل» برای نقش شما فعال نیست. در دسکتاپ: مدیریت کاربران ← نقش ← دسترسی «ایمیل».',
    _ => e.message,
  };

  // ------------------------------------------------------------
  //  عملیات
  // ------------------------------------------------------------

  Future<void> _openMessage(EmailMessage m) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EmailDetailPage(
          box: m.box,
          messageId: m.id,
          tab: _tabAt(_tabIndex),
          accounts: _scopedAccounts.isNotEmpty ? _scopedAccounts : _accounts,
          scope: _scope,
        ),
      ),
    );
    if (changed == true || !m.isRead) {
      final key = _keyAt(_tabIndex);
      setState(() => _items.remove(key));
      _load(key, reset: true);
    }
  }

  Future<void> _toggleNeshan(EmailMessage m) async {
    try {
      final now = await _repo.toggleNeshan(m.box, m.id);
      if (!mounted) return;
      setState(() {
        for (final k in _items.keys) {
          _items[k] = (_items[k] ?? [])
              .map((it) => it.id == m.id && it.box == m.box ? it.copyWith(isNeshan: now) : it)
              .toList();
        }
      });
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final EmailSyncResult res;
      if (_accountId != null) {
        final box = _tabIndex == 1 ? EmailBox.sent : EmailBox.inbox;
        res = await _repo.syncAccount(_accountId!, box: box);
      } else if (_tabIndex == 1) {
        res = await _repo.syncSent(personal: _scope.isPersonal);
      } else {
        res = await _repo.syncInbox(personal: _scope.isPersonal);
      }
      if (!mounted) return;
      final msg = res.message.isNotEmpty
          ? res.message
          : 'همگام‌سازی انجام شد (${Fa.digits(res.newCount)} ایمیل جدید).';
      showMessage(context, msg);
      final key = _keyAt(_tabIndex);
      setState(() => _items.remove(key));
      await _load(key, reset: true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, _diagnose(e), error: true);
    } catch (e) {
      if (mounted) showMessage(context, 'خطا در همگام‌سازی: $e', error: true);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _compose({EmailDraft? draft}) async {
    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (_) => EmailComposePage(
          scope: _scope,
          accounts: _scopedAccounts.isNotEmpty ? _scopedAccounts : _accounts,
          draft: draft,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      if (draft != null) {
        await _draftStore.remove(_userId, draft.localId);
        await _loadDrafts();
      }
      setState(() => _items.remove('sent'));
      if (_keyAt(_tabIndex) == 'sent') _load('sent', reset: true);
      if (mounted) showMessage(context, 'ایمیل با موفقیت ارسال شد.');
    } else if (result is EmailDraft) {
      await _saveDraftLocal(result);
    }
  }

  Future<void> _saveDraftLocal(EmailDraft savedDraft) async {
    await _draftStore.upsert(_userId, savedDraft);
    await _loadDrafts();
    if (!mounted) return;
    showMessage(context, 'پیش‌نویس ذخیره شد.');
  }

  Future<void> _openDraft(EmailDraft d) => _compose(draft: d);

  Future<void> _deleteDraft(EmailDraft d) async {
    await _draftStore.remove(_userId, d.localId);
    await _loadDrafts();
    if (!mounted) return;
    showMessage(context, 'پیش‌نویس حذف شد.');
  }

  void _changeScope(EmailScope s) {
    if (_scope == s) return;
    setState(() {
      _scope = s;
      _accountId = null;
      _items.clear();
      _error.clear();
      _page.clear();
      _total.clear();
      _unread.clear();
    });
    _ensureLoaded(_keyAt(_tabIndex));
  }

  void _goTab(int i) {
    _tabs.animateTo(i);
    _ensureLoaded(_keyAt(i));
  }

  Future<void> _openSettings() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EmailSettingsPage()),
    );
    if (changed == true) {
      await _loadAccounts();
      setState(() {
        _items.clear();
        _page.clear();
      });
      _ensureLoaded(_keyAt(_tabIndex));
    }
  }

  Future<void> _pickDateRange(String key) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _dateRange,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateRange = picked;
      _items.remove(key);
    });
    _load(key, reset: true);
  }

  // ============================================================
  //  ساختار صفحه
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final name = auth.session?.displayName ?? '';
    final accent = _scope.color;

    final tabCounts = {
      'inbox': _unread['inbox'] ?? 0,
      'sent': 0,
      'archive': 0,
      'draft': _drafts.length,
    };

    Color tabAccent(int i) => switch (i) {
      1 => OfficeColors.outgoing,
      2 => OfficeColors.archive,
      3 => const Color(0xffb04fbf),
      _ => accent,
    };

    final tabContent = Expanded(
      child: TabBarView(
        controller: _tabs,
        children: [
          _listTab('inbox'),
          _listTab('sent'),
          _listTab('archive'),
          _draftTab(),
        ],
      ),
    );

    final composeFab = FloatingActionButton.extended(
      heroTag: widget.embedded ? 'email_fab_${_scope.name}' : 'email_fab_main',
      onPressed: () => _compose(),
      backgroundColor: accent,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.edit_outlined),
      label: const Text(
        'ایمیل جدید',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );

    if (widget.embedded) {
      return Scaffold(
        backgroundColor: OfficeColors.bg,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OfficeSlidingTabs(
                        items: _tabsDef,
                        index: _tabIndex,
                        onChanged: _goTab,
                        pillColor: accent,
                        showCounts: true,
                        counts: tabCounts,
                        accentFor: tabAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  _SquareBtn(
                    icon: _syncing ? Icons.sync : Icons.refresh,
                    color: accent,
                    onTap: _sync,
                  ),
                  const SizedBox(width: 6),
                  _SquareBtn(
                    icon: Icons.settings_outlined,
                    color: Colors.blueGrey.shade700,
                    onTap: _openSettings,
                  ),
                ],
              ),
            ),
            tabContent,
          ],
        ),
        floatingActionButton: composeFab,
      );
    }

    return Scaffold(
      backgroundColor: OfficeColors.bg,
      body: Column(
        children: [
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
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 8, 0),
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
                              Icons.alternate_email,
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
                                  'پست الکترونیک',
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
                          if ((_unread['inbox'] ?? 0) > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: HeroBadge(
                                label: '${Fa.digits(_unread['inbox']!)} نخوانده',
                                icon: Icons.mark_email_unread_outlined,
                                color: OfficeColors.signing,
                              ),
                            ),
                          _HeaderBtn(
                            icon: _syncing ? Icons.sync : Icons.refresh,
                            tooltip: 'دریافت ایمیل‌ها',
                            onTap: _sync,
                          ),
                          _HeaderBtn(
                            icon: Icons.edit_outlined,
                            tooltip: 'ایمیل جدید',
                            onTap: () => _compose(),
                          ),
                          _HeaderBtn(
                            icon: Icons.settings_outlined,
                            tooltip: 'حساب‌های ایمیل',
                            onTap: _openSettings,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: _ScopeSwitch(
                        scope: _scope,
                        onChanged: _changeScope,
                        corporateCount: _accounts.where((a) => a.isDabirkhane).length,
                        personalCount: _accounts.where((a) => !a.isDabirkhane).length,
                      ),
                    ),
                    OfficeSlidingTabs(
                      items: _tabsDef,
                      index: _tabIndex,
                      onChanged: _goTab,
                      background: Colors.transparent,
                      pillColor: accent,
                      showCounts: true,
                      counts: tabCounts,
                      accentFor: tabAccent,
                    ),
                  ],
                ),
              ),
            ),
          ),
          tabContent,
        ],
      ),
      floatingActionButton: composeFab,
    );
  }

  // ------------------------------------------------------------
  //  کارتابل‌های فهرستی (دریافتی / ارسالی / بایگانی)
  // ------------------------------------------------------------

  ScrollController _scrollFor(String key) {
    return _scroll.putIfAbsent(key, () {
      final c = ScrollController();
      c.addListener(() {
        if (c.position.pixels >= c.position.maxScrollExtent - 160 &&
            _hasMore(key) &&
            _loading[key] != true) {
          _load(key);
        }
      });
      return c;
    });
  }

  Widget _listTab(String key) {
    final tab = switch (key) {
      'sent' => EmailTab.sent,
      'archive' => EmailTab.archive,
      _ => EmailTab.inbox,
    };
    final accent = emailTabColor(tab);
    final items = _items[key] ?? const [];
    final loading = _loading[key] == true;
    final error = _error[key];
    final scoped = _scopedAccounts;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: OfficeColors.line),
                  ),
                  child: TextField(
                    textInputAction: TextInputAction.search,
                    onSubmitted: (v) {
                      setState(() {
                        _search[key] = v.trim();
                        _items.remove(key);
                      });
                      _load(key, reset: true);
                    },
                    decoration: InputDecoration(
                      hintText: 'جست‌وجوی موضوع یا فرستنده...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey.shade400,
                      ),
                      prefixIcon: Icon(Icons.search, size: 18, color: accent),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              _SquareBtn(
                icon: Icons.date_range_outlined,
                color: _dateRange != null ? accent : Colors.blueGrey.shade600,
                onTap: () => _pickDateRange(key),
              ),
              if (_dateRange != null) ...[
                const SizedBox(width: 5),
                _SquareBtn(
                  icon: Icons.close,
                  color: OfficeColors.danger,
                  onTap: () {
                    setState(() {
                      _dateRange = null;
                      _items.remove(key);
                    });
                    _load(key, reset: true);
                  },
                ),
              ],
            ],
          ),
        ),
        if (scoped.isNotEmpty) ...[
          EmailAccountStrip(
            accounts: scoped,
            selectedId: _accountId,
            color: accent,
            onSelected: (id) {
              setState(() {
                _accountId = id;
                _items.remove(key);
              });
              _load(key, reset: true);
            },
          ),
          const SizedBox(height: 6),
        ],
        if (key == 'inbox')
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _FilterChip(
                  label: 'همه',
                  selected: !_starredOnly && !_spamOnly,
                  color: accent,
                  onTap: () {
                    setState(() {
                      _starredOnly = false;
                      _spamOnly = false;
                      _items.remove(key);
                    });
                    _load(key, reset: true);
                  },
                ),
                const SizedBox(width: 7),
                _FilterChip(
                  label: 'نشان‌شده ★',
                  selected: _starredOnly,
                  color: OfficeColors.gold,
                  onTap: () {
                    setState(() {
                      _starredOnly = !_starredOnly;
                      if (_starredOnly) _spamOnly = false;
                      _items.remove(key);
                    });
                    _load(key, reset: true);
                  },
                ),
                const SizedBox(width: 7),
                _FilterChip(
                  label: 'هرزنامه',
                  selected: _spamOnly,
                  color: OfficeColors.danger,
                  onTap: () {
                    setState(() {
                      _spamOnly = !_spamOnly;
                      if (_spamOnly) _starredOnly = false;
                      _items.remove(key);
                    });
                    _load(key, reset: true);
                  },
                ),
              ],
            ),
          ),
        if (key == 'archive' && _folders.isNotEmpty)
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _FilterChip(
                  label: 'همهٔ پوشه‌ها',
                  selected: _folderId == null,
                  color: accent,
                  onTap: () {
                    setState(() {
                      _folderId = null;
                      _items.remove(key);
                    });
                    _load(key, reset: true);
                  },
                ),
                for (final f in _folders) ...[
                  const SizedBox(width: 7),
                  _FilterChip(
                    label: f.title,
                    selected: _folderId == f.id,
                    color: accent,
                    onTap: () {
                      setState(() {
                        _folderId = f.id;
                        _items.remove(key);
                      });
                      _load(key, reset: true);
                    },
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 4),
        Expanded(
          child: Builder(
            builder: (_) {
              if (_accountsError != null && items.isEmpty && !loading) {
                return ErrorView(
                  message: _accountsError!,
                  onRetry: () {
                    _loadAccounts();
                    _load(key, reset: true);
                  },
                );
              }
              if (error != null && items.isEmpty) {
                return ErrorView(
                  message: error,
                  onRetry: () => _load(key, reset: true),
                );
              }
              if ((loading || _accountsLoading) && items.isEmpty) {
                return const LoadingView(label: 'در حال دریافت ایمیل‌ها...');
              }
              if (items.isEmpty) {
                final msg = scoped.isEmpty && _accounts.isNotEmpty
                    ? 'حسابی در دامنهٔ «${_scope.label}» تعریف نشده است.'
                    : 'ایمیلی در کارتابل «${tab.label}» وجود ندارد.';
                return EmptyView(message: msg, icon: emailTabIcon(tab));
              }
              return RefreshIndicator(
                onRefresh: () => _load(key, reset: true),
                child: ListView.builder(
                  controller: _scrollFor(key),
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 92),
                  itemCount: items.length + (_hasMore(key) ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= items.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final m = items[i];
                    return EmailCard(
                      message: m,
                      tab: tab,
                      onTap: () => _openMessage(m),
                      onToggleStar: () => _toggleNeshan(m),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  //  کارتابل پیش‌نویس‌های محلی
  // ------------------------------------------------------------

  Widget _draftTab() {
    if (_drafts.isEmpty) {
      return const EmptyView(
        message: 'پیش‌نویسی ذخیره نشده است.',
        icon: Icons.drafts_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadDrafts,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 92),
        itemCount: _drafts.length,
        itemBuilder: (context, i) {
          final d = _drafts[i];
          final sub = d.subject.trim().isEmpty ? '(پیش‌نویس بدون موضوع)' : d.subject;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: OfficeColors.line),
            ),
            child: ListTile(
              onTap: () => _openDraft(d),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xffb04fbf).withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.drafts_outlined,
                  size: 18,
                  color: Color(0xffb04fbf),
                ),
              ),
              title: Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                d.to.trim().isEmpty ? 'گیرنده مشخص نشده' : 'گیرنده: ${d.to}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: Colors.blueGrey.shade600),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: OfficeColors.danger),
                tooltip: 'حذف پیش‌نویس',
                onPressed: () => _deleteDraft(d),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
//  ویجت‌های داخلی صفحهٔ ایمیل
// ============================================================

class _ScopeSwitch extends StatelessWidget {
  const _ScopeSwitch({
    required this.scope,
    required this.onChanged,
    required this.corporateCount,
    required this.personalCount,
  });

  final EmailScope scope;
  final ValueChanged<EmailScope> onChanged;
  final int corporateCount;
  final int personalCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ScopePill(
              label: 'ایمیل سازمانی',
              icon: Icons.account_balance_outlined,
              count: corporateCount,
              selected: scope == EmailScope.corporate,
              color: OfficeColors.email,
              onTap: () => onChanged(EmailScope.corporate),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ScopePill(
              label: 'ایمیل شخصی',
              icon: Icons.person_outline,
              count: personalCount,
              selected: scope == EmailScope.personal,
              color: OfficeColors.emailPersonal,
              onTap: () => onChanged(EmailScope.personal),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopePill extends StatelessWidget {
  const _ScopePill({
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: selected ? color : Colors.white70),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected ? color : Colors.white,
              ),
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: .14) : Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                Fa.digits(count),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: selected ? color : Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _HeaderBtn extends StatelessWidget {
  const _HeaderBtn({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, size: 17, color: Colors.white),
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
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Icon(icon, size: 19, color: color),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: .12) : Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: selected ? color : OfficeColors.line),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? color : Colors.blueGrey.shade600,
        ),
      ),
    ),
  );
}
