// آزمون فاز ۹-د «مدیریت سرورها» و «مدیریت آی‌پی»
// — آینه‌بودن مدل‌ها، اعتبارسنجی‌ها و متن‌های فارسیِ وب

import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/features/it_assets/models/ipam_models.dart';
import 'package:forough_mobile/features/it_assets/models/server_models.dart';

void main() {
  group('مدیریت سرورها — مدل', () {
    test('ServerRow فیلدهای کنترلر را می‌خواند و متن‌های وب را می‌سازد', () {
      final s = ServerRow.fromJson({
        'id': 7,
        'companyId': 2,
        'name': 'SRV-DB-01',
        'manufacturer': 'HPE',
        'model': 'DL380 Gen11',
        'serialNumber': 'CZ123',
        'iloAddress': '10.0.0.15',
        'iloPort': 8443,
        'credentialId': 4,
        'criticality': 'Critical',
        'status': 'Maintenance',
        'rack': 'RACK-A',
        'rackUnit': 12,
        'monitoringEnabled': true,
        'monitoringIntervalMinutes': 30,
        'certPinned': true,
        'openAlertCount': 3,
        'lastHealthStatus': 'Critical',
        'maintenanceUntil': '2099-01-01T00:00:00',
      });

      expect(s.iloLabel, '10.0.0.15:8443');
      expect(s.rackTitle, 'RACK-A / U12');
      expect(s.subtitleLine, 'HPE · بحرانی · تعمیرات');
      expect(s.inMaintenance, isTrue);
      expect(s.modelCell, 'DL380 Gen11');
      expect(s.openAlertCount, 3);
    });

    test('بدون رک و سریال، متن‌های پیش‌فرض وب', () {
      final s = ServerRow.fromJson({'name': 'X', 'iloAddress': 'h'});
      expect(s.rackTitle, 'بدون رک');
      expect(s.serialCell, 'بدون سریال');
      expect(s.iloPort, 443);
      expect(s.monitoringIntervalMinutes, 15);
      expect(s.criticality, 'Normal');
      expect(s.status, 'Active');
    });

    test('HealthTitle / IsHealthy / IsProblem عیناً وب', () {
      expect(ServerHealth.title('OK'), 'سالم');
      expect(ServerHealth.title('Warning'), 'هشدار');
      expect(ServerHealth.title('Critical'), 'بحرانی');
      expect(ServerHealth.title(null), 'بررسی نشده');
      expect(ServerHealth.isHealthy('ok'), isTrue);
      expect(ServerHealth.isProblem('warning'), isTrue);
      expect(ServerHealth.isProblem('critical'), isTrue);
      expect(ServerHealth.isProblem('ok'), isFalse);
    });

    test('برچسب‌های اهمیت، چرخهٔ عمر و انواع قطعه', () {
      expect(criticalityTitle('Low'), 'کم');
      expect(criticalityTitle('High'), 'زیاد');
      expect(criticalityTitle('weird'), 'عادی');
      expect(serverStatusTitle('Standby'), 'رزرو');
      expect(serverStatusTitle('Retired'), 'بازنشسته');
      expect(componentTypeTitle('PowerSupply'), 'پاور');
      expect(componentTypeTitle('Storage'), 'کنترلر ذخیره‌سازی');
      expect(alertCategoryTitle('Connection'), 'ارتباط iLO');
      expect(alertCategoryTitle(null), 'سلامت سخت‌افزار');
    });

    test('اعتبارسنجی فرم — همان ترتیب و پیام‌های سرور', () {
      const ok = ServerSaveRequest(
        name: 'SRV',
        iloAddress: 'ilo.local',
        iloPort: 443,
      );
      expect(validateServerForm(ok), isNull);

      expect(
        validateServerForm(const ServerSaveRequest(iloAddress: 'x')),
        'نام سرور را وارد کنید.',
      );
      expect(
        validateServerForm(const ServerSaveRequest(name: 'a')),
        'آدرس iLO را وارد کنید.',
      );
      expect(
        validateServerForm(
          const ServerSaveRequest(name: 'a', iloAddress: 'HTTP://ilo'),
        ),
        'برای امنیت، آدرس iLO باید با HTTPS باشد.',
      );
      expect(
        validateServerForm(
          const ServerSaveRequest(name: 'a', iloAddress: 'i', iloPort: 0),
        ),
        'پورت iLO باید بین ۱ تا ۶۵۵۳۵ باشد.',
      );
      expect(
        validateServerForm(
          const ServerSaveRequest(
            name: 'a',
            iloAddress: 'i',
            criticality: 'X',
          ),
        ),
        'درجهٔ اهمیت نامعتبر است.',
      );
      expect(
        validateServerForm(
          const ServerSaveRequest(name: 'a', iloAddress: 'i', status: 'X'),
        ),
        'وضعیت چرخهٔ عمر نامعتبر است.',
      );
      expect(
        validateServerForm(
          const ServerSaveRequest(name: 'a', iloAddress: 'i', rackUnit: 0),
        ),
        'شمارهٔ U رک باید بین ۱ تا ۱۰۰ باشد.',
      );
      expect(
        validateServerForm(
          const ServerSaveRequest(
            name: 'a',
            iloAddress: 'i',
            monitoringIntervalMinutes: 2,
          ),
        ),
        'فاصلهٔ پایش باید بین ۵ تا ۱۴۴۰ دقیقه باشد.',
      );
      expect(
        validateServerForm(
          const ServerSaveRequest(
            name: 'a',
            iloAddress: 'i',
            monitoringEnabled: true,
          ),
        ),
        'برای فعال‌سازی پایش خودکار، Credential iLO را انتخاب کنید.',
      );
      expect(
        validateServerForm(
          const ServerSaveRequest(
            name: 'a',
            iloAddress: 'i',
            alertNotificationsEnabled: true,
          ),
        ),
        'برای فعال‌سازی اعلان هشدار، مسئول سرور را انتخاب کنید.',
      );
      expect(
        validateServerForm(
          ServerSaveRequest(
            name: 'a',
            iloAddress: 'i',
            maintenanceNote: 'x' * 501,
          ),
        ),
        'توضیح تعمیرات حداکثر ۵۰۰ کاراکتر است.',
      );
    });

    test('ServerSaveRequest همان کلیدهای SaveDto را می‌فرستد', () {
      final j = const ServerSaveRequest(
        companyId: 3,
        name: 'SRV',
        iloAddress: 'ilo',
        iloPort: 443,
      ).toJson();
      expect(j['companyId'], 3);
      expect(j['iloPort'], 443);
      expect(j['criticality'], 'Normal');
      expect(j['status'], 'Active');
      expect(j['monitoringIntervalMinutes'], 15);
      expect(j.containsKey('manufacturer'), isTrue);
      expect(j.containsKey('alertNotificationsEnabled'), isTrue);
    });

    test('هشدار: وضعیت تأیید و برچسب دسته', () {
      final a = ServerAlertRow.fromJson({
        'id': 1,
        'serverName': 'SRV',
        'category': 'HardwareEvent',
        'severity': 'Critical',
        'message': 'Fan failure',
        'status': 'Acknowledged',
        'acknowledgedByName': 'رضا',
      });
      expect(a.categoryFa, 'رخداد iLO');
      expect(a.isCritical, isTrue);
      expect(a.statusFa, 'تأیید: رضا');
      expect(
        ServerAlertRow.fromJson({'status': 'Open', 'category': 'x'}).statusFa,
        'باز',
      );
      expect(
        ServerAlertRow.fromJson({'status': 'Resolved'}).statusFa,
        'رفع شده',
      );
    });

    test('سخت‌افزار: شمارش سلامت و سلول مقدار', () {
      final hw = ServerHardware.fromJson({
        'capturedAt': '2026-01-01T10:00:00',
        'components': [
          {
            'componentType': 'Fan',
            'name': 'Fan 1',
            'health': 'OK',
            'reading': '30%',
          },
          {
            'componentType': 'PowerSupply',
            'name': 'PSU 1',
            'health': 'Critical',
            'state': 'Absent',
          },
        ],
        'events': [
          {'severity': 'Warning', 'message': 'Temp high', 'origin': 'iLO'},
        ],
      });
      expect(hw.countHealth('OK'), 1);
      expect(hw.countHealth('Critical'), 1);
      expect(hw.components.first.typeFa, 'فن');
      expect(hw.components.first.valueCell, '30%');
      expect(hw.components.last.valueCell, 'Absent');
      expect(hw.components.last.modelCell, '—');
      expect(hw.events.length, 1);
      expect(hw.isEmpty, isFalse);
    });

    test('گواهی iLO: اثر انگشت با «:» و انقضا', () {
      final c = IloCertificate.fromJson({
        'thumbprint': 'aabbccdd',
        'subject': 'CN=ilo',
        'notAfter': '2000-01-01T00:00:00',
        'systemTrusted': false,
        'selfSigned': true,
      });
      expect(c.fingerprint, 'AA:BB:CC:DD');
      expect(c.expired, isTrue);
      final check = IloCertificateCheck.fromJson({
        'certificate': {'thumbprint': 'aa'},
        'pinned': {'thumbprint': 'aabb', 'trustedByName': 'مریم'},
        'matchesPin': false,
        'canTrust': true,
      });
      expect(check.canTrust, isTrue);
      expect(check.matchesPin, isFalse);
      expect(check.pinned!.fingerprint, 'AA:BB');
      expect(check.pinned!.trustedByName, 'مریم');
    });

    test('agoFa مثل Ago() وب', () {
      final now = DateTime(2026, 5, 1, 12, 0);
      expect(agoFa(now.subtract(const Duration(seconds: 20)), now: now), 'همین الان');
      expect(agoFa(now.subtract(const Duration(minutes: 7)), now: now), '۷ دقیقه پیش'.replaceAll('۷', '7'));
      expect(agoFa(now.subtract(const Duration(hours: 5)), now: now), '5 ساعت پیش');
      expect(agoFa(now.subtract(const Duration(days: 3)), now: now), '3 روز پیش');
      expect(agoFa(null), '—');
    });
  });

  group('مدیریت آی‌پی — مدل و محاسبات', () {
    test('parseCidr و hostRange', () {
      final p = parseCidr('192.168.30.0/24')!;
      expect(p.$2, 24);
      expect(ipFromNum(p.$1), '192.168.30.0');
      final (f, l) = hostRange(p.$1, 24);
      expect(ipFromNum(f), '192.168.30.1');
      expect(ipFromNum(l), '192.168.30.254');
      expect(parseCidr('bogus'), isNull);
      expect(parseCidr('192.168.1.0/33'), isNull);
      expect(parseIpNum('256.1.1.1'), isNull);
    });

    test('cidrHint همان متن وب', () {
      expect(
        cidrHint('نامعتبر'),
        'مثال: 192.168.30.0/24 (۲۵۴ آدرس)',
      );
      expect(cidrHint('10.0.0.0/16'), 'طول پیشوند باید بین /22 تا /30 باشد.');
      expect(cidrHint('192.168.30.0/24'), contains('192.168.30.1'));
      expect(cidrHint('192.168.30.0/24'), contains('254'));
    });

    test('اعتبارسنجی فرم رنج — پیام‌های دقیق سرور', () {
      const ok = IpSubnetSaveRequest(
        companyId: 1,
        name: 'اداری',
        cidr: '192.168.30.0/24',
        gateway: '192.168.30.1',
        vlan: 30,
        autoScanMinutes: 60,
      );
      expect(validateSubnetForm(ok), isNull);

      expect(
        validateSubnetForm(const IpSubnetSaveRequest(cidr: '192.168.30.0/24')),
        'نام رنج را وارد کنید.',
      );
      expect(
        validateSubnetForm(const IpSubnetSaveRequest(name: 'a', cidr: 'bad')),
        'رنج CIDR نامعتبر است.',
      );
      expect(
        validateSubnetForm(
          const IpSubnetSaveRequest(name: 'a', cidr: '10.0.0.0/16'),
        ),
        'طول پیشوند باید بین /22 تا /30 باشد.',
      );
      expect(
        validateSubnetForm(
          const IpSubnetSaveRequest(
            name: 'a',
            cidr: '192.168.30.0/24',
            gateway: '1.2.3.4',
          ),
        ),
        'گیت‌وی باید داخل همین رنج باشد.',
      );
      expect(
        validateSubnetForm(
          const IpSubnetSaveRequest(
            name: 'a',
            cidr: '192.168.30.0/24',
            gateway: 'bad',
          ),
        ),
        'آدرس گیت‌وی نامعتبر است.',
      );
      expect(
        validateSubnetForm(
          const IpSubnetSaveRequest(
            name: 'a',
            cidr: '192.168.30.0/24',
            vlan: 5000,
          ),
        ),
        'شمارهٔ VLAN باید بین ۱ تا ۴۰۹۴ باشد.',
      );
      expect(
        validateSubnetForm(
          const IpSubnetSaveRequest(
            name: 'a',
            cidr: '192.168.30.0/24',
            autoScanMinutes: 3,
          ),
        ),
        'فاصلهٔ اسکن خودکار باید بین ۵ تا ۱۴۴۰ دقیقه باشد (۰ = خاموش).',
      );
    });

    test('parseDhcpRange دو حالت وب را می‌فهمد', () {
      final (a1, b1) = parseDhcpRange('192.168.30.100-192.168.30.200');
      expect(ipFromNum(a1), '192.168.30.100');
      expect(ipFromNum(b1), '192.168.30.200');
      final (a2, b2) = parseDhcpRange('192.168.30.100-200');
      expect(ipFromNum(a2), '192.168.30.100');
      expect(ipFromNum(b2), '192.168.30.200');
      expect(parseDhcpRange(''), (0, 0));
      expect(parseDhcpRange('junk'), (0, 0));
    });

    test('IpHost: برچسب وضعیت شبکه مثل وب', () {
      expect(
        IpHost.fromJson({'ip': '10.0.0.5', 'state': 'registered', 'alive': true})
            .stateLabel,
        'ثبت‌شده · روشن',
      );
      expect(
        IpHost.fromJson({'ip': '10.0.0.5', 'state': 'registered'}).stateLabel,
        'ثبت‌شده · خاموش',
      );
      expect(
        IpHost.fromJson({'ip': '10.0.0.5', 'state': 'unregistered'}).stateLabel,
        'اشغال بدون شناسنامه',
      );
      expect(
        IpHost.fromJson({'ip': '10.0.0.5', 'state': 'free'}).stateLabel,
        'خالی',
      );
    });

    test('IpHost: شناسنامه‌ها و رزرو دستی جدا می‌شوند', () {
      final h = IpHost.fromJson({
        'ip': '10.0.0.9',
        'num': 167772169,
        'state': 'unregistered',
        'owners': [
          {'source': 'Reserved', 'title': 'رزرو من'},
          {'source': 'System', 'sourceTitle': 'شناسنامه سیستم', 'title': 'PC-01'},
        ],
        'reserved': {'title': 'رزرو من', 'type': 'Printer', 'owner': 'واحد فنی'},
      });
      expect(h.owners.length, 2);
      expect(h.registryOwners.length, 1);
      expect(h.registryOwners.first.sourceTitle, 'شناسنامه سیستم');
      expect(h.reserved!.typeFa, 'پرینتر');
    });

    test('IpamStats درصد مصرف', () {
      final s = IpamStats.fromJson({
        'total': 254,
        'registered': 100,
        'registeredOnline': 80,
        'registeredOffline': 20,
        'unregistered': 54,
        'free': 100,
      });
      expect(s.total, 254);
      expect(s.usedPct, closeTo(60.6, 0.1));
      expect(pctOf(0, 0), 0);
    });

    test('IpSubnetRow: درصدها و اسکن', () {
      final s = IpSubnetRow.fromJson({
        'id': 3,
        'name': 'اداری',
        'cidr': '192.168.30.0/24',
        'total': 254,
        'registered': 127,
        'unregistered': 0,
        'free': 127,
        'scanning': true,
      });
      expect(s.regPct, 50);
      expect(s.scanning, isTrue);
    });

    test('IpamMap: نقشه، آمار و اسکن', () {
      final m = IpamMap.fromJson({
        'subnet': {
          'id': 1,
          'name': 'رنج',
          'cidr': '192.168.30.0/24',
          'networkNum': 3232241664,
          'prefix': 24,
          'mask': '255.255.255.0',
          'broadcast': '192.168.30.255',
          'lastScanDurationMs': 2400,
        },
        'stats': {'total': 254, 'free': 200},
        'hosts': [
          {'ip': '192.168.30.5', 'num': 1, 'state': 'free'},
          {'ip': '192.168.30.9', 'num': 2, 'state': 'registered', 'conflict': true},
        ],
        'scan': {'running': true, 'total': 254, 'scanned': 100, 'phase': 'ping'},
      });
      expect(m.subnet.mask, '255.255.255.0');
      expect(m.subnet.durationFa, '2.4');
      expect(m.problemCount, 1);
      expect(m.byNum[2]!.conflict, isTrue);
      expect(m.scan!.running, isTrue);
      expect(m.scan!.phase, 'ping');
      expect(m.subnet.neverScanned, isTrue);
    });

    test('نتیجهٔ probe و برچسب روش تشخیص', () {
      final p = IpProbeResult.fromJson({
        'alive': true,
        'method': 'arp',
        'mac': 'AA:BB',
      });
      expect(p.alive, isTrue);
      expect(p.methodFa, 'ARP — پینگ بسته است');
      expect(probeMethodFa('ping'), 'پینگ');
      expect(probeMethodFa('tcp'), 'پورت باز');
      expect(probeMethodFa(null), '—');
    });

    test('انواع رزرو و گزینه‌های اسکن خودکار', () {
      expect(reservedTypeFa('Camera'), 'دوربین');
      expect(reservedTypeFa('Unknown'), '');
      expect(kReservedTypes.length, 10);
      expect(kAutoScanOptions.first.key, 0);
      expect(kAutoScanOptions.first.value, 'خاموش (فقط دستی)');
      expect(kAutoScanOptions.last.value, 'روزی یک بار');
    });

    test('IpReserveRequest کلیدهای ReserveDto', () {
      final j = const IpReserveRequest(
        ip: '10.0.0.5',
        title: 'دوربین',
        type: 'Camera',
      ).toJson();
      expect(j['ip'], '10.0.0.5');
      expect(j['type'], 'Camera');
      expect(j.containsKey('note'), isTrue);
    });
  });
}
