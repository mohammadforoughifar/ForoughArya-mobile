// ============================================================
//  میز فرماندهی «اتوماسیون اداری و دبیرخانه یکپارچه توکا»
//  طراحی اجرایی فوق‌حرفه‌ای هم‌تراز با وب (`NavMenu.razor` + `Pages/Office/*`)
//  و معماری چندتب زنده (`IndexedStack`) + نمای دوگانهٔ بنتو / پوشه‌ای:
//    • هدر یکپارچهٔ یاقوتی-نیلی بدون تکرار اپ‌بار در تب‌های توکار
//    • تب‌های زنده با حفظ وضعیت: میز فرماندهی | داخلی | صادره | وارده | دبیرخانه | ایمیل | ایمیل شخصی
//    • نوار نبض زندهٔ کارتابل (خوانده‌نشده، نوبت امضا، صف ثبت دبیرخانه، ایمیل)
//    • داک اقدام فوری (ایجاد نامه داخلی/صادره/وارده، ثبت دبیرخانه، ارسال ایمیل)
//    • دسترسی کامل به تمام آیتم‌های وب با رعایت ۱۰۰٪ مجوزهای RBAC
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/web_access.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../../it_assets/presentation/doc_archive_cartable_page.dart';
import '../../misc/presentation/minutes_list_page.dart';
import '../data/email_repository.dart';
import '../data/office_repository.dart';
import '../models/letter_models.dart';
import 'email_page.dart';
import 'letter_detail_page.dart';
import 'letter_editor_page.dart';
import 'letter_mailbox_page.dart';
import 'office_dabirkhane_page.dart';
import 'office_style.dart';
import 'office_tools_pages.dart';
import 'office_widgets.dart';

enum _OfficeLayoutMode { bento, folders }

class _WorkspaceTabSpec {
  const _WorkspaceTabSpec({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.builder,
    this.badge = 0,
  });

  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final int badge;
  final Widget Function() builder;
}

class _HubItemSpec {
  const _HubItemSpec({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge,
    this.featured = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? badge;
  final bool featured;
}

class _HubGroupSpec {
  const _HubGroupSpec({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.items,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<_HubItemSpec> items;
}

class OfficeAutomationPage extends StatefulWidget {
  const OfficeAutomationPage({super.key});

  @override
  State<OfficeAutomationPage> createState() => _OfficeAutomationPageState();
}

class _OfficeAutomationPageState extends State<OfficeAutomationPage> {
  OfficeAutomationRepository get _repo =>
      Provider.of<OfficeAutomationRepository?>(context, listen: false) ??
      OfficeAutomationRepository(context.read<ApiClient>());

  EmailRepository get _emailRepo =>
      Provider.of<EmailRepository?>(context, listen: false) ??
      EmailRepository(context.read<ApiClient>());

  String _activeTabId = 'hub';
  _OfficeLayoutMode _layoutMode = _OfficeLayoutMode.bento;
  final Set<String> _expandedGroups = {
    'correspondence',
    'secretariat',
    'email',
  };

  bool _pulseLoading = false;
  int _innerUnread = 0;
  int _outgoingUnread = 0;
  int _signingPending = 0;
  int _incomingUnread = 0;
  int _dabirkhanePending = 0;
  int _dabirkhaneTotal = 0;
  int _emailUnread = 0;
  List<({LetterKind kind, LetterListItem item})> _urgentFeed = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPulse());
  }

  Future<void> _refreshPulse() async {
    if (!mounted || _pulseLoading) return;
    final session = Provider.of<AuthController?>(
      context,
      listen: false,
    )?.session;
    final access = WebAccess(session, unrestrictedWhenNull: true);

    setState(() => _pulseLoading = true);
    try {
      int innerUnread = 0;
      int outgoingUnread = 0;
      int signingPending = 0;
      int incomingUnread = 0;
      int dabirkhanePending = 0;
      int dabirkhaneTotal = 0;
      int emailUnread = 0;
      final feed = <({LetterKind kind, LetterListItem item})>[];

      final futures = <Future<void>>[];

      if (access.canSeeInnerLetters) {
        futures.add(() async {
          try {
            final p = await _repo.innerInbox(
              page: 1,
              pageSize: 4,
              unreadOnly: true,
            );
            innerUnread = p.totalCount;
            for (final it in p.items.take(2)) {
              feed.add((kind: LetterKind.inner, item: it));
            }
          } catch (_) {}
        }());
      }

      if (access.canSeeOutgoingLetters) {
        futures.add(() async {
          try {
            final p = await _repo.outgoingInbox(
              page: 1,
              pageSize: 3,
              unreadOnly: true,
            );
            outgoingUnread = p.totalCount;
            for (final it in p.items.take(2)) {
              feed.add((kind: LetterKind.outgoing, item: it));
            }
          } catch (_) {}
          try {
            final s = await _repo.signingInbox(page: 1, pageSize: 1);
            signingPending = s.totalCount;
          } catch (_) {}
        }());
      }

      if (access.canSeeIncomingLetters) {
        futures.add(() async {
          try {
            final p = await _repo.incomingInbox(
              page: 1,
              pageSize: 3,
              unreadOnly: true,
            );
            incomingUnread = p.totalCount;
            for (final it in p.items.take(2)) {
              feed.add((kind: LetterKind.incoming, item: it));
            }
          } catch (_) {}
        }());
      }

      if (access.canSeeOutgoingDabirkhane) {
        futures.add(() async {
          try {
            final st = await _repo.dabirkhaneStats();
            dabirkhanePending = st.pending;
            dabirkhaneTotal = st.total;
          } catch (_) {}
        }());
      }

      if (access.canSeeEmail) {
        futures.add(() async {
          try {
            final res = await _emailRepo.inbox(pageSize: 1);
            emailUnread += res.unreadCount;
          } catch (_) {}
        }());
      }

      await Future.wait(futures);
      if (!mounted) return;
      setState(() {
        _innerUnread = innerUnread;
        _outgoingUnread = outgoingUnread;
        _signingPending = signingPending;
        _incomingUnread = incomingUnread;
        _dabirkhanePending = dabirkhanePending;
        _dabirkhaneTotal = dabirkhaneTotal;
        _emailUnread = emailUnread;
        _urgentFeed = feed.take(5).toList();
        _pulseLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _pulseLoading = false);
    }
  }

  void _pushPage(Widget page) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page))
        .then((_) => _refreshPulse());
  }

