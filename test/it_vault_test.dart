// آزمون فاز ۹-ه «گاوصندوق رمزهای تجهیزات» — آینه‌بودن مدل‌ها، اعتبارسنجی،
// برچسب‌های فارسی، ساخت رمز قوی و سنجش قدرت با وب

import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/features/it_assets/models/vault_models.dart';

void main() {
  group('گاوصندوق — انواع تجهیز', () {
    test('شش نوع تجهیز وب با همان عنوان‌ها', () {
      expect(kVaultCategories.length, 6);
      expect(
        kVaultCategories.map((c) => c.key).toList(),
        ['Server', 'Switch', 'Mikrotik', 'Firewall', 'System', 'Other'],
      );
      expect(vaultCat('Server').title, 'سرور');
      expect(vaultCat('Switch').title, 'سوییچ منیجبل');
      expect(vaultCat('Mikrotik').title, 'میکروتیک');
      expect(vaultCat('Firewall').title, 'فایروال');
      expect(vaultCat('System').title, 'سامانه');
      expect(vaultCat('Other').title, 'سایر');
      expect(vaultCat('نامعتبر').key, 'Other');
    });

    test('راهنمای عنوان و پورت هر نوع مثل وب', () {
      expect(vaultCat('Server').titleHint, 'مثلاً: سرور فایل / DC01');
      expect(vaultCat('Server').portHint, '22 / 3389');
      expect(vaultCat('Mikrotik').portHint, '8291');
      expect(vaultCat('Firewall').portHint, '443');
      expect(vaultCat('Other').portHint, '');
    });

    test('یازده روش اتصال وب', () {
      expect(kVaultAccessMethods.length, 11);
      expect(kVaultAccessMethods.first, 'SSH');
      expect(kVaultAccessMethods.contains('Winbox'), isTrue);
      expect(kVaultAccessMethods.contains('SFTP'), isTrue);
    });
  });

  group('گاوصندوق — ردیف', () {
    final row = VaultRow.fromJson({
      'id': 5,
      'companyId': 2,
      'category': 'Switch',
      'title': 'سوییچ کور',
      'host': '10.0.0.2',
      'port': 22,
      'accessMethod': 'SSH',
      'url': 'https://10.0.0.2',
      'username': 'admin',
      'hasPassword': true,
      'hasExtraSecret': true,
      'location': 'رک اتاق سرور',
      'notes': 'پورت uplink 24',
      'isActive': true,
      'passwordChangedAt': '2026-02-01T09:30:00',
      'updatedByName': 'مریم',
    });

    test('فیلدها و متن آدرس', () {
      expect(row.meta.title, 'سوییچ منیجبل');
      expect(row.hostText, '10.0.0.2:22');
      expect(row.addressCell, '10.0.0.2:22');
      expect(row.hasPassword, isTrue);
      expect(row.hasExtraSecret, isTrue);
      expect(row.passwordChangedAt, isNotNull);
      expect(row.updatedByName, 'مریم');
    });

    test('بدون host، آدرس = url و در نبود هر دو «—»', () {
      final a = VaultRow.fromJson({'url': 'https://panel.ir', 'category': 'System'});
      expect(a.addressCell, 'https://panel.ir');
      final b = VaultRow.fromJson({'category': 'Server'});
      expect(b.addressCell, '—');
      expect(b.isActive, isTrue);
    });

    test('جستجو (Match وب) در عنوان/آی‌پی/کاربری/آدرس/محل/روش/توضیحات', () {
      expect(row.matches('کور'), isTrue);
      expect(row.matches('10.0.0'), isTrue);
      expect(row.matches('ADMIN'), isTrue);
      expect(row.matches('panel'), isFalse);
      expect(row.matches('اتاق'), isTrue);
      expect(row.matches('ssh'), isTrue);
      expect(row.matches('uplink'), isTrue);
      expect(row.matches('ناموجود'), isFalse);
    });

    test('SafeUrl وب: فقط http/https و تکمیل طرح', () {
      expect(vaultSafeUrl('https://a.ir'), 'https://a.ir');
      expect(vaultSafeUrl('HTTP://a.ir'), 'HTTP://a.ir');
      expect(vaultSafeUrl('panel.ir'), 'http://panel.ir');
      expect(vaultSafeUrl('javascript:alert(1)'), '');
      expect(vaultSafeUrl('10.0.0.5:8443'), 'http://10.0.0.5:8443');
    });
  });

  group('گاوصندوق — اعتبارسنجی فرم', () {
    const ok = VaultSaveRequest(
      companyId: 1,
      title: 'SRV',
      category: 'Server',
      port: 22,
    );

    test('فرم معتبر', () => expect(validateVaultForm(ok), isNull));

    test('همان پیام‌های وب با همان ترتیب', () {
      expect(
        validateVaultForm(const VaultSaveRequest(companyId: 1)),
        'عنوان را وارد کنید.',
      );
      expect(
        validateVaultForm(
          const VaultSaveRequest(companyId: 1, title: 'a', category: 'X'),
        ),
        'نوع تجهیز نامعتبر است.',
      );
      expect(
        validateVaultForm(
          const VaultSaveRequest(companyId: 0, title: 'a', category: 'Server'),
        ),
        'شرکت را انتخاب کنید.',
      );
      expect(
        validateVaultForm(
          const VaultSaveRequest(
            companyId: 1,
            title: 'a',
            category: 'Server',
            port: 70000,
          ),
        ),
        'پورت باید بین ۱ تا ۶۵۵۳۵ باشد.',
      );
      expect(
        validateVaultForm(
          VaultSaveRequest(
            companyId: 1,
            title: 'a',
            extraSecret: 'x' * 4001,
          ),
        ),
        'طول رمز/اطلاعات محرمانه بیش از حد مجاز است.',
      );
    });

    test('toJson همان کلیدهای SaveDto', () {
      final j = const VaultSaveRequest(
        companyId: 4,
        title: 'T',
        category: 'Firewall',
        password: 'p',
        clearPassword: true,
        clearExtraSecret: false,
        isActive: false,
      ).toJson();
      expect(j['companyId'], 4);
      expect(j['category'], 'Firewall');
      expect(j['password'], 'p');
      expect(j['clearPassword'], isTrue);
      expect(j['clearExtraSecret'], isFalse);
      expect(j['isActive'], isFalse);
      expect(j.containsKey('extraSecret'), isTrue);
    });
  });

  group('گاوصندوق — توکن و رمز', () {
    test('نتیجهٔ باز کردن گاوصندوق', () {
      final u = VaultUnlockResult.fromJson({
        'token': 'abc.def',
        'expiresAt': '2026-05-01T12:10:00',
        'minutes': 10,
      });
      expect(u.token, 'abc.def');
      expect(u.minutes, 10);
      expect(u.expiresAt, isNotNull);
      expect(const VaultUnlockResult().minutes, 10);
    });

    test('پاسخ reveal رمز و اطلاعات تکمیلی', () {
      final s = VaultSecret.fromJson({
        'password': 'P@ss',
        'extraSecret': 'community: public',
      });
      expect(s.password, 'P@ss');
      expect(s.extraSecret, 'community: public');
      final e = VaultSecret.fromJson({'password': null, 'extraSecret': ''});
      expect(e.password, isNull);
      expect(e.extraSecret, isNull);
    });

    test('ساخت رمز: طول ۱۶ و شامل چهار دستهٔ کاراکتر', () {
      final p = generateStrongPassword(7);
      expect(p.length, 16);
      expect(p.contains(RegExp('[a-z]')), isTrue);
      expect(p.contains(RegExp('[A-Z]')), isTrue);
      expect(p.contains(RegExp('[0-9]')), isTrue);
      expect(p.contains(RegExp('[^A-Za-z0-9]')), isTrue);
      // کاراکترهای مبهم وب حذف شده‌اند
      expect(p.contains('l'), isFalse);
      expect(p.contains('I'), isFalse);
      expect(p.contains('0'), isFalse);
      expect(p.contains('O'), isFalse);
      expect(generateStrongPassword(7), generateStrongPassword(7));
    });

    test('سنجش قدرت رمز مثل Strength() وب', () {
      expect(passwordStrength('123').$1, 'ضعیف');
      expect(passwordStrength('abcdefgh').$1, 'ضعیف');
      expect(passwordStrength('abcdefgh1').$1, 'ضعیف');
      expect(passwordStrength('abcdefghij12').$1, 'متوسط');
      expect(passwordStrength('Abcdefghij12').$1, 'خوب');
      expect(passwordStrength('Abcdefghij12!').$1, 'قوی');
      expect(passwordStrength('Abcdefghij12').$2, 0xff2563eb);
    });
  });

  group('گاوصندوق — لاگ دسترسی', () {
    test('برچسب عملیات و رنگ آن', () {
      expect(
        VaultLogRow.fromJson({'action': 'Reveal'}).actionLabel,
        'نمایش رمز',
      );
      expect(VaultLogRow.fromJson({'action': 'Copy'}).actionLabel, 'کپی رمز');
      expect(VaultLogRow.fromJson({'action': 'Create'}).actionLabel, 'ایجاد');
      expect(VaultLogRow.fromJson({'action': 'Update'}).actionLabel, 'ویرایش');
      expect(VaultLogRow.fromJson({'action': 'Delete'}).actionLabel, 'حذف');
      expect(
        VaultLogRow.fromJson({'action': 'UnlockFailed'}).actionLabel,
        'رمز ورود اشتباه',
      );
      expect(VaultLogRow.fromJson({'action': 'Other'}).actionLabel, 'Other');
      expect(VaultLogRow.fromJson({'action': 'Delete'}).actionColor, 0xffd13438);
      expect(VaultLogRow.fromJson({'action': 'Create'}).actionColor, 0xff1a7f37);
    });

    test('فیلدهای لاگ خوانده می‌شوند', () {
      final l = VaultLogRow.fromJson({
        'id': 9,
        'credentialId': 5,
        'userName': 'رضا',
        'action': 'Copy',
        'clientIp': '10.0.0.9',
        'details': 'کپی',
        'at': '2026-03-01T08:00:00',
        'title': 'سوییچ کور',
      });
      expect(l.credentialId, 5);
      expect(l.userName, 'رضا');
      expect(l.clientIp, '10.0.0.9');
      expect(l.title, 'سوییچ کور');
      expect(l.at, isNotNull);
    });

    test('شرکت‌ها و همگام‌سازی شمارنده', () {
      final c = VaultCompanyRow.fromJson({'id': 3, 'name': 'فروغ', 'count': 2});
      expect(c.name, 'فروغ');
      expect(c.copyWith(count: 9).count, 9);
      expect(c.copyWith().name, 'فروغ');
    });
  });
}
