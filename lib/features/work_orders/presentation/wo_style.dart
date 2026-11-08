// ============================================================
//  زبان طراحی ماژول دستور کار
//  رنگ‌ها، گرادیان‌ها، انیمیشن‌های ورود، تب‌های کشویی و کارت‌های شیشه‌ای
//  همهٔ ویجت‌ها RTL-آگاه و سبک‌اند (بدون وابستگی جدید)
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/fa.dart';
import '../models/work_order.dart';

// ------------------------------------------------------------
//  پالت رنگ
// ------------------------------------------------------------

class WoColors {
  static const seed = Color(0xff2547a8);
  static const deep = Color(0xff152a63);
  static const accent = Color(0xff5b47d6);

  static const open = Color(0xff1a7f37);
  static const overdue = Color(0xffd13438);
  static const urgent = Color(0xffe07b00);
  static const closed = Color(0xff6b7a90);

  static const bg = Color(0xfff4f7fb);
  static const line = Color(0xffe4eaf3);

  /// رنگ وضعیت یک دستور کار (باز / دیرکرد / فوری / بسته)
  static Color forOrder(WorkOrder o) => !o.isOpen
      ? closed
      : o.isOverdue
      ? overdue
      : o.priority == 3
      ? urgent
      : open;

  static LinearGradient gradientFor(WorkOrder o) {
    if (!o.isOpen) {
      return const LinearGradient(colors: [Color(0xff8d99ae), Color(0xff5d6b80)]);
    }
    if (o.isOverdue) {
      return const LinearGradient(colors: [Color(0xffe05357), Color(0xffa4262c)]);
    }
    if (o.priority == 3) {
      return const LinearGradient(colors: [Color(0xfff3a33c), Color(0xffd2691e)]);
    }
    if (o.priority == 2) {
      return const LinearGradient(colors: [Color(0xff4f7ce8), Color(0xff2547a8)]);
    }
    return const LinearGradient(colors: [Color(0xff3fb27f), Color(0xff1a7f37)]);
  }

