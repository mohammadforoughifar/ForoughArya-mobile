// ============================================================
//  «مقایسهٔ محتوای فایل‌ها» — آینهٔ `Pages/DocArchive/DocContentCompare.razor`
//  GET  documents/{id}/compare-files/{versionId}
//  POST documents/{id}/compare-content {leftAttachmentId, rightAttachmentId}
//  در صورت نیاز: POST documents/{id}/confirm-download {password}
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/doc_archive_repository.dart';
import '../models/doc_archive_models.dart';
import 'doc_archive_detail_page.dart' show DocVersionRow;
import 'system_style.dart';

class DocContentComparePage extends StatefulWidget {
  const DocContentComparePage({
    super.key,
    required this.documentId,
    required this.versions,
    this.fromVersionId,
    this.toVersionId,
  });

  final int documentId;
  final List<DocVersionRow> versions;
  final int? fromVersionId;
  final int? toVersionId;

  @override
  State<DocContentComparePage> createState() => _DocContentComparePageState();
}

class _DocContentComparePageState extends State<DocContentComparePage> {
  late final DocArchiveRepository _repo;

  int _fromVersion = 0;
  int _toVersion = 0;
  List<DocLookup> _leftFiles = const [];
  List<DocLookup> _rightFiles = const [];
  int _leftId = 0;
  int _rightId = 0;

  bool _onlyDiff = true;
  bool _busy = false;
  bool _needsPassword = false;
  final _password = TextEditingController();

  DocContentCompare? _result;
  String? _error;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _repo = DocArchiveRepository(context.read<ApiClient>());
    final vs = widget.versions;
    _toVersion = widget.toVersionId ?? (vs.isEmpty ? 0 : vs.first.id);
    _fromVersion = widget.fromVersionId ??
        (vs.length > 1 ? vs.last.id : (vs.isEmpty ? 0 : vs.first.id));
    _loadFiles();
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  static String _msgOf(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '')
      .trim();

