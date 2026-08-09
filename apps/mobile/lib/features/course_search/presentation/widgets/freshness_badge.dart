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
import 'package:vsp_mobile/l10n/app_localizations.dart';

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
      label: AppLocalizations.of(context).freshnessUnknownLabel,
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
          AppLocalizations.of(context).freshnessUnknown,
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
    final l10n = AppLocalizations.of(context);
    final days = dataFreshness!.daysSincePublished;
    // "3 days ago" on a card whose every other word is Vietnamese. The badge is
    // on the main course list, so it was the untranslated string a golfer saw
    // most often.
    final label = days == 0
        ? l10n.freshnessToday
        : days == 1
        ? l10n.relativeYesterday
        : l10n.relativeDaysAgo(days);

    return Semantics(
      label: AppLocalizations.of(context).freshnessUpdatedLabel(label),
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
      label: AppLocalizations.of(context).freshnessStaleLabel,
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
              AppLocalizations.of(context).freshnessStale,
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
