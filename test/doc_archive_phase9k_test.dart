// تست‌های فاز ۹-ک — تکمیل شکاف‌های آرشیو
// امضا در تایید، فیلتر کامل جستجو، لینک چندمدرکی، ورود انبوه

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:forough_mobile/features/it_assets/models/doc_archive_models.dart';

void main() {
  group('آرشیو ۹-ک — امضای تایید', () {
    test('امضا و مشخصات دستگاه در بدنه می‌آید', () {
      final j = DocApprovalInput(
        versionId: 9,
        approve: true,
        comment: 'ok',
        signatureDataUrl: 'data:image/png;base64,AAA',
        biometricVerified: false,
        deviceInfo: 'FPA-Mobile android app',
        clientTimestamp: DateTime(2026, 5, 1, 10, 30),
      ).toJson();
      expect(j['signatureDataUrl'], 'data:image/png;base64,AAA');
      expect(j['biometricVerified'], false);
      expect(j['deviceInfo'], 'FPA-Mobile android app');
      expect(j['clientTimestamp'], contains('2026-05-01'));
    });

    test('بدون امضا، کلید امضا ارسال نمی‌شود', () {
      final j = const DocApprovalInput(versionId: 1, approve: false).toJson();
      expect(j.containsKey('signatureDataUrl'), isFalse);
      expect(j['clientTimestamp'], isA<String>());
    });
  });

  group('آرشیو ۹-ک — فیلتر کامل جستجو', () {
    test('بازه‌های تاریخ و فیلترهای افراد در بدنه', () {
      final f = DocSearchFilter(
        createdFrom: DateTime(2026, 1, 1),
        createdTo: DateTime(2026, 2, 1),
        expiryFrom: DateTime(2026, 3, 1),
        expiryTo: DateTime(2026, 4, 1),
        approverUserId: 7,
        createdByUserId: 8,
        hasAttachment: true,
        tagIds: const [3],
      );
      final j = f.toJson();
      expect(j['createdFrom'], contains('2026-01-01'));
      expect(j['expiryTo'], contains('2026-04-01'));
      expect(j['approverUserId'], 7);
      expect(j['createdByUserId'], 8);
      expect(j['hasAttachment'], true);
      expect(f.activeCount, 5);
    });

    test('فیلتر خالی شمارش صفر دارد و اعتبار تاریخ درست است', () {
      const empty = DocSearchFilter();
      expect(empty.activeCount, 0);
      expect(validateSearchDates(empty), isNull);
      expect(
        validateSearchDates(
          DocSearchFilter(
            createdFrom: DateTime(2026, 5, 1),
            createdTo: DateTime(2026, 4, 1),
          ),
        ),
        'بازه تاریخ معتبر نیست.',
      );
      expect(
        validateSearchDates(
          DocSearchFilter(
            expiryFrom: DateTime(2026, 5, 1),
            expiryTo: DateTime(2026, 3, 1),
          ),
        ),
        'بازه تاریخ معتبر نیست.',
      );
    });

    test('«پاک کردن» فقط عبارت و وضعیت‌ها را نگه می‌دارد', () {
      final f = DocSearchFilter(
        search: 'قرارداد',
        contentSearch: 'نگهداری',
        fileTypes: const ['pdf'],
        tagIds: const [1],
        hasAttachment: false,
        createdFrom: DateTime(2026, 1, 1),
      );
      final c = f.cleared();
      expect(c.search, 'قرارداد');
      expect(c.contentSearch, isNull);
      expect(c.fileTypes, isEmpty);
      expect(c.tagIds, isEmpty);
      expect(c.hasAttachment, isNull);
      expect(c.createdFrom, isNull);
      expect(c.status, 'active');
    });

    test('فیلتر حساب صفر (user 0) ارسال نمی‌شود', () {
      final j = const DocSearchFilter(
        approverUserId: 0,
        createdByUserId: 0,
      ).toJson();
      expect(j.containsKey('approverUserId'), isFalse);
      expect(j.containsKey('createdByUserId'), isFalse);
    });
  });

  group('آرشیو ۹-ک — لینک چندمدرکی', () {
    test('بدنهٔ لینک چندمدرکی و راهنمای وب', () {
      final j = DocLinkInput(
        documentId: 4,
        linkedDocumentIds: const [10, 11],
        note: ' نسخهٔ قبلی ',
      ).toJson();
      expect(j['documentId'], 4);
      expect(j['linkedDocumentIds'], [10, 11]);
      expect(j['note'], 'نسخهٔ قبلی');
      expect(kDocLinkHint, contains('بررسی/به‌روزرسانی'));
      expect(kDocLinkHint, contains('فقط مدارک فعال'));
    });

    test('یادداشت خالی ارسال نمی‌شود', () {
      final j = const DocLinkInput(
        documentId: 1,
        linkedDocumentIds: [2],
        note: '   ',
      ).toJson();
      expect(j.containsKey('note'), isFalse);
    });

    test('comparison validation', () {
      expect(validateCompare(3, 3), 'دو ورژن متفاوت انتخاب کنید.');
      expect(validateCompare(1, 2), isNull);
    });
  });

  group('آرشیو ۹-ک — ورود انبوه', () {
    test('پیکربندی پیش‌فرض روشن و سقف‌ها', () {
      final cfg = DocImportConfig.fromJson({});
      expect(cfg.enabled, isTrue);
      expect(cfg.maxFileBytes, 50 * 1024 * 1024);
      expect(cfg.maxFileFa, isNotEmpty);
    });

    test('پیکربندی خاموش با دلیل فارسی', () {
      final cfg = DocImportConfig.fromJson({
        'enabled': false,
        'problemFa': 'روی سرور خاموش است',
      });
      expect(cfg.enabled, isFalse);
      expect(cfg.problemFa, 'روی سرور خاموش است');
    });

    test('خلاصهٔ بررسی و نتیجهٔ ورود', () {
      const p = DocImportPreview(total: 10, ready: 7, failed: 2, skipped: 1);
      expect(p.notImported, 3);
      expect(p.summaryFa, contains('۷'));

      const r = DocImportResult(imported: 7, duplicate: 1, failed: 2);
      expect(r.headlineFa, contains('وارد آرشیو شد'));
      expect(r.headlineFa, contains('تکراری'));
      expect(r.headlineFa, contains('ناموفق'));
      expect(r.isSuccess, isFalse);

      final ok = DocImportResult.fromJson({'imported': 5});
      expect(ok.imported, 5);
      expect(ok.isSuccess, isTrue);
    });

    test('فایل مشکل‌دار دلیل و حجم فارسی دارد', () {
      const item = DocImportItem(
        relativePath: 'a/b.pdf',
        fileName: 'b.pdf',
        size: 2048,
        ready: false,
        reasonFa: 'حجم فایل بیش از سقف است.',
      );
      expect(item.relativePath, 'a/b.pdf');
      expect(item.sizeFa, contains('KB'));
      expect(item.ready, isFalse);
    });
  });

  group('آرشیو ۹-ک — امضای موبایل', () {
    test('پلتفرم پیش‌فرض تست، مشخصات دستگاه می‌دهد', () {
      expect(defaultTargetPlatform, isNotNull);
      expect(kIsWeb, isFalse);
    });
  });
}
