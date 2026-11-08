// ============================================================
//  تست ماژول اتوماسیون اداری
//  نگاشت DTOهای بک‌اند → مدل‌های Dart با کلیدهای PascalCase و camelCase
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/features/office_automation/data/office_repository.dart';
import 'package:forough_mobile/features/office_automation/models/letter_models.dart';
import 'package:forough_mobile/features/office_automation/models/office_common.dart';

void main() {
  group('قرارداد پاسخ صفحه‌بندی سرور', () {
    test('آرایهٔ ساده → همهٔ آیتم‌ها', () {
      final paged = Paged<LetterListItem>.fromJson([
        {'title': 'الف', 'letterId': 1},
        {'title': 'ب', 'letterId': 2},
      ], LetterListItem.fromJson);
      expect(paged.items.length, 2);
      expect(paged.items.first.title, 'الف');
    });

    test('{total, items} → شمارش کل حفظ می‌شود', () {
      final paged = Paged<LetterListItem>.fromJson({
        'total': 45,
        'items': [
          {'title': 'نامهٔ یک', 'letterId': 7},
        ],
      }, LetterListItem.fromJson);
      expect(paged.totalCount, 45);
      expect(paged.items.single.letterId, 7);
    });

    test('{items, totalCount, page, pageSize} → مسیرهای قدیمی', () {
      final paged = Paged<LetterListItem>.fromJson({
        'items': [],
        'totalCount': 10,
        'page': 2,
        'pageSize': 5,
      }, LetterListItem.fromJson);
      expect(paged.totalCount, 10);
      expect(paged.page, 2);
      expect(paged.pageCount, 2);
    });
  });

  group('نامهٔ داخلی', () {
    final json = {
      'letterId': 12,
      'letterNumber': '1405/د-12',
      'title': 'بازبینی قرارداد توسعه',
      'text': 'متن نامه',
      'mahramanegi': 'محرمانه',
      'foriat': 'فوری',
      'dateSabt': '2026-11-01T09:30:00',
      'senderUserId': 5,
      'senderName': 'محمد فروغی',
      'reciversGirande': [
        {'userId': 7, 'fullName': 'علی رضایی', 'positions': ['کارشناس قراردادها']},
      ],
      'reciversErja': [
        {'userId': 8, 'fullName': 'مریم احمدی'},
      ],
      'reciversHamesh': [],
      'relatedLetters': [
        {'related': 2, 'relateLetterId': 3, 'relateLetterTitle': 'نامهٔ اصلی'},
      ],
      'myErja': {'erjaId': 55, 'senderName': 'محمد فروغی', 'isRead': false},
      'isMine': false,
      'canEdit': true,
    };

    test('فیلدها و گیرندگان درست خوانده می‌شوند', () {
      final d = InnerLetterDetail.fromJson(json);
      expect(d.letterId, 12);
      expect(d.letterNumber, '1405/د-12');
      expect(d.mahramanegi, 'محرمانه');
      expect(d.girande.single.fullName, 'علی رضایی');
      expect(d.erja.single.userId, 8);
      expect(d.relatedLetters.single.kindLabel, 'عطف');
      expect(d.myErja!.erjaId, 55);
      expect(d.canEdit, isTrue);
    });

    test('کلیدهای PascalCase هم پشتیبانی می‌شوند', () {
      final d = InnerLetterDetail.fromJson({
        'LetterId': 9,
        'Title': 'نامهٔ Pascal',
        'ReciversGirande': [
          {'UserId': 3, 'FullName': 'کاربر سه'},
        ],
      });
      expect(d.letterId, 9);
      expect(d.title, 'نامهٔ Pascal');
      expect(d.girande.single.userId, 3);
    });
  });

  group('نامهٔ صادره', () {
    test('گیرندهٔ بیرونی، وضعیت و نوبت امضا', () {
      final d = OutgoingLetterDetail.fromJson({
        'letterId': 40,
        'title': 'اعلام شرایط همکاری',
        'receiverOrganization': 'شرکت پارس فناور',
        'receiverName': 'رضا کریمی',
        'receiverTitle': 'مدیرعامل',
        'status': 2,
        'sadereNumber': null,
        'signers': [
          {'id': 1, 'userId': 10, 'userName': 'مدیرعامل', 'order': 1, 'isSigned': true},
          {'id': 2, 'userId': 11, 'userName': 'مدیر مالی', 'order': 2, 'isSigned': false, 'isMe': true},
        ],
        'dabirkhaneSabt': false,
      });
      expect(d.receiverOrganization, 'شرکت پارس فناور');
      expect(d.statusLabel, 'تأیید شده');
      expect(d.isIssued, isFalse);
      expect(d.signers.length, 2);
      expect(d.isMyTurnToSign, isTrue, reason: 'کاربر جاری نفر دوم و پس از امضای اولی است');
    });

    test('بعد از صدور، شمارهٔ صادره و دبیرخانه دیده می‌شود', () {
      final d = OutgoingLetterDetail.fromJson({
        'letterId': 41,
        'title': 'نامهٔ صادرشده',
        'status': 3,
        'sadereNumber': '1405/ص-88',
        'receiverOrganization': 'سازمان مقصد',
        'dabirkhaneSabt': true,
        'sendMethod': 'پست پیشتاز',
        'trackingCode': 'IR123456',
        'destRegNumber': '556',
      });
      expect(d.isIssued, isTrue);
      expect(d.sadereNumber, '1405/ص-88');
      expect(d.dabirkhaneSabt, isTrue);
      expect(d.trackingCode, 'IR123456');
      expect(d.isMyTurnToSign, isFalse);
    });
  });

  group('نامهٔ وارده', () {
    test('فرستنده و شمارهٔ نامهٔ مبدأ', () {
      final j = {
        'id': 3,
        'title': 'معرفی‌نامه',
        'ferestande': 'شرکت پارس فناور',
        'numberLetterVarede': 'PT-9912',
        'foriat': 2,
        'mahramanegi': 1,
        'deliveryName': 'آقای رضایی',
      };
      expect(pickStr(j, ['ferestande', 'Ferestande']), 'شرکت پارس فناور');
      expect(pickStr(j, ['numberLetterVarede']), 'PT-9912');
      expect(pickInt(j, ['foriat', 'Foriat']), 2);
      expect(pickInt(j, ['mahramanegi']), 1);
      expect(pickStr(j, ['deliveryName']), 'آقای رضایی');
    });
  });

  group('ارجاع و گردش', () {
    test('درخت گردش با فرزندان', () {
      final n = GardeshNode.fromJson({
        'erjaId': 1,
        'sender': 'مدیر',
        'reciver': 'کارشناس',
        'type': 'گیرنده',
        'matnErja': 'جهت اقدام',
        'isRead': true,
        'children': [
          {'erjaId': 2, 'sender': 'کارشناس', 'reciver': 'کارپرداز', 'type': 'ارجاع'},
        ],
      });
      expect(n.children.single.erjaId, 2);
      expect(n.matnErja, 'جهت اقدام');
      expect(n.isRead, isTrue);
    });

    test('وضعیت تأیید به برچسب فارسی نگاشت می‌شود', () {
      expect(ErjaItem.fromJson({'typeTaeed': 1}).taeedLabel, 'تأیید');
      expect(ErjaItem.fromJson({'typeTaeed': 2}).taeedLabel, 'رد');
      expect(ErjaItem.fromJson({'typeTaeed': 0}).taeedLabel, 'بدون اقدام');
    });
  });

  group('مسیرهای API مطابق کنترلرهای بک‌اند', () {
    test('ریشهٔ هر نوع نامه', () {
      expect(LetterKind.inner.root, '/api/letters');
      expect(LetterKind.outgoing.root, '/api/outgoing-letters');
      expect(LetterKind.incoming.root, '/api/incoming-letters');
      expect(LetterKind.inner.label, 'نامه داخلی');
    });

    test('ثابت‌های دامنه مطابق مدل‌های C#', () {
      expect(OfficeConst.sourceInner, 1);
      expect(OfficeConst.sourceOutgoing, 2);
      expect(OfficeConst.sourceIncoming, 3);
      expect(OfficeConst.outgoingStatus[3], 'صادر شده');
      expect(OfficeConst.sendMethods.contains('پست پیشتاز'), isTrue);
      expect(OfficeConst.erjaTypes, containsAll(['گیرنده', 'ارجاع', 'هامش']));
    });
  });

  group('بایگانی درختی', () {
    test('پوشه و برگ نامه', () {
      final root = ArchiveNode.fromJson({
        'bayeganiId': 1,
        'title': 'قراردادهای ۱۴۰۵',
        'isFolder': true,
        'parentId': 0,
        'children': [
          {
            'bayeganiId': 2,
            'title': 'نمونهٔ نامه',
            'isFolder': false,
            'letterId': 12,
            'letterNumber': '1405/د-12',
            'sourceType': 2,
            'receiverOrganization': 'شرکت مقصد',
          },
        ],
      });
      expect(root.isFolder, isTrue);
      expect(root.children.single.isFolder, isFalse);
      expect(root.children.single.receiverOrganization, 'شرکت مقصد');
    });
  });
}
