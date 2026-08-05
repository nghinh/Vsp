// TournamentPolicy Model — VSP Mobile App
//
// Domain model for a tournament's feature restriction policy.
//
// Per PRD §8.12: "Tournament Mode may lock after round start."
// Per Architecture §14 QG-8: "Basic Tournament Mode restrictions are
// represented in config and UI."
//
// Story 7.4 — Slice A: TournamentPolicy Domain Model

import 'package:equatable/equatable.dart';

import 'tournament_feature.dart';

/// Result of attempting to modify a locked policy.
class TournamentPolicyLockedException implements Exception {
  final String message;
  const TournamentPolicyLockedException([
    this.message = 'Policy is locked and cannot be modified',
  ]);

  @override
  String toString() => 'TournamentPolicyLockedException: $message';
}

/// Domain model for a tournament feature restriction policy.
///
/// A policy is attached to a tournament-format round to control which
/// assistance features are available to the golfer.
///
/// **Null policy** (no policy attached): All features enabled — casual/practice modes.
///
/// **Non-null policy**: Only features with `enabled = true` are available.
/// All other features must be hidden or disabled with an explanation tooltip.
///
/// When `isLocked == true`, no feature flag may be changed without the
/// `TournamentDirector` role.
class TournamentPolicy extends Equatable {
  /// Unique identifier for this policy.
  final String id;

  /// Human-readable name for this policy.
  final String name;

  /// Whether wind adjustment is enabled in this tournament.
  final bool windAdjustmentEnabled;

  /// Whether plays-like distance is enabled in this tournament.
  final bool playsLikeEnabled;

  /// Whether elevation data is enabled in this tournament.
  final bool elevationEnabled;

  /// Whether club recommendation is enabled in this tournament.
  final bool clubRecommendationEnabled;

  /// Whether green contours are enabled in this tournament.
  final bool contoursEnabled;

  /// Whether putting help is enabled in this tournament.
  final bool puttingHelpEnabled;

  /// Whether AI features are enabled in this tournament.
  final bool aiFeaturesEnabled;

  /// When true, feature flags cannot be changed without TournamentDirector role.
  final bool isLocked;

  /// Timestamp when this policy was created.
  final DateTime createdAt;

  /// ID of the user or system that created this policy.
  final String createdBy;

  /// Version number for optimistic locking.
  final int version;

  const TournamentPolicy({
    required this.id,
    required this.name,
    this.windAdjustmentEnabled = true,
    this.playsLikeEnabled = true,
    this.elevationEnabled = true,
    this.clubRecommendationEnabled = true,
    this.contoursEnabled = true,
    this.puttingHelpEnabled = true,
    this.aiFeaturesEnabled = true,
    this.isLocked = false,
    required this.createdAt,
    required this.createdBy,
    this.version = 1,
  });

  /// Returns true if the given [feature] is enabled in this policy.
  ///
  /// Convenience method that maps [TournamentFeature] to the correct flag.
  bool isFeatureEnabled(TournamentFeature feature) {
    switch (feature) {
      case TournamentFeature.windAdjustment:
        return windAdjustmentEnabled;
      case TournamentFeature.playsLike:
        return playsLikeEnabled;
      case TournamentFeature.elevation:
        return elevationEnabled;
      case TournamentFeature.clubRecommendation:
        return clubRecommendationEnabled;
      case TournamentFeature.contours:
        return contoursEnabled;
      case TournamentFeature.puttingHelp:
        return puttingHelpEnabled;
      case TournamentFeature.aiFeatures:
        return aiFeaturesEnabled;
    }
  }

  /// Returns the reason why [feature] is restricted, for display in UI.
  ///
  /// Returns null if the feature is enabled (no restriction).
  String? getRestrictionReason(TournamentFeature feature) {
    if (isFeatureEnabled(feature)) return null;
    return feature.restrictionLabel;
  }

  /// Locks this policy, preventing further feature flag changes.
  ///
  /// Idempotent: if already locked, returns this unchanged.
  /// Throws [TournamentPolicyLockedException] if called on an already-locked
  /// policy from a non-TournamentDirector caller.
  TournamentPolicy lock() {
    return copyWith(isLocked: true);
  }

