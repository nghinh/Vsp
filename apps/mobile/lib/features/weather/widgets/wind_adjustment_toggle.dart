// WindAdjustmentToggle — VSP Mobile App
//
// Toggle control for the wind adjustment feature (wind shown relative to
// shot line). Respects tournament mode restrictions.
//
// When restricted: shows disabled toggle with tooltip explaining restriction.
//
// Per PRD §8.12: "Restricted features must be hidden or disabled."
// Per UX spec: non-color-only indicator, screen reader accessible.
//
// Story 7.4 — Slice D: Restricted Feature UI
// (integrates with wind display from story 7.2)

import 'package:flutter/material.dart';

import '../../../application/services/tournament_feature_guard.dart';
import '../../../domain/models/tournament_feature.dart';
import '../../../domain/models/tournament_policy.dart';
import '../../round/widgets/restriction_badge.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Toggle control for wind adjustment feature.
///
/// When the tournament policy disables wind adjustment:
/// - Toggle is disabled
/// - [RestrictionBadge] is shown above/beside it
/// - Tooltip explains the restriction
///
/// Requires [TournamentFeatureGuard] to check feature status.
class WindAdjustmentToggle extends StatelessWidget {
  /// Current wind adjustment enabled state.
  final bool isEnabled;

  /// Called when the user toggles wind adjustment.
  final ValueChanged<bool>? onChanged;

  /// The tournament feature guard for checking restrictions.
  final TournamentFeatureGuard? featureGuard;

  /// The active round ID for feature guard lookup.
  final String? roundId;

  const WindAdjustmentToggle({
    super.key,
    required this.isEnabled,
    this.onChanged,
    this.featureGuard,
    this.roundId,
  });

  @override
  Widget build(BuildContext context) {
    // If no feature guard or round ID, render unrestricted toggle
    if (featureGuard == null || roundId == null) {
      return _buildToggle(context, isEnabled, onChanged);
    }

    return FutureBuilder<bool>(
      future: featureGuard!.isFeatureEnabled(
        roundId!,
        TournamentFeature.windAdjustment,
      ),
      builder: (context, snapshot) {
        final isRestricted = snapshot.data == false;

        if (isRestricted) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDisabledToggle(context),
              const SizedBox(height: 4),
              RestrictionBadge(
                restrictionReason:
                    TournamentFeature.windAdjustment.restrictionLabel,
              ),
            ],
          );
        }

        return _buildToggle(context, isEnabled, onChanged);
      },
    );
  }

  Widget _buildToggle(
    BuildContext context,
    bool value,
    ValueChanged<bool>? onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(AppLocalizations.of(context).weatherWindAdjustment, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 8),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF4CAF50),
        ),
      ],
    );
  }

  Widget _buildDisabledToggle(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Wind adjustment',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).disabledColor,
          ),
        ),
        const SizedBox(width: 8),
        Switch.adaptive(
          value: false,
          onChanged: null, // Disabled
          activeColor: Theme.of(context).disabledColor,
        ),
      ],
    );
  }
}
