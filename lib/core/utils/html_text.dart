/// تبدیل متن‌های HTML (خروجی ادیتور غنی نسخهٔ وب) به متن ساده برای نمایش در اپ.
///
/// نسخهٔ وب شرح دستور کار، پاسخ‌ها، نظرات و یادداشت‌ها را با ادیتور غنی
/// ذخیره می‌کند؛ در نتیجه سرور رشته‌هایی مثل `<p>سلام<br></p>` یا
/// `&nbsp;` برمی‌گرداند. ویجت `Text` در Flutter این‌ها را تفسیر نمی‌کند و
/// تگ‌ها خام روی صفحهٔ اندروید دیده می‌شدند.
library;

final _tagLike = RegExp(r'</?[a-zA-Z][a-zA-Z0-9-]*(\s[^<>]*)?/?\s*>');
final _entityLike = RegExp(r'&(#\d+|#x[0-9a-fA-F]+|[a-zA-Z]{2,8});');

/// آیا رشته شامل تگ یا موجودیت HTML است؟
bool looksLikeHtml(String? raw) {
  if (raw == null || raw.isEmpty) return false;
  return _tagLike.hasMatch(raw) || _entityLike.hasMatch(raw);
}

/// تگ‌های HTML را حذف می‌کند و ساختار (پاراگراف، شکست خط، فهرست) را به
/// شکست خط و بولت تبدیل می‌کند. متن ساده بدون تغییر برمی‌گردد.
String htmlToText(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  if (!looksLikeHtml(raw)) return raw;
  var s = raw;
  s = s.replaceAll(
    RegExp(r'<(style|script|head|title)[^>]*>[\s\S]*?</\1\s*>',
        caseSensitive: false),
    '',
  );
  s = s.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
  // شکست خط‌های خود HTML بی‌معنی‌اند؛ فقط تگ‌ها تعیین‌کننده‌اند
  // (اما اگر هیچ تگ بلوکی/br نبود، خطوط اصلی را نگه می‌داریم).
  final hasBlock = RegExp(r'</?(br|p|div|li|tr|h[1-6])\b', caseSensitive: false)
      .hasMatch(s);
  if (hasBlock) s = s.replaceAll(RegExp(r'[\r\n]+'), ' ');
  // مرز بلوک‌ها با نشانگر موقت؛ چند مرز پشت‌سرهم = یک شکست خط
  // (تا `</p><p>` یک خط خالی اضافه نسازد).
  const mark = '\u0001';
  s = s.replaceAll(RegExp(r'<li\b[^>]*>', caseSensitive: false), '$mark• ');
  s = s.replaceAll(RegExp(r'<br\s*/?\s*>', caseSensitive: false), '\n');
  s = s.replaceAll(
    RegExp(r'</?\s*(p|div|tr|h[1-6]|blockquote|ul|ol|table|li|pre)\b[^>]*>',
        caseSensitive: false),
    mark,
  );
  s = s.replaceAll(RegExp(r'</\s*t[dh]\s*>', caseSensitive: false), '  ');
  s = s.replaceAll(RegExp(r'</?[a-zA-Z!][^<>]*>'), '');
  s = s.replaceAll(RegExp('$mark(?:[ \t]*$mark)*'), '\n');
  s = decodeHtmlEntities(s);
  // یکدست‌سازی فاصله‌ها و خطوط خالی
  final out = <String>[];
  var blank = 0;
  for (final line in s.split(RegExp(r'\r?\n'))) {
    final l = line.replaceAll(RegExp(r'[ \t\u00A0]+'), ' ').trim();
    if (l.isEmpty) {
      blank++;
      if (blank == 1 && out.isNotEmpty) out.add('');
    } else {
      blank = 0;
      out.add(l);
    }
  }
  return out.join('\n').trim();
}

/// نسخهٔ nullable: `null` همان `null` می‌ماند.
String? htmlToTextOrNull(String? raw) => raw == null ? null : htmlToText(raw);

const _named = <String, String>{
  'nbsp': ' ',
  'zwnj': '\u200c',
  'zwj': '\u200d',
  'rlm': '\u200f',
  'lrm': '\u200e',
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'laquo': '«',
  'raquo': '»',
  'ndash': '–',
  'mdash': '—',
  'hellip': '…',
  'bull': '•',
  'middot': '·',
  'copy': '©',
  'reg': '®',
  'times': '×',
  'divide': '÷',
  'lsquo': '‘',
  'rsquo': '’',
  'ldquo': '“',
  'rdquo': '”',
};

String decodeHtmlEntities(String input) {
  return input.replaceAllMapped(_entityLike, (m) {
    final e = m.group(1)!;
    if (e.startsWith('#x') || e.startsWith('#X')) {
      final c = int.tryParse(e.substring(2), radix: 16);
      return c != null && c <= 0x10FFFF ? String.fromCharCode(c) : m.group(0)!;
    }
    if (e.startsWith('#')) {
      final c = int.tryParse(e.substring(1));
      return c != null && c <= 0x10FFFF ? String.fromCharCode(c) : m.group(0)!;
    }
    return _named[e.toLowerCase()] ?? m.group(0)!;
  });
}