  void _switchTab(String tabId, List<_WorkspaceTabSpec> tabs) {
    if (tabs.any((t) => t.id == tabId)) {
      setState(() => _activeTabId = tabId);
    }
  }

  List<_WorkspaceTabSpec> _buildTabs(WebAccess access) {
    return [
      _WorkspaceTabSpec(
        id: 'hub',
        label: 'میز فرماندهی',
        subtitle: 'نمای کلان مکاتبات، دبیرخانه یکپارچه و ابزارهای اتوماسیون',
        icon: Icons.space_dashboard_rounded,
        accent: const Color(0xff3357b0),
        builder: () => _buildHubBody(access),
      ),
      if (access.canSeeInnerLetters)
        _WorkspaceTabSpec(
          id: 'inner',
          label: 'داخلی',
          subtitle: 'کارتابل نامه‌های داخلی، ارجاع، هامش و بایگانی درختی',
          icon: Icons.mark_email_read_rounded,
          accent: OfficeColors.inner,
          badge: _innerUnread,
          builder: () => const LetterMailboxPage(
            kind: LetterKind.inner,
            embedded: true,
          ),
        ),
      if (access.canSeeOutgoingLetters)
        _WorkspaceTabSpec(
          id: 'outgoing',
          label: 'صادره',
          subtitle: 'کارتابل نامه‌های صادره، زنجیره امضای دیجیتال و پیش‌نویس‌ها',
          icon: Icons.outbox_rounded,
          accent: OfficeColors.outgoing,
          badge: _outgoingUnread + _signingPending,
          builder: () => const LetterMailboxPage(
            kind: LetterKind.outgoing,
            embedded: true,
          ),
        ),
      if (access.canSeeIncomingLetters)
        _WorkspaceTabSpec(
          id: 'incoming',
          label: 'وارده',
          subtitle: 'کارتابل نامه‌های وارده، شماره اندیکاتور و ارجاع سازمانی',
          icon: Icons.move_to_inbox_rounded,
          accent: OfficeColors.incoming,
          badge: _incomingUnread,
          builder: () => const LetterMailboxPage(
            kind: LetterKind.incoming,
            embedded: true,
          ),
        ),
      if (access.canSeeDabirkhane)
        _WorkspaceTabSpec(
          id: 'dabirkhane',
          label: 'دبیرخانه',
          subtitle: 'دبیرخانه یکپارچه صادره و وارده، چاپ سربرگ و رزرو اندیکاتور',
          icon: Icons.markunread_mailbox_rounded,
          accent: const Color(0xff20304f),
          badge: _dabirkhanePending,
          builder: () => OfficeDabirkhanePage(
            embedded: true,
            initialMode: access.canSeeOutgoingDabirkhane
                ? DabirkhaneMode.sadere
                : DabirkhaneMode.varede,
          ),
        ),
      if (access.canSeeEmail)
        _WorkspaceTabSpec(
          id: 'email',
          label: 'ایمیل',
          subtitle: 'پست الکترونیک سازمانی و حساب‌های رسمی دبیرخانه',
          icon: Icons.alternate_email_rounded,
          accent: OfficeColors.email,
          badge: _emailUnread,
          builder: () => const EmailPage(
            initialScope: EmailScope.corporate,
            embedded: true,
          ),
        ),
      if (access.canSeePersonalEmail)
        _WorkspaceTabSpec(
          id: 'personal_email',
          label: 'ایمیل شخصی',
          subtitle: 'صندوق پست الکترونیک اختصاصی کاربر',
          icon: Icons.person_pin_circle_rounded,
          accent: OfficeColors.emailPersonal,
          builder: () => const EmailPage(
            initialScope: EmailScope.personal,
            embedded: true,
          ),
        ),
    ];
  }