  Future<void> _loadFiles() async {
    if (_fromVersion == 0 || _toVersion == 0 || _fromVersion == _toVersion) {
      setState(() {
        _leftFiles = const [];
        _rightFiles = const [];
        _leftId = 0;
        _rightId = 0;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _needsPassword = false;
    });
    try {
      final left = await _repo.compareFiles(widget.documentId, _fromVersion);
      final right = await _repo.compareFiles(widget.documentId, _toVersion);
      if (!mounted) return;
      final firstLeft = left.isEmpty ? 0 : left.first.id;
      var rightPick = 0;
      if (left.isNotEmpty) {
        for (final r in right) {
          if (r.name == left.first.name) {
            rightPick = r.id;
            break;
          }
        }
      }
      if (rightPick == 0 && right.isNotEmpty) rightPick = right.first.id;
      setState(() {
        _leftFiles = left;
        _rightFiles = right;
        _leftId = firstLeft;
        _rightId = rightPick;
        _page = 1;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _msgOf(e);
      });
    }
  }

  Future<void> _compare() async {
    if (_leftId == 0 || _rightId == 0) {
      setState(() => _error = DocContentCompare.minTwoFiles);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final res = await _repo.compareContent(
        documentId: widget.documentId,
        leftAttachmentId: _leftId,
        rightAttachmentId: _rightId,
      );
      if (!mounted) return;
      setState(() {
        _result = res;
        _needsPassword = false;
        _page = 1;
        _busy = false;
      });
    } catch (e) {
      final m = _msgOf(e);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = m.isEmpty ? DocContentCompare.textPending : m;
        _needsPassword = m.contains('تأیید رمز');
      });
    }
  }

  Future<void> _confirm() async {
    if (_password.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.confirmDownload(widget.documentId, _password.text);
      _password.clear();
      if (!mounted) return;
      setState(() => _busy = false);
      await _compare();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _msgOf(e);
      });
    }
  }

  String _vLabel(DocVersionRow v) =>
      'ورژن ${Fa.digits(v.versionNo)} — ${DocVersionStatus.nameView(v.status)}';

  @override
  Widget build(BuildContext context) {
    final rows = _result == null
        ? const <DocContentRow>[]
        : (_onlyDiff ? _result!.onlyChanges : _result!.rows);
    final pageRows = rows.skip((_page - 1) * 100).take(100).toList();
    final pages = (rows.length / 100).ceil();
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: const Text(
          'مقایسه محتوای فایل‌ها',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 26),
        children: [
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _versionDrop(true)),
                    const SizedBox(width: 6),
                    Expanded(child: _versionDrop(false)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        isDense: true,
                        initialValue: _leftId == 0 ? null : _leftId,
                        style: const TextStyle(
                          fontSize: 10,
                          color: ShopColors.ink,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'فایل نسخه قدیمی',
                          labelStyle: TextStyle(fontSize: 9),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final f in _leftFiles)
                            DropdownMenuItem(
                              value: f.id,
                              child: Text(
                                f.name,
                                style: const TextStyle(fontSize: 9.5),
                              ),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (v) => setState(() {
                                _leftId = v ?? 0;
                                _result = null;
                              }),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        isDense: true,
                        initialValue: _rightId == 0 ? null : _rightId,
                        style: const TextStyle(
                          fontSize: 10,
                          color: ShopColors.ink,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'فایل نسخه جدید',
                          labelStyle: TextStyle(fontSize: 9),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final f in _rightFiles)
                            DropdownMenuItem(
                              value: f.id,
                              child: Text(
                                f.name,
                                style: const TextStyle(fontSize: 9.5),
                              ),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (v) => setState(() {
                                _rightId = v ?? 0;
                                _result = null;
                              }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy || _leftId == 0 || _rightId == 0
                        ? null
                        : _compare,
                    child: const Text(
                      'مقایسه',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                if (_needsPassword) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _password,
                          obscureText: true,
                          style: const TextStyle(fontSize: 11),
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'تأیید رمز برای مقایسه',
                            hintStyle: TextStyle(fontSize: 9),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        onPressed: _busy ? null : _confirm,
                        child: const Text(
                          'تأیید رمز',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            SystemNote(
              text: _error!,
              color: ShopColors.warn,
              icon: Icons.warning_amber_rounded,
            ),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_result != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                ShopTag(
                  text: _result!.summaryFa,
                  color: _result!.changeCount == 0
                      ? ShopColors.inkFaint
                      : ShopColors.warn,
                  icon: Icons.compare_arrows_rounded,
                ),
                const SizedBox(width: 6),
                ShopTag(text: _result!.modeFa, color: ShopColors.seed),
              ],
            ),
            if ((_result!.notice ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              SystemNote(
                text: _result!.notice!,
                color: ShopColors.warn,
                icon: Icons.info_outline_rounded,
              ),
            ],
            if (_result!.truncated) ...[
              const SizedBox(height: 6),
              const SystemNote(
                text: DocContentCompare.truncatedFa,
                color: ShopColors.danger,
                icon: Icons.warning_amber_rounded,
              ),
            ],
            const SizedBox(height: 4),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _onlyDiff,
              onChanged: (v) => setState(() {
                _onlyDiff = v == true;
                _page = 1;
              }),
              title: const Text(
                'فقط تفاوت‌ها',
                style: TextStyle(fontSize: 10.5),
              ),
            ),
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'قدیمی — ${_result!.leftName}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'جدید — ${_result!.rightName}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 12),
                  if (pageRows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'در بخش مقایسه‌شده تفاوتی یافت نشد.',
                        style: TextStyle(
                          fontSize: 10,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                    )
                  else
                    for (final r in pageRows) _row(r),
                  if (pages > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _page <= 1
                              ? null
                              : () => setState(() => _page--),
                          child: const Text(
                            'قبلی',
                            style: TextStyle(fontSize: 9.5),
                          ),
                        ),
                        Text(
                          Fa.digits(_page),
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: ShopColors.inkFaint,
                          ),
                        ),
                        TextButton(
                          onPressed: _page >= pages
                              ? null
                              : () => setState(() => _page++),
                          child: const Text(
                            'بعدی',
                            style: TextStyle(fontSize: 9.5),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _versionDrop(bool isFrom) => DropdownButtonFormField<int>(
    isDense: true,
    initialValue: (isFrom ? _fromVersion : _toVersion) == 0
        ? null
        : (isFrom ? _fromVersion : _toVersion),
    style: const TextStyle(fontSize: 10, color: ShopColors.ink),
    decoration: InputDecoration(
      isDense: true,
      labelText: isFrom ? 'نسخه قدیمی' : 'نسخه جدید',
      labelStyle: const TextStyle(fontSize: 9),
      border: const OutlineInputBorder(),
    ),
    items: [
      for (final v in widget.versions)
        DropdownMenuItem(
          value: v.id,
          child: Text(_vLabel(v), style: const TextStyle(fontSize: 9.5)),
        ),
    ],
    onChanged: _busy
        ? null
        : (v) {
            setState(() {
              if (isFrom) {
                _fromVersion = v ?? 0;
              } else {
                _toVersion = v ?? 0;
              }
            });
            _loadFiles();
          },
  );

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ShopColors.line),
    ),
    child: child,
  );

  Widget _row(DocContentRow r) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                r.field,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: ShopColors.inkFaint,
                ),
              ),
            ),
            ShopTag(
              text: r.kindLabel,
              color: switch (r.kind) {
                'added' => ShopColors.ok,
                'removed' => ShopColors.danger,
                'changed' => ShopColors.warn,
                _ => ShopColors.inkFaint,
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                r.left.isEmpty ? '—' : r.left,
                style: const TextStyle(fontSize: 9, height: 1.7),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                r.right.isEmpty ? '—' : r.right,
                style: const TextStyle(fontSize: 9, height: 1.7),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
