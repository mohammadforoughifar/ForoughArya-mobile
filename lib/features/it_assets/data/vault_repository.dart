// ============================================================
//  لایهٔ دادهٔ «گاوصندوق رمزهای تجهیزات» — فاز ۹-ه
//  اندپوینت‌ها عیناً از `ItVaultController.cs` (Route: api/it-vault)
//    GET  companies
//    GET  ?companyId&category&q            (هرگز رمز برنمی‌گردد)
//    POST · PUT {id} · DELETE {id}
//    POST unlock                          → { token, expiresAt, minutes }
//    POST {id}/reveal  { purpose, token } → { password, extraSecret }
//    GET  logs?companyId&credentialId&take
// ============================================================

import '../../../core/network/api_client.dart';
import '../models/vault_models.dart';

class VaultRepository {
  VaultRepository(this._api);

  final ApiClient _api;

  static const _base = '/api/it-vault';

  Future<List<VaultCompanyRow>> companies() async {
    final r = await _api.get<dynamic>('$_base/companies');
    final d = r.data;
    return (d is List ? d : const [])
        .whereType<Map>()
        .map((e) => VaultCompanyRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<VaultRow>> list({
    required int companyId,
    String? category,
    String? q,
  }) async {
    final r = await _api.get<dynamic>(
      _base,
      query: {
        'companyId': companyId,
        if ((category ?? '').isNotEmpty && category != 'All')
          'category': category,
        if ((q ?? '').trim().isNotEmpty) 'q': q!.trim(),
      },
    );
    final d = r.data;
    return (d is List ? d : const [])
        .whereType<Map>()
        .map((e) => VaultRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> create(VaultSaveRequest req) =>
      _api.post<dynamic>(_base, req.toJson());

  Future<void> update(int id, VaultSaveRequest req) =>
      _api.put<dynamic>('$_base/$id', req.toJson());

  Future<void> delete(int id) => _api.delete<dynamic>('$_base/$id');

  /// تأیید دوبارهٔ رمز ورود کاربر — توکن ۱۰ دقیقه‌ای
  Future<VaultUnlockResult> unlock(String password) async {
    final r = await _api.post<dynamic>('$_base/unlock', {'password': password});
    final d = r.data;
    return d is Map
        ? VaultUnlockResult.fromJson(Map<String, dynamic>.from(d))
        : const VaultUnlockResult();
  }

  /// رمزگشایی یک رکورد. خطای ۴۲۳ یعنی «گاوصندوق قفل است».
  Future<VaultSecret> reveal(
    int id, {
    required String token,
    required String purpose,
  }) async {
    // توکن هم در بدنه و هم در هدر پذیرفته می‌شود؛ بدنه کافی است.
    final r = await _api.post<dynamic>(
      '$_base/$id/reveal',
      {'purpose': purpose, 'token': token},
    );
    final d = r.data;
    return d is Map
        ? VaultSecret.fromJson(Map<String, dynamic>.from(d))
        : const VaultSecret();
  }

  Future<List<VaultLogRow>> logs({
    required int companyId,
    int? credentialId,
    int take = 200,
  }) async {
    final r = await _api.get<dynamic>(
      '$_base/logs',
      query: {
        'companyId': companyId,
        if ((credentialId ?? 0) > 0) 'credentialId': credentialId,
        'take': take,
      },
    );
    final d = r.data;
    return (d is List ? d : const [])
        .whereType<Map>()
        .map((e) => VaultLogRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

/// بررسی قفل بودن از روی خطای رابط برنامه‌نویسی (کد ۴۲۳)
bool isVaultLockedError(Object e) =>
    (e is ApiException && e.statusCode == 423) ||
    e.toString().contains('423') ||
    e.toString().contains('گاوصندوق قفل است');

/// متن خطای تمیز برای نمایش
String vaultErrorText(Object e) => e
    .toString()
    .replaceFirst('ApiException: ', '')
    .replaceFirst('Exception: ', '')
    .trim();
