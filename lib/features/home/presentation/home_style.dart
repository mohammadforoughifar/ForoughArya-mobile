// ============================================================
//  زبان طراحی صفحهٔ اصلی
//  همان هویت بصری ماژول‌های «دستور کار» و «اتوماسیون اداری»:
//  گرادیان نیلی، کارت درخشان، هالهٔ نبضی و ریزانیمیشن‌های ورود —
//  به‌همراه انیمیشن‌های اختصاصی این صفحه:
//    • شمارش تدریجی اعداد (count-up)
//    • رسم تدریجی sparkline
//    • مقیاس/شفافیت کارت‌های کاروسل بر اساس فاصله از مرکز
//    • هالهٔ نبضی روی زنگولهٔ اعلان
//    • اسکلت shimmer هنگام بارگذاری
// ============================================================

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/utils/fa.dart';

// ------------------------------------------------------------
//  پالت
// ------------------------------------------------------------

class HomeColors {
  static const seed = Color(0xff2547a8);
  static const deep = Color(0xff152a63);
  static const accent = Color(0xff5b47d6);

  static const bg = Color(0xfff4f7fb);
  static const surface = Color(0xffffffff);
  static const line = Color(0xffe4eaf3);
  static const ink = Color(0xff1e293b);
  static const inkSoft = Color(0xff5b6b85);
  static const inkFaint = Color(0xff93a1b8);

  static const ok = Color(0xff1a7f37);
  static const warn = Color(0xffe07b00);
  static const danger = Color(0xffd13438);

  static const LinearGradient hero = LinearGradient(
    colors: [deep, seed, accent],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
}

// ------------------------------------------------------------
//  انیمیشن ورود (fade + slide + scale) با تأخیر پلکانی
// ------------------------------------------------------------

class HFadeSlideIn extends StatefulWidget {
  const HFadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.delayMs = 60,
    this.durationMs = 420,
    this.offsetY = 24,
    this.offsetX = 0,
  });

  final Widget child;
  final int index;
  final int delayMs;
  final int durationMs;
  final double offsetY;
  final double offsetX;

  @override
  State<HFadeSlideIn> createState() => _HFadeSlideInState();
}

class _HFadeSlideInState extends State<HFadeSlideIn>
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
    final delay = math.min(widget.index * widget.delayMs, 420);
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
    child: widget.child,
    builder: (_, child) {
      final t = _curve.value.clamp(0.0, 1.0);
      return Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(
            widget.offsetX * (1 - t),
            widget.offsetY * (1 - t),
          ),
          child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
        ),
      );
    },
  );
}

// ------------------------------------------------------------
//  فشار دادن کارت — مقیاس نرم با فنر
// ------------------------------------------------------------

class HPressable extends StatefulWidget {
  const HPressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<HPressable> createState() => _HPressableState();
}

class _HPressableState extends State<HPressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => _set(true),
    onTapUp: (_) => _set(false),
    onTapCancel: () => _set(false),
    onTap: widget.onTap,
    child: AnimatedScale(
      scale: _down ? widget.scale : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}

// ------------------------------------------------------------
//  شمارش تدریجی عدد
// ------------------------------------------------------------

class HCountUp extends StatelessWidget {
  const HCountUp({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 900),
    this.decimals = 0,
  });

  final double value;
  final TextStyle? style;
  final Duration duration;
  final int decimals;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey<double>(value),
    tween: Tween<double>(begin: 0, end: value),
    duration: duration,
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => Text(
      Fa.digits(v.toStringAsFixed(decimals)),
      style: style,
    ),
  );
}

// ------------------------------------------------------------
//  Sparkline با رسم تدریجی
// ------------------------------------------------------------

class HSparkline extends StatefulWidget {
  const HSparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 40,
    this.width = 260,
    this.strokeWidth = 2.2,
  });

  final List<double> values;
  final Color color;
  final double height;
  final double width;
  final double strokeWidth;

  @override
  State<HSparkline> createState() => _HSparklineState();
}

