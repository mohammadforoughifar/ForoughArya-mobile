// آزمون فاز ۹-ط «آرشیو اسناد — بخش ۲»
// عملیات گروهی، سطل بازیافت، دسترسی و برچسب‌ها — با همان متن‌های وب

import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/features/it_assets/data/doc_archive_repository.dart';
import 'package:forough_mobile/features/it_assets/models/doc_archive_models.dart';

void main() {
  group('نتیجهٔ عملیات گروهی — DocBulkResult', () {
    test('پیام و شمارش‌ها از سرور خوانده می‌شوند', () {
      final r = DocBulkResult.fromJson({
        'requested': 5,
        'succeeded': 3,
        'failed': 2,
        'errors': ['DOC-1: دسترسی نوشتن ندارید.', 'DOC-2: در گردش است.'],
        'message': '۳ مدرک منتقل شد. ۲ مورد خطا.',
      });
      expect(r.requested, 5);
      expect(r.succeeded, 3);
      expect(r.failed, 2);
      expect(r.errors.length, 2);
      expect(r.message, '۳ مدرک منتقل شد. ۲ مورد خطا.');
    });

    test('نمایش، پیام را با سه خطای اول ترکیب می‌کند', () {
      final r = DocBulkResult.fromJson({
        'requested': 4,
        'succeeded': 1,
        'failed': 3,
        'errors': ['a', 'b', 'c', 'd'],
        'message': '۱ مدرک منتقل شد.',
      });
      final lines = r.display.split('\n');
      expect(lines.first, '۱ مدرک منتقل شد.');
      expect(lines.length, 4); // پیام + سه خطا
      expect(lines.contains('d'), isFalse);
    });

    test('بدون خطا فقط پیام برمی‌گردد', () {
      final r = DocBulkResult.fromJson({
        'requested': 2,
        'succeeded': 2,
        'message': '۲ مدرک برچسب‌گذاری شد.',
      });
      expect(r.display, '۲ مدرک برچسب‌گذاری شد.');
    });

    test('پیام خالی با شمارش جایگزین می‌شود', () {
      final r = DocBulkResult.fromJson({
        'requested': 3,
        'succeeded': 2,
        'failed': 1,
      });
      expect(r.display, '2 از 3 مورد انجام شد.');
    });

    test('errors تهی امن است', () {
      final r = DocBulkResult.fromJson({'requested': 1, 'succeeded': 1});
      expect(r.errors, isEmpty);
      expect(r.failed, 0);
    });
  });

  group('متن‌های ثابت عملیات گروهی', () {
    test('دو حالت برچسب گروهی: افزودن / جایگزینی', () {
      expect(kDocBulkTagModes.length, 2);
      expect(kDocBulkTagModes[0].value, 'افزودن');
      expect(kDocBulkTagModes[0].key, DocBulkTagMode.append);
      expect(kDocBulkTagModes[1].value, 'جایگزینی');
      expect(kDocBulkTagModes[1].key, DocBulkTagMode.replace);
    });

    test('هشدار انتقال گروهی عیناً همان وب است', () {
      expect(
        kBulkMoveWarning,
        'فقط مدارکی که روی آن‌ها دسترسی نوشتن دارید منتقل می‌شوند؛ بقیه رد می‌شوند.',
      );
    });

    test('هشدار حذف قطعی و عبارت تایید', () {
      expect(
        kPurgeWarning,
        'این عملیات برگشت‌ناپذیر است. مدرک به‌همراه کلیه ورژن‌ها، پیوست‌ها، دسترسی‌ها و تاریخچه به‌صورت قطعی از دیتابیس پاک خواهد شد.',
      );
      expect(kPurgePhrase, 'حذف قطعی');
    });

    test('متن تایید حذف گروهی با شمارش', () {
      expect(
        bulkDeleteConfirmText(4),
        'آیا 4 مدرک انتخاب‌شده به سطل بازیافت منتقل شود؟',
      );
    });

    test('پالت رنگ برچسب‌ها با رنگ پیش‌فرض وب شروع می‌شود', () {
      expect(kTagPalette.first, '#4f46e5');
      expect(kTagPalette.length, greaterThan(5));
    });

    test('اعتبارسنجی نام برچسب — عیناً پیام سرور', () {
      expect(validateTagName(''), 'نام تگ اجباری است.');
      expect(validateTagName('   '), 'نام تگ اجباری است.');
      expect(validateTagName('قرارداد مالی'), isNull);
    });
  });

  group('دسترسی — DocPermissionInput', () {
    test('ردیف فردی بدون نقش ارسال می‌شود', () {
      const p = DocPermissionInput(userId: 7, level: DocLevel.write, canDownload: true);
      final j = p.toJson();
      expect(j['userId'], 7);
      expect(j['roleId'], 0);
      expect(j['level'], 3);
      expect(j['canDownload'], isTrue);
      expect(p.isRole, isFalse);
    });

    test('ردیف گروهی با نقش و کاربر صفر', () {
      const p = DocPermissionInput(roleId: 3, level: DocLevel.full);
      final j = p.toJson();
      expect(j['userId'], 0);
      expect(j['roleId'], 3);
      expect(j['level'], 4);
      expect(p.isRole, isTrue);
    });

    test('پیش‌فرض سطح «خواندن» است', () {
      const p = DocPermissionInput(userId: 1);
      expect(p.level, DocLevel.read);
      expect(p.canDownload, isFalse);
    });
  });

  group('آرشیو — حالت‌های انتخاب و سطل', () {
    test('مدرک در سطل، تاریخ حذف و حذف‌کننده را نگه می‌دارد', () {
      final d = DocRow.fromJson({
        'id': 3,
        'code': 'DOC-003',
        'title': 'بیمه‌نامه منقضی',
        'isDeleted': true,
        'deletedAt': '2026-03-01T12:00:00',
        'deletedByName': 'مدیر آرشیو',
        'isActive': false,
      });
      expect(d.isDeleted, isTrue);
      expect(d.deletedByName, 'مدیر آرشیو');
      expect(d.deletedAt, isNotNull);
    });

    test('مدرک غیرفعال با دلیل و تاریخ غیرفعال‌سازی', () {
      final d = DocRow.fromJson({
        'id': 4,
        'isActive': false,
        'deactivatedAt': '2026-03-02T09:00:00',
        'deactivatedByName': 'کارشناس',
        'deactivateReason': 'منسوخ شده و با مدرک جدید جایگزین گردید',
      });
      expect(d.isActive, isFalse);
      expect(d.deactivateReason, 'منسوخ شده و با مدرک جدید جایگزین گردید');
      expect(d.deactivatedByName, 'کارشناس');
    });

    test('سطح «کامل» شرط مدیریت دسترسی است', () {
      expect(DocLevel.name(4), 'کامل');
      final f = DocFolder.fromJson({'id': 1, 'myLevel': 4});
      expect(f.canWrite, isTrue);
      final g = DocFolder.fromJson({'id': 2, 'myLevel': 3});
      expect(g.canWrite, isTrue);
      final h = DocFolder.fromJson({'id': 3, 'myLevel': 2});
      expect(h.canWrite, isFalse);
    });
  });
}
