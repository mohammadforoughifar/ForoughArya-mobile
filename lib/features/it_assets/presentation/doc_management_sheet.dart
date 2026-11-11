// ============================================================
//  ابزارهای مدیریت مدرک — آینهٔ `Pages/DocArchive/DocManagementTools.razor`
//  • «دسترسی موقت»  GET/POST/DELETE documents/{id}/temporary-grants
//  • «پیگیری خودکار تمدید»  GET/PUT documents/{id}/renewal
//  • «صف پردازش فایل‌ها»  GET index-queue + POST …/{attachmentId}/retry
//    و ابزارهای مدیر: reindex / semantic-reindex / expiry-check
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/doc_archive_repository.dart';
import '../models/doc_archive_models.dart';
import 'system_style.dart';

class DocManagementSheet extends StatefulWidget {
  const DocManagementSheet({
    super.key,
    required this.documentId,
    this.users = const [],
  });

  final int documentId;
  final List<DocLookup> users;

  @override
  State<DocManagementSheet> createState() => _DocManagementSheetState();
}

class _DocManagementSheetState extends State<DocManagementSheet> {
  late final DocArchiveRepository _repo;

  List<DocTemporaryGrant> _grants = const [];
  DocRenewalPolicy _policy = const DocRenewalPolicy();
  DocIndexQueue _queue = const DocIndexQueue();

  bool _loading = true;
  bool _busy = false;
  String? _note;
  bool _noteError = false;

