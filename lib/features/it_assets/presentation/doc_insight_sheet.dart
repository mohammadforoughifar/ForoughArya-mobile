// ============================================================
//  «گزارش‌ها و نظرات مدرک» — آینهٔ کارت‌های DocumentView وب
//  • درخواست‌های دسترسی   documents/{id}/access-requests  (+approve/reject/cancel)
//  • گزارش دانلود و مشاهده  documents/{id}/access-logs
//  • لاگ چاپ               print/logs/{id}
//  • ردیاب نشت             documents/{id}/leak-traces
//  • متن استخراج‌شده        documents/{id}/extracted-texts (+ attachments/{id}/ocr)
//  • نظرات                 documents/{id}/comments (+ resolve)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/doc_archive_repository.dart';
import '../models/doc_archive_models.dart';
import 'system_style.dart';

class DocInsightSheet extends StatefulWidget {
  const DocInsightSheet({
    super.key,
    required this.documentId,
    required this.myLevel,
    this.isActive = true,
  });

  final int documentId;
  final int myLevel;
  final bool isActive;

  @override
  State<DocInsightSheet> createState() => _DocInsightSheetState();
}

class _DocInsightSheetState extends State<DocInsightSheet> {
  late final DocArchiveRepository _repo;

  List<DocAccessRequest> _requests = const [];
  List<DocFileAccessLog> _accessLogs = const [];
  List<DocPrintLog> _printLogs = const [];
  List<DocLeakTrace> _leaks = const [];
  List<DocExtractedText> _texts = const [];
  List<DocComment> _comments = const [];