  List<_HubGroupSpec> _buildHubGroups(
    WebAccess access,
    List<_WorkspaceTabSpec> tabs,
  ) {
    final groups = <_HubGroupSpec>[];

    // ۱) کارتابل مکاتبات رسمی
    final corrItems = <_HubItemSpec>[
      if (access.canSeeInnerLetters)
        _HubItemSpec(
          id: 'cartable_inner',
          title: 'کارتابل نامه‌های داخلی',
          subtitle: 'دریافتی، ارسالی، پیش‌نویس، نشان‌شده و بایگانی درختی',
          icon: Icons.mark_email_read_rounded,
          color: OfficeColors.inner,
          featured: true,
          badge: _innerUnread > 0 ? '${Fa.digits(_innerUnread)} جدید' : null,
          onTap: () => _switchTab('inner', tabs),
        ),
      if (access.canSeeOutgoingLetters)
        _HubItemSpec(
          id: 'cartable_outgoing',
          title: 'کارتابل نامه‌های صادره',
          subtitle: 'پیش‌نویس، پیگیری صدور شماره و مکاتبات برون‌سازمانی',
          icon: Icons.outbox_rounded,
          color: OfficeColors.outgoing,
          featured: true,
          badge: _outgoingUnread > 0
              ? '${Fa.digits(_outgoingUnread)} جدید'
              : null,
          onTap: () => _switchTab('outgoing', tabs),
        ),
      if (access.canSeeOutgoingLetters)
        _HubItemSpec(
          id: 'signing_queue',
          title: 'زنجیره امضای دیجیتال من',
          subtitle: 'نامه‌های صادره در نوبت بررسی و امضای شما',
          icon: Icons.draw_rounded,
          color: OfficeColors.signing,
          badge: _signingPending > 0
              ? '${Fa.digits(_signingPending)} امضا'
              : null,
          onTap: () => _pushPage(
            const LetterMailboxPage(
              kind: LetterKind.outgoing,
              initialBox: LetterBox.signing,
            ),
          ),
        ),
      if (access.canSeeIncomingLetters)
        _HubItemSpec(
          id: 'cartable_incoming',
          title: 'کارتابل نامه‌های وارده',
          subtitle: 'نامه‌های رسیده از سازمان‌های بیرونی و ارجاعات من',
          icon: Icons.move_to_inbox_rounded,
          color: OfficeColors.incoming,
          featured: true,
          badge: _incomingUnread > 0
              ? '${Fa.digits(_incomingUnread)} جدید'
              : null,
          onTap: () => _switchTab('incoming', tabs),
        ),
    ];
    if (corrItems.isNotEmpty) {
      groups.add(
        _HubGroupSpec(
          id: 'correspondence',
          title: 'کارتابل مکاتبات رسمی',
          subtitle: 'گردش مکاتبات درون‌سازمانی، برون‌سازمانی و امضای دیجیتال',
          icon: Icons.inbox_rounded,
          accent: const Color(0xff3357b0),
          items: corrItems,
        ),
      );
    }

    // ۲) دبیرخانه یکپارچه و اندیکاتور
    final secItems = <_HubItemSpec>[
      if (access.canSeeOutgoingDabirkhane)
        _HubItemSpec(
          id: 'sec_outgoing',
          title: 'دبیرخانه نامه‌های صادره',
          subtitle:
              'ثبت روش ارسال، کد رهگیری، چاپ سربرگ A4/A5 و بایگانی دبیرخانه',
          icon: Icons.markunread_mailbox_rounded,
          color: const Color(0xff20304f),
          featured: true,
          badge: _dabirkhanePending > 0
              ? '${Fa.digits(_dabirkhanePending)} در انتظار'
              : (_dabirkhaneTotal > 0 ? Fa.digits(_dabirkhaneTotal) : null),
          onTap: () => _pushPage(
            const OfficeDabirkhanePage(initialMode: DabirkhaneMode.sadere),
          ),
        ),
      if (access.canSeeIncomingDabirkhane)
        _HubItemSpec(
          id: 'sec_incoming',
          title: 'دبیرخانه یکپارچه نامه‌های وارده',
          subtitle: 'ثبت، ارجاع سازمانی، نمودار گردش و بایگانی گروهی وارده',
          icon: Icons.domain_verification_rounded,
          color: const Color(0xff1466a6),
          featured: true,
          onTap: () => _pushPage(
            const OfficeDabirkhanePage(initialMode: DabirkhaneMode.varede),
          ),
        ),
      if (access.canCreateIncomingLetter || access.canSeeIncomingDabirkhane)
        _HubItemSpec(
          id: 'sec_reservations',
          title: 'رزرو شماره اندیکاتور',
          subtitle: 'رزرو تکی و دسته‌ای شماره ثبت برای نامه‌های وارده فیزیکی',
          icon: Icons.confirmation_number_rounded,
          color: const Color(0xffb4771e),
          onTap: () => _pushPage(
            const OfficeDabirkhanePage(
              initialMode: DabirkhaneMode.varede,
              openReservationsOnStart: true,
            ),
          ),
        ),
      if (access.canSeeLetterStructures)
        _HubItemSpec(
          id: 'letter_structures',
          title: 'ساختار شماره نامه و اندیکاتور',
          subtitle: 'چیدمان فرمت «سال / واحد / شماره» در کل سازمان',
          icon: Icons.format_list_numbered_rtl_rounded,
          color: const Color(0xff46536b),
          onTap: () => _pushPage(const LetterStructurePage()),
        ),
    ];
    if (secItems.isNotEmpty) {
      groups.add(
        _HubGroupSpec(
          id: 'secretariat',
          title: 'دبیرخانه یکپارچه و اندیکاتور',
          subtitle: 'ثبت رسمی مرسولات، چاپ سربرگ و مدیریت شماره‌گذاری',
          icon: Icons.account_balance_rounded,
          accent: const Color(0xff20304f),
          items: secItems,
        ),
      );
    }

    // ۳) پست الکترونیک سازمانی و شخصی
    final emailItems = <_HubItemSpec>[
      if (access.canSeeEmail)
        _HubItemSpec(
          id: 'corp_email',
          title: 'پست الکترونیک سازمانی',
          subtitle: 'مدیریت حساب‌های رسمی شرکت، دبیرخانه و پیوست‌ها',
          icon: Icons.alternate_email_rounded,
          color: OfficeColors.email,
          featured: true,
          badge: _emailUnread > 0 ? '${Fa.digits(_emailUnread)} جدید' : null,
          onTap: () => _switchTab('email', tabs),
        ),
      if (access.canSeePersonalEmail)
        _HubItemSpec(
          id: 'personal_email',
          title: 'ایمیل شخصی من',
          subtitle: 'صندوق پست الکترونیک اختصاصی متصل به حساب کاربری شما',
          icon: Icons.mail_lock_rounded,
          color: OfficeColors.emailPersonal,
          onTap: () => _switchTab('personal_email', tabs),
        ),
    ];
    if (emailItems.isNotEmpty) {
      groups.add(
        _HubGroupSpec(
          id: 'email',
          title: 'پست الکترونیک رسمی و شخصی',
          subtitle: 'ارتباطات ایمیلی برون‌سازمانی و صندوق شخصی',
          icon: Icons.forward_to_inbox_rounded,
          accent: OfficeColors.email,
          items: emailItems,
        ),
      );
    }

    // ۴) بایگانی، الگوها و تنظیمات مکاتبات
    final canAnyLetters =
        access.canSeeInnerLetters ||
        access.canSeeOutgoingLetters ||
        access.canSeeIncomingLetters;
    final toolItems = <_HubItemSpec>[
      if (access.canSee('MyArchive'))
        _HubItemSpec(
          id: 'personal_archive',
          title: 'بایگانی شخصی من',
          subtitle: 'پوشه‌بندی اختصاصی نامه‌ها و مستندات فردی',
          icon: Icons.folder_special_rounded,
          color: const Color(0xff1d4e89),
          onTap: () => _pushPage(const PersonalArchivePage()),
        ),
      if (access.canSeeInnerLetters || access.canManageLetterGroups)
        _HubItemSpec(
          id: 'recipient_groups',
          title: 'گروه‌های گیرندگان نامه',
          subtitle: 'تعریف گروه برای انتخاب یک‌ضرب در گیرنده، ارجاع و هامش',
          icon: Icons.groups_2_rounded,
          color: const Color(0xff3357b0),
          onTap: () => _pushPage(const LetterGroupsPage()),
        ),
      if (canAnyLetters)
        _HubItemSpec(
          id: 'amalgars',
          title: 'عناوین و دستورات ارجاع',
          subtitle: 'مدیریت قالب‌های دستور ارجاع («جهت اقدام»، «فوری» و ...)',
          icon: Icons.alt_route_rounded,
          color: const Color(0xff1f6e45),
          onTap: () => _pushPage(const AmalgarsManagerPage()),
        ),
      if (access.canSeeDocArchive)
        _HubItemSpec(
          id: 'doc_cartable',
          title: 'کارتابل آرشیو اسناد',
          subtitle: 'تأیید نسخه‌های مدارک و اعلان‌های آرشیو فنی و اداری',
          icon: Icons.inventory_rounded,
          color: const Color(0xffe11d48),
          onTap: () => _pushPage(const DocArchiveCartablePage()),
        ),
    ];
    if (toolItems.isNotEmpty) {
      groups.add(
        _HubGroupSpec(
          id: 'tools',
          title: 'بایگانی، گروه‌ها و قالب‌های ارجاع',
          subtitle: 'ابزارهای شتاب‌دهندهٔ مکاتبات و سازمان‌دهی پرونده‌ها',
          icon: Icons.tune_rounded,
          accent: const Color(0xff1d4e89),
          items: toolItems,
        ),
      );
    }

    // ۵) صورتجلسات و راهنما
    final coordItems = <_HubItemSpec>[
      if (access.canSeeMinutes)
        _HubItemSpec(
          id: 'meeting_minutes',
          title: 'صورتجلسات سازمانی',
          subtitle: 'ثبت جلسات، امضای حاضرین و ارسال مصوبات در قالب نامه/ایمیل',
          icon: Icons.assignment_rounded,
          color: const Color(0xff46536b),
          onTap: () => _pushPage(const MinutesListPage()),
        ),
      _HubItemSpec(
        id: 'office_guide',
        title: 'راهنمای جامع اتوماسیون اداری',
        subtitle: 'مرجع فرآیندهای مکاتبات، امضا و گردش کار دبیرخانه',
        icon: Icons.menu_book_rounded,
        color: const Color(0xff44547a),
        onTap: () => _pushPage(const OfficeGuidePage()),
      ),
    ];
    groups.add(
      _HubGroupSpec(
        id: 'coordination',
        title: 'جلسات و راهنمای اتوماسیون',
        subtitle: 'هماهنگی مصوبات جلسات و مستندات آموزشی سیستم',
        icon: Icons.hub_rounded,
        accent: const Color(0xff46536b),
        items: coordItems,
      ),
    );

    return groups;
  }