  @override
  void initState() {
    super.initState();
    _repo = DocArchiveRepository(context.read<ApiClient>());
    _load();
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '')
      .trim();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final grants = await _repo.temporaryGrants(widget.documentId);
      final policy = await _repo.renewalPolicy(widget.documentId);
      DocIndexQueue queue = const DocIndexQueue();
      try {
        queue = await _repo.indexQueue();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _grants = grants;
        _policy = policy;
        _queue = queue;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _note = _clean(e);
        _noteError = true;
      });
    }
  }

  void _toast(String t, {bool error = false}) => setState(() {
    _note = t;
    _noteError = error;
  });

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
      if (!mounted) return;
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
      height: MediaQuery.of(context).size.height * 0.84,
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
              child: Row(
                children: [
                  const Icon(
                    Icons.settings_suggest_rounded,
                    size: 17,
                    color: ShopColors.seed,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'ابزارهای مدیریت مدرک',
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
                Tab(text: 'دسترسی موقت'),
                Tab(text: 'پیگیری تمدید'),
                Tab(text: 'صف پردازش'),
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
                      children: [_grantsTab(), _renewalTab(), _queueTab()],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- دسترسی موقت ----------------

  Widget _grantsTab() => ListView(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
    children: [
      const Text(
        'فقط خواندن تا زمان تعیین‌شده؛ لغو این مجوز، دسترسی دائمی یا فایل قبلاً دریافت‌شده را حذف نمی‌کند.',
        style: TextStyle(fontSize: 9, height: 1.8, color: ShopColors.inkFaint),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
        onPressed: _busy ? null : _addGrant,
        icon: const Icon(Icons.person_add_alt_rounded, size: 15),
        label: const Text(
          'ثبت دسترسی موقت',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(height: 10),
      if (_grants.isEmpty)
        const Text(
          'دسترسی موقتی ثبت نشده است.',
          style: TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
        )
      else
        for (final g in _grants)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: ShopColors.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            g.userName,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (g.canDownload) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.download_rounded,
                              size: 12,
                              color: ShopColors.seed,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        'پایان: ${Fa.date(g.expiresAtUtc?.toIso8601String(), time: true)}',
                        style: const TextStyle(
                          fontSize: 8.5,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                ShopTag(
                  text: g.statusFa,
                  color: g.isRevoked
                      ? ShopColors.inkFaint
                      : g.isExpired
                      ? ShopColors.warn
                      : ShopColors.ok,
                ),
                if (!g.isRevoked && !g.isExpired)
                  TextButton(
                    onPressed: _busy ? null : () => _revoke(g),
                    child: const Text(
                      'لغو',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: ShopColors.danger,
                      ),
                    ),
                  ),
              ],
            ),
          ),
    ],
  );

  Future<void> _addGrant() async {
    var userId = widget.users.isEmpty ? 0 : widget.users.first.id;
    var canDownload = false;
    var until = DateTime.now().add(const Duration(days: 7));
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text(
            'دسترسی موقت',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  isDense: true,
                  initialValue: userId == 0 ? null : userId,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'کاربر',
                    labelStyle: TextStyle(fontSize: 9),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final u in widget.users)
                      DropdownMenuItem(
                        value: u.id,
                        child: Text(
                          u.name,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => userId = v ?? 0),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 38),
                  ),
                  onPressed: () async {
                    final d = await showJalaliDatePicker(
                      context,
                      initial: until,
                      title: 'تاریخ پایان',
                    );
                    if (d != null) {
                      setLocal(
                        () => until = DateTime(
                          d.year,
                          d.month,
                          d.day,
                          until.hour,
                          until.minute,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.event_rounded, size: 15),
                  label: Text(
                    'تاریخ پایان (تهران): ${jalaliShort(until)}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: canDownload,
                  onChanged: (v) => setLocal(() => canDownload = v == true),
                  title: const Text(
                    'اجازه دانلود',
                    style: TextStyle(fontSize: 10.5),
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
              child: const Text('ثبت دسترسی', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (userId <= 0) {
      _toast('کاربر را انتخاب کنید.', error: true);
      return;
    }
    _toast('دسترسی ثبت شد.');
    await _run(
      () => _repo.saveTemporaryGrant(
        documentId: widget.documentId,
        userId: userId,
        expiresAtUtc: until,
        canDownload: canDownload,
      ),
    );
  }

  Future<void> _revoke(DocTemporaryGrant g) async {
    _toast('دسترسی موقت لغو شد.');
    await _run(
      () => _repo.revokeTemporaryGrant(
        documentId: widget.documentId,
        grantId: g.id,
      ),
    );
  }

  // ---------------- پیگیری تمدید ----------------

  Widget _renewalTab() {
    final p = _policy;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
      children: [
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: p.enabled,
          onChanged: (v) => setState(() => _policy = p.copyWith(enabled: v)),
          title: const Text(
            'فعال',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
          ),
        ),
        DropdownButtonFormField<int>(
          isDense: true,
          initialValue: p.assigneeUserId == 0 ? null : p.assigneeUserId,
          decoration: const InputDecoration(
            isDense: true,
            labelText: 'مسئول تمدید',
            labelStyle: TextStyle(fontSize: 9),
            border: OutlineInputBorder(),
          ),
          items: [
            for (final u in widget.users)
              DropdownMenuItem(
                value: u.id,
                child: Text(u.name, style: const TextStyle(fontSize: 10)),
              ),
          ],
          onChanged: (v) => setState(
            () => _policy = p.copyWith(assigneeUserId: v ?? 0),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'چند روز قبل از انقضا: ${Fa.digits(p.leadDays)} روز',
          style: const TextStyle(fontSize: 9.5, color: ShopColors.inkSoft),
        ),
        Slider(
          value: p.leadDays.clamp(0, 365).toDouble(),
          min: 0,
          max: 365,
          divisions: 73,
          label: Fa.digits(p.leadDays),
          onChanged: (v) =>
              setState(() => _policy = p.copyWith(leadDays: v.round())),
        ),
        const Text(
          'برای هر تاریخ انقضا یک دستور کار ساخته می‌شود. خاموش‌کردن پیگیری، دستورهای قبلی را حذف نمی‌کند.',
          style: TextStyle(
            fontSize: 8.5,
            height: 1.8,
            color: ShopColors.inkFaint,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _saveRenewal,
            child: const Text(
              'ذخیره',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        if (p.orders.isNotEmpty) ...[
          const Divider(height: 22),
          const Text(
            'دستورهای کار تمدید',
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          for (final o in p.orders)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${o.number} — ${o.statusFa}',
                      style: const TextStyle(fontSize: 9.5),
                    ),
                  ),
                  if (o.expiryDate != null)
                    Text(
                      Fa.date(o.expiryDate!.toIso8601String(), time: false),
                      style: const TextStyle(
                        fontSize: 8.5,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _saveRenewal() async {
    final err = validateRenewalLead(_policy.leadDays);
    if (err != null) {
      _toast(err, error: true);
      return;
    }
    _toast('تنظیمات تمدید ذخیره شد.');
    await _run(() => _repo.saveRenewalPolicy(widget.documentId, _policy));
  }

  // ---------------- صف پردازش ----------------

  Widget _queueTab() => ListView(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
    children: [
      Row(
        children: [
          _stat('در انتظار', _queue.pending),
          const SizedBox(width: 6),
          _stat('در حال انجام', _queue.working),
          const SizedBox(width: 6),
          _stat('ناموفق', _queue.failed, ShopColors.danger),
          const SizedBox(width: 6),
          _stat('انجام‌شده', _queue.done, ShopColors.ok),
        ],
      ),
      const SizedBox(height: 10),
      if (_queue.failures.isEmpty)
        const Text(
          'شکستی در صف ثبت نشده است.',
          style: TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
        )
      else
        for (final f in _queue.failures)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.fileName, style: const TextStyle(fontSize: 9.5)),
                      Text(
                        f.error ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 8.5,
                          color: ShopColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          _toast('در صف قرار گرفت.');
                          _run(() => _repo.retryIndex(f.attachmentId));
                        },
                  child: const Text(
                    'تلاش دوباره',
                    style: TextStyle(fontSize: 9),
                  ),
                ),
              ],
            ),
          ),
      const Divider(height: 22),
      const Text(
        'ابزارهای مدیر آرشیو',
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () {
                    _toast('بازخوانی متن اسناد اجرا شد.');
                    _run(_repo.reindexAll);
                  },
            icon: const Icon(Icons.text_snippet_outlined, size: 14),
            label: const Text('بازخوانی متن', style: TextStyle(fontSize: 9.5)),
          ),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () {
                    _toast('ایندکس معنایی اجرا شد.');
                    _run(() => _repo.semanticReindex());
                  },
            icon: const Icon(Icons.memory_rounded, size: 14),
            label: const Text('ایندکس معنایی', style: TextStyle(fontSize: 9.5)),
          ),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () {
                    _toast('بررسی انقضا اجرا شد.');
                    _run(_repo.expiryCheck);
                  },
            icon: const Icon(Icons.notifications_active_outlined, size: 14),
            label: const Text('بررسی انقضا', style: TextStyle(fontSize: 9.5)),
          ),
        ],
      ),
    ],
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
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color ?? ShopColors.ink,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 8, color: ShopColors.inkFaint),
          ),
        ],
      ),
    ),
  );
}
