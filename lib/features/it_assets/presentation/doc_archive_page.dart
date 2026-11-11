// ============================================================
//  «آرشیو اسناد و مدارک» — فاز ۹-ح (بخش ۱)
//  آینهٔ `Pages/DocArchive/DocArchiveExplorer.razor` (مسیر وب: /doc-archive)
//
//  ساختار وب → موبایل:
//   • سرصفحهٔ «آرشیو اسناد و مدارک» / «مدارک غیرفعال» / «سطل بازیافت»
//     + دکمهٔ «مدرک جدید» (F2) + «پوشه جدید» (گیت DocArchive.Create)
//   • سه تب: «همه مدارک» / «ستاره‌دارها» / «اخیراً دیده‌شده»
//   • جستجو «جستجوی اسناد…» با دکمهٔ پاک‌کردن
//   • درخت پوشه‌ها با شمارندهٔ هر پوشه + میان‌برهای «منقضی شده»،
//     «رو به انقضا»، «مدارک غیرفعال»، «سطل بازیافت» (با شمارنده)
//   • فیلترهای پیشرفته: وضعیت انقضا، شامل زیرپوشه‌ها، برچسب‌ها، نوع فایل
//   • کارت هر مدرک: کد، نشان سطح دسترسی، عنوان، پوشه، نسخه‌ها،
//     وضعیت آخرین نسخه، برچسب‌ها، سرنخ انقضا و ستاره‌دار کردن
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/auth/auth_controller.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/doc_archive_repository.dart';
import '../data/it_perms.dart';
import '../models/doc_archive_models.dart';
import 'doc_archive_cartable_page.dart';
import 'doc_archive_detail_page.dart';
import 'doc_import_page.dart';
import 'doc_search_page.dart';
import 'doc_archive_form_page.dart';
import 'system_style.dart';

enum DocTab { all, fav, recent }

enum DocStatusFilter { active, inactive, deleted }

class DocArchivePage extends StatefulWidget {
  const DocArchivePage({super.key});

  @override
  State<DocArchivePage> createState() => _DocArchivePageState();
}

class _DocArchivePageState extends State<DocArchivePage> {
  late final DocArchiveRepository _repo;

  DocTab _tab = DocTab.all;
  DocStatusFilter _status = DocStatusFilter.active;
  int? _folderId;
  String? _expiryFilter;

  /// پوشه‌های باز‌شده در درخت
  final Set<int> _expandedFolders = {}; // expiring | expired
  bool _includeSubfolders = true;

  final _search = TextEditingController();
  Timer? _searchDelay;

  bool _loading = true;
  String? _error;

  List<DocRow> _docs = const [];
  int _total = 0;
  int _skip = 0;
  static const _pageSize = 30;

  List<DocFolder> _folders = const [];
  List<DocTag> _tags = const [];
  List<DocFavorite> _favorites = const [];
  List<DocRecent> _recent = const [];
  DocArchiveStats _stats = const DocArchiveStats();

  final Set<int> _selectedTagIds = {};

  /// انتخاب چندگانهٔ مدارک برای عملیات گروهی (فاز ۹-ط)
  final Set<int> _selectedIds = {};
  bool _selecting = false;
  bool _bulkBusy = false;
  bool _isManager = false;

  @override
  void initState() {
    super.initState();
    _repo = DocArchiveRepository(context.read<ApiClient>());
    final perms = ItPerms(context.read<AuthController>().session);
    _isManager = perms.has('DocArchive.Manage');
    _bootstrap();
  }

