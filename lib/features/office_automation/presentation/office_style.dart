// ============================================================
//  زبان طراحی ماژول اتوماسیون اداری
//  همان زبان بصری «دستور کار»: گرادیان، کارت درخشان، تب کشویی،
//  شیشه‌ای، هالهٔ نبضی و ریزانیمیشن‌های ورود
//  رنگ‌مایه: نیلی اداری + تفکیک رنگی نوع نامه (داخلی/صادره/وارده)
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/fa.dart';
import '../data/office_repository.dart' show LetterKind;
import '../models/letter_models.dart';

// ------------------------------------------------------------
//  پالت رنگ
// ------------------------------------------------------------

class OfficeColors {
  // هویت واحد با ماژول دستور کار
  static const seed = Color(0xff2547a8);
  static const deep = Color(0xff152a63);
  static const accent = Color(0xff5b47d6);

  // رنگ اختصاصی هر نوع نامه
  static const inner = Color(0xff2547a8); // داخلی — نیلی
  static const outgoing = Color(0xff1a7f37); // صادره — سبز
  static const incoming = Color(0xff0d7d8c); // وارده — فیروزه‌ای
  static const signing = Color(0xffe07b00); // در انتظار امضا — نارنجی
  static const dabirkhane = Color(0xff5b47d6); // دبیرخانه — بنفش
  static const archive = Color(0xff6b7a90); // بایگانی — خاکستری

  static const danger = Color(0xffd13438);
  static const gold = Color(0xffe0a800);
  static const ok = Color(0xff1a7f37);

  static const bg = Color(0xfff4f7fb);
  static const line = Color(0xffe4eaf3);

  /// رنگ پایه هر نوع نامه
  static Color forKind(LetterKind? kind) => switch (kind) {
    LetterKind.inner => inner,
    LetterKind.outgoing => outgoing,
    LetterKind.incoming => incoming,
    null => inner,
  };

  /// رنگ وضعیت یک سطر کارتابل (اولویت‌بندی معنادار)
  static Color forItem(LetterListItem it, {LetterKind? kind}) {
    if (it.deadline != null && it.deadline!.isBefore(DateTime.now())) {
      return danger; // از مهلت گذشته
    }
    if (!it.isRead) return seed; // خوانده‌نشده = نیاز به اقدام
    if (it.foriat == 'آنی' || it.foriat == 'فوری') return signing;
    if (it.isNeshan) return gold;
    return forKind(kind);
  }

  /// گرادیان وضعیت — همان منطق «نوار رنگی کناری» دستور کار
  static LinearGradient gradientFor(LetterListItem it, {LetterKind? kind}) {
    if (it.deadline != null && it.deadline!.isBefore(DateTime.now())) {
      return const LinearGradient(colors: [Color(0xffe05357), Color(0xffa4262c)]);
    }
    if (it.foriat == 'آنی') {
      return const LinearGradient(colors: [Color(0xffe05357), Color(0xffa4262c)]);
    }
    if (it.foriat == 'فوری') {
      return const LinearGradient(colors: [Color(0xfff3a33c), Color(0xffd2691e)]);
    }
    return switch (kind) {
      LetterKind.outgoing => const LinearGradient(
        colors: [Color(0xff3fb27f), Color(0xff1a7f37)],
      ),
      LetterKind.incoming => const LinearGradient(
        colors: [Color(0xff2fa8b8), Color(0xff0d7d8c)],
      ),
      _ => const LinearGradient(
        colors: [Color(0xff4f7ce8), Color(0xff2547a8)],
      ),
    };
  }

  static LinearGradient get heroGradient => const LinearGradient(
    colors: [deep, seed, accent],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static Color forConfidential(String v) => switch (v) {
    'سری' => danger,
    'محرمانه' => signing,
    _ => const Color(0xff55637a),
  };

  static Color forOutgoingStatus(int s) => switch (s) {
    3 => ok,
    2 => const Color(0xff2a6bd4),
    1 => signing,
    _ => const Color(0xff55637a),
  };
}

// ------------------------------------------------------------
//  انیمیشن ورود آیتم لیست (fade + slide + scale)
// ------------------------------------------------------------

class OFadeSlideIn extends StatefulWidget {
  const OFadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.delayMs = 45,
    this.durationMs = 380,
    this.offsetY = 26,
  });

  final Widget child;
  final int index;
  final int delayMs;
  final int durationMs;
  final double offsetY;

  @override
  State<OFadeSlideIn> createState() => _OFadeSlideInState();
}

