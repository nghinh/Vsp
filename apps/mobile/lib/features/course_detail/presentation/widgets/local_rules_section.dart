// Local Rules Section — VSP Mobile App
//
// Bulleted rules list.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../../domain/models/course_detail.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class LocalRulesSection extends StatelessWidget {
  final CourseDetail course;

  const LocalRulesSection({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    if (!course.hasLocalRules) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VspSpacing.md,
        vertical: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.rule,
                size: VspIconSize.md,
                color: colorScheme.primary,
              ),
              const SizedBox(width: VspSpacing.sm),
              Text(
                AppLocalizations.of(context).sectionLocalRules,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...course.localRules.map(
            (rule) => Padding(
              padding: const EdgeInsets.only(bottom: VspSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: VspSpacing.sm),
                  Expanded(
                    child: Text(rule, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
