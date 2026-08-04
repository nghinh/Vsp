// TournamentPolicyGuard Service — VSP Mobile App
//
// Pure function that gates Smart Target generation based on tournament policy.
//
// Per Story 7.4 contract: if clubRecommendation or aiStrategy is restricted,
// Smart Target must return available: false.
//
// Story 11.4 — Slice 0: Domain Models + Tournament Policy Guard

import '../../../models/tournament_feature.dart';
import '../../../models/tournament_policy.dart';
import '../models/smart_target_recommendation.dart';

/// Result of a tournament policy guard check.
class TournamentPolicyGuardResult extends SmartTargetRecommendation {
  /// True if the guard blocked generation.
  final bool isBlocked;

  /// The policy that was evaluated (null if no policy present).
  final TournamentPolicy? policy;

  const TournamentPolicyGuardResult._({
    required super.available,
    super.reason,
    super.reasonLabel,
    super.strategyOptions,
    required super.generatedAt,
    super.dataSourceVersions,
    required this.isBlocked,
    this.policy,
  });

  /// Blocked by policy: returns unavailable recommendation.
  factory TournamentPolicyGuardResult.blocked({
    required TournamentPolicy policy,
    required UnavailabilityReason reason,
    required String reasonLabel,
    required DateTime generatedAt,
  }) {
    return TournamentPolicyGuardResult._(
      available: false,
      reason: reason,
      reasonLabel: reasonLabel,
      strategyOptions: null,
      generatedAt: generatedAt,
      dataSourceVersions: null,
      isBlocked: true,
      policy: policy,
    );
  }

  /// Not blocked: returns null (caller should proceed with generation).
  const TournamentPolicyGuardResult.proceed({
    required TournamentPolicy policy,
    required DateTime generatedAt,
  }) : policy = policy,
       isBlocked = false,
       super(
         available: true,
         reason: null,
         reasonLabel: null,
         strategyOptions: null,
         generatedAt: generatedAt,
         dataSourceVersions: null,
       );

  /// No policy attached (casual/practice mode): proceed.
  const TournamentPolicyGuardResult.noPolicy()
    : isBlocked = false,
      policy = null,
      super(
        available: true,
        reason: null,
        reasonLabel: null,
        strategyOptions: null,
        generatedAt: const _ConstDateTime(),
        dataSourceVersions: null,
      );
}

/// Guard function that checks tournament policy before generating Smart Target.
///
/// Returns a [TournamentPolicyGuardResult] that is either:
/// - `blocked`: with an unavailable recommendation to return immediately
/// - `proceed`: null result, caller should proceed with generation
///
/// Per Story 7.4 contract:
/// - `clubRecommendation` restriction → blocked
/// - `aiStrategy` restriction → blocked
TournamentPolicyGuardResult? checkTournamentPolicy(TournamentPolicy? policy) {
  final now = DateTime.now();

  // No policy attached: casual/practice mode, always proceed.
  if (policy == null) {
    return const TournamentPolicyGuardResult.noPolicy();
  }

  // Check club recommendation restriction.
  if (!policy.isFeatureEnabled(TournamentFeature.clubRecommendation)) {
    return TournamentPolicyGuardResult.blocked(
      policy: policy,
      reason: UnavailabilityReason.restrictedByPolicy,
      reasonLabel:
          policy.getRestrictionReason(TournamentFeature.clubRecommendation) ??
          'Club recommendation is disabled in tournament mode',
      generatedAt: now,
    );
  }

  // Check AI features restriction (covers Smart Target as an AI feature).
  if (!policy.isFeatureEnabled(TournamentFeature.aiFeatures)) {
    return TournamentPolicyGuardResult.blocked(
      policy: policy,
      reason: UnavailabilityReason.restrictedByPolicy,
      reasonLabel:
          policy.getRestrictionReason(TournamentFeature.aiFeatures) ??
          'AI features are disabled in tournament mode',
      generatedAt: now,
    );
  }

  // Policy allows generation.
  return TournamentPolicyGuardResult.proceed(policy: policy, generatedAt: now);
}

/// Stub date-time for const constructor.
class _ConstDateTime implements DateTime {
  const _ConstDateTime();

  @override
  dynamic noSuchMethod(Invocation invocation) => DateTime.now();
}
