// ============================================================
//  «کارتابل آرشیو اسناد» — فاز ۹-ح (بخش ۱)
//  آینهٔ `Pages/DocArchive/DocCartable.razor` (مسیر وب: /doc-archive/cartable)
//
//  • سرصفحهٔ گرادیان نارنجی/سرخ «کارتابل آرشیو اسناد» + شمارندهٔ کارهای باز
//  • سوئیچ «نمایش انجام‌شده‌ها»
//  • هر کار: نوع («تایید ورژن» / «به‌روزرسانی مرتبط» / «هشدار انقضا» / «اعلان ورژن»)،
//    «کد — عنوان» + موضوع، «vN»، تاریخ، وضعیت («در انتظار» / «انجام شد» / «رد شد»)
//  • دکمهٔ «باز کردن مدرک» و «علامت‌گذاری به‌عنوان انجام‌شده» (برای کارهای غیرتاییدی)
//  • پیام خالی: «کاری در کارتابل شما نیست»
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/doc_archive_repository.dart';
import '../models/doc_archive_models.dart';
import 'doc_archive_detail_page.dart';
import 'system_style.dart';

class DocArchiveCartablePage extends StatefulWidget {
  const DocArchiveCartablePage({super.key});

  @override
  State<DocArchiveCartablePage> createState() => _DocArchiveCartablePageState();
}

class _DocArchiveCartablePageState extends State<DocArchiveCartablePage> {
  late final DocArchiveRepository _repo;

  bool _loading = true;
  bool _includeDone = false;
  String? _error;
  List<DocCartableItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _repo = DocArchiveRepository(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _repo.cartable(includeDone: _includeDone, take: 300);
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e
            .toString()
            .replaceFirst('ApiException: ', '')
            .replaceFirst('Exception: ', '')
            .trim();
      });
    }
  }

  Future<void> _close(DocCartableItem t) async {
    try {
      await _repo.closeCartableTask(t.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('کار بسته شد.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e
                .toString()
                .replaceFirst('ApiException: ', '')
                .replaceFirst('Exception: ', '')
                .trim(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  int get _openCount => _items.where((i) => i.isPending).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: const Text(
          'کارتابل آرشیو اسناد',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 26),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xffb45309), Color(0xffb91c1c)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.all(Radius.circular(15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.move_to_inbox_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'کارتابل آرشیو اسناد',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          Fa.digits(_openCount),
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xffb45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text(
                        'نمایش انجام‌شده‌ها',
                        style: TextStyle(fontSize: 10, color: Colors.white),
                      ),
                      Switch(
                        value: _includeDone,
                        activeThumbColor: Colors.white,
                        onChanged: (v) {
                          setState(() => _includeDone = v);
                          _load();
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (_error != null) ...[
              SystemNote(
                text: 'بارگذاری کارتابل ناموفق بود — $_error',
                color: ShopColors.danger,
                icon: Icons.error_outline_rounded,
              ),
              const SizedBox(height: 8),
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isEmpty)
              const SystemNote(
                text: 'کاری در کارتابل شما نیست',
                icon: Icons.inbox_rounded,
              )
            else
              for (final t in _items) _taskCard(t),
          ],
        ),
      ),
    );
  }

  Widget _taskCard(DocCartableItem t) {
    final kindColor = switch (t.kind) {
      'Approval' => ShopColors.warn,
      'RelatedUpdate' => ShopColors.teal,
      'ExpiryAlert' => ShopColors.danger,
      _ => ShopColors.inkSoft,
    };
    final statusColor = switch (t.status) {
      0 => ShopColors.warn,
      1 => ShopColors.ok,
      _ => ShopColors.danger,
    };
    return Opacity(
      opacity: t.isPending ? 1 : 0.62,
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: ShopColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 5,
              runSpacing: 5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ShopTag(text: t.kindLabel, color: kindColor),
                ShopTag(text: t.statusLabel, color: statusColor),
                if (t.versionNo > 0)
                  ShopTag(text: t.versionText, color: ShopColors.seed),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${t.documentCode} — ${t.documentTitle}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (t.title.trim().isNotEmpty)
              Text(
                t.title,
                style: const TextStyle(
                  fontSize: 9.5,
                  height: 1.7,
                  color: ShopColors.inkSoft,
                ),
              ),
            Text(
              Fa.date(t.createdAt?.toIso8601String()),
              style: const TextStyle(
                fontSize: 8.5,
                color: ShopColors.inkFaint,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              DocArchiveDetailPage(id: t.documentId),
                        ),
                      );
                      if (mounted) await _load();
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                    label: const Text(
                      'باز کردن مدرک',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ),
                if (t.canClose) ...[
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    onPressed: () => _close(t),
                    style: FilledButton.styleFrom(
                      backgroundColor: ShopColors.ok,
                      minimumSize: const Size(0, 34),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 14),
                    label: const Text(
                      'انجام شد',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
