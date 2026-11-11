// آزمون نازکِ مدل و مجوزهای «سامانه فروشگاهی»
// تضمین می‌کند فیلدهای DTO طرف حساب دقیقاً همان‌هایی باشند که وب/سرور دارند
// و قاعدهٔ نمایش تب مشتریان/تأمین‌کنندگان مثل Parties.razor عمل کند.

import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/auth/auth_session.dart';
import 'package:forough_mobile/features/shop/data/shop_perms.dart';
import 'package:forough_mobile/features/shop/models/shop_models.dart';

AuthSession _session(List<String> perms, {String role = 'User'}) => AuthSession(
  userId: 7,
  token: 't',
  username: 'u',
  role: role,
  displayName: 'کاربر آزمون',
  permissions: perms,
);

void main() {
  group('Party DTO', () {
    test('از پاسخ سرور همهٔ فیلدهای وب خوانده می‌شود', () {
      final p = Party.fromJson({
        'id': 12,
        'type': 0,
        'name': 'فروشگاه نمونه',
        'mobile': '09120000000',
        'phone': '02100000000',
        'address': 'تهران',
        'taxId': '1234567890',
        'postalCode': '1111111111',
        'note': 'یادداشت',
        'isActive': true,
        'referrerId': 3,
        'referrerName': 'معرف الف',
        'registeredByName': 'کارشناس فروش',
        'balance': 1500,
        'bouncedChequesCount': 1,
        'bouncedChequesTotal': 500,
        'overdueInstallmentsCount': 2,
        'overdueInstallmentsTotal': 700,
      });
      expect(p.id, 12);
      expect(p.type, PartyType.customer);
      expect(p.name, 'فروشگاه نمونه');
      expect(p.taxId, '1234567890');
      expect(p.postalCode, '1111111111');
      expect(p.referrerName, 'معرف الف');
      expect(p.registeredByName, 'کارشناس فروش');
      expect(p.hasBouncedCheque, isTrue);
      expect(p.hasOverdueInstallment, isTrue);
    });

    test('بدنهٔ ارسال فقط فیلدهای فرم وب را دارد', () {
      final body = Party(
        type: PartyType.supplier,
        name: '  تأمین‌کننده  ',
        mobile: '0912',
        note: '',
      ).toJson();
      expect(body['name'], 'تأمین‌کننده');
      expect(body['type'], PartyType.supplier);
      expect(body['mobile'], '0912');
      expect(body['note'], isNull, reason: 'رشتهٔ خالی باید null برود');
      // هیچ فیلد اختراعی اضافه نشده باشد
      const allowed = {
        'id',
        'type',
        'name',
        'phone',
        'mobile',
        'address',
        'taxId',
        'postalCode',
        'note',
        'isActive',
        'referrerId',
      };
      expect(body.keys.toSet().difference(allowed), isEmpty);
    });
  });

  group('ShopPerms — همان قاعدهٔ Parties.razor', () {
    test('کاربر فقط با مشتریان، تب تأمین‌کننده را نمی‌بیند', () {
      final perms = ShopPerms(_session(['Customers.Read']));
      expect(perms.canSeeCustomers, isTrue);
      expect(perms.canSeeSuppliers, isFalse);
      expect(perms.partyPageTitle, 'طرف حساب‌ها');
    });

    test('کاربر فقط تأمین‌کننده: عنوان صفحه «تأمین‌کنندگان»', () {
      final perms = ShopPerms(_session(['Suppliers.Create']));
      expect(perms.canSeeCustomers, isFalse);
      expect(perms.canSeeSuppliers, isTrue);
      expect(perms.partyPageTitle, 'تأمین‌کنندگان');
      expect(perms.canCreateParty(1), isTrue);
      expect(perms.canUpdateParty(1), isFalse);
    });

    test('مجوز قدیمی Parties.Read هر دو نوع را باز می‌کند', () {
      final perms = ShopPerms(_session(['Parties.Read']));
      expect(perms.canSeeCustomers, isTrue);
      expect(perms.canSeeSuppliers, isTrue);
      expect(perms.anyPartyAccess, isTrue);
    });

    test('مدیر سیستم همه‌کاره است', () {
      final perms = ShopPerms(_session(const [], role: 'Admin'));
      expect(perms.canSeeCustomers, isTrue);
      expect(perms.canDeleteParty(0), isTrue);
    });
  });
}