class _OFadeSlideInState extends State<OFadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.durationMs),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    // آیتم‌های دورتر با تأخیر کمتر می‌آیند تا لیست طولانی کند نشود
    final delay = math.min(widget.index * widget.delayMs, 480);
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curve,
    builder: (_, child) => Opacity(
      opacity: _curve.value.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, widget.offsetY * (1 - _curve.value)),
        child: Transform.scale(
          scale: 0.97 + 0.03 * _curve.value,
          child: child,
        ),
      ),
    ),
    child: widget.child,
  );
}

// ------------------------------------------------------------
//  کارت نامه — نسخهٔ گرادیانی با هالهٔ نبضی و نوار مهلت
// ------------------------------------------------------------

class GlowLetterCard extends StatefulWidget {
  const GlowLetterCard({
    super.key,
    required this.item,
    this.kind,
    this.onTap,
    this.onNeshan,
    this.showSender = true,
    this.index = 0,
    this.bulkMode = false,
    this.selected = false,
    this.onSelect,
  });

  final LetterListItem item;
  final LetterKind? kind;
  final VoidCallback? onTap;
  final VoidCallback? onNeshan;
  final bool showSender;
  final int index;
  final bool bulkMode;
  final bool selected;
  final ValueChanged<bool>? onSelect;

  @override
  State<GlowLetterCard> createState() => _GlowLetterCardState();
}

