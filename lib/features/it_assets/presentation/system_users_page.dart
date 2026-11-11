// ============================================================
//  «کاربران سیستم» — فاز ۹-ج
//  آینهٔ `Pages/System/SystemUsers.razor` (مسیر وب: /system-users)
//
//  • کارت با هدر گرادیانی: «لیست کاربران سیستم» + شمارنده + «افزودن کاربر»
//  • جستجو: «جستجو (نام / شماره پرسنلی)...» + «N کاربر»
//  • جدول: # | نام و نام خانوادگی | شماره تماس | شماره پرسنلی | شرکت | واحد |
//    دسته‌بندی | وضعیت | عملیات (عکس / ویرایش / حذف)
//  • فرم افزودن/ویرایش: عکس کاربر، نام*، نام خانوادگی، شماره تماس،
//    شماره پرسنلی*، شرکت*، واحد، واحد سازمانی، دسته‌بندی، «کاربر فعال باشد»
//  • متن‌های خطا عیناً همان متن‌های وب
// ============================================================

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../shop/presentation/shop_style.dart';
import '../data/system_repository.dart';
import '../models/system_models.dart';
import 'system_style.dart';

class SystemUsersPage extends StatefulWidget {
  const SystemUsersPage({super.key});

  @override
  State<SystemUsersPage> createState() => _SystemUsersPageState();
}

class _SystemUsersPageState extends State<SystemUsersPage> {
  late final SystemRepository _repo;

  List<SystemUserRow> _items = const [];
  List<SystemCompanyRow> _companies = const [];
  List<SystemDepartmentRow> _departments = const [];
  List<SystemOrganizationRow> _organizations = const [];

  bool _loading = true;
  String? _error;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo = SystemRepository(context.read<ApiClient>());
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static String _clean(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '')
      .trim();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Future.wait<dynamic>([
        _repo.users(),
        _repo.companies(),
        _repo.departments(),
        _repo.organizations(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = r[0] as List<SystemUserRow>;
        _companies = r[1] as List<SystemCompanyRow>;
        _departments = r[2] as List<SystemDepartmentRow>;
        _organizations = r[3] as List<SystemOrganizationRow>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _clean(e);
      });
    }
  }

  /// همان فیلتر وب: نام کامل یا شماره پرسنلی
  List<SystemUserRow> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((u) {
      return u.fullName.toLowerCase().contains(q) ||
          u.staffNumber.toLowerCase().contains(q);
    }).toList();
  }

  String _companyName(int? id) {
    if (id == null) return '—';
    for (final c in _companies) {
      if (c.id == id) return c.name;
    }
    return '—';
  }

  String _deptName(int? id) {
    if (id == null) return '—';
    for (final d in _departments) {
      if (d.id == id) return d.name;
    }
    return '—';
  }

  Future<void> _openForm({SystemUserRow? user}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserFormSheet(
        repo: _repo,
        user: user,
        companies: _companies,
        departments: _departments,
        organizations: _organizations,
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _delete(SystemUserRow u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'حذف کاربر',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'کاربر «${u.fullName}» حذف شود؟',
          style: const TextStyle(fontSize: 12, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ShopColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteUser(u.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حذف ناموفق بود — ${_clean(e)}',
            style: const TextStyle(fontSize: 11.5),
          ),
          backgroundColor: ShopColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return Scaffold(
      backgroundColor: ShopColors.bg,
      appBar: AppBar(
        backgroundColor: ShopColors.surface,
        foregroundColor: ShopColors.ink,
        elevation: 0.5,
        title: const Text(
          'کاربران سیستم',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'بارگذاری مجدد',
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
        children: [
          const ShopHeader(
            title: 'کاربران سیستم',
            subtitle:
                'کاربران تجهیزات، شماره پرسنلی، شرکت و واحد سازمانی هر کاربر',
            icon: Icons.people_alt_rounded,
            badge: 'IT',
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: ShopColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ShopColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xff4f8cff), Color(0xff8e5cff)],
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.people_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'لیست کاربران سیستم',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          Fa.digits(rows.length),
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xff4f5b8a),
                          ),
                        ),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xff4f5b8a),
                          minimumSize: const Size(0, 30),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add_rounded, size: 14),
                        label: const Text(
                          'افزودن کاربر',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontSize: 11.5),
                          decoration: InputDecoration(
                            hintText: 'جستجو (نام / شماره پرسنلی)...',
                            hintStyle: const TextStyle(
                              fontSize: 10.5,
                              color: ShopColors.inkFaint,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 17,
                              color: ShopColors.inkFaint,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 11,
                            ),
                            filled: true,
                            fillColor: const Color(0xfff7f9fd),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: ShopColors.line,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: ShopColors.line,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ShopTag(
                        text: '${Fa.digits(rows.length)} کاربر',
                        color: ShopColors.inkFaint,
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SystemNote(
                      text: 'بارگذاری کاربران ناموفق بود — $_error',
                      color: ShopColors.danger,
                      icon: Icons.cloud_off_rounded,
                    ),
                  )
                else if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 16),
                    child: SystemNote(
                      text: 'کاربری یافت نشد.',
                      color: ShopColors.inkFaint,
                      icon: Icons.person_off_rounded,
                    ),
                  )
                else
                  // ---------- کارت‌ویو موبایل (همان ساختار وب) ----------
                  for (var i = 0; i < rows.length; i++)
                    _userCard(rows[i], i + 1),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _userCard(SystemUserRow u, int index) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xfff9fbfe),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: ShopColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(repo: _repo, user: u, size: 34),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.fullName.isEmpty ? '—' : u.fullName,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: ShopColors.ink,
                      ),
                    ),
                    Text(
                      '#${Fa.digits(index)} — ${u.roleFa}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: ShopColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              ShopTag(
                text: u.isActive ? 'فعال ✅' : 'غیرفعال',
                color: u.isActive ? ShopColors.ok : ShopColors.inkFaint,
              ),
            ],
          ),
          const SizedBox(height: 6),
          _row('شماره تماس', (u.phone ?? '').trim().isEmpty ? '—' : u.phone!,
              ltr: true),
          _row('شماره پرسنلی', u.staffNumber.isEmpty ? '—' : u.staffNumber),
          _row('شرکت', _companyName(u.companyId)),
          _row('واحد', _deptName(u.departmentId)),
          _row('دسته‌بندی', u.roleFa),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    foregroundColor: ShopColors.seed,
                    side: BorderSide(
                      color: ShopColors.seed.withValues(alpha: 0.35),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  onPressed: () => _openForm(user: u),
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: const Text(
                    'ویرایش',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    foregroundColor: ShopColors.danger,
                    side: BorderSide(
                      color: ShopColors.danger.withValues(alpha: 0.35),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  onPressed: () => _delete(u),
                  icon: const Icon(Icons.delete_rounded, size: 14),
                  label: const Text(
                    'حذف',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool ltr = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(fontSize: 9.5, color: ShopColors.inkFaint),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: ShopColors.ink,
            ),
          ),
        ),
      ],
    ),
  );
}

