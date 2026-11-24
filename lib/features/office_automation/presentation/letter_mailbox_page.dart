// ============================================================
//  کارتابل اجرایی نامه‌ها — «داخلی»، «صادره»، «وارده»
//  هم‌تراز ۱۰۰٪ با وب (`LetterCartable.razor`, `OutgoingLetterCartable.razor`,
//  `IncomingLetterCartable.razor`) + چیپ‌های فیلتر، مرتب‌سازی ۶ حالته،
//  نشان‌گذاری ستاره‌دار، بایگانی درختی و دسترسی مستقیم به دبیرخانه و راهنما.
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/web_access.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/widgets/common.dart';
import '../data/office_repository.dart';
import '../models/letter_models.dart';
import '../models/office_common.dart';

import 'letter_detail_page.dart';
import 'letter_editor_page.dart';
import 'office_dabirkhane_page.dart';
import 'office_style.dart';
import 'office_tools_pages.dart';
import 'office_widgets.dart';

/// نوع کارتابل‌های استاندارد هر ماژول
enum LetterBox { inbox, signing, sent, drafts, starred, archive, dabirkhane }

extension LetterBoxX on LetterBox {
  String get label => switch (this) {
    LetterBox.inbox => 'دریافتی',
    LetterBox.signing => 'امضای من',
    LetterBox.sent => 'ارسالی',
    LetterBox.drafts => 'پیش‌نویس',
    LetterBox.starred => 'نشان‌شده',
    LetterBox.archive => 'بایگانی',
    LetterBox.dabirkhane => 'دبیرخانه',
  };

  IconData get icon => switch (this) {
    LetterBox.inbox => Icons.move_to_inbox_rounded,
    LetterBox.signing => Icons.draw_rounded,
    LetterBox.sent => Icons.send_rounded,
    LetterBox.drafts => Icons.drafts_rounded,
    LetterBox.starred => Icons.star_rounded,
    LetterBox.archive => Icons.inventory_2_rounded,
    LetterBox.dabirkhane => Icons.markunread_mailbox_rounded,
  };
}

enum _CartableChip { all, unread, starred, urgent, deadline, attachment }

