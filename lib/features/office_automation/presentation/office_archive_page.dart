// ============================================================
//  بایگانی درختی — GET /bayegani/tree و مدیریت پوشه‌ها
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/widgets/common.dart';
import '../data/office_repository.dart';
import '../models/office_common.dart';
import 'office_style.dart';

class OfficeArchivePage extends StatefulWidget {
  const OfficeArchivePage({super.key, this.kind = LetterKind.inner});

  final LetterKind kind;

  @override
  State<OfficeArchivePage> createState() => _OfficeArchivePageState();
}

class _OfficeArchivePageState extends State<OfficeArchivePage> {
  OfficeAutomationRepository get _repo => context.read<OfficeAutomationRepository>();

  late LetterKind _kind = widget.kind;
  bool _loading = true;
  String? _error;
  List<ArchiveNode> _roots = const [];

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
      final r = await _repo.archiveTree(_kind);
      final data = r.data;
      final raw = data is List ? data : (asMap(data)['items'] ?? asMap(data)['tree']);
      final list = raw is List
          ? raw.whereType<Map>().map((e) => ArchiveNode.fromJson(asMap(e))).toList()
          : <ArchiveNode>[];
      if (mounted) {
        setState(() {
          _roots = list;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'خطا در دریافت بایگانی: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _addFolder({required bool sub, int parentId = 0}) async {
    final title = await promptText(
      context,
      sub ? 'نام زیرپوشه' : 'نام دستهٔ اصلی',
      hint: 'مثلاً: قراردادهای سال ۱۴۰۵',
    );
    if (title == null || title.trim().isEmpty) return;
    try {
      await _repo.addArchiveFolder(_kind, title.trim(), sub: sub, parentId: parentId);
      await _load();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _renameFolder(ArchiveNode node) async {
    final title = await promptText(context, 'تغییر نام پوشه', initial: node.title);
    if (title == null || title.trim().isEmpty) return;
    try {
      await _repo.renameArchiveFolder(_kind, node.id, title.trim());
      await _load();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _deleteFolder(ArchiveNode node) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف پوشه'),
        content: Text('پوشهٔ «${node.title}» حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteArchiveFolder(_kind, node.id);
      await _load();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: OfficeSlidingTabs(
                  items: const [
                    (label: 'داخلی', icon: Icons.edit_note, key: 'in'),
                    (label: 'صادره', icon: Icons.north_east, key: 'out'),
                    (label: 'وارده', icon: Icons.south_west, key: 'inc'),
                  ],
                  index: _kind.index,
                  onChanged: (i) {
                    setState(() => _kind = LetterKind.values[i]);
                    _load();
                  },
                  pillColor: OfficeColors.archive,
                  accentFor: (i) => switch (i) {
                    1 => OfficeColors.outgoing,
                    2 => OfficeColors.incoming,
                    _ => OfficeColors.inner,
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _addFolder(sub: false),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      OfficeColors.gold.withValues(alpha: .20),
                      OfficeColors.gold.withValues(alpha: .07),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: OfficeColors.gold.withValues(alpha: .30)),
                ),
                child: const Icon(Icons.create_new_folder_outlined,
                    size: 19, color: Color(0xffe0a800)),
              ),
            ),
            const SizedBox(width: 7),
            InkWell(
              onTap: _load,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: OfficeColors.line),
                ),
                child: const Icon(Icons.refresh, size: 19, color: OfficeColors.archive),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: _loading
            ? const OfficeShimmer(count: 6, height: 78)
            : _error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : _roots.isEmpty
                    ? ListView(
                        children: [
                          SizedBox(height: MediaQuery.sizeOf(context).height * .16),
                          const EmptyView(
                            message: 'بایگانی خالی است. با دکمهٔ پوشهٔ جدید یک دستهٔ اصلی بسازید.',
                            icon: Icons.account_tree_outlined,
                          ),
                        ],
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                          children: _roots.map((n) => _folderTile(n, 0)).toList(),
                        ),
                      ),
      ),
    ],
  );

  Widget _folderTile(ArchiveNode node, int depth) {
    if (node.isFolder) {
      return Padding(
        padding: EdgeInsetsDirectional.only(start: depth * 12.0),
        child: Container(
          margin: const EdgeInsets.only(bottom: 9),
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
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              childrenPadding: const EdgeInsets.only(bottom: 6),
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      OfficeColors.gold.withValues(alpha: .22),
                      OfficeColors.gold.withValues(alpha: .07),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  depth == 0 ? Icons.folder_special_outlined : Icons.folder_outlined,
                  size: 18,
                  color: const Color(0xffe0a800),
                ),
              ),
              title: Text(
                node.title,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${Fa.digits(node.children.length)} مورد',
                style: TextStyle(fontSize: 10.5, color: Colors.blueGrey.shade500),
              ),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (v) => switch (v) {
                  'sub' => _addFolder(sub: true, parentId: node.id),
                  'rename' => _renameFolder(node),
                  'delete' => _deleteFolder(node),
                  _ => null,
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'sub', child: Text('زیرپوشهٔ جدید', style: TextStyle(fontSize: 12.5))),
                  PopupMenuItem(value: 'rename', child: Text('تغییر نام', style: TextStyle(fontSize: 12.5))),
                  PopupMenuItem(value: 'delete', child: Text('حذف پوشه', style: TextStyle(fontSize: 12.5))),
                ],
              ),
              children: node.children.map((c) => _folderTile(c, depth + 1)).toList(),
            ),
          ),
        ),
      );
    }

    final accent = OfficeColors.forKind(_kind);
    final hot = node.foriat != null && node.foriat != 'عادی';
    return Padding(
      padding: EdgeInsetsDirectional.only(start: (depth + 1) * 12.0),
      child: OFadeSlideIn(
        index: depth,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: OfficeColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.mail_outline, size: 16, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (node.letterNumber != null)
                          'شماره ${Fa.digits(node.letterNumber)}',
                        if (node.receiverOrganization != null) node.receiverOrganization!,
                        if (node.sendMethod != null) node.sendMethod!,
                        if (node.date != null)
                          Fa.date(node.date!.toIso8601String(), time: false),
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: Colors.blueGrey.shade500),
                    ),
                  ],
                ),
              ),
              if (hot)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: OfficeColors.signing.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: OfficeColors.signing.withValues(alpha: .2)),
                  ),
                  child: Text(
                    node.foriat!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: OfficeColors.signing,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
