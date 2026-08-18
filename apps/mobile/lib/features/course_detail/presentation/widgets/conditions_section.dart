// Conditions Section — VSP Mobile App
//
// Active conditions list with full AC1 display:
// - Official status badge
// - Source indicator
// - Effective/expiry dates
// - Confidence percentage
// - Stale warning
//
// Story 7.3 — Slice 3: ConditionsSection UI Extension

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../../domain/models/course_detail.dart';
import '../../../../domain/models/condition_entry.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Configuration for offline/cached state.
class ConditionsSectionConfig {
  /// Whether the device is currently offline.
  final bool isOffline;

  /// When the data was last cached (null if live).
  final DateTime? cachedAt;

  const ConditionsSectionConfig({this.isOffline = false, this.cachedAt});

  /// True if showing cached/stale data.
  bool get isCached => cachedAt != null;
}

class ConditionsSection extends StatelessWidget {
  final CourseDetail course;
  final ConditionsSectionConfig? config;

  const ConditionsSection({super.key, required this.course, this.config});

  @override
  Widget build(BuildContext context) {
    if (!course.hasConditions) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOffline = config?.isOffline ?? false;

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
                Icons.warning_amber,
                size: VspIconSize.md,
                color: colorScheme.primary,
              ),
              const SizedBox(width: VspSpacing.sm),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).sectionConditions,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              if (isOffline) ...[
                const SizedBox(width: VspSpacing.sm),
                _OfflineBadge(cachedAt: config?.cachedAt),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ...course.conditions.map(
            (condition) => _ConditionTile(condition: condition),
          ),
        ],
      ),
    );
  }
}

/// Badge shown when device is offline with cached timestamp.
class _OfflineBadge extends StatelessWidget {
  final DateTime? cachedAt;

  const _OfflineBadge({this.cachedAt});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: cachedAt != null
          ? AppLocalizations.of(context).conditionsOfflineCached(_formatDateTime(cachedAt!))
          : AppLocalizations.of(context).commonOffline,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 14,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: 4),
            Text(
              cachedAt != null ? AppLocalizations.of(context).commonCached : AppLocalizations.of(context).commonOffline,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _ConditionTile extends StatelessWidget {
  final ConditionEntry condition;

  const _ConditionTile({required this.condition});

  Color _sourceColor(BuildContext context) {
    final brightness = Theme.of(context).colorScheme.brightness;
    if (condition.isOfficial) {
      return VspColorSemantic.of(brightness, VspSemanticColorToken.online);
    }
    return VspColorSemantic.of(brightness, VspSemanticColorToken.estimated);
  }

  Color _severityColor(BuildContext context) {
    final brightness = Theme.of(context).colorScheme.brightness;
    switch (condition.severity) {
      case ConditionSeverity.info:
        return VspColorSemantic.of(brightness, VspSemanticColorToken.online);
      case ConditionSeverity.minor:
        return VspColorSemantic.of(brightness, VspSemanticColorToken.online);
      case ConditionSeverity.moderate:
        return VspColorSemantic.of(brightness, VspSemanticColorToken.estimated);
      case ConditionSeverity.major:
        return VspColorSemantic.of(brightness, VspSemanticColorToken.stale);
    }
  }

  IconData _conditionIcon() {
    switch (condition.conditionType) {
      case ConditionType.pinPosition:
        return Icons.push_pin;
      case ConditionType.greenSpeed:
        return Icons.speed;
      case ConditionType.courseCondition:
        return Icons.grass;
      case ConditionType.bunkerCondition:
        return Icons.landscape;
      case ConditionType.cartPath:
        return Icons.directions_car;
      case ConditionType.localRule:
        return Icons.rule;
      case ConditionType.alert:
        return Icons.campaign;
    }
  }

  /// Check if the condition is stale: expired or >30 days old.
  bool get _isStale {
    if (condition.isExpired) return true;
    if (condition.effectiveDate != null) {
      return DateTime.now().difference(condition.effectiveDate!).inDays > 30;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final severityColor = _severityColor(context);
    final sourceColor = _sourceColor(context);
    final isStale = _isStale;

    return Semantics(
      label: _buildSemanticLabel(context),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: VspSpacing.sm),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: severityColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isStale
                ? Theme.of(context).colorScheme.error.withOpacity(0.4)
                : severityColor.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: type label + badges
            Row(
              children: [
                Expanded(
                  child: Text(
                    condition.conditionType.displayLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Official/Estimated badge
                _SourceBadge(source: condition.source, color: sourceColor),
                const SizedBox(width: 6),
                // Severity badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: VspSpacing.half,
                  ),
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    condition.severity.displayLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: severityColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: VspSpacing.xs),

            // Description if present
            if (condition.description != null) ...[
              Text(
                condition.description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: VspSpacing.xs),
            ],

            // Metadata row: effective/expiry, confidence, stale warning
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Effective/Expiry date
                if (condition.effectiveDate != null)
                  _MetadataChip(
                    icon: Icons.schedule,
                    label:
                        AppLocalizations.of(context).conditionsEffective(_formatDate(condition.effectiveDate!)),
                  ),
                if (condition.expiryDate != null)
                  _MetadataChip(
                    icon: condition.isExpired
                        ? Icons.error_outline
                        : Icons.event,
                    label: condition.isExpired
                        ? AppLocalizations.of(context).conditionsExpired(_formatDate(condition.expiryDate!))
                        : AppLocalizations.of(context).conditionsExpires(_formatDate(condition.expiryDate!)),
                    isWarning: condition.isExpired,
                  ),

                // Confidence percentage
                if (condition.confidence != null)
                  _MetadataChip(
                    icon: Icons.verified,
                    label:
                        '${(condition.confidence! * 100).toStringAsFixed(0)}% confidence',
                  ),

                // Accuracy class
                _MetadataChip(
                  icon: Icons.grade,
                  label: AppLocalizations.of(context).conditionsAccuracyClass('${condition.accuracyClass}'),
                ),

                // Stale warning
                if (isStale)
                  _MetadataChip(
                    icon: Icons.warning,
                    label: AppLocalizations.of(context).conditionsStaleData,
                    isWarning: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _buildSemanticLabel(BuildContext context) {
    final parts = <String>[
      condition.conditionType.displayLabel,
      condition.severity.displayLabel,
    ];
    if (condition.isOfficial) {
      parts.add('official source');
    } else if (condition.source != null) {
      parts.add('${condition.source!.displayLabel} source');
    }
    if (condition.confidence != null) {
      parts.add(
        '${(condition.confidence! * 100).toStringAsFixed(0)} percent confidence',
      );
    }
    if (condition.isExpired) {
      parts.add('expired');
    } else if (_isStale) {
      parts.add('stale');
    }
    return parts.join(', ');
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Badge showing the source (Official/Estimated/Manual).
class _SourceBadge extends StatelessWidget {
  final ConditionSource? source;
  final Color color;

  const _SourceBadge({required this.source, required this.color});

  @override
  Widget build(BuildContext context) {
    if (source == null) return const SizedBox.shrink();

    return Semantics(
      label: '${source!.displayLabel} source',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          source!.displayLabel,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Small metadata chip with icon and label.
class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isWarning;

  const _MetadataChip({
    required this.icon,
    required this.label,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isWarning
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}

// Re-export semantic token
enum _SemanticToken { online, estimated, stale }
