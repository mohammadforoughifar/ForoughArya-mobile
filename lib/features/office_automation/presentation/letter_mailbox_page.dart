// ============================================================
//  کارتابل هر ماژول نامه — «داخلی»، «صادره»، «وارده»
//  کارتابل‌هایی که در وب وجود دارد و اپ باید همان‌ها را بدهد:
//     • دریافتی (inbox)
//     • ارسالی (sent)
//     • پیش‌نویس (drafts)
//     • بایگانی (archive)
//  (برای صادره، «امضا» و «دبیرخانه» هم به‌عنوان کارتابل اضافه می‌شوند)
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/fa.dart';
import '../../../core/widgets/common.dart';
import '../data/office_repository.dart';
import '../models/letter_models.dart';
import '../models/office_common.dart';
import 'letter_detail_page.dart';
import 'letter_editor_page.dart';
import 'office_style.dart';
import 'office_widgets.dart';

/// نوع کارتابل‌های استاندارد هر ماژول
enum LetterBox { inbox, sent, drafts, archive, signing, dabirkhane }

extension LetterBoxX on LetterBox {
  String get label => switch (this) {
    LetterBox.inbox => 'دریافتی',
    LetterBox.sent => 'ارسالی',
    LetterBox.drafts => 'پیش‌نویس',
    LetterBox.archive => 'بایگانی',
    LetterBox.signing => 'امضا',
    LetterBox.dabirkhane => 'دبیرخانه',
  };

  IconData get icon => switch (this) {
    LetterBox.inbox => Icons.move_to_inbox_rounded,
    LetterBox.sent => Icons.send_rounded,
    LetterBox.drafts => Icons.drafts_rounded,
    LetterBox.archive => Icons.inventory_2_rounded,
    LetterBox.signing => Icons.draw_rounded,
    LetterBox.dabirkhane => Icons.account_balance_rounded,
  };
}

class LetterMailboxPage extends StatefulWidget {
  const LetterMailboxPage({
    super.key,
    required this.kind,
    this.initialBox = LetterBox.inbox,
    this.embedded = false,
  });

  final LetterKind kind;
  final LetterBox initialBox;

  /// وقتی داخل صفحهٔ اتوماسیون به‌صورت تب نمایش داده می‌شود
  final bool embedded;

  @override
  State<LetterMailboxPage> createState() => _LetterMailboxPageState();
}

