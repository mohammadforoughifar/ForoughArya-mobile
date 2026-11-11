// ============================================================
//  نوار ناوبری اصلی — «شیشهٔ شناور» با پیل کشویی
//
//  الگو گرفته از روند ۲۰۲۶: Floating Pill + Glassmorphism
//  (iOS 26 / visionOS) ولی کاملاً بومی و بدون پکیج اضافه، تا حجم
//  APK بالا نرود.
//
//  جزئیات حرکت:
//    • پیل انتخاب‌شده با فنر (elasticOut) بین تب‌ها می‌لغزد
//    • آیکون انتخاب‌شده از خطی به توپُر تبدیل و کمی بزرگ می‌شود
//    • برچسب تب فعال بزرگ‌تر و پررنگ‌تر می‌شود
//    • هر لمس یک ویبرهٔ ریز (lightImpact) می‌دهد
//    • در RTL از راست شروع می‌شود (PositionedDirectional)
// ============================================================

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.badge,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int? badge;
}

class GlassNavBar extends StatefulWidget {
  const GlassNavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onSelected,
    this.accent = const Color(0xff1f6feb),
    this.tint = const Color(0xff0f766e),
  });

  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onSelected;
  final Color accent;
  final Color tint;

  @override
  State<GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends State<GlassNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pill = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: 0,
  );

  /// موقعیت پیل به‌صورت Animation از ۰ تا index فعلی
  late Animation<double> _pos;
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _pos = Tween<double>(
      begin: widget.index.toDouble(),
      end: widget.index.toDouble(),
    ).animate(CurvedAnimation(parent: _pill, curve: Curves.easeOutBack));
    _pill.value = 1;
  }

  @override
  void didUpdateWidget(covariant GlassNavBar old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _from = _pos.value;
      _pos = Tween<double>(
        begin: _from,
        end: widget.index.toDouble(),
      ).animate(CurvedAnimation(parent: _pill, curve: Curves.easeOutBack));
      _pill.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final count = widget.items.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 10 + bottom * 0.6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              // شیشهٔ نیمه‌شفاف با رگهٔ رنگی برند
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  Colors.white.withValues(alpha: 0.90),
                  Colors.white.withValues(alpha: 0.74),
                ],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // پیل لغزان
                AnimatedBuilder(
                  animation: _pill,
                  builder: (context, _) {
                    final w =
                        (MediaQuery.of(context).size.width - 24) / count;
                    // در RTL ستون اول از راست است
                    final dir = Directionality.of(context);
                    final slot = _pos.value.clamp(0.0, count - 1.0);
                    final offset = dir == TextDirection.rtl
                        ? (count - 1 - slot) * w
                        : slot * w;
                    return Positioned(
                      top: 7,
                      bottom: 7,
                      left: offset + 6,
                      width: w - 12,
                      child: _Pill(
                        accent: widget.accent,
                        tint: widget.tint,
                        progress: slot,
                      ),
                    );
                  },
                ),
                Row(
                  children: [
                    for (var i = 0; i < count; i++)
                      Expanded(
                        child: _NavButton(
                          item: widget.items[i],
                          selected: i == widget.index,
                          accent: widget.accent,
                          onTap: () {
                            if (i == widget.index) return;
                            HapticFeedback.lightImpact();
                            widget.onSelected(i);
                          },
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

/// پیل با گرادیان برند و درخشش داخلی
class _Pill extends StatelessWidget {
  const _Pill({
    required this.accent,
    required this.tint,
    required this.progress,
  });

  final Color accent;
  final Color tint;
  final double progress;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Color.lerp(accent, tint, (progress % 2) / 2)!,
          Color.lerp(tint, accent, (progress % 2) / 2)!,
        ],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: accent.withValues(alpha: 0.30),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    ),
  );
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : const Color(0xff5b6b7c);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 26,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: anim,
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                      child: Icon(
                        selected ? item.activeIcon : item.icon,
                        key: ValueKey<bool>(selected),
                        size: selected ? 23 : 21,
                        color: color,
                      ),
                    ),
                    if ((item.badge ?? 0) > 0)
                      PositionedDirectional(
                        top: -3,
                        end: -8,
                        child: _Badge(count: item.badge!),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 240),
                style: TextStyle(
                  fontSize: selected ? 10.5 : 9.5,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                  fontFamily: 'Vazirmatn',
                ),
                child: Text(item.label, maxLines: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    constraints: const BoxConstraints(minWidth: 15),
    decoration: BoxDecoration(
      color: const Color(0xffe2445c),
      borderRadius: BorderRadius.circular(100),
      border: Border.all(color: Colors.white, width: 1.2),
    ),
    child: Text(
      count > 99 ? '۹۹+' : _fa(count),
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 8,
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    ),
  );

  static String _fa(int n) {
    const en = '0123456789';
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    return n.toString().split('').map((c) {
      final i = en.indexOf(c);
      return i < 0 ? c : fa[i];
    }).join();
  }
}
