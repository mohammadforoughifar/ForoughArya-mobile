// ============================================================
//  ویجت‌های مشترک فاز ۹-ج (سیستم‌ها / شناسنامه / کاربران)
//  • گیج دایره‌ای سلامت — همان `Shared/HealthGauge.razor` (شعاع ۵۲، ضخامت ۱۲،
//    رنگ‌بندی آستانه‌ای و فونت ۳۶ برای مرکز)
//  • دونات چندبخشی سیستم‌عامل — همان `OsDonut` در `SystemInfoList.razor`
//  • کارت بخش (card با هدر گرادیانی یکسان با جدول‌های وب)
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/fa.dart';
import '../../../core/widgets/common.dart';
import '../../shop/presentation/shop_style.dart';
import '../models/system_models.dart';

Color hexColor(String? hex, {Color fallback = ShopColors.inkFaint}) {
  final s = (hex ?? '').trim().replaceFirst('#', '');
  if (s.length != 6 && s.length != 8) return fallback;
  final v = int.tryParse(s, radix: 16);
  if (v == null) return fallback;
  return Color(s.length == 6 ? 0xff000000 | v : v);
}

/// گیج دایره‌ای امتیاز سلامت (۰–۱۰۰)
class HealthGauge extends StatelessWidget {
  const HealthGauge({
    super.key,
    required this.score,
    this.size = 40,
    this.label,
    this.showLabel = false,
    this.showScore = true,
  });

  final int? score;
  final double size;
  final String? label;
  final bool showLabel;
  final bool showScore;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: healthTip(score),
      child: CustomPaint(
        size: Size(size, size),
        painter: _GaugePainter(
          score: score,
          showLabel: showLabel,
          showScore: showScore,
          label: label,
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    this.score,
    this.showLabel = false,
    this.showScore = true,
    this.label,
  });

  final int? score;
  final bool showLabel;
  final bool showScore;
  final String? label;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 120.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = 52 * scale;
    final stroke = 12 * scale;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xffeef0f7);
    canvas.drawCircle(center, radius, track);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = hexColor(healthRingColor(score));

    if (score == null) {
      _text(
        canvas,
        '—',
        Offset(center.dx, center.dy),
        size: 36 * scale,
        weight: FontWeight.w700,
        color: const Color(0xffb6bccb),
      );
      return;
    }

    if (!showScore) {
      // همان حالت `ShowScore=false` وب: دو دایرهٔ توپُر با شفافیت
      final soft = Paint()..color = ring.color.withValues(alpha: 0.16);
      canvas.drawCircle(center, 26 * scale, soft);
      canvas.drawCircle(center, 12 * scale, Paint()..color = ring.color);
      return;
    }

    final sweep = (score!.clamp(0, 100)) * 2 * math.pi / 100;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      ring,
    );

    final y = size.height / 2 + (size.width >= 90 ? 8 : 11) * scale;
    _text(
      canvas,
      '${score!}',
      Offset(center.dx, y),
      size: (size.width >= 90 ? 27 : 36) * scale,
      weight: FontWeight.w900,
      color: const Color(0xff1c2130),
      anchor: true,
    );

    if (showLabel && (label ?? '').isNotEmpty) {
      _text(
        canvas,
        label!,
        Offset(center.dx, size.height / 2 + 30 * scale),
        size: 15 * scale,
        weight: FontWeight.w700,
        color: ring.color,
        anchor: true,
      );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    required double size,
    required FontWeight weight,
    required Color color,
    bool anchor = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: size, fontWeight: weight, color: color),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    final dx = anchor ? at.dx - tp.width / 2 : at.dx - tp.width / 2;
    final dy = anchor ? at.dy - tp.height / 2 : at.dy - tp.height / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.score != score ||
      old.showLabel != showLabel ||
      old.showScore != showScore ||
      old.label != label;
}

/// دونات چندبخشی سیستم‌عامل با عدد مرکزی «N سیستم»
class OsDonut extends StatelessWidget {
  const OsDonut({super.key, required this.segments, required this.total});

  final List<OsSegment> segments;
  final int total;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(140, 140),
            painter: _DonutPainter(segments: segments, total: total),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Fa.digits(total),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.ink,
                ),
              ),
              const Text(
                'سیستم',
                style: TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.segments, required this.total});

  final List<OsSegment> segments;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * (42 / 110);
    final stroke = size.width * (14 / 110);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = const Color(0xffeef0f7),
    );

    final sum = math.max(1, total);
    var acc = 0.0;
    for (final seg in segments) {
      final sweep = seg.count * 2 * math.pi / sum;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2 + acc,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = hexColor(seg.color),
      );
      acc += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.total != total || old.segments != segments;
}

/// کارت با هدر یکسان با کارت‌های جدول وب
class SystemCard extends StatelessWidget {
  const SystemCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(12, 10, 12, 12),
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
              decoration: const BoxDecoration(
                color: Color(0xfff7f9fd),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: ShopColors.line)),
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 14, color: ShopColors.inkSoft),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: ShopColors.ink,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// ردیف «برچسب — مقدار» برای مشخصات
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.ltr = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                color: ShopColors.inkFaint,
                height: 1.6,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
              textAlign: ltr ? TextAlign.right : TextAlign.right,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.6,
                color: valueColor ?? ShopColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// نوار افقی درصدی (برای میانگین رم دپارتمان و دسته‌های سلامت)
class MiniBar extends StatelessWidget {
  const MiniBar({
    super.key,
    required this.pct,
    this.color = ShopColors.seed,
    this.height = 6,
  });

  final int pct;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: const Color(0xffeef0f7),
        child: FractionallySizedBox(
          alignment: Alignment.centerRight,
          widthFactor: (pct.clamp(0, 100)) / 100,
          child: Container(color: color),
        ),
      ),
    );
  }
}

/// کادر پیام (خطا/هشدار/اطلاع)
class SystemNote extends StatelessWidget {
  const SystemNote({
    super.key,
    required this.text,
    this.color = ShopColors.seed,
    this.icon = Icons.info_outline_rounded,
  });

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 10.5, height: 1.7, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// دکمهٔ کوچک اکشن ردیف (تأیید / جزئیات / تاریخچه / حذف)
class RowAction extends StatelessWidget {
  const RowAction({
    super.key,
    required this.icon,
    required this.color,
    this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final w = Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.35)),
            color: color.withValues(alpha: 0.06),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
    return w;
  }
}

/// نمایشگر خالی/بارگذاری/خطا با همان زبان بصری
class SystemLoadState extends StatelessWidget {
  const SystemLoadState({
    super.key,
    this.loading = false,
    this.error,
    this.onRetry,
    this.emptyTitle,
    this.emptySubtitle,
    this.emptyIcon = Icons.inbox_rounded,
  });

  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final String? emptyTitle;
  final String? emptySubtitle;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    if (loading) return const LoadingView();
    if (error != null && onRetry != null) {
      return ErrorView(message: error!, onRetry: onRetry!);
    }
    return ShopEmpty(
      title: emptyTitle ?? 'موردی برای نمایش وجود ندارد',
      subtitle: emptySubtitle,
      icon: emptyIcon,
    );
  }
}
