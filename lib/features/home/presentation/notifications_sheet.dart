// ============================================================
//  شیت اعلان‌ها — از صفحهٔ اصلی حذف شد و پشت زنگولهٔ هدر نشست
//  GET  /api/notifications
//  POST /api/notifications/{id}/read
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/utils/fa.dart';
import '../data/home_repository.dart';
import '../models/home_models.dart';
import 'home_style.dart';

class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({
    super.key,
    required this.repository,
    this.onOpen,
  });

  final HomeRepository repository;

  /// با زدن روی اعلان، همان ماژول/صفحهٔ مربوطه باز می‌شود.
  final void Function(NotificationItem item)? onOpen;

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
                    TextButton(
                      onPressed: _markAll,
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'خواندن همه (${Fa.digits(unread)})',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: HomeColors.seed,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Flexible(
              child: Builder(
                builder: (context) {
                  if (_error != null) {
                    return _Center(
                      icon: Icons.cloud_off_rounded,
                      text: _error!,
                      action: TextButton(
                        onPressed: _load,
                        child: const Text('تلاش دوباره'),
                      ),
                    );
                  }
                  if (items == null) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (items.isEmpty) {
                    return const _Center(
                      icon: Icons.notifications_none_rounded,
                      text: 'اعلانی ندارید.',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 9),
                      itemBuilder: (context, i) => HFadeSlideIn(
                        index: i,
                        delayMs: 35,
                        durationMs: 320,
                        offsetY: 14,
                        child: _NotificationCard(
                          item: items[i],
                          onTap: () async {
                            await _markRead(items[i]);
                            if (!context.mounted) return;
                            // بستن شیت، سپس رفتن به صفحهٔ مربوطه
                            Navigator.of(context).pop();
                            widget.onOpen?.call(items[i]);
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
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
