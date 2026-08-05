// Data Quality Section — VSP Mobile App
//
// Data quality badge + freshness + last updated.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../../domain/models/course_detail.dart';
import 'data_quality_badge.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class DataQualitySection extends StatelessWidget {
  final CourseDetail course;

  const DataQualitySection({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dataQuality = course.dataQuality;

    return Container(
      margin: const EdgeInsets.all(VspSpacing.md),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_user,
                size: VspIconSize.md,
                color: colorScheme.primary,
              ),
              const SizedBox(width: VspSpacing.sm),
              Text(
                AppLocalizations.of(context).sectionDataQuality,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Badge
          DataQualityBadge(dataQuality: dataQuality),

          if (dataQuality != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Details
            _DetailRow(
              label: AppLocalizations.of(context).fieldVersion,
              value: 'v${dataQuality.versionNumber}',
            ),
            const SizedBox(height: VspSpacing.sm),
            _DetailRow(
              label: AppLocalizations.of(context).fieldLastUpdated,
              value: _formatDate(dataQuality.publishedAt),
            ),
            if (dataQuality.publisher != null) ...[
              const SizedBox(height: VspSpacing.sm),
              _DetailRow(label: AppLocalizations.of(context).fieldPublisher, value: dataQuality.publisher!),
            ],
            if (dataQuality.isStale) ...[
              const SizedBox(height: VspSpacing.sm),
              Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    size: VspIconSize.sm,
                    color: VspColorSemantic.of(
                      colorScheme.brightness,
                      VspSemanticColorToken.stale,
                    ),
                  ),
                  const SizedBox(width: VspSpacing.xs),
                  Text(
                    AppLocalizations.of(context).dataOlderThan30Days,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: VspColorSemantic.of(
                        colorScheme.brightness,
                        VspSemanticColorToken.stale,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    if (diff < 30) return '${(diff / 7).floor()} weeks ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Text(
          '$label:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: VspSpacing.sm),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

