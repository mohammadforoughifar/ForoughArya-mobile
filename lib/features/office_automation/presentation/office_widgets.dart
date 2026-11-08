// ============================================================
//  ویجت‌های مشترک ماژول اتوماسیون اداری
//  سبک هم‌خوان با بقیهٔ اپ (Material 3، RTL، فونت Vazirmatn)
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/utils/fa.dart';
import '../data/office_repository.dart' show LetterKind;
import '../models/letter_models.dart';
import '../models/office_common.dart';

/// برچسب کوچک رنگی (محرمانگی، فوریت، وضعیت، ...)
class OfficeChip extends StatelessWidget {
  const OfficeChip({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.dense = false,
    this.onTap,
  });

  final String label;
  final Color? color;
  final IconData? icon;
  final bool dense;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    final child = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: c,
              fontSize: dense ? 10.5 : 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: child,
    );
  }
}

/// رنگ محرمانگی
Color mahramanegiColor(String value) => switch (value) {
  'سری' => const Color(0xffb3261e),
  'محرمانه' => const Color(0xffe07b00),
  _ => const Color(0xff55637a),
};

/// رنگ فوریت
Color foriatColor(String value) => switch (value) {
  'آنی' => const Color(0xffb3261e),
  'فوری' => const Color(0xffe07b00),
  _ => const Color(0xff55637a),
};

/// رنگ وضعیت نامه صادره
Color outgoingStatusColor(int status) => switch (status) {
  3 => const Color(0xff1a7f37),
  2 => const Color(0xff2a6bd4),
  1 => const Color(0xffe07b00),
  _ => const Color(0xff55637a),
};

/// بج‌های وضعیت یک سطر نامه
class LetterBadges extends StatelessWidget {
  const LetterBadges({
    super.key,
    required this.item,
    this.kind,
    this.compact = false,
  });

  final LetterListItem item;
  final LetterKind? kind;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[];

    if (kind == LetterKind.outgoing) {
      badges.add(OfficeChip(
        label: OfficeConst.outgoingStatus[
            item.outgoingStatus.clamp(0, OfficeConst.outgoingStatus.length - 1)],
        color: outgoingStatusColor(item.outgoingStatus),
        dense: compact,
      ));
    }
    if (item.isUrgent) {
      badges.add(OfficeChip(
        label: item.foriat,
        color: foriatColor(item.foriat),
        icon: Icons.bolt,
        dense: compact,
      ));
    }
    if (item.isConfidential) {
      badges.add(OfficeChip(
        label: item.mahramanegi,
        color: mahramanegiColor(item.mahramanegi),
        icon: Icons.lock_outline,
        dense: compact,
      ));
    }
    if (item.erjaType != null && item.erjaType!.isNotEmpty && item.erjaType != 'گیرنده') {
      badges.add(OfficeChip(
        label: item.erjaType!,
        color: item.erjaType == 'هامش' ? const Color(0xff6b4fd8) : const Color(0xff1a7f37),
        dense: compact,
      ));
    }
    if (item.hasAttachment) {
      badges.add(OfficeChip(
        label: 'پیوست',
        color: const Color(0xff2a6bd4),
        icon: Icons.attach_file,
        dense: compact,
      ));
    }
    if (item.typeTaeed != 0) {
      badges.add(OfficeChip(
        label: item.typeTaeed == 1 ? 'تأیید شد' : 'رد شد',
        color: item.typeTaeed == 1 ? const Color(0xff1a7f37) : const Color(0xffb3261e),
        icon: item.typeTaeed == 1 ? Icons.check_circle_outline : Icons.cancel_outlined,
        dense: compact,
      ));
    }
    if (item.hasAnswer) {
      badges.add(OfficeChip(
        label: 'پاسخ دارد',
        color: const Color(0xff1a7f37),
        icon: Icons.reply_outlined,
        dense: compact,
      ));
    }
    if (item.sadereNumber != null && item.sadereNumber!.isNotEmpty) {
      badges.add(OfficeChip(
        label: 'صادره ${Fa.digits(item.sadereNumber)}',
        color: const Color(0xff1a7f37),
        dense: compact,
      ));
    }
    if (item.deadline != null) {
      final overdue = item.deadline!.isBefore(DateTime.now());
      badges.add(OfficeChip(
        label: 'مهلت ${Fa.date(item.deadline!.toIso8601String(), time: false)}',
        color: overdue ? const Color(0xffb3261e) : const Color(0xffe07b00),
        icon: Icons.schedule,
        dense: compact,
      ));
    }

    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 6, children: badges);
  }
}

/// کارت یک سطر نامه در کارتابل
class LetterTile extends StatelessWidget {
  const LetterTile({
    super.key,
    required this.item,
    this.kind,
    this.onTap,
    this.onNeshan,
    this.showSender = true,
  });

