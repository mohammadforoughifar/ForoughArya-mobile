// آزمون فاز ۹-ب «درخواست خدمت IT» — آینه‌بودن مدل‌ها، متن‌ها و گیت‌ها

import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/auth/auth_session.dart';
import 'package:forough_mobile/features/it_assets/data/it_perms.dart';
import 'package:forough_mobile/features/it_assets/models/it_request_models.dart';

AuthSession session(List<String> permissions, {String role = 'User'}) =>
    AuthSession(
      userId: 7,
      token: 't',
      username: 'u',
      role: role,
      displayName: 'کاربر تست',
      permissions: permissions,
    );

void main() {
  group('ItRequestType / ItRequestStatus — متن‌های وب', () {
    test('نوع درخواست مثل TypeFa وب', () {
      expect(ItRequestType.label('Hardware'), 'سخت‌افزار');
      expect(ItRequestType.label('Software'), 'نرم‌افزار');
      expect(ItRequestType.label('Network'), 'شبکه و زیرساخت');
      expect(ItRequestType.label('Telecom'), 'مخابرات');
      expect(ItRequestType.all.length, 4);
    });

    test('برچسب وضعیت در نمای درخواست‌دهنده و کارتابل', () {
      expect(
        ItRequestStatus.label('New', requesterView: true),
        'ثبت شده',
      );
      expect(
        ItRequestStatus.label('Assigned', requesterView: true),
        'در حال بررسی',
      );
      expect(
        ItRequestStatus.label('Assigned', requesterView: false),
        'ارجاع شده',
      );
      expect(
        ItRequestStatus.label('ManagerApproved', requesterView: true),
        'در انتظار تایید شما',
      );
      expect(
        ItRequestStatus.label('ManagerApproved', requesterView: false),
        'پاسخ ارسال شده',
      );
      expect(ItRequestStatus.label('Completed'), 'تکمیل شده ✔');
      expect(ItRequestStatus.label('Rejected'), 'رد شده ✖');
    });
  });

  group('ItRequestItem — آیتم ToItem سرور', () {
    final json = {
      'id': 12,
      'number': 'IT-0412-25',
      'seen': false,
      'requesterName': 'رضا کریمی',
      'requesterUserId': 7,
      'systemLabel': 'PC-IT-01',
      'requestType': 'Network',
      'title': 'قطعی شبکه',
      'description': '<p>از دیروز</p>',
      'status': 'Assigned',
      'isExternal': true,
      'companyName': 'شعبه کرج',
      'companyCode': 'KRJ',
      'createdAt': '2026-11-09T08:15:00Z',
      'attachmentCount': 2,
      'assignments': [
        {
          'id': 4,
          'expertUserId': 9,
          'expertName': 'expert1',
          'reportSubmitted': true,
          'done': true,
          'managerDecision': 'Approved',
          'includeInFinal': true,
        },
        {'id': 5, 'expertUserId': 10, 'expertName': 'expert2'},
      ],
    };

    test('خواندن فیلدها و پرچم‌ها', () {
      final r = ItRequestItem.fromJson(json);
      expect(r.id, 12);
      expect(r.number, 'IT-0412-25');
      expect(r.isNew, isTrue); // seen=false → «جدید»
      expect(r.title, 'قطعی شبکه');
      expect(r.isExternal, isTrue);
      expect(r.companyName, 'شعبه کرج');
      expect(r.attachmentCount, 2);
      expect(r.assignments.length, 2);
      expect(r.reportsSubmitted, 1);
      expect(r.allReportsSubmitted, isFalse);
      expect(r.allApproved, isFalse);
      expect(r.open, isTrue); // Assigned → باز
      expect(r.managerNote, isNull);
    });

    test('همهٔ گزارش‌ها و تاییدها', () {
      final r = ItRequestItem.fromJson({
        'id': 1,
        'status': 'Completed',
        'assignments': [
          {'id': 1, 'reportSubmitted': true, 'managerDecision': 'Approved'},
          {'id': 2, 'reportSubmitted': true, 'managerDecision': 'Approved'},
        ],
      });
      expect(r.allReportsSubmitted, isTrue);
      expect(r.allApproved, isTrue);
      expect(r.open, isFalse);
    });

    test('ارجاع بدون تصمیم مدیر = در انتظار تصمیم', () {
      final a = ItAssignment.fromJson({
        'id': 3,
        'expertUserId': 9,
        'reportSubmitted': true,
        'done': false,
      });
      expect(a.pendingDecision, isTrue);
      expect(a.approved, isFalse);
      expect(a.done, isFalse);
    });
  });

  group('ItLogRow / ItAttachment — RoleFa و ActionFa وب', () {
    test('عنوان نقش و اقدام', () {
      final l = ItLogRow.fromJson({
        'id': 1,
        'actorName': 'مدیر',
        'actorRole': 'Manager',
        'action': 'Assigned',
        'text': 'ارجاع به: expert1',
        'createdAt': '2026-11-09T10:00:00Z',
      });
      expect(l.roleTitle, 'مدیر');
      expect(l.actionTitle, 'ارجاع');
      expect(
        ItLogRow.fromJson({'actorRole': 'Expert', 'action': 'Report'})
            .actionTitle,
        'ثبت گزارش',
      );
      expect(
        ItLogRow.fromJson({'actorRole': 'Requester', 'action': 'Created'})
            .roleTitle,
        'درخواست‌دهنده',
      );
    });

    test('پیوست و حجم فایل', () {
      final a = ItAttachment.fromJson({
        'id': 5,
        'fileName': 'log.txt',
        'uploaderRole': 'Expert',
        'uploaderName': 'expert1',
        'size': 2048,
      });
      expect(a.roleTitle, 'کارشناس');
      expect(a.sizeText, '۲.0 KB'.replaceAll('۲', '2'));
      final big = ItAttachment.fromJson({'size': 3 * 1024 * 1024});
      expect(big.sizeText, '3.0 MB');
    });
  });

  group('ItAccess / ItSystemOption / ItClientCompany', () {
    test('دسترسی از my-access', () {
      final a = ItAccess.fromJson({
        'userId': 7,
        'canCreate': true,
        'isExpert': false,
        'isManager': true,
      });
      expect(a.canCreate, isTrue);
      expect(a.isExpert, isFalse);
      expect(a.isManager, isTrue);
    });

    test('برچسب سیستم — مثل SysLabel وب', () {
      final s = ItSystemOption.fromJson({
        'id': 3,
        'label': 'PC-IT-01',
        'ip': '10.0.0.9',
        'userName': 'رضا',
        'departmentName': 'فنی',
      });
      expect(s.display, 'PC-IT-01 — رضا — فنی');
      final empty = ItSystemOption.fromJson({'id': 8, 'ip': '10.0.0.1'});
      expect(empty.display, '10.0.0.1');
    });

    test('شرکت راه‌دور', () {
      final c = ItClientCompany.fromJson({
        'id': 2,
        'code': 'KRJ',
        'name': 'شعبه کرج',
        'isActive': true,
        'hourlyLimit': 120,
        'requestCount': 5,
        'openCount': 2,
      });
      expect(c.code, 'KRJ');
      expect(c.hourlyLimit, 120);
      expect(c.requestCount, 5);
      expect(c.openCount, 2);
      expect(c.isActive, isTrue);
    });
  });

  group('ItPerms — گیت‌های هلدسک', () {
    test('ItRequests با مجوز مشاهده', () {
      expect(ItPerms(session([])).canSeeItRequests, isFalse);
      expect(ItPerms(session(['ItRequests.Read'])).canSeeItRequests, isTrue);
      expect(ItPerms(session(['ItRequests.Manage'])).canSeeItRequests, isTrue);
    });

    test('شرکت‌های راه‌دور فقط مدیر', () {
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

    test('مدیر همهٔ گروه‌ها را می‌بیند', () {
      final p = ItPerms(session(const [], role: 'Admin'));
      expect(p.canSeeItRequests, isTrue);
      expect(p.canSeeAdminGroup, isTrue);
    });
  });
}
