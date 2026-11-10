// ============================================================
//  صفحهٔ جزئیات کامل صورتجلسه
//  شامل: مشخصات، حاضرین و امضای الکترونیکی، بندها و تصمیمات،
//  ارسال به گردش، تبدیل به نامه داخلی/صادره/ایمیل، چاپ PDF و پیوست‌ها
// ============================================================

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/widgets/common.dart';
import '../data/minutes_repository.dart';
import '../models/minutes_models.dart';
import 'minutes_dispatch_sheet.dart';
import 'minutes_editor_page.dart';
import 'misc_style.dart';

class MinutesDetailPage extends StatefulWidget {
  const MinutesDetailPage({super.key, required this.minutesId});

  final int minutesId;

  @override
  State<MinutesDetailPage> createState() => _MinutesDetailPageState();
}

class _MinutesDetailPageState extends State<MinutesDetailPage> {
  late final MinutesRepository _repo =
      Provider.of<MinutesRepository?>(context, listen: false) ??
      MinutesRepository(context.read<ApiClient>());

  MinutesDetail? _detail;
  List<MinutesAttachment> _attachments = const [];
  List<MinutesUserOption> _users = const [];
  bool _loading = true;
  Object? _error;
  bool _changed = false;
  bool _printing = false;
  bool _uploading = false;
  final Set<int> _downloadingAtt = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  int get _myUserId => context.read<AuthController>().session?.userId ?? 0;

