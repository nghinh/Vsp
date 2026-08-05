// Course Hero Section — VSP Mobile App
//
// Hero section of course detail screen: name, holes, par, address, download CTA.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../../domain/models/course_detail.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class CourseHeroSection extends StatelessWidget {
  final CourseDetail course;
  final VoidCallback? onDownloadPressed;

  const CourseHeroSection({
    super.key,
    required this.course,
    this.onDownloadPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(VspSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course name
          Text(
            course.facilityName,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: VspSpacing.sm),

          // Holes + par row
          Row(
            children: [
              _InfoChip(
                icon: Icons.golf_course,
                label: '${course.holesCount} Holes',
              ),
              if (course.parTotal != null) ...[
                const SizedBox(width: VspSpacing.sm),
                _InfoChip(icon: Icons.flag, label: AppLocalizations.of(context).coursePar('${course.parTotal}')),
              ],
            ],
          ),

          if (course.address != null) ...[
            const SizedBox(height: VspSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: VspIconSize.sm,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: VspSpacing.xs),
                Expanded(
                  child: Text(
                    course.address!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: VspSpacing.md),

          // Download CTA
          if (onDownloadPressed != null)
            SizedBox(
              width: double.infinity,
              height: VspSpacingSemantic.touchTargetRecommended,
              child: FilledButton.icon(
                onPressed: onDownloadPressed,
                icon: const Icon(Icons.download),
                label: Text(AppLocalizations.of(context).courseDownloadCourse),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VspSpacing.sm,
        vertical: VspSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: VspIconSize.sm, color: colorScheme.primary),
          const SizedBox(width: VspSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
