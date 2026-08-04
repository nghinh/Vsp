// TournamentFeature Enum — VSP Mobile App
//
// Restrictable feature flags for Tournament Mode.
//
// Story 7.4 — Slice A: TournamentPolicy Domain Model

/// Feature flags that can be enabled/disabled in a tournament policy.
///
/// Each flag gates a specific UI control or assistance feature.
/// When a feature is disabled, the corresponding control must be
/// hidden or disabled with an explanation tooltip.
enum TournamentFeature {
  /// Wind adjustment toggle (wind speed/direction shown relative to shot line).
  windAdjustment('WIND_ADJUSTMENT'),

  /// Plays-like distance display (elevation-adjusted distance).
  playsLike('PLAYS_LIKE'),

  /// Elevation data display.
  elevation('ELEVATION'),

  /// AI-powered club recommendation.
  clubRecommendation('CLUB_RECOMMENDATION'),

  /// Green contour overlay.
  contours('CONTOURS'),

  /// Putting help display (break/stimp information).
  puttingHelp('PUTTING_HELP'),

  /// AI features (Smart Target, AI round review, etc.).
  aiFeatures('AI_FEATURES');

  final String value;
  const TournamentFeature(this.value);

  /// Returns the feature flag name for API/persistence.
  String get flagName {
    switch (this) {
      case TournamentFeature.windAdjustment:
        return 'windAdjustmentEnabled';
      case TournamentFeature.playsLike:
        return 'playsLikeEnabled';
      case TournamentFeature.elevation:
        return 'elevationEnabled';
      case TournamentFeature.clubRecommendation:
        return 'clubRecommendationEnabled';
      case TournamentFeature.contours:
        return 'contoursEnabled';
      case TournamentFeature.puttingHelp:
        return 'puttingHelpEnabled';
      case TournamentFeature.aiFeatures:
        return 'aiFeaturesEnabled';
    }
  }

  /// Localized display label for the restricted feature tooltip.
  String get restrictionLabel {
    switch (this) {
      case TournamentFeature.windAdjustment:
        return 'Wind adjustment is disabled in tournament mode';
      case TournamentFeature.playsLike:
        return 'Plays-like distance is disabled in tournament mode';
      case TournamentFeature.elevation:
        return 'Elevation data is disabled in tournament mode';
      case TournamentFeature.clubRecommendation:
        return 'Club recommendation is disabled in tournament mode';
      case TournamentFeature.contours:
        return 'Green contours are disabled in tournament mode';
      case TournamentFeature.puttingHelp:
        return 'Putting help is disabled in tournament mode';
      case TournamentFeature.aiFeatures:
        return 'AI features are disabled in tournament mode';
    }
  }

  static TournamentFeature? fromFlagName(String flagName) {
    for (final feature in TournamentFeature.values) {
      if (feature.flagName == flagName) return feature;
    }
    return null;
  }
}