class _HSparklineState extends State<HSparkline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void didUpdateWidget(covariant HSparkline old) {
    super.didUpdateWidget(old);
    if (old.values != widget.values) {
      _c
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.values.length < 2) {
      return SizedBox(height: widget.height, width: widget.width);
    }
    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (_, _) => CustomPaint(
          painter: _SparkPainter(
            values: widget.values,
            color: widget.color,
            progress: _curve.value,
            strokeWidth: widget.strokeWidth,
          ),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.values,
    required this.color,
    required this.progress,
    required this.strokeWidth,
  });

  final List<double> values;
  final Color color;
  final double progress;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final mn = values.reduce(math.min);
    final mx = values.reduce(math.max);
    final range = (mx - mn).abs() < 0.0001 ? 1.0 : (mx - mn);
    const pad = 4.0;
    final usable = size.height - pad * 2;

    final pts = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          pad + i * (size.width - pad * 2) / (values.length - 1),
          size.height - pad - ((values[i] - mn) / range) * usable,
        ),
    ];

    // مسیر هموار با منحنی کاتمول-رام ساده‌شده
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);

    // ناحیهٔ زیر منحنی
    final area = Path.from(path)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    final fill = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
      );
    canvas.save();
    canvas.clipPath(_clipProgress(area, size, progress));
    canvas.drawPath(area, fill);
    canvas.restore();

    // خط با رسم تدریجی
    final metrics = path.computeMetrics().toList();
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    for (final m in metrics) {
      canvas.drawPath(m.extractPath(0, m.length * progress), linePaint);
    }

    // نقطهٔ پایانی
    if (progress > 0.9) {
      final a = ((progress - 0.9) / 0.1).clamp(0.0, 1.0);
      canvas.drawCircle(
        pts.last,
        strokeWidth * 1.1 + 3,
        Paint()..color = color.withValues(alpha: 0.22 * a),
      );
      canvas.drawCircle(pts.last, strokeWidth * 1.3, Paint()..color = color);
      canvas.drawCircle(
        pts.last,
        strokeWidth * 0.7,
        Paint()..color = Colors.white.withValues(alpha: a),
      );
    }
  }

  Path _clipProgress(Path area, Size size, double p) => Path.combine(
    PathOperation.intersect,
    area,
    Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width * p, size.height)),
  );

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.values != values;
}

// ------------------------------------------------------------
//  هالهٔ نبضی — برای زنگولهٔ اعلان و کارت‌های فوری
// ------------------------------------------------------------

class HPulseHalo extends StatefulWidget {
  const HPulseHalo({
    super.key,
    required this.child,
    required this.color,
    this.active = true,
    this.minScale = 1.0,
    this.maxScale = 2.1,
    this.period = const Duration(milliseconds: 1500),
  });

  final Widget child;
  final Color color;
  final bool active;
  final double minScale;
  final double maxScale;
  final Duration period;

  @override
  State<HPulseHalo> createState() => _HPulseHaloState();
}

class _HPulseHaloState extends State<HPulseHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant HPulseHalo old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (_, child) {
      if (!widget.active) return child!;
      final t = _c.value;
      final scale = widget.minScale + (widget.maxScale - widget.minScale) * t;
      return Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: scale,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.45 * (1 - t)),
              ),
            ),
          ),
          child!,
        ],
      );
    },
  );
}

// ------------------------------------------------------------
//  اسکلت shimmer
// ------------------------------------------------------------

class HShimmer extends StatefulWidget {
  const HShimmer({
    super.key,
    required this.width,
    required this.height,
    this.radius = 12,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<HShimmer> createState() => _HShimmerState();
}

class _HShimmerState extends State<HShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        gradient: LinearGradient(
          begin: Alignment(-1 + 2 * _c.value, 0),
          end: Alignment(1 + 2 * _c.value, 0),
          colors: const [
            Color(0xffe9eef7),
            Color(0xfff7f9fd),
            Color(0xffe9eef7),
          ],
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------
//  نقطه‌های راهنمای کاروسل
// ------------------------------------------------------------

class HDots extends StatelessWidget {
  const HDots({
    super.key,
    required this.count,
    required this.index,
    this.color = HomeColors.seed,
  });

  final int count;
  final double index;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < count; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          height: 5,
          width: 5 + 13 * (1 - ((index - i).abs()).clamp(0.0, 1.0)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            color: color.withValues(
              alpha: 0.22 + 0.78 * (1 - ((index - i).abs()).clamp(0.0, 1.0)),
            ),
          ),
        ),
    ],
  );
}