  void _openQuickCommandSheet(
    WebAccess access,
    List<_WorkspaceTabSpec> tabs,
  ) {
    final groups = _buildHubGroups(access, tabs);
    final allItems = [
      for (final g in groups)
        for (final it in g.items) (group: g.title, item: it),
    ];
    String q = '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final filtered = allItems.where((entry) {
            if (q.trim().isEmpty) return true;
            final needle = q.trim().toLowerCase();
            return entry.item.title.toLowerCase().contains(needle) ||
                entry.item.subtitle.toLowerCase().contains(needle) ||
                entry.group.toLowerCase().contains(needle);
          }).toList();

          return Directionality(
            textDirection: TextDirection.rtl,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xffd4dbe8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      autofocus: true,
                      onChanged: (v) => setS(() => q = v),
                      decoration: InputDecoration(
                        hintText:
                            'جستجوی سریع بخش‌ها (دبیرخانه، اندیکاتور، گروه گیرندگان، امضا…)',
                        prefixIcon: const Icon(Icons.search_rounded),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xfffafbfe),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xffdce3ee),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.55,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final entry = filtered[i];
                          final it = entry.item;
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: it.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(it.icon, color: it.color, size: 20),
                            ),
                            title: Text(
                              it.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              '${entry.group} • ${it.subtitle}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                            onTap: () {
                              Navigator.pop(ctx);
                              it.onTap();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<AuthController?>(context)?.session;
    final access = WebAccess(session, unrestrictedWhenNull: true);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!access.canSeeOfficeGroup && !access.canSeeMinutes) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: OfficeColors.bg,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_person_outlined,
                    size: 52,
                    color: Color(0xffb9c3d9),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'دسترسی به اتوماسیون اداری فعال نیست',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'نقش کاربری شما مجوز مشاهدهٔ کارتابل نامه‌ها، دبیرخانه یا ایمیل را ندارد.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xff66779c)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final tabs = _buildTabs(access);
    final activeIdx = tabs.indexWhere((t) => t.id == _activeTabId);
    final safeIdx = activeIdx >= 0 ? activeIdx : 0;
    final currentTab = tabs[safeIdx];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xff0d1526)
            : const Color(0xfff4f7fb),
        body: Column(
          children: [
            _buildExecutiveHeader(
              access: access,
              tabs: tabs,
              activeIndex: safeIdx,
              currentTab: currentTab,
            ),
            Expanded(
              child: IndexedStack(
                index: safeIdx,
                children: [for (final t in tabs) t.builder()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  //  هدر یکپارچهٔ اجرایی یاقوتی-نیلی با تب‌های زنده
  // ============================================================

  Widget _buildExecutiveHeader({
    required WebAccess access,
    required List<_WorkspaceTabSpec> tabs,
    required int activeIndex,
    required _WorkspaceTabSpec currentTab,
  }) {
    final canPop = Navigator.of(context).canPop();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xffffffff), Color(0xffe9effa)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
        border: Border(
          bottom: BorderSide(color: Color(0xff8a6a24), width: 1.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1a0f414b),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (canPop) ...[
                    _HeaderIconBtn(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'بازگشت',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          currentTab.accent,
                          OfficeColors.deep,
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: currentTab.accent.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(currentTab.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                currentTab.id == 'hub'
                                    ? 'اتوماسیون اداری توکا'
                                    : '${currentTab.label} • اتوماسیون توکا',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xff173a63),
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xfff3e8cf),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xffc9a24b),
                                  width: .8,
                                ),
                              ),
                              child: const Text(
                                'PRO',
                                style: TextStyle(
                                  color: Color(0xff8a6a24),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentTab.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xff5a6a8c),
                            fontSize: 10.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _HeaderIconBtn(
                    icon: Icons.manage_search_rounded,
                    tooltip: 'جستجوی سریع بخش‌ها',
                    onTap: () => _openQuickCommandSheet(access, tabs),
                  ),
                  if (currentTab.id == 'hub') ...[
                    const SizedBox(width: 6),
                    _HeaderIconBtn(
                      icon: _layoutMode == _OfficeLayoutMode.bento
                          ? Icons.folder_copy_outlined
                          : Icons.grid_view_rounded,
                      tooltip: _layoutMode == _OfficeLayoutMode.bento
                          ? 'نمای پوشه‌ای'
                          : 'نمای بنتو',
                      onTap: () => setState(() {
                        _layoutMode = _layoutMode == _OfficeLayoutMode.bento
                            ? _OfficeLayoutMode.folders
                            : _OfficeLayoutMode.bento;
                      }),
                    ),
                  ],
                  const SizedBox(width: 6),
                  _HeaderIconBtn(
                    icon: _pulseLoading
                        ? Icons.hourglass_top_rounded
                        : Icons.refresh_rounded,
                    tooltip: 'به‌روزرسانی آمار زنده',
                    onTap: _refreshPulse,
                  ),
                ],
              ),
              const SizedBox(height: 11),
              // نوار تب‌های زندهٔ محیط کاری
              SizedBox(
                height: 38,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < tabs.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Builder(
                          builder: (_) {
                            final t = tabs[i];
                            final selected = i == activeIndex;
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setState(() => _activeTabId = t.id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                height: 38,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                ),
                                decoration: BoxDecoration(
                                  gradient: selected
                                      ? const LinearGradient(
                                          colors: [Color(0xff2547a8), Color(0xff173a63)],
                                          begin: Alignment.topRight,
                                          end: Alignment.bottomLeft,
                                        )
                                      : null,
                                  color: selected ? null : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0xff173a63)
                                        : const Color(0xffdce3ee),
                                  ),
                                  boxShadow: selected
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x33155e6b),
                                            blurRadius: 10,
                                            offset: Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      t.icon,
                                      size: 16,
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xff2547a8),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      t.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: selected
                                            ? Colors.white
                                            : const Color(0xff1e2a45),
                                      ),
                                    ),
                                    if (t.badge > 0) ...[
                                      const SizedBox(width: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? const Color(0xffc9a24b)
                                              : const Color(0xffb5332f),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          Fa.digits(t.badge),
                                          style: TextStyle(
                                            color: selected
                                                ? const Color(0xff3a2c08)
                                                : Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  //  بدنهٔ تب ۰: میز فرماندهی اجرایی اتوماسیون اداری
  // ============================================================

  Widget _buildHubBody(WebAccess access) {
    final tabs = _buildTabs(access);
    final groups = _buildHubGroups(access, tabs);
    final totalUnread = _innerUnread + _outgoingUnread + _incomingUnread;

    return RefreshIndicator(
      onRefresh: _refreshPulse,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: [
          // ۱) کارت‌های نبض زنده کارتابل و دبیرخانه
          _buildPulseStrip(
            access: access,
            tabs: tabs,
            totalUnread: totalUnread,
          ),
          const SizedBox(height: 14),

          // ۲) داک اقدام فوری (فقط در صورت داشتن مجوز ثبت/عملیات)
          if (_hasAnyQuickAction(access)) ...[
            _buildQuickActionsDock(access),
            const SizedBox(height: 16),
          ],

          // ۳) گروه‌های ماژول اتوماسیون (نمای بنتو یا پوشه‌ای)
          if (_layoutMode == _OfficeLayoutMode.bento)
            for (final g in groups) ...[
              _buildBentoGroup(g),
              const SizedBox(height: 16),
            ]
          else
            for (final g in groups) ...[
              _buildFolderGroup(g),
              const SizedBox(height: 10),
            ],

          // ۴) فید سریع نامه‌های خوانده‌نشده در انتظار اقدام
          if (_urgentFeed.isNotEmpty) _buildUnreadFeedCard(),
        ],
      ),
    );
  }

  Widget _buildPulseStrip({
    required WebAccess access,
    required List<_WorkspaceTabSpec> tabs,
    required int totalUnread,
  }) {
    final cards = <({
      String title,
      int count,
      String unit,
      IconData icon,
      Color color,
      VoidCallback? onTap,
    })>[
      if (access.canSeeInnerLetters ||
          access.canSeeOutgoingLetters ||
          access.canSeeIncomingLetters)
        (
          title: 'خوانده‌نشده کارتابل',
          count: totalUnread,
          unit: 'نامه منتظر بررسی',
          icon: Icons.mark_email_unread_rounded,
          color: const Color(0xff3357b0),
          onTap: () {
            if (access.canSeeInnerLetters) {
              _switchTab('inner', tabs);
            } else if (access.canSeeOutgoingLetters) {
              _switchTab('outgoing', tabs);
            } else if (access.canSeeIncomingLetters) {
              _switchTab('incoming', tabs);
            }
          },
        ),
      if (access.canSeeOutgoingLetters)
        (
          title: 'در نوبت امضای من',
          count: _signingPending,
          unit: 'نامه آماده امضا',
          icon: Icons.draw_rounded,
          color: const Color(0xffb4771e),
          onTap: () => _pushPage(
            const LetterMailboxPage(
              kind: LetterKind.outgoing,
              initialBox: LetterBox.signing,
            ),
          ),
        ),
      if (access.canSeeDabirkhane)
        (
          title: 'صف ثبت دبیرخانه',
          count: _dabirkhanePending,
          unit: 'مرسوله منتظر ثبت',
          icon: Icons.markunread_mailbox_rounded,
          color: const Color(0xff3357b0),
          onTap: () => _switchTab('dabirkhane', tabs),
        ),
      if (access.canSeeEmail)
        (
          title: 'ایمیل خوانده‌نشده',
          count: _emailUnread,
          unit: 'پیام در صندوق رسمی',
          icon: Icons.alternate_email_rounded,
          color: const Color(0xff1466a6),
          onTap: () => _switchTab('email', tabs),
        ),
    ];

    if (cards.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, c) {
        final cols = cards.length == 1 ? 1 : 2;
        final w = (c.maxWidth - (cols - 1) * 10) / cols;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final kpi in cards)
              SizedBox(
                width: w,
                child: _PulseKpiCard(
                  title: kpi.title,
                  count: kpi.count,
                  unit: kpi.unit,
                  icon: kpi.icon,
                  color: kpi.color,
                  onTap: kpi.onTap,
                ),
              ),
          ],
        );
      },
    );
  }

  bool _hasAnyQuickAction(WebAccess access) =>
      access.canCreateInnerLetter ||
      access.canCreateOutgoingLetter ||
      access.canCreateIncomingLetter ||
      access.canSeeDabirkhane ||
      access.canCreateEmail;

  Widget _buildQuickActionsDock(WebAccess access) {
    final actions = <({
      String label,
      IconData icon,
      Color color,
      VoidCallback onTap,
    })>[
      if (access.canCreateInnerLetter)
        (
          label: 'ثبت نامه داخلی',
          icon: Icons.edit_document,
          color: OfficeColors.inner,
          onTap: () => _pushPage(const LetterEditorPage(kind: LetterKind.inner)),
        ),
      if (access.canCreateOutgoingLetter)
        (
          label: 'نگارش صادره',
          icon: Icons.outbox_rounded,
          color: OfficeColors.outgoing,
          onTap: () =>
              _pushPage(const LetterEditorPage(kind: LetterKind.outgoing)),
        ),
      if (access.canCreateIncomingLetter)
        (
          label: 'ثبت نامه وارده',
          icon: Icons.move_to_inbox_rounded,
          color: OfficeColors.incoming,
          onTap: () =>
              _pushPage(const LetterEditorPage(kind: LetterKind.incoming)),
        ),
      if (access.canSeeDabirkhane)
        (
          label: 'میز دبیرخانه',
          icon: Icons.markunread_mailbox_rounded,
          color: const Color(0xff20304f),
          onTap: () => _pushPage(
            OfficeDabirkhanePage(
              initialMode: access.canSeeOutgoingDabirkhane
                  ? DabirkhaneMode.sadere
                  : DabirkhaneMode.varede,
            ),
          ),
        ),
      if (access.canCreateEmail)
        (
          label: 'صندوق ایمیل',
          icon: Icons.send_rounded,
          color: OfficeColors.email,
          onTap: () => _pushPage(const EmailPage()),
        ),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff141d33) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xff26314e) : const Color(0xffdce3ee),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt_rounded, size: 17, color: Color(0xff3357b0)),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  'اقدام فوری مکاتبات و دبیرخانه',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: actions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final a = actions[i];
                return Material(
                  color: a.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: a.onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: a.color.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(a.icon, size: 16, color: a.color),
                          const SizedBox(width: 6),
                          Text(
                            a.label,
                            style: TextStyle(
                              fontSize: 11.8,
                              fontWeight: FontWeight.w900,
                              color: a.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoGroup(_HubGroupSpec group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: group.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(group.icon, size: 16, color: group.accent),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    group.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.8,
                      color: Color(0xff66779c),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) {
            final twoColWidth = (c.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final it in group.items)
                  SizedBox(
                    width: group.items.length == 1 ? c.maxWidth : twoColWidth,
                    child: _BentoModuleTile(item: it),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildFolderGroup(_HubGroupSpec group) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final open = _expandedGroups.contains(group.id);

    return Material(
      color: isDark ? const Color(0xff141d33) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? const Color(0xff26314e) : const Color(0xffdce3ee),
          ),
        ),
        child: Column(
          children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() {
              if (!_expandedGroups.remove(group.id)) {
                _expandedGroups.add(group.id);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: group.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(group.icon, color: group.accent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.title,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${Fa.digits(group.items.length)} زیربخش • ${group.subtitle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.8,
                            color: Color(0xff66779c),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                children: [
                  for (final it in group.items)
                    ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: it.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(it.icon, color: it.color, size: 18),
                      ),
                      title: Text(
                        it.title,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        it.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.8),
                      ),
                      trailing: it.badge != null
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: it.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                it.badge!,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: it.color,
                                ),
                              ),
                            )
                          : const Icon(Icons.chevron_right_rounded, size: 18),
                      onTap: it.onTap,
                    ),
                ],
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildUnreadFeedCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff141d33) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xff26314e) : const Color(0xffdce3ee),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                size: 18,
                color: Color(0xff3357b0),
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'نامه‌های خوانده‌نشده منتظر بررسی شما',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final entry in _urgentFeed)
            LetterTile(
              item: entry.item,
              kind: entry.kind,
              onTap: () => _pushPage(
                LetterDetailPage(
                  kind: entry.kind,
                  letterId: entry.item.letterId,
                  erjaId: entry.item.erjaId,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
//  ویجت‌های اختصاصی میز فرماندهی اتوماسیون
// ============================================================

class _HeaderIconBtn extends StatelessWidget {
  const _HeaderIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0xffdce3ee)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140f414b),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xff2547a8), size: 18),
        ),
      ),
    );
  }
}

