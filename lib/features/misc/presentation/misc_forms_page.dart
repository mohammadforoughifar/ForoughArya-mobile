// ============================================================
//  ماژول «فرم‌های متفرقه»
//  شامل زیرمجموعهٔ فعال «صورتجلسه» + فرم‌های آینده با نشان «به‌زودی»
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/fa.dart';
import '../data/minutes_repository.dart';
import 'minutes_list_page.dart';
import 'misc_style.dart';

class MiscFormsPage extends StatefulWidget {
  const MiscFormsPage({super.key});

  @override
  State<MiscFormsPage> createState() => _MiscFormsPageState();
}

class _MiscFormsPageState extends State<MiscFormsPage> {
  late final MinutesRepository _repo =
      Provider.of<MinutesRepository?>(context, listen: false) ??
      MinutesRepository(context.read<ApiClient>());

  int? _minutesCount;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    try {
      final res = await _repo.fetchList(take: 1);
      if (!mounted) return;
      setState(() => _minutesCount = res.total);
    } catch (_) {}
  }

  Future<void> _openMinutes() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const MinutesListPage()),
    );
    if (mounted) _loadCount();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: MiscColors.bg,
        body: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: MiscColors.heroGradient,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(26),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.14),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'فرم‌های متفرقه',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'صورتجلسات، مصوبات جلسات و فرم‌های داخلی سازمان',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // --- کارت برجستهٔ «صورتجلسه» ---
                  Material(
                    color: MiscColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: _openMinutes,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: MiscColors.teal.withValues(alpha: 0.35),
                            width: 1.3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: MiscColors.teal.withValues(alpha: 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: MiscColors.heroGradient,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: const Icon(
                                    Icons.description_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'صورتجلسه',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: MiscColors.ink,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (_minutesCount != null)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: MiscColors.teal
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(100),
                                              ),
                                              child: Text(
                                                '${Fa.digits(_minutesCount)} مورد',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: MiscColors.teal,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'ثبت جلسات، امضای دیجیتال حاضرین، پیگیری مصوبات و چاپ سربرگ',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: MiscColors.inkSoft,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: MiscColors.teal,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: const [
                                _FeaturePill('امضای الکترونیکی'),
                                _FeaturePill('پیگیری بندها'),
                                _FeaturePill('چاپ PDF با سربرگ'),
                                _FeaturePill('تبدیل به نامه و ایمیل'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'سایر زیرمجموعه‌های متفرقه',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: MiscColors.inkSoft,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.38,
                    children: const [
                      _UpcomingFormTile(
                        title: 'فرم تحویل و امانت',
                        subtitle: 'تحویل اموال و تجهیزات',
                        icon: Icons.assignment_return_outlined,
                      ),
                      _UpcomingFormTile(
                        title: 'درخواست ملزومات',
                        subtitle: 'اقلام مصرفی واحدها',
                        icon: Icons.inventory_outlined,
                      ),
                      _UpcomingFormTile(
                        title: 'فرم هماهنگی جلسات',
                        subtitle: 'رزرو اتاق و دعوت‌نامه',
                        icon: Icons.meeting_room_outlined,
                      ),
                      _UpcomingFormTile(
                        title: 'نظرسنجی داخلی',
                        subtitle: 'فرم‌های بازخورد سازمانی',
                        icon: Icons.poll_outlined,
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
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: MiscColors.bg,
      borderRadius: BorderRadius.circular(100),
      border: Border.all(color: MiscColors.line),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: MiscColors.inkSoft,
      ),
    ),
  );
}

class _UpcomingFormTile extends StatelessWidget {
  const _UpcomingFormTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: () {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('«$title» به‌زودی به اپلیکیشن اضافه می‌شود.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    },
    child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: MiscColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MiscColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: MiscColors.inkFaint.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: MiscColors.inkSoft),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: MiscColors.warn.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'به‌زودی',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: MiscColors.warn,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: MiscColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: MiscColors.inkFaint),
          ),
        ],
      ),
    ),
  );
}
