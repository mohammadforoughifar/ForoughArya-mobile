// آزمون فاز ۹-الف «مدیریت سخت‌افزار» — داشبورد سخت‌افزار
// تضمین می‌کند مدل‌ها و گیت‌ها عیناً آینهٔ وب باشند.

import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/auth/auth_session.dart';
import 'package:forough_mobile/features/it_assets/data/it_perms.dart';
import 'package:forough_mobile/features/it_assets/models/hardware_models.dart';

AuthSession session(List<String> permissions, {String role = 'User'}) =>
    AuthSession(
      userId: 1,
      token: 't',
      username: 'u',
      role: role,
      displayName: 'کاربر',
      permissions: permissions,
    );

void main() {
  group('HardwareStats (آینهٔ HardwareStats سرور)', () {
    final json = {
      'sweeping': false,
      'lastSweepAt': '2026-11-10T12:30:00Z',
      'systemsTotal': 12,
      'systemsApproved': 10,
      'systemsPending': 2,
      'systemsAvgHealth': 74,
      'camerasTotal': 20,
      'camerasActiveFlag': 17,
      'nvrsTotal': 3,
      'nvrsActiveFlag': 3,
      'devices': [
        {'kind': 'system', 'id': 1, 'name': 'PC-1', 'ip': '10.0.0.5', 'extra': 'تأیید شده', 'online': true, 'health': 88},
        {'kind': 'system', 'id': 2, 'name': 'PC-2', 'ip': '', 'extra': 'در انتظار', 'online': null, 'health': 40},
        {'kind': 'system', 'id': 3, 'name': 'PC-3', 'ip': '10.0.0.7', 'extra': 'تأیید شده', 'online': false},
        {'kind': 'camera', 'id': 9, 'name': 'CAM-1', 'ip': '10.0.1.2', 'extra': 'طبقه ۱', 'online': true},
        {'kind': 'nvr', 'id': 5, 'name': 'NVR-1', 'ip': '10.0.1.10', 'extra': 'اتاق سرور', 'online': true},
      ],
    };

    test('فیلدها و تفکیک دستگاه‌ها بر اساس kind', () {
      final s = HardwareStats.fromJson(json);
      expect(s.systemsTotal, 12);
      expect(s.systemsPending, 2);
      expect(s.systemsAvgHealth, 74);
      expect(s.camerasTotal, 20);
      expect(s.camerasInactive, 3); // ۲۰ - ۱۷ — همان محاسبهٔ وب
      expect(s.nvrsTotal, 3);
      expect(s.systems.length, 3);
      expect(s.cameras.length, 1);
      expect(s.nvrs.length, 1);
      expect(s.sweeping, isFalse);
      expect(s.lastSweepAt, isNotNull);
    });

    test('گروه Sys وب: آنلاین / آفلاین / بدون IP', () {
      final s = HardwareStats.fromJson(json);
      final g = HardwareGroupStats.of(s.systems);
      expect(g.total, 3);
      expect(g.online, 1);
      expect(g.offline, 1);
      expect(g.noIp, 1);
      expect(g.onlinePercent, 33);
    });

    test('بدون IP متن «بدون IP» می‌شود (مثل وب)', () {
      final d = HardwareDevice.fromJson({'kind': 'nvr', 'name': 'N', 'ip': ''});
      expect(d.ipText, 'بدون IP');
      expect(d.online, isNull);
    });

    test('گروه خالی درصد صفر دارد', () {
      final g = HardwareGroupStats.of(const []);
      expect(g.total, 0);
      expect(g.onlinePercent, 0);
    });
  });

  group('ItStats و میله‌های نمودار (عیناً ItBars وب)', () {
    test('پاسخ GET api/itrequests/stats', () {
      final s = ItStats.fromJson({
        'total': 10,
        'completed': 5,
        'inProgress': 3,
        'waitingManager': 6,
        'newOnes': 4,
        'waitingDecision': 2,
        'waitingRequester': 1,
        'rejected': 1,
      });
      expect(s.waitingManager, 6);
      expect(s.newOnes, 4);
      expect(s.waitingDecision, 2);
    });

    test('برچسب‌ها، رنگ‌ها و حداقل ارتفاع ۴ درصد مثل وب', () {
      const s = ItStats(total: 10, completed: 5, inProgress: 1, waitingManager: 0, newOnes: 4, waitingDecision: 2);
      final bars = ItBar.from(s);
      expect(bars.map((b) => b.label), [
        'کل درخواست‌ها',
        'انجام‌شده',
        'در حال اجرا',
        'در انتظار مدیر واحد',
      ]);
      expect(bars[0].percent, 100);
      expect(bars[1].percent, 50);
      expect(bars[2].percent, 10);
      expect(bars[3].percent, 0);
      expect(bars[3].sub, 'جدید: 4 | تایید گزارش: 2');
      expect(bars[0].color, 0xff3f8cff);
    });

    test('مقدار کوچک‌تر از ۴ درصد به ۴ درصد بالا می‌رود', () {
      const s = ItStats(total: 100, completed: 1);
      final bars = ItBar.from(s);
      expect(bars[1].percent, 4);
    });
  });

  group('ItPerms — گیت‌های وب', () {
    test('داشبورد سخت‌افزار فقط با Dashboards.Hardware', () {
      expect(ItPerms(null).canSeeHardwareDashboard, isFalse);
      expect(
        ItPerms(session(['Dashboards.Hardware'])).canSeeHardwareDashboard,
        isTrue,
      );
      expect(ItPerms(session(['Dashboards.Management'])).canSeeHardwareDashboard, isFalse);
    });

    test('گروه مدیریت سیستم = CanSeeAny هفت ماژول وب', () {
      expect(ItPerms(session([])).canSeeAdminGroup, isFalse);
      for (final m in [
        'ItRequests',
        'SystemUsers',
        'CctvCameras',
        'CctvNvrs',
        'ItVault',
        'Servers',
        'Ipam',
      ]) {
        expect(
          ItPerms(session(['$m.Read'])).canSeeAdminGroup,
          isTrue,
          reason: m,
        );
      }
      expect(ItPerms(session(['Products.Read'])).canSeeAdminGroup, isFalse);
    });

    test('مدیر همیشه همهٔ گروه‌ها را می‌بیند', () {
      final p = ItPerms(session(const [], role: 'Admin'));
      expect(p.canSeeAdminGroup, isTrue);
      expect(p.serversCollect, isTrue);
      expect(p.vaultReveal, isTrue);
    });

    test('شرکت‌های راه‌دور فقط برای مدیر با ItRequests', () {
      expect(
        ItPerms(session(['ItRequests.Read'])).canSeeRemoteCompanies,
        isFalse,
      );
      expect(
        ItPerms(session(['ItRequests.Read'], role: 'Admin'))
            .canSeeRemoteCompanies,
        isTrue,
      );
    });

    test('مجوزهای دانه‌ای سرور/IPAM/گاوصندوق', () {
      final p = ItPerms(
        session([
          'Servers.Collect',
          'Ipam.Scan',
          'ItVault.Reveal',
          'ItVault.ViewLog',
        ]),
      );
      expect(p.serversCollect, isTrue);
      expect(p.serversDelete, isFalse);
      expect(p.ipamScan, isTrue);
      expect(p.ipamCreate, isFalse);
      expect(p.vaultReveal, isTrue);
      expect(p.vaultViewLog, isTrue);
      expect(p.vaultDelete, isFalse);
    });
  });
}
