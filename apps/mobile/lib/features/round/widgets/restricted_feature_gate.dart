// RestrictedFeatureGate — VSP Mobile App
//
// General-purpose wrapper that shows/hides a child widget based on
// tournament feature guard status.
//
// Per PRD §8.12: "Restricted features must be hidden or disabled."
//
// Usage:
/// - RestrictedFeatureGate(
///     roundId: roundId,
///     feature: TournamentFeature.aiFeatures,
///     child: SmartTargetButton(...),
///   )
///
/// When restricted: shows [restrictedPlaceholder] (default: greyed-out icon + label).
/// When enabled: shows [child].
/// When guard unavailable: shows [child] (fail open).
//
// Story 7.4 — Slice D: Restricted Feature UI

import 'package:flutter/material.dart';

import '../../../application/services/tournament_feature_guard.dart';
import '../../../domain/models/tournament_feature.dart';
import 'restriction_badge.dart';

/// Widget that conditionally shows a child or a restricted placeholder
/// based on tournament policy feature status.
class RestrictedFeatureGate extends StatelessWidget {
  /// The active round ID for feature guard lookup.
  final String? roundId;

  /// The feature to check.
  final TournamentFeature feature;

  /// The tournament feature guard (nullable — renders child if null).
  final TournamentFeatureGuard? featureGuard;

  /// The child to show when the feature is enabled.
  final Widget child;

  /// Placeholder shown when the feature is restricted.
  /// Defaults to a greyed-out version of [child] with RestrictionBadge.
  final Widget? restrictedPlaceholder;

  /// If true, hides the child entirely when restricted (no placeholder).
  /// If false, shows [restrictedPlaceholder].
  /// Default: false.
  final bool hideWhenRestricted;

  const RestrictedFeatureGate({
    super.key,
    required this.roundId,
    required this.feature,
    required this.featureGuard,
    required this.child,
    this.restrictedPlaceholder,
    this.hideWhenRestricted = false,
  });

  @override
  Widget build(BuildContext context) {
    // No guard — fail open (show feature)
    if (featureGuard == null || roundId == null) {
      return child;
    }

    return FutureBuilder<bool>(
      future: featureGuard!.isFeatureEnabled(roundId!, feature),
      builder: (context, snapshot) {
        final isEnabled = snapshot.data;

        // Still loading — show child (avoid layout shift)
        if (isEnabled == null) {
          return child;
        }

        if (isEnabled) {
          return child;
        }

        if (hideWhenRestricted) {
          return const SizedBox.shrink();
        }

        return restrictedPlaceholder ??
            _DefaultRestrictedPlaceholder(feature: feature);
      },
    );
  }
}

/// Default restricted placeholder shown when a feature is disabled.
class _DefaultRestrictedPlaceholder extends StatelessWidget {
  final TournamentFeature feature;

  const _DefaultRestrictedPlaceholder({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(opacity: 0.4, child: IgnorePointer(child: child)),
        const SizedBox(height: 4),
        RestrictionBadge(restrictionReason: feature.restrictionLabel),
      ],
    );
  }

  Widget get child {
    // Return a generic placeholder based on feature type
    switch (feature) {
      case TournamentFeature.windAdjustment:
        return const _FeaturePlaceholder(
          icon: Icons.air,
          label: 'Wind adjustment',
        );
      case TournamentFeature.playsLike:
        return const _FeaturePlaceholder(
          icon: Icons.trending_up,
          label: 'Plays-like',
        );
      case TournamentFeature.elevation:
        return const _FeaturePlaceholder(
          icon: Icons.terrain,
          label: 'Elevation',
        );
      case TournamentFeature.clubRecommendation:
        return const _FeaturePlaceholder(
          icon: Icons.sports_golf,
          label: 'Club recommendation',
        );
      case TournamentFeature.contours:
        return const _FeaturePlaceholder(
          icon: Icons.layers,
          label: 'Green contours',
        );
      case TournamentFeature.puttingHelp:
        return const _FeaturePlaceholder(
          icon: Icons.flag,
          label: 'Putting help',
        );
      case TournamentFeature.aiFeatures:
        return const _FeaturePlaceholder(
          icon: Icons.smart_toy,
          label: 'AI features',
        );
    }
  }
}

class _FeaturePlaceholder extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeaturePlaceholder({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
