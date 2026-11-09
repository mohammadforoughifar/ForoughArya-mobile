// ============================================================
//  ویجت‌های مشترک پست الکترونیک — هم‌زبان با طراحی اتوماسیون اداری
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/utils/fa.dart';
import '../models/email_models.dart';
import 'office_style.dart';

Color emailTabColor(EmailTab tab) => switch (tab) {
  EmailTab.inbox => OfficeColors.email,
  EmailTab.sent => OfficeColors.outgoing,
  EmailTab.archive => OfficeColors.archive,
  EmailTab.draft => const Color(0xffb04fbf),
};

IconData emailTabIcon(EmailTab tab) => switch (tab) {
  EmailTab.inbox => Icons.move_to_inbox_outlined,
  EmailTab.sent => Icons.outbox_outlined,
  EmailTab.archive => Icons.account_tree_outlined,
  EmailTab.draft => Icons.drafts_outlined,
};

String emailScopeLabel(EmailAccount account) =>
    account.isDabirkhane ? 'سازمانی' : 'شخصی';

/// کارت نمایش یک ایمیل در فهرست کارتابل‌ها
class EmailCard extends StatelessWidget {
  const EmailCard({
    super.key,
    required this.message,
    required this.tab,
    this.onTap,
    this.onToggleStar,
  });

  final EmailMessage message;
  final EmailTab tab;
  final VoidCallback? onTap;
  final VoidCallback? onToggleStar;

  @override
  Widget build(BuildContext context) {
    final accent = emailTabColor(tab);
    final unread = tab == EmailTab.inbox && !message.isRead;
    final isSent = message.box == EmailBox.sent || tab == EmailTab.sent;
    final peer = message.fromOrTo.trim().isEmpty ? 'نامشخص' : message.fromOrTo.trim();
    final dateText = message.date != null
        ? Fa.date(message.date!.toIso8601String(), time: false)
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unread ? accent.withValues(alpha: .42) : OfficeColors.line,
          width: unread ? 1.3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (unread ? accent : Colors.blueGrey).withValues(alpha: unread ? .09 : .05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accent.withValues(alpha: .18),
                            accent.withValues(alpha: .07),
                          ],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isSent ? Icons.send_outlined : Icons.alternate_email,
                        size: 18,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (unread) ...[
                                _PulseDot(color: accent),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  message.subject,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                                    color: OfficeColors.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            peer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.blueGrey.shade600,
                              fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onToggleStar,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          message.isNeshan ? Icons.star : Icons.star_border_rounded,
                          size: 20,
                          color: message.isNeshan
                              ? OfficeColors.gold
                              : Colors.blueGrey.shade300,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (message.accountAddress.isNotEmpty)
                      _AccountBadge(address: message.accountAddress, color: accent),
                    if (message.hasAttachment)
                      const _MetaChip(
                        icon: Icons.attach_file_rounded,
                        label: 'پیوست',
                        color: OfficeColors.seed,
                      ),
                    if (message.folderTitle != null && message.folderTitle!.isNotEmpty)
                      _MetaChip(
                        icon: Icons.folder_outlined,
                        label: message.folderTitle!,
                        color: OfficeColors.archive,
                      ),
                    if (message.isSpam)
                      const _MetaChip(
                        icon: Icons.report_gmailerrorred_outlined,
                        label: 'هرزنامه',
                        color: OfficeColors.danger,
                      ),
                    if (dateText.isNotEmpty)
                      Text(
                        dateText,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.blueGrey.shade400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// نوار افقی انتخاب حساب ایمیل
class EmailAccountStrip extends StatelessWidget {
  const EmailAccountStrip({
    super.key,
    required this.accounts,
    required this.selectedId,
    required this.color,
    required this.onSelected,
  });

  final List<EmailAccount> accounts;
  final int? selectedId;
  final Color color;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _AccountPill(
            label: 'همهٔ حساب‌ها',
            selected: selectedId == null,
            color: color,
            onTap: () => onSelected(null),
          ),
          for (final a in accounts) ...[
            const SizedBox(width: 7),
            _AccountPill(
              label: a.address,
              subtitle: a.displayName.isNotEmpty ? a.displayName : null,
              selected: selectedId == a.id,
              color: color,
              onTap: () => onSelected(a.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountPill extends StatelessWidget {
  const _AccountPill({
    required this.label,
    this.subtitle,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? color : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? color : OfficeColors.line),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.alternate_email,
            size: 13,
            color: selected ? Colors.white : color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : OfficeColors.ink,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 4),
            Text(
              '($subtitle)',
              style: TextStyle(
                fontSize: 10.5,
                color: selected ? Colors.white70 : Colors.blueGrey.shade400,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _PulseDot extends StatelessWidget {
  const _PulseDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: .45), blurRadius: 6),
      ],
    ),
  );
}

class _AccountBadge extends StatelessWidget {
  const _AccountBadge({required this.address, required this.color});
  final String address;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      address,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}
