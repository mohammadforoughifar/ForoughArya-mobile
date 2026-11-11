// ============================================================
//  راهنمای سامانه فروشگاهی — آینهٔ /shop-guide
//  منبع: inventory/src/Inventory.Client/Pages/Shop/ShopGuide.razor
//
//  گیت: `ShopGuide` (CanSee) — بدون آن: «دسترسی به راهنمای سامانه
//  فروشگاهی ندارید» + توضیح تنظیمات ← نقش‌ها و دسترسی‌ها.
//  ۴ گام شروع سریع + ۱۲ بخش: نمای کلی، منوها، اطلاعات پایه، ثبت خرید،
//  ثبت فروش، تسویه/نسیه/چک/اقساط، چاپ و خروجی، بیجک، تعمیرات،
//  گزارش‌ها، دسترسی‌ها و نقش‌ها، پرسش‌های متداول.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../data/shop_perms.dart';
import 'shop_style.dart';

class ShopGuidePage extends StatelessWidget {
  const ShopGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final perms = ShopPerms(context.read<AuthController>().session);
    final canSee = perms.has('ShopGuide') || perms.canSeeModule('ShopGuide');

    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: const Text(
          'راهنمای سامانه فروشگاهی',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
      ),
      body: !canSee
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 44,
                      color: ShopColors.inkFaint,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'دسترسی به راهنمای سامانه فروشگاهی ندارید',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'برای دیدن این راهنما، مدیر سامانه باید در «تنظیمات ← نقش‌ها و دسترسی‌ها» '
                      'مجوز «راهنمای سامانه فروشگاهی» را به نقش شما بدهد.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                      label: const Text(
                        'بازگشت',
                        style: TextStyle(fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
              children: [
                ShopHeader(
                  title: 'راهنمای سامانه فروشگاهی',
                  subtitle:
                      'از تعریف اطلاعات پایه و ثبت خرید و فروش تا تسویه، چاپ فاکتور، بیجک، تعمیرات و گزارش‌ها؛ '
                      'همهٔ بخش‌های سامانه فروشگاهی را گام‌به‌گام ببینید.',
                  icon: Icons.school_rounded,
                  badge: 'سامانه فروشگاهی / راهنمای کاربری',
                ),
                const SizedBox(height: 10),
                _quickStart(),
                const SizedBox(height: 10),
                for (final s in _sections) _section(context, s),
              ],
            ),
    );
  }

  Widget _quickStart() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ShopColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'شروع کار در چهار گام',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ShopColors.seed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: ShopColors.seed,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _steps[i].$1,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _steps[i].$2,
                        style: const TextStyle(
                          fontSize: 10,
                          color: ShopColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _section(BuildContext context, _GuideSection s) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ShopColors.line),
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        iconColor: ShopColors.seed,
        collapsedIconColor: ShopColors.inkFaint,
        title: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ShopColors.seed.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                '${s.index}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: ShopColors.seed,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    s.kicker,
                    style: const TextStyle(
                      fontSize: 9,
                      color: ShopColors.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        children: s.body,
      ),
    ),
  );
}

// ------------------------------------------------------------
//  مدل بخش راهنما
// ------------------------------------------------------------
class _GuideSection {
  const _GuideSection({
    required this.index,
    required this.title,
    required this.kicker,
    required this.body,
  });

  final int index;
  final String title;
  final String kicker;
  final List<Widget> body;
}

const _steps = <(String, String)>[
  (
    'تکمیل اطلاعات پایه',
    'واحد، گروه کالا، کالا، انبار و طرف حساب را برای شرکت فعال تعریف کنید.',
  ),
  (
    'ثبت خرید',
    'رسید خرید را با ردیف کالاها و روش تسویه ثبت کنید تا موجودی انبار ساخته شود.',
  ),
  ('ثبت فروش و چاپ', 'فاکتور فروش را ثبت و از همان ردیف چاپ کنید.'),
  (
    'تسویه و گزارش',
    'نسیه را از ردیف فاکتور تسویه و نتیجه را در گردش حساب اشخاص و صندوق/بانک بررسی کنید.',
  ),
];

