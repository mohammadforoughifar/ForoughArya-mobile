// تست‌های فاز ۹-ی — بخش ۳ آرشیو اسناد
// مدل‌های ورژن جدید، تایید/رد، پیوست، مقایسه، جستجوی معنایی/تمام‌متن

import 'package:flutter_test/flutter_test.dart';

import 'package:forough_mobile/features/it_assets/models/doc_archive_models.dart';

void main() {
  group('آرشیو بخش ۳ — ثبت ورژن جدید', () {
    test('شرح تغییرات اجباری است', () {
      expect(
        validateVersionForm(changeNote: '   '),
        'شرح تغییرات را وارد کنید.',
      );
      expect(validateVersionForm(changeNote: 'اصلاح بند ۳'), isNull);
    });

    test('بدنهٔ ورژن جدید همان DTO سرور است', () {
      final input = DocVersionInput(
        documentId: 12,
        title: ' ورژن دوم ',
        changeNote: ' افزودن پیوست ',
        expireDate: DateTime(2027, 3, 21),
        sendToFlow: true,
        activateOnApprove: false,
        approverUserIds: const [7, 9],
      );
      final j = input.toJson();
      expect(j['documentId'], 12);
      expect(j['title'], 'ورژن دوم');
      expect(j['changeNote'], 'افزودن پیوست');
      expect(j['sendToFlow'], true);
      expect(j['activateOnApprove'], false);
      expect(j['approverUserIds'], [7, 9]);
    });

    test('اقدام تایید/رد فقط نسخه و نظر را می‌فرستد', () {
      final j = DocApprovalInput(
        versionId: 5,
        approve: false,
        comment: ' شرح نادرست ',
      ).toJson();
      expect(j['versionId'], 5);
      expect(j['approve'], false);
      expect(j['comment'], 'شرح نادرست');
    });
  });

  group('آرشیو بخش ۳ — پیوست‌ها', () {
    test('سقف حجم و پیام سرور', () {
      expect(kAttachmentMaxBytes, 10 * 1024 * 1024);
      expect(kAttachmentTooLarge, 'حداکثر حجم فایل ۱۰ مگابایت است.');
    });

    test('نوع فایل و متن حجم/تاریخ', () {
      final a = DocAttachment.fromJson({
        'id': 3,
        'fileName': 'scan.png',
        'uploaderName': 'محمد',
        'uploadedAt': '2026-02-01T10:00:00',
        'size': 2048,
        'contentType': 'image/png',
        'canDelete': true,
      });
      expect(a.isImage, isTrue);
      expect(a.isPdf, isFalse);
      expect(a.canDelete, isTrue);
      expect(a.sizeFa, contains('KB'));
    });

    test('PDF تشخیص داده می‌شود', () {
      final a = DocAttachment.fromJson({
        'contentType': 'application/pdf',
      });
      expect(a.isPdf, isTrue);
      expect(a.isImage, isFalse);
    });
  });

  group('آرشیو بخش ۳ — مقایسهٔ دو نسخه', () {
    test('ردیف‌های تغییر و شمارش', () {
      final cmp = DocVersionCompare.fromJson({
        'documentId': 1,
        'documentCode': 'DOC-1',
        'documentTitle': 'قرارداد',
        'fields': [
          {'field': 'عنوان', 'left': 'الف', 'right': 'ب', 'kind': 'changed'},
          {'field': 'وضعیت', 'left': 'تایید شده', 'right': 'تایید شده', 'kind': 'same'},
        ],
        'approvers': [
          {'field': 'محمد', 'left': 'در انتظار', 'right': 'تایید کرد', 'kind': 'changed'},
        ],
        'attachments': [],
        'between': [
          {
            'id': 1,
            'action': 'NewVersion',
            'detail': 'ورژن ۲',
            'userName': 'محمد',
            'createdAt': '2026-02-02T09:00:00',
          },
        ],
        'changeCount': 2,
      });
      expect(cmp.documentCode, 'DOC-1');
      expect(cmp.fields.length, 2);
      expect(cmp.fields.first.isChanged, isTrue);
      expect(cmp.fields.last.isChanged, isFalse);
      expect(cmp.approvers.first.rightCell, 'تایید کرد');
      expect(cmp.between.single.action, 'NewVersion');
      expect(cmp.changeCount, 2);
      expect(cmp.summaryFa, isNotEmpty);
    });

    test('سلول خالی به خط تیره تبدیل می‌شود', () {
      const row = DocDiffRow(field: 'توضیح', left: '', right: null);
      expect(row.leftCell, '—');
      expect(row.rightCell, '—');
    });

    test('برچسب نوع تغییر فارسی است', () {
      const changed = DocDiffRow(field: 'x', kind: 'changed');
      const added = DocDiffRow(field: 'x', kind: 'added');
      const removed = DocDiffRow(field: 'x', kind: 'removed');
      expect(changed.kindLabel, isNot('changed'));
      expect(added.kindLabel, isNot('added'));
      expect(removed.kindLabel, isNot('removed'));
    });

    test('آیین‌نامهٔ ورژن و اقدام‌ها', () {
      expect(DocVersionStatus.nameView(DocVersionStatus.draft), 'پیش‌نویس');
      expect(DocVersionStatus.nameView(DocVersionStatus.inReview), 'در گردش');
      expect(DocVersionStatus.nameView(DocVersionStatus.approved), 'تایید شده');
      expect(DocVersionStatus.nameView(DocVersionStatus.rejected), 'رد شده');
      expect(DocVersionStatus.nameView(DocVersionStatus.archived), 'بایگانی');
      expect(DocLogRow.actionName('NewVersion'), 'ورژن جدید');
      expect(DocLogRow.actionName('Approve'), 'تایید');
      expect(DocLogRow.actionName('Reject'), 'رد');
    });
  });

  group('آرشیو بخش ۳ — جستجوی هوشمند', () {
    test('اعتبارسنجی عبارت جستجو', () {
      expect(validateSemanticQuery(''), 'عبارت جستجو حداقل ۲ حرف باشد.');
      expect(validateSemanticQuery('گ'), 'عبارت جستجو حداقل ۲ حرف باشد.');
      expect(validateSemanticQuery('ا ب'), isNull);
      expect(
        validateSemanticQuery('x' * 501),
        'عبارت جستجو خیلی طولانی است.',
      );
    });

    test('نتیجهٔ معنایی و حالت برچسب', () {
      final r = DocSemanticResult.fromJson({
        'semantic': true,
        'note': 'با بردار معنایی',
        'totalCandidates': 40,
        'hits': [
          {
            'documentId': 8,
            'code': 'DOC-8',
            'title': 'قرارداد نگهداری',
            'folderName': 'قراردادها',
            'snippet': 'نگهداری تجهیزات',
            'score': 0.87,
            'myLevel': 3,
            'tags': [
              {'id': 1, 'name': 'مالی', 'color': '#2547a8'},
            ],
          },
        ],
      });
      expect(r.semantic, isTrue);
      expect(r.modeLabel, 'معنایی');
      expect(r.totalCandidates, 40);
      expect(r.hits.single.documentId, 8);
      expect(r.hits.single.score, closeTo(0.87, 0.001));
      expect(r.hits.single.tags.single.name, 'مالی');
    });

    test('نتیجهٔ کلیدواژه‌ای', () {
      final r = DocSemanticResult.fromJson({'semantic': false, 'hits': []});
      expect(r.modeLabel, 'کلیدواژه‌ای');
      expect(r.hits, isEmpty);
    });

    test('فیلتر جستجوی پیشرفته فقط مقادیر پرشده را می‌فرستد', () {
      final j = DocSearchFilter(
        search: ' قرارداد ',
        contentSearch: '   ',
        fileTypes: const ['pdf'],
        tagIds: const [2],
      ).toJson();
      expect(j['search'], 'قرارداد');
      expect(j.containsKey('contentSearch'), isFalse);
      expect(j['fileTypes'], ['pdf']);
      expect(j['tagIds'], [2]);
      expect(j['status'], 'active');
      expect(j['expiryStatus'], 'all');
    });

    test('پنج نوع فایل جستجو', () {
      expect(kDocFileTypes.length, 5);
      expect(
        kDocFileTypes.map((e) => e.value).toList(),
        ['PDF', 'Word', 'Excel', 'تصویر', 'متن'],
      );
    });

    test('درخواست معنایی مقادیر پیش‌فرض را نگه می‌دارد', () {
      final j = const DocSemanticRequest(query: 'قرارداد').toJson();
      expect(j['query'], 'قرارداد');
      expect(j['take'], 15);
      expect(j['status'], 'active');
      expect(j['includeSubfolders'], true);
    });
  });
}
