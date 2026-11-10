// ============================================================
//  زبان بصری و مؤلفه‌های مشترک «سامانه فروشگاهی» در موبایل
//  همان پالت HomeColors/OfficeColors است تا کاربر حس یک اپ را داشته باشد.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/utils/fa.dart';

class ShopColors {
  static const seed = Color(0xff2547a8);
  static const deep = Color(0xff152a63);
  static const accent = Color(0xff5b47d6);
  static const indigo = Color(0xff4f46e5);
  static const teal = Color(0xff0f766e);

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
    colors: [deep, seed, indigo],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
}

/// مبلغ ریالی با جداکنندهٔ هزارگان فارسی
String money(num? v) => Fa.number(v ?? 0);

/// عدد فارسی (مقدار و تعداد)
String numFa(num? v) => Fa.number(v ?? 0);

/// سربرگ گرادیانی صفحات فروشگاهی (هم‌سنگِ fin-header در وب)
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: const BoxDecoration(
        gradient: ShopColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: Colors.white, size: 23),
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
                                fontWeight: FontWeight.w800,
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
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                badge!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
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
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
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
    );
  }
}

/// دکمهٔ شیشه‌ای داخل سربرگ
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
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled
                ? Colors.white
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
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
                    fontWeight: FontWeight.w700,
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

/// کارت شاخص (KPI) همان fin-kpi-card وب
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: ShopColors.inkFaint,
                    height: 1.5,
                  ),
                ),
              ),
              if (icon != null)
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 15, color: color),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          if (unit != null)
            Text(
              unit!,
              style: const TextStyle(
                fontSize: 9.5,
                color: ShopColors.inkFaint,
              ),
            ),
          if (footer != null) ...[
            const SizedBox(height: 6),
            Text(
              footer!,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 9.5,
                color: ShopColors.inkSoft,
                height: 1.5,
              ),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// نوار تب سگمنتی (مشتریان | تأمین‌کنندگان) مثل op-tabs-nav وب
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ShopColors.line),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? ShopColors.seed : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : ShopColors.inkSoft,
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

/// کادر خالی
class ShopEmpty extends StatelessWidget {
  const ShopEmpty({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_rounded,
  });

  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 16),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: ShopColors.inkFaint.withValues(alpha: 0.6)),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: ShopColors.inkSoft,
              fontSize: 12.5,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: ShopColors.inkFaint,
                height: 1.6,
              ),
            ),
          ],
        ],
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
                fontWeight: FontWeight.w700,
                color: ShopColors.inkSoft,
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(
                  fontSize: 12,
                  color: ShopColors.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(
            hint!,
            style: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
          ),
        ],
        const SizedBox(height: 6),
        child,
        const SizedBox(height: 12),
      ],
    );
  }
}