enum _CartableSort { newest, oldest, urgent, confidential, number, title }

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
      Provider.of<OfficeAutomationRepository?>(context, listen: false) ??
      OfficeAutomationRepository(context.read<ApiClient>());

  late LetterBox _box = widget.initialBox;
  List<LetterBox> _boxes = const [];
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

  _CartableChip _activeChip = _CartableChip.all;
  _CartableSort _sort = _CartableSort.newest;

  // --- انتخاب چندگانه (برای بایگانی گروهی) ---
  bool _selectionMode = false;
  final Set<int> _selectedErja = <int>{};
  final Set<int> _selectedLetter = <int>{};

  // --- درخت پوشه‌های بایگانی ---
  List<ArchiveNode> _folders = const [];
  bool _foldersOpen = false;

  bool get _canSelect => _box != LetterBox.drafts && _items.isNotEmpty;

  static List<LetterBox> _boxesFor(LetterKind kind, WebAccess access) =>
      switch (kind) {
        LetterKind.inner => const [
          LetterBox.inbox,
          LetterBox.sent,
          LetterBox.drafts,
          LetterBox.starred,
          LetterBox.archive,
        ],
        LetterKind.outgoing => [
          LetterBox.inbox,
          LetterBox.signing,
          LetterBox.sent,
          LetterBox.drafts,
          LetterBox.starred,
          if (access.canSeeOutgoingDabirkhane) LetterBox.dabirkhane,
          LetterBox.archive,
        ],
        LetterKind.incoming => const [
          LetterBox.inbox,
          LetterBox.sent,
          LetterBox.starred,
          LetterBox.archive,
        ],
      };

  Color get _accent => OfficeColors.forKind(widget.kind);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncBoxes();
      _reload();
      _loadCounts();
      if (widget.initialBox == LetterBox.archive) _loadFolders();
    });
  }

  void _syncBoxes() {
    final session = Provider.of<AuthController?>(
      context,
      listen: false,
    )?.session;
    final access = WebAccess(session, unrestrictedWhenNull: true);
    final next = _boxesFor(widget.kind, access);
    if (_boxes.length != next.length) {
      _tabs?.dispose();
      _boxes = next;
      if (!_boxes.contains(_box)) _box = _boxes.first;
      _tabs = TabController(
        length: _boxes.length,
        vsync: this,
        initialIndex: _boxes.indexOf(_box),
      );
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _tabs?.dispose();
    super.dispose();
  }

  bool get _unreadOnly => _activeChip == _CartableChip.unread;

  Future<Paged<LetterListItem>> _fetch(LetterBox box, int page) async {
    final q = _searchCtrl.text.trim();
    if (box == LetterBox.starred) {
      final base = await _fetch(LetterBox.inbox, page);
      final starred = base.items.where((e) => e.isNeshan).toList();
      return Paged(
        items: starred,
        totalCount: starred.length,
        page: page,
        pageSize: base.pageSize,
      );
    }
    return switch ((widget.kind, box)) {
      (LetterKind.inner, LetterBox.inbox) => _repo.innerInbox(
        page: page,
        search: q.isEmpty ? null : q,
        unreadOnly: _unreadOnly ? true : null,
      ),
      (LetterKind.inner, LetterBox.sent) => _repo.innerSent(
        page: page,
        search: q.isEmpty ? null : q,
      ),
      (LetterKind.inner, _) => _repo.innerArchive(
        page: page,
        search: q.isEmpty ? null : q,
      ),
      (LetterKind.outgoing, LetterBox.inbox) => _repo.outgoingInbox(
        page: page,
        search: q.isEmpty ? null : q,
        unreadOnly: _unreadOnly ? true : null,
      ),
      (LetterKind.outgoing, LetterBox.sent) => _repo.outgoingSent(
        page: page,
        search: q.isEmpty ? null : q,
      ),
      (LetterKind.outgoing, LetterBox.signing) => _repo.signingInbox(
        page: page,
        search: q.isEmpty ? null : q,
      ),
      (LetterKind.outgoing, LetterBox.dabirkhane) => _repo.dabirkhane(
        page: page,
        search: q.isEmpty ? null : q,
      ),
      (LetterKind.outgoing, _) => _repo.outgoingArchive(
        page: page,
        search: q.isEmpty ? null : q,
      ),
      (LetterKind.incoming, LetterBox.inbox) => _repo.incomingInbox(
        page: page,
        search: q.isEmpty ? null : q,
        unreadOnly: _unreadOnly ? true : null,
      ),
      (LetterKind.incoming, LetterBox.sent) => _repo.incomingSent(
        page: page,
        search: q.isEmpty ? null : q,
      ),
      (LetterKind.incoming, _) => _repo.incomingArchive(
        page: page,
        search: q.isEmpty ? null : q,
      ),
    };
  }

  List<LetterListItem> get _visibleItems {
    var list = _items.where((it) {
      return switch (_activeChip) {
        _CartableChip.all => true,
        _CartableChip.unread => !it.isRead,
        _CartableChip.starred => it.isNeshan,
        _CartableChip.urgent => it.isUrgent,
        _CartableChip.deadline => it.deadline != null,
        _CartableChip.attachment => it.hasAttachment,
      };
    }).toList();

    int urgencyRank(String f) => f == 'آنی' ? 2 : (f == 'فوری' ? 1 : 0);
    int confRank(String m) => m == 'سری' ? 2 : (m == 'محرمانه' ? 1 : 0);

    list.sort((a, b) {
      return switch (_sort) {
        _CartableSort.newest =>
          (b.date ?? DateTime(1970)).compareTo(a.date ?? DateTime(1970)),
        _CartableSort.oldest =>
          (a.date ?? DateTime(1970)).compareTo(b.date ?? DateTime(1970)),
        _CartableSort.urgent =>
          urgencyRank(b.foriat).compareTo(urgencyRank(a.foriat)),
        _CartableSort.confidential =>
          confRank(b.mahramanegi).compareTo(confRank(a.mahramanegi)),
        _CartableSort.number => b.letterNumber.compareTo(a.letterNumber),
        _CartableSort.title => a.title.compareTo(b.title),
      };
    });
    return list;
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
    if (_loadingMore ||
        !_hasMore ||
        _box == LetterBox.drafts ||
        _box == LetterBox.starred) {
      return;
    }
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

  Future<void> _loadFolders() async {
    try {
      final r = await _repo.archiveTree(widget.kind);
      final data = r.data;
      final raw = data is List
          ? data
          : (asMap(data)['items'] ?? asMap(data)['tree']);
      final list = raw is List
          ? raw
                .whereType<Map>()
                .map((e) => ArchiveNode.fromJson(asMap(e)))
                .toList()
          : <ArchiveNode>[];
      if (mounted) setState(() => _folders = list);
    } catch (_) {
      if (mounted) setState(() => _folders = const []);
    }
  }

  Future<void> _createNewArchiveFolder() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text(
            'ایجاد پوشه بایگانی جدید',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
          ),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'نام پوشه بایگانی',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ایجاد'),
            ),
          ],
        ),
      ),
    );
    final t = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || t.isEmpty) return;
    try {
      await _repo.addArchiveFolder(widget.kind, t);
      await _loadFolders();
      if (mounted) showMessage(context, 'پوشهٔ «$t» ایجاد شد.');
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _toggleStar(LetterListItem it) async {
    final erjaId = it.erjaId;
    if (erjaId == null || erjaId <= 0) return;
    try {
      await _repo.toggleErjaNeshan(widget.kind, erjaId);
      await _reload();
      await _loadCounts();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  void _toggleSelect(LetterListItem it) {
    setState(() {
      final erja = it.erjaId;
      if (erja != null && erja > 0) {
        if (!_selectedErja.remove(erja)) _selectedErja.add(erja);
      } else {
        if (!_selectedLetter.remove(it.letterId)) {
          _selectedLetter.add(it.letterId);
        }
      }
      if (_selectedErja.isEmpty && _selectedLetter.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  bool _isSelected(LetterListItem it) {
    final erja = it.erjaId;
    if (erja != null && erja > 0) return _selectedErja.contains(erja);
    return _selectedLetter.contains(it.letterId);
  }

  void _startSelection() => setState(() => _selectionMode = true);

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedErja.clear();
      _selectedLetter.clear();
    });
  }

  void _selectAll() {
    setState(() {
      for (final it in _visibleItems) {
        final erja = it.erjaId;
        if (erja != null && erja > 0) {
          _selectedErja.add(erja);
        } else {
          _selectedLetter.add(it.letterId);
        }
      }
    });
  }

  Future<void> _archiveSelected() async {
    if (_selectedErja.isEmpty && _selectedLetter.isEmpty) return;
    if (_folders.isEmpty) await _loadFolders();
    if (!mounted) return;
    final folder = await _pickFolder();
    if (folder == null || !mounted) return;
    try {
      await _repo.archiveLetters(
        widget.kind,
        folderId: folder.id,
        erjaIds: _selectedErja.toList(),
        letterIds: _selectedLetter.toList(),
      );
      if (!mounted) return;
      final count = _selectedErja.length + _selectedLetter.length;
      showMessage(
        context,
        '${Fa.digits(count)} نامه در پوشهٔ «${folder.title}» بایگانی شد.',
      );
      _clearSelection();
      await _reload();
      await _loadFolders();
      await _loadCounts();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<ArchiveNode?> _pickFolder() {
    final flat = <({ArchiveNode node, int depth})>[];
    void walk(List<ArchiveNode> nodes, int depth) {
      for (final n in nodes) {
        flat.add((node: n, depth: depth));
        if (n.children.isNotEmpty) walk(n.children, depth + 1);
      }
    }

    walk(_folders, 0);

    return showModalBottomSheet<ArchiveNode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75,
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'انتخاب پوشهٔ بایگانی',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _createNewArchiveFolder();
                      },
                      icon: const Icon(Icons.create_new_folder_outlined, size: 17),
                      label: const Text('پوشه جدید'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (flat.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'پوشه‌ای وجود ندارد. از دکمهٔ «پوشه جدید» یک پوشه بسازید.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final f in flat)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.only(
                              right: 8.0 + f.depth * 16,
                              left: 8,
                            ),
                            leading: Icon(
                              f.depth == 0
                                  ? Icons.folder_rounded
                                  : Icons.subdirectory_arrow_left_rounded,
                              size: 19,
                              color: _accent,
                            ),
                            title: Text(
                              f.node.title,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onTap: () => Navigator.pop(ctx, f.node),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
    final idx = _boxes.indexOf(b);
    if (idx >= 0) _tabs?.animateTo(idx);
    if (b == LetterBox.archive) _loadFolders();
    _reload();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reload);
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
        builder: (_) => LetterEditorPage(kind: widget.kind, editingId: d.id),
      ),
    );
    if (res != null && mounted) {
      _reload();
      _loadCounts();
    }
  }

  bool _canCreateLetter(WebAccess access) => switch (widget.kind) {
    LetterKind.inner => access.canCreateInnerLetter,
    LetterKind.outgoing => access.canCreateOutgoingLetter,
    LetterKind.incoming => access.canCreateIncomingLetter,
  };

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<AuthController?>(context)?.session;
    final access = WebAccess(session, unrestrictedWhenNull: true);
    if (_boxes.isEmpty) {
      _boxes = _boxesFor(widget.kind, access);
      if (!_boxes.contains(_box)) _box = _boxes.first;
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: OfficeColors.bg,
        floatingActionButton: _canCreateLetter(access)
            ? FloatingActionButton.extended(
                heroTag: 'mailbox_fab_${widget.kind.name}',
                onPressed: _newLetter,
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.edit_square, size: 19),
                label: Text(
                  switch (widget.kind) {
                    LetterKind.inner => 'ثبت نامه داخلی',
                    LetterKind.outgoing => 'پیش‌نویس صادره',
                    LetterKind.incoming => 'ثبت نامه وارده',
                  },
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              )
            : null,
        body: Column(
          children: [
            if (!widget.embedded) _buildHeader(access),
            if (widget.embedded) const SizedBox(height: 6),
            _buildTabs(),
            _buildSearchRow(access),
            if (_box != LetterBox.drafts) _buildFilterAndSortStrip(),
            if (_box == LetterBox.archive) _buildFolderPanel(),
            if (_selectionMode) _buildSelectionBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(WebAccess access) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xffffffff), Color(0xffe9effa)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        border: const Border(
          bottom: BorderSide(color: Color(0xff8a6a24), width: 1.3),
        ),
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
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xff2547a8),
                  side: const BorderSide(color: Color(0xffdce3ee)),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'کارتابل ${widget.kind.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xff173a63),
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'صندوق ${_box.label} • ${Fa.digits(_total)} فقره نامه',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xff5a6a8c),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (access.canSeeDabirkhane &&
                  (widget.kind == LetterKind.outgoing ||
                      widget.kind == LetterKind.incoming))
                IconButton(
                  tooltip: 'دبیرخانه یکپارچه',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OfficeDabirkhanePage(
                          initialMode: widget.kind == LetterKind.incoming
                              ? DabirkhaneMode.varede
                              : DabirkhaneMode.sadere,
                        ),
                      ),
                    );
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xff8a6a24),
                    side: const BorderSide(color: Color(0xffdce3ee)),
                  ),
                  icon: const Icon(Icons.markunread_mailbox_rounded, size: 19),
                ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'راهنمای کارتابل',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const OfficeGuidePage(),
                    ),
                  );
                },
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xff2547a8),
                  side: const BorderSide(color: Color(0xffdce3ee)),
                ),
                icon: const Icon(Icons.help_outline_rounded, size: 19),
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
        height: 54,
        child: OfficeSlidingTabs(
          items: [
            for (final b in _boxes)
              (
                label: widget.kind == LetterKind.outgoing && b == LetterBox.sent
                    ? 'صادره'
                    : b.label,
                icon: b.icon,
                key: b.name,
              ),
          ],
          index: _boxes.indexOf(_box).clamp(0, _boxes.length - 1),
          onChanged: (i) => _selectBox(_boxes[i]),
          pillColor: _accent,
          showCounts: true,
          counts: {
            for (final e in _counts.entries) e.key.name: e.value ?? 0,
          },
        ),
      ),
    );
  }

  Widget _buildSearchRow(WebAccess access) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'جستجوی عنوان، شماره یا فرستنده در ${_box.label}…',
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 19),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          _reload();
                        },
                        icon: const Icon(Icons.close_rounded, size: 17),
                      ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide(color: OfficeColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide(color: OfficeColors.line),
                ),
              ),
            ),
          ),
          if (widget.kind == LetterKind.incoming &&
              access.canCreateIncomingLetter) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: 'پنل دبیرخانه و رزرو شماره اندیکاتور',
              child: Material(
                color: const Color(0xffeff6ff),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const OfficeDabirkhanePage(
                          initialMode: DabirkhaneMode.varede,
                          openReservationsOnStart: true,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xffbfdbfe)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.confirmation_number_outlined,
                          size: 17,
                          color: Color(0xff3357b0),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'اندیکاتور',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xff3357b0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (_canSelect && !_selectionMode) ...[
            const SizedBox(width: 6),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _startSelection,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: OfficeColors.line),
                  ),
                  child: const Icon(Icons.checklist_rounded, size: 18),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterAndSortStrip() {
    const chips = [
      (_CartableChip.all, 'همه', Icons.all_inbox_rounded),
      (_CartableChip.unread, 'خوانده‌نشده', Icons.mark_email_unread_outlined),
      (_CartableChip.starred, 'نشان‌شده', Icons.star_outline_rounded),
      (_CartableChip.urgent, 'فوری / آنی', Icons.bolt_rounded),
      (_CartableChip.deadline, 'مهلت‌دار', Icons.schedule_rounded),
      (_CartableChip.attachment, 'پیوست‌دار', Icons.attach_file_rounded),
    ];

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          PopupMenuButton<_CartableSort>(
            tooltip: 'مرتب‌سازی',
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _CartableSort.newest,
                child: Text('جدیدترین تاریخ'),
              ),
              PopupMenuItem(
                value: _CartableSort.oldest,
                child: Text('قدیمی‌ترین تاریخ'),
              ),
              PopupMenuItem(
                value: _CartableSort.urgent,
                child: Text('بیشترین فوریت'),
              ),
              PopupMenuItem(
                value: _CartableSort.confidential,
                child: Text('بیشترین محرمانگی'),
              ),
              PopupMenuItem(
                value: _CartableSort.number,
                child: Text('شماره نامه'),
              ),
              PopupMenuItem(
                value: _CartableSort.title,
                child: Text('عنوان نامه'),
              ),
            ],
            child: Container(
              margin: const EdgeInsets.only(left: 6, top: 3, bottom: 3),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: OfficeColors.line),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort_rounded, size: 15),
                  SizedBox(width: 4),
                  Text(
                    'مرتب‌سازی',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
          for (final (chip, label, icon) in chips)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 3, bottom: 3),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  final prevUnread = _unreadOnly;
                  setState(() => _activeChip = chip);
                  if (prevUnread != _unreadOnly) _reload();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _activeChip == chip
                        ? _accent
                        : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _activeChip == chip ? _accent : OfficeColors.line,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: _activeChip == chip
                            ? Colors.white
                            : const Color(0xff44547a),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _activeChip == chip
                              ? Colors.white
                              : const Color(0xff2c3a58),
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

  Widget _buildSelectionBar() {
    final count = _selectedErja.length + _selectedLetter.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 17, color: _accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${Fa.digits(count)} نامه انتخاب شده',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _accent,
              ),
            ),
          ),
          TextButton(
            onPressed: _selectAll,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('همه', style: TextStyle(fontSize: 11.5)),
          ),
          FilledButton.icon(
            onPressed: count == 0 ? null : _archiveSelected,
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: const Icon(Icons.inventory_2_outlined, size: 15),
            label: const Text(
              'بایگانی',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: _clearSelection,
            visualDensity: VisualDensity.compact,
            tooltip: 'انصراف',
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: OfficeColors.line),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: _accent.withValues(alpha: 0.06),
          ),
          child: ExpansionTile(
            key: ValueKey('folders_${widget.kind.name}_${_folders.length}'),
            initiallyExpanded: _foldersOpen,
            onExpansionChanged: (v) => _foldersOpen = v,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            leading: Icon(
              Icons.account_tree_rounded,
              size: 19,
              color: _accent,
            ),
            title: Text(
              'درخت پوشه‌های بایگانی (${Fa.digits(_buildFolderRows(_folders).length)})',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            trailing: IconButton(
              tooltip: 'پوشه جدید',
              onPressed: _createNewArchiveFolder,
              icon: Icon(
                Icons.create_new_folder_outlined,
                size: 19,
                color: _accent,
              ),
            ),
            children: [
              if (_folders.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'هنوز پوشه‌ای ساخته نشده است.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xff66779c)),
                  ),
                ),
              for (final row in _buildFolderRows(_folders))
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: EdgeInsets.only(
                    right: 14.0 + row.depth * 18,
                    left: 10,
                  ),
                  leading: Icon(
                    row.node.isFolder || row.node.children.isNotEmpty
                        ? Icons.folder_rounded
                        : Icons.insert_drive_file_outlined,
                    size: 18,
                    color: _accent,
                  ),
                  title: Text(
                    row.node.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: row.node.letterCount > 0
                      ? Text(
                          '${Fa.digits(row.node.letterCount)} نامه',
                          style: const TextStyle(fontSize: 10.5),
                        )
                      : null,
                  trailing: IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'بایگانی موارد انتخاب‌شده در این پوشه',
                    onPressed: () async {
                      final selected =
                          _selectedErja.length + _selectedLetter.length;
                      if (selected == 0) {
                        showMessage(
                          context,
                          'ابتدا از لیست، نامه‌ها را انتخاب کنید.',
                          error: true,
                        );
                        return;
                      }
                      try {
                        await _repo.archiveLetters(
                          widget.kind,
                          folderId: row.node.id,
                          erjaIds: _selectedErja.toList(),
                          letterIds: _selectedLetter.toList(),
                        );
                        if (!mounted) return;
                        showMessage(
                          context,
                          '${Fa.digits(selected)} نامه در «${row.node.title}» بایگانی شد.',
                        );
                        _clearSelection();
                        await _reload();
                        await _loadFolders();
                      } catch (e) {
                        if (mounted) {
                          showMessage(context, e.toString(), error: true);
                        }
                      }
                    },
                    icon: const Icon(Icons.move_to_inbox_rounded, size: 17),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<({ArchiveNode node, int depth})> _buildFolderRows(
    List<ArchiveNode> nodes,
  ) {
    final flat = <({ArchiveNode node, int depth})>[];
    void walk(List<ArchiveNode> list, int depth) {
      for (final n in list) {
        flat.add((node: n, depth: depth));
        if (n.children.isNotEmpty) walk(n.children, depth + 1);
      }
    }

    walk(nodes, 0);
    return flat;
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
        return _empty('پیش‌نویسی در این کارتابل وجود ندارد');
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
    final list = _visibleItems;
    if (list.isEmpty) {
      return _empty(
        _activeChip != _CartableChip.all
            ? 'نامه‌ای با فیلتر انتخابی در ${_box.label} یافت نشد'
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
          itemCount: list.length + (_loadingMore || _hasMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i >= list.length) {
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
            final it = list[i];
            final tile = LetterTile(
              item: it,
              kind: widget.kind,
              onNeshan: (it.erjaId ?? 0) > 0 ? () => _toggleStar(it) : null,
              onTap: () => _selectionMode ? _toggleSelect(it) : _openDetail(it),
            );
            if (!_selectionMode) return tile;
            final selected = _isSelected(it);
            return Container(
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: selected ? _accent.withValues(alpha: 0.06) : null,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? _accent.withValues(alpha: 0.4)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: selected,
                    activeColor: _accent,
                    onChanged: (_) => _toggleSelect(it),
                  ),
                  Expanded(child: tile),
                ],
              ),
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
        padding: const EdgeInsets.fromLTRB(24, 52, 24, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: OfficeColors.line),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(_box.icon, size: 28, color: _accent),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
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
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OfficeColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.drafts_rounded, size: 20, color: accent),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      draft.text.trim().isEmpty ? 'بدون متن' : draft.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: OfficeColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_outlined, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}
