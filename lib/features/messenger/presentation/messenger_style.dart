// ============================================================
//  رنگ‌ها و اجزای مشترک پیام‌رسان
// ============================================================

import 'package:flutter/material.dart';

class MessengerColors {
  static const brand = Color(0xff1f8f7a);
  static const brandDeep = Color(0xff0f6b5c);
  static const bg = Color(0xffeef4f6);
  static const surface = Colors.white;
  static const ink = Color(0xff122033);
  static const inkSoft = Color(0xff5b6b7c);
  static const inkFaint = Color(0xff8c9aa9);
  static const line = Color(0xffe1e9ee);
  static const unreadTint = Color(0xffeaf7f3);
  static const bubbleMine = Color(0xffd9f4e8);
  static const bubbleOther = Colors.white;
  static const danger = Color(0xffd13438);
  static const record = Color(0xffe2445c);

  static const brandGradient = LinearGradient(
    colors: [brand, brandDeep],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
}

/// آواتار حرفی با نشان آنلاین
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.text,
    this.color,
    this.size = 44,
    this.online = false,
  });

  final String text;
  final Color? color;
  final double size;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final c = color ?? MessengerColors.brand;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c, Color.lerp(c, Colors.black, 0.22)!],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(size * 0.34),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.36,
              ),
            ),
          ),
          if (online)
            PositionedDirectional(
              end: -1,
              bottom: -1,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  color: const Color(0xff22c55e),
                  shape: BoxShape.circle,
                  border: Border.all(color: MessengerColors.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
