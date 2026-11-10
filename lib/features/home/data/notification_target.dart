// ============================================================
//  پیدا کردن «همان رکورد» از روی یک اعلان
//
//  چرا لازم است: خیلی از اعلان‌های بک‌اند فقط «شناسهٔ ارجاع» یا
//  «عنوان» دارند و شناسهٔ خود نامه/دستور کار/صورت‌جلسه را نمی‌دهند.
//  این فایل با چند استراتژی، رکورد دقیق را پیدا می‌کند تا کلیک روی
//  اعلان، خودِ همان سند را باز کند (نه صفحهٔ اصلی ماژول):
//
//    ۱) شناسهٔ مستقیم در بدنهٔ اعلان
//    ۲) جست‌وجو با عنوان اعلان در همان ماژول (q/search)
//    ۳) جست‌وجو با شناسهٔ ارجاع / شناسهٔ نمایشی داخل عنوان
//    ۴) اگر هیچ‌کدام، آخرین سند همان ماژول (بهتر از صفحهٔ خالی)
// ============================================================

import '../../../core/network/api_client.dart';
import '../../misc/data/minutes_repository.dart';
import '../../office_automation/data/office_repository.dart';
import '../../office_automation/models/office_common.dart';
import '../../work_orders/data/work_order_repository.dart';
import '../models/home_models.dart';

/// مقصد نهایی کلیک روی اعلان
class NotificationTarget {
  const NotificationTarget({
    required this.kind,
    this.id,
    this.erjaId,
    this.letterKind,
    this.reason,
  });

  /// wo | minutes | letter | email | none
  final String kind;
  final int? id;
  final int? erjaId;
  final LetterKind? letterKind;

  /// توضیح اینکه چطور پیدا شد (برای عیب‌یابی/لاگ)
  final String? reason;

  bool get isResolved => id != null && id! > 0;
}

class NotificationResolver {
  NotificationResolver(this._api);

  final ApiClient _api;

  /// تلاش برای پیدا کردن رکورد مقصدِ اعلان
  Future<NotificationTarget> resolve(NotificationItem n) async {
    final kind = n.entityKind;
    if (kind == 'wo') return _resolveWorkOrder(n);
    if (kind == 'minutes') return _resolveMinutes(n);
    if (kind == 'letter') return _resolveLetter(n);
    if (kind == 'email') {
      return NotificationTarget(kind: 'email', id: n.entityId, reason: 'email');
    }
    return NotificationTarget(kind: 'none', reason: 'نوع اعلان مشخص نیست');
  }

  // ---------------- دستور کار ----------------
  Future<NotificationTarget> _resolveWorkOrder(NotificationItem n) async {
    if ((n.entityId ?? 0) > 0) {
      return NotificationTarget(kind: 'wo', id: n.entityId, reason: 'شناسهٔ اعلان');
    }
    final repo = WorkOrderRepository(_api);
    for (final tab in const ['mine', 'all', 'created', 'assigned']) {
      try {
        final page = await repo.list(tab, pageSize: 50);
        final hit = _matchWorkOrder(page.items, n);
        if (hit != null) {
          return NotificationTarget(kind: 'wo', id: hit, reason: 'جست‌وجو در $tab');
        }
      } catch (_) {}
    }
    // آخرین دستور کار همان ماژول
    try {
      final page = await repo.list('mine', pageSize: 1);
      if (page.items.isNotEmpty) {
        return NotificationTarget(
          kind: 'wo',
          id: page.items.first.id,
          reason: 'آخرین دستور کار',
        );
      }
    } catch (_) {}
    return const NotificationTarget(kind: 'wo', reason: 'پیدا نشد');
  }

  int? _matchWorkOrder(List<dynamic> items, NotificationItem n) {
    final numbers = _numbersIn(n);
    for (final o in items) {
      final id = (o.id as int);
      final number = (o.number as String? ?? '').trim();
      if (number.isNotEmpty && numbers.isNotEmpty) {
        final norm = _digitsOf(number);
        for (final num in numbers) {
          final n2 = _digitsOf(num);
          // مطابقت کامل، یا شمارهٔ اعلان با بخش انتهایی شمارهٔ سند یکی است
          if (norm == n2 || (n2.length >= 9 && norm.endsWith(n2))) {
            return id;
          }
        }
      }
      if ((o.title as String).trim() == n.title.trim()) return id;
    }
    return null;
  }

