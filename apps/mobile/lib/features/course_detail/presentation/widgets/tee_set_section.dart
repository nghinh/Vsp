// Tee Set Section — VSP Mobile App
//
// Tee set comparison cards with yardages per hole.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../../domain/models/course_detail.dart';
import '../../../../domain/models/tee_set_summary.dart';

class TeeSetSection extends StatelessWidget {
  final CourseDetail course;

  const TeeSetSection({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    if (course.teeSets.isEmpty) {
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
                Icons.flag,
                size: VspIconSize.md,
                color: colorScheme.primary,
              ),
              const SizedBox(width: VspSpacing.sm),
              Text(
                'Tee Sets',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...course.teeSets.map((teeSet) => _TeeSetCard(teeSet: teeSet)),
        ],
      ),
    );
  }
}

class _TeeSetCard extends StatelessWidget {
  final TeeSetSummary teeSet;

  const _TeeSetCard({required this.teeSet});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: VspSpacing.sm),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tee set name + gender
          Row(
            children: [
              Expanded(
                child: Text(
                  teeSet.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (teeSet.genderLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: VspSpacing.half,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    teeSet.genderLabel!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: VspSpacing.sm),

          // Par + yardages summary
          Row(
            children: [
              _MetricChip(label: 'Par', value: '${teeSet.totalPar}'),
              if (teeSet.rating != null) ...[
                const SizedBox(width: VspSpacing.sm),
                _MetricChip(
                  label: 'Rating',
                  value: teeSet.rating!.toStringAsFixed(1),
                ),
              ],
              if (teeSet.slope != null) ...[
                const SizedBox(width: VspSpacing.sm),
                _MetricChip(label: 'Slope', value: '${teeSet.slope}'),
              ],
            ],
          ),

          if (teeSet.yardages.isNotEmpty) ...[
            const SizedBox(height: VspSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: VspSpacing.sm),

            // Yardages per tee box
            Wrap(
              spacing: 12,
              runSpacing: VspSpacing.xs,
              children: teeSet.yardages.entries.map((entry) {
                return _YardageChip(teeName: entry.key, yardage: entry.value);
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Fira Code',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _YardageChip extends StatelessWidget {
  final String teeName;
  final int yardage;

  const _YardageChip({required this.teeName, required this.yardage});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          teeName,
          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 4),
        Text(
          '${yardage}yd',
          style: const TextStyle(
            fontFamily: 'Fira Code',
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