  /// Returns a copy of this policy with [feature] set to [enabled].
  ///
  /// Throws [TournamentPolicyLockedException] if this policy is locked
  /// and [actorHasDirectorRole] is false.
  TournamentPolicy setFeature({
    required TournamentFeature feature,
    required bool enabled,
    required bool actorHasDirectorRole,
  }) {
    if (isLocked && !actorHasDirectorRole) {
      throw const TournamentPolicyLockedException();
    }

    switch (feature) {
      case TournamentFeature.windAdjustment:
        return copyWith(windAdjustmentEnabled: enabled, version: version + 1);
      case TournamentFeature.playsLike:
        return copyWith(playsLikeEnabled: enabled, version: version + 1);
      case TournamentFeature.elevation:
        return copyWith(elevationEnabled: enabled, version: version + 1);
      case TournamentFeature.clubRecommendation:
        return copyWith(
          clubRecommendationEnabled: enabled,
          version: version + 1,
        );
      case TournamentFeature.contours:
        return copyWith(contoursEnabled: enabled, version: version + 1);
      case TournamentFeature.puttingHelp:
        return copyWith(puttingHelpEnabled: enabled, version: version + 1);
      case TournamentFeature.aiFeatures:
        return copyWith(aiFeaturesEnabled: enabled, version: version + 1);
    }
  }

  // ─── JSON ─────────────────────────────────────────────────────────────────

  factory TournamentPolicy.fromJson(Map<String, dynamic> json) {
    return TournamentPolicy(
      id: json['id'] as String,
      name: json['name'] as String,
      windAdjustmentEnabled: json['windAdjustmentEnabled'] as bool? ?? true,
      playsLikeEnabled: json['playsLikeEnabled'] as bool? ?? true,
      elevationEnabled: json['elevationEnabled'] as bool? ?? true,
      clubRecommendationEnabled:
          json['clubRecommendationEnabled'] as bool? ?? true,
      contoursEnabled: json['contoursEnabled'] as bool? ?? true,
      puttingHelpEnabled: json['puttingHelpEnabled'] as bool? ?? true,
      aiFeaturesEnabled: json['aiFeaturesEnabled'] as bool? ?? true,
      isLocked: json['isLocked'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      createdBy: json['createdBy'] as String,
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'windAdjustmentEnabled': windAdjustmentEnabled,
    'playsLikeEnabled': playsLikeEnabled,
    'elevationEnabled': elevationEnabled,
    'clubRecommendationEnabled': clubRecommendationEnabled,
    'contoursEnabled': contoursEnabled,
    'puttingHelpEnabled': puttingHelpEnabled,
    'aiFeaturesEnabled': aiFeaturesEnabled,
    'isLocked': isLocked,
    'createdAt': createdAt.toIso8601String(),
    'createdBy': createdBy,
    'version': version,
  };

  // ─── Copy ─────────────────────────────────────────────────────────────────

  TournamentPolicy copyWith({
    String? id,
    String? name,
    bool? windAdjustmentEnabled,
    bool? playsLikeEnabled,
    bool? elevationEnabled,
    bool? clubRecommendationEnabled,
    bool? contoursEnabled,
    bool? puttingHelpEnabled,
    bool? aiFeaturesEnabled,
    bool? isLocked,
    DateTime? createdAt,
    String? createdBy,
    int? version,
  }) {
    return TournamentPolicy(
      id: id ?? this.id,
      name: name ?? this.name,
      windAdjustmentEnabled:
          windAdjustmentEnabled ?? this.windAdjustmentEnabled,
      playsLikeEnabled: playsLikeEnabled ?? this.playsLikeEnabled,
      elevationEnabled: elevationEnabled ?? this.elevationEnabled,
      clubRecommendationEnabled:
          clubRecommendationEnabled ?? this.clubRecommendationEnabled,
      contoursEnabled: contoursEnabled ?? this.contoursEnabled,
      puttingHelpEnabled: puttingHelpEnabled ?? this.puttingHelpEnabled,
      aiFeaturesEnabled: aiFeaturesEnabled ?? this.aiFeaturesEnabled,
      isLocked: isLocked ?? this.isLocked,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      version: version ?? this.version,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    windAdjustmentEnabled,
    playsLikeEnabled,
    elevationEnabled,
    clubRecommendationEnabled,
    contoursEnabled,
    puttingHelpEnabled,
    aiFeaturesEnabled,
    isLocked,
    createdAt,
    createdBy,
    version,
  ];
}
