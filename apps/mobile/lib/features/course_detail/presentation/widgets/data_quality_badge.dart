// Data Quality Badge — VSP Mobile App
//
// Unified badge combining verification status + accuracy class + staleness.
//
// AC-3: Official, estimated, stale, and community data distinguishable by text/icon + color.
// Design: ux-spec §4.2 + DESIGN.md §Components
//
// Badge variants:
// - Official (Class A/B + VERIFIED): solid green badge "Official"
// - Estimated (Class C): amber badge "Estimated"
// - Community (Class D): dark grey badge "Community"
// - Stale (>30d): red pill "Stale" with strikethrough on timestamp

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../../../domain/models/data_quality.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Data quality badge — unified indicator for AC-3.
class DataQualityBadge extends StatelessWidget {
  final DataQuality? dataQuality;
  final bool compact;

  const DataQualityBadge({
    super.key,
    required this.dataQuality,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (dataQuality == null) {
      return _buildUnknown(context);
    }

    switch (dataQuality!.variant) {
      case DataQualityVariant.official:
        return _buildOfficial(context);
      case DataQualityVariant.estimated:
        return _buildEstimated(context);
      case DataQualityVariant.community:
        return _buildCommunity(context);
      case DataQualityVariant.stale:
        return _buildStale(context);
    }
  }

  Widget _buildUnknown(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context).dataQualityUnknown,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : VspSpacing.sm,
          vertical: compact ? VspSpacing.half : VspSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: VspColorSemantic.of(
              Theme.of(context).colorScheme.brightness,
              VspSemanticColorToken.courseNotDownloaded,
            ),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.help_outline,
              size: compact ? 12 : 14,
              color: VspColorSemantic.of(
                Theme.of(context).colorScheme.brightness,
                VspSemanticColorToken.courseNotDownloaded,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context).freshnessUnknown,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: VspColorSemantic.of(
                  Theme.of(context).colorScheme.brightness,
                  VspSemanticColorToken.courseNotDownloaded,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficial(BuildContext context) {
    final brightness = Theme.of(context).colorScheme.brightness;
    final color = VspColorSemantic.of(
      brightness,
      VspSemanticColorToken.official,
    );

    return Semantics(
      label: AppLocalizations.of(context).dataQualityOfficialLabel,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : VspSpacing.sm,
          vertical: compact ? VspSpacing.half : VspSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified,
              size: compact ? 12 : 14,
              color: brightness == Brightness.dark
                  ? VspColorDark.onAccent
                  : VspColorLight.onAccent,
            ),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context).dataQualityOfficial,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: brightness == Brightness.dark
                    ? VspColorDark.onAccent
                    : VspColorLight.onAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstimated(BuildContext context) {
    final brightness = Theme.of(context).colorScheme.brightness;
    final color = VspColorSemantic.of(
      brightness,
      VspSemanticColorToken.estimated,
    );

    return Semantics(
      label: AppLocalizations.of(context).dataQualityEstimatedLabel,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : VspSpacing.sm,
          vertical: compact ? VspSpacing.half : VspSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pending, size: compact ? 12 : 14, color: color),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context).dataQualityEstimated,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunity(BuildContext context) {
    final brightness = Theme.of(context).colorScheme.brightness;
    final color = brightness == Brightness.dark
        ? VspColorDark.textTertiary
        : VspColorLight.textTertiary;

    return Semantics(
      label: AppLocalizations.of(context).dataQualityCommunityLabel,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : VspSpacing.sm,
          vertical: compact ? VspSpacing.half : VspSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: brightness == Brightness.dark
              ? VspColorDark.muted
              : VspColorLight.muted,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.groups,
              size: compact ? 12 : 14,
              color: brightness == Brightness.dark
                  ? VspColorDark.onMuted
                  : VspColorLight.onMuted,
            ),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context).dataQualityCommunity,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: brightness == Brightness.dark
                    ? VspColorDark.onMuted
                    : VspColorLight.onMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStale(BuildContext context) {
    final brightness = Theme.of(context).colorScheme.brightness;
    final color = VspColorSemantic.of(brightness, VspSemanticColorToken.stale);

    return Semantics(
      label: AppLocalizations.of(context).freshnessStaleLabel,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : VspSpacing.sm,
          vertical: compact ? VspSpacing.half : VspSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber, size: compact ? 12 : 14, color: color),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context).freshnessStale,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: color,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Re-export semantic tokens from vsp_color
