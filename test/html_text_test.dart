import 'package:flutter_test/flutter_test.dart';
import 'package:forough_mobile/core/utils/html_text.dart';
import 'package:forough_mobile/features/work_orders/models/work_order.dart';

void main() {
  group('htmlToText', () {
    test('متن ساده بدون تغییر می‌ماند', () {
      expect(htmlToText('سلام\nخط دوم'), 'سلام\nخط دوم');
      expect(htmlToText('a < b و c > d'), 'a < b و c > d');
      expect(htmlToText(null), '');
    });

    test('تگ‌های ادیتور وب حذف و به شکست خط تبدیل می‌شوند', () {
      expect(
        htmlToText('<p>لطفاً گزارش&nbsp;را <strong>تا فردا</strong> بفرستید.</p><p>با تشکر</p>'),
        'لطفاً گزارش را تا فردا بفرستید.\nبا تشکر',
      );
      expect(htmlToText('خط یک<br>خط دو<br/>خط سه'), 'خط یک\nخط دو\nخط سه');
      expect(
        htmlToText('<ul><li>مورد اول</li><li>مورد دوم</li></ul>'),
        '• مورد اول\n• مورد دوم',
      );
      expect(
        htmlToText('<div dir="rtl" style="text-align:right"><span style="color:red">فوری</span></div>'),
        'فوری',
      );
    });

    test('موجودیت‌ها رمزگشایی می‌شوند', () {
      expect(htmlToText('می&zwnj;خواهم &laquo;الف&raquo; &amp; ب'), 'می\u200cخواهم «الف» & ب');
      expect(htmlToText('&#1587;&#x644;'), 'سل');
    });

    test('مدل دستور کار شرح HTML را تمیز می‌کند', () {
      final o = WorkOrder.fromJson({
        'id': 1,
        'title': 'بررسی <b>سرور</b>',
        'description': '<p>متن <em>شرح</em></p><p><br></p><p>پایان</p>',
        'closeNote': '<p>بسته شد</p>',
        'assignees': [
          {'id': 1, 'replyText': '<p>انجام&nbsp;شد</p>'},
        ],
      });
      expect(o.title, 'بررسی سرور');
      expect(o.description, 'متن شرح\n\nپایان');
      expect(o.closeNote, 'بسته شد');
      expect(o.assignees.first.replyText, 'انجام شد');
    });
  });
}
