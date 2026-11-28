/// لایهٔ دسترسی به موتور Vosk:
/// - IO (اندروید/iOS/دسکتاپ): خود پلاگین واقعی Vosk
/// - وب: API هم‌شکل ولی غیرفعال (مسیر وب از موتور مرورگر استفاده می‌کند)
export 'vosk_service_stub.dart'
    if (dart.library.io) 'vosk_service_io.dart';
