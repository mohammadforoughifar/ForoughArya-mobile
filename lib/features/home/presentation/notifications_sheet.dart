// ============================================================
//  شیت اعلان‌ها — از صفحهٔ اصلی حذف شد و پشت زنگولهٔ هدر نشست
//  GET  /api/notifications
//  POST /api/notifications/{id}/read
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/fa.dart';
import '../data/home_repository.dart';
import '../models/home_models.dart';
import 'home_style.dart';

class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({
    super.key,
    required this.repository,
    this.onOpen,
    this.onCleared,
  });

  final HomeRepository repository;

  /// با زدن روی اعلان، همان ماژول/صفحهٔ مربوطه باز می‌شود.
  final void Function(NotificationItem item)? onOpen;

  /// بعد از پاک شدن همهٔ اعلان‌ها صدا زده می‌شود (مثلاً پاک‌کردن نوار گوشی).
  final Future<void> Function()? onCleared;

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  List<NotificationItem>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.repository.fetchNotifications(take: 60);
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _markRead(NotificationItem n) async {
    if (n.isRead) return;
    setState(() {
      final i = _items!.indexOf(n);
      _items![i] = NotificationItem(
        id: n.id,
        title: n.title,
        body: n.body,
        fromName: n.fromName,
        formName: n.formName,
        link: n.link,
        isRead: true,
        createdAt: n.createdAt,
      );
    });
    try {
      await widget.repository.markRead(n.id);
    } on Exception {
      // خطای شبکه مهم نیست؛ وضعیت محلی همان چیزی است که کاربر می‌بیند.
    }
  }

  Future<void> _markAll() async {
    final unread = (_items ?? []).where((n) => !n.isRead).toList();
    for (final n in unread) {
      await _markRead(n);
    }
  }

  /// پاک کردن یک اعلان (حذف از فهرست، نه فقط خوانده‌شدن)
  Future<void> _deleteOne(NotificationItem n) async {
    setState(() => _items = [...?_items]..removeWhere((e) => e.id == n.id));
    try {
      await widget.repository.deleteNotification(n.id);
    } on Exception {
      // اگر سرور نپذیرفت، اعلان را برمی‌گردانیم تا کاربر گمراه نشود
      if (!mounted) return;
      setState(() => _items = [...?_items, n]..sort((a, b) => b.id.compareTo(a.id)));
      _toast('این اعلان از سرور پاک نشد؛ دوباره تلاش کنید.');
    }
  }

  /// پاک کردن همهٔ اعلان‌ها با تأیید کاربر
  Future<void> _clearAll() async {
    final count = _items?.length ?? 0;
    if (count == 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('پاک کردن همهٔ اعلان‌ها'),
        content: Text(
          'همهٔ ${Fa.digits(count)} اعلان از فهرست و از سرور پاک شود؟ '
          'این کار قابل بازگشت نیست.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: HomeColors.danger),
            child: const Text('پاک کن'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final backup = _items ?? const <NotificationItem>[];
    setState(() => _items = const []);
    try {
      await widget.repository.clearNotifications();
      // حذف نوتیفیکیشن‌های نشان‌داده‌شده در نوار گوشی هم (یک‌جا)
      await widget.onCleared?.call();
      _toast('همهٔ اعلان‌ها پاک شد.');
    } on Exception {
      if (!mounted) return;
      setState(() => _items = backup);
      _toast('پاک کردن همهٔ اعلان‌ها از سرور انجام نشد؛ دوباره تلاش کنید.');
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final unread = items?.where((n) => !n.isRead).length ?? 0;
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        decoration: const BoxDecoration(
          color: HomeColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: HomeColors.line,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'اعلان‌ها',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: HomeColors.ink,
                      ),
                    ),
                  ),
                  if (unread > 0)
                    TextButton.icon(
                      onPressed: _markAll,
                      icon: const Icon(Icons.done_all_rounded, size: 15),
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      label: Text(
                        'خواندن همه (${Fa.digits(unread)})',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: HomeColors.seed,
                        ),
                      ),
                    ),
                  if ((items?.isNotEmpty ?? false))
                    TextButton.icon(
                      onPressed: _clearAll,
                      icon: const Icon(
                        Icons.delete_sweep_rounded,
                        size: 16,
                        color: HomeColors.danger,
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      label: const Text(
                        'پاک کردن همه',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: HomeColors.danger,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// پس‌زمینهٔ کشیدن اعلان به کنار = پاک کردن
class _DeleteBg extends StatelessWidget {
  const _DeleteBg({required this.alignRight});
  final bool alignRight;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 1),
    padding: EdgeInsets.only(right: alignRight ? 16 : 0, left: alignRight ? 0 : 16),
    alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
    decoration: BoxDecoration(
      color: HomeColors.danger.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Icon(Icons.delete_outline_rounded, color: HomeColors.danger),
  );
}

class _Center extends StatelessWidget {
  const _Center({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 28),
    child: Column(
      children: [
        Icon(icon, size: 34, color: HomeColors.inkFaint),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.9,
            color: HomeColors.inkSoft,
          ),
        ),
        ?action,
      ],
    ),
  );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;
    final tone = _toneFor(item);
    final meta = [
      if ((item.fromName ?? '').isNotEmpty) item.fromName!,
      if ((item.formName ?? '').isNotEmpty) item.formName!,
      if (item.createdAt != null) Fa.date(item.createdAt!.toIso8601String()),
    ].join('  ·  ');

    return HPressable(
      onTap: onTap,
      scale: 0.985,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
            decoration: BoxDecoration(
              color: unread ? HomeColors.bg : HomeColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: unread
                    ? HomeColors.seed.withValues(alpha: 0.28)
                    : HomeColors.line,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: tone.withValues(alpha: 0.13),
                  ),
                  child: Icon(_iconFor(item), size: 18, color: tone),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.65,
                          fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                          color: HomeColors.ink,
                        ),
                      ),
                      if ((item.body ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.body!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.85,
                            color: HomeColors.inkSoft,
                          ),
                        ),
                      ],
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          meta,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: HomeColors.inkFaint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (unread)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6, right: 2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: HomeColors.seed,
                    ),
                  ),
              ],
            ),
          ),
          if (unread)
            Positioned(
              right: 0,
              top: 14,
              bottom: 14,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: HomeColors.seed,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Color _toneFor(NotificationItem n) {
    final t = '${n.title} ${n.formName ?? ''}';
    if (t.contains('هشدار') || t.contains('خطا') || t.contains('معوق')) {
      return HomeColors.danger;
    }
    if (t.contains('تأیید') || t.contains('تسویه') || t.contains('موفق')) {
      return HomeColors.ok;
    }
    if (t.contains('نامه') || t.contains('ارجاع')) return HomeColors.seed;
    if (t.contains('دستور کار')) return HomeColors.warn;
    return HomeColors.inkSoft;
  }

  static IconData _iconFor(NotificationItem n) {
    final t = '${n.title} ${n.formName ?? ''}';
    if (t.contains('نامه') || t.contains('ارجاع')) {
      return Icons.mail_outline_rounded;
    }
    if (t.contains('دستور کار')) return Icons.build_rounded;
    if (t.contains('مرخصی') || t.contains('پرسنل') || t.contains('تردد')) {
      return Icons.groups_rounded;
    }
    if (t.contains('سرور') || t.contains('هشدار')) return Icons.dns_rounded;
    if (t.contains('فاکتور') || t.contains('خزانه') || t.contains('چک')) {
      return Icons.account_balance_wallet_rounded;
    }
    if (t.contains('موجودی') || t.contains('انبار')) {
      return Icons.inventory_2_outlined;
    }
    return Icons.notifications_none_rounded;
  }
}
