// ============================================================
//  گزارش گردش حساب و مانده اشخاص (طلب و بدهی)
//  آینهٔ صفحهٔ وب: /operations/reports/party-statements
//                 → Pages/Operations/PartyStatementsReport.razor
//
//  همان اجزا:
//    • چهار کارت شاخص: کل مطالبات (طلب ما) + تعداد بدهکاران،
//      کل بدهی‌ها (بستانکاری اشخاص) + تعداد بستانکاران، تراز خالص،
//      تعداد طرف‌حساب‌ها
//    • فیلترها: جستجو، دسته‌بندی شخص (همه/مشتری/تأمین‌کننده)،
//      وضعیت مانده (همه/بدهکاران/بستانکاران/حساب‌های باز)، از تاریخ، تا تاریخ
//    • جدول خلاصه: مانده افتتاحیه، گردش بدهکار، گردش بستانکار، مانده نهایی،
//      وضعیت حساب، دکمهٔ «ریز صورت‌حساب»
//    • نمای ریز صورت‌حساب: مانده نهایی، گردش خط‌به‌خط، جمع کل گردش دوره
//  ⚠️ دکمهٔ «چاپ رسمی» وب در موبایل معادل چاپ ندارد؛ حذف شده تا چیزی خارج
//     از وب ساخته نشود (وب فقط چاپ مرورگر دارد).
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../../core/utils/jalali_picker.dart';
import '../data/shop_repository.dart';
import 'shop_style.dart';

class PartyStatementsPage extends StatefulWidget {
  const PartyStatementsPage({super.key});

  @override
  State<PartyStatementsPage> createState() => _PartyStatementsPageState();
}

class _PartyStatementsPageState extends State<PartyStatementsPage> {
  late final ShopRepository _repo =
      Provider.of<ShopRepository?>(context, listen: false) ??
      ShopRepository(context.read<ApiClient>());

  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  int? _type; // null = همه
  String _balanceFilter = 'all'; // all | debtors | creditors | nonzero
  DateTime? _from;
  DateTime? _to;

  Map<String, dynamic> _report = const {};
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;