class _LetterMailboxPageState extends State<LetterMailboxPage>
    with SingleTickerProviderStateMixin {
  OfficeAutomationRepository get _repo =>
      context.read<OfficeAutomationRepository>();

  late LetterBox _box = widget.initialBox;
  late List<LetterBox> _boxes = _boxesFor(widget.kind);
  TabController? _tabs;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<LetterListItem> _items = const [];
  List<DraftLetter> _drafts = const [];
  Map<LetterBox, int?> _counts = {};
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  int _page = 1;
  int _total = 0;
  bool _hasMore = false;
  bool _unreadOnly = false;

  static List<LetterBox> _boxesFor(LetterKind kind) => switch (kind) {
    LetterKind.inner => const [
      LetterBox.inbox,
      LetterBox.sent,
      LetterBox.drafts,
      LetterBox.archive,
    ],
    LetterKind.outgoing => const [
      LetterBox.inbox,
      LetterBox.sent,
      LetterBox.drafts,
      LetterBox.signing,
      LetterBox.dabirkhane,
      LetterBox.archive,
    ],
    LetterKind.incoming => const [
      LetterBox.inbox,
      LetterBox.sent,
      LetterBox.drafts,
      LetterBox.archive,
    ],
  };

  Color get _accent => OfficeColors.forKind(widget.kind);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _boxes.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reload();
      _loadCounts();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _tabs?.dispose();
    super.dispose();
  }

  Future<Paged<LetterListItem>> _fetch(LetterBox box, int page) {
    final q = _searchCtrl.text.trim();
    return switch ((widget.kind, box)) {
      (LetterKind.inner, LetterBox.inbox) => _repo.innerInbox(
        page: page,
        search: q.isEmpty ? null : q,
        unreadOnly: _unreadOnly ? true : null,
      ),
      (LetterKind.inner, LetterBox.sent) =>
        _repo.innerSent(page: page, search: q.isEmpty ? null : q),
      (LetterKind.inner, _) =>
        _repo.innerArchive(page: page, search: q.isEmpty ? null : q),
      (LetterKind.outgoing, LetterBox.inbox) => _repo.outgoingInbox(
        page: page,
        search: q.isEmpty ? null : q,
        unreadOnly: _unreadOnly ? true : null,
      ),
      (LetterKind.outgoing, LetterBox.sent) =>
        _repo.outgoingSent(page: page, search: q.isEmpty ? null : q),
      (LetterKind.outgoing, LetterBox.signing) =>
        _repo.signingInbox(page: page, search: q.isEmpty ? null : q),
      (LetterKind.outgoing, LetterBox.dabirkhane) =>
        _repo.dabirkhane(page: page, search: q.isEmpty ? null : q),
      (LetterKind.outgoing, _) =>
        _repo.outgoingArchive(page: page, search: q.isEmpty ? null : q),
      (LetterKind.incoming, LetterBox.inbox) => _repo.incomingInbox(
        page: page,
        search: q.isEmpty ? null : q,
        unreadOnly: _unreadOnly ? true : null,
      ),
      (LetterKind.incoming, LetterBox.sent) =>
        _repo.incomingSent(page: page, search: q.isEmpty ? null : q),
      (LetterKind.incoming, _) =>
        _repo.incomingArchive(page: page, search: q.isEmpty ? null : q),
    };
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
    });
    try {
      if (_box == LetterBox.drafts) {
        final paged = await _repo.drafts(widget.kind);
        if (!mounted) return;
        setState(() {
          _drafts = paged.items;
          _items = const [];
          _total = paged.items.length;
          _hasMore = false;
          _loading = false;
        });
        return;
      }
      final res = await _fetch(_box, 1);
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _total = res.totalCount;
        _hasMore = res.items.length < res.totalCount;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _box == LetterBox.drafts) return;
    setState(() => _loadingMore = true);
    try {
      final res = await _fetch(_box, _page + 1);
      if (!mounted) return;
      setState(() {
        _page += 1;
        _items = [..._items, ...res.items];
        _hasMore = _items.length < res.totalCount;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// شمارندهٔ کارتابل‌ها — مشابه وب
  Future<void> _loadCounts() async {
    final result = <LetterBox, int?>{};
    for (final b in _boxes) {
      try {
        if (b == LetterBox.drafts) {
          final d = await _repo.drafts(widget.kind);
          result[b] = d.items.length;
        } else {
          final p = await _fetch(b, 1);
          result[b] = p.totalCount;
        }
      } catch (_) {
        result[b] = null;
      }
    }
    if (!mounted) return;
    setState(() => _counts = result);
  }

  void _selectBox(LetterBox b) {
    if (_box == b) return;
    setState(() {
      _box = b;
      _items = const [];
      _drafts = const [];
      _total = 0;
    });
    _tabs?.animateTo(_boxes.indexOf(b));
    _reload();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reload);
  }

  Future<void> _openDetail(LetterListItem item) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LetterDetailPage(
          kind: widget.kind,
          letterId: item.letterId,
          erjaId: item.erjaId,
        ),
      ),
    );
    if (changed == true && mounted) {
      _reload();
      _loadCounts();
    }
  }

  Future<void> _newLetter() async {
    final created = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (_) => LetterEditorPage(kind: widget.kind),
      ),
    );
    if (created != null && mounted) {
      if (created is int) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                LetterDetailPage(kind: widget.kind, letterId: created),
          ),
        );
      }
      _reload();
      _loadCounts();
    }
  }

  Future<void> _openDraft(DraftLetter d) async {
    final res = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (_) => LetterEditorPage(
          kind: widget.kind,
          editingId: d.id,
        ),
      ),
    );
    if (res != null && mounted) {
      _reload();
      _loadCounts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OfficeColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'mailbox_fab_${widget.kind.name}',
        onPressed: _newLetter,
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'نامهٔ جدید',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          if (!widget.embedded) _buildHeader(),
          if (widget.embedded) const SizedBox(height: 8),
          _buildTabs(),
          _buildSearchRow(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accent, OfficeColors.deep],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.kind.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'کارتابل ${_box.label} • ${Fa.digits(_total)} نامه',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 2),
      child: SizedBox(
        height: 56,
        child: OfficeSlidingTabs(
          items: [
            for (final b in _boxes)
              (label: b.label, icon: b.icon, key: b.name),
          ],
          index: _boxes.indexOf(_box),
          onChanged: (i) => _selectBox(_boxes[i]),
          pillColor: _accent,
          showCounts: true,
          counts: {
            for (final e in _counts.entries)
              e.key.name: e.value ?? 0,
          },
        ),
      ),
    );
  }

  Widget _buildSearchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'جستجو در ${_box.label}…',
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 19),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: OfficeColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: OfficeColors.line),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_box != LetterBox.drafts && _box != LetterBox.sent)
            Material(
              color: _unreadOnly
                  ? _accent.withValues(alpha: 0.12)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() => _unreadOnly = !_unreadOnly);
                  _reload();
                },
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _unreadOnly ? _accent : OfficeColors.line,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.mark_email_unread_outlined,
                        size: 17,
                        color: _unreadOnly ? _accent : OfficeColors.ink,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'نخوانده',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _unreadOnly ? _accent : OfficeColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return LoadingView(label: 'در حال دریافت ${_box.label}…');
    }
    if (_error != null) {
      return ErrorView(message: _error.toString(), onRetry: _reload);
    }
    if (_box == LetterBox.drafts) {
      if (_drafts.isEmpty) {
        return _empty('پیش‌نویسی وجود ندارد');
      }
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 96),
          itemCount: _drafts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _DraftCard(
            draft: _drafts[i],
            accent: _accent,
            onTap: () => _openDraft(_drafts[i]),
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return _empty(
        _unreadOnly
            ? 'نامهٔ خوانده‌نشده‌ای در ${_box.label} نیست'
            : 'نامه‌ای در ${_box.label} وجود ندارد',
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await _reload();
        await _loadCounts();
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 240) {
            _loadMore();
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 96),
          itemCount: _items.length + (_loadingMore || _hasMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i >= _items.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final it = _items[i];
            return LetterTile(
              item: it,
              kind: widget.kind,
              onTap: () => _openDetail(it),
            );
          },
        ),
      ),
    );
  }

  Widget _empty(String message) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: OfficeColors.line),
            ),
            child: Column(
              children: [
                Icon(_box.icon, size: 34, color: _accent),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: OfficeColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.draft,
    required this.accent,
    required this.onTap,
  });

  final DraftLetter draft;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: OfficeColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.drafts_rounded, size: 19, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.title.trim().isEmpty
                          ? 'پیش‌نویس بدون عنوان'
                          : draft.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      draft.text.trim().isEmpty
                          ? 'بدون متن'
                          : draft.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: OfficeColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_outlined, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