  @override
  void dispose() {
    _searchDelay?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.folders(take: 500),
        _repo.stats(),
        _repo.tags(),
      ]);
      if (!mounted) return;
      setState(() {
        _folders = (results[0] as DocPage<DocFolder>).items;
        _stats = results[1] as DocArchiveStats;
        _tags = results[2] as List<DocTag>;
        _error = null;
      });
      await _loadDocs();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'ارتباط با سرور برقرار نشد — ${_clean(e)}';
      });
    }
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '')
      .trim();

  String get _statusParam => switch (_status) {
    DocStatusFilter.active => 'active',
    DocStatusFilter.inactive => 'inactive',
    DocStatusFilter.deleted => 'all',
  };

  Future<void> _loadDocs({bool reset = true}) async {
    if (reset) _skip = 0;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _repo.documents(
        folderId: _folderId,
        search: _search.text,
        status: _statusParam,
        expiry: _expiryFilter,
        skip: _skip,
        take: _pageSize,
      );
      if (!mounted) return;
      var items = page.items;
      // سطل بازیافت و غیرفعال‌ها با فیلتر وضعیت سرور جدا می‌شوند؛
      // برای «همه» فقط فعال‌ها می‌آیند، پس فیلتر محلی لازم نیست جز حالت deleted.
      if (_status == DocStatusFilter.deleted) {
        items = items.where((d) => d.isDeleted).toList();
      } else if (_status == DocStatusFilter.inactive) {
        items = items.where((d) => !d.isDeleted && !d.isActive).toList();
      }
      setState(() {
        _docs = items;
        _total = page.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'بارگذاری مدارک ناموفق بود — ${_clean(e)}';
      });
    }
  }

  Future<void> _loadFavorites() async {
    setState(() => _loading = true);
    try {
      final favs = await _repo.favorites(take: 50);
      if (!mounted) return;
      setState(() {
        _favorites = favs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'بارگذاری ستاره‌دارها ناموفق بود — ${_clean(e)}';
      });
    }
  }

  Future<void> _loadRecent() async {
    setState(() => _loading = true);
    try {
      final rows = await _repo.recentlyViewed(take: 10);
      if (!mounted) return;
      setState(() {
        _recent = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'بارگذاری اخیر ناموفق بود — ${_clean(e)}';
      });
    }
  }

  void _switchTab(DocTab t) {
    setState(() => _tab = t);
    switch (t) {
      case DocTab.all:
        _loadDocs();
      case DocTab.fav:
        _loadFavorites();
      case DocTab.recent:
        _loadRecent();
    }
  }

  void _onSearchChanged(String _) {
    _searchDelay?.cancel();
    _searchDelay = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _loadDocs();
    });
  }

  void _toggleFavorite(DocRow d) async {
    try {
      await _repo.toggleFavorite(d.id);
      if (!mounted) return;
      if (_tab == DocTab.fav) {
        await _loadFavorites();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('وضعیت ستاره‌دار تغییر کرد.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_clean(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String get _title => switch (_status) {
    DocStatusFilter.inactive => 'مدارک غیرفعال',
    DocStatusFilter.deleted => 'سطل بازیافت',
    DocStatusFilter.active => 'آرشیو اسناد و مدارک',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: Text(
          _title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'جستجوی هوشمند',
            icon: const Icon(Icons.manage_search_rounded, size: 20),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DocSearchPage(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'کارتابل آرشیو',
            icon: const Icon(Icons.move_to_inbox_rounded, size: 19),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DocArchiveCartablePage(),
              ),
            ),
          ),
          IconButton(
            tooltip: _selecting ? 'پایان انتخاب' : 'انتخاب گروهی',
            icon: Icon(
              _selecting
                  ? Icons.close_rounded
                  : Icons.checklist_rounded,
              size: 20,
            ),
            onPressed: () => setState(() {
              _selecting = !_selecting;
              if (!_selecting) _selectedIds.clear();
            }),
          ),
          IconButton(
            tooltip: 'برچسب‌ها',
            icon: const Icon(Icons.local_offer_rounded, size: 19),
            onPressed: _manageTags,
          ),
          IconButton(
            tooltip: 'ورود انبوه آرشیو',
            icon: const Icon(Icons.folder_copy_rounded, size: 19),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DocImportPage(folders: _folders),
              ),
            ),
          ),
          IconButton(
            tooltip: 'پوشه جدید',
            icon: const Icon(Icons.create_new_folder_rounded, size: 20),
            onPressed: _openNewFolder,
          ),
          IconButton(
            tooltip: 'مدرک جدید',
            icon: const Icon(Icons.add_rounded, size: 20),
            // گیت وب: «مدرک جدید» فقط در وضعیت فعال
            onPressed: _status == DocStatusFilter.active ? _openNewDoc : null,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _bootstrap();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 26),
          children: [
            const ShopHeader(
              title: 'آرشیو اسناد و مدارک',
              subtitle: 'پوشه‌ها، نسخه‌ها و گردش تأیید مدارک',
              icon: Icons.folder_open_rounded,
              badge: 'DMS',
            ),
            const SizedBox(height: 10),
            ShopSegmented(
              labels: const ['همه مدارک', 'ستاره‌دارها', 'اخیراً دیده‌شده'],
              index: _tab.index,
              onChanged: (i) => _switchTab(DocTab.values[i]),
            ),
            const SizedBox(height: 8),
            if (_error != null) ...[
              SystemNote(
                text: _error!,
                color: ShopColors.danger,
                icon: Icons.error_outline_rounded,
              ),
              const SizedBox(height: 8),
            ],
            if (_tab == DocTab.all) ...[
              _searchBar(),
              const SizedBox(height: 8),
              _foldersCard(),
              const SizedBox(height: 8),
              _filtersRow(),
              const SizedBox(height: 8),
              if (_selecting) ...[
                _selectionBar(),
                const SizedBox(height: 8),
              ],
              if (_status == DocStatusFilter.deleted &&
                  _isManager &&
                  _docs.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ShopColors.danger,
                      side: BorderSide(
                        color: ShopColors.danger.withValues(alpha: 0.5),
                      ),
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(19),
                      ),
                    ),
                    onPressed: _emptyTrash,
                    icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                    label: const Text(
                      'خالی کردن سطل',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              _countRow(),
              const SizedBox(height: 6),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_docs.isEmpty)
                const SystemNote(
                  text: 'مدرکی یافت نشد',
                  icon: Icons.file_present_rounded,
                )
              else ...[
                for (final d in _docs) _docCard(d),
                if (_total > _skip + _docs.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _skip += _pageSize;
                        _loadDocs(reset: false);
                      },
                      icon: const Icon(Icons.expand_more_rounded, size: 17),
                      label: Text(
                        'موارد بیشتر (${Fa.digits(_total - _skip - _docs.length)})',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
              ],
            ] else if (_tab == DocTab.fav) ...[
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_favorites.isEmpty)
                const SystemNote(
                  text: 'هنوز مدرکی را ستاره‌دار نکرده‌اید',
                  icon: Icons.star_border_rounded,
                )
              else
                for (final f in _favorites)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ShopColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ShopColors.line),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${f.code} — ${f.title}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${f.folderCell} · ${Fa.date(f.favoritedAt?.toIso8601String())}',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  color: ShopColors.inkFaint,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'حذف از ستاره‌دارها',
                          icon: const Icon(
                            Icons.star_rounded,
                            size: 19,
                            color: Colors.amber,
                          ),
                          onPressed: () async {
                            await _repo.toggleFavorite(f.documentId);
                            if (mounted) await _loadFavorites();
                          },
                        ),
                      ],
                    ),
                  ),
            ] else ...[
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_recent.isEmpty)
                const SystemNote(
                  text: 'هنوز مدرکی را باز نکرده‌اید',
                  icon: Icons.history_rounded,
                )
              else ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text(
                    'اخیراً دیده‌شده (۱۰ مورد آخر)',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                for (final r in _recent)
                  InkWell(
                    onTap: () => _openDoc(r.documentId),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ShopColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ShopColors.line),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${r.code} — ${r.title}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${r.folderCell} · ${Fa.date(r.viewedAt?.toIso8601String())}',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    color: ShopColors.inkFaint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_left_rounded,
                            size: 18,
                            color: ShopColors.inkFaint,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openNewDoc() async {
    if (_folders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('پوشه مدرک را انتخاب کنید.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DocArchiveFormPage(
          folders: _folders,
          tags: _tags,
          numberingEnabled: true,
          defaultFolderId: _folderId,
        ),
      ),
    );
    if (created == true) await _loadDocs();
  }

  void _openDoc(int id) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => DocArchiveDetailPage(id: id)),
    );
    if (mounted) await _loadDocs();
  }

  Widget _searchBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ShopColors.line),
    ),
    child: Row(
      children: [
        const Icon(Icons.search_rounded, size: 17, color: ShopColors.inkFaint),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: _search,
            onChanged: _onSearchChanged,
            style: const TextStyle(fontSize: 11.5),
            decoration: const InputDecoration(
              hintText: 'جستجوی اسناد…',
              hintStyle: TextStyle(
                fontSize: 10.5,
                color: ShopColors.inkFaint,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        if (_search.text.isNotEmpty)
          IconButton(
            tooltip: 'پاک کردن جستجو',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.close_rounded,
              size: 16,
              color: ShopColors.inkFaint,
            ),
            onPressed: () {
              _search.clear();
              _loadDocs();
              setState(() {});
            },
          ),
      ],
    ),
  );

  Widget _foldersCard() => Container(
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ShopColors.line),
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        initiallyExpanded: false,
        leading: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ShopColors.seed.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(
            Icons.account_tree_rounded,
            size: 16,
            color: ShopColors.seed,
          ),
        ),
        title: const Text(
          'پوشه‌ها',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          _folderId == null
              ? 'همه مدارک'
              : folderPathText(_folders, _folderId!),
          style: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
        ),
        children: [
          _shortcut(
            icon: Icons.archive_rounded,
            label: 'همه مدارک',
            count: null,
            color: ShopColors.seed,
            active:
                _status == DocStatusFilter.active &&
                _folderId == null &&
                _expiryFilter == null,
            onTap: () {
              setState(() {
                _status = DocStatusFilter.active;
                _folderId = null;
                _expiryFilter = null;
              });
              _loadDocs();
            },
          ),
          _shortcut(
            icon: Icons.event_busy_rounded,
            label: 'منقضی شده',
            count: _stats.expired,
            color: ShopColors.danger,
            active: _expiryFilter == 'expired',
            onTap: () {
              setState(() {
                _status = DocStatusFilter.active;
                _expiryFilter = 'expired';
                _folderId = null;
              });
              _loadDocs();
            },
          ),
          _shortcut(
            icon: Icons.hourglass_bottom_rounded,
            label: 'رو به انقضا',
            count: _stats.expiring,
            color: ShopColors.warn,
            active: _expiryFilter == 'expiring',
            onTap: () {
              setState(() {
                _status = DocStatusFilter.active;
                _expiryFilter = 'expiring';
                _folderId = null;
              });
              _loadDocs();
            },
          ),
          _shortcut(
            icon: Icons.inventory_2_rounded,
            label: 'مدارک غیرفعال',
            count: _stats.inactive,
            color: ShopColors.inkSoft,
            active: _status == DocStatusFilter.inactive,
            onTap: () {
              setState(() {
                _status = DocStatusFilter.inactive;
                _expiryFilter = null;
                _folderId = null;
              });
              _loadDocs();
            },
          ),
          _shortcut(
            icon: Icons.delete_outline_rounded,
            label: 'سطل بازیافت',
            count: _stats.deleted,
            color: ShopColors.danger,
            active: _status == DocStatusFilter.deleted,
            onTap: () {
              setState(() {
                _status = DocStatusFilter.deleted;
                _expiryFilter = null;
                _folderId = null;
              });
              _loadDocs();
            },
          ),
          const Divider(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'پوشه‌ها (سلسله‌مراتبی)',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: ShopColors.inkSoft,
                    ),
                  ),
                ),
                Text(
                  '${Fa.digits(_folders.length)} پوشه',
                  style: const TextStyle(
                    fontSize: 8.5,
                    color: ShopColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          ..._folderTreeNodes(buildFolderTree(_folders)),
        ],
      ),
    ),
  );

  /// رندر بازگشتی درخت پوشه‌ها — زیرمجموعه‌ها با تودرتویی و راهنمای خط
  List<Widget> _folderTreeNodes(List<DocFolderNode> nodes) {
    final out = <Widget>[];
    for (final n in nodes) {
      final hasKids = n.children.isNotEmpty;
      final expanded = _expandedFolders.contains(n.id);
      out.add(
        Padding(
          padding: EdgeInsets.only(right: n.depth * 14.0),
          child: Row(
            children: [
              if (hasKids)
                InkWell(
                  onTap: () => setState(() {
                    if (expanded) {
                      _expandedFolders.remove(n.id);
                    } else {
                      _expandedFolders.add(n.id);
                    }
                  }),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      expanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_left_rounded,
                      size: 15,
                      color: ShopColors.inkFaint,
                    ),
                  ),
                )
              else
                const SizedBox(width: 19),
              Expanded(
                child: _shortcut(
                  icon: hasKids
                      ? (expanded
                            ? Icons.folder_open_rounded
                            : Icons.folder_rounded)
                      : Icons.folder_outlined,
                  label: n.name,
                  count: n.folder.documentCount,
                  color: ShopColors.seed,
                  active: _folderId == n.id,
                  level: n.folder.levelName,
                  onTap: () {
                    setState(() {
                      _folderId = n.id;
                      _status = DocStatusFilter.active;
                      _expiryFilter = null;
                      if (hasKids) _expandedFolders.add(n.id);
                    });
                    _loadDocs();
                  },
                ),
              ),
              if (n.folder.myLevel >= DocLevel.full)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 26,
                  ),
                  tooltip: 'تنظیمات پوشه',
                  icon: const Icon(
                    Icons.settings_rounded,
                    size: 14,
                    color: ShopColors.inkFaint,
                  ),
                  onPressed: () => _editFolderSettings(n.folder),
                ),
            ],
          ),
        ),
      );
      out.addAll(_folderTreeNodes(n.children));
    }
    return out;
  }

  Future<void> _editFolderSettings(DocFolder f) async {
    // «چرخ‌دندهٔ پوشه» در وب فقط برای سطح «کامل» باز است
    final name = TextEditingController(text: f.name);
    final description = TextEditingController(text: f.description ?? '');
    var isPublic = f.isPublic;
    var publicCanDownload = f.publicCanDownload;
    var busy = false;
    final res = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: Text(
            'تنظیمات پوشه «${f.name}»',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: name,
                  style: const TextStyle(fontSize: 11),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'نام پوشه',
                    labelStyle: TextStyle(fontSize: 9),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: description,
                  style: const TextStyle(fontSize: 11),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'توضیح',
                    labelStyle: TextStyle(fontSize: 9),
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: isPublic,
                  onChanged: (v) => setLocal(() => isPublic = v),
                  title: const Text(
                    'نمایش برای همه',
                    style: TextStyle(fontSize: 10.5),
                  ),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: publicCanDownload,
                  onChanged: isPublic
                      ? (v) => setLocal(() => publicCanDownload = v)
                      : null,
                  title: const Text(
                    'اجازهٔ دانلود برای همه',
                    style: TextStyle(fontSize: 10.5),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.of(c).pop(false),
              child: const Text('انصراف', style: TextStyle(fontSize: 11)),
            ),
            FilledButton(
              onPressed: busy ? null : () => Navigator.of(c).pop(true),
              child: const Text('ذخیره', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
    if (res != true) return;
    try {
      await _repo.updateFolder(
        id: f.id,
        name: name.text.trim(),
        description: description.text.trim(),
        isPublic: isPublic,
        publicCanDownload: publicCanDownload,
      );
      _toast('تنظیمات پوشه ذخیره شد.');
      await _bootstrap();
    } catch (e) {
      _toast(
        e
            .toString()
            .replaceFirst('ApiException: ', '')
            .replaceFirst('Exception: ', '')
            .trim(),
        error: true,
      );
    }
  }

  Widget _shortcut({
    required IconData icon,
    required String label,
    required int? count,
    required Color color,
    required bool active,
    required VoidCallback onTap,
    String? level,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(9),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.10) : null,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                color: ShopColors.ink,
              ),
            ),
          ),
          if (level != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                level,
                style: const TextStyle(
                  fontSize: 8.5,
                  color: ShopColors.inkFaint,
                ),
              ),
            ),
          if (count != null && count > 0)
            ShopTag(text: Fa.digits(count), color: color),
        ],
      ),
    ),
  );

  Widget _filtersRow() => Row(
    children: [
      Expanded(
        child: DropdownButtonFormField<String?>(
          initialValue: _expiryFilter,
          isDense: true,
          style: const TextStyle(fontSize: 11, color: ShopColors.ink),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: ShopColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: ShopColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: ShopColors.line),
            ),
          ),
          items: const [
            DropdownMenuItem(value: null, child: Text('همه وضعیت‌ها')),
            DropdownMenuItem(value: 'expiring', child: Text('رو به انقضا')),
            DropdownMenuItem(value: 'expired', child: Text('منقضی شده')),
            DropdownMenuItem(value: 'all', child: Text('منقضی + رو به انقضا')),
          ],
          onChanged: (v) {
            setState(() => _expiryFilter = v);
            _loadDocs();
          },
        ),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: ShopColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'شامل زیرپوشه‌ها',
              style: TextStyle(fontSize: 9.5, color: ShopColors.inkSoft),
            ),
            Switch(
              value: _includeSubfolders,
              onChanged: (v) {
                setState(() => _includeSubfolders = v);
                _loadDocs();
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    ],
  );

  Widget _countRow() => Row(
    children: [
      ShopTag(
        text: '${Fa.digits(_total)} مدرک',
        color: ShopColors.seed,
        icon: Icons.description_rounded,
      ),
      const Spacer(),
      if (_tags.isNotEmpty)
        TextButton.icon(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 30),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: _pickTags,
          icon: const Icon(Icons.local_offer_rounded, size: 14),
          label: Text(
            _selectedTagIds.isEmpty
                ? 'برچسب‌ها'
                : 'برچسب‌ها (${Fa.digits(_selectedTagIds.length)})',
            style: const TextStyle(fontSize: 10),
          ),
        ),
    ],
  );

  Future<void> _pickTags() async {
    final picked = await showModalBottomSheet<Set<int>>(
      context: context,
      backgroundColor: ShopColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (c) {
        final sel = {..._selectedTagIds};
        return StatefulBuilder(
          builder: (c, setLocal) => Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'برچسب‌ها',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in _tags)
                      FilterChip(
                        label: Text(
                          t.name,
                          style: const TextStyle(fontSize: 10),
                        ),
                        selected: sel.contains(t.id),
                        onSelected: (v) => setLocal(() {
                          if (v) {
                            sel.add(t.id);
                          } else {
                            sel.remove(t.id);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(c).pop(<int>{}),
                        child: const Text(
                          'پاک کردن',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(c).pop(sel),
                        child: const Text(
                          'اعمال',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTagIds
          ..clear()
          ..addAll(picked);
      });
    }
  }

  Widget _docCard(DocRow d) {
    final expired = d.isExpired;
    final soon = d.isExpiringSoon;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _selecting
                ? () => setState(() {
                    if (!_selectedIds.remove(d.id)) _selectedIds.add(d.id);
                  })
                : () => _openDoc(d.id),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(13),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 6, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              d.code,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: ShopColors.inkFaint,
                              ),
                            ),
                            const SizedBox(width: 6),
                            ShopTag(
                              text: d.levelName,
                              color: docLevelColor(d.myLevel),
                            ),
                            if (d.versionCount > 0) ...[
                              const SizedBox(width: 4),
                              ShopTag(
                                text: d.activeVersionText,
                                color: ShopColors.seed,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          d.title,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${d.folderCell} · ${d.createdByName} · ${Fa.date(d.createdAt?.toIso8601String())}',
                          style: const TextStyle(
                            fontSize: 9,
                            color: ShopColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selecting)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 2),
                      child: Icon(
                        _selectedIds.contains(d.id)
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 20,
                        color: _selectedIds.contains(d.id)
                            ? ShopColors.ok
                            : ShopColors.inkFaint,
                      ),
                    )
                  else
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: const Icon(
                        Icons.star_border_rounded,
                        size: 18,
                        color: Colors.amber,
                      ),
                      onPressed: () => _toggleFavorite(d),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 0, 11, 9),
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ShopTag(
                  text: DocVersionStatus.nameExplorer(d.lastVersionStatus),
                  color: docVersionColor(d.lastVersionStatus),
                ),
                if (expired)
                  ShopTag(text: 'منقضی شده', color: ShopColors.danger)
                else if (d.daysToExpire != null)
                  ShopTag(
                    text: d.expiryText,
                    color: soon ? ShopColors.warn : ShopColors.inkFaint,
                    icon: Icons.event_rounded,
                  ),
                if (!d.isActive)
                  const ShopTag(
                    text: 'غیرفعال',
                    color: ShopColors.inkFaint,
                  ),
                if (d.isDeleted)
                  const ShopTag(text: 'در سطل', color: ShopColors.danger),
                if (d.isPublic)
                  const ShopTag(text: 'نمایش برای همه', color: ShopColors.teal),
                if (d.linkCount > 0)
                  ShopTag(
                    text: '${Fa.digits(d.linkCount)} مرتبط',
                    color: ShopColors.seed,
                    icon: Icons.link_rounded,
                  ),
                for (final t in d.tags.take(3))
                  ShopTag(text: t.name, color: colorFromHex(t.color)),
              ],
            ),
          ),
          if (_status == DocStatusFilter.deleted)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 7),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: ShopColors.ok,
                        minimumSize: const Size(0, 32),
                      ),
                      onPressed: () => _restore(d),
                      icon: const Icon(Icons.restore_rounded, size: 15),
                      label: const Text(
                        'بازگرداندن',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  if (_isManager)
                    Expanded(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: ShopColors.danger,
                          minimumSize: const Size(0, 32),
                        ),
                        onPressed: () => _purgeOne(d),
                        icon: const Icon(Icons.delete_forever_rounded, size: 15),
                        label: const Text(
                          'حذف قطعی',
                          style: TextStyle(fontSize: 10),
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

  // ============================================================
  //  فاز ۹-ط — عملیات گروهی، سطل بازیافت، پوشه و برچسب
  // ============================================================

  void _toast(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? ShopColors.danger : null,
      ),
    );
  }

  Widget _selectionBar() => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: ShopColors.seed.withValues(alpha: 0.4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ShopTag(
              text: '${Fa.digits(_selectedIds.length)} انتخاب شده',
              color: ShopColors.seed,
              icon: Icons.checklist_rounded,
            ),
            const SizedBox(width: 6),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 26),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: () => setState(_selectedIds.clear),
              child: const Text(
                'پاک کردن انتخاب',
                style: TextStyle(fontSize: 9.5),
              ),
            ),
            const Spacer(),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 26),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: () => setState(() {
                if (_selectedIds.length == _docs.length) {
                  _selectedIds.clear();
                } else {
                  _selectedIds
                    ..clear()
                    ..addAll(_docs.map((d) => d.id));
                }
              }),
              child: Text(
                _selectedIds.length == _docs.length ? 'لغو همه' : 'انتخاب همه',
                style: const TextStyle(fontSize: 9.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _bulkButton(
              label: 'انتقال پوشه',
              icon: Icons.drive_file_move_rounded,
              onTap: _bulkMove,
            ),
            _bulkButton(
              label: 'برچسب گروهی',
              icon: Icons.local_offer_rounded,
              onTap: _bulkTags,
            ),
            _bulkButton(
              label: 'تمدید انقضا',
              icon: Icons.event_repeat_rounded,
              onTap: _bulkExpire,
            ),
            _bulkButton(
              label: 'حذف گروهی',
              icon: Icons.delete_outline_rounded,
              danger: true,
              onTap: _bulkDelete,
            ),
          ],
        ),
      ],
    ),
  );

  Widget _bulkButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? ShopColors.danger : ShopColors.seed;
    return OutlinedButton.icon(
      onPressed: _bulkBusy || _selectedIds.isEmpty ? null : onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.45)),
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: _bulkBusy
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.8),
            )
          : Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 9.5)),
    );
  }

  Future<void> _afterBulk() async {
    setState(() => _selectedIds.clear());
    await _loadDocs();
    await _reloadSide();
  }

  Future<void> _reloadSide() async {
    try {
      final results = await Future.wait([
        _repo.folders(take: 500),
        _repo.stats(),
      ]);
      if (!mounted) return;
      setState(() {
        _folders = (results[0] as DocPage<DocFolder>).items;
        _stats = results[1] as DocArchiveStats;
      });
    } catch (_) {}
  }

  String _cleanErr(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '')
      .trim();

  Future<void> _bulkMove() async {
    final targets = _folders.where((f) => f.canWrite).toList();
    if (targets.isEmpty) {
      _toast('پوشه‌ای با دسترسی نوشتن برای انتقال وجود ندارد.');
      return;
    }
    var target = 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text(
            'انتقال گروهی به پوشه',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'انتقال ${Fa.digits(_selectedIds.length)} مدرک انتخاب‌شده به پوشه جدید:',
                style: const TextStyle(fontSize: 10.5, height: 1.8),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: target == 0 ? null : target,
                isDense: true,
                style: const TextStyle(fontSize: 11, color: ShopColors.ink),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xfff9fbfe),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: [
                  for (final f in targets)
                    DropdownMenuItem(
                      value: f.id,
                      child: Text(
                        folderPathText(_folders, f.id),
                        style: const TextStyle(fontSize: 10.5),
                      ),
                    ),
                ],
                onChanged: (v) => setLocal(() => target = v ?? 0),
              ),
              const SizedBox(height: 8),
              Text(
                kBulkMoveWarning,
                style: const TextStyle(
                  fontSize: 9,
                  height: 1.8,
                  color: ShopColors.warn,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('انصراف', style: TextStyle(fontSize: 11)),
            ),
            FilledButton(
              onPressed: target > 0 ? () => Navigator.of(c).pop(true) : null,
              child: const Text('انتقال', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _runBulk(
      () => _repo.bulkMove(
        ids: _selectedIds.toList(),
        targetFolderId: target,
      ),
    );
  }

  Future<void> _bulkTags() async {
    if (_tags.isEmpty) {
      _toast('برچسبی تعریف نشده است.');
      return;
    }
    final sel = <int>{};
    var mode = DocBulkTagMode.append;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text(
            'برچسب گروهی',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${Fa.digits(_selectedIds.length)} مدرک انتخاب شده',
                style: const TextStyle(
                  fontSize: 10,
                  color: ShopColors.inkFaint,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in _tags)
                    FilterChip(
                      label: Text(
                        t.name,
                        style: const TextStyle(fontSize: 9.5),
                      ),
                      selected: sel.contains(t.id),
                      onSelected: (v) => setLocal(() {
                        if (v) {
                          sel.add(t.id);
                        } else {
                          sel.remove(t.id);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ShopSegmented(
                labels: [for (final m in kDocBulkTagModes) m.value],
                index: mode == DocBulkTagMode.append ? 0 : 1,
                onChanged: (i) => setLocal(
                  () => mode = i == 0
                      ? DocBulkTagMode.append
                      : DocBulkTagMode.replace,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('انصراف', style: TextStyle(fontSize: 11)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('اعمال', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _runBulk(
      () => _repo.bulkTags(ids: _selectedIds.toList(), tagIds: sel.toList(), mode: mode),
    );
  }

  Future<void> _bulkExpire() async {
    DateTime? date;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text(
            'تمدید انقضای گروهی',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تاریخ انقضای ${Fa.digits(_selectedIds.length)} مدرک به:',
                style: const TextStyle(fontSize: 10.5),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  foregroundColor: ShopColors.ink,
                ),
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: c,
                    initialDate: date ?? now,
                    firstDate: DateTime(now.year - 20),
                    lastDate: DateTime(now.year + 30),
                  );
                  if (picked != null) setLocal(() => date = picked);
                },
                icon: const Icon(Icons.event_rounded, size: 15),
                label: Text(
                  date == null
                      ? 'بدون انقضا (حذف تاریخ)'
                      : Fa.date(date!.toIso8601String(), time: false),
                  style: const TextStyle(fontSize: 10.5),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'اگر خالی بگذارید تاریخ انقضا حذف می‌شود.',
                style: TextStyle(fontSize: 9, color: ShopColors.inkFaint),
              ),
            ],
          ),
          actions: [
            if (date != null)
              TextButton(
                onPressed: () => setLocal(() => date = null),
                child: const Text(
                  'پاک کردن تاریخ',
                  style: TextStyle(fontSize: 10),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('انصراف', style: TextStyle(fontSize: 11)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('ذخیره', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _runBulk(
      () => _repo.bulkExpire(ids: _selectedIds.toList(), expireDate: date),
    );
  }

  Future<void> _bulkDelete() async {
    final count = _selectedIds.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text(
          'حذف گروهی',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
        ),
        content: Text(
          bulkDeleteConfirmText(count),
          style: const TextStyle(fontSize: 10.5, height: 1.8),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('انصراف', style: TextStyle(fontSize: 11)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ShopColors.danger),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text(
              'انتقال به سطل',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _runBulk(() => _repo.bulkDelete(_selectedIds.toList()));
  }

  Future<void> _runBulk(Future<DocBulkResult> Function() action) async {
    setState(() => _bulkBusy = true);
    try {
      final res = await action();
      _toast(res.display);
      await _afterBulk();
    } catch (e) {
      _toast(_cleanErr(e), error: true);
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  // ---------- سطل بازیافت ----------

  Future<void> _restore(DocRow d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text(
          'بازگرداندن مدرک از سطل بازیافت',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'آیا مدرک «${d.code} — ${d.title}» بازگردانده شود؟',
              style: const TextStyle(fontSize: 10.5, height: 1.9),
            ),
            const SizedBox(height: 8),
            const Text(
              'مدرک مجدداً در پوشه اصلی خود (یا اولین پوشه موجود در صورت حذف پوشه اصلی) فعال خواهد شد.',
              style: TextStyle(
                fontSize: 9,
                height: 1.8,
                color: ShopColors.seed,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('انصراف', style: TextStyle(fontSize: 11)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ShopColors.ok),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text(
              'بازگرداندن مدرک',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final msg = await _repo.restoreDocument(d.id);
      _toast(msg);
      await _afterBulk();
    } catch (e) {
      _toast(_cleanErr(e), error: true);
    }
  }

  Future<void> _purgeOne(DocRow d) async {
    final done = await _askPurge(title: 'حذف قطعی و برگشت‌ناپذیر مدرک');
    if (!done) return;
    try {
      final msg = await _repo.purgeDocument(d.id);
      _toast(msg);
      await _afterBulk();
    } catch (e) {
      _toast(_cleanErr(e), error: true);
    }
  }

  Future<void> _emptyTrash() async {
    final done = await _askPurge(title: 'خالی کردن کامل سطل بازیافت');
    if (!done) return;
    try {
      final msg = await _repo.emptyTrash();
      _toast(msg);
      await _afterBulk();
    } catch (e) {
      _toast(_cleanErr(e), error: true);
    }
  }

  /// تایید با تایپ عبارت «حذف قطعی» — همان قاعدهٔ وب
  Future<bool> _askPurge({required String title}) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: ShopColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'هشدار بسیار مهم: $kPurgeWarning',
                  style: TextStyle(
                    fontSize: 9.5,
                    height: 1.8,
                    color: ShopColors.danger,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'برای تایید، عبارت «$kPurgePhrase» را در کادر زیر تایپ کنید:',
                style: const TextStyle(fontSize: 10, height: 1.8),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: ctrl,
                onChanged: (_) => setLocal(() {}),
                style: const TextStyle(fontSize: 11),
                decoration: InputDecoration(
                  hintText: kPurgePhrase,
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xfff9fbfe),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('انصراف', style: TextStyle(fontSize: 11)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: ShopColors.danger),
              onPressed: ctrl.text.trim() == kPurgePhrase
                  ? () => Navigator.of(c).pop(true)
                  : null,
              child: const Text(
                'تایید و حذف قطعی',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
    return ok == true;
  }

  // ---------- پوشه ----------

  Future<void> _openNewFolder() async {
    final name = TextEditingController();
    final description = TextEditingController();
    int? parentId;
    var isPublic = false;
    var publicCanDownload = false;
    final perms = <DocPermissionInput>[];

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text(
            'پوشه جدید',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShopField(
                  label: 'نام پوشه',
                  required: true,
                  child: TextField(
                    controller: name,
                    style: const TextStyle(fontSize: 11),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                ShopField(
                  label: 'پوشه والد',
                  child: DropdownButtonFormField<int?>(
                    initialValue: parentId,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: ShopColors.ink,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text(
                          'بدون پوشه والد',
                          style: TextStyle(fontSize: 10.5),
                        ),
                      ),
                      for (final f in _folders)
                        DropdownMenuItem(
                          value: f.id,
                          child: Text(
                            folderPathText(_folders, f.id),
                            style: const TextStyle(fontSize: 10.5),
                          ),
                        ),
                    ],
                    onChanged: (v) => setLocal(() => parentId = v),
                  ),
                ),
                ShopField(
                  label: 'توضیحات',
                  child: TextField(
                    controller: description,
                    style: const TextStyle(fontSize: 11),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: isPublic,
                  onChanged: (v) => setLocal(() {
                    isPublic = v;
                    if (!v) publicCanDownload = false;
                  }),
                  title: const Text(
                    'نمایش برای همه',
                    style: TextStyle(fontSize: 10.5),
                  ),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: publicCanDownload,
                  onChanged: isPublic
                      ? (v) => setLocal(() => publicCanDownload = v)
                      : null,
                  title: const Text(
                    'دانلود برای همه کاربران',
                    style: TextStyle(fontSize: 10.5),
                  ),
                ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                  ),
                  onPressed: () async {
                    final rows = await _pickPermissions(
                      context,
                      initial: perms,
                    );
                    if (rows != null) {
                      setLocal(() {
                        perms
                          ..clear()
                          ..addAll(rows);
                      });
                    }
                  },
                  icon: const Icon(Icons.people_rounded, size: 15),
                  label: Text(
                    'دسترسی کاربران و گروه‌ها (${Fa.digits(perms.length)})',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('انصراف', style: TextStyle(fontSize: 11)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('ذخیره', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    // همان ترتیب/پیام وب: «نام پوشه اجباری است.»
    if (name.text.trim().isEmpty) {
      _toast('نام پوشه اجباری است.', error: true);
      return;
    }
    try {
      await _repo.createFolder(
        name: name.text,
        parentId: parentId,
        description: description.text,
        isPublic: isPublic,
        publicCanDownload: publicCanDownload,
        permissions: perms,
      );
      _toast('پوشه ساخته شد.');
      await _reloadSide();
      await _loadDocs();
    } catch (e) {
      _toast(_cleanErr(e), error: true);
    }
  }

  /// ویرایشگر دسترسی — همان ساختار «نفر / گروه» وب
  Future<List<DocPermissionInput>?> _pickPermissions(
    BuildContext ctx, {
    required List<DocPermissionInput> initial,
  }) async {
    final rows = [...initial];
    final users = <DocLookup>[];
    final roles = <DocLookup>[];
    try {
      final l = await _repo.lookups();
      users.addAll(l.users);
      roles.addAll(l.roles);
    } catch (_) {}
    if (!ctx.mounted) return null;

    var pickRole = false;
    var pickId = 0;
    var pickLevel = DocLevel.read;
    var pickDownload = false;

    return showDialog<List<DocPermissionInput>>(
      context: ctx,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text(
            'دسترسی کاربران و گروه‌ها',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '«خواندن» فقط برای مشاهده است؛ ویرایش و ورژن جدید نیازمند «نوشتن» است. دانلود باید جداگانه انتخاب شود.',
                    style: TextStyle(
                      fontSize: 8.5,
                      height: 1.8,
                      color: ShopColors.inkFaint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ShopSegmented(
                    labels: const ['نفر', 'گروه'],
                    index: pickRole ? 1 : 0,
                    onChanged: (i) => setLocal(() {
                      pickRole = i == 1;
                      pickId = 0;
                    }),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: pickId == 0 ? null : pickId,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: ShopColors.ink,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: pickRole ? 'افزودن گروه/نقش' : 'افزودن نفر',
                      labelStyle: const TextStyle(fontSize: 9.5),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final u in (pickRole ? roles : users))
                        DropdownMenuItem(
                          value: u.id,
                          child: Text(
                            u.name,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                    ],
                    onChanged: (v) => setLocal(() => pickId = v ?? 0),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: pickLevel,
                          isDense: true,
                          style: const TextStyle(
                            fontSize: 10,
                            color: ShopColors.ink,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'سطح دسترسی',
                            labelStyle: TextStyle(fontSize: 9),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final o in DocLevel.options)
                              DropdownMenuItem(
                                value: o.key,
                                child: Text(
                                  o.key == 4 ? 'دسترسی کامل' : o.value,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                          ],
                          onChanged: (v) => setLocal(() {
                            pickLevel = v ?? DocLevel.read;
                            if (pickLevel < DocLevel.read) pickDownload = false;
                          }),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        children: [
                          const Text(
                            'دانلود',
                            style: TextStyle(
                              fontSize: 8.5,
                              color: ShopColors.inkFaint,
                            ),
                          ),
                          Switch(
                            value: pickDownload,
                            onChanged: pickLevel < DocLevel.read
                                ? null
                                : (v) => setLocal(() => pickDownload = v),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: 'افزودن',
                        icon: const Icon(
                          Icons.add_circle_rounded,
                          size: 22,
                          color: ShopColors.seed,
                        ),
                        onPressed: pickId <= 0
                            ? null
                            : () => setLocal(() {
                                rows.add(
                                  DocPermissionInput(
                                    userId: pickRole ? 0 : pickId,
                                    roleId: pickRole ? pickId : 0,
                                    level: pickLevel,
                                    canDownload: pickDownload,
                                  ),
                                );
                                pickId = 0;
                              }),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  if (rows.isEmpty)
                    const Text(
                      'هنوز نفر یا گروهی اضافه نشده است.',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: ShopColors.inkFaint,
                      ),
                    )
                  else
                    for (var i = 0; i < rows.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                rows[i].isRole
                                    ? _lookupName(roles, rows[i].roleId)
                                    : _lookupName(users, rows[i].userId),
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                            ShopTag(
                              text: DocLevel.name(rows[i].level),
                              color: docLevelColor(rows[i].level),
                            ),
                            if (rows[i].canDownload)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.download_rounded,
                                  size: 13,
                                  color: ShopColors.ok,
                                ),
                              ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: ShopColors.danger,
                              ),
                              onPressed: () =>
                                  setLocal(() => rows.removeAt(i)),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('انصراف', style: TextStyle(fontSize: 11)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(c).pop(rows),
              child: const Text('تأیید', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  String _lookupName(List<DocLookup> list, int id) {
    for (final x in list) {
      if (x.id == id) return x.name;
    }
    return '#$id';
  }

  // ---------- مدیریت برچسب‌ها ----------

  Future<void> _manageTags() async {
    final name = TextEditingController();
    final color = TextEditingController(text: '#4f46e5');
    final description = TextEditingController();
    int? editingId;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ShopColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(c).size.height * 0.74,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'برچسب‌ها',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => Navigator.of(c).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                    children: [
                      ShopField(
                        label: 'عنوان تگ',
                        required: true,
                        child: TextField(
                          controller: name,
                          style: const TextStyle(fontSize: 11),
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'مثلاً: قرارداد مالی، فوری، ایزو…',
                            hintStyle: TextStyle(fontSize: 9.5),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      ShopField(
                        label: 'رنگ تگ',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final h in kTagPalette)
                                  InkWell(
                                    onTap: () => setLocal(() => color.text = h),
                                    child: Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: colorFromHex(h),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: color.text.trim() == h
                                              ? ShopColors.ink
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: color,
                              textDirection: TextDirection.ltr,
                              onChanged: (_) => setLocal(() {}),
                              style: const TextStyle(fontSize: 11),
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: '#4f46e5',
                                hintStyle: TextStyle(fontSize: 9.5),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ShopField(
                        label: 'توضیحات (اختیاری)',
                        child: TextField(
                          controller: description,
                          style: const TextStyle(fontSize: 11),
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'کاربرد تگ…',
                            hintStyle: TextStyle(fontSize: 9.5),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 38),
                              ),
                              onPressed: () async {
                                final err = validateTagName(name.text);
                                if (err != null) {
                                  _toast(err, error: true);
                                  return;
                                }
                                try {
                                  if (editingId == null) {
                                    await _repo.createTag(
                                      name: name.text,
                                      color: color.text,
                                      description: description.text,
                                    );
                                  } else {
                                    await _repo.updateTag(
                                      id: editingId!,
                                      name: name.text,
                                      color: color.text,
                                      description: description.text,
                                    );
                                  }
                                  name.clear();
                                  description.clear();
                                  color.text = '#4f46e5';
                                  editingId = null;
                                  final fresh = await _repo.tags();
                                  setLocal(() {});
                                  setState(() => _tags = fresh);
                                } catch (e) {
                                  _toast(_cleanErr(e), error: true);
                                }
                              },
                              child: Text(
                                editingId == null ? 'افزودن' : 'ذخیره',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                          if (editingId != null) ...[
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => setLocal(() {
                                editingId = null;
                                name.clear();
                                description.clear();
                                color.text = '#4f46e5';
                              }),
                              child: const Text(
                                'انصراف',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Divider(height: 20),
                      if (_tags.isEmpty)
                        const Text(
                          'برچسبی تعریف نشده است.',
                          style: TextStyle(
                            fontSize: 10,
                            color: ShopColors.inkFaint,
                          ),
                        )
                      else
                        for (final t in _tags)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                ShopTag(
                                  text: t.name,
                                  color: colorFromHex(t.color),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${Fa.digits(t.documentCount)} مدرک',
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    color: ShopColors.inkFaint,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  tooltip: 'ویرایش',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 30,
                                    minHeight: 30,
                                  ),
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    size: 15,
                                  ),
                                  onPressed: () => setLocal(() {
                                    editingId = t.id;
                                    name.text = t.name;
                                    color.text = t.color;
                                    description.text = t.description ?? '';
                                  }),
                                ),
                                IconButton(
                                  tooltip: 'حذف',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 30,
                                    minHeight: 30,
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 15,
                                    color: ShopColors.danger,
                                  ),
                                  onPressed: () async {
                                    try {
                                      final msg = await _repo.deleteTag(t.id);
                                      _toast(msg);
                                      final fresh = await _repo.tags();
                                      setLocal(() {});
                                      setState(() => _tags = fresh);
                                    } catch (e) {
                                      _toast(_cleanErr(e), error: true);
                                    }
                                  },
                                ),
                              ],
                            ),
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

}

/// نگاشت رنگ HEX سرور به Color — برای برچسب‌ها
Color colorFromHex(String hex) {
  var h = hex.trim().replaceAll('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  final v = int.tryParse(h, radix: 16);
  return v == null ? ShopColors.seed : Color(0xff000000 | v);
}

/// رنگ نشان سطح دسترسی
Color docLevelColor(int level) => switch (level) {
  4 => ShopColors.ok,
  3 => ShopColors.seed,
  2 => ShopColors.teal,
  1 => ShopColors.warn,
  _ => ShopColors.inkFaint,
};

/// رنگ نشان وضعیت نسخه
Color docVersionColor(int status) => switch (status) {
  2 => ShopColors.ok,
  1 => ShopColors.warn,
  3 => ShopColors.danger,
  0 => ShopColors.inkSoft,
  _ => ShopColors.inkFaint,
};