// ---------- اجزای متن ----------
Widget _p(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 7),
  child: Text(
    text,
    style: const TextStyle(fontSize: 10.5, height: 1.7, color: ShopColors.ink),
  ),
);

Widget _note(String title, String text, {IconData icon = Icons.info_outline_rounded, Color color = ShopColors.indigo}) =>
    Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.6,
                    color: ShopColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

Widget _ol(List<String> items) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    for (var i = 0; i < items.length; i++)
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ShopColors.bg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${i + 1}',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: ShopColors.inkSoft,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                items[i],
                style: const TextStyle(
                  fontSize: 10.5,
                  height: 1.65,
                  color: ShopColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
  ],
);

Widget _table(List<(String, String)> rows, {List<String>? heads}) => Container(
  margin: const EdgeInsets.only(bottom: 7),
  decoration: BoxDecoration(
    color: ShopColors.bg,
    borderRadius: BorderRadius.circular(10),
  ),
  padding: const EdgeInsets.all(8),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (heads != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  heads[0],
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.inkSoft,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  heads[1],
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  r.$1,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  r.$2,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.55,
                    color: ShopColors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  ),
);

Widget _faq(String q, String a) => Container(
  margin: const EdgeInsets.only(bottom: 6),
  padding: const EdgeInsets.all(9),
  decoration: BoxDecoration(
    color: ShopColors.bg,
    borderRadius: BorderRadius.circular(10),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        q,
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 3),
      Text(
        a,
        style: const TextStyle(
          fontSize: 10,
          height: 1.6,
          color: ShopColors.inkSoft,
        ),
      ),
    ],
  ),
);

