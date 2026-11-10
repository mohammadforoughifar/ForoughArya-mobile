// آزمون فاز ۹-ج «سیستم‌های ثبت‌شده / شناسنامه / ثبت دستی / کاربران سیستم»
// — آینه‌بودن مدل‌ها، تحلیل‌ها و متن‌های فارسیِ وب

import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/features/it_assets/models/system_models.dart';

SystemInfoItem sys({
  int id = 1,
  String agentId = 'PC-01',
  bool approved = true,
  DateTime? at,
  int? companyId,
  int? departmentId,
  int? userId,
  String cpu = '',
  int ramGb = 0,
  String? ram,
  String? motherboard,
  String ip = '',
  String? os,
  int? health,
  String? pending,
}) => SystemInfoItem(
  id: id,
  agentId: agentId,
  isApproved: approved,
  receivedAt: at,
  companyId: companyId,
  departmentId: departmentId,
  userId: userId,
  cpu: cpu,
  totalRamGb: ramGb,
  ram: ram,
  motherboard: motherboard,
  ip: ip,
  osName: os,
  health: health,
  pendingPayloadJson: pending,
);

void main() {
  group('SystemInfoItem — شکل GET api/SystemInfo', () {
    test('همهٔ فیلدهای لیست خوانده می‌شوند', () {
      final it = SystemInfoItem.fromJson({
        'id': 12,
        'agentId': 'PC-ACC-01',
        'isApproved': true,
        'receivedAt': '2025-11-02T08:30:00',
        'userId': 7,
        'companyId': 3,
        'departmentId': 5,
        'pendingPayloadJson': null,
        'cpu': 'Intel Core i5-10500',
        'totalRamGb': 16,
        'ram': '16 GB — 2 ماژول',
        'motherboard': 'ASUS H510',
        'ip': '192.168.1.10',
        'osName': 'Windows 11 Pro',
        'health': 78,
      });
      expect(it.id, 12);
      expect(it.agentId, 'PC-ACC-01');
      expect(it.isApproved, isTrue);
      expect(it.receivedAt, isNotNull);
      expect(it.userId, 7);
      expect(it.companyId, 3);
      expect(it.departmentId, 5);
      expect(it.cpu, 'Intel Core i5-10500');
      expect(it.totalRamGb, 16);
      expect(it.ram, '16 GB — 2 ماژول');
      expect(it.motherboard, 'ASUS H510');
      expect(it.ip, '192.168.1.10');
      expect(it.osName, 'Windows 11 Pro');
      expect(it.health, 78);
      expect(it.hasPending, isFalse);
    });

    test('ستون RAM و CPU مثل وب', () {
      expect(sys(ramGb: 8).ramCell, '8 GB');
      expect(sys(ram: 'DDR4 8GB').ramCell, 'DDR4 8GB');
      expect(sys().ramCell, '—');
      expect(sys().cpuCell, '—');
      expect(sys(motherboard: '  ').motherboardCell, '—');
    });

    test('health صفر معتبر است و null یعنی محاسبه نشده', () {
      expect(SystemInfoItem.fromJson({'id': 1, 'health': 0}).health, 0);
      expect(SystemInfoItem.fromJson({'id': 1, 'health': null}).health, isNull);
    });

    test('pendingCpu از JSON معلق — همان PendingCpu() وب', () {
      final it = sys(
        cpu: 'Core i3',
        pending: '{"cpu":"Core i7-12700","ram":"32"}',
      );
      expect(it.hasPending, isTrue);
      expect(it.pendingCpu, 'Core i7-12700');
      expect(sys().pendingCpu, isNull);
      expect(sys(pending: 'not-json').pendingCpu, isNull);
    });
  });

  group('قطعات — GET api/SystemInfo/{id}/components', () {
    test('همهٔ آرایه‌ها و برد خوانده می‌شوند', () {
      final c = SystemComponents.fromJson({
        'board': {
          'board': 'ASUS H510',
          'boardSerial': 'SN-1',
          'computerModel': 'Dell OptiPlex 7090',
        },
        'cpus': [
          {
            'name': 'i5-10500',
            'cores': 6,
            'threads': 12,
            'clockGhz': 3.1,
          },
        ],
        'rams': [
          {
            'slot': 'DIMM1',
            'capacityGb': 8,
            'type': 'DDR4',
            'speedMhz': 2666,
            'manufacturer': 'Kingston',
            'partNumber': 'KVR',
            'serialNumber': '123',
          },
        ],
        'disks': [
          {
            'model': 'Samsung 980',
            'sizeGb': 512,
            'interface': 'NVMe',
            'smartStatus': 'OK',
          },
          {'model': 'WD Blue', 'sizeGb': 1000, 'smartStatus': 'PredFail'},
        ],
        'gpus': [
          {'name': 'Intel UHD 630', 'resolution': '1920x1080'},
        ],
        'monitors': [
          {
            'name': 'LG 22',
            'resolution': '1920x1080',
            'serialNumber': 'M-1',
            'isPrimary': true,
          },
        ],
        'netAdapters': [
          {
            'name': 'Ethernet',
            'type': 'Ethernet',
            'ipv4': '192.168.1.10',
            'gateway': '192.168.1.1',
            'macAddress': 'AA:BB',
          },
        ],
        'volumes': [
          {'letter': 'C:', 'label': 'System', 'totalGb': 200, 'usedGb': 150},
        ],
      });
      expect(c.hasAny, isTrue);
      expect(c.board!.computerModel, 'Dell OptiPlex 7090');
      expect(c.cpus.first.cores, 6);
      expect(c.rams.first.capacityGb, 8);
      expect(c.totalRamGb, 8);
      expect(c.disks.length, 2);
      expect(c.disks[1].smartBad, isTrue);
      expect(c.disks[0].smartBad, isFalse);
      expect(c.gpus.first.name, 'Intel UHD 630');
      expect(c.monitors.first.isPrimary, isTrue);
      expect(c.netAdapters.first.typeFa, 'کابلی');
      expect(c.volumes.first.usedPct, 75);
    });

    test('پاسخ خالی → hasAny برابر false', () {
      final c = SystemComponents.fromJson({'cpus': [], 'rams': []});
      expect(c.hasAny, isFalse);
    });
  });

  group('امتیاز سلامت', () {
    test('دسته‌ها، ضعیف‌ترین دسته و راهنمای ارتقا', () {
      final h = SystemHealth.fromJson({
        'score': 62,
        'grade': 'average',
        'gradeFa': 'متوسط',
        'color': '#f4a23c',
        'categories': [
          {'key': 'ram', 'fa': 'حافظه', 'score': 12, 'max': 20, 'note': '۸ گیگ'},
          {'key': 'storage', 'fa': 'فضا', 'score': 4, 'max': 20, 'note': '۹۰٪ پر'},
          {'key': 'cpu', 'fa': 'پردازنده', 'score': 20, 'max': 20, 'note': 'خوب'},
        ],
      });
      expect(h.score, 62);
      expect(h.gradeFa, 'متوسط');
      expect(h.categories.length, 3);
      expect(h.categories.first.pct, 60);
      expect(h.worst!.key, 'storage');
      expect(h.worstTip, 'آزادسازی فضا / ارتقا درایو');
    });

    test('راهنمای ارتقا برای همهٔ کلیدها — عیناً TipFor() وب', () {
      expect(SystemTip.forKey('storage'), 'آزادسازی فضا / ارتقا درایو');
      expect(SystemTip.forKey('ram'), 'ارتقا حافظه رم');
      expect(SystemTip.forKey('media'), 'جایگزینی با SSD');
      expect(SystemTip.forKey('cpu'), 'ارتقا پردازنده');
      expect(
        SystemTip.forKey('fresh'),
        'به‌روزرسانی اطلاعات (اجرای ایجنت)',
      );
      expect(SystemTip.forKey('status'), 'تکمیل فرآیند تایید');
      expect(SystemTip.forKey('other'), 'بررسی و ارتقا');
    });

    test('رنگ حلقهٔ گیج با آستانه‌های HealthGauge', () {
      expect(healthRingColor(96), '#0ea5a4');
      expect(healthRingColor(80), '#2ec47e');
      expect(healthRingColor(60), '#f4a23c');
      expect(healthRingColor(40), '#ff7043');
      expect(healthRingColor(10), '#e0245e');
      expect(healthRingColor(null), '#d5d9e6');
    });

    test('متن راهنمای امتیاز — HealthTip()', () {
      expect(healthTip(78), 'امتیاز سلامت: 78 از ۱۰۰');
      expect(healthTip(null), '');
    });
  });

  group('تغییرات و تاریخچه', () {
    test('changes/{id} و فقط موارد تغییرکرده', () {
      final p = PendingChanges.fromJson({
        'hasPending': true,
        'pendingReceivedAt': '2025-11-02T09:00:00',
        'changeCount': 2,
        'diffs': [
          {'field': 'CPU', 'old': 'i3', 'new': 'i7', 'changed': true},
          {'field': 'RAM', 'old': '8', 'new': '8', 'changed': false},
        ],
      });
      expect(p.hasPending, isTrue);
      expect(p.changeCount, 2);
      expect(p.diffs.where((d) => d.changed).length, 1);
      expect(p.diffs.first.newValue, 'i7');
    });

    test('history/{id} — رکوردها با تعداد تغییر', () {
      final rows = [
        SystemHistoryEntry.fromJson({
          'id': 4,
          'changedAt': '2025-10-30T12:00:00',
          'changeCount': 1,
          'diffs': [
            {'field': 'هارد', 'old': 'HDD', 'new': 'SSD', 'changed': true},
          ],
        }),
      ];
      expect(rows.single.id, 4);
      expect(rows.single.changeCount, 1);
      expect(rows.single.diffs.single.field, 'هارد');
    });
  });

  group('کاربران سیستم — GET api/SystemUsers', () {
    test('فیلدها و متن‌های نقش مثل RoleName() وب', () {
      final u = SystemUserRow.fromJson({
        'id': 7,
        'firstName': 'رضا',
        'lastName': 'کریمی',
        'staffNumber': '1042',
        'phone': '09120000000',
        'companyId': 3,
        'departmentId': 5,
        'organizationId': 9,
        'role': 'Operator',
        'isActive': true,
      });
      expect(u.fullName, 'رضا کریمی');
      expect(u.lookupLabel, 'رضا کریمی (1042)');
      expect(u.roleFa, 'اپراتور');
      expect(u.companyId, 3);
      expect(u.departmentId, 5);
      expect(u.organizationId, 9);

      expect(
        SystemUserRow.fromJson({'role': 'Admin'}).roleFa,
        'مدیر',
      );
      expect(
        SystemUserRow.fromJson({'role': 'Accountant'}).roleFa,
        'حسابدار',
      );
      expect(
        SystemUserRow.fromJson({'role': 'Referrer'}).roleFa,
        'معرف',
      );
      expect(
        SystemUserRow.fromJson({'role': 'HrManager'}).roleFa,
        'مدیر منابع انسانی',
      );
      expect(
        SystemUserRow.fromJson({'role': 'Employee'}).roleFa,
        'کارمند',
      );
      expect(SystemUserRow.fromJson({'role': ''}).roleFa, 'کاربر');
    });

    test('پنج گزینهٔ «دسته‌بندی» عیناً مثل فرم وب', () {
      expect(SystemUserRow.roleOptions.keys.toList(), [
        'User',
        'Operator',
        'Accountant',
        'Referrer',
        'Admin',
      ]);
      expect(
        SystemUserRow.roleOptions['User'],
        'کاربر عادی (کارمند)',
      );
      expect(SystemUserRow.roleOptions['Admin'], 'مدیر کل');
    });

    test('payload ذخیره/ویرایش همان فیلدهای سرور', () {
      final p = SystemUserRow.fromJson({
        'id': 7,
        'firstName': 'رضا',
        'lastName': 'کریمی',
        'staffNumber': '1042',
        'phone': '0912',
        'companyId': 3,
        'departmentId': 5,
        'organizationId': 9,
        'role': 'User',
        'isActive': false,
      }).toPayload();
      expect(p['id'], 7);
      expect(p['firstName'], 'رضا');
      expect(p['staffNumber'], '1042');
      expect(p['companyId'], 3);
      expect(p['organizationId'], 9);
      expect(p['isActive'], false);
    });
  });

  group('تحویل دیجیتال', () {
    test('چک‌لیست پیش‌فرض هفت آیتمی عیناً وب', () {
      expect(kHandoverChecklist.length, 7);
      expect(kHandoverChecklist.first.key, 'body');
      expect(kHandoverChecklist.first.fa, 'بدنه‌ی سیستم سالم است و روشن می‌شود');
      expect(kHandoverChecklist.last.key, 'tested');
      expect(
        kHandoverChecklist.last.fa,
        'گیرنده سیستم را تست کرده و تأیید می‌کند',
      );
    });

    test('handovers/{id} — فهرست تحویل‌ها', () {
      final h = SystemHandover.fromJson({
        'id': 3,
        'fromUserName': 'رضا کریمی',
        'toUserId': 9,
        'toUserName': 'سارا محمدی',
        'createdAt': '2025-11-01T10:00:00',
        'isCompleted': true,
        'completedAt': '2025-11-01T10:05:00',
        'checklist': [
          {'key': 'body', 'fa': 'بدنه', 'checked': true},
        ],
        'signatureDataUrl': 'data:image/png;base64,AAA',
        'note': 'تحویل در محل',
      });
      expect(h.id, 3);
      expect(h.isCompleted, isTrue);
      expect(h.checklist.single.checked, isTrue);
      expect(h.note, 'تحویل در محل');
    });
  });

  group('دستور از راه دور', () {
    test('متن دستور و وضعیت — CmdFa/CmdStatusFa وب', () {
      final c = RemoteCommandRow.fromJson({
        'id': 1,
        'action': 'Reboot',
        'status': 'Completed',
        'createdAt': '2025-11-03T08:00:00',
        'byUserName': 'مدیر',
      });
      expect(c.actionFa, 'ری‌استارت سیستم');
      expect(c.statusFa, 'انجام شد');

      expect(
        RemoteCommandRow.fromJson({'action': 'Shutdown'}).actionFa,
        'خاموش کردن سیستم',
      );
      expect(RemoteCommandRow.fromJson({'action': 'Lock'}).actionFa, 'قفل صفحه');
      expect(
        RemoteCommandRow.fromJson({'status': 'Failed'}).statusFa,
        'ناموفق',
      );
      expect(
        RemoteCommandRow.fromJson({'status': 'Pending'}).statusFa,
        'در انتظار ایجنت',
      );
      expect(RemoteCommandRow.fromJson({}).byUserFa, '—');
    });
  });

  group('تحلیل‌های ناوگان — getterهای SystemInfoList.razor', () {
    test('نرمال‌سازی سیستم‌عامل — NormOs()', () {
      expect(normOs('Windows 11 Pro'), 'Windows 11');
      expect(normOs('Microsoft Windows 10 Enterprise'), 'Windows 10');
      expect(normOs('Ubuntu 22.04'), 'سایر');
      expect(normOs(''), 'نامشخص');
      expect(normOs(null), 'نامشخص');
    });

    test('بخش‌های دونات سیستم‌عامل با رنگ‌های ثابت', () {
      final segs = osSegments([
        sys(id: 1, os: 'Windows 11'),
        sys(id: 2, os: 'Windows 11 Pro'),
        sys(id: 3, os: 'Windows 10'),
        sys(id: 4, os: 'Ubuntu'),
      ]);
      expect(segs.length, 3);
      expect(segs.first.name, 'Windows 11');
      expect(segs.first.count, 2);
      expect(segs.first.pct, 50);
      expect(segs.first.color, '#0ea5a4');
      expect(segs[1].color, '#8e5cff');
      expect(segs[2].name, 'سایر');
      expect(segs.map((s) => s.pct).reduce((a, b) => a + b), 100);
      expect(segs.length <= kOsColors.length, isTrue);
    });

    test('میانگین رم دپارتمان — RamByDept با نام واحدهای ناشناخته', () {
      final rows = ramByDept(
        [
          sys(id: 1, departmentId: 5, ramGb: 8),
          sys(id: 2, departmentId: 5, ramGb: 16),
          sys(id: 3, departmentId: 6, ramGb: 4),
          sys(id: 4, departmentId: null, ramGb: 32),
        ],
        {5: 'حسابداری', 6: 'فروش'},
      );
      expect(rows.length, 3);
      // مرتب‌سازی نزولی بر اساس میانگین — «بدون واحد» با ۳۲ اول است
      expect(rows.first.name, 'بدون واحد');
      expect(rows.first.avg, 32);
      final acc = rows.firstWhere((r) => r.name == 'حسابداری');
      expect(acc.avg, 12);
      expect(acc.count, 2);
      expect(acc.avgLabel, '12 GB');
      expect(rows.firstWhere((r) => r.name == 'فروش').avgLabel, '4 GB');
    });

    test('نام واحد ناشناخته → «واحد #id» مثل وب', () {
      final rows = ramByDept([sys(departmentId: 99, ramGb: 8)], {});
      expect(rows.single.name, 'واحد #99');
    });

    test('بزرگ‌ترین میانگین برای عرض نوار — MaxDeptRam', () {
      expect(
        maxDeptRam([
          const DeptRam(name: 'a', avg: 7.4, count: 1),
          const DeptRam(name: 'b', avg: 15.6, count: 1),
        ]),
        16,
      );
      expect(maxDeptRam(const []), 1);
    });

    test('۱۰ سیستم ضعیف‌تر — Weakest10 فقط با امتیاز سلامت', () {
      final items = [
        for (var i = 0; i < 14; i++) sys(id: i + 1, health: i + 40),
        sys(id: 99, health: null),
      ];
      final weak = weakest10(items);
      expect(weak.length, 10);
      expect(weak.first.id, 1);
      expect(weak.last.id, 10);
      expect(weak.every((w) => w.health != null), isTrue);
    });

    test('گروه‌بندی شرکت‌ها — CompanyGroups (بدون شرکت آخر)', () {
      final groups = companyGroups(
        [
          sys(id: 1, companyId: 3, at: DateTime(2025, 11, 1)),
          sys(id: 2, companyId: 3, at: DateTime(2025, 11, 3)),
          sys(id: 3, companyId: 4),
          sys(id: 4, companyId: null),
          sys(id: 5, companyId: 77),
        ],
        const [
          SystemCompanyRow(id: 3, name: 'فروغ آریا', code: 'FA'),
          SystemCompanyRow(id: 4, name: 'آریا تک'),
        ],
      );
      expect(groups.length, 4);
      // شرکت‌دارها بر اساس نام، بعد «بدون شرکت»
      // ترتیب: شرکت‌دارها به ترتیب نام (آریا تک، شرکت حذف‌شده، فروغ آریا)، بعد «بدون شرکت»
      expect(groups.first.name, 'آریا تک');
      expect(groups[1].name, 'شرکت حذف‌شده / ناشناخته (#77)');
      expect(groups[2].name, 'فروغ آریا');
      expect(groups[2].code, 'FA');
      expect(groups[2].items.first.id, 2); // جدیدترین اول
      expect(groups[2].items.length, 2);
      expect(groups.last.name, 'بدون شرکت');
      expect(groups.last.companyId, isNull);
    });
  });

  group('ثبت دستی — POST api/SystemInfo/manual', () {
    test('payload همان فیلدهای ManualSystemInfoRequest', () {
      final req = ManualSystemRequest(
        agentId: 'PC-ACC-01',
        companyId: 3,
        departmentId: 5,
        userId: 7,
        computerModel: 'Dell OptiPlex 7090',
        motherboard: 'ASUS H510',
        cpu: 'Intel Core i5-10500',
        totalRamGb: 16,
        ram: 'DDR4',
        hardDisk: '512GB NVMe SSD',
        graphics: 'Intel UHD 630',
        monitor: 'LG 22',
        osName: 'Windows 11 Pro',
        ip: '192.168.1.10',
      );
      final j = req.toJson();
      expect(j['agentId'], 'PC-ACC-01');
      expect(j['companyId'], 3);
      expect(j['departmentId'], 5);
      expect(j['userId'], 7);
      expect(j['totalRamGb'], 16);
      expect(j['osName'], 'Windows 11 Pro');
      expect(j.keys.length, 14);
    });
  });

  group('کاربر تاریخچه و پایه‌ها', () {
    test('user-history/{id} — رکورد باز/بسته', () {
      final rows = [
        SystemUserHistoryRow.fromJson({
          'id': 1,
          'userId': 7,
          'userName': 'رضا کریمی',
          'staffNumber': '1042',
          'companyName': 'فروغ آریا',
          'fromAt': '2025-10-01T08:00:00',
          'toAt': null,
        }),
        SystemUserHistoryRow.fromJson({
          'id': 2,
          'userName': 'سارا محمدی',
          'fromAt': '2025-09-01T08:00:00',
          'toAt': '2025-10-01T08:00:00',
        }),
      ];
      expect(rows.first.isOpen, isTrue);
      expect(rows[1].isOpen, isFalse);
      expect(rows.first.companyName, 'فروغ آریا');
    });

    test('شرکت/واحد/واحد سازمانی', () {
      final c = SystemCompanyRow.fromJson({
        'id': 3,
        'name': 'فروغ آریا',
        'code': 'FA',
        'isActive': true,
      });
      expect(c.code, 'FA');
      final d = SystemDepartmentRow.fromJson({
        'id': 5,
        'name': 'حسابداری',
        'companyId': 3,
      });
      expect(d.companyId, 3);
      final o = SystemOrganizationRow.fromJson({
        'organizationId': 9,
        'nameUnit': 'واحد مالی',
        'nameUniq': 'FIN',
        'isActive': true,
      });
      expect(o.label, 'واحد مالی (FIN)');
    });
  });
}