  final LetterListItem item;
  final LetterKind? kind;
  final VoidCallback? onTap;
  final VoidCallback? onNeshan;
  final bool showSender;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !item.isRead;
    final subtitle = kind == LetterKind.outgoing
        ? (item.receiverOrganization ?? item.receiver)
        : (item.senderOrganization ?? item.sender);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: unread
              ? theme.colorScheme.primary.withValues(alpha: .35)
              : const Color(0xffe4eaf3),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (unread
                              ? theme.colorScheme.primary
                              : Colors.blueGrey.shade200)
                          .withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      _kindIcon(kind),
                      size: 20,
                      color: unread
                          ? theme.colorScheme.primary
                          : Colors.blueGrey.shade400,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: unread
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (item.isNeshan)
                              const Icon(
                                Icons.star,
                                size: 17,
                                color: Color(0xffe0a800),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (item.letterNumber.isNotEmpty)
                              'شماره ${Fa.digits(item.letterNumber)}',
                            if (showSender && subtitle.isNotEmpty)
                              subtitle,
                          ].join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.blueGrey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Fa.date(item.date?.toIso8601String(), time: false),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.blueGrey.shade400,
                        ),
                      ),
                      if (onNeshan != null)
                        IconButton(
                          onPressed: onNeshan,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            item.isNeshan ? Icons.star : Icons.star_border,
                            size: 19,
                            color: item.isNeshan
                                ? const Color(0xffe0a800)
                                : Colors.blueGrey.shade300,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (item.matnErja != null && item.matnErja!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xfff4f7fb),
                    borderRadius: BorderRadius.circular(9),
                    border: const Border(
                      right: BorderSide(color: Color(0xff2a6bd4), width: 3),
                    ),
                  ),
                  child: Text(
                    'دستور ارجاع: ${item.matnErja}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: Colors.blueGrey.shade700),
                  ),
                ),
              ],
              const SizedBox(height: 9),
              LetterBadges(item: item, kind: kind, compact: true),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _kindIcon(LetterKind? kind) => switch (kind) {
    LetterKind.inner => Icons.edit_note,
    LetterKind.outgoing => Icons.north_east,
    LetterKind.incoming => Icons.south_west,
    null => Icons.mail_outline,
  };
}

/// سطر برچسب/مقدار در صفحهٔ جزئیات
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: Colors.blueGrey.shade400),
          const SizedBox(width: 6),
        ],
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

/// عنوان بخش داخل صفحه
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.icon, this.trailing});

  final String title;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 14),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// نوار آمار کوچک
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.onTap,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xffe4eaf3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: c.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: c),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Fa.digits(value),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: c,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 10.5, color: Colors.blueGrey.shade500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// انتخاب‌گر چندگزینه‌ای گیرندگان (کاربر یا گروه)
Future<List<LetterRecipient>?> pickRecipients(
  BuildContext context, {
  required String title,
  required Future<List<LetterRecipient>> Function() loadUsers,
  Future<List<LetterGroup>> Function()? loadGroups,
  List<LetterRecipient> initial = const [],
}) => showModalBottomSheet<List<LetterRecipient>>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (_) => _RecipientSheet(
    title: title,
    loadUsers: loadUsers,
    loadGroups: loadGroups,
    initial: initial,
  ),
);

class _RecipientSheet extends StatefulWidget {
  const _RecipientSheet({
    required this.title,
    required this.loadUsers,
    this.loadGroups,
    this.initial = const [],
  });
  final String title;
  final Future<List<LetterRecipient>> Function() loadUsers;
  final Future<List<LetterGroup>> Function()? loadGroups;
  final List<LetterRecipient> initial;

  @override
  State<_RecipientSheet> createState() => _RecipientSheetState();
}

class _RecipientSheetState extends State<_RecipientSheet> {
  final _selected = <int, LetterRecipient>{};
  List<LetterRecipient> _users = [];
  List<LetterGroup> _groups = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    for (final r in widget.initial) {
      _selected[r.userId] = r;
    }
    _load();
  }

  Future<void> _load() async {
    try {
      _users = await widget.loadUsers();
      if (widget.loadGroups != null) _groups = await widget.loadGroups!();
    } catch (_) {
      _users = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? _users
        : _users
              .where((u) =>
                  u.label.contains(_query) ||
                  u.positions.any((p) => p.contains(_query)))
              .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .82,
      maxChildSize: .95,
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${Fa.digits(_selected.length)} انتخاب',
                  style: TextStyle(fontSize: 11.5, color: Colors.blueGrey.shade500),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'جست‌وجوی نام یا سمت…',
                prefixIcon: Icon(Icons.search, size: 19),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  if (_groups.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Text('گروه‌ها',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.blueGrey.shade600,
                          )),
                    ),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: _groups
                          .map((g) => OfficeChip(
                                label: '${g.name} (${Fa.digits(g.memberCount)})',
                                icon: Icons.groups_outlined,
                                onTap: () {
                                  for (final m in g.members) {
                                    _selected[m.userId] = m;
                                  }
                                  setState(() {});
                                },
                              ))
                          .toList(),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Text('کاربران',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.blueGrey.shade600,
                        )),
                  ),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('کاربری یافت نشد.')),
                    ),
                  ...filtered.map((u) {
                    final on = _selected.containsKey(u.userId);
                    return CheckboxListTile(
                      value: on,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(u.label, style: const TextStyle(fontSize: 13.5)),
                      subtitle: u.positions.isEmpty
                          ? null
                          : Text(
                              u.positions.join('، '),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blueGrey.shade500,
                              ),
                            ),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected[u.userId] = u;
                        } else {
                          _selected.remove(u.userId);
                        }
                      }),
                    );
                  }),
                ],
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, <LetterRecipient>[]),
                      child: const Text('پاک کردن'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, _selected.values.toList()),
                      child: const Text('تأیید انتخاب'),
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