class _GlowLetterCardState extends State<GlowLetterCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  bool get _overdue =>
      widget.item.deadline != null &&
      widget.item.deadline!.isBefore(DateTime.now());

  @override
  void initState() {
    super.initState();
    if (_overdue || widget.item.foriat == 'آنی') _glow.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant GlowLetterCard old) {
    super.didUpdateWidget(old);
    final hot = _overdue || widget.item.foriat == 'آنی';
    if (hot && !_glow.isAnimating) {
      _glow.repeat(reverse: true);
    } else if (!hot && _glow.isAnimating) {
      _glow.stop();
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final tint = OfficeColors.forItem(it, kind: widget.kind);
    final grad = OfficeColors.gradientFor(it, kind: widget.kind);
    final unread = !it.isRead;
    final sender = widget.kind == LetterKind.outgoing
        ? (it.receiverOrganization ?? it.receiver)
        : (it.senderOrganization ?? it.sender);

    return OFadeSlideIn(
      index: widget.index,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.bulkMode
            ? () => widget.onSelect?.call(!widget.selected)
            : widget.onTap,
        onLongPress: widget.onSelect == null
            ? null
            : () => widget.onSelect!(!widget.selected),
        child: AnimatedScale(
          scale: _pressed ? .975 : 1,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: Container(
            margin: const EdgeInsets.only(bottom: 11),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: widget.selected ? OfficeColors.seed : OfficeColors.line,
                width: widget.selected ? 1.8 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: (widget.selected ? OfficeColors.seed : Colors.blueGrey)
                      .withValues(alpha: widget.selected ? .20 : .07),
                  blurRadius: widget.selected ? 18 : 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                // نوار رنگی کناری
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 5, decoration: BoxDecoration(gradient: grad)),
                ),
                // هالهٔ نبضی برای نامه‌های داغ
                if (_overdue || it.foriat == 'آنی')
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _glow,
                        builder: (context, child) => DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                OfficeColors.danger.withValues(
                                  alpha: .07 * (.45 + .55 * _glow.value),
                                ),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.bulkMode) ...[
                            _SelectDot(on: widget.selected, color: tint),
                            const SizedBox(width: 9),
                          ],
                          _KindAvatar(
                            kind: widget.kind,
                            color: tint,
                            unread: unread,
                            badge: it.senderOrganization == null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (it.letterNumber.isNotEmpty)
                                      _NumberBadge(
                                        number: it.letterNumber,
                                        color: tint,
                                      ),
                                    if (unread) ...[
                                      const SizedBox(width: 6),
                                      _PulseDot(color: tint),
                                    ],
                                    const Spacer(),
                                    if (it.isNeshan)
                                      const Icon(Icons.star, size: 17, color: OfficeColors.gold),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  it.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    height: 1.45,
                                    fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                                    color: unread
                                        ? const Color(0xff16233a)
                                        : const Color(0xff2c3a4f),
                                  ),
                                ),
                                if (widget.showSender && sender.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      Icon(
                                        widget.kind == LetterKind.outgoing
                                            ? Icons.outbox_outlined
                                            : Icons.person_outline,
                                        size: 13,
                                        color: Colors.blueGrey.shade400,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          sender,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: Colors.blueGrey.shade500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      // دستور ارجاع
                      if (it.matnErja != null && it.matnErja!.trim().isNotEmpty) ...[
                        const SizedBox(height: 9),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xfff4f7fb),
                            borderRadius: BorderRadius.circular(11),
                            border: BorderDirectional(
                              start: BorderSide(color: tint, width: 3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.subdirectory_arrow_left,
                                  size: 13, color: tint.withValues(alpha: .8)),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  it.matnErja!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    height: 1.6,
                                    color: Colors.blueGrey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ..._badges(it),
                          const SizedBox(width: 2),
                          _MetaChip(
                            icon: Icons.calendar_today_outlined,
                            label: Fa.date(it.date?.toIso8601String(), time: false),
                          ),
                          if (it.receiverCount > 0)
                            _MetaChip(
                              icon: Icons.groups_outlined,
                              label: Fa.digits(it.receiverCount),
                            ),
                          if (widget.onNeshan != null)
                            GestureDetector(
                              onTap: widget.onNeshan,
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Icon(
                                  it.isNeshan ? Icons.star : Icons.star_border,
                                  size: 19,
                                  color: it.isNeshan
                                      ? OfficeColors.gold
                                      : Colors.blueGrey.shade300,
                                ),
                              ),
                            ),
                        ],
                      ),
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

  List<Widget> _badges(LetterListItem it) {
    final out = <Widget>[];
    if (it.isUrgent) {
      out.add(_Tag(
        label: it.foriat,
        icon: Icons.bolt,
        color: OfficeColors.forConfidential(it.foriat == 'آنی' ? 'سری' : 'محرمانه'),
      ));
    }
    if (it.isConfidential) {
      out.add(_Tag(
        label: it.mahramanegi,
        icon: Icons.lock_outline,
        color: OfficeColors.forConfidential(it.mahramanegi),
      ));
    }
    if (it.deadline != null) {
      final late = it.deadline!.isBefore(DateTime.now());
      out.add(_Tag(
        label: late
            ? 'دیرکرد ${Fa.date(it.deadline!.toIso8601String(), time: false)}'
            : 'مهلت ${Fa.date(it.deadline!.toIso8601String(), time: false)}',
        icon: late ? Icons.warning_amber_rounded : Icons.schedule,
        color: late ? OfficeColors.danger : OfficeColors.signing,
      ));
    }
    if (it.erjaType != null && it.erjaType!.isNotEmpty && it.erjaType != 'گیرنده') {
      out.add(_Tag(
        label: it.erjaType!,
        icon: it.erjaType == 'هامش' ? Icons.content_copy_outlined : Icons.redo,
        color: it.erjaType == 'هامش' ? OfficeColors.accent : OfficeColors.ok,
      ));
    }
    if (it.hasAttachment) {
      out.add(const _Tag(label: 'پیوست', icon: Icons.attach_file, color: Color(0xff2a6bd4)));
    }
    if (it.typeTaeed != 0) {
      out.add(_Tag(
        label: it.typeTaeed == 1 ? 'تأیید شد' : 'رد شد',
        icon: it.typeTaeed == 1 ? Icons.check_circle_outline : Icons.cancel_outlined,
        color: it.typeTaeed == 1 ? OfficeColors.ok : OfficeColors.danger,
      ));
    }
    if (it.hasAnswer) {
      out.add(const _Tag(label: 'پاسخ دارد', icon: Icons.reply_outlined, color: OfficeColors.ok));
    }
    if (it.outgoingStatus > 0 && widget.kind == LetterKind.outgoing) {
      out.add(_Tag(
        label: _outgoingLabel(it.outgoingStatus),
        icon: Icons.circle,
        color: OfficeColors.forOutgoingStatus(it.outgoingStatus),
      ));
    }
    return out;
  }

  static String _outgoingLabel(int s) => switch (s) {
    3 => 'بایگانی',
    2 => 'ارسال شده',
    1 => 'ثبت شده',
    _ => 'نامشخص',
  };
}

// --- زیرویجت‌های کارت ---