  // ---------------- صورت‌جلسه ----------------
  Future<NotificationTarget> _resolveMinutes(NotificationItem n) async {
    if ((n.entityId ?? 0) > 0) {
      return NotificationTarget(
        kind: 'minutes',
        id: n.entityId,
        reason: 'شناسهٔ اعلان',
      );
    }
    final repo = MinutesRepository(_api);
    final numbers = _numbersIn(n);
    for (final q in _queries(n)) {
      try {
        final res = await repo.fetchList(search: q, take: 30);
        for (final m in res.items) {
          if (_numbersIn(n).contains(m.id.toString())) {
            return NotificationTarget(
              kind: 'minutes',
              id: m.id,
              reason: 'شناسهٔ نمایشی',
            );
          }
          if (_similar(m.title, n.title)) {
            return NotificationTarget(
              kind: 'minutes',
              id: m.id,
              reason: 'عنوان مشابه',
            );
          }
        }
      } catch (_) {}
    }
    // تلاش مستقیم: بعضی اعلان‌ها شناسهٔ صورت‌جلسه را در متن دارند
    for (final num in numbers) {
      final id = int.tryParse(num);
      if (id == null || id <= 0) continue;
      try {
        await repo.fetchDetail(id);
        return NotificationTarget(
          kind: 'minutes',
          id: id,
          reason: 'شناسه در متن اعلان',
        );
      } catch (_) {}
    }
    try {
      final res = await repo.fetchList(take: 1);
      if (res.items.isNotEmpty) {
        return NotificationTarget(
          kind: 'minutes',
          id: res.items.first.id,
          reason: 'آخرین صورت‌جلسه',
        );
      }
    } catch (_) {}
    return const NotificationTarget(kind: 'minutes', reason: 'پیدا نشد');
  }

  // ---------------- نامه‌ها ----------------
  Future<NotificationTarget> _resolveLetter(NotificationItem n) async {
    final repo = OfficeAutomationRepository(_api);
    final kinds = _candidateLetterKinds(n);
    final numbers = _numbersIn(n);

    // ۱) شناسهٔ ارجاع در لینک
    final erjaId = _erjaFromLink(n.targetLink);
    if (erjaId != null) {
      return NotificationTarget(
        kind: 'letter',
        id: (n.entityId ?? erjaId),
        erjaId: erjaId,
        letterKind: kinds.first,
        reason: 'شناسهٔ ارجاع',
      );
    }

    // ۲) جست‌وجو در کارتابل‌های همان ماژول
    for (final k in kinds) {
      for (final q in _queries(n)) {
        try {
          final page = await _inboxOf(repo, k, q);
          for (final l in page.items) {
            if (numbers.contains(l.letterNumber) ||
                numbers.contains(l.sadereNumber ?? '') ||
                _similar(l.title, n.title)) {
              return NotificationTarget(
                kind: 'letter',
                id: l.letterId,
                erjaId: l.erjaId,
                letterKind: k,
                reason: 'جست‌وجوی «$q»',
              );
            }
          }
        } catch (_) {}
      }
    }

    // ۳) شناسهٔ مستقیم نامه در متن
    if ((n.entityId ?? 0) > 0) {
      return NotificationTarget(
        kind: 'letter',
        id: n.entityId,
        letterKind: kinds.first,
        reason: 'شناسهٔ اعلان',
      );
    }

    // ۴) آخرین نامهٔ کارتابل
    for (final k in kinds) {
      try {
        final page = await _inboxOf(repo, k, null);
        if (page.items.isNotEmpty) {
          final l = page.items.first;
          return NotificationTarget(
            kind: 'letter',
            id: l.letterId,
            erjaId: l.erjaId,
            letterKind: k,
            reason: 'آخرین نامهٔ کارتابل',
          );
        }
      } catch (_) {}
    }
    return NotificationTarget(
      kind: 'letter',
      letterKind: kinds.first,
      reason: 'پیدا نشد',
    );
  }