final _sections = <_GuideSection>[
  _GuideSection(
    index: 1,
    title: 'سامانه فروشگاهی در یک نگاه',
    kicker: 'نمای کلی',
    body: [
      _p(
        '«سامانه فروشگاهی» محل کار روزمرهٔ خرید و فروش است: تعریف کالا و طرف حساب، ثبت رسید خرید و '
        'فاکتور فروش، ثبت نحوهٔ تسویه، چاپ اسناد، صدور بیجک، پیگیری تعمیرات و دیدن گزارش‌ها. '
        'همهٔ اسناد به شرکت فعال (انتخاب‌شده در نوار بالای صفحه) و انبار مربوط‌اند؛ پس پیش از هر کار '
        'مطمئن شوید شرکت و انبار درست انتخاب شده‌اند.',
      ),
      _table(
        [
          (
            'خرید و فروش',
            'ثبت رسید خرید از تأمین‌کننده و فاکتور فروش به مشتری، همراه با ردیف کالاها، تخفیف، مالیات و روش تسویه.',
          ),
          (
            'اطلاعات پایه',
            'کالاها، گروه‌های کالا، واحدهای شمارش، انبارها، طرف حساب‌ها و معرف‌ها؛ پیش‌نیاز هر سند.',
          ),
          (
            'بیجک و تعمیرات',
            'حوالهٔ تحویل کالا بدون قیمت (بیجک) و ثبت و پیگیری تعمیرات کالاهای مشتری.',
          ),
          (
            'گزارش و داشبورد',
            'کاردکس تعداد و ریالی، گزارش خرید و فروش و داشبورد جامع عملیات.',
          ),
        ],
        heads: ['بخش', 'چه کاری انجام می‌دهد'],
      ),
      _note(
        'سامانه مودیان، ماژول جداگانه است',
        'صدور و ارسال صورتحساب الکترونیکی در منوی مستقل «سامانه مودیان» انجام می‌شود و راهنمای خودش را دارد. '
        'فروشگاه برای فروش روزمره و سند داخلی است؛ برای ارسال به سازمان مالیاتی از همان ماژول استفاده کنید.',
        icon: Icons.receipt_long_rounded,
      ),
    ],
  ),
  _GuideSection(
    index: 2,
    title: 'منوها و ساختار صفحه',
    kicker: 'جست‌وجو در سامانه',
    body: [
      _p(
        'همهٔ بخش‌ها زیر گروه «سامانه فروشگاهی» در منو جمع شده‌اند و هر آیتم فقط وقتی دیده می‌شود که مجوزش را داشته باشید:',
      ),
      _table(
        [
          ('خرید', 'فهرست و ثبت رسیدهای خرید از تأمین‌کننده.'),
          ('فروش', 'فهرست و ثبت فاکتورهای فروش به مشتری و چاپ فاکتور.'),
          ('بیجک', 'حوالهٔ تحویل کالا بدون قیمت برای همراهی بار.'),
          ('تعمیرات', 'پذیرش، ارجاع و پیگیری تعمیر کالا.'),
          ('هزینه‌ها', 'ثبت هزینه‌های جاری فروشگاه.'),
          ('تسویه فاکتورها', 'ثبت دریافت/پرداخت مرتبط با فاکتورها و چک‌ها.'),
          (
            'گزارش',
            'کاردکس تعداد و ریالی، گزارش خرید و فروش، داشبورد عملیات.',
          ),
          (
            'اطلاعات پایه',
            'کالاها، گروه‌های کالا، واحدهای شمارش، انبارها، طرف حساب‌ها، معرف‌ها.',
          ),
          ('راهنمای سامانه', 'همین صفحه.'),
        ],
        heads: ['بخش', 'چه کاری انجام می‌دهد'],
      ),
    ],
  ),
  _GuideSection(
    index: 3,
    title: 'اطلاعات پایه',
    kicker: 'پیش‌نیاز اسناد',
    body: [
      _ol([
        'واحدهای شمارش: واحدهای مورد استفاده (عدد، کیلوگرم، متر، بسته…) را تعریف کنید؛ هر کالا به یکی از این واحدها وصل می‌شود.',
        'گروه‌های کالا: برای دسته‌بندی و گزارش‌گیری، گروه بسازید. گروه می‌تواند «گروه پدر» داشته باشد و به شکل درختی مرتب شود.',
        'کالاها: کد، نام، گروه، واحد، قیمت خرید و قیمت فروش، موجودی حداقل/حداکثر و بارکد را ثبت کنید. کالای بدون واحد در سند قابل انتخاب نیست.',
        'انبارها: حداقل یک انبار بسازید؛ موجودی و کاردکس بر اساس انبار محاسبه می‌شود.',
        'طرف حساب‌ها: مشتری و تأمین‌کننده را با نوع حساب مشخص کنید؛ گردش حساب و مانده هر طرف حساب از همین اسناد ساخته می‌شود.',
        'معرف‌ها: اگر فروش از طریق معرف انجام می‌شود، معرف را تعریف کنید تا سهم و کیف پول او محاسبه شود.',
      ]),
      _note(
        'ترتیب پیشنهادی',
        'واحد ← گروه کالا ← کالا ← انبار ← طرف حساب ← معرف. با رعایت این ترتیب هنگام ثبت سند، کمبود گزینه ندارید.',
      ),
    ],
  ),
  _GuideSection(
    index: 4,
    title: 'ثبت خرید',
    kicker: 'رسید خرید',
    body: [
      _ol([
        'از منوی «سامانه فروشگاهی ← خرید» وارد فهرست رسیدهای خرید شوید.',
        'دکمهٔ «خرید جدید» را بزنید؛ فرم سند باز می‌شود.',
        'انبار، تأمین‌کننده و تاریخ سند را مشخص کنید (این سه الزامی‌اند).',
        'ردیف‌های کالا را اضافه کنید: کالا، تعداد، قیمت واحد و تخفیف/مالیات هر ردیف.',
        'روش تسویه را انتخاب کنید: نقدی، کارت‌خوان، کارت‌به‌کارت، نسیه، چک یا اقساط.',
        'سند را ثبت کنید؛ موجودی انبار و گردش حساب تأمین‌کننده به‌روز می‌شود.',
      ]),
      _note(
        'پیش‌پرداخت نقدی',
        'در فرم خرید می‌توانید مبلغی پیش‌پرداخت ثبت کنید؛ باقی‌مانده به‌صورت نسیه/چک در گردش حساب می‌ماند.',
        icon: Icons.payments_rounded,
      ),
    ],
  ),
  _GuideSection(
    index: 5,
    title: 'ثبت فروش',
    kicker: 'فاکتور فروش',
    body: [
      _ol([
        'از منوی «سامانه فروشگاهی ← فروش» وارد فهرست اسناد فروش شوید.',
        'دکمهٔ «فروش جدید» را بزنید.',
        'انبار، مشتری و تاریخ سند را انتخاب کنید، سپس ردیف کالاها را وارد کنید.',
        'در صورت نیاز پیش‌دریافت نقدی ثبت کنید و روش تسویهٔ باقی‌مانده را مشخص کنید.',
        'سند را ثبت و از همان ردیف فهرست، فاکتور را چاپ کنید.',
      ]),
      _note(
        'موجودی کافی',
        'اگر موجودی انبار کافی نباشد، سامانه هشدار می‌دهد. اول رسید خرید را ثبت کنید یا موجودی اول دوره را وارد کنید '
        'تا فروش بدون منفی‌شدن انبار انجام شود.',
        icon: Icons.warning_amber_rounded,
        color: ShopColors.warn,
      ),
    ],
  ),
  _GuideSection(
    index: 6,
    title: 'تسویه، نسیه، چک و اقساط',
    kicker: 'گردش مالی',
    body: [
      _p(
        'در فرم سند، بخش «روش تسویه» تعیین می‌کند پول چگونه دریافت/پرداخت می‌شود. برای حالت‌های غیرنقدی، سامانه جزئیات را می‌پرسد:',
      ),
      _table(
        [
          (
            'نقدی',
            'حساب صندوق/بانک و نوع دریافت (وجه نقد، کارت‌خوان، کارت‌به‌کارت).',
          ),
          ('نسیه', 'تاریخ سررسید؛ مبلغ به ماندهٔ طرف حساب اضافه می‌شود.'),
          (
            'چک',
            'شمارهٔ چک/صیاد، بانک، مبلغ، تاریخ سررسید و صاحب چک/در وجه.',
          ),
          ('اقساط', 'تعداد اقساط و تاریخ اولین قسط؛ سررسیدها خودکار ساخته می‌شوند.'),
        ],
        heads: ['روش', 'چه اطلاعاتی لازم است'],
      ),
      _note(
        'سود اقساط چک در فروش',
        'در فروش جدید، چک و سپس «محاسبه اقساط چک» را انتخاب کنید. سود همان ماشین‌حساب همراه ردیف‌های چک ساخته می‌شود '
        'و پس از ثبت، جدا از کالا در بدهی مشتری و درآمد فروشگاه می‌آید. مبالغ چک‌های ساخته‌شده با ماشین‌حساب و اقساط '
        'ساخته‌شده در فاکتور تا ۱۰٬۰۰۰ ریال رند می‌شوند؛ جمع تغییر نمی‌کند و اختلاف کمتر از این واحد در ردیف آخر می‌ماند. '
        'ریز سود در «گزارش طلب و بدهی اشخاص ← ریز صورت‌حساب» و گزارش درآمد آن در «گزارش فروش ← گزارش تاخیر تادیه چک» '
        'قابل مشاهده است. وصول چک جداگانه ثبت می‌شود.',
        icon: Icons.calculate_rounded,
      ),
      _note(
        'تسویهٔ بعدی',
        'در فهرست خرید یا فروش، دکمهٔ «نسیه و سوابق» روی ردیف فاکتور را باز کنید؛ مبلغ، تاریخ و حساب صندوق/بانک را انتخاب کنید. '
        'لغو گردش نیز با تاریخ جداگانه و حفظ سابقه انجام می‌شود. چک‌ها و اقساط باز جداگانه تسویه می‌شوند.',
        icon: Icons.account_balance_wallet_rounded,
      ),
    ],
  ),
  _GuideSection(
    index: 7,
    title: 'چاپ و خروجی',
    kicker: 'اسناد',
    body: [
      _ol([
        'چاپ فاکتور فروش: از آیکن چاپ در ردیف فاکتور یا از نوار عملیات همان سند.',
        'چاپ رسید خرید: همان مسیر، با قالب رسید خرید.',
        'پیش‌نمایش چاپ: ابتدا نسخهٔ چاپی را بررسی کنید؛ پنجرهٔ چاپ فقط با زدن «چاپ» در پیش‌نمایش باز می‌شود.',
        'خروجی فهرست: دکمه‌های خروجی، همان فیلترهای فعال را در اکسل/PDF می‌آورند.',
        'فیلترها: بازهٔ تاریخ، انبار و طرف حساب؛ دکمهٔ «اعمال فیلتر» فهرست را به‌روز می‌کند.',
        'کپی فاکتور: در ردیف انتخاب‌شده یا جزئیات سند F7 را بزنید. نسخهٔ جدید برای بازبینی باز می‌شود و پرداخت، چک، اقساط و گردش قبلی را ندارد.',
        'مشاهدهٔ سود: در تنظیمات نقش، زیر «سامانه فروشگاهی — فروش، مالی و مودیان» و «فروش / فاکتورها»، مجوز مستقل «مشاهده سود» را فعال کنید؛ مجوز کلی مدیریت فروش به‌تنهایی این ستون را نمایش نمی‌دهد.',
      ]),
      _p(
        'میانبر فرم‌ها: F1 ثبت (در مرحلهٔ اول فاکتور: ادامه)، F2 سطر جدید، F3 مرحلهٔ قبل، F4 چاپ یا ثبت و چاپ، و Esc انصراف. '
        'هر میانبر فقط در فرم یا پنجرهٔ فعال اجرا می‌شود.',
      ),
      _note(
        'سربرگ چاپ',
        'سربرگ و اطلاعات شرکتِ چاپ از همان شرکت فعال خوانده می‌شود؛ اگر سربرگ خالی بود، اطلاعات شرکت را در تنظیمات شرکت‌ها تکمیل کنید.',
        icon: Icons.print_rounded,
      ),
    ],
  ),
  _GuideSection(
    index: 8,
    title: 'بیجک (حوالهٔ بدون قیمت)',
    kicker: 'تحویل بار',
    body: [
      _p(
        'بیجک برای وقتی است که کالا از انبار خارج می‌شود ولی نمی‌خواهید قیمت روی برگه دیده شود (همراهی بار، تحویل به واحد دیگر یا ارسال با پیک). '
        'در بیجک کالا، تعداد و انبار ثبت می‌شود ولی مبلغ/قیمت نمایش داده نمی‌شود.',
      ),
      _note(
        'تفاوت بیجک و حوالهٔ فروش',
        'فاکتور فروش سند مالی است و روی گردش حساب اثر دارد؛ بیجک سند «فقط مقدار» است و بدون قیمت صادر می‌شود.',
        icon: Icons.local_shipping_rounded,
      ),
    ],
  ),
  _GuideSection(
    index: 9,
    title: 'تعمیرات',
    kicker: 'سرویس کالا',
    body: [
      _ol([
        'در «تعمیرات» یک پروندهٔ تازه بسازید: مشتری، کالا، ایراد و توضیحات.',
        'پرونده را به کارشناس یا واحد مربوط ارجاع دهید و وضعیت را به‌روز نگه دارید.',
        'هزینهٔ تعمیر را ثبت و پس از تحویل کالا، پرونده را ببندید.',
      ]),
    ],
  ),
  _GuideSection(
    index: 10,
    title: 'گزارش‌ها و داشبورد',
    kicker: 'تحلیل',
    body: [
      _table(
        [
          ('کاردکس تعداد کالا', 'گردش موجودی هر کالا در بازهٔ زمانی، بر اساس تعداد.'),
          ('کاردکس ریالی کالا', 'همان گردش، با مبالغ؛ برای بهای تمام‌شده و ارزش موجودی.'),
          ('گزارش خرید', 'جمع خرید در بازه، به تفکیک تأمین‌کننده و انبار.'),
          ('گزارش فروش', 'جمع فروش در بازه، به تفکیک مشتری، کالا و معرف.'),
          ('داشبورد عملیات', 'نمای کلی خرید، فروش، تعمیرات و معرف.'),
        ],
        heads: ['گزارش', 'به چه کاری می‌آید'],
      ),
    ],
  ),
  _GuideSection(
    index: 11,
    title: 'دسترسی‌ها و نقش‌ها',
    kicker: 'مدیریت سامانه',
    body: [
      _p(
        'هر بخش این سامانه یک دسترسی مستقل دارد. همهٔ آن‌ها در یک جا و در دستهٔ «سامانه فروشگاهی — دسترسی هر بخش» '
        'داخل «تنظیمات ← نقش‌ها و دسترسی‌ها» هستند؛ برای هر بخش دو سطح وجود دارد:',
      ),
      _ol([
        'مشاهدهٔ بخش: آیتم آن بخش در منوی «سامانه فروشگاهی» دیده می‌شود و صفحه‌اش باز می‌شود.',
        'ثبت، ویرایش و حذف: علاوه بر دیدن، اجازهٔ ساخت و تغییر اسناد همان بخش را می‌دهد (سیاهه، چک، سند).',
      ]),
      _table(
        [
          ('خرید', 'خرید • مشاهده + ثبت/ویرایش'),
          ('فروش', 'فروش • مشاهده + ثبت/ویرایش'),
          ('بیجک', 'بیجک • مشاهده + ثبت/ویرایش'),
          ('تعمیرات', 'تعمیرات • مشاهده + ثبت/ویرایش'),
          ('هزینه‌ها', 'هزینه‌ها • مشاهده + ثبت/ویرایش'),
          (
            'مدیریت اقساط و چک‌ها',
            'مدیریت اقساط و خزانه‌داری • مشاهده + ثبت/ویرایش',
          ),
          (
            'افتتاح حساب و مانده‌های اولیه',
            'افتتاح حساب و مانده‌های اولیه • مشاهده + ثبت/ویرایش',
          ),
          ('تسویه فاکتورها', 'تسویه فاکتورها • مشاهده + ثبت/ویرایش'),
          ('فروش و ویزیتوری', 'فروش و ویزیتوری • مشاهده + ثبت/ویرایش'),
          ('کالاها', 'اطلاعات پایه ← کالاها • مشاهده + ثبت/ویرایش'),
          ('گروه‌های کالا', 'اطلاعات پایه ← گروه‌های کالا • مشاهده + ثبت/ویرایش'),
          ('واحدهای شمارش', 'اطلاعات پایه ← واحدهای شمارش • مشاهده + ثبت/ویرایش'),
          ('انبارها', 'اطلاعات پایه ← انبارها • مشاهده + ثبت/ویرایش'),
          ('طرف حساب‌ها', 'اطلاعات پایه ← طرف حساب‌ها • مشاهده + ثبت/ویرایش'),
          ('معرف‌ها', 'اطلاعات پایه ← معرف‌ها • مشاهده + ثبت/ویرایش'),
          (
            'بانک، صندوق و کارتخوان',
            'اطلاعات پایه ← بانک، صندوق و کارتخوان • مشاهده + ثبت/ویرایش',
          ),
          ('داشبورد عملیاتی', 'داشبورد ← داشبورد عملیاتی • فقط مشاهده'),
          ('کاردکس کالا (تعداد و ریالی)', 'گزارش ← کاردکس • فقط مشاهده'),
          ('گزارش خرید و فروش', 'گزارش ← گزارش خرید / فروش • فقط مشاهده'),
          ('گزارش طلب و بدهی اشخاص', 'گزارش ← طلب و بدهی اشخاص • فقط مشاهده'),
          ('راهنمای سامانه', 'راهنمای سامانه • فقط مشاهده'),
        ],
        heads: ['بخش', 'در منو + نوع'],
      ),
      _note(
        'پنهان‌شدن منو + بسته‌شدن آدرس مستقیم',
        'اگر تیک یک بخش برداشته شود، آیتم آن از منو حذف می‌شود و باز کردن آدرس آن صفحه هم پیام «دسترسی به این بخش ندارید» می‌دهد؛ '
        'یعنی دسترسی فقط به پنهان‌شدن منو محدود نیست.',
        icon: Icons.shield_outlined,
      ),
      _note(
        'دسترسی‌های قبلی از بین نمی‌روند',
        'نقش‌هایی که از قبل مجوز ماژول‌های قدیمی (فروش/فاکتورها، بیجک، تعمیرات، کالاها و …) را داشتند، بدون تغییر هم به همان بخش‌ها دسترسی دارند.',
        icon: Icons.sync_rounded,
      ),
      _note(
        'دیدن راهنما بدون دیدن اسناد',
        'می‌توانید فقط مجوز «راهنمای سامانه فروشگاهی» را به یک نقش بدهید؛ در این حالت آن کاربر منوی «سامانه فروشگاهی ← راهنمای سامانه» را می‌بیند '
        'و به اسناد و اطلاعات پایه دسترسی ندارد.',
        icon: Icons.person_outline_rounded,
      ),
    ],
  ),
  _GuideSection(
    index: 12,
    title: 'پرسش‌های متداول',
    kicker: 'رفع ابهام',
    body: [
      _faq(
        'فاکتور فروش را ثبت کردم ولی موجودی کم نشد؛ چرا؟',
        'احتمالاً سند هنوز نهایی نشده یا در انبار دیگری ثبت شده است. انبار سند و وضعیت آن را بررسی کنید؛ موجودی بر اساس انبارِ همان سند کم می‌شود.',
      ),
      _faq(
        'چرا نمی‌توانم کالایی را در سند انتخاب کنم؟',
        'کالا باید فعال باشد و واحد شمارش داشته باشد. کالای غیرفعال یا بدون واحد در لیست انتخاب سند نمی‌آید.',
      ),
      _faq(
        'سربرگ چاپ خالی است یا نام شرکت دیگری را نشان می‌دهد؟',
        'سربرگ از «شرکت فعال» خوانده می‌شود. ابتدا شرکت فعال را از نوار بالا انتخاب کنید و سپس اطلاعات و سربرگ همان شرکت را در تنظیمات تکمیل کنید.',
      ),
      _faq(
        'تفاوت «چاپ فاکتور» و «سامانه مودیان» چیست؟',
        'چاپ فاکتور سند داخلی فروشگاه است؛ ارسال صورتحساب الکترونیکی به سازمان مالیاتی در ماژول «سامانه مودیان» انجام می‌شود.',
      ),
      _faq(
        'چرا دکمه‌ای که در راهنما آمده در صفحهٔ من نیست؟',
        'بسیاری از دکمه‌ها به مجوز نقش شما وابسته‌اند. اگر دکمه‌ای را نمی‌بینید، مجوز مربوط را از مدیر سامانه بخواهید.',
      ),
    ],
  ),
];
