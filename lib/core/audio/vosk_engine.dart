/// نقطهٔ دسترسی واحد موتور Vosk اندروید:
/// - IO: پلاگین واقعی (prewarm گرون‌قیمت → یک‌بار در استارتاپ انجام می‌شود)
/// - وب/سایر: پیادهٔ هم‌شکل غیرفعال
export 'vosk_engine_stub.dart'
    if (dart.library.io) 'vosk_engine_io.dart';