  Future<Paged<dynamic>> _inboxOf(
    OfficeAutomationRepository repo,
    LetterKind k,
    String? q,
  ) async {
    switch (k) {
      case LetterKind.inner:
        return await repo.innerInbox(search: q, pageSize: 40);
      case LetterKind.outgoing:
        return await repo.outgoingInbox(search: q, pageSize: 40);
      case LetterKind.incoming:
        return await repo.incomingInbox(search: q, pageSize: 40);
    }
  }

  List<LetterKind> _candidateLetterKinds(NotificationItem n) {
    final hay = [
      n.targetLink,
      n.formName,
      n.title,
      n.body,
    ].map((e) => e ?? '').join(' ').toLowerCase();
    final first = hay.contains('outgoing') || hay.contains('صادره')
        ? LetterKind.outgoing
        : hay.contains('incoming') || hay.contains('وارده')
        ? LetterKind.incoming
        : LetterKind.inner;
    // اول همان حدس، بعد بقیه (اگر متن گمراه‌کننده بود)
    return [
      first,
      ...LetterKind.values.where((k) => k != first),
    ];
  }

  // ---------------- کمکی‌ها ----------------
  /// همهٔ اعداد معنادار متن اعلان (شمارهٔ نامه، شناسه و …)
  Set<String> _numbersIn(NotificationItem n) {
    final text = [
      n.title,
      n.body ?? '',
      n.targetLink ?? '',
      n.formName ?? '',
    ].join(' ');
    final out = <String>{};
    // شمارهٔ ترکیبی مثل WO-1404-78 یا 1404/2187
    for (final m in RegExp(r'[A-Za-z]{2,6}[-/][0-9۰-۹]{2,4}[-/][0-9۰-۹]{1,6}')
        .allMatches(text)) {
      out.add(_toEn(m.group(0)!));
    }
    // الگوی شمارهٔ نامه: ۱۴۰۴/۲۱۸۷ یا 1404-2187
    for (final m in RegExp(r'[0-9۰-۹]{2,4}[/\-][0-9۰-۹]{1,6}').allMatches(text)) {
      out.add(_toEn(m.group(0)!));
    }
    // اعداد مستقل ۳ رقمی به بالا (شناسه‌ها)
    for (final m in RegExp(r'(?<![0-9۰-۹])[0-9۰-۹]{3,7}(?![0-9۰-۹])').allMatches(text)) {
      out.add(_toEn(m.group(0)!));
    }
    return out;
  }

  /// فقط حروف/اعداد — برای مقایسهٔ شماره‌ها با جداکننده‌های متفاوت
  String _digitsOf(String s) =>
      _toEn(s).toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  String _toEn(String s) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const en = '0123456789';
    var r = s;
    for (var i = 0; i < fa.length; i++) {
      r = r.replaceAll(fa[i], en[i]);
    }
    return r;
  }

  Iterable<String> _queries(NotificationItem n) sync* {
    final t = n.title.trim();
    if (t.isNotEmpty) yield t;
    // کلمات کلیدی معنادار (بدون کلمات پرتکرار اعلان)
    const stop = {
      'ارجاع',
      'نامه',
      'شما',
      'به',
      'برای',
      'جدید',
      'اعلان',
      'دستور',
      'کار',
      'صورت‌جلسه',
      'صورتجلسه',
      'شد',
      'است',
      'در',
      'از',
      'و',
      'یک',
    };
    final words = t
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3 && !stop.contains(w));
    if (words.isNotEmpty) yield words.take(3).join(' ');
    for (final num in _numbersIn(n)) {
      yield num;
    }
  }

  bool _similar(String a, String b) {
    final x = a.trim();
    final y = b.trim();
    if (x.isEmpty || y.isEmpty) return false;
    return x == y || x.contains(y) || y.contains(x);
  }

  int? _erjaFromLink(String? link) {
    if (link == null || link.isEmpty) return null;
    final m = RegExp(r'[?&](?:erjaId|ErjaId|erja)=(\d+)').firstMatch(link);
    return m == null ? null : int.tryParse(m.group(1)!);
  }
}