class _KindAvatar extends StatelessWidget {
  const _KindAvatar({
    required this.kind,
    required this.color,
    required this.unread,
    required this.badge,
  });
  final LetterKind? kind;
  final Color color;
  final bool unread;
  final bool badge;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          color.withValues(alpha: unread ? .22 : .12),
          color.withValues(alpha: unread ? .10 : .05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: unread ? .35 : .16)),
    ),
    child: Icon(
      switch (kind) {
        LetterKind.inner => Icons.edit_note,
        LetterKind.outgoing => Icons.north_east,
        LetterKind.incoming => Icons.south_west,
        null => Icons.mail_outline,
      },
      size: 20,
      color: color,
    ),
  );
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number, required this.color});
  final String number;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      'شماره ${Fa.digits(number)}',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: .2,
      ),
    ),
  );
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) => Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color.withValues(alpha: .35 + .65 * _c.value),
      ),
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .18)),
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: Colors.blueGrey.shade400),
      const SizedBox(width: 3),
      Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: Colors.blueGrey.shade500,
        ),
      ),
    ],
  );
}

class _SelectDot extends StatelessWidget {
  const _SelectDot({required this.on, required this.color});
  final bool on;
  final Color color;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      color: on ? color : Colors.transparent,
      shape: BoxShape.circle,
      border: Border.all(color: on ? color : Colors.blueGrey.shade300, width: 2),
    ),
    child: on
        ? const Icon(Icons.check, size: 13, color: Colors.white)
        : const SizedBox.shrink(),
  );
}


// ------------------------------------------------------------
//  تب‌های کشویی (sliding pill) — هم‌رفتار با ماژول دستور کار
// ------------------------------------------------------------

class OfficeSlidingTabs extends StatefulWidget {
  const OfficeSlidingTabs({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
    this.pillColor,
    this.background,
    this.height = 62,
    this.showCounts = false,
    this.counts = const {},
    this.accentFor,
  });

  /// (برچسب، آیکون، کلید شمارنده)
  final List<({String label, IconData icon, String key})> items;
  final int index;
  final ValueChanged<int> onChanged;
  final Color? pillColor;
  final Color? background;
  final double height;
  final bool showCounts;
  final Map<String, int> counts;

  /// رنگ اختصاصی هر تب (در کارتابل‌ها رنگ نوع نامه است)
  final Color Function(int index)? accentFor;

  @override
  State<OfficeSlidingTabs> createState() => _OfficeSlidingTabsState();
}

class _OfficeSlidingTabsState extends State<OfficeSlidingTabs> {
  late final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(covariant OfficeSlidingTabs old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _reveal(widget.index);
  }

  void _reveal(int i) {
    if (!_scroll.hasClients) return;
    final target = (i * 118.0) - 60;
    _scroll.animateTo(
      target.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.pillColor ?? OfficeColors.seed;
    return Container(
      color: widget.background ?? OfficeColors.bg,
      child: SizedBox(
        height: widget.height,
        child: ListView.separated(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          itemCount: widget.items.length,
          separatorBuilder: (context, i) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final item = widget.items[i];
            final count = widget.counts[item.key] ?? 0;
            return _TabPill(
              label: item.label,
              icon: item.icon,
              selected: i == widget.index,
              color: widget.accentFor?.call(i) ?? base,
              badge: widget.showCounts && count > 0 ? count : null,
              onTap: () => widget.onChanged(i),
            );
          },
        ),
      ),
    );
  }
}

class _TabPill extends StatefulWidget {
  const _TabPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
    this.badge,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final int? badge;

  @override
  State<_TabPill> createState() => _TabPillState();
}

class _TabPillState extends State<_TabPill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return GestureDetector(
      onTapDown: (d) => setState(() => _pressed = true),
      onTapUp: (d) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? .95 : 1,
        duration: const Duration(milliseconds: 110),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [widget.color, widget.color.withValues(alpha: .78)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  )
                : null,
            color: selected ? null : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? Colors.transparent : OfficeColors.line,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: .34),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: selected ? Colors.white : Colors.blueGrey.shade400,
              ),
              const SizedBox(width: 7),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected ? Colors.white : Colors.blueGrey.shade700,
                ),
                child: Text(widget.label),
              ),
              if (widget.badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: .28)
                        : widget.color.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    Fa.digits(widget.badge!),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : widget.color,
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
}

// ------------------------------------------------------------
//  هدر گرادیانی صفحهٔ نامه
// ------------------------------------------------------------

class LetterHero extends StatelessWidget {
  const LetterHero({
    super.key,
    required this.title,
    required this.child,
    this.accent = OfficeColors.seed,
    this.progress,
    this.progressLabel,
  });

  final String title;
  final Widget child;
  final Color accent;
  final double? progress;
  final String? progressLabel;

