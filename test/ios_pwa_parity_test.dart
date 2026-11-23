import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/pwa/pwa_bridge.dart';
import 'package:forough_mobile/core/pwa/pwa_settings_sheet.dart';
import 'package:forough_mobile/core/utils/web_files.dart';

void main() {
  group('iOS Safari PWA & Web Files Parity', () {
    test('mimeOf resolves standard iPhone Share Sheet MIME types', () {
      expect(mimeOf('invoice_104.pdf'), 'application/pdf');
      expect(
        mimeOf('Products-Template.xlsx'),
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      expect(mimeOf('reorder_report.csv'), 'text/csv;charset=utf-8');
      expect(mimeOf('invoice_A4.html'), 'text/html;charset=utf-8');
      expect(mimeOf('voice_123.m4a'), 'audio/mp4');
      expect(mimeOf('photo.jpeg'), 'image/jpeg');
    });

    test('PwaPushStatus parses APNs / VAPID state payloads accurately', () {
      final s1 = PwaPushStatus.fromJson({
        'supported': true,
        'enabled': true,
        'message': 'اعلان فعال است.',
      });
      expect(s1.supported, isTrue);
      expect(s1.enabled, isTrue);
      expect(s1.needsStandaloneIos, isFalse);

      final s2 = PwaPushStatus.fromJson({
        'supported': false,
        'enabled': false,
        'needsStandaloneIos': true,
        'message': 'نیاز به Add to Home Screen دارد.',
      });
      expect(s2.supported, isFalse);
      expect(s2.needsStandaloneIos, isTrue);
    });

    testWidgets(
      'PwaSettingsSheet renders cleanly on 360px iPhone SE width without overflow',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 740));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: PwaSettingsSheet(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('نسخهٔ وب‌اپلیکیشن آیفون'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Add to Home Screen'),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