class _PulseKpiCard extends StatelessWidget {
  const _PulseKpiCard({
    required this.title,
    required this.count,
    required this.unit,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final int count;
  final String unit;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xff141d33) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: count > 0
                  ? color.withValues(alpha: 0.35)
                  : (isDark
                        ? const Color(0xff26314e)
                        : const Color(0xffdce3ee)),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.14 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Fa.digits(count),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: count > 0
                            ? color
                            : (isDark ? Colors.white : const Color(0xff1e2a45)),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      unit,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.8,
                        color: Color(0xff66779c),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BentoModuleTile extends StatelessWidget {
  const _BentoModuleTile({required this.item});

  final _HubItemSpec item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xff141d33) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: item.onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: item.featured
                ? LinearGradient(
                    colors: [
                      item.color.withValues(alpha: isDark ? 0.22 : 0.08),
                      isDark ? const Color(0xff141d33) : Colors.white,
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  )
                : null,
            border: Border.all(
              color: item.featured
                  ? item.color.withValues(alpha: 0.30)
                  : (isDark
                        ? const Color(0xff26314e)
                        : const Color(0xffdce3ee)),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xff1e2a45,
                ).withValues(alpha: isDark ? 0.16 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, color: item.color, size: 20),
                  ),
                  const SizedBox(width: 6),
                  if (item.badge != null)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: item.color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.badge!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 16,
                      color: item.color.withValues(alpha: 0.7),
                    ),
                ],
              ),
              const SizedBox(height: 11),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.6,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.6,
                  height: 1.45,
                  color: isDark
                      ? const Color(0xffb9c3d9)
                      : const Color(0xff66779c),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
