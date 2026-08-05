// Facilities Section — VSP Mobile App
//
// Chip list of facility types (clubhouse, restaurant, etc.).

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../../domain/models/course_detail.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class FacilitiesSection extends StatelessWidget {
  final CourseDetail course;

  const FacilitiesSection({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    if (!course.hasFacilities) {
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
                Icons.business,
                size: VspIconSize.md,
                color: colorScheme.primary,
              ),
              const SizedBox(width: VspSpacing.sm),
              Text(
                AppLocalizations.of(context).sectionFacilities,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: VspSpacing.sm,
            runSpacing: VspSpacing.sm,
            children: course.facilities.map((facility) {
              return _FacilityChip(label: facility);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _FacilityChip extends StatelessWidget {
  final String label;

  const _FacilityChip({required this.label});

  IconData _iconFor(String facility) {
    final lower = facility.toLowerCase();
    if (lower.contains('restaurant')) return Icons.restaurant;
    if (lower.contains('clubhouse')) return Icons.home;
    if (lower.contains('pro shop')) return Icons.shopping_bag;
    if (lower.contains('practice')) return Icons.golf_course;
    if (lower.contains('gym')) return Icons.fitness_center;
    if (lower.contains('spa')) return Icons.spa;
    if (lower.contains('pool')) return Icons.pool;
    if (lower.contains('tennis')) return Icons.sports_tennis;
    if (lower.contains('parking')) return Icons.local_parking;
    if (lower.contains('bathroom')) return Icons.wc;
    if (lower.contains('caddie')) return Icons.person;
    return Icons.check_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VspSpacing.sm,
        vertical: VspSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _iconFor(label),
            size: VspIconSize.sm,
            color: colorScheme.primary,
          ),
          const SizedBox(width: VspSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