  static LinearGradient get heroGradient => const LinearGradient(
    colors: [deep, seed, accent],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
}

// ------------------------------------------------------------
//  انیمیشن ورود آیتم لیست (fade + slide + scale)
// ------------------------------------------------------------

class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
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
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
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
    final delay = widget.index * widget.delayMs;
    // آیتم‌های دورتر از صفحه با تأخیر کمتری می‌آیند تا لیست کند نشود
    Future.delayed(Duration(milliseconds: math.min(delay, 480)), () {
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
    builder: (context, child) => Opacity(
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
//  تب‌های کشویی (sliding pill) — انیمیشن روان با اندیکاتور متحرک
// ------------------------------------------------------------

class SlidingTabs extends StatefulWidget {
  const SlidingTabs({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
    this.pillColor,
    this.background,
    this.height = 62,
    this.showCounts = false,
    this.counts = const {},
  });

  final List<({String label, IconData icon, String key})> items;
  final int index;
  final ValueChanged<int> onChanged;
  final Color? pillColor;
  final Color? background;
  final double height;
  final bool showCounts;
  final Map<String, int> counts;

  @override
  State<SlidingTabs> createState() => _SlidingTabsState();
}

class _SlidingTabsState extends State<SlidingTabs> {
  late final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(covariant SlidingTabs old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _reveal(widget.index);
  }

  void _reveal(int i) {
    if (!_scroll.hasClients) return;
    const w = 118.0;
    final target = (i * w) - 60;
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
    final pill = widget.pillColor ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: widget.height,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemCount: widget.items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = i == widget.index;
          final item = widget.items[i];
          final count = widget.counts[item.key] ?? 0;
          return _TabPill(
            label: item.label,
            icon: item.icon,
            selected: selected,
            color: pill,
            badge: widget.showCounts && count > 0 ? count : null,
            onTap: () => widget.onChanged(i),
          );
        },
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
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
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
              color: selected ? Colors.transparent : WoColors.line,
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
              AnimatedRotation(
                turns: selected ? 0 : 0,
                duration: const Duration(milliseconds: 260),
                child: Icon(
                  widget.icon,
                  size: 18,
                  color: selected ? Colors.white : Colors.blueGrey.shade400,
                ),
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
//  کارت دستور کار — نسخهٔ گرادیانی با انیمیشن و نوار پیشرفت
// ------------------------------------------------------------

class GlowWorkOrderCard extends StatefulWidget {
  const GlowWorkOrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.selected = false,
    this.onSelect,
    this.index = 0,
  });

  final WorkOrder order;
  final VoidCallback onTap;
  final bool selected;
  final ValueChanged<bool>? onSelect;
  final int index;

  @override
  State<GlowWorkOrderCard> createState() => _GlowWorkOrderCardState();
}

class _GlowWorkOrderCardState extends State<GlowWorkOrderCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.order.isOverdue) _shimmer.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant GlowWorkOrderCard old) {
    super.didUpdateWidget(old);
    if (widget.order.isOverdue && !_shimmer.isAnimating) {
      _shimmer.repeat(reverse: true);
    } else if (!widget.order.isOverdue && _shimmer.isAnimating) {
      _shimmer.stop();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final status = WoColors.forOrder(o);
    final gradient = WoColors.gradientFor(o);
    final done = o.checklistTotal == 0 ? 0.0 : o.checklistDone / o.checklistTotal;

    return FadeSlideIn(
      index: widget.index,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        onLongPress: widget.onSelect == null
            ? null
            : () => widget.onSelect!(!widget.selected),
        child: AnimatedScale(
          scale: _pressed ? .975 : 1,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: Container(
            margin: const EdgeInsets.only(bottom: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: widget.selected ? WoColors.seed : WoColors.line,
                width: widget.selected ? 1.8 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: (widget.selected ? WoColors.seed : Colors.blueGrey)
                      .withValues(alpha: widget.selected ? .20 : .07),
                  blurRadius: widget.selected ? 18 : 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Stack(
                children: [
                  // نوار رنگی سمت راست (RTL)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 5,
                      decoration: BoxDecoration(gradient: gradient),
                    ),
                  ),
                  // درخشش ملایم برای دستورهای دارای دیرکرد
                  if (o.isOverdue)
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _shimmer,
                        builder: (_, __) => IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                                colors: [
                                  WoColors.overdue.withValues(
                                    alpha: .03 + .05 * _shimmer.value,
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
                    padding: const EdgeInsets.fromLTRB(14, 13, 15, 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.onSelect != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: widget.selected,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    onChanged: (v) =>
                                        widget.onSelect!(v ?? false),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _NumberBadge(text: o.number, color: status),
                                      const SizedBox(width: 7),
                                      _StatusDot(overdue: o.isOverdue, open: o.isOpen),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    o.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.45,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            _PriorityBadge(priority: o.priority, closed: !o.isOpen),
                          ],
                        ),
                        if (o.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            o.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.6,
                              color: Colors.blueGrey.shade500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _Tag(
                              text: !o.isOpen
                                  ? 'بسته'
                                  : o.isOverdue
                                      ? 'دیرکرد'
                                      : 'باز',
                              color: status,
                              icon: !o.isOpen
                                  ? Icons.lock_outline
                                  : o.isOverdue
                                      ? Icons.warning_amber_rounded
                                      : Icons.play_circle_outline,
                            ),
                            if (o.recurrence > 0)
                              _Tag(
                                text: Fa.recurrence(o.recurrence),
                                color: const Color(0xff0d7d8c),
                                icon: Icons.repeat,
                              ),
                            ...o.tags.take(2).map(
                              (t) => _Tag(
                                text: t,
                                color: const Color(0xff6b4fd8),
                                icon: Icons.sell_outlined,
                              ),
                            ),
                          ],
                        ),
                        if (o.checklistTotal > 0) ...[
                          const SizedBox(height: 11),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: done),
                                    duration: const Duration(milliseconds: 900),
                                    curve: Curves.easeOutCubic,
                                    builder: (_, v, __) => LinearProgressIndicator(
                                      value: v,
                                      minHeight: 5,
                                      backgroundColor: WoColors.line,
                                      valueColor: AlwaysStoppedAnimation(
                                        done >= 1 ? WoColors.open : status,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${Fa.digits(o.checklistDone)}/${Fa.digits(o.checklistTotal)}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.blueGrey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 11),
                        Row(
                          children: [
                            Icon(
                              Icons.event_outlined,
                              size: 14,
                              color: o.isOverdue
                                  ? WoColors.overdue
                                  : Colors.blueGrey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              Fa.date(o.dueAt, time: false),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: o.isOverdue
                                    ? WoColors.overdue
                                    : Colors.blueGrey.shade600,
                              ),
                            ),
                            const Spacer(),
                            if (o.commentCount > 0) ...[
                              _MetaIcon(
                                icon: Icons.chat_bubble_outline,
                                value: o.commentCount,
                              ),
                              const SizedBox(width: 9),
                            ],
                            if (o.attachmentCount > 0) ...[
                              _MetaIcon(
                                icon: Icons.attach_file,
                                value: o.attachmentCount,
                              ),
                              const SizedBox(width: 9),
                            ],
                            _Avatars(assignees: o.assignees),
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
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      Fa.digits(text),
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: .3,
      ),
    ),
  );
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.overdue, required this.open});
  final bool overdue;
  final bool open;

  @override
  Widget build(BuildContext context) {
    if (!open) return const SizedBox.shrink();
    final color = overdue ? WoColors.overdue : WoColors.open;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .35, end: 1),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeInOut,
      builder: (_, v, __) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: color.withValues(alpha: v),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority, required this.closed});
  final int priority;
  final bool closed;

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = closed
        ? (WoColors.closed, 'بسته', Icons.lock_outline)
        : switch (priority) {
            3 => (WoColors.urgent, 'فوری', Icons.bolt),
            2 => (WoColors.seed, 'بالا', Icons.arrow_upward),
            0 => (WoColors.open, 'کم', Icons.arrow_downward),
            _ => (const Color(0xff55637a), 'عادی', Icons.drag_handle),
          };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color, required this.icon});
  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .16)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _MetaIcon extends StatelessWidget {
  const _MetaIcon({required this.icon, required this.value});
  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: Colors.blueGrey.shade400),
      const SizedBox(width: 2),
      Text(
        Fa.digits(value),
        style: TextStyle(fontSize: 10.5, color: Colors.blueGrey.shade500),
      ),
    ],
  );
}

