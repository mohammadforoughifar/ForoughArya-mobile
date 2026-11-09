// ============================================================
//  شیت انتخاب شرکت فعال
//  داده از GET /api/company-context — شرکت‌های IsActive=false
//  نمایش داده می‌شوند ولی قابل انتخاب نیستند.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/utils/fa.dart';
import '../models/home_models.dart';
import 'home_style.dart';

class CompanyPickerSheet extends StatefulWidget {
  const CompanyPickerSheet({
    super.key,
    required this.context_,
    required this.activeId,
    required this.onPick,
  });

  final CompanyContext context_;
  final int? activeId;
  final ValueChanged<CompanyOption> onPick;

  @override
  State<CompanyPickerSheet> createState() => _CompanyPickerSheetState();
}

class _CompanyPickerSheetState extends State<CompanyPickerSheet> {
  late int? _sel = widget.activeId;

  @override
  Widget build(BuildContext context) {
    final companies = widget.context_.companies;
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        decoration: const BoxDecoration(
          color: HomeColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: HomeColors.line,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const Text(
              'انتخاب شرکت فعال',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: HomeColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'دادهٔ تمام ماژول‌ها بر اساس شرکت انتخابی نمایش داده می‌شود.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.9,
                color: HomeColors.inkSoft,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: companies.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'شرکتی برای شما تعریف نشده است.',
                          style: TextStyle(
                            color: HomeColors.inkFaint,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: companies.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 9),
                      itemBuilder: (context, i) => HFadeSlideIn(
                        index: i,
                        delayMs: 40,
                        durationMs: 300,
                        offsetY: 14,
                        child: _CompanyRow(
                          company: companies[i],
                          selected: companies[i].id == _sel,
                          onTap: companies[i].isActive
                              ? () {
                                  setState(() => _sel = companies[i].id);
                                  widget.onPick(companies[i]);
                                  Navigator.of(context).pop();
                                }
                              : null,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyRow extends StatelessWidget {
  const _CompanyRow({
    required this.company,
    required this.selected,
    this.onTap,
  });

  final CompanyOption company;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = company.isActive;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: HPressable(
        onTap: onTap,
        scale: 0.98,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? HomeColors.seed.withValues(alpha: 0.07)
                : HomeColors.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? HomeColors.seed : HomeColors.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: LinearGradient(
                    colors: selected
                        ? const [HomeColors.seed, HomeColors.accent]
                        : [
                            HomeColors.seed.withValues(alpha: 0.14),
                            HomeColors.accent.withValues(alpha: 0.14),
                          ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: Text(
                  company.initials,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : HomeColors.seed,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: HomeColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (company.code != null && company.code!.isNotEmpty)
                          'کد ${Fa.digits(company.code)}',
                        if (company.phone != null && company.phone!.isNotEmpty)
                          Fa.digits(company.phone!),
                      ].join('  ·  '),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: HomeColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusTag(enabled: enabled, selected: selected),
              const SizedBox(width: 9),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 21,
                height: 21,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? HomeColors.seed : HomeColors.line,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: HomeColors.seed,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.enabled, required this.selected});

  final bool enabled;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch ((enabled, selected)) {
      (false, _) => ('غیرفعال', HomeColors.inkFaint, HomeColors.bg),
      (true, true) => ('فعال', HomeColors.seed, HomeColors.seed.withValues(alpha: 0.12)),
      (true, false) => ('مجاز', HomeColors.ok, HomeColors.ok.withValues(alpha: 0.12)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}
