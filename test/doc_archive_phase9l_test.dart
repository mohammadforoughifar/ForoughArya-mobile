// تست‌های فاز ۹-ل — ارتباط آرشیو با دستور کار و اتوماسیون،
// گفتگو با سند، دسترسی موقت، پیگیری تمدید و صف پردازش فایل‌ها

import 'package:flutter_test/flutter_test.dart';

import 'package:forough_mobile/features/it_assets/models/doc_archive_models.dart';

void main() {
  group('آرشیو ۹-ل — گفتگو با سند', () {
    test('اعتبارسنجی پرسش خالی', () {
      expect(validateDocChatQuestion('   '), 'پرسش را بنویسید.');
      expect(validateDocChatQuestion('خلاصهٔ سند'), isNull);
    });

    test('بدنهٔ درخواست با تاریخچه', () {
      final j = DocChatRequest(
        question: ' مبلغ‌ها چیست؟ ',
        history: const [
          DocChatTurn(role: 'user', text: 'سلام'),
          DocChatTurn(role: 'assistant', text: 'بله'),
        ],
      ).toJson();
      expect(j['question'], 'مبلغ‌ها چیست؟');
      expect((j['history'] as List).length, 2);
      expect((j['history'] as List).first['role'], 'user');
    });

    test('سه حالت پاسخ و متن‌های فارسی', () {
      final ai = DocChatAnswer.fromJson({
        'answer': 'مبلغ ۱۰ میلیون است.',
        'mode': 'ai',
        'hasText': true,
        'sources': ['قرارداد.pdf'],
      });
      expect(ai.modeLabel, 'پاسخ با هوش مصنوعی');
      expect(ai.sources.single, 'قرارداد.pdf');
      expect(ai.hasText, isTrue);

      final ret = DocChatAnswer.fromJson({'answer': 'x', 'mode': 'retrieval'});
      expect(ret.modeLabel, 'پاسخ از متن سند');

      final none = DocChatAnswer.fromJson({'mode': 'notext'});
      expect(none.modeLabel, 'متن استخراج نشده');
      expect(none.modeHint, contains('متنی استخراج نشده'));
    });

    test('پاسخ خالی امن است', () {
      const a = DocChatAnswer();
      expect(a.answer, '');
      expect(a.sources, isEmpty);
    });
  });

  group('آرشیو ۹-ل — دسترسی موقت', () {
    test('وضعیت فعال/لغو/منقضی', () {
      final active = DocTemporaryGrant.fromJson({
        'id': 1,
        'userId': 5,
        'userName': 'محمد',
        'canDownload': true,
        'expiresAtUtc': DateTime.now()
            .toUtc()
            .add(const Duration(days: 3))
            .toIso8601String(),
      });
      expect(active.statusFa, 'فعال');
      expect(active.canDownload, isTrue);
      expect(active.isExpired, isFalse);

      final revoked = DocTemporaryGrant.fromJson({
        'expiresAtUtc': DateTime.now()
            .toUtc()
            .add(const Duration(days: 3))
            .toIso8601String(),
        'revokedAtUtc': DateTime.now().toUtc().toIso8601String(),
      });
      expect(revoked.statusFa, 'لغوشده');

      final expired = DocTemporaryGrant.fromJson({
        'expiresAtUtc': DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
      });
      expect(expired.statusFa, 'منقضی');
    });
  });

  group('آرشیو ۹-ل — پیگیری تمدید', () {
    test('سیاست پیش‌فرض و اعتبارسنجی مهلت', () {
      const p = DocRenewalPolicy();
      expect(p.enabled, isFalse);
      expect(p.leadDays, 30);
      expect(p.toJson()['leadDays'], 30);
      expect(validateRenewalLead(0), isNull);
      expect(validateRenewalLead(365), isNull);
      expect(validateRenewalLead(-1), 'مهلت بین صفر تا ۳۶۵ روز باشد.');
      expect(validateRenewalLead(400), 'مهلت بین صفر تا ۳۶۵ روز باشد.');
    });

    test('سفارش‌های تمدید و وضعیت فارسی', () {
      final p = DocRenewalPolicy.fromJson({
        'enabled': true,
        'assigneeUserId': 9,
        'leadDays': 15,
        'orders': [
          {'id': 1, 'number': 'WO-1', 'status': 'Closed'},
          {'id': 2, 'number': 'WO-2', 'status': 'Deleted'},
          {'id': 3, 'number': 'WO-3', 'status': 'Open'},
        ],
      });
      expect(p.enabled, isTrue);
      expect(p.leadDays, 15);
      expect(p.orders.map((o) => o.statusFa).toList(), [
        'بسته',
        'حذف‌شده',
        'باز',
      ]);
    });
  });

  group('آرشیو ۹-ل — ارتباط با دستور کار', () {
    test('ماژول مبدأ همان «Document» وب است', () {
      expect(kDocWoSourceModule, 'Document');
    });

    test('ردیف دستور کارِ مدرک', () {
      final rows = DocWorkOrderLink.listFrom([
        {
          'id': 7,
          'number': 'WO-100',
          'title': 'بررسی مدرک',
          'ownerName': 'محمد',
          'status': 'Open',
        },
        {'id': 8, 'number': 'WO-101', 'status': 'Closed'},
      ]);
      expect(rows.length, 2);
      expect(rows.first.number, 'WO-100');
      expect(rows.first.statusFa, 'باز');
      expect(rows.last.isClosed, isTrue);
      expect(DocWorkOrderLink.listFrom(null), isEmpty);
    });
  });

  group('آرشیو ۹-ل — صف پردازش فایل‌ها', () {
    test('شمارش‌ها و شکست‌ها', () {
      final q = DocIndexQueue.fromJson({
        'pending': 3,
        'working': 1,
        'failed': 2,
        'done': 10,
        'failures': [
          {'attachmentId': 5, 'fileName': 'a.pdf', 'error': 'متن خوانده نشد'},
        ],
      });
      expect(q.total, 16);
      expect(q.failures.single.attachmentId, 5);
      expect(q.failures.single.error, 'متن خوانده نشد');
    });
  });
}
