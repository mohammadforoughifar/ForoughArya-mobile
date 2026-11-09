// ============================================================
//  صفحهٔ جزئیات ایمیل — نمایش متن، پیوست‌ها و عملیات کامل
// ============================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/widgets/common.dart';
import '../data/email_draft_store.dart';
import '../data/email_repository.dart';
import '../models/email_models.dart';
import 'email_compose_page.dart';
import 'email_page.dart';
import 'email_widgets.dart';
import 'office_style.dart';

class EmailDetailPage extends StatefulWidget {
  const EmailDetailPage({
    super.key,
    required this.box,
    required this.messageId,
    required this.tab,
    this.accounts = const [],
    this.scope = EmailScope.corporate,
  });

  final String box;
  final int messageId;
  final EmailTab tab;
  final List<EmailAccount> accounts;
  final EmailScope scope;

  @override
  State<EmailDetailPage> createState() => _EmailDetailPageState();
}

class _EmailDetailPageState extends State<EmailDetailPage> {
  EmailRepository get _repo => context.read<EmailRepository>();
  EmailDraftStore get _draftStore => context.read<EmailDraftStore>();

  EmailMessageDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _changed = false;
  final _downloading = <int>{};

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
      final d = await _repo.message(widget.box, widget.messageId);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'خطا در دریافت جزئیات ایمیل: $e';
        _loading = false;
      });
    }
  }

  Future<void> _toggleNeshan() async {
    final d = _detail;
    if (d == null) return;
    try {
      final now = await _repo.toggleNeshan(d.box, d.id);
      if (!mounted) return;
      _changed = true;
      setState(() {
        _detail = EmailMessageDetail(
          id: d.id,
          box: d.box,
          accountId: d.accountId,
          accountAddress: d.accountAddress,
          fromOrTo: d.fromOrTo,
          to: d.to,
          cc: d.cc,
          subject: d.subject,
          body: d.body,
          date: d.date,
          isRead: d.isRead,
          isNeshan: now,
          isSpam: d.isSpam,
          folderId: d.folderId,
          folderTitle: d.folderTitle,
          attachments: d.attachments,
        );
      });
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _toggleSpam() async {
    final d = _detail;
    if (d == null) return;
    try {
      final now = await _repo.toggleSpam(d.box, d.id);
      if (!mounted) return;
      _changed = true;
      showMessage(context, now ? 'به هرزنامه منتقل شد.' : 'از هرزنامه خارج شد.');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _pickFolder() async {
    final d = _detail;
    if (d == null) return;
    final folderId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FolderPickerSheet(currentFolderId: d.folderId),
    );
    if (folderId == null || !mounted) return;
    try {
      await _repo.moveToFolder(box: d.box, id: d.id, folderId: folderId);
      if (!mounted) return;
      _changed = true;
      showMessage(
        context,
        folderId == 0 ? 'از بایگانی خارج شد.' : 'در پوشهٔ بایگانی ذخیره شد.',
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _downloadAttachment(EmailAttachment a, {bool share = false}) async {
    if (_downloading.contains(a.id)) return;
    setState(() => _downloading.add(a.id));
    try {
      final bytes = await _repo.downloadAttachment(a.id);
      final dir = await getTemporaryDirectory();
      final safeName = a.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${dir.path}/$safeName');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      if (share) {
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
      } else {
        await OpenFilex.open(file.path);
      }
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) showMessage(context, 'خطا در دانلود پیوست: $e', error: true);
    } finally {
      if (mounted) setState(() => _downloading.remove(a.id));
    }
  }

  Future<void> _reply({bool all = false, bool forward = false}) async {
    final d = _detail;
    if (d == null) return;
    var accounts = widget.accounts;
    if (accounts.isEmpty) {
      try {
        accounts = await _repo.accounts();
      } catch (_) {}
    }
    if (!mounted) return;
    final res = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (_) => EmailComposePage(
          scope: widget.scope,
          accounts: accounts,
          replyTo: forward ? null : d,
          replyAll: all,
          forwardOf: forward ? d : null,
        ),
      ),
    );
    if (!mounted) return;
    if (res == true) {
      _changed = true;
      showMessage(context, 'ایمیل ارسال شد.');
    } else if (res is EmailDraft) {
      final userId = context.read<AuthController>().session?.userId ?? 0;
      await _draftStore.upsert(userId, res);
      if (mounted) showMessage(context, 'پیش‌نویس ذخیره شد.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = emailTabColor(widget.tab);
    final d = _detail;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: OfficeColors.bg,
        body: _loading
            ? const LoadingView(label: 'در حال دریافت متن ایمیل...')
            : _error != null
            ? ErrorView(message: _error!, onRetry: _load)
            : d == null
            ? const EmptyView(message: 'ایمیل یافت نشد.')
            : Column(
                children: [
                  LetterHero(
                    title: d.subject,
                    accent: accent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            InkWell(
                              onTap: () => Navigator.pop(context, _changed),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .14),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: const Icon(
                                  Icons.arrow_back,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            HeroBadge(
                              label: widget.tab.label,
                              icon: emailTabIcon(widget.tab),
                              color: Colors.white,
                            ),
                            if (d.folderTitle != null && d.folderTitle!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              HeroBadge(
                                label: d.folderTitle!,
                                icon: Icons.folder_outlined,
                                color: OfficeColors.gold,
                              ),
                            ],
                            const Spacer(),
                            IconButton(
                              onPressed: _toggleNeshan,
                              icon: Icon(
                                d.isNeshan ? Icons.star : Icons.star_border_rounded,
                                color: d.isNeshan ? OfficeColors.gold : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                      children: [
                        OfficeCard(
                          title: 'مشخصات پیام',
                          icon: Icons.info_outline,
                          color: accent,
                          children: [
                            OfficeInfoTile(
                              icon: Icons.person_outline,
                              label: d.box == EmailBox.sent ? 'گیرنده' : 'فرستنده',
                              value: d.fromOrTo.isEmpty ? '—' : d.fromOrTo,
                              color: accent,
                            ),
                            if (d.to.isNotEmpty)
                              OfficeInfoTile(
                                icon: Icons.alternate_email,
                                label: 'به',
                                value: d.to,
                                color: accent,
                              ),
                            if (d.cc.isNotEmpty)
                              OfficeInfoTile(
                                icon: Icons.group_outlined,
                                label: 'رونوشت (CC)',
                                value: d.cc,
                                color: accent,
                              ),
                            if (d.accountAddress.isNotEmpty)
                              OfficeInfoTile(
                                icon: Icons.mail_outline,
                                label: 'حساب ایمیل',
                                value: d.accountAddress,
                                color: accent,
                              ),
                            if (d.date != null)
                              OfficeInfoTile(
                                icon: Icons.schedule_outlined,
                                label: 'تاریخ و ساعت',
                                value: Fa.date(d.date!.toIso8601String()),
                                color: accent,
                              ),
                          ],
                        ),
                        if (d.attachments.isNotEmpty)
                          OfficeCard(
                            title: 'پیوست‌ها (${Fa.digits(d.attachments.length)})',
                            icon: Icons.attach_file_rounded,
                            color: OfficeColors.seed,
                            children: [
                              for (final a in d.attachments)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: OfficeColors.bg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: OfficeColors.line),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.insert_drive_file_outlined,
                                        size: 20,
                                        color: OfficeColors.seed,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              a.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            if (a.sizeLabel.isNotEmpty)
                                              Text(
                                                a.sizeLabel,
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  color: Colors.blueGrey.shade500,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (_downloading.contains(a.id))
                                        const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      else ...[
                                        IconButton(
                                          tooltip: 'باز کردن',
                                          icon: const Icon(Icons.open_in_new, size: 18),
                                          onPressed: () => _downloadAttachment(a),
                                        ),
                                        IconButton(
                                          tooltip: 'اشتراک‌گذاری',
                                          icon: const Icon(Icons.share_outlined, size: 18),
                                          onPressed: () =>
                                              _downloadAttachment(a, share: true),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        OfficeCard(
                          title: 'متن ایمیل',
                          icon: Icons.subject_rounded,
                          color: accent,
                          children: [
                            SelectableText(
                              d.plainBody.isEmpty ? '(بدون متن)' : d.plainBody,
                              style: const TextStyle(
                                fontSize: 13.5,
                                height: 1.8,
                                color: OfficeColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: OfficeColors.line)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _ActionChipBtn(
                              icon: Icons.reply_rounded,
                              label: 'پاسخ',
                              color: accent,
                              onTap: () => _reply(),
                            ),
                            const SizedBox(width: 7),
                            _ActionChipBtn(
                              icon: Icons.reply_all_rounded,
                              label: 'پاسخ همه',
                              color: accent,
                              onTap: () => _reply(all: true),
                            ),
                            const SizedBox(width: 7),
                            _ActionChipBtn(
                              icon: Icons.forward_rounded,
                              label: 'ارجاع',
                              color: OfficeColors.outgoing,
                              onTap: () => _reply(forward: true),
                            ),
                            const SizedBox(width: 7),
                            _ActionChipBtn(
                              icon: Icons.folder_outlined,
                              label: 'بایگانی',
                              color: OfficeColors.archive,
                              onTap: _pickFolder,
                            ),
                            const SizedBox(width: 7),
                            _ActionChipBtn(
                              icon: Icons.report_gmailerrorred_outlined,
                              label: d.isSpam ? 'خروج از هرزنامه' : 'هرزنامه',
                              color: OfficeColors.danger,
                              onTap: _toggleSpam,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ActionChipBtn extends StatelessWidget {
  const _ActionChipBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}

class _FolderPickerSheet extends StatefulWidget {
  const _FolderPickerSheet({required this.currentFolderId});
  final int currentFolderId;

  @override
  State<_FolderPickerSheet> createState() => _FolderPickerSheetState();
}

class _FolderPickerSheetState extends State<_FolderPickerSheet> {
  EmailRepository get _repo => context.read<EmailRepository>();
  List<EmailFolder> _folders = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _repo.folders();
      if (!mounted) return;
      setState(() {
        _folders = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createFolder() async {
    final title = await promptText(
      context,
      'نام پوشهٔ جدید بایگانی',
      hint: 'مثلاً مکاتبات مالی',
      maxLines: 1,
    );
    if (title == null || title.isEmpty || !mounted) return;
    try {
      final created = await _repo.createFolder(title);
      if (!mounted) return;
      Navigator.pop(context, created.id);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'انتقال به پوشهٔ بایگانی',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: _createFolder,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  label: const Text('پوشهٔ جدید'),
                ),
              ],
            ),
            const Divider(),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (widget.currentFolderId > 0)
                ListTile(
                  leading: const Icon(Icons.unarchive_outlined, color: OfficeColors.danger),
                  title: const Text('خروج از بایگانی'),
                  onTap: () => Navigator.pop(context, 0),
                ),
              if (_folders.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('هنوز پوشه‌ای ساخته نشده است. «پوشهٔ جدید» را بزنید.'),
                ),
              for (final f in _folders)
                ListTile(
                  leading: Icon(
                    Icons.folder_outlined,
                    color: f.id == widget.currentFolderId
                        ? OfficeColors.email
                        : OfficeColors.archive,
                  ),
                  title: Text(f.title),
                  trailing: f.id == widget.currentFolderId
                      ? const Icon(Icons.check, color: OfficeColors.email)
                      : null,
                  onTap: () => Navigator.pop(context, f.id),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
