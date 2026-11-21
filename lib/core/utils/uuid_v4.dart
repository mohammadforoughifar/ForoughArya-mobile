import 'dart:math';

/// تولید شناسهٔ یکتای RFC-4122 نسخهٔ ۴ بدون وابستگی به بستهٔ خارجی `uuid`
String generateUuidV4() {
  Random rng;
  try {
    rng = Random.secure();
  } catch (_) {
    rng = Random();
  }
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx

  String hex(int start, int end) => bytes
      .sublist(start, end)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