  /// نمای ریز صورت‌حساب
  Map<String, dynamic>? _detail;
  bool _detailLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.statementReport(
        type: _type,
        from: _from,
        to: _to,
        search: _searchCtrl.text,
      );
      if (!mounted) return;
      final raw = data['items'] ?? data['Items'];
      setState(() {
        _report = data;
        _items = raw is List
            ? raw
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
            : const [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openDetail(int partyId) async {
    setState(() {
      _detailLoading = true;
      _detail = const {};
    });
    try {
      final d = await _repo.partyStatement(partyId, from: _from, to: _to);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _detailLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _detailLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString(), style: const TextStyle(fontSize: 12.5)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ShopColors.danger,
        ),
      );
    }
  }

  /// فیلتر وضعیت مانده — مثل وب روی فهرست دریافتی اعمال می‌شود
  List<Map<String, dynamic>> get _filtered {
    return _items.where((it) {
      final closing = _d(it['closingBalance'] ?? it['ClosingBalance']);
      switch (_balanceFilter) {
        case 'debtors':
          return closing > 0;
        case 'creditors':
          return closing < 0;
        case 'nonzero':
          return closing != 0;
        default:
          return true;
      }
    }).toList();
  }

  static double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
  static int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
  static String _s(dynamic v) {
    final s = v?.toString();
    return (s == null || s == 'null') ? '' : s;
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showJalaliDatePicker(
      context,
      initial: isFrom ? _from : _to,
      title: isFrom ? 'از تاریخ' : 'تا تاریخ',
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_detail != null) return _buildDetail();
    final receivable = _d(_report['totalReceivable']);
    final payable = _d(_report['totalPayable']);
    final net = receivable - payable;

    return Scaffold(
      backgroundColor: ShopColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ShopHeader(
              title: 'گزارش طلب و بدهی اشخاص',
              subtitle:
                  'پایش مطالبات وصول‌نشده، دیون به تأمین‌کنندگان، اثر مانده افتتاحیه و ریز تراکنش‌ها',
              icon: Icons.account_balance_wallet_rounded,
              badge: 'دفتر معین اشخاص',
              actions: [
                ShopHeaderButton(
                  label: 'به‌روزرسانی داده‌ها',
                  icon: Icons.refresh_rounded,
                  onTap: _loading ? () {} : _load,
                ),
              ],
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    ShopEmpty(
                      icon: Icons.wifi_off_rounded,
                      title: 'دریافت گزارش انجام نشد',
                      subtitle: _error,
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('تلاش دوباره'),
                    ),
                  ],
                ),
              )
            else ...[
              // ---------- کارت‌های شاخص ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ShopKpi(
                            title: 'کل مطالبات (طلب ما)',
                            value: Fa.number(receivable),
                            unit: 'ریال',
                            icon: Icons.south_west_rounded,
                            color: ShopColors.danger,
                            footer:
                                '${Fa.number(_i(_report['debtorCount']))} شخص بدهکار',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ShopKpi(
                            title: 'کل بدهی‌ها (بستانکاری اشخاص)',
                            value: Fa.number(payable),
                            unit: 'ریال',
                            icon: Icons.north_east_rounded,
                            color: ShopColors.ok,
                            footer:
                                '${Fa.number(_i(_report['creditorCount']))} شخص بستانکار',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ShopKpi(
                            title: 'تراز خالص مطالبات / بدهی',
                            value: Fa.number(net.abs()),
                            unit: 'ریال',
                            icon: Icons.balance_rounded,
                            color: net >= 0
                                ? ShopColors.indigo
                                : ShopColors.warn,
                            footer: net >= 0
                                ? 'تراز مثبت (مازاد مطالبات)'
                                : 'تراز منفی (مازاد بدهی‌ها)',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ShopKpi(
                            title: 'کل طرف‌حساب‌های فعال',
                            value: Fa.number(_items.length),
                            unit: 'طرف حساب ثبت‌شده',
                            icon: Icons.receipt_long_rounded,
                            color: ShopColors.inkSoft,
                            footer: 'شامل کلیه مشتریان و تأمین‌کنندگان',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ---------- فیلترها ----------
              Container(
                margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ShopColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ShopColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'نام مشتری، تأمین‌کننده یا موبایل…',
                        hintStyle: const TextStyle(
                          fontSize: 11.5,
                          color: ShopColors.inkFaint,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(fontSize: 12.5),
                      onChanged: (v) {
                        _debounce?.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 450),
                          _load,
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _dropdown<int?>(
                            label: 'دسته‌بندی شخص',
                            value: _type,
                            items: const [
                              MapEntry(null, 'همه اشخاص'),
                              MapEntry(0, 'فقط مشتریان'),
                              MapEntry(1, 'فقط تأمین‌کنندگان'),
                            ],
                            onChanged: (v) {
                              setState(() => _type = v);
                              _load();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _dropdown<String>(
                            label: 'وضعیت مانده حساب',
                            value: _balanceFilter,
                            items: const [
                              MapEntry('all', 'همه وضعیت‌ها'),
                              MapEntry('debtors', 'فقط بدهکاران (طلب ما)'),
                              MapEntry('creditors', 'فقط بستانکاران (بدهی ما)'),
                              MapEntry('nonzero', 'فقط حساب‌های باز'),
                            ],
                            onChanged: (v) => setState(
                              () => _balanceFilter = v ?? 'all',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _dateBox(
                            'از تاریخ',
                            _from,
                            () => _pickDate(isFrom: true),
                            () => setState(() => _from = null),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _dateBox(
                            'تا تاریخ',
                            _to,
                            () => _pickDate(isFrom: false),
                            () => setState(() => _to = null),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ---------- فهرست اشخاص ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'صورت وضعیت اشخاص و مانده نهایی',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: ShopColors.ink,
                        ),
                      ),
                    ),
                    ShopTag(text: '${Fa.number(_filtered.length)} شخص'),
                  ],
                ),
              ),
              if (_filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: ShopEmpty(
                    icon: Icons.inbox_rounded,
                    title: 'هیچ شخصی با فیلترهای جاری یافت نشد',
                    subtitle:
                        'می‌توانید عبارات جستجو را تغییر دهید یا فیلترها را حذف کنید.',
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  child: Column(
                    children: [
                      for (final it in _filtered)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _StatementRow(
                            item: it,
                            onDetail: () =>
                                _openDetail(_i(it['partyId'] ?? it['PartyId'])),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------- نمای ریز صورت‌حساب ----------------
  Widget _buildDetail() {
    final d = _detail!;
    if (_detailLoading) {
      return Scaffold(
        backgroundColor: ShopColors.bg,
        appBar: AppBar(title: const Text('ریز صورت‌حساب')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final name = _s(d['partyName']);
    final isCustomer = _i(d['partyType']) == 0;
    final closing = _d(d['closingBalance']);
    final rowsRaw = d['rows'] ?? d['Rows'];
    final rows = rowsRaw is List
        ? rowsRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: Text(
          'صورت‌حساب مالی «$name»',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: () => setState(() => _detail = null),
            child: const Text(
              'بازگشت',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ShopColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ShopColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ShopTag(
                      text: isCustomer ? 'مشتری' : 'تأمین‌کننده',
                      color: isCustomer ? ShopColors.seed : ShopColors.teal,
                    ),
                    const SizedBox(width: 8),
                    if (_s(d['mobile']).isNotEmpty)
                      ShopTag(
                        text: _s(d['mobile']),
                        color: ShopColors.inkSoft,
                        icon: Icons.call_outlined,
                      ),
                    if (_s(d['nationalCode']).isNotEmpty) ...[
                      const SizedBox(width: 8),
                      ShopTag(
                        text: 'کد ملی: ${_s(d['nationalCode'])}',
                        color: ShopColors.inkSoft,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: closing > 0
                        ? ShopColors.danger.withValues(alpha: 0.07)
                        : closing < 0
                        ? ShopColors.ok.withValues(alpha: 0.07)
                        : ShopColors.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'مانده نهایی حساب',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: ShopColors.inkFaint,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${Fa.number(closing.abs())} ریال',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: closing > 0
                              ? ShopColors.danger
                              : closing < 0
                              ? ShopColors.ok
                              : ShopColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        closing > 0
                            ? 'بدهکار (طلب ما)'
                            : closing < 0
                            ? 'بستانکار (طلب شخص)'
                            : 'تسویه کامل',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: ShopColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'گردش خط‌به‌خط اسناد و تسویه‌ها',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: ShopColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            const ShopEmpty(title: 'گردشی در این دوره ثبت نشده است')
          else
            Column(
              children: [
                for (final r in rows)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: ShopColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: r['isOpening'] == true
                            ? ShopColors.warn.withValues(alpha: 0.45)
                            : ShopColors.line,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _s(r['title']),
                                maxLines: 2,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: ShopColors.ink,
                                ),
                              ),
                            ),
                            Text(
                              Fa.date(_s(r['date']), time: false),
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: ShopColors.inkFaint,
                              ),
                            ),
                          ],
                        ),
                        if (_s(r['description']).isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            _s(r['description']),
                            style: const TextStyle(
                              fontSize: 11,
                              color: ShopColors.inkSoft,
                              height: 1.6,
                            ),
                          ),
                        ],
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            if (_s(r['documentNumber']).isNotEmpty)
                              ShopTag(
                                text: 'سند ${_s(r['documentNumber'])}',
                                color: ShopColors.inkSoft,
                              ),
                            if (r['isOpening'] == true) ...[
                              const SizedBox(width: 6),
                              const ShopTag(
                                text: 'مانده افتتاحیه',
                                color: ShopColors.warn,
                                icon: Icons.star_rounded,
                              ),
                            ],
                            const Spacer(),
                            if (_d(r['debit']) != 0)
                              Text(
                                'بد ${Fa.number(_d(r['debit']))}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: ShopColors.danger,
                                ),
                              ),
                            if (_d(r['credit']) != 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                'بس ${Fa.number(_d(r['credit']))}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: ShopColors.ok,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text(
                              'مانده لحظه‌ای:',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: ShopColors.inkFaint,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${Fa.number(_d(r['balance']).abs())} ${_d(r['balance']) > 0 ? '(بد)' : _d(r['balance']) < 0 ? '(بس)' : ''}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: _d(r['balance']) > 0
                                    ? ShopColors.danger
                                    : _d(r['balance']) < 0
                                    ? ShopColors.ok
                                    : ShopColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ShopColors.deep,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'جمع کل گردش دوره',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    'بد ${Fa.number(_d(d['totalDebit']))}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xffffd0d0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'بس ${Fa.number(_d(d['totalCredit']))}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xffc9f5d4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<MapEntry<T, String>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: ShopColors.inkFaint,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          style: const TextStyle(
            fontSize: 11.5,
            color: ShopColors.ink,
            fontWeight: FontWeight.w600,
          ),
          items: [
            for (final e in items)
              DropdownMenuItem<T>(value: e.key, child: Text(e.value)),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _dateBox(
    String label,
    DateTime? value,
    VoidCallback onTap,
    VoidCallback onClear,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: ShopColors.inkFaint,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ShopColors.line),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  size: 15,
                  color: ShopColors.inkFaint,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    value == null ? 'انتخاب تاریخ' : jalaliShort(value),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: value == null
                          ? ShopColors.inkFaint
                          : ShopColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (value != null)
                  GestureDetector(
                    onTap: onClear,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: ShopColors.inkFaint,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatementRow extends StatelessWidget {
  const _StatementRow({required this.item, required this.onDetail});

  final Map<String, dynamic> item;
  final VoidCallback onDetail;

  static double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
  static int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
  static String _s(dynamic v) {
    final s = v?.toString();
    return (s == null || s == 'null') ? '' : s;
  }

  @override
  Widget build(BuildContext context) {
    final name = _s(item['partyName']);
    final isCustomer = _i(item['type'] ?? item['partyType']) == 0;
    final opening = _d(item['openingBalance']);
    final debit = _d(item['totalDebit'] ?? item['periodDebit']);
    final credit = _d(item['totalCredit'] ?? item['periodCredit']);
    final closing = _d(item['closingBalance']);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ShopColors.ink,
                  ),
                ),
              ),
              ShopTag(
                text: isCustomer ? 'مشتری' : 'تأمین‌کننده',
                color: isCustomer ? ShopColors.seed : ShopColors.teal,
              ),
            ],
          ),
          if (_s(item['nationalCode']).isNotEmpty ||
              _s(item['mobile']).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                [
                  if (_s(item['nationalCode']).isNotEmpty)
                    'کد ملی: ${_s(item['nationalCode'])}',
                  if (_s(item['mobile']).isNotEmpty) _s(item['mobile']),
                ].join('  ·  '),
                style: const TextStyle(
                  fontSize: 10.5,
                  color: ShopColors.inkFaint,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: ShopColors.bg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              children: [
                _line(
                  'مانده افتتاحیه',
                  opening == 0
                      ? '۰'
                      : '${Fa.number(opening.abs())} ${opening > 0 ? 'طلب' : 'بدهی'}',
                  opening == 0
                      ? ShopColors.inkFaint
                      : (opening > 0 ? ShopColors.danger : ShopColors.ok),
                ),
                const SizedBox(height: 4),
                _line(
                  'گردش بدهکار (افزایش)',
                  debit == 0 ? '۰' : Fa.number(debit),
                  ShopColors.danger,
                ),
                const SizedBox(height: 4),
                _line(
                  'گردش بستانکار (کاهش)',
                  credit == 0 ? '۰' : Fa.number(credit),
                  ShopColors.ok,
                ),
                const Divider(height: 12, color: ShopColors.line),
                _line(
                  'مانده نهایی',
                  closing == 0
                      ? 'تسویه صفر'
                      : '${Fa.number(closing.abs())} ریال',
                  closing > 0
                      ? ShopColors.danger
                      : closing < 0
                      ? ShopColors.ok
                      : ShopColors.inkFaint,
                  boldValue: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ShopTag(
                text: closing > 0
                    ? 'بدهکار (طلب ما)'
                    : closing < 0
                    ? 'بستانکار (بدهی ما)'
                    : 'تسویه کامل',
                color: closing > 0
                    ? ShopColors.danger
                    : closing < 0
                    ? ShopColors.ok
                    : ShopColors.inkFaint,
              ),
              const Spacer(),
              GestureDetector(
                onTap: onDetail,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: ShopColors.seed.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 14,
                        color: ShopColors.seed,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'ریز صورت‌حساب',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: ShopColors.seed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(
    String label,
    String value,
    Color color, {
    bool boldValue = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: boldValue ? 12.5 : 11.5,
            fontWeight: boldValue ? FontWeight.w900 : FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
