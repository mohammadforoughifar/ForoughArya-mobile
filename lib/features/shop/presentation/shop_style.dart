// ============================================================
//  زبان بصری لوکس و یکپارچهٔ «فروشگاهی کایر» در موبایل
//  هماهنگ با میز کار فروغ آریا، با هویت اختصاصی تجاری/فین‌تک کایر
//  (یاقوتی تیره، زمردی بازرگانی، فیروزه‌ای خزانه و طلایی شاخص‌ها).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/fa.dart';

class ShopColors {
  static const seed = Color(0xff1d4ed8);
  static const deep = Color(0xff0b1938);
  static const kayerNavy = Color(0xff081229);
  static const kayerTeal = Color(0xff0d5c63);
  static const kayerEmerald = Color(0xff059669);
  static const kayerCyan = Color(0xff0284c7);
  static const kayerGold = Color(0xffd97706);

  static const accent = Color(0xff6d28d9);
  static const indigo = Color(0xff4338ca);
  static const teal = Color(0xff0f766e);

  static const ok = Color(0xff059669);
  static const warn = Color(0xffd97706);
  static const danger = Color(0xffdc2626);

  static const bg = Color(0xfff1f5fb);
  static const surface = Colors.white;
  static const surfaceSoft = Color(0xfff8fafd);
  static const line = Color(0xffe2e8f2);
  static const ink = Color(0xff0f172a);
  static const inkSoft = Color(0xff475569);
  static const inkFaint = Color(0xff64748b);

  /// گرادیان اختصاصی سربرگ‌های داخلی فروشگاهی کایر
  static const heroGradient = LinearGradient(
    colors: [
      Color(0xff091530),
      Color(0xff14346b),
      Color(0xff134e6f),
      Color(0xff0f766e),
    ],
    stops: [0.0, 0.42, 0.76, 1.0],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  /// گرادیان پرچمدار میز فرماندهی اصلی «فروشگاهی کایر»
  static const kayerCockpitGradient = LinearGradient(
    colors: [
      Color(0xff071126),
      Color(0xff0f2854),
      Color(0xff114b5f),
      Color(0xff0c6b58),
    ],
    stops: [0.0, 0.38, 0.74, 1.0],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
}

/// مبلغ ریالی با جداکنندهٔ هزارگان فارسی
String money(num? v) => Fa.number(v ?? 0);

/// عدد فارسی (مقدار و تعداد)
String numFa(num? v) => Fa.number(v ?? 0);

/// نمایش خلاصه و خوانای مبالغ ریالی در کارت‌های مدیریتی کایر
String compactRial(num? v) {
  final n = (v ?? 0).toDouble();
  final sign = n < 0 ? '-' : '';
  final abs = n.abs();
  if (abs >= 1000000000) {
    final b = abs / 1000000000.0;
    return '$sign${Fa.number(b, decimals: b >= 10 ? 1 : 2)} میلیارد';
  }
  if (abs >= 1000000) {
    final m = abs / 1000000.0;
    return '$sign${Fa.number(m, decimals: m >= 100 ? 0 : 1)} میلیون';
  }
  if (abs >= 1000) {
    return '$sign${Fa.number(abs.round())}';
  }
  return '$sign${Fa.number(abs.round())}';
}

/// ویجت لمسی با افکت فشرده‌شدن نرم و بازخورد لمسی ظریف
class ShopPressable extends StatefulWidget {
  const ShopPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<ShopPressable> createState() => _ShopPressableState();
}

class _ShopPressableState extends State<ShopPressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null && widget.onLongPress == null) {
      return widget.child;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap?.call();
      },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onLongPress?.call();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// شبکهٔ هندسی ظریف پس‌زمینهٔ سربرگ‌های کایر
class ShopGridPainter extends CustomPainter {
  const ShopGridPainter({this.opacity = 0.045});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..strokeWidth = 0.8;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant ShopGridPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}

/// سربرگ گرادیانی لوکس صفحات فروشگاهی کایر
class ShopHeader extends StatelessWidget {
  const ShopHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.badge,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? badge;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final hasAppBar = Scaffold.maybeOf(context)?.hasAppBar ?? false;
    final showBack = !hasAppBar && Navigator.of(context).canPop();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: ShopColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Color(0x22091530),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: ShopGridPainter()),
            ),
            Positioned(
              left: -40,
              top: -35,
              child: Container(
                width: 145,
                height: 145,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xff34d399).withValues(alpha: 0.20),
                      const Color(0xff34d399).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -30,
              bottom: -45,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xff38bdf8).withValues(alpha: 0.18),
                      const Color(0xff38bdf8).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              top: !hasAppBar,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (showBack) ...[
                          ShopPressable(
                            onTap: () => Navigator.of(context).maybePop(),
                            scale: 0.92,
                            child: Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.24),
                                ),
                              ),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                                size: 19,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.24),
                                Colors.white.withValues(alpha: 0.09),
                              ],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Icon(icon, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                  if (badge != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xff34d399,
                                        ).withValues(alpha: 0.22),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(
                                            0xff6ee7b7,
                                          ).withValues(alpha: 0.40),
                                        ),
                                      ),
                                      child: Text(
                                        badge!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.84),
                                  fontSize: 11.5,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Row(children: actions),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// دکمهٔ شیشه‌ای یا برجسته داخل سربرگ کایر
