// Smart Target Models Unit Tests — VSP Mobile App
//
// Tests for StrategyType, HazardAtLanding, StrategyOption,
// and SmartTargetRecommendation models.
//
// Story 11.4 — Slice 0: Unit Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/analytics/smart_target/models/models.dart';
import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';

void main() {
  group('StrategyType', () {
    test('has correct display names', () {
      expect(StrategyType.safe.displayName, 'Safe');
      expect(StrategyType.balanced.displayName, 'Balanced');
      expect(StrategyType.aggressive.displayName, 'Aggressive');
    });

    test('has correct descriptions', () {
      expect(StrategyType.safe.description, contains('risk'));
      expect(StrategyType.balanced.description, contains('Balance'));
      expect(StrategyType.aggressive.description, contains('distance'));
    });
  });

  group('HazardAtLanding', () {
    test('fromJson parses correctly', () {
      final json = {
        'hazardId': 'h1',
        'hazardName': 'Bunker 1',
        'hazardType': 'bunker',
        'proximityFactor': 1.0,
        'penaltyWeight': 30,
      };
      final hazard = HazardAtLanding.fromJson(json);

      expect(hazard.hazardId, 'h1');
      expect(hazard.hazardName, 'Bunker 1');
      expect(hazard.hazardType, 'bunker');
      expect(hazard.proximityFactor, 1.0);
      expect(hazard.penaltyWeight, 30);
    });

    test('toJson round-trip is lossless', () {
      const hazard = HazardAtLanding(
        hazardId: 'h2',
        hazardName: 'Water Hole 3',
        hazardType: 'water',
        proximityFactor: 0.5,
        penaltyWeight: 50,
      );
      final restored = HazardAtLanding.fromJson(hazard.toJson());

      expect(restored, hazard);
    });

    test('isOverlapping returns true when proximity >= 1.0', () {
      const hazard = HazardAtLanding(
        hazardId: 'h1',
        hazardName: 'Bunker',
        hazardType: 'bunker',
        proximityFactor: 1.0,
        penaltyWeight: 30,
      );
      expect(hazard.isOverlapping, true);
    });

    test('isNearMiss returns true when 0 < proximity < 1.0', () {
      const hazard = HazardAtLanding(
        hazardId: 'h1',
        hazardName: 'Bunker',
        hazardType: 'bunker',
        proximityFactor: 0.5,
        penaltyWeight: 30,
      );
      expect(hazard.isNearMiss, true);
    });

    test('isClear returns true when proximity <= 0.0', () {
      const hazard = HazardAtLanding(
        hazardId: 'h1',
        hazardName: 'Bunker',
        hazardType: 'bunker',
        proximityFactor: 0.0,
        penaltyWeight: 30,
      );
      expect(hazard.isClear, true);
    });
  });

  group('StrategyOption', () {
    test('fromJson parses correctly', () {
      final json = {
        'strategyType': 'balanced',
        'clubId': 'club-7',
        'clubName': '7 Iron',
        'loftDegrees': 34.0,
        'aimPoint': {
          'type': 'Point',
          'coordinates': [-122.0, 37.0],
        },
        'carryMeters': 150.0,
        'remainingMeters': 35.0,
        'hazardsAtLanding': <Map<String, dynamic>>[],
        'riskScore': 25,
        'confidenceScore': 0.85,
        'explanation': 'Balanced risk-reward option',
      };
      final option = StrategyOption.fromJson(json);

      expect(option.strategyType, StrategyType.balanced);
      expect(option.clubId, 'club-7');
      expect(option.clubName, '7 Iron');
      expect(option.loftDegrees, 34.0);
      expect(option.aimPoint.latitude, 37.0);
      expect(option.aimPoint.longitude, -122.0);
      expect(option.carryMeters, 150.0);
      expect(option.remainingMeters, 35.0);
      expect(option.hazardsAtLanding, isEmpty);
      expect(option.riskScore, 25);
      expect(option.confidenceScore, 0.85);
      expect(option.explanation, 'Balanced risk-reward option');
    });

    test('toJson round-trip is lossless', () {
      const option = StrategyOption(
        strategyType: StrategyType.aggressive,
        clubId: 'club-driver',
        clubName: 'Driver',
        loftDegrees: 10.5,
        aimPoint: LatLng(latitude: 37.5, longitude: -122.3),
        carryMeters: 220.0,
        remainingMeters: 80.0,
        hazardsAtLanding: [
          HazardAtLanding(
            hazardId: 'h1',
            hazardName: 'Water',
            hazardType: 'water',
            proximityFactor: 0.5,
            penaltyWeight: 50,
          ),
        ],
        riskScore: 70,
        confidenceScore: 0.7,
        explanation: 'Go long',
      );
      final restored = StrategyOption.fromJson(option.toJson());

      expect(restored, option);
    });

    test('hasDirectHazard is true when any hazard overlaps', () {
      const option = StrategyOption(
        strategyType: StrategyType.safe,
        clubId: 'club-7',
        clubName: '7 Iron',
        aimPoint: LatLng(latitude: 37.0, longitude: -122.0),
        carryMeters: 150.0,
        remainingMeters: 35.0,
        hazardsAtLanding: [
          HazardAtLanding(
            hazardId: 'h1',
            hazardName: 'Bunker',
            hazardType: 'bunker',
            proximityFactor: 1.0,
            penaltyWeight: 30,
          ),
        ],
        riskScore: 40,
        confidenceScore: 0.8,
        explanation: 'Clear',
      );
      expect(option.hasDirectHazard, true);
    });

    test('hasNearMissHazard is true when any hazard is in near-miss zone', () {
      const option = StrategyOption(
        strategyType: StrategyType.balanced,
        clubId: 'club-7',
        clubName: '7 Iron',
        aimPoint: LatLng(latitude: 37.0, longitude: -122.0),
        carryMeters: 150.0,
        remainingMeters: 35.0,
        hazardsAtLanding: [
          HazardAtLanding(
            hazardId: 'h1',
            hazardName: 'Bunker',
            hazardType: 'bunker',
            proximityFactor: 0.5,
            penaltyWeight: 30,
          ),
        ],
        riskScore: 20,
        confidenceScore: 0.8,
        explanation: 'Near miss',
      );
      expect(option.hasNearMissHazard, true);
    });
  });

  group('SmartTargetRecommendation', () {
    test('available factory produces correct structure', () {
      final recommendation = SmartTargetRecommendation.available(
        strategyOptions: [
          const StrategyOption(
            strategyType: StrategyType.safe,
            clubId: 'club-7',
            clubName: '7 Iron',
            aimPoint: LatLng(latitude: 37.0, longitude: -122.0),
            carryMeters: 150.0,
            remainingMeters: 35.0,
            hazardsAtLanding: [],
            riskScore: 10,
            confidenceScore: 0.9,
            explanation: 'Safe',
          ),
        ],
        dataSourceVersions: {'11.1': 'v1', '11.3': 'v1'},
      );

      expect(recommendation.available, true);
      expect(recommendation.reason, isNull);
      expect(recommendation.strategyOptions, isNotNull);
      expect(recommendation.strategyOptions!.length, 1);
      expect(recommendation.dataSourceVersions, isNotNull);
      expect(recommendation.dataSourceVersions!['11.1'], 'v1');
    });

    test('unavailable factory produces correct structure for restrictedByPolicy', () {
      final recommendation = SmartTargetRecommendation.unavailable(
        reason: UnavailabilityReason.restrictedByPolicy,
        reasonLabel: 'AI features are disabled in tournament mode',
      );

      expect(recommendation.available, false);
      expect(recommendation.reason, UnavailabilityReason.restrictedByPolicy);
      expect(recommendation.reasonLabel,
          'AI features are disabled in tournament mode');
      expect(recommendation.strategyOptions, isNull);
      expect(recommendation.isRestrictedByPolicy, true);
    });

    test('isInsufficientHistory returns true for insufficient history', () {
      final recommendation = SmartTargetRecommendation.unavailable(
        reason: UnavailabilityReason.insufficientHistory,
      );
      expect(recommendation.isInsufficientHistory, true);
    });

    test('fromJson parses available recommendation correctly', () {
      final json = {
        'available': true,
        'strategyOptions': [
          {
            'strategyType': 'safe',
            'clubId': 'club-7',
            'clubName': '7 Iron',
            'aimPoint': {
              'type': 'Point',
              'coordinates': [-122.0, 37.0],
            },
            'carryMeters': 150.0,
            'remainingMeters': 35.0,
            'hazardsAtLanding': <Map<String, dynamic>>[],
            'riskScore': 10,
            'confidenceScore': 0.9,
            'explanation': 'Safe',
          },
        ],
        'generatedAt': '2026-08-02T10:00:00.000Z',
        'dataSourceVersions': {'11.1': 'v1'},
      };
      final recommendation = SmartTargetRecommendation.fromJson(json);

      expect(recommendation.available, true);
      expect(recommendation.strategyOptions, isNotNull);
      expect(recommendation.strategyOptions!.length, 1);
    });

    test('fromJson parses unavailable recommendation correctly', () {
      final json = {
        'available': false,
        'reason': 'restricted_by_policy',
        'reasonLabel': 'Club recommendation is disabled',
        'generatedAt': '2026-08-02T10:00:00.000Z',
      };
      final recommendation = SmartTargetRecommendation.fromJson(json);

      expect(recommendation.available, false);
      expect(recommendation.reason, UnavailabilityReason.restrictedByPolicy);
      expect(recommendation.strategyOptions, isNull);
    });

    test('toJson round-trip is lossless for available recommendation', () {
      final original = SmartTargetRecommendation.available(
        strategyOptions: [
          const StrategyOption(
            strategyType: StrategyType.balanced,
            clubId: 'club-5',
            clubName: '5 Iron',
            aimPoint: LatLng(latitude: 37.0, longitude: -122.0),
            carryMeters: 170.0,
            remainingMeters: 20.0,
            hazardsAtLanding: [],
            riskScore: 30,
            confidenceScore: 0.75,
            explanation: 'Balanced',
          ),
        ],
        dataSourceVersions: {'11.1': 'v2'},
      );
      final restored =
          SmartTargetRecommendation.fromJson(original.toJson());

      expect(restored.available, original.available);
      expect(restored.strategyOptions!.length,
          original.strategyOptions!.length);
      expect(restored.dataSourceVersions, original.dataSourceVersions);
    });

    test('toJson round-trip is lossless for unavailable recommendation', () {
      final original = SmartTargetRecommendation.unavailable(
        reason: UnavailabilityReason.noHoleData,
        reasonLabel: 'No hole data available',
      );
      final restored =
          SmartTargetRecommendation.fromJson(original.toJson());

      expect(restored.available, false);
      expect(restored.reason, original.reason);
      expect(restored.reasonLabel, original.reasonLabel);
    });
  });
}
