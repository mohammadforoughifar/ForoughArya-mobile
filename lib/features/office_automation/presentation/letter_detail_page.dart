// ============================================================
//  صفحهٔ جزئیات نامه — داخلی / صادره / وارده
//  طراحی‌شده با زبان office_style.dart: هدر گرادیانی، تب کشویی،
//  کارت‌های بخش، حلقهٔ آمار، خط زمانی گردش و نوار اقدام شیشه‌ای
// ============================================================

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'dart:io';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../../../core/widgets/common.dart';
import '../data/office_repository.dart';
import '../models/email_models.dart';
import '../models/letter_models.dart';
import '../models/office_common.dart';
import 'office_style.dart';
import 'office_widgets.dart';
import '../../../core/utils/web_files.dart';

class LetterDetailPage extends StatefulWidget {
  const LetterDetailPage({
    super.key,
    required this.kind,
    required this.letterId,
    this.erjaId,
  });

  final LetterKind kind;
  final int letterId;
  final int? erjaId;

  @override
  State<LetterDetailPage> createState() => _LetterDetailPageState();
}

class _LetterDetailPageState extends State<LetterDetailPage>
    with SingleTickerProviderStateMixin {
  OfficeAutomationRepository get _repo =>
      context.read<OfficeAutomationRepository>();

  bool _loading = true;
  String? _error;
  bool _changed = false;

  InnerLetterDetail? _inner;
  OutgoingLetterDetail? _outgoing;
  Map<String, dynamic>? _incoming;

  List<LetterAttachment> _attachments = const [];
  List<GardeshNode> _gardesh = const [];

  late final TabController _tabs = TabController(length: 4, vsync: this);
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (_tabs.index != _tab && mounted) {
        setState(() => _tab = _tabs.index);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      switch (widget.kind) {
        case LetterKind.inner:
          final d = await _repo.innerDetail(widget.letterId);
          _inner = d;
        case LetterKind.outgoing:
          final d = await _repo.outgoingDetail(widget.letterId);
          _outgoing = d;
        case LetterKind.incoming:
          final d = await _repo.incomingDetailRaw(widget.letterId);
          _incoming = d;
      }
      await _loadSide();
      if (mounted) setState(() => _loading = false);
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
          _error = 'خطا در دریافت نامه: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadSide() async {
    try {
      final a = await _repo.attachments(widget.kind, widget.letterId);
      final g = await _repo.gardesh(widget.kind, widget.letterId);
      if (mounted) {
        setState(() {
          _attachments = a;
          _gardesh = g;
        });
      }
    } catch (_) {
      // پیوست/گردش اختیاری است؛ خطای آن صفحه را نمی‌شکند
    }
  }

  // ------------------------------------------------------------
  //  اقدام‌ها (منطق بدون تغییر نسبت به نسخهٔ قبل)
  // ------------------------------------------------------------

  Future<void> _erja() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OfficeColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ErjaSheet(kind: widget.kind, letterId: widget.letterId),
    );
    if (ok == true) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _answer() async {
    final text = await promptText(
      context,
      'متن پاسخ',
      hint: 'پاسخ خود را بنویسید…',
    );
    if (text == null || text.trim().isEmpty) return;
    try {
      await _repo.answerErja(
        widget.kind,
        erjaId: widget.erjaId ??
            _inner?.myErja?.erjaId ??
            _outgoing?.myErja?.erjaId ??
            0,
        answer: text.trim(),
      );
      _changed = true;
      await _load();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _sign() async {
    final note = await promptText(
      context,
      'پاراف / یادداشت امضا',
      hint: 'اختیاری — مثلاً «با احترام، مورد تأیید است»',
    );
    if (note == null) return;
    try {
      await _repo.signOutgoing(widget.letterId, note: note.trim());
      _changed = true;
      await _load();
      if (mounted) showMessage(context, 'نامه امضا شد.');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _dabirkhane() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OfficeColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _DabirkhaneSheet(letterId: widget.letterId),
    );
    if (ok == true) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _upload() async {
    try {
      final picked = await FilePicker.pickFiles();
      final file = picked.isEmpty ? null : picked.first;
      final path = file?.path;
      if (file == null || (path == null && !kIsWeb)) return;
      final size = file == null ? 0 : (file.lengthSync() ?? 0);
      if (size > 20 * 1024 * 1024) {
        if (mounted) {
          showMessage(context, 'حجم فایل بیش از ۲۰ مگابایت است.', error: true);
        }
        return;
      }
      await _repo.uploadAttachment(
        widget.kind,
        widget.letterId,
        path ?? '',
        file.name,
        bytes: kIsWeb ? await file.readAsBytes() : null,
      );
      _changed = true;
      await _loadSide();
      if (mounted) showMessage(context, 'پیوست بارگذاری شد.');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) showMessage(context, 'خطا در بارگذاری: $e', error: true);
    }
  }

  Future<void> _download(LetterAttachment a) async {
    try {
      final bytes = await _repo.downloadAttachment(widget.kind, a.id);
      if (bytes.isEmpty) {
        if (mounted) showMessage(context, 'فایل خالی است.', error: true);
        return;
      }
      if (await webDeliver(bytes, a.fileName)) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${a.fileName}');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        backgroundColor: OfficeColors.bg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.open_in_new, color: OfficeColors.seed),
                  title: const Text('بازکردن فایل', style: TextStyle(fontSize: 13.5)),
                  onTap: () {
                    Navigator.pop(c);
                    OpenFilex.open(file.path);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_outlined, color: OfficeColors.accent),
                  title: const Text('اشتراک‌گذاری', style: TextStyle(fontSize: 13.5)),
                  onTap: () {
                    Navigator.pop(c);
                    SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.blueGrey),
                  subtitle: Text(
                    file.path,
                    style: TextStyle(fontSize: 10.5, color: Colors.blueGrey.shade500),
                  ),
                  title: Text(
                    '${a.fileName} • ${Fa.bytes(a.size)}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) showMessage(context, 'خطا در دانلود: $e', error: true);
    }
  }

  Future<void> _deleteAttachment(LetterAttachment a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف پیوست'),
        content: Text('پیوست «${a.fileName}» حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteAttachment(widget.kind, a.id);
      _changed = true;
      await _loadSide();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _deleteLetter() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف نامه'),
        content: const Text('این نامه برای همیشه حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      switch (widget.kind) {
        case LetterKind.inner:
          await _repo.deleteInner(widget.letterId);
        case LetterKind.outgoing:
          await _repo.deleteOutgoing(widget.letterId);
        case LetterKind.incoming:
          await _repo.deleteIncoming(widget.letterId);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  // ------------------------------------------------------------
  //  داده‌های نمایشی مشترک سه نوع نامه
  // ------------------------------------------------------------

  String get _title => _inner?.title ?? _outgoing?.title ??
      pickStr(_incoming ?? const {}, ['title', 'Title'], '(بدون عنوان)');

  String get _number => _inner?.letterNumber ??
      _outgoing?.sadereNumber ?? _outgoing?.letterNumber ??
      pickStr(_incoming ?? const {}, ['letterNumber', 'LetterNumber']);

  String get _mahramanegi => _inner?.mahramanegi ??
      _outgoing?.mahramanegi ??
      pickStr(_incoming ?? const {}, ['mahramanegi', 'Mahramanegi'], 'عادی');

  String get _foriat {
    if (_inner != null) return _inner!.foriat;
    if (_outgoing != null) return _outgoing!.foriat;
    final raw = pick(_incoming ?? const {}, ['foriat', 'Foriat']);
    if (raw is num) {
      return switch (raw.toInt()) {
        >= 3 => 'آنی',
        2 => 'فوری',
        _ => 'عادی',
      };
    }
    return raw?.toString() ?? 'عادی';
  }

  DateTime? get _date => _inner?.dateSabt ??
      _outgoing?.dateSabt ??
      pickDate(_incoming ?? const {}, ['date', 'Date', 'dateErsal']);

  String get _sender => _inner?.senderName ??
      _outgoing?.senderName ??
      pickStr(_incoming ?? const {}, ['ferestande', 'Ferestande']);

  String? get _text {
    final t = _inner?.text ?? _outgoing?.text;
    if (t != null && t.trim().isNotEmpty) return t;
    final d = pickStr(_incoming ?? const {}, ['description', 'Description']);
    return d.trim().isEmpty ? null : d;
  }

  ErjaItem? get _myErja => _inner?.myErja ?? _outgoing?.myErja;

  /// درصد گردش — بر پایهٔ نسبت خوانده‌شده/پاسخ‌داده‌شده در گردش نامه
  double get _gardeshProgress {
    if (_gardesh.isEmpty) return 0;
    final flat = _flatten(_gardesh);
    if (flat.isEmpty) return 0;
    final done = flat.where((n) => n.isRead || n.answer.isNotEmpty).length;
    return done / flat.length;
  }

  List<GardeshNode> _flatten(List<GardeshNode> nodes) => [
    ...nodes,
    ...nodes.expand((n) => _flatten(n.children)),
  ];

  // ============================================================
  //  ساختار صفحه
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final accent = OfficeColors.forKind(widget.kind);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: OfficeColors.bg,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : Column(
                    children: [
                      // ---------- هدر ثابت ----------
                      _heroHeader(accent),
                      // ---------- تب کشویی ----------
                      Container(
                        color: OfficeColors.deep,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: OfficeSlidingTabs(
                            items: const [
                              (label: 'نامه', icon: Icons.description_outlined, key: 'letter'),
                              (label: 'پیوست', icon: Icons.attach_file, key: 'attach'),
                              (label: 'گردش', icon: Icons.account_tree_outlined, key: 'gardesh'),
                              (label: 'ارجاع من', icon: Icons.assignment_ind_outlined, key: 'mine'),
                            ],
                            index: _tab,
                            onChanged: (i) {
                              _tabs.animateTo(i);
                              setState(() => _tab = i);
                            },
                            background: Colors.transparent,
                            pillColor: accent,
                            showCounts: true,
                            counts: {
                              'attach': _attachments.length,
                              'gardesh': _flatten(_gardesh).length,
                              'mine': _myErja == null ? 0 : 1,
                            },
                          ),
                        ),
                      ),
                      // ---------- محتوا ----------
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _load,
                          child: IndexedStack(
                            index: _tab,
                            children: [
                              _letterTab(accent),
                              _attachTab(),
                              _gardeshTab(),
                              _mineTab(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
        bottomNavigationBar: _loading || _error != null ? null : _actionBar(accent),
      ),
    );
  }

  // ------------------------------------------------------------
  //  هدر صفحه
  // ------------------------------------------------------------

  Widget _heroHeader(Color accent) {
    final statusChip = _outgoing != null
        ? HeroBadge(
            label: _outgoing!.statusLabel,
            icon: Icons.verified_outlined,
            color: OfficeColors.forOutgoingStatus(_outgoing!.status),
          )
        : null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [OfficeColors.deep, accent, OfficeColors.accent.withValues(alpha: .85)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: OfficeColors.deep.withValues(alpha: .28),
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
                top: -50,
                child: Container(
                  width: 150,
                  height: 150,
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
                    padding: const EdgeInsets.fromLTRB(6, 6, 10, 2),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context, _changed),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          tooltip: 'بازگشت',
                        ),
                        Expanded(
                          child: Text(
                            widget.kind.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          tooltip: 'به‌روزرسانی',
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onSelected: (v) {
                            if (v == 'delete') _deleteLetter();
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete_outline, color: Colors.red),
                                title: Text('حذف نامه', style: TextStyle(fontSize: 13)),
                                dense: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (_number.isNotEmpty)
                              HeroBadge(
                                label: 'شماره ${Fa.digits(_number)}',
                                icon: Icons.confirmation_number_outlined,
                              ),
                            HeroBadge(
                              label: _mahramanegi,
                              icon: Icons.lock_outline,
                              color: OfficeColors.forConfidential(_mahramanegi),
                            ),
                            HeroBadge(
                              label: _foriat,
                              icon: Icons.bolt,
                              color: _foriat == 'عادی' ? null : OfficeColors.signing,
                            ),
                            ?statusChip,
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            height: 1.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (_sender.isNotEmpty) ...[
                              Icon(Icons.person_outline,
                                  size: 13, color: Colors.white.withValues(alpha: .8)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _sender,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .9),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Icon(Icons.schedule,
                                size: 13, color: Colors.white.withValues(alpha: .8)),
                            const SizedBox(width: 4),
                            Text(
                              Fa.date(_date?.toIso8601String()),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .9),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                        if (_gardesh.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Icon(Icons.timeline,
                                  size: 14, color: Colors.white.withValues(alpha: .85)),
                              const SizedBox(width: 5),
                              Text(
                                'پیشرفت گردش',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: .85),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${Fa.digits((_gardeshProgress * 100).round())}٪',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: _gardeshProgress),
                              duration: const Duration(milliseconds: 950),
                              curve: Curves.easeOutCubic,
                              builder: (context, v, child) => LinearProgressIndicator(
                                value: v,
                                minHeight: 7,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  //  تب ۱ — متن و مشخصات نامه
  // ------------------------------------------------------------

  Widget _letterTab(Color accent) => ListView(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
    children: [
      // --- نوار آماری ---
      OFadeSlideIn(
        index: 0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: OfficeColors.line),
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withValues(alpha: .05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OfficeRing(
                value: _gardesh.isEmpty
                    ? 0
                    : _flatten(_gardesh).where((n) => n.isRead).length /
                        _flatten(_gardesh).length,
                label: 'خوانده‌شده',
                color: accent,
              ),
              _vDivider(),
              MiniStat(
                icon: Icons.attach_file,
                value: Fa.digits(_attachments.length),
                label: 'پیوست',
                color: const Color(0xff2a6bd4),
              ),
              _vDivider(),
              MiniStat(
                icon: Icons.account_tree_outlined,
                value: Fa.digits(_flatten(_gardesh).length),
                label: 'گردش',
                color: OfficeColors.accent,
              ),
              _vDivider(),
              MiniStat(
                icon: Icons.groups_outlined,
                value: Fa.digits(_recipientCount()),
                label: 'گیرنده',
                color: OfficeColors.ok,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),

      // --- متن نامه ---
      if (_text != null)
        OFadeSlideIn(
          index: 1,
          child: OfficeCard(
            title: 'متن نامه',
            icon: Icons.article_outlined,
            color: accent,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xfff7f9fc),
                  borderRadius: BorderRadius.circular(12),
                  border: BorderDirectional(
                    start: BorderSide(color: accent.withValues(alpha: .55), width: 3),
                  ),
                ),
                // متن نامه در وب با ادیتور HTML ثبت می‌شود؛ در موبایل
                // باید به متن خوانا تبدیل شود، نه نمایش تگ‌های خام.
                child: SelectableText(
                  isHtmlLike(_text!) ? htmlToPlain(_text!) : _text!,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.95,
                    color: Color(0xff22314a),
                  ),
                ),
              ),
            ],
          ),
        ),

      // --- مشخصات ---
      OFadeSlideIn(
        index: 2,
        child: OfficeCard(
          title: 'مشخصات نامه',
          icon: Icons.badge_outlined,
          color: OfficeColors.accent,
          children: [
            if (_inner != null) ...[
              OfficeInfoTile(
                icon: Icons.person_outline,
                label: 'فرستنده',
                value: _inner!.senderName,
                color: accent,
              ),
              OfficeInfoTile(
                icon: Icons.confirmation_number_outlined,
                label: 'شمارهٔ نامه',
                value: Fa.digits(_inner!.letterNumber),
                color: Colors.blueGrey.shade400,
              ),
              OfficeInfoTile(
                icon: Icons.login,
                label: 'تاریخ ثبت',
                value: Fa.date(_inner!.dateSabt?.toIso8601String()),
                color: Colors.blueGrey.shade400,
              ),
              OfficeInfoTile(
                icon: Icons.lock_outline,
                label: 'محرمانگی',
                value: _inner!.mahramanegi,
                color: OfficeColors.forConfidential(_inner!.mahramanegi),
              ),
              OfficeInfoTile(
                icon: Icons.bolt,
                label: 'فوریت',
                value: _inner!.foriat,
                color: _inner!.foriat == 'عادی'
                    ? Colors.blueGrey.shade400
                    : OfficeColors.signing,
              ),
            ],
            if (_outgoing != null) ...[
              OfficeInfoTile(
                icon: Icons.apartment,
                label: 'سازمان مقصد',
                value: _outgoing!.receiverOrganization,
                color: accent,
              ),
              if ((_outgoing!.receiverName ?? '').isNotEmpty)
                OfficeInfoTile(
                  icon: Icons.person_outline,
                  label: 'شخص گیرنده',
                  value: _outgoing!.receiverName!,
                  color: Colors.blueGrey.shade400,
                ),
              if ((_outgoing!.receiverTitle ?? '').isNotEmpty)
                OfficeInfoTile(
                  icon: Icons.badge_outlined,
                  label: 'سمت گیرنده',
                  value: _outgoing!.receiverTitle!,
                  color: Colors.blueGrey.shade400,
                ),
              if ((_outgoing!.receiverAddress ?? '').isNotEmpty)
                OfficeInfoTile(
                  icon: Icons.place_outlined,
                  label: 'نشانی',
                  value: _outgoing!.receiverAddress!,
                  color: Colors.blueGrey.shade400,
                ),
              if ((_outgoing!.externalRefNumber ?? '').isNotEmpty)
                OfficeInfoTile(
                  icon: Icons.tag,
                  label: 'شمارهٔ نامهٔ طرف مقابل',
                  value: Fa.digits(_outgoing!.externalRefNumber!),
                  color: Colors.blueGrey.shade400,
                ),
              OfficeInfoTile(
                icon: Icons.verified_outlined,
                label: 'وضعیت',
                value: _outgoing!.statusLabel,
                color: OfficeColors.forOutgoingStatus(_outgoing!.status),
              ),
              OfficeInfoTile(
                icon: Icons.login,
                label: 'تاریخ ثبت',
                value: Fa.date(_outgoing!.dateSabt?.toIso8601String()),
                color: Colors.blueGrey.shade400,
              ),
            ],
            if (_incoming != null) ...[
              OfficeInfoTile(
                icon: Icons.business,
                label: 'فرستنده',
                value: pickStr(_incoming!, ['ferestande', 'Ferestande']),
                color: accent,
              ),
              OfficeInfoTile(
                icon: Icons.tag,
                label: 'شمارهٔ نامهٔ مبدأ',
                value: Fa.digits(
                  pickStr(_incoming!, ['numberLetterVarede', 'NumberLetterVarede']),
                ),
                color: Colors.blueGrey.shade400,
              ),
              OfficeInfoTile(
                icon: Icons.event,
                label: 'تاریخ نامه',
                value: Fa.date(
                  pickDate(_incoming!, ['date', 'Date'])?.toIso8601String(),
                  time: false,
                ),
                color: Colors.blueGrey.shade400,
              ),
              OfficeInfoTile(
                icon: Icons.login,
                label: 'تاریخ ثبت',
                value: Fa.date(
                  pickDate(_incoming!, ['dateErsal', 'DateErsal'])?.toIso8601String(),
                ),
                color: Colors.blueGrey.shade400,
              ),
              OfficeInfoTile(
                icon: Icons.local_shipping_outlined,
                label: 'روش ارسال',
                value: pickStr(_incoming!, ['typeErsal', 'TypeErsal']),
                color: Colors.blueGrey.shade400,
              ),
              OfficeInfoTile(
                icon: Icons.person_outline,
                label: 'تحویل‌گیرنده',
                value: pickStr(_incoming!, ['deliveryName', 'DeliveryName']),
                color: Colors.blueGrey.shade400,
              ),
            ],
          ],
        ),
      ),

      // --- رونوشت‌ها ---
      if (_outgoing != null && _outgoing!.copyTos.isNotEmpty)
        OFadeSlideIn(
          index: 3,
          child: OfficeCard(
            title: 'رونوشت‌ها (${Fa.digits(_outgoing!.copyTos.length)})',
            icon: Icons.content_copy_outlined,
            color: OfficeColors.accent,
            children: [
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: _outgoing!.copyTos
                    .map((c) => _Pill(label: c.label, color: OfficeColors.accent))
                    .toList(),
              ),
            ],
          ),
        ),

      // --- گیرندگان داخلی ---
      if (_inner != null) ...[
        if (_inner!.girande.isNotEmpty)
          _recipientsCard('گیرندگان', _inner!.girande, Icons.groups_outlined,
              OfficeColors.ok, 4),
        if (_inner!.erja.isNotEmpty)
          _recipientsCard('ارجاع (جهت اقدام)', _inner!.erja, Icons.redo,
              OfficeColors.seed, 5),
        if (_inner!.hamesh.isNotEmpty)
          _recipientsCard('هامش (رونوشت)', _inner!.hamesh,
              Icons.content_copy_outlined, OfficeColors.accent, 6),
      ],

      // --- امضاکنندگان ---
      if (_outgoing != null && _outgoing!.signers.isNotEmpty)
        OFadeSlideIn(
          index: 7,
          child: OfficeCard(
            title: 'امضاکنندگان (${Fa.digits(_outgoing!.signers.length)})',
            icon: Icons.draw_outlined,
            color: OfficeColors.signing,
            trailing: _outgoing!.isMyTurnToSign
                ? FilledButton.icon(
                    onPressed: _sign,
                    style: FilledButton.styleFrom(
                      backgroundColor: OfficeColors.signing,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 32),
                      textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                    icon: const Icon(Icons.draw_outlined, size: 14),
                    label: const Text('امضا'),
                  )
                : null,
            children: [
              ...(_outgoing!.signers.toList()
                    ..sort((a, b) => a.order.compareTo(b.order)))
                  .map(_signerTile),
            ],
          ),
        ),

      // --- نامه‌های مرتبط ---
      if (_related.isNotEmpty)
        OFadeSlideIn(
          index: 8,
          child: OfficeCard(
            title: 'نامه‌های مرتبط',
            icon: Icons.link,
            color: const Color(0xff2a6bd4),
            children: _related
                .map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xff2a6bd4).withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(Icons.description_outlined,
                              size: 15, color: Color(0xff2a6bd4)),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.title.isEmpty ? '(بدون عنوان)' : r.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'شماره ${Fa.digits(r.number)}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.blueGrey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _Pill(label: r.kindLabel, color: OfficeColors.accent),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),

      // --- دبیرخانه ---
      if (_outgoing != null && _outgoing!.dabirkhaneSabt)
        _dabirkhaneCard(_outgoing!),
    ],
  );

  List<RelatedLetter> get _related =>
      _inner?.relatedLetters ?? _outgoing?.relatedLetters ?? const [];

  int _recipientCount() {
    if (_inner != null) {
      return _inner!.girande.length + _inner!.erja.length + _inner!.hamesh.length;
    }
    if (_outgoing != null) return _outgoing!.copyTos.length + _outgoing!.signers.length;
    return 0;
  }

  Widget _vDivider() => Container(
    width: 1,
    height: 34,
    color: OfficeColors.line,
  );

  Widget _recipientsCard(
    String title,
    List<LetterRecipient> list,
    IconData icon,
    Color color,
    int index,
  ) => OFadeSlideIn(
    index: index,
    child: OfficeCard(
      title: '$title (${Fa.digits(list.length)})',
      icon: icon,
      color: color,
      children: [
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: list
              .map(
                (r) => _Pill(
                  label: r.positions.isEmpty ? r.label : '${r.label} • ${r.positions.first}',
                  color: color,
                  icon: Icons.person_outline,
                ),
              )
              .toList(),
        ),
      ],
    ),
  );

  Widget _signerTile(OutgoingSigner s) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: s.isSigned
          ? OfficeColors.ok.withValues(alpha: .045)
          : const Color(0xfff7f9fc),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: s.isSigned
            ? OfficeColors.ok.withValues(alpha: .25)
            : OfficeColors.line,
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: s.isSigned
                  ? [const Color(0xff3fb27f), OfficeColors.ok]
                  : [Colors.blueGrey.shade200, Colors.blueGrey.shade100],
            ),
            shape: BoxShape.circle,
          ),
          child: s.isSigned
              ? const Icon(Icons.check, size: 17, color: Colors.white)
              : Text(
                  Fa.digits(s.order),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.blueGrey.shade600,
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.userName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              if ((s.sematTitle ?? '').isNotEmpty)
                Text(
                  s.sematTitle!,
                  style: TextStyle(fontSize: 10.5, color: Colors.blueGrey.shade500),
                ),
              if ((s.signNote ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    'پاراف: ${s.signNote}',
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.6,
                      color: Colors.blueGrey.shade600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        _Pill(
          label: s.isSigned
              ? Fa.date(s.dateSigned?.toIso8601String(), time: false)
              : 'در انتظار',
          color: s.isSigned ? OfficeColors.ok : OfficeColors.signing,
          icon: s.isSigned ? Icons.check_circle_outline : Icons.schedule,
        ),
      ],
    ),
  );

  Widget _dabirkhaneCard(OutgoingLetterDetail d) => OFadeSlideIn(
    index: 9,
    child: OfficeCard(
      title: 'ثبت دبیرخانه',
      icon: Icons.account_balance_outlined,
      color: OfficeColors.dabirkhane,
      children: [
        OfficeInfoTile(
          icon: Icons.event_available,
          label: 'تاریخ ثبت',
          value: Fa.date(d.dateDabirkhane?.toIso8601String()),
          color: OfficeColors.dabirkhane,
        ),
        OfficeInfoTile(
          icon: Icons.local_shipping_outlined,
          label: 'روش ارسال',
          value: d.sendMethod ?? '',
          color: Colors.blueGrey.shade400,
        ),
        OfficeInfoTile(
          icon: Icons.tag,
          label: 'شمارهٔ ثبت مقصد',
          value: d.destRegNumber ?? '',
          color: Colors.blueGrey.shade400,
        ),
        OfficeInfoTile(
          icon: Icons.person_outline,
          label: 'تحویل‌گیرنده',
          value: d.delivererName ?? '',
          color: Colors.blueGrey.shade400,
        ),
        OfficeInfoTile(
          icon: Icons.qr_code_2,
          label: 'کد رهگیری',
          value: d.trackingCode ?? '',
          color: Colors.blueGrey.shade400,
        ),
        OfficeInfoTile(
          icon: Icons.print_outlined,
          label: 'فکس مقصد',
          value: d.destFax ?? '',
          color: Colors.blueGrey.shade400,
        ),
        OfficeInfoTile(
          icon: Icons.mail_outline,
          label: 'ایمیل مقصد',
          value: d.destEmail ?? '',
          color: Colors.blueGrey.shade400,
        ),
        OfficeInfoTile(
          icon: Icons.notes_outlined,
          label: 'توضیحات',
          value: d.dabirkhaneNote ?? '',
          color: Colors.blueGrey.shade400,
        ),
      ],
    ),
  );

  // ------------------------------------------------------------
  //  تب ۲ — پیوست‌ها
  // ------------------------------------------------------------

  Widget _attachTab() => ListView(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
    children: [
      OfficeCard(
        title: 'پیوست‌ها (${Fa.digits(_attachments.length)})',
        icon: Icons.attach_file,
        color: const Color(0xff2a6bd4),
        trailing: FilledButton.icon(
          onPressed: _upload,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xff2a6bd4),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(0, 34),
            textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
          icon: const Icon(Icons.upload_file, size: 15),
          label: const Text('افزودن'),
        ),
        children: [
          if (_attachments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xff2a6bd4).withValues(alpha: .08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.attach_file,
                          size: 25, color: Color(0xff2a6bd4)),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'پیوستی ثبت نشده است.',
                      style: TextStyle(fontSize: 12.5, color: Colors.blueGrey.shade500),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'حداکثر ۲۰ مگابایت برای هر فایل',
                      style: TextStyle(fontSize: 10.5, color: Colors.blueGrey.shade400),
                    ),
                  ],
                ),
              ),
            )
          else
            ...List.generate(_attachments.length, (i) {
              final a = _attachments[i];
              return OFadeSlideIn(
                index: i,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0xfff7f9fc),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: OfficeColors.line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xff2a6bd4).withValues(alpha: .18),
                              const Color(0xff2a6bd4).withValues(alpha: .07),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(Icons.insert_drive_file_outlined,
                            size: 18, color: Color(0xff2a6bd4)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.fileName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${Fa.bytes(a.size)} • ${a.uploaderName}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.blueGrey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _download(a),
                        icon: const Icon(Icons.download_outlined, size: 19),
                        tooltip: 'دانلود',
                        color: const Color(0xff2a6bd4),
                      ),
                      IconButton(
                        onPressed: () => _deleteAttachment(a),
                        icon: const Icon(Icons.delete_outline, size: 19),
                        tooltip: 'حذف',
                        color: OfficeColors.danger,
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    ],
  );

  // ------------------------------------------------------------
  //  تب ۳ — گردش نامه (خط زمانی)
  // ------------------------------------------------------------

  Widget _gardeshTab() => ListView(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
    children: [
      if (_gardesh.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Center(
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: OfficeColors.accent.withValues(alpha: .08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_tree_outlined,
                      size: 28, color: OfficeColors.accent),
                ),
                const SizedBox(height: 12),
                Text(
                  'گردشی ثبت نشده است.',
                  style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade500),
                ),
              ],
            ),
          ),
        )
      else
        ...List.generate(_gardesh.length, (i) {
          final n = _gardesh[i];
          return OFadeSlideIn(
            index: i,
            child: OfficeCard(
              title: '${n.sender} ← ${n.receiver}',
              icon: n.isRead ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined,
              color: n.isRead ? OfficeColors.ok : const Color(0xff2a6bd4),
              trailing: _Pill(
                label: n.type,
                color: OfficeColors.accent,
              ),
              children: [
                if (n.amalgarTitle != null && n.amalgarTitle!.isNotEmpty)
                  OfficeInfoTile(
                    icon: Icons.alt_route,
                    label: 'عملگر',
                    value: n.amalgarTitle!,
                    color: OfficeColors.accent,
                  ),
                OfficeInfoTile(
                  icon: Icons.schedule,
                  label: 'تاریخ',
                  value: Fa.date(n.date?.toIso8601String()),
                  color: Colors.blueGrey.shade400,
                ),
                if (n.deadline != null)
                  OfficeInfoTile(
                    icon: Icons.timer_outlined,
                    label: 'مهلت پاسخ',
                    value: Fa.date(n.deadline!.toIso8601String(), time: false),
                    color: n.deadline!.isBefore(DateTime.now())
                        ? OfficeColors.danger
                        : OfficeColors.signing,
                  ),
                if (n.matnErja.trim().isNotEmpty)
                  _quoteBox('دستور ارجاع', n.matnErja, OfficeColors.seed),
                if (n.answer.trim().isNotEmpty)
                  _quoteBox('پاسخ', n.answer, OfficeColors.ok),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Pill(
                      label: n.isRead ? 'خوانده شد' : 'خوانده نشده',
                      color: n.isRead ? OfficeColors.ok : const Color(0xff2a6bd4),
                      icon: n.isRead
                          ? Icons.check_circle_outline
                          : Icons.mark_email_unread_outlined,
                    ),
                    if (n.typeTaeed != 0)
                      _Pill(
                        label: n.typeTaeed == 1 ? 'تأیید شد' : 'رد شد',
                        color: n.typeTaeed == 1
                            ? OfficeColors.ok
                            : OfficeColors.danger,
                        icon: n.typeTaeed == 1
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                      ),
                    if (n.showForAll)
                      const _Pill(
                        label: 'برای همه',
                        color: OfficeColors.gold,
                        icon: Icons.groups_outlined,
                      ),
                  ],
                ),
                if (n.children.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _childGardesh(n.children, 0),
                ],
              ],
            ),
          );
        }),
    ],
  );

  Widget _childGardesh(List<GardeshNode> nodes, int depth) => Padding(
    padding: EdgeInsetsDirectional.only(start: 10.0 + depth * 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in nodes)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: (c.isRead ? OfficeColors.ok : const Color(0xff2a6bd4))
                        .withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    c.isRead ? Icons.check : Icons.subdirectory_arrow_left,
                    size: 12,
                    color: c.isRead ? OfficeColors.ok : const Color(0xff2a6bd4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${c.sender} ← ${c.receiver}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (c.matnErja.trim().isNotEmpty)
                        Text(
                          c.matnErja,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.6,
                            color: Colors.blueGrey.shade600,
                          ),
                        ),
                      Text(
                        Fa.date(c.date?.toIso8601String()),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blueGrey.shade400,
                        ),
                      ),
                      if (c.children.isNotEmpty) _childGardesh(c.children, depth + 1),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _quoteBox(String label, String text, Color color) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(11),
        border: BorderDirectional(
          start: BorderSide(color: color.withValues(alpha: .55), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.75,
              color: Colors.blueGrey.shade800,
            ),
          ),
        ],
      ),
    ),
  );

  // ------------------------------------------------------------
  //  تب ۴ — ارجاع به من
  // ------------------------------------------------------------

  Widget _mineTab() {
    final e = _myErja;
    if (e == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(14, 60, 14, 100),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: OfficeColors.ok.withValues(alpha: .08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.assignment_turned_in_outlined,
                      size: 28, color: OfficeColors.ok),
                ),
                const SizedBox(height: 12),
                Text(
                  'ارجاعی به شما ثبت نشده است.',
                  style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade500),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final late = e.deadline != null && e.deadline!.isBefore(DateTime.now());
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
      children: [
        OFadeSlideIn(
          index: 0,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (late ? OfficeColors.danger : OfficeColors.seed)
                      .withValues(alpha: .10),
                  Colors.white,
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: (late ? OfficeColors.danger : OfficeColors.seed)
                    .withValues(alpha: .25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: late
                          ? [const Color(0xffe05357), OfficeColors.danger]
                          : [const Color(0xff4f7ce8), OfficeColors.seed],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    late ? Icons.warning_amber_rounded : Icons.assignment_ind_outlined,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        late ? 'مهلت پاسخ گذشته است' : 'ارجاع فعال به شما',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: late ? OfficeColors.danger : OfficeColors.deep,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        e.deadline == null
                            ? 'بدون مهلت مشخص'
                            : 'مهلت: ${Fa.date(e.deadline!.toIso8601String(), time: false)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blueGrey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        OfficeCard(
          title: 'جزئیات ارجاع',
          icon: Icons.info_outline,
          color: OfficeColors.seed,
          children: [
            OfficeInfoTile(
              icon: Icons.person_outline,
              label: 'ارجاع‌دهنده',
              value: e.senderName,
              color: OfficeColors.seed,
            ),
            OfficeInfoTile(
              icon: Icons.redo,
              label: 'نوع ارجاع',
              value: e.type,
              color: OfficeColors.accent,
            ),
            if ((e.amalgarTitle ?? '').isNotEmpty)
              OfficeInfoTile(
                icon: Icons.alt_route,
                label: 'عملگر',
                value: e.amalgarTitle!,
                color: Colors.blueGrey.shade400,
              ),
            OfficeInfoTile(
              icon: Icons.schedule,
              label: 'تاریخ ارجاع',
              value: Fa.date(e.date?.toIso8601String()),
              color: Colors.blueGrey.shade400,
            ),
            if (e.deadline != null)
              OfficeInfoTile(
                icon: Icons.timer_outlined,
                label: 'مهلت پاسخ',
                value: Fa.date(e.deadline!.toIso8601String(), time: false),
                color: late ? OfficeColors.danger : OfficeColors.signing,
              ),
            if (e.typeTaeed != 0)
              OfficeInfoTile(
                icon: e.typeTaeed == 1 ? Icons.check_circle_outline : Icons.cancel_outlined,
                label: 'نتیجهٔ شما',
                value: e.taeedLabel,
                color: e.typeTaeed == 1 ? OfficeColors.ok : OfficeColors.danger,
              ),
          ],
        ),
        if (e.matnErja.trim().isNotEmpty)
          OfficeCard(
            title: 'دستور ارجاع',
            icon: Icons.short_text,
            color: OfficeColors.accent,
            children: [_quoteBox('متن دستور', e.matnErja, OfficeColors.accent)],
          ),
        if (e.answer.trim().isNotEmpty)
          OfficeCard(
            title: 'پاسخ ثبت‌شدهٔ شما',
            icon: Icons.reply_outlined,
            color: OfficeColors.ok,
            children: [_quoteBox('پاسخ', e.answer, OfficeColors.ok)],
          ),
      ],
    );
  }

  // ------------------------------------------------------------
  //  نوار اقدام پایین
  // ------------------------------------------------------------

  Widget? _actionBar(Color accent) {
    final canAnswer = _myErja != null;
    final o = _outgoing;
    final canSign = o != null && o.isMyTurnToSign;
    final canDabirkhane = o != null && o.isIssued && !o.dabirkhaneSabt;

    if (!canAnswer && !canSign && !canDabirkhane) return null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: OfficeColors.line),
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withValues(alpha: .10),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              if (canAnswer)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _answer,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OfficeColors.seed,
                      side: BorderSide(color: OfficeColors.seed.withValues(alpha: .5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    icon: const Icon(Icons.reply_outlined, size: 18),
                    label: const Text(
                      'پاسخ',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              if (canAnswer) const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: canSign
                      ? _sign
                      : canDabirkhane
                          ? _dabirkhane
                          : _erja,
                  style: FilledButton.styleFrom(
                    backgroundColor: canSign
                        ? OfficeColors.signing
                        : canDabirkhane
                            ? OfficeColors.dabirkhane
                            : accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: Icon(
                    canSign
                        ? Icons.draw_outlined
                        : canDabirkhane
                            ? Icons.account_balance_outlined
                            : Icons.redo,
                    size: 18,
                  ),
                  label: Text(
                    canSign
                        ? 'امضای نامه'
                        : canDabirkhane
                            ? 'ثبت دبیرخانه'
                            : 'ارجاع نامه',
                    style: const TextStyle(fontWeight: FontWeight.w700),
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

/// برچسب قرصی‌شکل کوچک
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .20)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
        ],
        Text(
          label,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    ),
  );
}

// ============================================================
//  فرم ارجاع
// ============================================================

class _ErjaSheet extends StatefulWidget {
  const _ErjaSheet({required this.kind, required this.letterId});

  final LetterKind kind;
  final int letterId;

  @override
  State<_ErjaSheet> createState() => _ErjaSheetState();
}

class _ErjaSheetState extends State<_ErjaSheet> {
  final _text = TextEditingController();
  final _selected = <int, LetterRecipient>{};
  final _hamesh = <int, LetterRecipient>{};
  List<Amalgar> _amalgars = const [];
  int _amalgarId = 1;
  String _type = 'ارجاع';
  DateTime? _deadline;
  bool _busy = false;
  bool _loadingAmalgars = true;

  OfficeAutomationRepository get _repo =>
      context.read<OfficeAutomationRepository>();

  @override
  void initState() {
    super.initState();
    _loadAmalgars();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _loadAmalgars() async {
    try {
      final list = await _repo.amalgars(widget.kind);
      if (mounted) {
        setState(() {
          _amalgars = list;
          _loadingAmalgars = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAmalgars = false);
    }
  }

  Future<void> _pickReceivers({required bool hamesh}) async {
    final result = await pickRecipients(
      context,
      title: hamesh ? 'انتخاب رونوشت (هامش)' : 'انتخاب گیرندگان',
      loadUsers: () => _repo.recipients(widget.kind),
      loadGroups: () => _repo.groups(widget.kind),
      initial: (hamesh ? _hamesh : _selected).values.toList(),
    );
    if (result == null) return;
    setState(() {
      final target = hamesh ? _hamesh : _selected;
      target
        ..clear()
        ..addEntries(result.map((r) => MapEntry(r.userId, r)));
    });
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) {
      showMessage(context, 'حداقل یک گیرنده انتخاب کنید.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await _repo.addErja(
        widget.kind,
        letterId: widget.letterId,
        receivers: _selected.values.map((r) => r.userId).toList(),
        hamesh: _hamesh.values.map((r) => r.userId).toList(),
        text: _text.text.trim(),
        amalgarId: _amalgarId,
        deadline: _deadline,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      bottom: MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: DraggableScrollableSheet(
      expand: false,
      initialChildSize: .88,
      maxChildSize: .96,
      builder: (context, scroll) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: OfficeColors.heroGradient,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.redo, size: 17, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'ارجاع نامه',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              children: [
                // نوع ارجاع
                const _FieldLabel('نوع ارجاع'),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: (_amalgars.isEmpty
                          ? OfficeConst.erjaTypes
                              .map((t) => Amalgar(id: 1, title: t))
                              .toList()
                          : _amalgars)
                      .map(
                        (a) => GestureDetector(
                          onTap: () => setState(() {
                            _type = a.title;
                            _amalgarId = a.id;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 15, vertical: 9),
                            decoration: BoxDecoration(
                              gradient: _type == a.title
                                  ? const LinearGradient(
                                      colors: [OfficeColors.seed, Color(0xff4f7ce8)],
                                    )
                                  : null,
                              color: _type == a.title ? null : Colors.white,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: _type == a.title
                                    ? Colors.transparent
                                    : OfficeColors.line,
                              ),
                              boxShadow: _type == a.title
                                  ? [
                                      BoxShadow(
                                        color: OfficeColors.seed.withValues(alpha: .3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              a.title,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: _type == a.title
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: _type == a.title
                                    ? Colors.white
                                    : Colors.blueGrey.shade700,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),

                // دستور ارجاع
                const _FieldLabel('دستور ارجاع'),
                TextField(
                  controller: _text,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13, height: 1.7),
                  decoration: _inputDeco('مثلاً: بررسی و اعلام نظر تا پایان هفته'),
                ),
                const SizedBox(height: 14),

                // گیرندگان
                const _FieldLabel('گیرندگان'),
                _chipList(
                  _selected.values.toList(),
                  () => _pickReceivers(hamesh: false),
                  'افزودن گیرنده…',
                ),
                const SizedBox(height: 14),

                // هامش
                const _FieldLabel('رونوشت (هامش)'),
                _chipList(
                  _hamesh.values.toList(),
                  () => _pickReceivers(hamesh: true),
                  'افزودن رونوشت…',
                ),
                const SizedBox(height: 14),

                // مهلت
                const _FieldLabel('مهلت پاسخ'),
                InkWell(
                  onTap: () async {
                    final d = await showJalaliDatePicker(
                      context,
                      initial: _deadline ?? DateTime.now(),
                      title: 'مهلت پاسخ (شمسی)',
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 1),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setState(() => _deadline = d);
                  },
                  borderRadius: BorderRadius.circular(13),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: OfficeColors.line),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event_outlined,
                            size: 18, color: Colors.blueGrey.shade400),
                        const SizedBox(width: 8),
                        Text(
                          _deadline == null
                              ? 'بدون مهلت'
                              : Fa.date(_deadline!.toIso8601String(), time: false),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: _deadline == null
                                ? Colors.blueGrey.shade400
                                : const Color(0xff16233a),
                          ),
                        ),
                        const Spacer(),
                        if (_deadline != null)
                          GestureDetector(
                            onTap: () => setState(() => _deadline = null),
                            child: Icon(Icons.close,
                                size: 17, color: Colors.blueGrey.shade400),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_loadingAmalgars)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text('انصراف'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: OfficeColors.seed,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send, size: 17),
                        label: Text(
                          _busy ? 'در حال ارسال…' : 'ثبت ارجاع',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _chipList(
    List<LetterRecipient> list,
    VoidCallback onAdd,
    String hint,
  ) => Wrap(
    spacing: 7,
    runSpacing: 7,
    children: [
      ...list.map(
        (r) => InputChip(
          label: Text(
            r.label,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
          onDeleted: () => setState(() {
            _selected.remove(r.userId);
            _hamesh.remove(r.userId);
          }),
          backgroundColor: OfficeColors.seed.withValues(alpha: .08),
          side: BorderSide(color: OfficeColors.seed.withValues(alpha: .22)),
          deleteIconColor: OfficeColors.seed,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      ActionChip(
        avatar: const Icon(Icons.add, size: 15, color: OfficeColors.seed),
        label: Text(
          hint,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
        onPressed: onAdd,
        backgroundColor: Colors.white,
        side: const BorderSide(color: OfficeColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ],
  );
}

InputDecoration _inputDeco(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(fontSize: 12.5, color: Colors.blueGrey.shade300),
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(13),
    borderSide: const BorderSide(color: OfficeColors.line),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(13),
    borderSide: const BorderSide(color: OfficeColors.line),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(13),
    borderSide: const BorderSide(color: OfficeColors.seed, width: 1.6),
  ),
);

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7, top: 2),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

// ============================================================
//  فرم ثبت دبیرخانه
// ============================================================

class _DabirkhaneSheet extends StatefulWidget {
  const _DabirkhaneSheet({required this.letterId});
  final int letterId;

  @override
  State<_DabirkhaneSheet> createState() => _DabirkhaneSheetState();
}

class _DabirkhaneSheetState extends State<_DabirkhaneSheet> {
  final _reg = TextEditingController();
  final _deliverer = TextEditingController();
  final _tracking = TextEditingController();
  final _fax = TextEditingController();
  final _email = TextEditingController();
  final _note = TextEditingController();
  String _method = OfficeConst.sendMethods.first;
  bool _busy = false;

  OfficeAutomationRepository get _repo =>
      context.read<OfficeAutomationRepository>();

  @override
  void dispose() {
    for (final c in [_reg, _deliverer, _tracking, _fax, _email, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await _repo.dabirkhaneRegister(widget.letterId, {
        'sendMethod': _method,
        'destRegNumber': _reg.text.trim(),
        'delivererName': _deliverer.text.trim(),
        'trackingCode': _tracking.text.trim(),
        'destFax': _fax.text.trim(),
        'destEmail': _email.text.trim(),
        'note': _note.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: DraggableScrollableSheet(
      expand: false,
      initialChildSize: .86,
      maxChildSize: .96,
      builder: (context, scroll) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        OfficeColors.dabirkhane,
                        OfficeColors.dabirkhane.withValues(alpha: .75),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.account_balance_outlined,
                      size: 17, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'ثبت دبیرخانه',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              children: [
                const _FieldLabel('روش ارسال'),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: OfficeConst.sendMethods
                      .map(
                        (m) => GestureDetector(
                          onTap: () => setState(() => _method = m),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 13, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: _method == m
                                  ? LinearGradient(
                                      colors: [
                                        OfficeColors.dabirkhane,
                                        OfficeColors.dabirkhane
                                            .withValues(alpha: .78),
                                      ],
                                    )
                                  : null,
                              color: _method == m ? null : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _method == m
                                    ? Colors.transparent
                                    : OfficeColors.line,
                              ),
                            ),
                            child: Text(
                              m,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: _method == m
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: _method == m
                                    ? Colors.white
                                    : Colors.blueGrey.shade700,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                const _FieldLabel('شمارهٔ ثبت مقصد'),
                TextField(controller: _reg, decoration: _inputDeco('مثلاً: ۱۴۰۵/۲۸۴')),
                const SizedBox(height: 12),
                const _FieldLabel('تحویل‌گیرنده'),
                TextField(controller: _deliverer, decoration: _inputDeco('نام تحویل‌گیرنده')),
                const SizedBox(height: 12),
                const _FieldLabel('کد رهگیری'),
                TextField(controller: _tracking, decoration: _inputDeco('کد رهگیری مرسوله')),
                const SizedBox(height: 12),
                const _FieldLabel('فکس مقصد'),
                TextField(
                  controller: _fax,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDeco('۰۲۱…'),
                ),
                const SizedBox(height: 12),
                const _FieldLabel('ایمیل مقصد'),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDeco('name@company.com'),
                ),
                const SizedBox(height: 12),
                const _FieldLabel('توضیحات'),
                TextField(
                  controller: _note,
                  maxLines: 3,
                  decoration: _inputDeco('یادداشت دبیرخانه…'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text('انصراف'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: OfficeColors.dabirkhane,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check, size: 17),
                        label: Text(
                          _busy ? 'در حال ثبت…' : 'ثبت دبیرخانه',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
