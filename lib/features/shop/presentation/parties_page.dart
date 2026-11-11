// ============================================================
//  طرف حساب‌ها (مشتریان | تأمین‌کنندگان)
//  آینهٔ صفحهٔ وب: /parties  →  Pages/Catalog/Parties.razor
//
//  هر آنچه در وب هست و اینجا هم هست:
//    • دو زبانهٔ سگمنتی «مشتریان» و «تأمین‌کنندگان» (هرکدام اگر مجوزش باشد)
//    • صفحه‌بندی ۱۲تایی مثل وب
//    • ستون‌های نام، موبایل، تلفن ثابت، آدرس، (معرف و ثبت‌کننده برای مشتری)،
//      مانده حساب + نشان چک برگشتی + نشان اقساط معوق، وضعیت فعال، ویرایش/حذف
//    • دکمهٔ «ثبت مشتری جدید / ثبت تأمین‌کننده جدید» با همان متن وب
//    • حذف با تأیید «آیا از حذف «...» مطمئن هستید؟»
//  هر چیزی که اینجا نیست: جستجو (وب هم ندارد)، مرتب‌سازی سفارشی (وب ندارد).
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../data/shop_perms.dart';
import '../data/shop_repository.dart';
import '../models/shop_models.dart';
import 'party_form_page.dart';
import 'shop_style.dart';

class PartiesPage extends StatefulWidget {
  const PartiesPage({super.key, this.initialType = PartyType.customer});

  final int initialType;

  @override
  State<PartiesPage> createState() => _PartiesPageState();
}

class _PartiesPageState extends State<PartiesPage> {
  late final ShopRepository _repo =
      Provider.of<ShopRepository?>(context, listen: false) ??
      ShopRepository(context.read<ApiClient>());
  late final ShopPerms _perms =
      ShopPerms(context.read<AuthController>().session);

  /// اندازهٔ صفحه در وب: ۱۲
  static const int pageSize = 12;

  late int _type = widget.initialType;
  int _page = 1;
  int _total = 0;
  List<Party> _items = const [];
  bool _loading = true;
  String? _error;
  int _version = 0;

  int get _pageCount => _total <= 0 ? 1 : ((_total + pageSize - 1) ~/ pageSize);

  @override
  void initState() {
    super.initState();
    // مثل وب: اگر کاربر فقط مجوز تأمین‌کننده دارد، همان زبانه پیش‌فرض می‌شود
    if (!_perms.canSeeCustomers && _perms.canSeeSuppliers) {
      _type = PartyType.supplier;
    }
    _load();
  }

