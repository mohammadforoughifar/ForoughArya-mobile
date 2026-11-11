// تست‌های فاز ۱۰ — آینهٔ کامل صفحات DocArchive وب
// (مقایسهٔ محتوا، لاگ دسترسی/چاپ، ردیاب نشت، درخواست دسترسی،
//  متن استخراج‌شده، نظرات، شماره‌گذاری کد، بررسی تکراری)

import 'package:flutter_test/flutter_test.dart';

import 'package:forough_mobile/features/it_assets/models/doc_archive_models.dart';

void main() {
  group('فاز ۱۰ — مقایسهٔ محتوای فایل‌ها', () {
    test('ردیف‌های تفاوت و شمارش', () {
      final c = DocContentCompare.fromJson({
        'leftName': 'a.pdf',
        'rightName': 'b.pdf',
        'mode': 'Text',
        'truncated': true,
        'rows': [
          {'field': 'line 1', 'left': 'الف', 'right': 'ب', 'kind': 'changed'},
          {'field': 'line 2', 'left': 'ج', 'right': 'ج', 'kind': 'same'},
          {'field': 'line 3', 'left': '', 'right': 'د', 'kind': 'added'},
        ],
      });
      expect(c.rows.length, 3);
      expect(c.changeCount, 2);
      expect(c.onlyChanges.length, 2);
      expect(c.summaryFa, '۲ تفاوت');
      expect(c.rows.first.kindLabel, 'تغییر کرد');
      expect(c.rows[1].kindLabel, 'یکسان');
      expect(c.rows.last.kindLabel, 'افزوده شد');
      expect(c.modeFa, 'مقایسهٔ متن');
      expect(c.truncated, isTrue);
    });

    test('حالت اکسل و نتیجهٔ بدون تفاوت', () {
      final c = DocContentCompare.fromJson({'mode': 'Spreadsheet'});
      expect(c.modeFa, 'مقایسهٔ شیت‌های اکسل');
      expect(c.summaryFa, 'تفاوتی یافت نشد');
      expect(c.rows, isEmpty);
    });

    test('پیام‌های ثابت سرور عیناً حفظ شده‌اند', () {
      expect(
        DocContentCompare.minTwoFiles,
        'دو فایل از دو نسخه متفاوت همین مدرک انتخاب کنید.',
      );
      expect(
        DocContentCompare.needsPassword,
        'برای مقایسه محتوای محرمانه، تأیید رمز لازم است.',
      );
      expect(
        DocContentCompare.excelTooLarge,
        'سقف فایل مقایسه Excel بیست مگابایت است.',
      );
      expect(
        DocContentCompare.truncatedFa,
        'مقایسه کامل نیست؛ محدودیت حجم اعمال شده است.',
      );
    });
  });

  group('فاز ۱۰ — گزارش دسترسی و چاپ', () {
    test('لاگ مشاهده/دانلود', () {
      final logs = DocFileAccessLog.listFrom([
        {
          'attachmentId': 3,
          'fileName': 'a.pdf',
          'action': 'Download',
          'userName': 'محمد',
          'ip': '1.2.3.4',
          'at': '2026-01-02T10:00:00',
        },
        {'action': 'Preview', 'fileName': 'b.pdf'},
      ]);
      expect(logs.length, 2);
      expect(logs.first.actionFa, 'دانلود');
      expect(logs.last.actionFa, 'مشاهده');
      expect(logs.first.ip, '1.2.3.4');
      expect(DocFileAccessLog.listFrom(null), isEmpty);
    });

    test('لاگ چاپ با واترمارک', () {
      final p = DocPrintLog.fromJson({
        'id': 9,
        'fileName': 'قرارداد.pdf',
        'versionNo': 2,
        'userName': 'سارا',
        'watermarkText': 'سارا — ۱۴۰۴/۰۱/۰۲',
        'pageCount': 4,
        'fileSizeBytes': 2048,
      });
      expect(p.versionNo, 2);
      expect(p.watermarkText.contains('سارا'), isTrue);
      expect(p.pageCount, 4);
    });

    test('ردیاب نشت', () {
      final t = DocLeakTrace.listFrom([
        {'id': 1, 'userName': 'علی', 'visibleWatermark': 'W-1', 'action': 'Print'},
      ]);
      expect(t.single.visibleWatermark, 'W-1');
      expect(t.single.action, 'Print');
    });
  });

  group('فاز ۱۰ — درخواست دسترسی', () {
    test('وضعیت‌های فارسی ۰..۳', () {
      String st(int s) => DocAccessRequest.fromJson({'status': s}).statusFa;
      expect(st(0), 'در انتظار');
      expect(st(1), 'پذیرفته');
      expect(st(2), 'ردشده');
      expect(st(3), 'لغوشده');
    });

    test('در انتظار بودن و سطح', () {
      final r = DocAccessRequest.fromJson({
        'id': 4,
        'requesterName': 'رضا',
        'requestedLevel': DocLevel.write,
        'status': 0,
      });
      expect(r.isPending, isTrue);
      expect(r.levelFa, 'نوشتن');
      expect(r.requesterName, 'رضا');
    });
  });

  group('فاز ۱۰ — متن استخراج‌شده', () {
    test('وضعیت ایندکس و OCR', () {
      final t = DocExtractedText.fromJson({
        'attachmentId': 5,
        'fileName': 'scan.jpg',
        'sourceType': 'ImageOcr',
        'status': 'Indexed',
        'characterCount': 120,
      });
      expect(t.isIndexed, isTrue);
      expect(t.isOcr, isTrue);
      expect(t.statusFa, 'آماده');
      final p = DocExtractedText.fromJson({'status': 'Pending'});
      expect(p.statusFa, 'در صف');
      expect(p.isIndexed, isFalse);
    });
  });

  group('فاز ۱۰ — نظرات مدرک', () {
    test('پاسخ‌های تودرتو و منشن', () {
      final c = DocComment.listFrom([
        {
          'id': 1,
          'authorName': 'مریم',
          'body': 'سلام @علی',
          'isResolved': false,
          'mentionedUserIds': [7],
          'mentionedUserNames': ['علی'],
          'replies': [
            {'id': 2, 'authorName': 'علی', 'body': 'سلام', 'isResolved': true},
          ],
        },
      ]);
      expect(c.single.replies.single.isResolved, isTrue);
      expect(c.single.mentionedUserIds.single, 7);
      expect(c.single.mentionedUserNames.single, 'علی');
    });
  });

  group('فاز ۱۰ — شماره‌گذاری کد مدرک', () {
    test('پیش‌نمایش کد بعدی و اعتبارسنجی', () {
      const s = DocCodeSettings(prefix: 'DOC-', padding: 5, nextNumber: 42);
      expect(s.sampleFa, 'DOC-00042');
      expect(DocCodeSettings.validatePrefix('  '), 'پیشوند کد را بنویسید.');
      expect(DocCodeSettings.validatePrefix('DOC-'), isNull);
      expect(DocCodeSettings.validatePadding(0), 'تعداد رقم بین ۱ تا ۱۲ باشد.');
      expect(DocCodeSettings.validatePadding(13), 'تعداد رقم بین ۱ تا ۱۲ باشد.');
      expect(DocCodeSettings.validatePadding(5), isNull);
      expect(s.toJson()['nextNumber'], 42);
    });

    test('پیش‌فرض‌های سرور', () {
      final s = DocCodeSettings.fromJson(const {});
      expect(s.enabled, isFalse);
      expect(s.prefix, 'DOC-');
      expect(s.padding, 5);
    });
  });

  group('فاز ۱۰ — بررسی تکراری', () {
    test('هشدار تکراری و دلایل فارسی', () {
      final r = DocDuplicateResult.fromJson({
        'isDuplicate': true,
        'hits': [
          {
            'documentId': 3,
            'code': 'DOC-1',
            'title': 'قرارداد',
            'reason': 'hash-exact',
            'score': 100,
          },
          {'reason': 'semantic'},
          {'reason': 'name'},
        ],
      });
      expect(r.isDuplicate, isTrue);
      expect(r.hits.length, 3);
      expect(r.hits[0].reasonFa, 'فایل یکسان');
      expect(r.hits[1].reasonFa, 'محتوای مشابه');
      expect(r.hits[2].reasonFa, 'نام مشابه');
      expect(r.headlineFa.contains('مدرک مشابه پیدا شد'), isTrue);
      expect(const DocDuplicateResult().headlineFa, 'مدرک مشابهی پیدا نشد.');
    });

    test('بدنهٔ درخواست بدون فیلدهای خالی', () {
      final j = const DocDuplicateRequest(title: 'x').toJson();
      expect(j, {'title': 'x'});
    });
  });
}
