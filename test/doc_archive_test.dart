// آزمون فاز ۹-ح «آرشیو اسناد و مدارک» (بخش ۱: کاوشگر، مدرک، فرم و کارتابل)
// — آینه‌بودن مدل‌ها، سطح دسترسی، وضعیت نسخه، انقضا، کارتابل و اعتبارسنجی فرم

import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/features/it_assets/models/doc_archive_models.dart';

void main() {
  group('سطح دسترسی و وضعیت نسخه — متن‌های وب', () {
    test('پنج سطح با همان نام‌های وب', () {
      expect(DocLevel.name(0), 'ندارد');
      expect(DocLevel.name(1), 'مشاهده');
      expect(DocLevel.name(2), 'خواندن');
      expect(DocLevel.name(3), 'نوشتن');
      expect(DocLevel.name(4), 'کامل');
    });

    test('وضعیت نسخه در کاوشگر «در گردش (فریز)» و در مدرک «در گردش» است', () {
      expect(DocVersionStatus.nameExplorer(0), 'پیش‌نویس');
      expect(DocVersionStatus.nameExplorer(1), 'در گردش (فریز)');
      expect(DocVersionStatus.nameExplorer(2), 'تایید شده');
      expect(DocVersionStatus.nameExplorer(3), 'رد شده');
      expect(DocVersionStatus.nameExplorer(4), 'بایگانی');
      expect(DocVersionStatus.nameView(1), 'در گردش');
    });
  });

  group('پوشه — DocFolder', () {
    test('فیلدها از JSON سرور خوانده می‌شوند', () {
      final f = DocFolder.fromJson({
        'id': 12,
        'parentId': 4,
        'name': 'قراردادها',
        'description': 'قراردادهای جاری',
        'documentCount': 27,
        'myLevel': 4,
        'myCanDownload': true,
        'isActive': true,
      });
      expect(f.id, 12);
      expect(f.parentId, 4);
      expect(f.documentCount, 27);
      expect(f.levelName, 'کامل');
      expect(f.canWrite, isTrue);
      expect(f.titleWithLevel, 'قراردادها (کامل)');
    });

    test('دسترسی «مشاهده» اجازهٔ نوشتن نمی‌دهد', () {
      final f = DocFolder.fromJson({'id': 1, 'name': 'x', 'myLevel': 1});
      expect(f.canWrite, isFalse);
    });

    test('مسیر پوشه‌ها از والد تا فرزند ساخته می‌شود', () {
      final all = [
        DocFolder.fromJson({'id': 1, 'name': 'ریشه'}),
        DocFolder.fromJson({'id': 2, 'name': 'حقوقی', 'parentId': 1}),
        DocFolder.fromJson({'id': 3, 'name': 'قرارداد', 'parentId': 2}),
      ];
      expect(folderPathText(all, 3), 'ریشه / حقوقی / قرارداد');
      expect(folderPathText(all, 1), 'ریشه');
    });
  });

  group('ردیف مدرک — DocRow', () {
    DocRow row({
      int? days,
      bool expired = false,
      bool active = true,
      int level = 2,
      int versionCount = 0,
      int activeVersionNo = 0,
    }) => DocRow.fromJson({
      'id': 7,
      'code': 'DOC-001',
      'title': 'قرارداد اجاره انبار',
      'folderId': 3,
      'folderName': 'قراردادها',
      'daysToExpire': days,
      'isExpired': expired,
      'isActive': active,
      'myLevel': level,
      'versionCount': versionCount,
      'activeVersionNo': activeVersionNo,
      'tags': [
        {'id': 1, 'name': 'مهم', 'color': '#e11d48'},
      ],
    });

    test('سرنخ انقضا با همان متن وب: «N روز» / «N روز گذشته» / «امروز»', () {
      expect(row(days: 30).expiryText, '۳۰ روز');
      expect(row(days: 0).expiryText, 'امروز');
      expect(row(days: -5, expired: true).expiryText, '۵ روز گذشته');
      expect(row().expiryText, '');
    });

    test('نسخه‌ها: «N نسخه» و «vN»', () {
      expect(row(versionCount: 3, activeVersionNo: 2).versionsText, '۳ نسخه');
      expect(row(versionCount: 3, activeVersionNo: 2).activeVersionText, 'v۲');
      expect(row().versionsText, '—');
      expect(row().activeVersionText, '—');
    });

    test('سطح دسترسی و جای‌خالی‌ها', () {
      expect(row(level: 4).levelName, 'کامل');
      expect(row().customerCodeCell, '—');
      expect(row().folderCell, 'قراردادها');
      expect(row().tags.single.name, 'مهم');
    });

    test('مدرک غیرفعال و در سطل پرچم درست دارند', () {
      final d = DocRow.fromJson({
        'id': 9,
        'isActive': false,
        'deactivateReason': 'منقضی شد',
        'isDeleted': true,
      });
      expect(d.isActive, isFalse);
      expect(d.deactivateReason, 'منقضی شد');
      expect(d.isDeleted, isTrue);
    });

    test('صفحه‌بندی: hasNext بر اساس total', () {
      final p = DocPage.documents({
        'total': 80,
        'page': 1,
        'pageSize': 30,
        'items': [
          {'id': 1, 'title': 'a'},
          {'id': 2, 'title': 'b'},
        ],
      });
      expect(p.total, 80);
      expect(p.items.length, 2);
      expect(p.hasNext, isTrue);
      final last = DocPage.documents({
        'total': 80,
        'page': 3,
        'pageSize': 30,
        'items': const [],
      });
      expect(last.hasNext, isFalse);
    });
  });

  group('آمار آرشیو — DocArchiveStats', () {
    test('چهار شمارندهٔ وب', () {
      final s = DocArchiveStats.fromJson({
        'inactive': 4,
        'deleted': 2,
        'expired': 7,
        'expiring': 3,
      });
      expect(s.inactive, 4);
      expect(s.deleted, 2);
      expect(s.expired, 7);
      expect(s.expiring, 3);
    });

    test('پاسخ خالی صفر می‌شود', () {
      final s = DocArchiveStats.fromJson({});
      expect(s.inactive + s.deleted + s.expired + s.expiring, 0);
    });
  });

  group('کارتابل آرشیو — DocCartableItem', () {
    DocCartableItem item({String kind = 'Approval', int status = 0}) =>
        DocCartableItem.fromJson({
          'id': 3,
          'kind': kind,
          'documentId': 21,
          'documentCode': 'DOC-021',
          'documentTitle': 'صورتجلسه هیئت مدیره',
          'versionNo': 2,
          'title': 'اعلان ورژن جدید',
          'status': status,
          'createdAt': '2026-02-01T10:00:00',
        });

    test('چهار نوع کار با همان برچسب‌های وب', () {
      expect(item(kind: 'Approval').kindLabel, 'تایید ورژن');
      expect(item(kind: 'RelatedUpdate').kindLabel, 'به‌روزرسانی مرتبط');
      expect(item(kind: 'ExpiryAlert').kindLabel, 'هشدار انقضا');
      expect(item(kind: 'VersionNotice').kindLabel, 'اعلان ورژن');
    });

    test('وضعیت‌ها: در انتظار / انجام شد / رد شد', () {
      expect(item(status: 0).statusLabel, 'در انتظار');
      expect(item(status: 1).statusLabel, 'انجام شد');
      expect(item(status: 2).statusLabel, 'رد شد');
    });

    test('فقط کارهای غیرتاییدی باز قابل بستن دستی‌اند', () {
      expect(item(kind: 'Approval', status: 0).canClose, isFalse);
      expect(item(kind: 'RelatedUpdate', status: 0).canClose, isTrue);
      expect(item(kind: 'RelatedUpdate', status: 1).canClose, isFalse);
    });

    test('نسخه: «v2» یا «—»', () {
      expect(item().versionText, 'v۲');
      expect(
        DocCartableItem.fromJson({'id': 1, 'versionNo': 0}).versionText,
        '—',
      );
    });
  });

  group('ستاره‌دار و اخیراً دیده‌شده', () {
    test('ستاره‌دار فیلدهای مدرک را نگه می‌دارد', () {
      final f = DocFavorite.fromJson({
        'documentId': 5,
        'code': 'DOC-005',
        'title': 'بیمه‌نامه',
        'folderId': 2,
        'folderName': 'بیمه',
        'favoritedAt': '2026-01-11T09:00:00',
        'isFavorite': true,
      });
      expect(f.documentId, 5);
      expect(f.folderCell, 'بیمه');
      expect(f.isFavorite, isTrue);
    });

    test('اخیراً دیده‌شده پوشهٔ خالی را «—» می‌کند', () {
      final r = DocRecent.fromJson({'documentId': 6, 'title': 'x'});
      expect(r.folderCell, '—');
      expect(r.action, 'View');
    });
  });

  group('اعتبارسنجی فرم مدرک — همان ترتیب و پیام‌های وب', () {
    test('عنوان خالی', () {
      expect(
        validateDocForm(
          title: '   ',
          code: 'DOC-1',
          numberingEnabled: false,
          isNew: true,
          folderId: 1,
        ),
        'عنوان مدرک اجباری است.',
      );
    });

    test('کد خالی بدون شماره‌گذار خودکار', () {
      expect(
        validateDocForm(
          title: 'قرارداد',
          code: '',
          numberingEnabled: false,
          isNew: true,
          folderId: 1,
        ),
        'کد مدرک اجباری است.',
      );
    });

    test('کد خالی در ساخت با شماره‌گذار فعال مجاز است', () {
      expect(
        validateDocForm(
          title: 'قرارداد',
          code: '',
          numberingEnabled: true,
          isNew: true,
          folderId: 1,
        ),
        isNull,
      );
    });

    test('کد خالی در ویرایش حتی با شماره‌گذار فعال اجباری است', () {
      expect(
        validateDocForm(
          title: 'قرارداد',
          code: '',
          numberingEnabled: true,
          isNew: false,
          folderId: 1,
        ),
        'کد مدرک اجباری است.',
      );
    });

    test('پوشه انتخاب‌نشده', () {
      expect(
        validateDocForm(
          title: 'قرارداد',
          code: 'DOC-1',
          numberingEnabled: false,
          isNew: true,
          folderId: 0,
        ),
        'پوشه مدرک را انتخاب کنید.',
      );
    });

    test('فرم معتبر خطا ندارد', () {
      expect(
        validateDocForm(
          title: 'قرارداد',
          code: 'DOC-9',
          numberingEnabled: false,
          isNew: true,
          folderId: 3,
        ),
        isNull,
      );
    });
  });

  group('ورودی ذخیرهٔ مدرک — DocSaveInput', () {
    test('ترتیب تأییدکنندگان به order تبدیل می‌شود', () {
      const input = DocSaveInput(
        folderId: 2,
        title: '  قرارداد  ',
        code: ' DOC-7 ',
        approvers: [11, 9, 4],
        tagIds: [3, 1],
        isPublic: true,
        publicCanDownload: true,
        expireDate: null,
      );
      final j = input.toJson();
      expect(j['title'], 'قرارداد');
      expect(j['code'], 'DOC-7');
      final approvers = j['approvers'] as List;
      expect(approvers.length, 3);
      expect((approvers[0] as Map)['userId'], 11);
      expect((approvers[0] as Map)['order'], 0);
      expect((approvers[2] as Map)['userId'], 4);
      expect((approvers[2] as Map)['order'], 2);
      expect(j['tagIds'], [3, 1]);
      expect(j['publicCanDownload'], isTrue);
    });

    test('بدون «نمایش برای همه»، دانلود عمومی ارسال نمی‌شود', () {
      const input = DocSaveInput(
        folderId: 1,
        title: 'x',
        code: 'c',
        isPublic: false,
        publicCanDownload: true,
      );
      expect(input.toJson()['publicCanDownload'], isFalse);
    });
  });

  group('داده‌های کمکی — DocLookups', () {
    test('کاربران، مدارک، نقش‌ها و شماره‌گذار خوانده می‌شوند', () {
      final l = DocLookups.fromJson({
        'users': [
          {'id': 1, 'name': 'علی رضایی', 'avatarUrl': '/uploads/a.png'},
        ],
        'documents': [
          {'id': 8, 'name': 'DOC-008 — بیمه‌نامه (مشتری: 12)'},
        ],
        'roles': [
          {'id': 3, 'name': 'مدیر آرشیو'},
        ],
        'codeNumberingEnabled': true,
      });
      expect(l.users.single.name, 'علی رضایی');
      expect(l.documents.single.id, 8);
      expect(l.roles.single.name, 'مدیر آرشیو');
      expect(l.codeNumberingEnabled, isTrue);
    });
  });
}
