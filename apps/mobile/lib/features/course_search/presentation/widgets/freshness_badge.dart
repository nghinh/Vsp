// Freshness Badge — VSP Mobile App
//
// Badge showing data freshness — days since published or stale indicator.
//
// Design: ux-spec §4.2 + DESIGN.md §Components
// - Fresh (≤30 days): green tint, "Updated X days ago"
// - Stale (>30 days): red text, strikethrough, "Stale"

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../../domain/models/data_freshness.dart';

/// Freshness badge — shows days since data was published or stale indicator.
class FreshnessBadge extends StatelessWidget {
  final DataFreshness? dataFreshness;
  final bool compact;

  const FreshnessBadge({
    super.key,
    required this.dataFreshness,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.colorScheme.brightness;

    if (dataFreshness == null) {
      return _buildUnknown(context, brightness, theme);
    }

    if (dataFreshness!.isStale) {
      return _buildStale(context, brightness, theme);
    }

    return _buildFresh(context, brightness, theme);
  }

  Widget _buildUnknown(
    BuildContext context,
    Brightness brightness,
    ThemeData theme,
  ) {
    return Semantics(
      label: 'Data freshness unknown',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : VspSpacing.sm,
          vertical: compact ? VspSpacing.half : VspSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: brightness == Brightness.dark
                ? VspColorDark.textTertiary
                : VspColorLight.textTertiary,
            width: 1,
          ),
        ),
        child: Text(
          'Unknown',
          style: TextStyle(
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w500,
            color: brightness == Brightness.dark
                ? VspColorDark.textTertiary
                : VspColorLight.textTertiary,
          ),
        ),
      ),
    );
  }

  Widget _buildFresh(
    BuildContext context,
    Brightness brightness,
    ThemeData theme,
  ) {
    final days = dataFreshness!.daysSincePublished;
    final label = days == 0
        ? 'Today'
        : days == 1
        ? '1 day ago'
        : '$days days ago';

    return Semantics(
      label: 'Data updated $label',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : VspSpacing.sm,
          vertical: compact ? VspSpacing.half : VspSpacing.xs,
        ),
        decoration: BoxDecoration(
          // Tinted background (not solid accent) so the accent-colored label
          // and icon stay legible in both light and dark modes.
          color: brightness == Brightness.dark
              ? VspColorDark.accent.withOpacity(0.16)
              : VspColorLight.accent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.update,
              size: compact ? 10 : 12,
              color: VspColorSemantic.of(
                brightness,
                VspSemanticColorToken.official,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w500,
                color: VspColorSemantic.of(
                  brightness,
                  VspSemanticColorToken.official,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStale(
    BuildContext context,
    Brightness brightness,
    ThemeData theme,
  ) {
    return Semantics(
      label: 'Data is stale',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : VspSpacing.sm,
          vertical: compact ? VspSpacing.half : VspSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: brightness == Brightness.dark
              ? VspColorDark.destructive
              : VspColorLight.destructive.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber,
              size: compact ? 10 : 12,
              color: VspColorSemantic.of(
                brightness,
                VspSemanticColorToken.stale,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Stale',
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: VspColorSemantic.of(
                  brightness,
                  VspSemanticColorToken.stale,
                ),
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
