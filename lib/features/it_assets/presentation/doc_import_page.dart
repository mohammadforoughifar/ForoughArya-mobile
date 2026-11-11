// ============================================================
//  «ورود انبوه آرشیو» — آینهٔ `Pages/DocArchive/DocBulkImport.razor`
//  مسیر وب: /doc-archive/import   (منو: «ورود انبوه»)
//  GET  import/config → {enabled, maxFileBytes, problemFa}
//  POST import/upload  (rootFolderId, path, file)
//  POST import/run     (rootFolderId, paths[]) → {imported, duplicate, failed, skipped, failedNames}
//  مراحل وب: ۱) انتخاب پوشه ۲) بررسی نام فایل‌ها ۳) نتیجه
// ============================================================

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/doc_archive_repository.dart';
import '../models/doc_archive_models.dart';
import 'system_style.dart';

class DocImportPage extends StatefulWidget {
  const DocImportPage({super.key, this.folders = const []});

  final List<DocFolder> folders;

  @override
  State<DocImportPage> createState() => _DocImportPageState();
}

class _DocImportPageState extends State<DocImportPage> {
  late final DocArchiveRepository _repo;

  DocImportConfig _cfg = const DocImportConfig();
  List<DocFolder> _folders = const [];
  int? _rootFolderId;

  List<PlatformFile> _picked = const [];
  DocImportPreview? _preview;
  DocImportResult? _result;

