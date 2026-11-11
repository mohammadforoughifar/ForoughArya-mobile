// آزمون فاز ۹-و «دوربین‌های مداربسته» و «دستگاه‌های NVR»
// — آینه‌بودن مدل‌ها، اعتبارسنجی‌ها، گروه‌بندی، فیلتر و متن‌های فارسیِ وب

import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/features/it_assets/models/cctv_models.dart';

CctvCameraRow cam({
  int id = 1,
  String model = 'Hikvision DS-2CD2143G2-I',
  String serial = 'C123',
  String? ip,
  String? mac,
  String? location,
  String? notes,
  int? nvrId,
  bool active = true,
  DateTime? at,
}) => CctvCameraRow(
  id: id,
  model: model,
  serialNumber: serial,
  ip: ip,
  mac: mac,
  location: location,
  notes: notes,
  nvrId: nvrId,
  isActive: active,
  createdAt: at,
);

CctvNvrRow nvr({
  int id = 1,
  String model = 'Hikvision DS-7716NI-M4',
  String serial = 'N-1',
  String? location,
}) => CctvNvrRow(
  id: id,
  model: model,
  serialNumber: serial,
  location: location,
);

void main() {
  group('دوربین — مدل و متن‌ها', () {
    test('فیلدها از JSON سرور خوانده می‌شوند', () {
      final c = CctvCameraRow.fromJson({
        'id': 5,
        'model': 'Dahua IPC-HFW',
        'serialNumber': 'SN-01',
        'ip': '192.168.1.101',
        'mac': 'C0:56:E3:AA:BB:01',
        'location': 'انبار مرکزی — سردر شرقی',
        'notes': 'بولت ۴ مگاپیکسل',
        'nvrId': 3,
        'isActive': true,
        'createdAt': '2026-01-02T08:30:00',
      });
      expect(c.id, 5);
      expect(c.model, 'Dahua IPC-HFW');
      expect(c.serialNumber, 'SN-01');
      expect(c.ipCell, '192.168.1.101');
      expect(c.macCell, 'C0:56:E3:AA:BB:01');
      expect(c.locationCell, 'انبار مرکزی — سردر شرقی');
      expect(c.nvrId, 3);
      expect(c.statusCell, 'فعال');
      expect(c.createdAt, isNotNull);
    });

    test('مقادیر خالی «—» و وضعیت غیرفعال', () {
      final c = CctvCameraRow.fromJson({'model': 'X', 'isActive': false});
      expect(c.ipCell, '—');
      expect(c.macCell, '—');
      expect(c.locationCell, '—');
      expect(c.statusCell, 'غیرفعال');
      expect(CctvCameraRow.fromJson({'model': 'Y'}).isActive, isTrue);
    });

    test('جستجو مثل filtered وب: مدل/سریال/آی‌پی/مک/محل', () {
      final c = cam(
        ip: '10.0.0.5',
        mac: 'AA:BB:CC',
        location: 'طبقه ۲',
      );
      expect(c.matches('hikvision'), isTrue);
      expect(c.matches('C123'), isTrue);
      expect(c.matches('10.0.0'), isTrue);
      expect(c.matches('aa:bb'), isTrue);
      expect(c.matches('طبقه'), isTrue);
      expect(c.matches('ناموجود'), isFalse);
    });
  });

  group('دوربین — اعتبارسنجی فرم', () {
    test('سه پیام وب با همان ترتیب', () {
      expect(
        validateCameraForm(CctvCameraForm()),
        'مدل را وارد کنید.',
      );
      expect(
        validateCameraForm(CctvCameraForm(model: 'M')),
        'شماره سریال را وارد کنید.',
      );
      expect(
        validateCameraForm(CctvCameraForm(model: 'M', serialNumber: 'S')),
        'محل استقرار را وارد کنید.',
      );
      expect(
        validateCameraForm(
          CctvCameraForm(model: 'M', serialNumber: 'S', location: 'L'),
        ),
        isNull,
      );
    });

    test('toJson همان فیلدهای CctvCamera سرور است', () {
      final j = CctvCameraForm(
        id: 7,
        model: 'M',
        serialNumber: 'S',
        location: 'L',
        nvrId: 2,
        isActive: false,
      ).toJson();
      expect(j['id'], 7);
      expect(j['nvrId'], 2);
      expect(j['isActive'], false);
      for (final k in [
        'model',
        'serialNumber',
        'ip',
        'mac',
        'location',
        'notes',
      ]) {
        expect(j.containsKey(k), isTrue);
      }
    });

    test('fromRow همهٔ فیلدها را منتقل می‌کند', () {
      final f = CctvCameraForm.fromRow(
        cam(ip: '1.1.1.1', mac: 'M', location: 'L', notes: 'N', nvrId: 4),
      );
      expect(f.id, 1);
      expect(f.ip, '1.1.1.1');
      expect(f.location, 'L');
      expect(f.nvrId, 4);
      expect(f.notes, 'N');
    });
  });

  group('NVR — مدل و اعتبارسنجی', () {
    test('گزینهٔ مودال دوربین: «مدل (سریال) — محل»', () {
      expect(
        nvr(model: 'Hikvision DS-7716', serial: 'N-9', location: 'اتاق سرور')
            .optionLabel,
        'Hikvision DS-7716 (N-9) — اتاق سرور',
      );
      expect(
        nvr(model: 'A', serial: 'B').optionLabel,
        'A (B)',
      );
    });

    test('دو پیام اعتبارسنجی وب', () {
      expect(validateNvrForm(CctvNvrForm()), 'مدل را وارد کنید.');
      expect(
        validateNvrForm(CctvNvrForm(model: 'M')),
        'شماره سریال را وارد کنید.',
      );
      expect(
        validateNvrForm(CctvNvrForm(model: 'M', serialNumber: 'S')),
        isNull,
      );
    });

    test('جستجوی NVR: مدل/سریال/آی‌پی/محل', () {
      final n = CctvNvrRow.fromJson({
        'model': 'Hikvision',
        'serialNumber': 'N1',
        'ip': '192.168.1.10',
        'location': 'اتاق سرور',
      });
      expect(n.matches('hik'), isTrue);
      expect(n.matches('n1'), isTrue);
      expect(n.matches('192.168'), isTrue);
      expect(n.matches('سرور'), isTrue);
      expect(n.matches('zzz'), isFalse);
      expect(n.ipCell, '192.168.1.10');
    });

    test('fromRow و toJson فرم NVR', () {
      final n = CctvNvrRow.fromJson({
        'id': 2,
        'model': 'M',
        'serialNumber': 'S',
        'location': 'L',
        'isActive': false,
      });
      final f = CctvNvrForm.fromRow(n);
      expect(f.id, 2);
      expect(f.location, 'L');
      expect(f.isActive, isFalse);
      expect(f.toJson()['id'], 2);
    });
  });

  group('گروه‌بندی و فیلتر — عیناً وب', () {
    final items = [
      cam(id: 1, model: 'A', location: 'انبار', nvrId: 1),
      cam(id: 2, model: 'B', location: 'انبار', nvrId: 1),
      cam(id: 3, model: 'C', location: 'طبقه ۲', nvrId: 2),
      cam(id: 4, model: 'D'),
    ];
    final nvrs = [
      nvr(id: 1, model: 'NVR-1'),
      nvr(id: 2, model: 'NVR-2'),
    ];

    test('محل‌های یکتا مرتب‌شده و تعداد هر محل', () {
      expect(cctvLocations(items), ['انبار', 'طبقه ۲']);
      expect(cctvCamerasAt(items, 'انبار'), 2);
      expect(cctvCamerasAt(items, 'طبقه ۲'), 1);
      expect(cctvCamerasAt(items, 'ناموجود'), 0);
    });

    test('گروه‌بندی بر اساس محل با گروه «بدون محل مشخص»', () {
      final g = groupCameras(items, CctvGroupMode.location, nvrs);
      expect(g.length, 3);
      expect(g.first.key, 'انبار');
      expect(g.first.items.length, 2);
      expect(g.map((x) => x.key).toList(), contains('بدون محل مشخص'));
    });

    test('گروه‌بندی بر اساس NVR با «—» برای بدون دستگاه', () {
      final g = groupCameras(items, CctvGroupMode.nvr, nvrs);
      expect(g.length, 3);
      expect(g.map((x) => x.key).toList(), contains('NVR-1'));
      expect(g.map((x) => x.key).toList(), contains('—'));
    });

    test('بدون گروه‌بندی یک گروه با کل موارد', () {
      final g = groupCameras(items, CctvGroupMode.none, nvrs);
      expect(g.length, 1);
      expect(g.first.key, '');
      expect(g.first.items.length, 4);
    });

    test('NvrName: مدل دستگاه و «—» در نبود آن', () {
      expect(cctvNvrName(nvrs, 1), 'NVR-1');
      expect(cctvNvrName(nvrs, 99), '—');
      expect(cctvNvrName(nvrs, null), '—');
    });

    test('سه حالت گروه‌بندی وب', () {
      expect(kCctvGroupModes.length, 3);
      expect(kCctvGroupModes[0].value, 'گروه‌بندی: محل');
      expect(kCctvGroupModes[1].value, 'گروه‌بندی: NVR');
      expect(kCctvGroupModes[2].value, 'بدون گروه‌بندی');
    });
  });

  group('ورود گروهی از اکسل', () {
    test('پاسخ سرور و متن خلاصه', () {
      final r = CctvImportResult.fromJson({
        'inserted': 12,
        'skipped': 3,
        'errors': ['سطر ۴: مدل یا سریال خالی است.', 'سطر ۹: خطا'],
      });
      expect(r.inserted, 12);
      expect(r.skipped, 3);
      expect(r.summaryFa, '12 دوربین ثبت شد؛ 3 رد شد (خالی/تکراری).');
      expect(r.hasErrors, isTrue);
      expect(r.firstErrors.length, 2);
    });

    test('بدون خطا', () {
      final r = CctvImportResult.fromJson({'inserted': 5, 'skipped': 0});
      expect(r.hasErrors, isFalse);
      expect(r.errors, isEmpty);
      expect(r.summaryFa, contains('5 دوربین ثبت شد'));
    });

    test('حداکثر ۱۰ خطای اول نمایش داده می‌شود — مثل وب', () {
      final r = CctvImportResult(
        errors: List.generate(15, (i) => 'سطر ${i + 2}: خطا'),
      );
      expect(r.firstErrors.length, 10);
    });
  });
}
