// TournamentPolicyGuard Unit Tests — VSP Mobile App
//
// Truth table tests for tournament policy gating.
//
// Per Story 7.4 contract:
// - clubRecommendation restricted → blocked
// - aiStrategy restricted → blocked
// - Neither restricted → proceed
// - No policy attached → proceed
//
// Story 11.4 — Slice 0: Unit Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/tournament_feature.dart';
import 'package:vsp_mobile/domain/models/tournament_policy.dart';
import 'package:vsp_mobile/domain/analytics/smart_target/models/smart_target_recommendation.dart';
import 'package:vsp_mobile/domain/analytics/smart_target/services/tournament_policy_guard.dart';

void main() {
  final now = DateTime.now();

  TournamentPolicy makePolicy({
    bool clubRecommendationEnabled = true,
    bool aiFeaturesEnabled = true,
  }) {
    return TournamentPolicy(
      id: 'policy-1',
      name: 'Test Tournament',
      clubRecommendationEnabled: clubRecommendationEnabled,
      aiFeaturesEnabled: aiFeaturesEnabled,
      isLocked: false,
      createdAt: now,
      createdBy: 'test',
    );
  }

  group('checkTournamentPolicy', () {
    test('returns noPolicy when policy is null (casual mode)', () {
      final result = checkTournamentPolicy(null);

      expect(result, isA<TournamentPolicyGuardResult>());
      expect(result!.isBlocked, false);
      expect(result.available, true);
      expect(result.policy, isNull);
    });

    test('returns proceed when all features are enabled', () {
      final policy = makePolicy(
        clubRecommendationEnabled: true,
        aiFeaturesEnabled: true,
      );

      final result = checkTournamentPolicy(policy);

      expect(result, isA<TournamentPolicyGuardResult>());
      expect(result!.isBlocked, false);
      expect(result.available, true);
      expect(result.policy, policy);
    });

    test('returns blocked when clubRecommendation is disabled', () {
      final policy = makePolicy(
        clubRecommendationEnabled: false,
        aiFeaturesEnabled: true,
      );

      final result = checkTournamentPolicy(policy);

      expect(result!.isBlocked, true);
      expect(result.available, false);
      expect(result.reason, UnavailabilityReason.restrictedByPolicy);
      expect(result.reasonLabel, isNotNull);
      expect(result.policy, policy);
    });

    test('returns blocked when aiFeatures is disabled', () {
      final policy = makePolicy(
        clubRecommendationEnabled: true,
        aiFeaturesEnabled: false,
      );

      final result = checkTournamentPolicy(policy);

      expect(result!.isBlocked, true);
      expect(result.available, false);
      expect(result.reason, UnavailabilityReason.restrictedByPolicy);
      expect(result.reasonLabel, contains('AI features'));
      expect(result.policy, policy);
    });

    test('returns blocked when both clubRecommendation and aiFeatures are disabled',
        () {
      final policy = makePolicy(
        clubRecommendationEnabled: false,
        aiFeaturesEnabled: false,
      );

      final result = checkTournamentPolicy(policy);

      // clubRecommendation check takes precedence (first in order).
      expect(result!.isBlocked, true);
      expect(result.reason, UnavailabilityReason.restrictedByPolicy);
    });

    test('proceed result is not blocked and is available', () {
      final policy = makePolicy();
      final result = checkTournamentPolicy(policy);

      expect(result!.isBlocked, false);
      expect(result.available, true);
      expect(result.reason, isNull);
    });

    test('blocked result has correct unavailability reason', () {
      final policyClubOff = makePolicy(clubRecommendationEnabled: false);
      final policyAiOff = makePolicy(aiFeaturesEnabled: false);

      final clubOffResult = checkTournamentPolicy(policyClubOff);
      final aiOffResult = checkTournamentPolicy(policyAiOff);

      expect(
        clubOffResult!.reasonLabel,
        contains('Club recommendation'),
      );
      expect(
        aiOffResult!.reasonLabel,
        contains('AI features'),
      );
    });

    test('result is always non-null (no nullable path escapes)', () {
      // Every branch returns a TournamentPolicyGuardResult.
      final results = [
        checkTournamentPolicy(null),
        checkTournamentPolicy(makePolicy()),
        checkTournamentPolicy(
            makePolicy(clubRecommendationEnabled: false)),
        checkTournamentPolicy(makePolicy(aiFeaturesEnabled: false)),
      ];

      for (final r in results) {
        expect(r, isA<TournamentPolicyGuardResult>());
      }
    });
  });

  group('TournamentPolicyGuardResult', () {
    test('blocked factory sets isBlocked true', () {
      final result = TournamentPolicyGuardResult.blocked(
        policy: makePolicy(),
        reason: UnavailabilityReason.restrictedByPolicy,
        reasonLabel: 'Test block',
        generatedAt: now,
      );

      expect(result.isBlocked, true);
      expect(result.available, false);
      expect(result.reason, UnavailabilityReason.restrictedByPolicy);
    });

    test('proceed factory sets isBlocked false', () {
      final policy = makePolicy();
      final result = TournamentPolicyGuardResult.proceed(
        policy: policy,
        generatedAt: now,
      );

      expect(result.isBlocked, false);
      expect(result.available, true);
      expect(result.policy, policy);
    });

    test('noPolicy factory sets isBlocked false and policy null', () {
      const result = TournamentPolicyGuardResult.noPolicy();

      expect(result.isBlocked, false);
      expect(result.available, true);
      expect(result.policy, isNull);
    });
  });

  group('UnavailabilityReason', () {
    test('fromValue returns correct enum for known values', () {
      expect(
        UnavailabilityReason.fromValue('restricted_by_policy'),
        UnavailabilityReason.restrictedByPolicy,
      );
      expect(
        UnavailabilityReason.fromValue('insufficient_history'),
        UnavailabilityReason.insufficientHistory,
      );
      expect(
        UnavailabilityReason.fromValue('no_hole_data'),
        UnavailabilityReason.noHoleData,
      );
    });

    test('fromValue returns unknown for unknown values', () {
      expect(
        UnavailabilityReason.fromValue('not_a_reason'),
        UnavailabilityReason.unknown,
      );
    });

    test('fromValue returns null for null input', () {
      expect(UnavailabilityReason.fromValue(null), isNull);
    });
  });
}