/// آواتار کاربر — عکس از `api/SystemUsers/photo/{id}`، وگرنه حرف اول نام
class _Avatar extends StatelessWidget {
  const _Avatar({required this.repo, required this.user, this.size = 34});

  final SystemRepository repo;
  final SystemUserRow user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = user.fullName.trim().isEmpty
        ? '؟'
        : user.fullName.trim().characters.first;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          repo.photoUrl(user.id),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: const Color(0xffe0e9ff),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: TextStyle(
                fontSize: size * 0.42,
                fontWeight: FontWeight.w900,
                color: const Color(0xff1d4ed8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// فرم افزودن/ویرایش کاربر (همان مودال وب)
class _UserFormSheet extends StatefulWidget {
  const _UserFormSheet({
    required this.repo,
    this.user,
    required this.companies,
    required this.departments,
    required this.organizations,
  });

  final SystemRepository repo;
  final SystemUserRow? user;
  final List<SystemCompanyRow> companies;
  final List<SystemDepartmentRow> departments;
  final List<SystemOrganizationRow> organizations;

  @override
  State<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<_UserFormSheet> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final TextEditingController _staffNumber;

  int _companyId = 0;
  int? _departmentId;
  int? _organizationId;
  String _role = 'User';
  bool _isActive = true;
  String _error = '';
  bool _busy = false;

  List<int>? _photoBytes;
  String? _photoName;

  bool get _isEdit => (widget.user?.id ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _firstName = TextEditingController(text: u?.firstName ?? '');
    _lastName = TextEditingController(text: u?.lastName ?? '');
    _phone = TextEditingController(text: u?.phone ?? '');
    _staffNumber = TextEditingController(text: u?.staffNumber ?? '');
    _companyId = u?.companyId ?? 0;
    _departmentId = u?.departmentId;
    _organizationId = u?.organizationId;
    _role = (u?.role ?? '').trim().isEmpty ? 'User' : u!.role;
    _isActive = u?.isActive ?? true;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _staffNumber.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    // وب: «انتخاب عکس (JPG/PNG، حداکثر ۵MB)»
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        setState(() => _error = 'حجم عکس باید کمتر از ۵ مگابایت باشد.');
        return;
      }
      setState(() {
        _photoBytes = bytes;
        _photoName = file.name;
        _error = '';
      });
    } catch (e) {
      setState(() => _error = 'انتخاب عکس ناموفق بود — $e');
    }
  }

  Future<void> _save() async {
    setState(() => _error = '');
    if (_firstName.text.trim().isEmpty) {
      setState(() => _error = 'نام را وارد کنید.');
      return;
    }
    if (_staffNumber.text.trim().isEmpty) {
      setState(() => _error = 'شماره پرسنلی را وارد کنید.');
      return;
    }
    if (_companyId <= 0) {
      setState(
        () => _error =
            'یک شرکت انتخاب کنید. اگر لیست شرکت‌ها خالی است، اول از صفحه‌ی «شناسه سیستم» شرکت بسازید و مطمئن شوید API در حال اجراست.',
      );
      return;
    }
    final deptOk = _departmentId != null &&
        widget.departments.any(
          (d) => d.id == _departmentId && d.companyId == _companyId,
        );
    final row = SystemUserRow(
      id: widget.user?.id ?? 0,
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      staffNumber: _staffNumber.text.trim(),
      departmentId: deptOk ? _departmentId : null,
      companyId: _companyId,
      organizationId: _organizationId,
      role: _role,
      isActive: _isActive,
    );
    setState(() => _busy = true);
    try {
      final id = await widget.repo.saveUser(row);
      if (_photoBytes != null && id > 0) {
        try {
          await widget.repo.uploadUserPhoto(
            userId: id,
            fileName: _photoName ?? 'user-$id.jpg',
            bytes: _photoBytes!,
          );
        } catch (e) {
          // مثل وب: کاربر ذخیره شده؛ فقط عکس ثبت نشده
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'کاربر ذخیره شد ولی عکس ثبت نشد — ${e.toString().replaceFirst('ApiException: ', '')}',
                  style: const TextStyle(fontSize: 11),
                ),
                backgroundColor: ShopColors.warn,
              ),
            );
          }
        }
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e
            .toString()
            .replaceFirst('ApiException: ', '')
            .replaceFirst('Exception: ', '')
            .trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCompanies = widget.companies.where((c) => c.isActive).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final depts = widget.departments
        .where((d) => d.companyId == _companyId)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final orgs = widget.organizations
        .where(
          (o) =>
              o.isActive &&
              (_companyId == 0 || o.companyId == null || o.companyId == _companyId),
        )
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      expand: false,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: ShopColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 6),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: ShopColors.line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEdit ? 'ویرایش کاربر' : 'افزودن کاربر جدید',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: ShopColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                children: [
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SystemNote(
                        text: _error,
                        color: ShopColors.danger,
                        icon: Icons.error_outline_rounded,
                      ),
                    ),
                  SystemCard(
                    title: 'عکس کاربر (اختیاری — بدون عکس، عکس پیش‌فرض نمایش داده می‌شود)',
                    icon: Icons.photo_camera_front_rounded,
                    child: Row(
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: _photoBytes != null
                                ? Image.memory(
                                    Uint8List.fromList(_photoBytes!),
                                    fit: BoxFit.cover,
                                  )
                                : widget.user != null
                                ? Image.network(
                                    widget.repo.photoUrl(widget.user!.id),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const _DefaultAvatar(),
                                  )
                                : const _DefaultAvatar(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 34),
                                  foregroundColor: ShopColors.seed,
                                  side: BorderSide(
                                    color: ShopColors.seed.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(17),
                                  ),
                                ),
                                onPressed: _pickPhoto,
                                icon: const Icon(
                                  Icons.cloud_upload_rounded,
                                  size: 14,
                                ),
                                label: const Text(
                                  'انتخاب عکس (JPG/PNG، حداکثر ۵MB)',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (_photoBytes != null)
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 28),
                                    foregroundColor: ShopColors.danger,
                                  ),
                                  onPressed: () => setState(() {
                                    _photoBytes = null;
                                    _photoName = null;
                                  }),
                                  icon: const Icon(
                                    Icons.cancel_rounded,
                                    size: 13,
                                  ),
                                  label: const Text(
                                    'حذف عکس',
                                    style: TextStyle(fontSize: 9.5),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SystemCard(
                    title: 'اطلاعات کاربر',
                    icon: Icons.badge_rounded,
                    child: Column(
                      children: [
                        _txt(
                          label: 'نام',
                          required: true,
                          controller: _firstName,
                          hint: 'مثلاً: علی',
                        ),
                        _txt(label: 'نام خانوادگی', controller: _lastName),
                        _txt(
                          label: 'شماره تماس',
                          controller: _phone,
                          hint: '09xxxxxxxxx',
                          ltr: true,
                          keyboardType: TextInputType.phone,
                        ),
                        _txt(
                          label: 'شماره پرسنلی',
                          required: true,
                          controller: _staffNumber,
                        ),

                        // شرکت
                        ShopField(
                          label: 'شرکت',
                          required: true,
                          child: activeCompanies.isEmpty
                              ? const SystemNote(
                                  text:
                                      'شرکتی ثبت نشده — اول از صفحه‌ی «شناسه سیستم» یک شرکت بسازید.',
                                  color: ShopColors.warn,
                                  icon: Icons.domain_disabled_rounded,
                                )
                              : DropdownButtonFormField<int>(
                                  initialValue:
                                      _companyId > 0 ? _companyId : null,
                                  isDense: true,
                                  isExpanded: true,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: ShopColors.ink,
                                  ),
                                  decoration: _dec('— انتخاب کنید —'),
                                  items: [
                                    for (final c in activeCompanies)
                                      DropdownMenuItem(
                                        value: c.id,
                                        child: Text(
                                          c.name,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                  ],
                                  onChanged: (v) => setState(() {
                                    _companyId = v ?? 0;
                                    _departmentId = null;
                                  }),
                                ),
                        ),

                        // واحد
                        ShopField(
                          label: 'واحد (دپارتمان)',
                          child: DropdownButtonFormField<int>(
                            initialValue: _departmentId,
                            isDense: true,
                            isExpanded: true,
                            style: const TextStyle(
                              fontSize: 11,
                              color: ShopColors.ink,
                            ),
                            decoration: _dec('— بدون واحد —'),
                            items: [
                              for (final d in depts)
                                DropdownMenuItem(
                                  value: d.id,
                                  child: Text(
                                    d.name,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _departmentId = v),
                          ),
                        ),

                        // واحد سازمانی
                        ShopField(
                          label: 'واحد سازمانی (برای شماره نامه)',
                          child: DropdownButtonFormField<int>(
                            initialValue: _organizationId,
                            isDense: true,
                            isExpanded: true,
                            style: const TextStyle(
                              fontSize: 11,
                              color: ShopColors.ink,
                            ),
                            decoration: _dec('— بدون واحد سازمانی —'),
                            items: [
                              for (final o in orgs)
                                DropdownMenuItem(
                                  value: o.organizationId,
                                  child: Text(
                                    o.label,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _organizationId = v),
                          ),
                        ),

                        // دسته‌بندی
                        ShopField(
                          label: 'دسته‌بندی (سطح دسترسی سیستمی)',
                          hint:
                              'دسترسی‌های جزئی‌تر (مدیر منابع انسانی، کارشناس IT و ...) از صفحه «کاربران» ← تب «نقش‌ها و دسترسی‌ها» اختصاص داده می‌شوند.',
                          child: DropdownButtonFormField<String>(
                            initialValue: SystemUserRow.roleOptions.containsKey(
                              _role,
                            )
                                ? _role
                                : 'User',
                            isDense: true,
                            isExpanded: true,
                            style: const TextStyle(
                              fontSize: 11,
                              color: ShopColors.ink,
                            ),
                            decoration: _dec('— انتخاب کنید —'),
                            items: [
                              for (final e
                                  in SystemUserRow.roleOptions.entries)
                                DropdownMenuItem(
                                  value: e.key,
                                  child: Text(
                                    e.value,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _role = v ?? 'User'),
                          ),
                        ),

                        // فعال
                        Row(
                          children: [
                            Switch(
                              value: _isActive,
                              onChanged: (v) => setState(() => _isActive = v),
                            ),
                            const Text(
                              'کاربر فعال باشد',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: ShopColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 42),
                            foregroundColor: ShopColors.inkSoft,
                            side: const BorderSide(color: ShopColors.line),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(21),
                            ),
                          ),
                          onPressed: _busy
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text(
                            'انصراف',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: ShopColors.seed,
                            minimumSize: const Size(0, 42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(21),
                            ),
                          ),
                          onPressed: _busy ? null : _save,
                          icon: _busy
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_rounded, size: 16),
                          label: Text(
                            _busy
                                ? 'در حال ذخیره…'
                                : (_isEdit ? 'ذخیره تغییرات' : 'افزودن کاربر'),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _txt({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool required = false,
    bool ltr = false,
    TextInputType? keyboardType,
  }) => ShopField(
    label: label,
    required: required,
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
      style: const TextStyle(fontSize: 11.5, color: ShopColors.ink),
      decoration: _dec(hint),
    ),
  );

  InputDecoration _dec(String? hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 10.5, color: ShopColors.inkFaint),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
    filled: true,
    fillColor: const Color(0xfff7f9fd),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: ShopColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: ShopColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: ShopColors.accent),
    ),
  );
}

class _DefaultAvatar extends StatelessWidget {
  const _DefaultAvatar();

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xffeef2fa),
    alignment: Alignment.center,
    child: const Icon(
      Icons.person_rounded,
      size: 30,
      color: Color(0xff9aa7c2),
    ),
  );
}
