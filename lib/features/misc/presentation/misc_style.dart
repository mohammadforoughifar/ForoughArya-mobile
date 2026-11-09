// ============================================================
//  زبان بصری و ابزارهای مشترک ماژول «فرم‌های متفرقه» و «صورتجلسه»
//  هم‌هویت با پالت OfficeColors / HomeColors
// ============================================================

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../models/minutes_models.dart';

class MiscColors {
  static const seed = Color(0xff2547a8);
  static const deep = Color(0xff152a63);
  static const teal = Color(0xff0f766e);
  static const tealLight = Color(0xff14b8a6);
  static const accent = Color(0xff5b47d6);

  static const ok = Color(0xff1a7f37);
  static const warn = Color(0xffd97706);
  static const danger = Color(0xffd13438);

  static const bg = Color(0xfff4f7fb);
  static const surface = Colors.white;
  static const line = Color(0xffe4eaf3);
  static const ink = Color(0xff1e293b);
  static const inkSoft = Color(0xff475569);
  static const inkFaint = Color(0xff64748b);

  static const heroGradient = LinearGradient(
    colors: [Color(0xff0f4c5c), Color(0xff0f766e), Color(0xff2547a8)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static Color forMinutesStatus(MinutesStatus s) =>
      s == MinutesStatus.closed ? ok : warn;

  static Color forItemState(MinutesItemState s) => switch (s) {
    MinutesItemState.done => ok,
    MinutesItemState.rejected => danger,
    MinutesItemState.inProgress => seed,
  };
}

String formatJalaliDate(DateTime? dt, {bool withTime = false}) {
  if (dt == null) return '—';
  return Fa.date(dt.toIso8601String(), time: withTime);
}

// ============================================================
//  نشان وضعیت صورتجلسه و بندها
// ============================================================

class MinutesStatusBadge extends StatelessWidget {
  const MinutesStatusBadge({super.key, required this.status});

  final MinutesStatus status;

  @override
  Widget build(BuildContext context) {
    final c = MiscColors.forMinutesStatus(status);
    final closed = status == MinutesStatus.closed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            closed ? Icons.verified_rounded : Icons.pending_actions_rounded,
            size: 13,
            color: c,
          ),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

class MinutesItemStateBadge extends StatelessWidget {
  const MinutesItemStateBadge({super.key, required this.state});

  final MinutesItemState state;

  @override
  Widget build(BuildContext context) {
    final c = MiscColors.forItemState(state);
    final icon = switch (state) {
      MinutesItemState.done => Icons.check_circle_rounded,
      MinutesItemState.rejected => Icons.cancel_rounded,
      MinutesItemState.inProgress => Icons.timelapse_rounded,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: c),
          const SizedBox(width: 4),
          Text(
            state.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  کارت تشخیص هوشمند خطای دسترسی / شرکت فعال (هرگز صفحهٔ خالی نمی‌ماند)
// ============================================================

class MinutesAccessDiagnosticCard extends StatelessWidget {
  const MinutesAccessDiagnosticCard({
    super.key,
    required this.error,
    required this.onRetry,
    this.onPickCompany,
  });

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback? onPickCompany;

  @override
  Widget build(BuildContext context) {
    final apiErr = error is ApiException ? error as ApiException : null;
    final code = apiErr?.statusCode;
    final msg = apiErr?.message ?? error.toString();
    final isCompanyErr =
        msg.contains('شرکت فعال') || (code == 400 && msg.contains('شرکت'));
    final isForbidden = code == 403 || msg.contains('دسترسی ندارید');

    final String title;
    final String guide;
    final IconData icon;
    final Color tone;

    if (isForbidden) {
      title = 'عدم دسترسی به ماژول صورتجلسه (۴۰۳)';
      guide =
          'نقش کاربری فعلی شما مجوز «مشاهدهٔ صورتجلسه» (MeetingMinutes.View) را ندارد.\n'
          '• از پنل وب به «تنظیمات ← نقش‌ها و دسترسی‌ها ← فرم‌های متفرقه (صورتجلسه)» بروید و تیک «مشاهده» را فعال کنید.\n'
          '• پس از ذخیرهٔ نقش، یک‌بار از حساب کاربری خارج و دوباره وارد شوید.';
      icon = Icons.lock_person_rounded;
      tone = MiscColors.danger;
    } else if (isCompanyErr) {
      title = 'شرکت فعال انتخاب یا مجاز نشده است';
      guide =
          'برای مشاهده و ثبت صورتجلسه، باید شرکت فعال مشخص باشد و کاربر شما در آن شرکت مجاز باشد.\n'
          '• از دکمهٔ «انتخاب شرکت فعال» در پایین، شرکت خود را انتخاب کنید.\n'
          '• اگر حتی با نقش مدیر این پیام را می‌بینید، در وب از مسیر «سیستم ← کاربران ← دسترسی شرکت‌ها» شرکت فعال را به این کاربر اختصاص دهید.';
      icon = Icons.apartment_rounded;
      tone = MiscColors.warn;
    } else {
      title = 'خطا در دریافت اطلاعات صورتجلسه';
      guide = msg;
      icon = Icons.cloud_off_rounded;
      tone = MiscColors.danger;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MiscColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tone.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: MiscColors.ink.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: tone, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: MiscColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            guide,
            style: const TextStyle(
              fontSize: 12,
              height: 1.85,
              color: MiscColors.inkSoft,
            ),
          ),
          if ((isForbidden || isCompanyErr) && msg.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: MiscColors.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'پیام سرور: $msg',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: MiscColors.inkFaint,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(backgroundColor: MiscColors.teal),
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('تلاش دوباره'),
              ),
              if (onPickCompany != null)
                OutlinedButton.icon(
                  onPressed: onPickCompany,
                  icon: const Icon(Icons.business_rounded, size: 17),
                  label: const Text('انتخاب شرکت فعال'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  انتخابگر تاریخ شمسی (بدون وابستگی اضافی)
// ============================================================

const List<String> _jalaliMonths = [
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
];

Future<DateTime?> showJalaliDatePicker(
  BuildContext context, {
  DateTime? initial,
  String title = 'انتخاب تاریخ شمسی',
}) {
  final initJalali = Jalali.fromDateTime(initial ?? DateTime.now());
  int year = initJalali.year;
  int month = initJalali.month;
  int day = initJalali.day;

  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(
        builder: (ctx, setS) {
          final maxDay = Jalali(year, month, 1).monthLength;
          if (day > maxDay) day = maxDay;
          final currentYear = Jalali.now().year;
          final years = List<int>.generate(
            11,
            (i) => currentYear - 5 + i,
          );
          if (!years.contains(year)) {
            years.add(year);
            years.sort();
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<int>(
                        initialValue: year,
                        decoration: const InputDecoration(
                          labelText: 'سال',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final y in years)
                            DropdownMenuItem(
                              value: y,
                              child: Text(Fa.digits(y)),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) setS(() => year = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: DropdownButtonFormField<int>(
                        initialValue: month,
                        decoration: const InputDecoration(
                          labelText: 'ماه',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (var m = 1; m <= 12; m++)
                            DropdownMenuItem(
                              value: m,
                              child: Text(_jalaliMonths[m - 1]),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) setS(() => month = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        initialValue: day,
                        decoration: const InputDecoration(
                          labelText: 'روز',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (var d = 1; d <= maxDay; d++)
                            DropdownMenuItem(
                              value: d,
                              child: Text(Fa.digits(d)),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) setS(() => day = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      final now = Jalali.now();
                      setS(() {
                        year = now.year;
                        month = now.month;
                        day = now.day;
                      });
                    },
                    icon: const Icon(Icons.today_rounded, size: 16),
                    label: const Text('امروز'),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(ctx).pop(Jalali(year, month, day).toDateTime()),
                style: FilledButton.styleFrom(backgroundColor: MiscColors.teal),
                child: const Text('تأیید'),
              ),
            ],
          );
        },
      ),
    ),
  );
}

// ============================================================
//  شیت انتخاب چندگانه و تکی کاربران با جست‌وجو
// ============================================================

Future<List<int>?> pickMultiUsersSheet(
  BuildContext context, {
  required String title,
  required List<MinutesUserOption> users,
  required List<int> initialSelected,
}) {
  final selected = Set<int>.from(initialSelected);
  var query = '';

  return showModalBottomSheet<List<int>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(
        builder: (ctx, setS) {
          final filtered = users.where((u) {
            if (query.trim().isEmpty) return true;
            return u.name.toLowerCase().contains(query.trim().toLowerCase());
          }).toList();

          return SafeArea(
            top: false,
            child: Material(
              color: MiscColors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.78,
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 12,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 14,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: MiscColors.line,
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: MiscColors.ink,
                              ),
                            ),
                          ),
                          Text(
                            '${Fa.digits(selected.length)} نفر',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: MiscColors.teal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        onChanged: (v) => setS(() => query = v),
                        decoration: InputDecoration(
                          hintText: 'جست‌وجوی نام همکار…',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: MiscColors.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: filtered.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 28),
                                child: Center(
                                  child: Text(
                                    'کاربری با این مشخصات یافت نشد.',
                                    style: TextStyle(
                                      color: MiscColors.inkFaint,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                itemBuilder: (_, i) {
                                  final u = filtered[i];
                                  final checked = selected.contains(u.id);
                                  return CheckboxListTile(
                                    dense: true,
                                    value: checked,
                                    activeColor: MiscColors.teal,
                                    title: Text(
                                      u.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onChanged: (v) => setS(() {
                                      if (v == true) {
                                        selected.add(u.id);
                                      } else {
                                        selected.remove(u.id);
                                      }
                                    }),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          TextButton(
                            onPressed: () => setS(selected.clear),
                            child: const Text('پاک‌کردن'),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('انصراف'),
                              ),
                              const SizedBox(width: 6),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(ctx).pop(selected.toList()),
                                style: FilledButton.styleFrom(
                                  backgroundColor: MiscColors.teal,
                                ),
                                child: const Text('تأیید انتخاب'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

Future<MinutesUserOption?> pickSingleUserSheet(
  BuildContext context, {
  required String title,
  required List<MinutesUserOption> users,
  int? selectedId,
  bool allowClear = true,
}) {
  var query = '';
  return showModalBottomSheet<MinutesUserOption?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(
        builder: (ctx, setS) {
          final filtered = users.where((u) {
            if (query.trim().isEmpty) return true;
            return u.name.toLowerCase().contains(query.trim().toLowerCase());
          }).toList();

          return SafeArea(
            top: false,
            child: Material(
              color: MiscColors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.72,
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 12,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 14,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: MiscColors.line,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (allowClear && selectedId != null && selectedId > 0)
                        TextButton(
                          onPressed: () => Navigator.of(
                            ctx,
                          ).pop(const MinutesUserOption(id: 0, name: '')),
                          child: const Text('حذف انتخاب'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (v) => setS(() => query = v),
                    decoration: InputDecoration(
                      hintText: 'جست‌وجوی نام…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      filled: true,
                      fillColor: MiscColors.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final u = filtered[i];
                        final sel = u.id == selectedId;
                        return ListTile(
                          dense: true,
                          selected: sel,
                          leading: CircleAvatar(
                            radius: 15,
                            backgroundColor: MiscColors.teal.withValues(
                              alpha: 0.14,
                            ),
                            child: Text(
                              u.name.characters.firstOrNull ?? '؟',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: MiscColors.teal,
                              ),
                            ),
                          ),
                          title: Text(
                            u.name,
                            style: TextStyle(
                              fontWeight: sel
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                          trailing: sel
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: MiscColors.teal,
                                  size: 19,
                                )
                              : null,
                          onTap: () => Navigator.of(ctx).pop(u),
                        );
                      },
                    ),
                  ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

// ============================================================
//  پد رسم امضای الکترونیکی با خروجی PNG Base64
// ============================================================

Future<String?> showSignaturePadSheet(
  BuildContext context, {
  required String signerName,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _SignaturePadSheet(signerName: signerName),
  );
}

class _SignaturePadSheet extends StatefulWidget {
  const _SignaturePadSheet({required this.signerName});

  final String signerName;

  @override
  State<_SignaturePadSheet> createState() => _SignaturePadSheetState();
}

class _SignaturePadSheetState extends State<_SignaturePadSheet> {
  final List<List<Offset>> _strokes = [];
  bool _exporting = false;

  bool get _hasInk => _strokes.any((s) => s.length > 1);

  Future<void> _save() async {
    if (!_hasInk || _exporting) return;
    setState(() => _exporting = true);
    try {
      const width = 480.0;
      const height = 210.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        const Rect.fromLTWH(0, 0, width, height),
      );
      final paint = Paint()
        ..color = const Color(0xff0f172a)
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      for (final stroke in _strokes) {
        if (stroke.length < 2) continue;
        final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
        for (var i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }
        canvas.drawPath(path, paint);
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final b64 = base64Encode(byteData.buffer.asUint8List());
      if (mounted) Navigator.of(context).pop(b64);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          decoration: const BoxDecoration(
            color: MiscColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.draw_rounded, color: MiscColors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ثبت امضای الکترونیکی — ${widget.signerName}',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'امضای خود را با انگشت در کادر زیر رسم کنید. این امضا در صورتجلسه و نسخهٔ چاپی درج می‌شود.',
                style: TextStyle(fontSize: 11.5, color: MiscColors.inkSoft),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 210,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xfff8fafc),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: MiscColors.line, width: 1.4),
                    ),
                    child: GestureDetector(
                      onPanStart: (d) {
                        setState(() => _strokes.add([d.localPosition]));
                      },
                      onPanUpdate: (d) {
                        if (_strokes.isEmpty) return;
                        setState(() => _strokes.last.add(d.localPosition));
                      },
                      child: CustomPaint(
                        painter: _SignaturePainter(_strokes),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _strokes.isEmpty
                        ? null
                        : () => setState(_strokes.clear),
                    icon: const Icon(Icons.cleaning_services_rounded, size: 17),
                    label: const Text('پاک‌کردن'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('انصراف'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _hasInk && !_exporting ? _save : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: MiscColors.teal,
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(_exporting ? 'در حال ثبت…' : 'ثبت امضا'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.strokes);
  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xff0f172a)
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final s in strokes) {
      if (s.length < 2) continue;
      final path = Path()..moveTo(s.first.dx, s.first.dy);
      for (var i = 1; i < s.length; i++) {
        path.lineTo(s[i].dx, s[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
