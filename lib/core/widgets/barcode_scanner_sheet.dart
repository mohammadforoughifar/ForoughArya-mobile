import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// شیت اسکن زندهٔ بارکد و QR با دوربین گوشی
/// قابل استفاده در فرم خرید، فرم فروش، پیش‌فاکتور و تعریف کالا.
Future<String?> showBarcodeScannerSheet(
  BuildContext context, {
  String title = 'اسکن بارکد کالا',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BarcodeScannerSheet(title: title),
  );
}

class _BarcodeScannerSheet extends StatefulWidget {
  const _BarcodeScannerSheet({required this.title});

  final String title;

  @override
  State<_BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<_BarcodeScannerSheet> {
  late final MobileScannerController _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    autoZoom: true,
  );
  bool _handled = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final b in capture.barcodes) {
      final raw = (b.rawValue ?? b.displayValue ?? '').trim();
      if (raw.isNotEmpty) {
        _handled = true;
        HapticFeedback.mediumImpact();
        if (mounted) {
          Navigator.of(context).pop(raw);
        }
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.72;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: sheetHeight < 420 ? 420 : sheetHeight,
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // نوار بالایی شیت اسکنر
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 14, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Color(0xFF34D399),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<MobileScannerState>(
                    valueListenable: _ctrl,
                    builder: (_, state, _) {
                      final torchOn = state.torchState == TorchState.on;
                      final torchAvail =
                          state.torchState != TorchState.unavailable;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (torchAvail)
                            IconButton(
                              onPressed: () => _ctrl.toggleTorch(),
                              tooltip: 'چراغ‌قوه',
                              icon: Icon(
                                torchOn
                                    ? Icons.flash_on_rounded
                                    : Icons.flash_off_rounded,
                                color: torchOn
                                    ? const Color(0xFFFBBF24)
                                    : Colors.white70,
                                size: 21,
                              ),
                            ),
                          IconButton(
                            onPressed: () => _ctrl.switchCamera(),
                            tooltip: 'تغییر دوربین',
                            icon: const Icon(
                              Icons.cameraswitch_rounded,
                              color: Colors.white70,
                              size: 21,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'بستن',
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            // پیش‌نمایش زنده دوربین و کادر راهنمای بارکد
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _ctrl,
                    tapToFocus: true,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) {
                      final msg = switch (error.errorCode) {
                        MobileScannerErrorCode.permissionDenied =>
                          'دسترسی به دوربین مجاز نیست. لطفاً مجوز دوربین را در تنظیمات گوشی فعال کنید.',
                        MobileScannerErrorCode.unsupported =>
                          'دوربین در این دستگاه پشتیبانی نمی‌شود.',
                        _ => 'خطا در راه‌اندازی دوربین: ${error.errorDetails?.message ?? error.errorCode.name}',
                      };
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.no_photography_rounded,
                                color: Color(0xFFF87171),
                                size: 42,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                msg,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  height: 1.7,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  // کادر هدف‌گیری وسط تصویر
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 260,
                        height: 155,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFF34D399),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 18,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'بارکد کالا را مقابل دوربین قرار دهید تا خودکار خوانده و ثبت شود',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
