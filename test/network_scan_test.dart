// آزمون فاز ۹-ز «اسکن شبکه» و «اسکن دوربین/NVR»
// — آینه‌بودن مدل‌ها، نگاشت JSON سرور و متن‌های فارسیِ وب

import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/features/it_assets/models/network_scan_models.dart';

void main() {
  group('اسکن سیستم‌ها — پاسخ شروع', () {
    test('jobId و رنج و آی‌پی محلی خوانده می‌شوند', () {
      final r = ScanStartResult.fromJson({
        'jobId': 'N7K2QW9A',
        'targetCount': 254,
        'range': '192.168.1.1-192.168.1.254',
        'localIp': '192.168.1.20',
      });
      expect(r.jobId, 'N7K2QW9A');
      expect(r.targetCount, 254);
      expect(r.range, '192.168.1.1-192.168.1.254');
      expect(r.localIp, '192.168.1.20');
    });

    test('پاسخ خالی امن است', () {
      final r = ScanStartResult.fromJson({});
      expect(r.jobId, '');
      expect(r.targetCount, 0);
    });
  });

  group('میزبان پیدا‌شده — ScanHost', () {
    test('روش TCP متن «TCP» و توضیح بسته‌بودن پینگ را می‌دهد', () {
      final h = ScanHost.fromJson({
        'ip': '192.168.1.15',
        'hostname': 'OFFICE-PC',
        'mac': 'AA:BB:CC:DD:EE:FF',
        'method': 'tcp',
      });
      expect(h.isTcp, isTrue);
      expect(h.methodLabel, 'TCP');
      expect(h.hostnameCell, 'OFFICE-PC');
      expect(h.macCell, 'AA:BB:CC:DD:EE:FF');
      expect(h.isRegistered, isFalse);
    });

    test('روش پیش‌فرض «پینگ» است', () {
      final h = ScanHost.fromJson({'ip': '10.0.0.5'});
      expect(h.method, 'ping');
      expect(h.methodLabel, 'پینگ');
      expect(h.hostnameCell, '—');
      expect(h.macCell, '—');
    });

    test('شناسنامهٔ ثبت‌شده با شماره نمایش داده می‌شود', () {
      final h = ScanHost.fromJson({
        'ip': '192.168.1.30',
        'systemInfoId': 412,
      });
      expect(h.isRegistered, isTrue);
      expect(h.systemInfoId, 412);
      expect(h.registeredLabel, 'ثبت‌شده (#412)');
    });

    test('systemInfoId صفر یا null یعنی ثبت‌نشده', () {
      expect(ScanHost.fromJson({'systemInfoId': 0}).isRegistered, isFalse);
      expect(ScanHost.fromJson({'systemInfoId': null}).isRegistered, isFalse);
    });
  });

  group('وضعیت اسکن — ScanStatus', () {
    test('پیشرفت، شمارش و میزبان‌ها خوانده می‌شوند', () {
      final st = ScanStatus.fromJson({
        'running': true,
        'progress': 72,
        'scanned': 183,
        'targetCount': 254,
        'foundCount': 9,
        'range': '192.168.1.1-192.168.1.254',
        'localIp': '192.168.1.20',
        'adapter': 'Ethernet',
        'elapsedMs': 12500,
        'hosts': [
          {'ip': '192.168.1.2', 'hostname': 'GW', 'method': 'ping'},
          {'ip': '192.168.1.9', 'method': 'tcp', 'systemInfoId': 77},
        ],
      });
      expect(st.running, isTrue);
      expect(st.progress, 72);
      expect(st.scanned, 183);
      expect(st.targetCount, 254);
      expect(st.foundCount, 9);
      expect(st.adapter, 'Ethernet');
      expect(st.elapsedFa, '12.5');
      expect(st.hosts.length, 2);
      expect(st.hosts[1].isTcp, isTrue);
      expect(st.hosts[1].systemInfoId, 77);
      expect(st.finished, isFalse);
    });

    test('خطای سرور جدا می‌شود', () {
      final st = ScanStatus.fromJson({
        'running': false,
        'error': 'هیچ کارت شبکه‌ی فعالی با آی‌پی مناسب پیدا نشد.',
      });
      expect(st.error, 'هیچ کارت شبکه‌ی فعالی با آی‌پی مناسب پیدا نشد.');
      expect(st.isEmptyAndDone, isFalse);
    });

    test('تمام‌شده و خالی ⇒ پیام «چیزی پیدا نشد» نمایش داده می‌شود', () {
      final st = ScanStatus.fromJson({
        'running': false,
        'scanned': 254,
        'targetCount': 254,
        'foundCount': 0,
      });
      expect(st.finished, isTrue);
      expect(st.isEmptyAndDone, isTrue);
      expect(st.error, isNull);
    });

    test('پاسخ نامعتبر به مقادیر پیش‌فرض نگاشت می‌شود', () {
      final st = ScanStatus.fromJson({'progress': null, 'hosts': null});
      expect(st.progress, 0);
      expect(st.hosts, isEmpty);
      expect(st.running, isFalse);
    });
  });

  group('دستگاه CCTV پیدا‌شده', () {
    CctvScanDevice dev({
      String kind = 'camera',
      String confidence = 'high',
      bool onvif = false,
      String vendor = '',
      String macVendor = '',
      List<int> ports = const [],
    }) => CctvScanDevice.fromJson({
      'ip': '192.168.1.64',
      'kind': kind,
      'vendor': vendor,
      'openPorts': ports,
      'rtspServer': 'Hikvision RTSP',
      'httpTitle': 'NVR Login',
      'onvif': onvif,
      'mac': 'C0:56:E3:11:22:33',
      'macVendor': macVendor,
      'confidence': confidence,
    });

    test('نوع دستگاه با همان سه برچسب وب نمایش داده می‌شود', () {
      expect(dev(kind: 'camera').kindLabel, '📷 دوربین');
      expect(dev(kind: 'nvr').kindLabel, '📼 NVR/DVR');
      expect(dev(kind: 'unknown').kindLabel, 'نامشخص');
    });

    test('دقت تشخیص: بالا / متوسط / نیاز به بررسی', () {
      expect(dev(confidence: 'high').confidenceLabel, 'بالا');
      expect(dev(confidence: 'medium').confidenceLabel, 'متوسط');
      expect(dev(confidence: 'low').confidenceLabel, 'نیاز به بررسی');
    });

    test('پورت‌های باز با «،» جدا می‌شوند', () {
      final d = dev(ports: [80, 554, 8000]);
      expect(d.portsCell, '80، 554، 8000');
      expect(dev().portsCell, '—');
    });

    test('ONVIF و MAC با برند در پرانتز', () {
      final d = dev(onvif: true, macVendor: 'Hikvision');
      expect(d.onvif, isTrue);
      expect(d.macCell, 'C0:56:E3:11:22:33 (Hikvision)');
      expect(dev().macCell, 'C0:56:E3:11:22:33');
    });

    test('برند و RTSP خالی «—» می‌شوند', () {
      final d = dev();
      expect(d.vendorCell, '—');
      expect(d.rtspCell, 'Hikvision RTSP');
    });

    test('پورت‌های نامعتبر حذف می‌شوند', () {
      final d = CctvScanDevice.fromJson({
        'openPorts': [80, null, 'x', 554],
      });
      expect(d.openPorts, [80, 554]);
    });
  });

  group('نتیجهٔ اسکن دوربین — CctvScanResult', () {
    test('خلاصهٔ «N آدرس بررسی شد در X ثانیه»', () {
      final r = CctvScanResult.fromJson({
        'localIp': '192.168.1.20',
        'subnet': '192.168.1.0/24',
        'scannedCount': 254,
        'elapsedMs': 21400,
        'devices': [
          {'ip': '192.168.1.64', 'kind': 'camera', 'confidence': 'high'},
          {'ip': '192.168.1.65', 'kind': 'nvr', 'confidence': 'medium'},
        ],
      });
      expect(r.localIp, '192.168.1.20');
      expect(r.subnet, '192.168.1.0/24');
      expect(r.summaryFa, '254 آدرس بررسی شد در 21.4 ثانیه');
      expect(r.devices.length, 2);
      expect(r.isEmpty, isFalse);
    });

    test('نتیجهٔ خالی پیام «دوربینی پیدا نشد» را فعال می‌کند', () {
      final r = CctvScanResult.fromJson({'devices': []});
      expect(r.isEmpty, isTrue);
      expect(r.scannedCount, 0);
    });
  });

  group('متن‌های ثابت وب', () {
    test('راهنما و مثال رنج دقیقاً همان وب است', () {
      expect(
        kScanRangeHint,
        'فرمت‌ها: پیشوند /24 — یا CIDR — یا بازه‌ی شروع-پایان',
      );
      expect(
        kScanRangePlaceholder,
        'مثال: 192.168.1 یا 192.168.1.0/24 یا 192.168.1.1-192.168.1.254',
      );
      expect(kScanRangeModes[0].value, 'خودکار — شبکه‌ی خودم');
      expect(kScanRangeModes[1].value, 'دستی — خودم می‌نویسم');
    });
  });
}
