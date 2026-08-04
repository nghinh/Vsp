// Ratings Section — VSP Mobile App
//
// Rating + slope display.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../../domain/models/course_detail.dart';

class RatingsSection extends StatelessWidget {
  final CourseDetail course;

  const RatingsSection({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    if (!course.hasRatings) {
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
                Icons.star,
                size: VspIconSize.md,
                color: colorScheme.primary,
              ),
              const SizedBox(width: VspSpacing.sm),
              Text(
                'Ratings',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (course.rating != null)
                Expanded(
                  child: _RatingCard(
                    label: 'Course Rating',
                    value: course.rating!.toStringAsFixed(1),
                    icon: Icons.star,
                    color: VspColorSemantic.of(
                      colorScheme.brightness,
                      VspSemanticColorToken.official,
                    ),
                  ),
                ),
              if (course.rating != null && course.slope != null)
                const SizedBox(width: 12),
              if (course.slope != null)
                Expanded(
                  child: _RatingCard(
                    label: 'Slope',
                    value: '${course.slope}',
                    icon: Icons.trending_up,
                    color: VspColorSemantic.of(
                      colorScheme.brightness,
                      VspSemanticColorToken.estimated,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _RatingCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: VspIconSize.md, color: color),
          const SizedBox(height: VspSpacing.xs),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Fira Code',
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: VspSpacing.half),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

