// ============================================================
//  ذخیره‌ساز پیش‌نویس‌های محلی ایمیل به تفکیک کاربر
// ============================================================

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/email_models.dart';
import '../models/office_common.dart';

class EmailDraftStore {
  const EmailDraftStore(this._storage);

  final FlutterSecureStorage _storage;

  String _key(int userId) => 'email_drafts_u$userId';

  Future<List<EmailDraft>> list(int userId) async {
    try {
      final raw = await _storage.read(key: _key(userId));
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final drafts = decoded
          .whereType<Map>()
          .map((e) => EmailDraft.fromJson(asMap(e)))
          .toList();
      drafts.sort(
        (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return drafts;
    } catch (_) {
      return const [];
    }
  }

  Future<void> upsert(int userId, EmailDraft draft) async {
    final current = List<EmailDraft>.from(await list(userId));
    final idx = current.indexWhere((d) => d.localId == draft.localId);
    if (idx >= 0) {
      current[idx] = draft;
    } else {
      current.insert(0, draft);
    }
    await _save(userId, current);
  }

  Future<void> remove(int userId, String localId) async {
    final current = (await list(userId)).where((d) => d.localId != localId).toList();
    await _save(userId, current);
  }

  Future<void> _save(int userId, List<EmailDraft> items) async {
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await _storage.write(key: _key(userId), value: encoded);
  }
}