  bool _loading = true;
  bool _busy = false;
  String? _note;
  bool _noteError = false;

  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo = DocArchiveRepository(context.read<ApiClient>());
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '')
      .trim();

  Future<void> _load() async {
    setState(() => _loading = true);
    Future<T?> safe<T>(Future<T> Function() f) async {
      try {
        return await f();
      } catch (_) {
        return null;
      }
    }

    final requests = await safe(() => _repo.accessRequests(widget.documentId));
    final logs = await safe(() => _repo.accessLogs(widget.documentId));
    final prints = await safe(() => _repo.printLogs(widget.documentId));
    final leaks = await safe(() => _repo.leakTraces(widget.documentId));
    final texts = await safe(() => _repo.extractedTexts(widget.documentId));
    final comments = await safe(() => _repo.comments(widget.documentId));
    if (!mounted) return;
    setState(() {
      _requests = requests ?? const [];
      _accessLogs = logs ?? const [];
      _printLogs = prints ?? const [];
      _leaks = leaks ?? const [];
      _texts = texts ?? const [];
      _comments = comments ?? const [];
      _loading = false;
    });
  }

  bool get _isManager => widget.myLevel >= DocLevel.write;

  void _toast(String t, {bool error = false}) => setState(() {
    _note = t;
    _noteError = error;
  });

  Future<void> _run(Future<void> Function() f, String okText) async {
    setState(() => _busy = true);
    try {
      await f();
      if (!mounted) return;
      _toast(okText);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast(_clean(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.88,
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
              child: Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 17,
                    color: ShopColors.seed,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'گزارش‌ها و نظرات مدرک',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const TabBar(
              labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
              tabs: [
                Tab(text: 'دسترسی‌ها'),
                Tab(text: 'گزارش‌ها'),
                Tab(text: 'متن و نظرات'),
              ],
            ),
            if (_note != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: SystemNote(
                  text: _note!,
                  color: _noteError ? ShopColors.danger : ShopColors.ok,
                  icon: _noteError
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline_rounded,
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _requestsTab(),
                        _reportsTab(),
                        _textsCommentsTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Text(
      t,
      style: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
    ),
  );

  // ---------------- درخواست دسترسی ----------------

  Widget _requestsTab() => ListView(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
    children: [
      if (!widget.isActive)
        const SystemNote(
          text: 'مدرک غیرفعال است؛ درخواست دسترسی فقط برای مدرک فعال معنا دارد.',
          color: ShopColors.inkFaint,
          icon: Icons.info_outline_rounded,
        )
      else
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
          onPressed: _busy ? null : _requestAccess,
          icon: const Icon(Icons.lock_open_rounded, size: 15),
          label: const Text(
            'درخواست دسترسی',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
          ),
        ),
      const SizedBox(height: 10),
      if (_requests.isEmpty)
        _empty('درخواستی ثبت نشده است.')
      else
        for (final r in _requests)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: ShopColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${r.requesterName} — سطح ${r.levelFa}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    ShopTag(
                      text: r.statusFa,
                      color: switch (r.status) {
                        1 => ShopColors.ok,
                        2 => ShopColors.danger,
                        3 => ShopColors.inkFaint,
                        _ => ShopColors.warn,
                      },
                    ),
                  ],
                ),
                Text(
                  r.createdAtFa,
                  style: const TextStyle(
                    fontSize: 8.5,
                    color: ShopColors.inkFaint,
                  ),
                ),
                if ((r.note ?? '').isNotEmpty)
                  Text(
                    r.note!,
                    style: const TextStyle(
                      fontSize: 9,
                      height: 1.7,
                      color: ShopColors.inkSoft,
                    ),
                  ),
                if (r.isPending && _isManager)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => _repo.approveAccessRequest(r.id),
                                'درخواست تأیید شد.',
                              ),
                        child: const Text(
                          'تأیید',
                          style: TextStyle(fontSize: 9.5, color: ShopColors.ok),
                        ),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => _repo.rejectAccessRequest(r.id),
                                'درخواست رد شد.',
                              ),
                        child: const Text(
                          'رد',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: ShopColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
    ],
  );

  Future<void> _requestAccess() async {
    var level = DocLevel.read;
    var note = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text(
            'درخواست دسترسی',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                isDense: true,
                initialValue: level,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'سطح درخواستی',
                  labelStyle: TextStyle(fontSize: 9),
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final o in DocLevel.options)
                    DropdownMenuItem(
                      value: o.key,
                      child: Text(
                        o.value,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                ],
                onChanged: (v) => setLocal(() => level = v ?? DocLevel.read),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (v) => note = v,
                style: const TextStyle(fontSize: 11),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'توضیح (اختیاری)',
                  hintStyle: TextStyle(fontSize: 9.5),
                  border: OutlineInputBorder(),
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
              child: const Text('ارسال', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _run(
      () => _repo.requestAccess(
        documentId: widget.documentId,
        level: level,
        note: note,
      ),
      'درخواست دسترسی ثبت شد.',
    );
  }

  // ---------------- گزارش‌ها ----------------

  Widget _reportsTab() => ListView(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
    children: [
      const _SectionTitle(
        icon: Icons.cloud_download_outlined,
        text: 'گزارش دانلود و مشاهده فایل‌ها',
      ),
      if (_accessLogs.isEmpty)
        _empty('گزارشی ثبت نشده است.')
      else
        for (final l in _accessLogs)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  l.action == 'Download'
                      ? Icons.download_rounded
                      : Icons.visibility_outlined,
                  size: 13,
                  color: ShopColors.seed,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l.userName} — ${l.actionFa}',
                        style: const TextStyle(fontSize: 9.5),
                      ),
                      Text(
                        l.fileName,
                        style: const TextStyle(
                          fontSize: 8.5,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  l.atFa,
                  style: const TextStyle(
                    fontSize: 8.5,
                    color: ShopColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
      const Divider(height: 22),
      const _SectionTitle(
        icon: Icons.print_rounded,
        text: 'لاگ چاپ فایل‌ها',
      ),
      if (_printLogs.isEmpty)
        _empty('چاپی ثبت نشده است.')
      else
        for (final p in _printLogs)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ShopColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${p.userName} — ${p.fileName} (ورژن ${Fa.digits(p.versionNo)})',
                  style: const TextStyle(fontSize: 9.5),
                ),
                if (p.watermarkText.isNotEmpty)
                  Text(
                    'واترمارک: ${p.watermarkText}',
                    style: const TextStyle(
                      fontSize: 8.5,
                      color: ShopColors.inkFaint,
                    ),
                  ),
                Text(
                  p.atFa,
                  style: const TextStyle(
                    fontSize: 8.5,
                    color: ShopColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
      const Divider(height: 22),
      const _SectionTitle(
        icon: Icons.water_damage_outlined,
        text: 'ردیاب نشت',
      ),
      const Text(
        'هر خروجی چاپی/دانلودی واترمارک اختصاصی دارد؛ با تطبیق آن می‌توان منبع فایل منتشرشده را یافت.',
        style: TextStyle(fontSize: 9, height: 1.8, color: ShopColors.inkFaint),
      ),
      const SizedBox(height: 6),
      if (_leaks.isEmpty)
        _empty('ردی ثبت نشده است.')
      else
        for (final t in _leaks)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${t.userName} — ${t.action}',
                        style: const TextStyle(fontSize: 9.5),
                      ),
                      Text(
                        t.visibleWatermark,
                        style: const TextStyle(
                          fontSize: 8.5,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  t.createdAtFa,
                  style: const TextStyle(
                    fontSize: 8.5,
                    color: ShopColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
    ],
  );

  // ---------------- متن استخراج‌شده و نظرات ----------------

  Widget _textsCommentsTab() => ListView(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
    children: [
      const _SectionTitle(
        icon: Icons.file_present_outlined,
        text: 'متن استخراج‌شده و نتایج',
      ),
      if (_texts.isEmpty)
        _empty('متنی استخراج نشده است.')
      else
        for (final t in _texts)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ShopColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.fileName,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (t.isOcr)
                      const ShopTag(text: 'OCR', color: ShopColors.seed),
                    const SizedBox(width: 4),
                    ShopTag(
                      text: t.statusFa,
                      color: t.isIndexed ? ShopColors.ok : ShopColors.warn,
                    ),
                  ],
                ),
                Text(
                  '${Fa.digits(t.characterCount)} نویسه',
                  style: const TextStyle(
                    fontSize: 8.5,
                    color: ShopColors.inkFaint,
                  ),
                ),
                if (t.extractedText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      t.extractedText.length > 240
                          ? '${t.extractedText.substring(0, 240)}…'
                          : t.extractedText,
                      style: const TextStyle(
                        fontSize: 8.5,
                        height: 1.8,
                        color: ShopColors.inkSoft,
                      ),
                    ),
                  ),
                if (!t.isIndexed)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              try {
                                final m = await _repo.runOcr(t.attachmentId);
                                if (!mounted) return;
                                _toast(m.isEmpty ? 'OCR اجرا شد.' : m);
                                await _load();
                              } catch (e) {
                                if (!mounted) return;
                                _toast(_clean(e), error: true);
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            },
                      child: const Text(
                        'اجرای OCR',
                        style: TextStyle(fontSize: 9),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      const Divider(height: 22),
      const _SectionTitle(icon: Icons.forum_outlined, text: 'نظرات'),
      if (_comments.isEmpty)
        _empty('نظری ثبت نشده است.')
      else
        for (final c in _comments) _commentTile(c, top: true),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentCtrl,
              style: const TextStyle(fontSize: 11),
              maxLines: 2,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'نظر جدید…',
                hintStyle: TextStyle(fontSize: 9.5),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            onPressed: _busy ? null : _addComment,
            icon: const Icon(Icons.send_rounded, size: 16),
          ),
        ],
      ),
    ],
  );

  Widget _commentTile(DocComment c, {bool top = false}) => Padding(
    padding: EdgeInsets.only(bottom: 6, right: top ? 0 : 12),
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.authorName,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (c.isResolved)
                const ShopTag(text: 'بسته‌شده', color: ShopColors.ok),
              if (top && !c.isResolved)
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 24),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                  ),
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => _repo.resolveComment(widget.documentId, c.id),
                          'نظر بسته شد.',
                        ),
                  child: const Text('بستن', style: TextStyle(fontSize: 8.5)),
                ),
            ],
          ),
          Text(c.body, style: const TextStyle(fontSize: 9, height: 1.8)),
          Text(
            c.createdAtFa,
            style: const TextStyle(fontSize: 8, color: ShopColors.inkFaint),
          ),
          for (final r in c.replies) _commentTile(r),
        ],
      ),
    ),
  );

  Future<void> _addComment() async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty) return;
    await _run(() async {
      final msg = await _repo.addComment(
        documentId: widget.documentId,
        body: body,
      );
      _commentCtrl.clear();
      if (msg.isNotEmpty) _toast(msg);
    }, 'نظر ثبت شد.');
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icon, size: 14, color: ShopColors.seed),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}