  bool _busy = false;
  String _stage = '';
  int _sent = 0;
  int _totalBytes = 0;
  int _imported = 0;
  int _failedCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = DocArchiveRepository(context.read<ApiClient>());
    _folders = widget.folders;
    _bootstrap();
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '')
      .trim();

  Future<void> _bootstrap() async {
    try {
      final cfg = await _repo.importConfig();
      var folders = widget.folders;
      if (folders.isEmpty) {
        folders = (await _repo.folders(take: 500)).items;
      }
      if (!mounted) return;
      setState(() {
        _cfg = cfg;
        _folders = folders;
        _rootFolderId ??= folders.isEmpty ? null : folders.first.id;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _clean(e));
    }
  }

  String get _stageText => switch (_stage) {
    'picked' => 'در حال خواندن فایل‌ها…',
    'preview' => 'در حال بررسی نام فایل‌ها…',
    'progress' => 'در حال بارگذاری و ورود فایل‌ها…',
    'done' => 'پایان ورود انبوه',
    _ => '',
  };

  String _relative(String path) {
    final parts = path.split(Platform.pathSeparator);
    return parts.isEmpty ? path : parts.last;
  }

  /// مرحلهٔ ۱ و ۲ — انتخاب فایل‌ها و بررسی محلی (حجم/خواندن)
  Future<void> _pick() async {
    if (_rootFolderId == null) {
      setState(() => _error = 'پوشه مقصد در آرشیو را انتخاب کنید.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _preview = null;
      _stage = 'picked';
    });
    try {
      final files = await FilePicker.pickFiles();
      if (!mounted) return;
      if (files.isEmpty) {
        setState(() {
          _busy = false;
          _stage = '';
        });
        return;
      }
      setState(() {
        _picked = files;
        _stage = 'preview';
      });
      final problems = <DocImportItem>[];
      var ready = 0;
      var failed = 0;
      for (final f in files) {
        final path = f.path;
        var size = 0;
        var ok = path != null;
        if (path != null) {
          try {
            final io = File(path);
            if (!await io.exists()) {
              ok = false;
            } else {
              size = await io.length();
            }
          } catch (_) {
            ok = false;
          }
        }
        String? reason;
        if (!ok) {
          reason = 'فایل روی دستگاه خوانده نشد.';
        } else if (size > _cfg.maxFileBytes) {
          reason = 'حجم فایل بیش از سقف ${_cfg.maxFileFa} است.';
        }
        if (reason != null) {
          failed++;
          problems.add(
            DocImportItem(
              relativePath: path == null ? f.name : _relative(path),
              fileName: f.name,
              size: size,
              ready: false,
              reasonFa: reason,
            ),
          );
        } else {
          ready++;
        }
      }
      if (!mounted) return;
      setState(() {
        _preview = DocImportPreview(
          total: files.length,
          ready: ready,
          failed: failed,
          problems: problems,
        );
        _busy = false;
        _stage = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stage = '';
        _error = _clean(e);
      });
    }
  }

  /// مرحلهٔ ۳ — بارگذاری و اجرا
  Future<void> _run() async {
    final preview = _preview;
    final root = _rootFolderId;
    if (preview == null || root == null || preview.ready == 0) return;
    setState(() {
      _busy = true;
      _error = null;
      _stage = 'progress';
      _imported = 0;
      _failedCount = 0;
      _sent = 0;
      _totalBytes = 0;
    });
    final uploaded = <String>[];
    final failedNames = <String>[];
    try {
      for (final f in _picked) {
        final path = f.path;
        if (path == null) continue;
        final io = File(path);
        if (!await io.exists()) {
          failedNames.add(f.name);
          continue;
        }
        final len = await io.length();
        if (len > _cfg.maxFileBytes) {
          failedNames.add(f.name);
          continue;
        }
        setState(() {
          _totalBytes = len;
          _sent = 0;
        });
        try {
          final rel = _relative(path);
          await _repo.importUpload(
            rootFolderId: root,
            relativePath: rel,
            bytes: await io.readAsBytes(),
            onProgress: (s, t) {
              if (!mounted) return;
              setState(() {
                _sent = s;
                _totalBytes = t;
              });
            },
          );
          uploaded.add(rel);
          if (!mounted) return;
          setState(() => _imported++);
        } catch (_) {
          failedNames.add(f.name);
          if (!mounted) return;
          setState(() => _failedCount++);
        }
      }
      DocImportResult res;
      try {
        res = await _repo.importRun(rootFolderId: root, relativePaths: uploaded);
      } catch (_) {
        res = DocImportResult(imported: uploaded.length);
      }
      if (!mounted) return;
      setState(() {
        _result = DocImportResult(
          imported: res.imported == 0 ? uploaded.length : res.imported,
          failed: res.failed + _failedCount,
          duplicate: res.duplicate,
          skipped: res.skipped,
          failedNames: [...res.failedNames, ...failedNames],
        );
        _busy = false;
        _stage = 'done';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stage = 'done';
        _error = _clean(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final percent = _totalBytes == 0
        ? 0.0
        : (_sent / _totalBytes).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: const Text(
          'ورود انبوه آرشیو',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 26),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ShopColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ShopColors.line),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.folder_copy_rounded,
                      size: 17,
                      color: ShopColors.seed,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'ورود انبوه آرشیو',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'فایل‌ها را از گوشی انتخاب کنید. هر فایل با نام «عنوان + شماره» یک سند می‌شود و نام هیچ فایلی عوض نمی‌شود.',
                  style: TextStyle(
                    fontSize: 9.5,
                    height: 1.9,
                    color: ShopColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (!_cfg.enabled) ...[
            SystemNote(
              text:
                  'ورود انبوه هنوز آماده نیست${(_cfg.problemFa ?? '').isEmpty ? '' : ' — ${_cfg.problemFa}'}',
              color: ShopColors.warn,
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 8),
          ],
          if (_error != null) ...[
            SystemNote(
              text: _error!,
              color: ShopColors.danger,
              icon: Icons.error_outline_rounded,
            ),
            const SizedBox(height: 8),
          ],

          _step(
            number: '۱',
            title: 'انتخاب پوشه',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  isDense: true,
                  initialValue: _rootFolderId,
                  style: const TextStyle(fontSize: 10.5, color: ShopColors.ink),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'مقصد در آرشیو',
                    labelStyle: TextStyle(fontSize: 9),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final f in _folders)
                      DropdownMenuItem(
                        value: f.id,
                        child: Text(
                          f.name,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _rootFolderId = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'سقف حجم هر فایل: ${_cfg.maxFileFa}',
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: ShopColors.inkSoft,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _busy || !_cfg.enabled ? null : _pick,
                      icon: const Icon(Icons.folder_open_rounded, size: 15),
                      label: const Text(
                        'انتخاب فایل‌ها',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_busy)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _stageText,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: ShopColors.seed,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          if (_preview != null) ...[
            _step(
              number: '۲',
              title: 'بررسی نام فایل‌ها',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _stat('فایل', _preview!.total),
                      const SizedBox(width: 6),
                      _stat('آمادهٔ ورود', _preview!.ready, ShopColors.ok),
                      const SizedBox(width: 6),
                      _stat('مشکل‌دار', _preview!.failed, ShopColors.danger),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_preview!.ready > 0)
                    SystemNote(
                      text: _preview!.summaryFa,
                      color: ShopColors.ok,
                      icon: Icons.check_circle_outline_rounded,
                    ),
                  if (_preview!.problems.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'فایل‌هایی که وارد نمی‌شوند (${Fa.digits(_preview!.problems.length)} مورد)',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final p in _preview!.problems)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.cancel_outlined,
                              size: 12,
                              color: ShopColors.danger,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                '${p.fileName} — ${p.reasonFa ?? ''}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  height: 1.7,
                                  color: ShopColors.inkSoft,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy || _preview!.ready == 0 ? null : _run,
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: Text(
                        'ورود ${Fa.digits(_preview!.ready)} فایل',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  if (_busy && _stage == 'progress') ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: percent, minHeight: 8),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${Fa.digits((percent * 100).round())}٪',
                          style: const TextStyle(
                            fontSize: 9,
                            color: ShopColors.inkFaint,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'واردشده: ${Fa.digits(_imported)} | ناموفق: ${Fa.digits(_failedCount)}',
                          style: const TextStyle(
                            fontSize: 9,
                            color: ShopColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          if (_result != null)
            _step(
              number: '۳',
              title: 'نتیجه',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SystemNote(
                    text: _result!.headlineFa,
                    color: _result!.isSuccess ? ShopColors.ok : ShopColors.warn,
                    icon: _result!.isSuccess
                        ? Icons.check_circle_outline_rounded
                        : Icons.info_outline_rounded,
                  ),
                  if (_result!.failedNames.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'نمونهٔ فایل‌های ناموفق:',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                    for (final n in _result!.failedNames.take(10))
                      Text(
                        '• $n',
                        style: const TextStyle(
                          fontSize: 9,
                          height: 1.8,
                          color: ShopColors.inkSoft,
                        ),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _step({
    required String number,
    required String title,
    required Widget child,
  }) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: ShopColors.ink,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );

  Widget _stat(String label, int value, [Color? color]) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color ?? ShopColors.line),
      ),
      child: Column(
        children: [
          Text(
            Fa.digits(value),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color ?? ShopColors.ink,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 8.5, color: ShopColors.inkFaint),
          ),
        ],
      ),
    ),
  );
}
