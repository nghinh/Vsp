// Hole List Section — VSP Mobile App
//
// Compact hole list: number, par, length.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../../domain/models/course_detail.dart';
import '../../../../domain/models/hole_summary.dart';
import 'package:vsp_mobile/presentation/widgets/distance/not_surveyed_chip.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';

class HoleListSection extends StatelessWidget {
  final CourseDetail course;

  const HoleListSection({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    if (course.holes.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Sort holes by number
    final sortedHoles = List.of(course.holes)
      ..sort((a, b) => a.holeNumber.compareTo(b.holeNumber));

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
                Icons.list,
                size: VspIconSize.md,
                color: colorScheme.primary,
              ),
              const SizedBox(width: VspSpacing.sm),
              Text(
                AppLocalizations.of(context).sectionHoles,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Table header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: VspSpacing.sm),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    AppLocalizations.of(context).fieldHole,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).fieldPar,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  AppLocalizations.of(context).fieldLength,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: VspSpacing.xs),
          const Divider(height: 1),
          const SizedBox(height: VspSpacing.xs),

          // Says once, in a sentence, what the amber markers on the rows below
          // mean. Every length in this table is measured between the hole's
          // tee and green coordinates, and most of those coordinates in this
          // database were generated rather than surveyed.
          if (sortedHoles.any((h) => !h.isSurveyed)) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: VspSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const NotSurveyedChip(),
                  const SizedBox(width: VspSpacing.sm),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).holeListUnverifiedNotice(
                        sortedHoles.where((h) => !h.isSurveyed).length,
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Front 9
          if (sortedHoles.any((h) => h.holeNumber <= 9)) ...[
            _HoleGroup(
              label: AppLocalizations.of(context).roundSetupFront9,
              holes: sortedHoles.where((h) => h.holeNumber <= 9).toList(),
            ),
            const SizedBox(height: VspSpacing.sm),
          ],

          // Back 9
          if (sortedHoles.any((h) => h.holeNumber >= 10)) ...[
            _HoleGroup(
              label: AppLocalizations.of(context).roundSetupBack9,
              holes: sortedHoles.where((h) => h.holeNumber >= 10).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _HoleGroup extends StatelessWidget {
  final String label;
  final List<HoleSummary> holes;

  const _HoleGroup({required this.label, required this.holes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: VspSpacing.xs),
        ...holes.map(
          (hole) => Padding(
            padding: const EdgeInsets.symmetric(vertical: VspSpacing.xs),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    '${hole.holeNumber}',
                    style: const TextStyle(
                      fontFamily: 'Fira Code',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${hole.par}',
                    style: const TextStyle(
                      fontFamily: 'Fira Code',
                      fontSize: 14,
                    ),
                  ),
                ),
                // The marker rides with the number, not just with the table:
                // a golfer reading one row must not have to have read the
                // notice above to know what they are looking at.
                if (!hole.isSurveyed &&
                    hole.formattedLength(context.distanceUnit) != null) ...[
                  const NotSurveyedChip(iconOnly: true),
                  const SizedBox(width: 4),
                ],
                Text(
                  hole.formattedLength(context.distanceUnit) ?? '—',
                  style: const TextStyle(fontFamily: 'Fira Code', fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
