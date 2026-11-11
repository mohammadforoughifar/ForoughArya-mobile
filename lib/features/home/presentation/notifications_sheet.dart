// ============================================================
//  شیت اعلان‌ها — از صفحهٔ اصلی حذف شد و پشت زنگولهٔ هدر نشست
//  GET  /api/notifications
//  POST /api/notifications/{id}/read
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/notifications/push_service.dart';
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

  /// وضعیت مجوز اعلان در سطح سیستم — اگر خاموش باشد، «نوتیفیکیشن هست ولی
  /// چیزی نمایش داده نمی‌شود» و کاربر باید بداند چرا.
  bool _permDenied = false;

  @override
  void initState() {
    super.initState();
    _load();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    try {
      final enabled = await PushService.instance.areNotificationsEnabled();
      if (mounted && enabled == false) setState(() => _permDenied = true);
    } catch (_) {
      // پلتفرم‌های بدون پشتیبانی — نادیده
    }
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
      // نه فقط ثبت خطا: کاربر باید ببیند چرا فهرست خالی است و بتواند تلاش کند
      setState(() => _error = e.toString());
      _items ??= const [];
    }
  }

  Future<void> _markRead(NotificationItem n) async {
    if (n.isRead) return;
    final list = _items;
    if (list == null) return;
    final i = list.indexWhere((e) => e.id == n.id);
    if (i >= 0) {
      setState(() => list[i] = list[i].asRead());
    }
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

  /// باز کردن سندِ متناظر؛ بعد از برگشت، اعلان «خوانده‌شده» می‌شود.
  Future<void> _open(NotificationItem n) async {
    await _markRead(n);
    if (!mounted) return;
    widget.onOpen?.call(n);
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
            if (_permDenied) const _PermissionBanner(),
            Flexible(child: _body(items)),
          ],
        ),
      ),
    );
  }

  /// بدنهٔ شیت: بارگذاری / خطا / خالی / فهرست اعلان‌ها.
  /// (پیش‌تر فهرست هیچ‌جا رندر نمی‌شد و شیت فقط سربرگ داشت.)
  Widget _body(List<NotificationItem>? items) {
    if (items == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 34),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }
    if (items.isEmpty) {
      if (_error != null) {
        return _Center(
          icon: Icons.wifi_off_rounded,
          text: 'اعلان‌ها خوانده نشد.\nاتصال شبکه یا آدرس سرور را بررسی کنید.',
          action: TextButton.icon(
            onPressed: () {
              setState(() => _items = null);
              _load();
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('تلاش دوباره'),
          ),
        );
      }
      return const _Center(
        icon: Icons.notifications_off_outlined,
        text: 'اعلان تازه‌ای ندارید.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, i) {
          final n = items[i];
          return Dismissible(
            key: ValueKey('notif-${n.id}'),
            direction: DismissDirection.horizontal,
            background: const _DeleteBg(alignRight: true),
            secondaryBackground: const _DeleteBg(alignRight: false),
            onDismissed: (_) => _deleteOne(n),
            child: _NotificationCard(item: n, onTap: () => _open(n)),
          );
        },
      ),
    );
  }
}

/// نوار هشدار «مجوز اعلان گوشی خاموش است» — علت رایج دیده‌نشدن نوتیفیکیشن.
class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 2, 12, 8),
    padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
    decoration: BoxDecoration(
      color: HomeColors.warn.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: HomeColors.warn.withValues(alpha: 0.32)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.notifications_paused_rounded,
          size: 17,
          color: HomeColors.warn,
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'اعلان‌های این اپ در گوشی خاموش است؛ برای دیدن نوتیفیکیشن، از تنظیمات اندروید اجازهٔ اعلان را روشن کنید.',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.85,
              fontWeight: FontWeight.w600,
              color: HomeColors.ink,
            ),
          ),
        ),
        TextButton(
          onPressed: () => PushService.instance.openNotificationSettings(),
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'تنظیمات',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: HomeColors.warn,
            ),
          ),
        ),
      ],
    ),
  );
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
      if ((item.companyName ?? '').isNotEmpty) item.companyName!,
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
                        item.displayTitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.65,
                          fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                          color: HomeColors.ink,
                        ),
                      ),
                      if (item.displayBody != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.displayBody!,
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