class _Avatars extends StatelessWidget {
  const _Avatars({required this.assignees});
  final List<Assignee> assignees;

  static const _palette = [
    Color(0xff2547a8),
    Color(0xff1a7f37),
    Color(0xffd2691e),
    Color(0xff6b4fd8),
    Color(0xff0d7d8c),
  ];

  @override
  Widget build(BuildContext context) {
    if (assignees.isEmpty) return const SizedBox.shrink();
    final shown = assignees.take(3).toList();
    return SizedBox(
      height: 24,
      width: 24.0 + (shown.length - 1) * 15 + (assignees.length > 3 ? 18 : 0),
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              right: i * 15.0,
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _palette[i % _palette.length],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.6),
                ),
                child: Text(
                  shown[i].name.isEmpty
                      ? '؟'
                      : shown[i].name.characters.first,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          if (assignees.length > 3)
            Positioned(
              right: shown.length * 15.0,
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade200,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.6),
                ),
                child: Text(
                  '+${Fa.digits(assignees.length - 3)}',
                  style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
//  بلوک‌های صفحهٔ جزئیات
// ------------------------------------------------------------

/// هدر گرادیانی صفحهٔ جزئیات با نوار پیشرفت و بج‌های وضعیت
class DetailHero extends StatelessWidget {
  const DetailHero({
    super.key,
    required this.order,
    required this.child,
  });

  final WorkOrder order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final progress = order.checklistTotal == 0
        ? 0.0
        : order.checklistDone / order.checklistTotal;
    return Container(
      decoration: BoxDecoration(
        gradient: WoColors.heroGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: WoColors.deep.withValues(alpha: .28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
        child: Stack(
          children: [
            // حباب‌های تزئینی
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
                  if (order.checklistTotal > 0) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.checklist_rtl,
                          size: 15,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'پیشرفت چک‌لیست',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: .8),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${Fa.digits(order.checklistDone)} از ${Fa.digits(order.checklistTotal)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 950),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => LinearProgressIndicator(
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

/// کارت شیشه‌ای/سفید با عنوان آیکونی
class GlassCard extends StatelessWidget {
  const GlassCard({
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
    final c = color ?? WoColors.seed;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WoColors.line),
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
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
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

/// یک ردیف اطلاعات با آیکون در کارت
class InfoTile extends StatelessWidget {
  const InfoTile({
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
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.blueGrey.shade400,
                    ),
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

/// نوار پیشرفت دایره‌ای برای آمار کوچک
class RingStat extends StatelessWidget {
  const RingStat({
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
          builder: (_, v, __) => Stack(
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
                '${(v * 100).round()}٪',
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

/// الگوی ریتمیک کارت‌های اسکلتی برای حالت بارگذاری
class ShimmerList extends StatefulWidget {
  const ShimmerList({super.key, this.count = 5});
  final int count;

  @override
  State<ShimmerList> createState() => _ShimmerListState();
}

class _ShimmerListState extends State<ShimmerList>
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
      builder: (_, __) {
        final t = (_c.value + i * .12) % 1.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 11),
          height: 118,
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