class ShopHeaderButton extends StatelessWidget {
  const ShopHeaderButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ShopPressable(
        onTap: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: filled
                ? Colors.white
                : Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: filled
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.26),
            ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: filled ? ShopColors.deep : Colors.white,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: filled ? ShopColors.deep : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// کارت شاخص (KPI) مدرن فین‌تک کایر
class ShopKpi extends StatelessWidget {
  const ShopKpi({
    super.key,
    required this.title,
    required this.value,
    this.unit,
    this.icon,
    this.color = ShopColors.seed,
    this.footer,
  });

  final String title;
  final String value;
  final String? unit;
  final IconData? icon;
  final Color color;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.35)],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: ShopColors.inkSoft,
                          height: 1.45,
                        ),
                      ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.withValues(alpha: 0.18),
                              color.withValues(alpha: 0.07),
                            ],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 15.5, color: color),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: -0.3,
                  ),
                ),
                if (unit != null)
                  Text(
                    unit!,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: ShopColors.inkFaint,
                    ),
                  ),
                if (footer != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    footer!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: ShopColors.inkSoft,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// برچسب کوچک رنگی
class ShopTag extends StatelessWidget {
  const ShopTag({
    super.key,
    required this.text,
    this.color = ShopColors.seed,
    this.icon,
  });

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11.5, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// نوار تب سگمنتی مدرن کایر
class ShopSegmented extends StatelessWidget {
  const ShopSegmented({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: ShopColors.line),
        boxShadow: [
          BoxShadow(
            color: ShopColors.deep.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(i);
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                height: 40,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  gradient: active
                      ? const LinearGradient(
                          colors: [Color(0xff1d4ed8), Color(0xff0f766e)],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: ShopColors.seed.withValues(alpha: 0.24),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : ShopColors.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// کادر خالی مدرن با هالهٔ ملایم
class ShopEmpty extends StatelessWidget {
  const ShopEmpty({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ShopColors.line),
        boxShadow: [
          BoxShadow(
            color: ShopColors.deep.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ShopColors.seed.withValues(alpha: 0.07),
              border: Border.all(
                color: ShopColors.seed.withValues(alpha: 0.14),
              ),
            ),
            child: Icon(
              icon,
              size: 30,
              color: ShopColors.seed.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: ShopColors.ink,
              fontSize: 13,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.2,
                color: ShopColors.inkFaint,
                height: 1.65,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// نام مستعار `ShopTag` برای یکپارچگی در کارت‌های عملیاتی
typedef ShopPill = ShopTag;

/// کادر جستجوی استاندارد صفحات فروشگاهی کایر
class ShopSearchField extends StatelessWidget {
  const ShopSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, val, _) => Container(
        decoration: BoxDecoration(
          color: ShopColors.surfaceSoft,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: ShopColors.line),
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 11.5,
              color: ShopColors.inkFaint,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 19,
              color: ShopColors.seed,
            ),
            suffixIcon: val.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    onPressed: () {
                      controller.clear();
                      onChanged?.call('');
                    },
                  ),
            isDense: true,
          ),
        ),
      ),
    );
  }
}

/// برچسب فیلد فرم
class ShopField extends StatelessWidget {
  const ShopField({
    super.key,
    required this.label,
    required this.child,
    this.hint,
    this.required = false,
  });

  final String label;
  final Widget child;
  final String? hint;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: ShopColors.inkSoft,
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(
                  fontSize: 12,
                  color: ShopColors.danger,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(
            hint!,
            style: const TextStyle(fontSize: 9.8, color: ShopColors.inkFaint),
          ),
        ],
        const SizedBox(height: 6),
        child,
        const SizedBox(height: 12),
      ],
    );
  }
}
