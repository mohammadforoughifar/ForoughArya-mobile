// ============================================================
//  بوم امضای دستی — برای «تایید/رد ورژن» با امضا
//  خروجی: PNG base64 به شکل data URI برای `signatureDataUrl`
// ============================================================

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../shop/presentation/shop_style.dart';

class DocSignaturePad extends StatefulWidget {
  const DocSignaturePad({
    super.key,
    this.height = 150,
    this.onChanged,
  });

  final double height;

  /// هر بار تغییر: آیا امضا خالی است؟
  final ValueChanged<bool>? onChanged;

  @override
  State<DocSignaturePad> createState() => DocSignaturePadState();
}

class DocSignaturePadState extends State<DocSignaturePad> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _current = [];
  List<int>? _png;

  bool get isEmpty => _strokes.isEmpty && _current.isEmpty;

  void clear() {
    setState(() {
      _strokes.clear();
      _current = [];
      _png = null;
    });
    widget.onChanged?.call(true);
  }

  Future<void> _export() async {
    if (isEmpty) return;
    final size = context.size;
    if (size == null) return;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final s in _strokes) {
      if (s.length < 2) continue;
      final path = Path()..moveTo(s.first.dx, s.first.dy);
      for (final p in s.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
    final img = await recorder.endRecording().toImage(
      size.width.round(),
      size.height.round(),
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return;
    _png = data.buffer.asUint8List();
  }

  /// امضا به‌صورت data URI برای ارسال به سرور
  Future<String> toDataUrl() async {
    await _export();
    final png = _png;
    if (png == null || png.isEmpty) return '';
    return 'data:image/png;base64,${base64Encode(png)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.draw_rounded,
              size: 14,
              color: ShopColors.seed,
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'امضای دستی (اختیاری)',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 26),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                foregroundColor: ShopColors.inkFaint,
              ),
              onPressed: clear,
              icon: const Icon(Icons.refresh_rounded, size: 13),
              label: const Text('پاک کردن', style: TextStyle(fontSize: 9)),
            ),
          ],
        ),
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ShopColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: GestureDetector(
            onPanStart: (d) => setState(() {
              _current = [d.localPosition];
              _png = null;
            }),
            onPanUpdate: (d) => setState(() {
              _current = [..._current, d.localPosition];
            }),
            onPanEnd: (_) => setState(() {
              if (_current.isNotEmpty) _strokes.add(_current);
              _current = [];
            }),
            child: CustomPaint(
              painter: _PadPainter(strokes: _strokes, current: _current),
              size: Size.infinite,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'امضا با انگشت روی کادر سفید رسم می‌شود و همراه کاربر و زمان تایید در سرور ثبت می‌گردد.',
            style: TextStyle(
              fontSize: 8.5,
              height: 1.8,
              color: ShopColors.inkFaint,
            ),
          ),
        ),
      ],
    );
  }
}

class _PadPainter extends CustomPainter {
  _PadPainter({required this.strokes, required this.current});

  final List<List<Offset>> strokes;
  final List<Offset> current;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xff111827)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    void draw(List<Offset> s) {
      if (s.length < 2) {
        if (s.length == 1) canvas.drawCircle(s.first, 1.2, paint);
        return;
      }
      final path = Path()..moveTo(s.first.dx, s.first.dy);
      for (final p in s.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }

    for (final s in strokes) {
      draw(s);
    }
    draw(current);
  }

  @override
  bool shouldRepaint(covariant _PadPainter old) => true;
}

/// مشخصات دستگاه برای ثبت در تایید — شماره بیلد اپ
const String kDeviceInfoFa = 'FPA-Mobile android app';