  Future<void> _load() async {
    if (!_perms.anyPartyAccess) {
      setState(() {
        _loading = false;
        _items = const [];
        _total = 0;
      });
      return;
    }
    final v = ++_version;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _repo.parties(
        type: _type,
        skip: (_page - 1) * pageSize,
        take: pageSize,
      );
      if (!mounted || v != _version) return;
      setState(() {
        _items = res.items;
        _total = res.total ?? res.items.length;
        if (_page > _pageCount) _page = _pageCount;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || v != _version) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _setType(int t) {
    if (t == _type) return;
    setState(() {
      _type = t;
      _page = 1;
    });
    _load();
  }

  void _changePage(int p) {
    if (p < 1 || p > _pageCount || p == _page) return;
    setState(() => _page = p);
    _load();
  }

  Future<void> _openForm([Party? source]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            PartyFormPage(type: _type, source: source),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Party p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text(
          'حذف طرف حساب',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'آیا از حذف «${p.name}» مطمئن هستید؟',
          style: const TextStyle(fontSize: 12.5, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ShopColors.danger,
              minimumSize: const Size(80, 40),
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.deleteParty(p.id, type: _type);
      if (!mounted) return;
      _toast('طرف حساب حذف شد.', ok: true);
      _load();
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString());
    }
  }

  void _toast(String msg, {bool ok = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12.5)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? ShopColors.ok : ShopColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <String>[];
    if (_perms.canSeeCustomers) tabs.add('مشتریان');
    if (_perms.canSeeSuppliers) tabs.add('تأمین‌کنندگان');
    final tabIndex = _perms.canSeeCustomers
        ? (_type == PartyType.customer ? 0 : tabs.length - 1)
        : 0;

    return Scaffold(
      backgroundColor: ShopColors.bg,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ShopHeader(
                title: _perms.partyPageTitle,
                subtitle:
                    'مدیریت اطلاعات هویتی، سوابق تماس، مانده حساب مالی و وضعیت چک‌های برگشتی',
                icon: Icons.people_alt_rounded,
                badge: _type == PartyType.customer
                    ? 'پایگاه مشتریان'
                    : 'شبکه تأمین‌کنندگان',
                actions: [
                  if (_perms.canCreateParty(_type))
                    ShopHeaderButton(
                      label: _type == PartyType.supplier
                          ? 'ثبت تأمین‌کننده جدید'
                          : 'ثبت مشتری جدید',
                      icon: Icons.person_add_alt_1_rounded,
                      filled: true,
                      onTap: () => _openForm(),
                    ),
                ],
              ),
            ),
            if (!_perms.anyPartyAccess)
              const SliverPadding(
                padding: EdgeInsets.all(14),
                sliver: SliverToBoxAdapter(
                  child: ShopEmpty(
                    icon: Icons.lock_outline_rounded,
                    title: 'به این بخش دسترسی ندارید',
                    subtitle:
                        'برای دریافت دسترسی «مشتریان» یا «تأمین‌کنندگان» با مدیر سیستم تماس بگیرید.',
                  ),
                ),
              )
            else ...[
              if (tabs.length > 1)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                  sliver: SliverToBoxAdapter(
                    child: ShopSegmented(
                      labels: tabs,
                      index: tabIndex,
                      onChanged: (i) {
                        if (!_perms.canSeeCustomers) return;
                        _setType(
                          i == 0 ? PartyType.customer : PartyType.supplier,
                        );
                      },
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'فهرست ${_type == PartyType.customer ? 'مشتریان' : 'تأمین‌کنندگان'}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: ShopColors.ink,
                          ),
                        ),
                      ),
                      ShopTag(
                        text: '${Fa.number(_total)} طرف حساب',
                        icon: Icons.people_outline_rounded,
                      ),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const SliverPadding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  sliver: SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_error != null)
                SliverPadding(
                  padding: const EdgeInsets.all(14),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        ShopEmpty(
                          icon: Icons.wifi_off_rounded,
                          title: 'دریافت فهرست انجام نشد',
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
                  ),
                )
              else if (_items.isEmpty)
                const SliverPadding(
                  padding: EdgeInsets.all(14),
                  sliver: SliverToBoxAdapter(
                    child: ShopEmpty(
                      icon: Icons.people_outline_rounded,
                      title: 'طرف حسابی در این بخش ثبت نشده است',
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                  sliver: SliverList.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _PartyCard(
                      party: _items[i],
                      showReferrer: _type == PartyType.customer,
                      canEdit: _perms.canUpdateParty(_type),
                      canDelete: _perms.canDeleteParty(_type),
                      onEdit: () => _openForm(_items[i]),
                      onDelete: () => _delete(_items[i]),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                  sliver: SliverToBoxAdapter(child: _pager()),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _pager() {
    if (_pageCount <= 1) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ShopColors.line),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _page > 1 ? () => _changePage(_page - 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'صفحهٔ قبل',
          ),
          Expanded(
            child: Text(
              'صفحهٔ ${Fa.digits(_page)} از ${Fa.digits(_pageCount)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ShopColors.inkSoft,
              ),
            ),
          ),
          IconButton(
            onPressed: _page < _pageCount ? () => _changePage(_page + 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'صفحهٔ بعد',
          ),
        ],
      ),
    );
  }
}

class _PartyCard extends StatelessWidget {
  const _PartyCard({
    required this.party,
    required this.showReferrer,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  final Party party;
  final bool showReferrer;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final initial = party.name.trim().isEmpty
        ? '؟'
        : party.name.trim().characters.first;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ShopColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ShopColors.seed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: ShopColors.seed,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      party.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: ShopColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if ((party.mobile ?? '').isNotEmpty) party.mobile!,
                        if ((party.phone ?? '').isNotEmpty) party.phone!,
                      ].isEmpty
                          ? 'بدون شماره تماس'
                          : [
                              if ((party.mobile ?? '').isNotEmpty) party.mobile!,
                              if ((party.phone ?? '').isNotEmpty) party.phone!,
                            ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              ShopTag(
                text: party.isActive ? 'فعال' : 'غیرفعال',
                color: party.isActive ? ShopColors.ok : ShopColors.inkFaint,
              ),
            ],
          ),
          if ((party.address ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _row(Icons.place_outlined, party.address!),
          ],
          if (showReferrer)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  _row(
                    Icons.badge_outlined,
                    (party.referrerName ?? '').isEmpty
                        ? 'بدون معرف'
                        : party.referrerName!,
                    flex: false,
                  ),
                  const SizedBox(width: 10),
                  if ((party.registeredByName ?? '').isNotEmpty)
                    Flexible(
                      child: Tooltip(
                        message: _registrarTitle(party),
                        child: ShopTag(
                          text: party.registeredByName!,
                          color: ShopColors.ok,
                          icon: Icons.how_to_reg_rounded,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: ShopColors.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'مانده حساب',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: ShopColors.inkFaint,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${Fa.number(party.balance)} ریال',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: party.balance > 0
                            ? ShopColors.ok
                            : party.balance < 0
                            ? ShopColors.danger
                            : ShopColors.inkFaint,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      party.balance > 0
                          ? '(بستانکار)'
                          : party.balance < 0
                          ? '(بدهکار)'
                          : '',
                      style: const TextStyle(
                        fontSize: 9,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                  ],
                ),
                if (party.hasBouncedCheque) ...[
                  const SizedBox(height: 6),
                  ShopTag(
                    text:
                        '${Fa.number(party.bouncedChequesCount)} چک برگشتی (${Fa.number(party.bouncedChequesTotal)})',
                    color: ShopColors.danger,
                    icon: Icons.cancel_outlined,
                  ),
                ],
                if (party.hasOverdueInstallment) ...[
                  const SizedBox(height: 6),
                  ShopTag(
                    text:
                        '${Fa.number(party.overdueInstallmentsCount)} قسط معوق (${Fa.number(party.overdueInstallmentsTotal)})',
                    color: ShopColors.warn,
                    icon: Icons.history_rounded,
                  ),
                ],
              ],
            ),
          ),
          if (canEdit || canDelete)
            Row(
              children: [
                if (canEdit)
                  _action(
                    'ویرایش',
                    Icons.edit_outlined,
                    ShopColors.seed,
                    onEdit,
                  ),
                if (canDelete) ...[
                  const SizedBox(width: 8),
                  _action(
                    'حذف',
                    Icons.delete_outline_rounded,
                    ShopColors.danger,
                    onDelete,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  static String _registrarTitle(Party p) {
    final parts = <String>['ثبت‌کننده: ${p.registeredByName}'];
    if ((p.registeredByReferrerName ?? '').isNotEmpty) {
      parts.add('پروندهٔ معرف: ${p.registeredByReferrerName}');
    }
    if (p.registeredAt != null) {
      parts.add('تاریخ ثبت: ${Fa.date(p.registeredAt!.toIso8601String(), time: false)}');
    }
    return parts.join(' | ');
  }

  Widget _row(IconData icon, String text, {bool flex = true}) {
    final child = Row(
      mainAxisSize: flex ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: ShopColors.inkFaint),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: ShopColors.inkSoft,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
    return flex ? child : child;
  }

  Widget _action(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