  bool _isCreator(MinutesDetail d) =>
      _myUserId > 0 && d.createdByUserId == _myUserId;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.fetchDetail(widget.minutesId),
        _repo
            .fetchAttachments(widget.minutesId)
            .catchError((_) => <MinutesAttachment>[]),
        _repo.fetchUserOptions().catchError((_) => <MinutesUserOption>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _detail = results[0] as MinutesDetail;
        _attachments = results[1] as List<MinutesAttachment>;
        _users = results[2] as List<MinutesUserOption>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _editMinutes() async {
    final d = _detail;
    if (d == null) return;
    final res = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => MinutesEditorPage(initial: d)),
    );
    if (res != null && mounted) {
      _changed = true;
      showMessage(context, 'تغییرات صورتجلسه ذخیره شد.');
      await _load();
    }
  }

  Future<void> _deleteMinutes() async {
    final d = _detail;
    if (d == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف صورتجلسه'),
          content: Text('آیا صورتجلسه «${d.title}» حذف شود؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: MiscColors.danger),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.deleteMinutes(d.id);
      if (!mounted) return;
      showMessage(context, 'صورتجلسه حذف شد.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _submitMinutes() async {
    final d = _detail;
    if (d == null) return;
    var includeAbsentees = true;
    final absentCount = d.absentees.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: const Text('ارسال صورتجلسه به گردش'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'با ارسال به گردش، صورتجلسه برای تمام حاضرین و مسئولان بندها قابل مشاهده شده و اعلان ارسال می‌شود.',
                  style: TextStyle(fontSize: 12.5, height: 1.7),
                ),
                if (absentCount > 0) ...[
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: includeAbsentees,
                    activeColor: MiscColors.teal,
                    title: Text(
                      'ارسال اطلاع‌رسانی به غایبین (${Fa.digits(absentCount)} نفر)',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onChanged: (v) =>
                        setS(() => includeAbsentees = v ?? true),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('انصراف'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: MiscColors.ok),
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('ارسال به گردش'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repo.submit(d.id, includeAbsentees: includeAbsentees);
      if (!mounted) return;
      _changed = true;
      showMessage(context, 'صورتجلسه با موفقیت به گردش ارسال شد.');
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _printPdf({required bool share}) async {
    final d = _detail;
    if (d == null || _printing) return;
    setState(() => _printing = true);
    try {
      final bytes = await _repo.downloadPrintPdf(d.id);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/minutes-${d.id}.pdf');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      if (share) {
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
      } else {
        final res = await OpenFilex.open(file.path);
        if (res.type != ResultType.done && mounted) {
          await SharePlus.instance.share(
            ShareParams(files: [XFile(file.path)]),
          );
        }
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _signMinutes(MinutesParticipant p) async {
    final d = _detail;
    if (d == null) return;
    final b64 = await showSignaturePadSheet(context, signerName: p.name);
    if (b64 == null || !mounted) return;
    try {
      await _repo.sign(d.id, b64);
      if (!mounted) return;
      _changed = true;
      showMessage(context, 'امضای شما با موفقیت ثبت شد.');
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _removeSignature(MinutesParticipant p) async {
    final d = _detail;
    if (d == null) return;
    try {
      await _repo.removeSignature(d.id, p.userId);
      if (!mounted) return;
      _changed = true;
      showMessage(context, 'امضای ${p.name} حذف شد.');
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  // ================== مدیریت بندها و تصمیمات ==================

  Future<void> _addOrEditItem({MinutesItem? item}) async {
    final d = _detail;
    if (d == null) return;
    final descCtrl = TextEditingController(text: item?.description ?? '');
    DateTime? dueDate = item?.dueDate;
    int? respId = item?.responsibleUserId;
    DateTime? followDate = item?.followUpDate;
    int? followId = item?.followUpUserId;

    String nameOf(int? id) {
      if (id == null || id <= 0) return 'انتخاب همکار…';
      for (final u in _users) {
        if (u.id == id) return u.name;
      }
      return item?.responsibleUserId == id
          ? (item?.responsibleName ?? 'کاربر #${Fa.digits(id)}')
          : (item?.followUpName ?? 'کاربر #${Fa.digits(id)}');
    }

    final input = await showModalBottomSheet<SaveMinutesItemInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) => SafeArea(
            top: false,
            child: Container(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 14,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              decoration: const BoxDecoration(
                color: MiscColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      item == null
                          ? 'افزودن بند جدید'
                          : 'ویرایش بند ${Fa.digits(item.rowNo)}',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'شرح بند / تصمیم *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.person_outline_rounded,
                        color: MiscColors.teal,
                      ),
                      title: const Text(
                        'مسئول اجرا',
                        style: TextStyle(fontSize: 11.5),
                      ),
                      subtitle: Text(
                        nameOf(respId),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onTap: () async {
                        final u = await pickSingleUserSheet(
                          ctx,
                          title: 'انتخاب مسئول اجرا',
                          users: _users,
                          selectedId: respId,
                        );
                        if (u != null) {
                          setS(() => respId = u.id == 0 ? null : u.id);
                        }
                      },
                    ),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.event_available_rounded,
                        color: MiscColors.teal,
                      ),
                      title: const Text(
                        'مهلت انجام',
                        style: TextStyle(fontSize: 11.5),
                      ),
                      subtitle: Text(
                        dueDate == null
                            ? 'بدون مهلت'
                            : formatJalaliDate(dueDate),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      trailing: dueDate == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, size: 17),
                              onPressed: () => setS(() => dueDate = null),
                            ),
                      onTap: () async {
                        final dt = await showJalaliDatePicker(
                          ctx,
                          initial: dueDate,
                          title: 'مهلت انجام بند',
                        );
                        if (dt != null) setS(() => dueDate = dt);
                      },
                    ),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.verified_user_outlined,
                        color: MiscColors.teal,
                      ),
                      title: const Text(
                        'مسئول پیگیری (تأیید/رد)',
                        style: TextStyle(fontSize: 11.5),
                      ),
                      subtitle: Text(
                        nameOf(followId),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onTap: () async {
                        final u = await pickSingleUserSheet(
                          ctx,
                          title: 'انتخاب مسئول پیگیری',
                          users: _users,
                          selectedId: followId,
                        );
                        if (u != null) {
                          setS(() => followId = u.id == 0 ? null : u.id);
                        }
                      },
                    ),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.schedule_rounded,
                        color: MiscColors.teal,
                      ),
                      title: const Text(
                        'تاریخ پیگیری',
                        style: TextStyle(fontSize: 11.5),
                      ),
                      subtitle: Text(
                        followDate == null
                            ? 'تعیین نشده'
                            : formatJalaliDate(followDate),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      trailing: followDate == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, size: 17),
                              onPressed: () => setS(() => followDate = null),
                            ),
                      onTap: () async {
                        final dt = await showJalaliDatePicker(
                          ctx,
                          initial: followDate,
                          title: 'تاریخ پیگیری',
                        );
                        if (dt != null) setS(() => followDate = dt);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('انصراف'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            if (descCtrl.text.trim().isEmpty) return;
                            Navigator.pop(
                              ctx,
                              SaveMinutesItemInput(
                                id: item?.id ?? 0,
                                description: descCtrl.text.trim(),
                                dueDate: dueDate,
                                responsibleUserId: respId,
                                followUpDate: followDate,
                                followUpUserId: followId,
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: MiscColors.teal,
                          ),
                          child: const Text('ذخیره'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (input == null || !mounted) return;
    try {
      if (item == null) {
        await _repo.addItem(d.id, input);
      } else {
        await _repo.updateItem(item.id, input);
      }
      if (!mounted) return;
      _changed = true;
      showMessage(context, item == null ? 'بند اضافه شد.' : 'بند ویرایش شد.');
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _deleteItem(MinutesItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('حذف بند ${Fa.digits(item.rowNo)}'),
          content: const Text('آیا از حذف این بند اطمینان دارید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: MiscColors.danger),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.deleteItem(item.id);
      if (!mounted) return;
      _changed = true;
      showMessage(context, 'بند حذف شد.');
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _openRespDecision(MinutesItem item) async {
    final noteCtrl = TextEditingController(text: item.respNote ?? '');
    var approved = !item.respApproved;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: Text('گزارش مسئول اجرا — بند ${Fa.digits(item.rowNo)}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: approved,
                  activeThumbColor: MiscColors.ok,
                  title: const Text(
                    'انجام شد (تأیید مسئول اجرا)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  onChanged: (v) => setS(() => approved = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'توضیح اقدام انجام‌شده (اختیاری)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: MiscColors.teal),
                child: const Text('ثبت'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.respDecision(
        item.id,
        approved: approved,
        note: noteCtrl.text,
      );
      if (!mounted) return;
      _changed = true;
      showMessage(context, 'وضعیت انجام بند ثبت شد.');
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _openFollowUpDecision(
    MinutesItem item,
    String initialDecision,
  ) async {
    final noteCtrl = TextEditingController(text: item.followUpNote ?? '');
    var decision = initialDecision;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: Text('نظر مسئول پیگیری — بند ${Fa.digits(item.rowNo)}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'Approved',
                      icon: Icon(Icons.check_circle_outline, size: 17),
                      label: Text('تأیید نهایی'),
                    ),
                    ButtonSegment(
                      value: 'Rejected',
                      icon: Icon(Icons.cancel_outlined, size: 17),
                      label: Text('رد و بازگشت'),
                    ),
                  ],
                  selected: {decision},
                  onSelectionChanged: (s) => setS(() => decision = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: decision == 'Rejected'
                        ? 'علت رد / توضیح پیگیری'
                        : 'شرح تأیید پیگیری (اختیاری)',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: decision == 'Rejected'
                      ? MiscColors.danger
                      : MiscColors.ok,
                ),
                child: Text(decision == 'Rejected' ? 'ثبت رد' : 'ثبت تأیید'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.followUpDecision(
        item.id,
        decision: decision,
        note: noteCtrl.text,
      );
      if (!mounted) return;
      _changed = true;
      showMessage(context, 'نظر پیگیری ثبت شد.');
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  // ================== ارسال/ارجاع (کل صورتجلسه یا یک بند) ==================

  /// اگر [item] داده شود فقط همان بند ارسال می‌شود؛ در غیر این صورت کل
  /// صورتجلسه (با پیوست PDF کامل) به ماژول مقصد می‌رود.
  Future<void> _openDispatch({MinutesItem? item}) async {
    final d = _detail;
    if (d == null) return;
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MinutesDispatchSheet(
        minutesId: d.id,
        item: item,
        minutesTitle: d.title,
        users: _users,
      ),
    );
    if (done == true && mounted) {
      showMessage(
        context,
        item == null
            ? 'صورتجلسه به ماژول مقصد ارسال شد.'
            : 'بند ${Fa.digits(item.rowNo)} ارسال شد.',
      );
    }
  }

  // ================== تبدیل به نامه داخلی / صادره / ایمیل ==================

  Future<void> _convertToInnerLetter({int itemId = 0}) async {
    final d = _detail;
    if (d == null) return;
    final defaultTitle = itemId > 0
        ? 'بند صورتجلسه «${d.title}»'
        : 'صورتجلسه «${d.title}»';
    final titleCtrl = TextEditingController(text: defaultTitle);
    final girande = <int>[];

    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setS) => SafeArea(
            top: false,
            child: Container(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 14,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              decoration: const BoxDecoration(
                color: MiscColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'تبدیل به نامهٔ داخلی',
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'عنوان نامه',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await pickMultiUsersSheet(
                        ctx,
                        title: 'انتخاب گیرندگان نامهٔ داخلی',
                        users: _users,
                        initialSelected: girande,
                      );
                      if (picked != null) {
                        setS(() {
                          girande
                            ..clear()
                            ..addAll(picked);
                        });
                      }
                    },
                    icon: const Icon(Icons.group_add_outlined, size: 18),
                    label: Text(
                      girande.isEmpty
                          ? 'انتخاب گیرندگان اصلی *'
                          : '${Fa.digits(girande.length)} گیرنده انتخاب شد',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('انصراف'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: girande.isEmpty
                            ? null
                            : () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: MiscColors.seed,
                        ),
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('ثبت نامهٔ داخلی'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (sent != true || !mounted) return;
    try {
      final lid = await _repo.toInnerLetter(
        d.id,
        itemId: itemId,
        title: titleCtrl.text,
        girande: girande,
      );
      if (!mounted) return;
      showMessage(
        context,
        'نامهٔ داخلی #${Fa.digits(lid)} با موفقیت ثبت شد.',
      );
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _convertToOutgoingLetter() async {
    final d = _detail;
    if (d == null) return;
    final orgCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final titleCtrl = TextEditingController(text: 'صورتجلسه «${d.title}»');

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          top: false,
          child: Container(
            padding: EdgeInsets.only(
              left: 18,
              right: 18,
              top: 14,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            decoration: const BoxDecoration(
              color: MiscColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'تبدیل به نامهٔ صادره',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'موضوع نامه',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: orgCtrl,
                  decoration: const InputDecoration(
                    labelText: 'نام سازمان / شرکت مقصد *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'نام گیرنده (اختیاری)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('انصراف'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        if (orgCtrl.text.trim().isEmpty) return;
                        Navigator.pop(ctx, true);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: MiscColors.ok,
                      ),
                      icon: const Icon(Icons.outbox_rounded, size: 17),
                      label: const Text('ثبت نامهٔ صادره'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final lid = await _repo.toOutgoingLetter(
        d.id,
        receiverOrganization: orgCtrl.text,
        receiverName: nameCtrl.text,
        title: titleCtrl.text,
      );
      if (!mounted) return;
      showMessage(
        context,
        'نامهٔ صادره #${Fa.digits(lid)} با موفقیت ثبت شد.',
      );
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  // ================== پیوست‌ها ==================

  Future<void> _uploadAttachment() async {
    final d = _detail;
    if (d == null || _uploading) return;
    final files = await FilePicker.pickFiles();
    if (files.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    try {
      var uploaded = 0;
      for (final f in files) {
        if (f.path == null) continue;
        final bytes = await File(f.path!).readAsBytes();
        await _repo.uploadAttachment(d.id, fileName: f.name, bytes: bytes);
        uploaded++;
      }
      if (!mounted) return;
      if (uploaded > 0) {
        _changed = true;
        showMessage(
          context,
          '${Fa.digits(uploaded)} پیوست با موفقیت بارگذاری شد.',
        );
        await _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openAttachment(MinutesAttachment a, {bool share = false}) async {
    if (_downloadingAtt.contains(a.id)) return;
    setState(() => _downloadingAtt.add(a.id));
    try {
      final bytes = await _repo.downloadAttachment(a.id);
      final dir = await getTemporaryDirectory();
      final safe = a.fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${dir.path}/$safe');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      if (share) {
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
      } else {
        await OpenFilex.open(file.path);
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _downloadingAtt.remove(a.id));
    }
  }

  Future<void> _deleteAttachment(MinutesAttachment a) async {
    try {
      await _repo.deleteAttachment(a.id);
      if (!mounted) return;
      _changed = true;
      showMessage(context, 'پیوست حذف شد.');
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.of(context).pop(_changed);
        },
        child: Scaffold(
          backgroundColor: MiscColors.bg,
          body: _loading
              ? const LoadingView(label: 'در حال دریافت جزئیات صورتجلسه…')
              : _error != null
              ? SafeArea(
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(_changed),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: MinutesAccessDiagnosticCard(
                            error: _error!,
                            onRetry: _load,
                            apiBaseUrl: _repo.api.baseUrl,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : d == null
              ? const EmptyView(message: 'صورتجلسه یافت نشد.')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildHero(d)),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                        sliver: SliverList.list(
                          children: [
                            _buildActionToolbar(d),
                            const SizedBox(height: 14),
                            _buildParticipantsSection(d),
                            const SizedBox(height: 14),
                            _buildItemsSection(d),
                            const SizedBox(height: 14),
                            _buildAttachmentsSection(d),
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

  Widget _buildHero(MinutesDetail d) {
    return Container(
      decoration: const BoxDecoration(
        gradient: MiscColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(_changed),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          'صورتجلسه #${Fa.digits(d.id)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          d.isClosed
                              ? Icons.lock_rounded
                              : Icons.pending_actions_rounded,
                          size: 13.5,
                          color: MiscColors.forMinutesStatus(d.status),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          d.status.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: MiscColors.forMinutesStatus(d.status),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                d.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17.5,
                  fontWeight: FontWeight.w900,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _HeroMeta(
                    icon: Icons.event_rounded,
                    label: 'جلسه: ${formatJalaliDate(d.meetingDate)}',
                  ),
                  _HeroMeta(
                    icon: Icons.person_outline_rounded,
                    label: 'ثبت‌کننده: ${d.createdByName}',
                  ),
                  _HeroMeta(
                    icon: Icons.schedule_rounded,
                    label: 'ثبت: ${formatJalaliDate(d.dateRegistered)}',
                  ),
                ],
              ),
              if (d.items.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'پیشرفت مصوبات: ${Fa.digits(d.doneCount)} از ${Fa.digits(d.items.length)} بند انجام شد',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${Fa.digits((d.progress * 100).round())}٪',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: d.progress,
                    minHeight: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xff4ade80),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionToolbar(MinutesDetail d) {
    final canEdit = !d.isClosed && (_isCreator(d) || _myUserId == 0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MiscColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MiscColors.line),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonalIcon(
            onPressed: _printing ? null : () => _printPdf(share: false),
            icon: _printing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_rounded, size: 17),
            label: const Text('چاپ PDF با سربرگ'),
          ),
          OutlinedButton.icon(
            onPressed: _printing ? null : () => _printPdf(share: true),
            icon: const Icon(Icons.share_rounded, size: 16),
            label: const Text('اشتراک PDF'),
          ),
          if (!d.isClosed)
            FilledButton.icon(
              onPressed: _submitMinutes,
              style: FilledButton.styleFrom(backgroundColor: MiscColors.ok),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('ارسال به گردش'),
            ),
          FilledButton.tonalIcon(
            onPressed: () => _openDispatch(),
            icon: const Icon(Icons.outbox_rounded, size: 16),
            label: const Text('ارسال کل صورتجلسه'),
          ),
          if (canEdit)
            OutlinedButton.icon(
              onPressed: _editMinutes,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('ویرایش'),
            ),
          PopupMenuButton<String>(
            tooltip: 'تبدیل و عملیات بیشتر',
            onSelected: (v) {
              switch (v) {
                case 'inner':
                  _convertToInnerLetter();
                case 'outgoing':
                  _convertToOutgoingLetter();
                case 'email':
                  _openDispatch();
                case 'delete':
                  _deleteMinutes();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'inner',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.mail_outline_rounded),
                  title: Text('تبدیل به نامهٔ داخلی'),
                ),
              ),
              const PopupMenuItem(
                value: 'outgoing',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.outbox_outlined),
                  title: Text('تبدیل به نامهٔ صادره'),
                ),
              ),
              const PopupMenuItem(
                value: 'email',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.send_rounded),
                  title: Text('ارسال کل صورتجلسه (ایمیل/نامه/دستور کار)'),
                ),
              ),
              if (canEdit)
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: MiscColors.danger,
                    ),
                    title: Text(
                      'حذف صورتجلسه',
                      style: TextStyle(color: MiscColors.danger),
                    ),
                  ),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                border: Border.all(color: MiscColors.line),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.more_horiz_rounded, size: 18),
                  SizedBox(width: 4),
                  Text(
                    'نامه / ایمیل / بیشتر',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection(MinutesDetail d) {
    final attendees = d.attendees;
    final absentees = d.absentees;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: MiscColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MiscColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.groups_2_rounded,
                size: 19,
                color: MiscColors.teal,
              ),
              const SizedBox(width: 8),
              Text(
                'حاضرین و امضاها (${Fa.digits(attendees.length)} نفر)',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (attendees.isEmpty)
            const Text(
              'حاضری ثبت نشده است.',
              style: TextStyle(fontSize: 12, color: MiscColors.inkFaint),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 9,
                crossAxisSpacing: 9,
                childAspectRatio: 1.48,
              ),
              itemCount: attendees.length,
              itemBuilder: (_, i) {
                final p = attendees[i];
                final b64 = p.cleanSignatureBase64;
                final canSignHere =
                    !d.isClosed &&
                    !p.isSigned &&
                    (_myUserId == p.userId || _myUserId == 0);
                final canRemoveSig =
                    !d.isClosed && p.isSigned && _isCreator(d);

                return Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: MiscColors.bg,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: p.isSigned
                          ? MiscColors.ok.withValues(alpha: 0.35)
                          : MiscColors.line,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (canRemoveSig)
                            GestureDetector(
                              onTap: () => _removeSignature(p),
                              child: const Icon(
                                Icons.delete_sweep_outlined,
                                size: 15,
                                color: MiscColors.danger,
                              ),
                            )
                          else
                            Icon(
                              p.isSigned
                                  ? Icons.verified_rounded
                                  : Icons.draw_outlined,
                              size: 14,
                              color: p.isSigned
                                  ? MiscColors.ok
                                  : MiscColors.inkFaint,
                            ),
                        ],
                      ),
                      Expanded(
                        child: Center(
                          child: b64 != null
                              ? _SignatureImage(base64: b64)
                              : canSignHere
                              ? TextButton.icon(
                                  onPressed: () => _signMinutes(p),
                                  style: TextButton.styleFrom(
                                    minimumSize: Size.zero,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.draw_rounded,
                                    size: 15,
                                  ),
                                  label: const Text(
                                    'امضا کن',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'بدون امضا',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: MiscColors.inkFaint,
                                  ),
                                ),
                        ),
                      ),
                      if (p.signedAt != null)
                        Text(
                          formatJalaliDate(p.signedAt),
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: MiscColors.inkFaint,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          if (absentees.isNotEmpty) ...[
            const Divider(height: 22),
            Text(
              'غایبین (${Fa.digits(absentees.length)} نفر):',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: MiscColors.inkSoft,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in absentees)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: MiscColors.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: MiscColors.danger,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsSection(MinutesDetail d) {
    final canManageItems = !d.isClosed && (_isCreator(d) || _myUserId == 0);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: MiscColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MiscColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.format_list_numbered_rtl_rounded,
                size: 19,
                color: MiscColors.teal,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'بندها و مصوبات (${Fa.digits(d.items.length)})',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (canManageItems)
                TextButton.icon(
                  onPressed: () => _addOrEditItem(),
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('افزودن بند'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (d.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'بندی برای این صورتجلسه ثبت نشده است.',
                  style: TextStyle(fontSize: 12, color: MiscColors.inkFaint),
                ),
              ),
            )
          else
            for (var idx = 0; idx < d.items.length; idx++) ...[
              if (idx > 0) const SizedBox(height: 10),
              _buildSingleItemCard(d, d.items[idx], canManageItems),
            ],
        ],
      ),
    );
  }

  Widget _buildSingleItemCard(
    MinutesDetail d,
    MinutesItem item,
    bool canManageItems,
  ) {
    final isResp =
        !d.isClosed &&
        (item.responsibleUserId == _myUserId || _myUserId == 0);
    final isFollow =
        !d.isClosed &&
        (item.followUpUserId == _myUserId || _myUserId == 0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MiscColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MiscColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MiscColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'بند ${Fa.digits(item.rowNo)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: MiscColors.teal,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              MinutesItemStateBadge(state: item.state),
              const Spacer(),
              if (canManageItems) ...[
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'ویرایش بند',
                  onPressed: () => _addOrEditItem(item: item),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'حذف بند',
                  color: MiscColors.danger,
                  onPressed: () => _deleteItem(item),
                  icon: const Icon(Icons.delete_outline_rounded, size: 17),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.description,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MiscColors.ink,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 5,
            children: [
              Text(
                'مسئول اجرا: ${item.responsibleName ?? '—'}',
                style: const TextStyle(fontSize: 11.5, color: MiscColors.inkSoft),
              ),
              Text(
                'مهلت: ${formatJalaliDate(item.dueDate)}',
                style: const TextStyle(fontSize: 11.5, color: MiscColors.inkSoft),
              ),
              Text(
                'مسئول پیگیری: ${item.followUpName ?? '—'}',
                style: const TextStyle(fontSize: 11.5, color: MiscColors.inkSoft),
              ),
              Text(
                'تاریخ پیگیری: ${formatJalaliDate(item.followUpDate)}',
                style: const TextStyle(fontSize: 11.5, color: MiscColors.inkSoft),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.respApproved
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 14,
                    color: item.respApproved
                        ? MiscColors.ok
                        : MiscColors.inkFaint,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.respApproved ? 'تأیید مسئول اجرا' : 'مسئول: بررسی‌نشده',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: item.respApproved
                          ? MiscColors.ok
                          : MiscColors.inkFaint,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.isFollowUpApproved
                        ? Icons.verified_rounded
                        : item.isFollowUpRejected
                        ? Icons.cancel_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 14,
                    color: item.isFollowUpApproved
                        ? MiscColors.ok
                        : item.isFollowUpRejected
                        ? MiscColors.danger
                        : MiscColors.inkFaint,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'پیگیری: ${item.followUpStatusLabel}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: item.isFollowUpApproved
                          ? MiscColors.ok
                          : item.isFollowUpRejected
                          ? MiscColors.danger
                          : MiscColors.inkFaint,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if ((item.respNote ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'یادداشت مسئول: ${item.respNote}',
              style: const TextStyle(fontSize: 11.5, color: MiscColors.ok),
            ),
          ],
          if ((item.followUpNote ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'یادداشت پیگیری: ${item.followUpNote}',
              style: TextStyle(
                fontSize: 11.5,
                color: item.isFollowUpRejected
                    ? MiscColors.danger
                    : MiscColors.ok,
              ),
            ),
          ],
          if (!d.isClosed) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (isResp)
                  OutlinedButton.icon(
                    onPressed: () => _openRespDecision(item),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.task_alt_rounded, size: 15),
                    label: Text(
                      item.respApproved ? 'تغییر گزارش اجرا' : 'اعلام انجام',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                if (isFollow) ...[
                  OutlinedButton.icon(
                    onPressed: () => _openFollowUpDecision(item, 'Approved'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: MiscColors.ok,
                    ),
                    icon: const Icon(Icons.done_all_rounded, size: 15),
                    label: const Text(
                      'تأیید پیگیری',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openFollowUpDecision(item, 'Rejected'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: MiscColors.danger,
                    ),
                    icon: const Icon(Icons.close_rounded, size: 15),
                    label: const Text(
                      'رد بند',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
                TextButton.icon(
                  onPressed: () => _openDispatch(item: item),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: MiscColors.teal,
                  ),
                  icon: const Icon(Icons.outbox_rounded, size: 15),
                  label: const Text(
                    'ارسال بند',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection(MinutesDetail d) {
    final canUpload = !d.isClosed;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: MiscColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MiscColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.attach_file_rounded,
                size: 19,
                color: MiscColors.teal,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'پیوست‌ها (${Fa.digits(_attachments.length)})',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (canUpload)
                TextButton.icon(
                  onPressed: _uploading ? null : _uploadAttachment,
                  icon: _uploading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_rounded, size: 17),
                  label: const Text('افزودن فایل'),
                ),
            ],
          ),
          if (_attachments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'فایل پیوستی برای این صورتجلسه ثبت نشده است.',
                style: TextStyle(fontSize: 12, color: MiscColors.inkFaint),
              ),
            )
          else
            for (final a in _attachments)
              Material(
                type: MaterialType.transparency,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.insert_drive_file_outlined,
                    color: MiscColors.seed,
                  ),
                  title: Text(
                    a.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${a.uploaderName.isEmpty ? '' : '${a.uploaderName} • '}${Fa.bytes(a.size)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: MiscColors.inkFaint,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (a.canDownload)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: _downloadingAtt.contains(a.id)
                              ? null
                              : () => _openAttachment(a),
                          icon: _downloadingAtt.contains(a.id)
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.download_rounded,
                                  size: 18,
                                  color: MiscColors.ok,
                                ),
                        ),
                      if (a.canDownload)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _openAttachment(a, share: true),
                          icon: const Icon(Icons.share_outlined, size: 17),
                        ),
                      if (canUpload && a.canDelete)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          color: MiscColors.danger,
                          onPressed: () => _deleteAttachment(a),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 17,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.85)),
      const SizedBox(width: 4),
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _SignatureImage extends StatelessWidget {
  const _SignatureImage({required this.base64});

  final String base64;

  @override
  Widget build(BuildContext context) {
    try {
      final bytes = base64Decode(base64);
      return Image.memory(bytes, height: 42, fit: BoxFit.contain);
    } catch (_) {
      return const Text(
        'امضا ثبت‌شده',
        style: TextStyle(fontSize: 11, color: MiscColors.ok),
      );
    }
  }
}
