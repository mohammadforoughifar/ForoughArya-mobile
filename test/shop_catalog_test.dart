// آزمون فاز ۲ «سامانه فروشگاهی» — مدل‌های کالا/گروه/واحد/انبار/موجودی
// تضمین می‌کند فیلدها و قواعد عیناً مثل DTOهای سرور و صفحهٔ وب باشند.

import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/features/shop/data/shop_perms.dart';
import 'package:forough_mobile/features/shop/models/shop_models.dart';
import 'package:forough_mobile/core/auth/auth_session.dart';

AuthSession _s(List<String> perms, {String role = 'User'}) => AuthSession(
  userId: 1,
  token: 't',
  username: 'u',
  role: role,
  displayName: 'x',
  permissions: perms,
);

void main() {
  group('Product', () {
    test('همهٔ فیلدهای DTO سرور خوانده می‌شود', () {
      final p = Product.fromJson({
        'id': 5,
        'code': 'P-1',
        'name': 'روغن موتور',
        'unit': 'لیتر',
        'category': 'روغن',
        'barcode': '6260001',
        'taxCode': '2711000000',
        'salePrice': 1200,
        'purchasePrice': 900,
        'reorderPoint': 10,
        'maxStock': 100,
        'description': 'توضیح',
        'isActive': true,
        'isService': false,
        'warehouseId': 3,
        'warehouseName': 'انبار مرکزی',
        'createdAt': '2026-01-01T10:00:00',
        'totalStock': 4,
        'avgCost': 850,
      });
      expect(p.code, 'P-1');
      expect(p.unit, 'لیتر');
      expect(p.category, 'روغن');
      expect(p.warehouseId, 3);
      expect(p.totalStock, 4);
      // همان قاعدهٔ سرور: ۱۰ > ۰ و ۴ <= ۱۰ ⇒ زیر نقطه سفارش
      expect(p.belowReorder, isTrue);
    });

    test('قاعدهٔ زیر نقطه سفارش با نقطه سفارش صفر خاموش است', () {
      final p = Product(name: 'x', totalStock: 0, reorderPoint: 0);
      expect(p.belowReorder, isFalse);
    });

    test('بدنهٔ ارسال فقط فیلدهای فرم وب را دارد', () {
      final body = Product(name: ' کالا ', code: '', unit: '').toJson();
      expect(body['name'], 'کالا');
      expect(body['unit'], 'عدد', reason: 'پیش‌فرض وب عدد است');
      expect(body['code'], '');
      const allowed = {
        'id',
        'code',
        'name',
        'unit',
        'category',
        'barcode',
        'taxCode',
        'salePrice',
        'purchasePrice',
        'reorderPoint',
        'maxStock',
        'description',
        'isActive',
        'isService',
        'warehouseId',
      };
      expect(body.keys.toSet().difference(allowed), isEmpty);
    });
  });

  group('StockItem', () {
    test('ارزش کل موجودی = تعداد × میانگین خرید', () {
      final s = StockItem.fromJson({
        'warehouseId': 1,
        'warehouseName': 'مرکزی',
        'productId': 2,
        'productName': 'فیلتر',
        'productCode': 'F-9',
        'unit': 'عدد',
        'quantity': 3,
        'avgCost': 250,
        'reorderPoint': 5,
      });
      expect(s.totalValue, 750);
      expect(s.belowReorder, isTrue);
    });
  });

  group('Category / Unit / Warehouse', () {
    test('گروه: والد و عمق', () {
      final c = ProductCategory.fromJson({
        'id': 9,
        'name': 'فیلتر',
        'parentId': 4,
        'depth': 1,
        'productCount': 6,
      });
      expect(c.parentId, 4);
      expect(c.depth, 1);
      expect(c.toJson()['parentId'], 4);
    });

    test('واحد و انبار: نام و وضعیت', () {
      final u = MeasureUnit.fromJson({'id': 1, 'name': 'کیلوگرم', 'isActive': false});
      expect(u.name, 'کیلوگرم');
      expect(u.isActive, isFalse);
      final w = Warehouse.fromJson({
        'id': 2,
        'name': 'انبار ۲',
        'address': 'شیراز',
        'isActive': true,
        'itemCount': 12,
      });
      expect(w.itemCount, 12);
      expect(w.toJson()['address'], 'شیراز');
    });
  });

  group('گیت مجوز فاز ۲ — مثل CanSee وب', () {
    test('Products.Read هر سه صفحهٔ کالا/گروه/واحد را باز می‌کند', () {
      final p = ShopPerms(_s(['Products.Read']));
      expect(p.canSeeProducts, isTrue);
      expect(p.canSeeWarehouses, isFalse);
      expect(p.canSeeStock, isFalse);
    });

    test('Warehouses.Manage و Stock.Update هم کافی‌اند', () {
      final p = ShopPerms(_s(['Warehouses.Manage', 'Stock.Update']));
      expect(p.canSeeWarehouses, isTrue);
      expect(p.canSeeStock, isTrue);
    });
  });
}