  @override
  Widget build(BuildContext context) => Container(
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
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
      child: Stack(
        children: [
          Positioned(
            left: -40,
            top: -50,
            child: _Bubble(size: 150, opacity: .07),
          ),
          Positioned(
            right: -30,
            bottom: -60,
            child: _Bubble(size: 190, opacity: .06),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                child,
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18.5,
                    height: 1.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.timeline, size: 15, color: Colors.white70),
                      const SizedBox(width: 5),
                      Text(
                        progressLabel ?? 'گردش کار',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: .85),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress!.clamp(0.0, 1.0)),
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
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [Colors.white.withValues(alpha: opacity), Colors.transparent],
      ),
    ),
  );
}

/// بج شیشه‌ای روی هدر
class HeroBadge extends StatelessWidget {
  const HeroBadge({super.key, required this.label, this.icon, this.color});
  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color?.withValues(alpha: .30) ?? Colors.white.withValues(alpha: .22),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: Colors.white.withValues(alpha: .28)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

// ------------------------------------------------------------
//  کارت بخش (شیشه‌ای سفید) + ردیف اطلاعات + حلقهٔ آمار
// ------------------------------------------------------------

class OfficeCard extends StatelessWidget {
  const OfficeCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.color,
    this.trailing,
    this.padding = const EdgeInsets.all(15),
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color? color;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = color ?? OfficeColors.seed;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: padding,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: c),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class OfficeInfoTile extends StatelessWidget {
  const OfficeInfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.blueGrey.shade400;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 15.5, color: c),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 10.5, color: Colors.blueGrey.shade400),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value.isEmpty ? '—' : value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
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

class OfficeRing extends StatelessWidget {
  const OfficeRing({
    super.key,
    required this.value,
    required this.label,
    required this.color,
    this.size = 62,
  });

  final double value;
  final String label;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, v, child) => Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: v,
                strokeWidth: 5.5,
                backgroundColor: color.withValues(alpha: .12),
                valueColor: AlwaysStoppedAnimation(color),
                strokeCap: StrokeCap.round,
              ),
              Text(
                '${Fa.digits((v * 100).round())}٪',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        label,
        style: TextStyle(fontSize: 10.5, color: Colors.blueGrey.shade500),
      ),
    ],
  );
}

/// آمار کوچک آیکونی (برای نوار آماری صفحهٔ نامه)
class MiniStat extends StatelessWidget {
  const MiniStat({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = color ?? OfficeColors.seed;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.withValues(alpha: .10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 17, color: c),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
//  اسکلت بارگذاری
// ------------------------------------------------------------

class OfficeShimmer extends StatefulWidget {
  const OfficeShimmer({super.key, this.count = 5, this.height = 112});
  final int count;
  final double height;

  @override
  State<OfficeShimmer> createState() => _OfficeShimmerState();
}

class _OfficeShimmerState extends State<OfficeShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 90),
    itemCount: widget.count,
    itemBuilder: (_, i) => AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = (_c.value + i * .12) % 1.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 11),
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, 0),
              end: Alignment(0 + 2 * t, 0),
              colors: const [
                Color(0xffeef2f8),
                Color(0xfff8fafd),
                Color(0xffeef2f8),
              ],
            ),
          ),
        );
      },
    ),
  );
}

// ------------------------------------------------------------
//  گردش کار — خط زمانی عمودی نامه
// ------------------------------------------------------------

class GardeshTimeline extends StatelessWidget {
  const GardeshTimeline({super.key, required this.nodes});

  /// (عنوان، توضیح، زمان، رنگ، آیکون)
  final List<({String title, String? subtitle, String? time, Color color, IconData icon})>
  nodes;

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return Text(
        'گردشی ثبت نشده است.',
        style: TextStyle(fontSize: 12.5, color: Colors.blueGrey.shade400),
      );
    }
    return Column(
      children: List.generate(nodes.length, (i) {
        final n = nodes[i];
        final last = i == nodes.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: n.color.withValues(alpha: .12),
                      shape: BoxShape.circle,
                      border: Border.all(color: n.color.withValues(alpha: .35)),
                    ),
                    child: Icon(n.icon, size: 15, color: n.color),
                  ),
                  if (!last)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              n.color.withValues(alpha: .35),
                              n.color.withValues(alpha: .06),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: last ? 0 : 14, top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      if (n.subtitle != null && n.subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          n.subtitle!,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.65,
                            color: Colors.blueGrey.shade600,
                          ),
                        ),
                      ],
                      if (n.time != null && n.time!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          n.time!,
                          style: TextStyle(fontSize: 10.5, color: Colors.blueGrey.shade400),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
