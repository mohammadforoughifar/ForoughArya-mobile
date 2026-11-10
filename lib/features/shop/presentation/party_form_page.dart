// ============================================================
//  فرم ثبت/ویرایش طرف حساب
//  آینهٔ مودال وب: Shared/PartyFormModal.razor — همان فیلدها، همان ترتیب
//
//  ۱) نام  *
//  ۲) موبایل
//  ۳) تلفن ثابت
//  ۴) آدرس
//  ۵) شناسه ملی خریدار + کد پستی خریدار
//  ۶) معرف — فقط برای مشتری
//  ۷) یادداشت
//  ۸) سوییچ «فعال باشد»
//  دکمه‌ها: انصراف | ثبت (وب: «ثبت» / «ذخیره تغییرات»)
//
//  ⚠️ فیلد اضافه‌ای ساخته نشده؛ ایمیل/کد اقتصادی/تاریخ تولد در وب نیست.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../data/shop_repository.dart';
import '../models/shop_models.dart';
import 'shop_style.dart';

class PartyFormPage extends StatefulWidget {
  const PartyFormPage({
    super.key,
    required this.type,
    this.source,
  });

  final int type;
  final Party? source;

  @override
  State<PartyFormPage> createState() => _PartyFormPageState();
}

class _PartyFormPageState extends State<PartyFormPage> {
  late final ShopRepository _repo =
      Provider.of<ShopRepository?>(context, listen: false) ??
      ShopRepository(context.read<ApiClient>());

  bool get _isEdit => (widget.source?.id ?? 0) > 0;

  late final _name = TextEditingController(text: widget.source?.name ?? '');
  late final _mobile = TextEditingController(
    text: widget.source?.mobile ?? '',
  );
  late final _phone = TextEditingController(text: widget.source?.phone ?? '');
  late final _address = TextEditingController(
    text: widget.source?.address ?? '',
  );
  late final _taxId = TextEditingController(text: widget.source?.taxId ?? '');
  late final _postal = TextEditingController(
    text: widget.source?.postalCode ?? '',
  );
  late final _note = TextEditingController(text: widget.source?.note ?? '');

  late bool _active;
  int? _referrerId;
  String? _referrerLabel;
  List<Referrer> _referrers = const [];
  bool _loadingReferrers = false;
  bool _saving = false;

  /// وب: AllowReferrerPicker پیش‌فرض true است
  bool get _allowReferrerPicker => widget.type == PartyType.customer;

  @override
  void initState() {
    super.initState();
    _active = widget.source?.isActive ?? true;
    _referrerId = widget.source?.referrerId;
    _referrerLabel = widget.source?.referrerName;
    if (_allowReferrerPicker) _loadReferrers();
  }

  @override
  void dispose() {
    for (final c in [_name, _mobile, _phone, _address, _taxId, _postal, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadReferrers() async {
    setState(() => _loadingReferrers = true);
    final list = await _repo.referrers();
    if (!mounted) return;
    setState(() {
      _referrers = list;
      _loadingReferrers = false;
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _toast('نام را وارد کنید.');
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    final base =
        widget.source ??
        Party(type: widget.type);
    final payload = base.copyWith(
      type: widget.type,
      name: _name.text,
      phone: _phone.text,
      mobile: _mobile.text,
      address: _address.text,
      taxId: _taxId.text,
      postalCode: _postal.text,
      note: _note.text,
      isActive: _active,
      referrerId: _referrerId,
      clearReferrer: _referrerId == null,
    );
    try {
      await _repo.saveParty(payload);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.toString());
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12.5)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ShopColors.danger,
      ),
    );
  }

  Future<void> _pickReferrer() async {
    final picked = await showModalBottomSheet<Referrer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => _ReferrerSheet(items: _referrers, loading: _loadingReferrers),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _referrerId = picked.id;
      _referrerLabel = picked.label;
    });
  }

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 11.5, color: ShopColors.inkFaint),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  @override
  Widget build(BuildContext context) {
    final isSupplier = widget.type == PartyType.supplier;
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        title: Text(
          _isEdit
              ? (isSupplier ? 'ویرایش تأمین‌کننده' : 'ویرایش مشتری')
              : (isSupplier ? 'ثبت تأمین‌کننده جدید' : 'ثبت مشتری جدید'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ShopColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ShopColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShopField(
                  label: 'نام',
                  required: true,
                  child: TextField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: _dec('نام شخص یا شرکت'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                ShopField(
                  label: 'موبایل',
                  child: TextField(
                    controller: _mobile,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: _dec('۰۹۱۲۰۰۰۰۰۰۰'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                ShopField(
                  label: 'تلفن ثابت',
                  child: TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: _dec('۰۲۱۰۰۰۰۰۰۰۰'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                ShopField(
                  label: 'آدرس',
                  child: TextField(
                    controller: _address,
                    minLines: 2,
                    maxLines: 4,
                    decoration: _dec('آدرس کامل'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                ShopField(
                  label: 'شناسه ملی خریدار',
                  hint: 'برای صورتحساب رسمی',
                  child: TextField(
                    controller: _taxId,
                    textDirection: TextDirection.ltr,
                    decoration: _dec('شناسه ملی / کد اقتصادی'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                ShopField(
                  label: 'کد پستی خریدار',
                  child: TextField(
                    controller: _postal,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    decoration: _dec('کد پستی ۱۰ رقمی'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (_allowReferrerPicker)
                  ShopField(
                    label: 'معرف',
                    child: InkWell(
                      onTap: _loadingReferrers ? null : _pickReferrer,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ShopColors.line),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _loadingReferrers
                                    ? 'در حال دریافت معرف‌ها…'
                                    : ((_referrerLabel ?? '').isEmpty
                                          ? 'بدون معرف'
                                          : _referrerLabel!),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: (_referrerLabel ?? '').isEmpty
                                      ? ShopColors.inkFaint
                                      : ShopColors.ink,
                                ),
                              ),
                            ),
                            if (_referrerId != null)
                              GestureDetector(
                                onTap: () => setState(() {
                                  _referrerId = null;
                                  _referrerLabel = null;
                                }),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: ShopColors.inkFaint,
                                  ),
                                ),
                              ),
                            const Icon(
                              Icons.expand_more_rounded,
                              size: 18,
                              color: ShopColors.inkFaint,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ShopField(
                  label: 'یادداشت',
                  child: TextField(
                    controller: _note,
                    minLines: 2,
                    maxLines: 4,
                    decoration: _dec('یادداشت داخلی'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Row(
                  children: [
                    Switch(
                      value: _active,
                      onChanged: (v) => setState(() => _active = v),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'فعال باشد',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ShopColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: ShopColors.surface,
            border: Border(top: BorderSide(color: ShopColors.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    side: const BorderSide(color: ShopColors.line),
                    foregroundColor: ShopColors.inkSoft,
                  ),
                  child: const Text('انصراف'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: ShopColors.seed,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isEdit ? 'ذخیره تغییرات' : 'ثبت'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReferrerSheet extends StatelessWidget {
  const _ReferrerSheet({required this.items, required this.loading});
  final List<Referrer> items;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: ShopColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'انتخاب معرف',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: CircularProgressIndicator(),
              )
            else if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'معرفی برای انتخاب وجود ندارد.',
                  style: TextStyle(fontSize: 12, color: ShopColors.inkFaint),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: ShopColors.line),
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    title: Text(
                      items[i].label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, items[i]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
