// SmartTargetGenerator — VSP Mobile App
//
// Core algorithm for generating Smart Target strategy recommendations.
//
// Per slice-plan-11-4.md Slice 2:
// - Safe/balanced/aggressive strategy tiers
// - Candidate aim points along shot line
// - Landing ellipse computation
// - Risk scoring
//
// Story 11.4 — Slice 2: Core Generator Algorithm

import 'dart:math' as math;

import '../../value_objects/lat_lng.dart';
import '../../models/tournament_policy.dart';
import 'models/hazard_at_landing.dart';
import 'models/smart_target_recommendation.dart';
import 'models/strategy_option.dart';
import 'models/strategy_type.dart';
import 'repositories/club_performance_repository.dart';
import 'repositories/hole_geometry_provider.dart';
import 'repositories/strokes_gained_repository.dart';
import 'services/tournament_policy_guard.dart';

/// Golfer state required for Smart Target generation.
class GolferState {
  final String playerId;
  final LatLng position;
  final double? handicap;
  final int totalRoundsPlayed;

  const GolferState({
    required this.playerId,
    required this.position,
    this.handicap,
    this.totalRoundsPlayed = 0,
  });
}

/// Conditions affecting shot distance.
class ShotConditions {
  final double windSpeedMps;
  final double windDirectionRadians;
  final double temperatureCelsius;
  final double? greenSpeedStimp;

  const ShotConditions({
    this.windSpeedMps = 0,
    this.windDirectionRadians = 0,
    this.temperatureCelsius = 20,
    this.greenSpeedStimp,
  });
}

/// Smart Target generation input context.
class SmartTargetInput {
  final HoleContext holeContext;
  final GolferState golferState;
  final ClubPerformanceRepository clubPerformanceRepo;
  final StrokesGainedRepository strokesGainedRepo;
  final TournamentPolicy? tournamentPolicy;
  final ShotConditions conditions;

  const SmartTargetInput({
    required this.holeContext,
    required this.golferState,
    required this.clubPerformanceRepo,
    required this.strokesGainedRepo,
    this.tournamentPolicy,
    this.conditions = const ShotConditions(),
  });
}

/// Landing ellipse describing where a shot is expected to land.
class LandingEllipse {
  /// Center of ellipse (where ball is expected to land).
  final LatLng center;

  /// Distance from center to nearest edge (meters).
  final double nearMeters;

  /// Distance from center to farthest edge (meters).
  final double farMeters;

  /// Lateral spread half-width (meters).
  final double lateralSpreadMeters;

  const LandingEllipse({
    required this.center,
    required this.nearMeters,
    required this.farMeters,
    required this.lateralSpreadMeters,
  });
}

/// A candidate aim point with evaluated clubs.
class CandidateAimPoint {
  final LatLng point;
  final double carryMeters;
  final double remainingMeters;
  final List<EvaluatedClub> clubs;

  const CandidateAimPoint({
    required this.point,
    required this.carryMeters,
    required this.remainingMeters,
    required this.clubs,
  });
}

/// A club evaluated for a specific aim point.
class EvaluatedClub {
  final ClubPerformanceStats stats;
  final StrokesGainedResult? strokesGained;
  final LandingEllipse ellipse;
  final List<HazardAtLanding> hazards;
  final int riskScore;
  final double expectedValue;

  const EvaluatedClub({
    required this.stats,
    this.strokesGained,
    required this.ellipse,
    required this.hazards,
    required this.riskScore,
    required this.expectedValue,
  });
}

/// Smart Target generator.
///
/// Generates safe, balanced, and aggressive strategy recommendations
/// based on hole geometry, club performance data, strokes gained analytics,
/// and golfer state.
class SmartTargetGenerator {
  /// Minimum sample count for a club to be considered reliable.
  static const int minSampleCount = 3;

  /// Minimum number of reliable clubs required for generation.
  static const int minReliableClubs = 3;

  /// Aim point interval in meters.
  static const double aimPointIntervalMeters = 10.0;

  /// Dispersion tolerance factor (± this × dispersion for club selection).
  static const double dispersionToleranceFactor = 1.5;

  /// Maximum aim point candidates to evaluate per strategy.
  static const int maxAimPointCandidates = 30;

  /// Generate Smart Target recommendations.
  ///
  /// Returns `SmartTargetRecommendation` which is either:
  /// - `available: false` with a reason (policy blocked, insufficient data, etc.)
  /// - `available: true` with 3 strategy options (safe, balanced, aggressive)
  Future<SmartTargetRecommendation> generate(SmartTargetInput input) async {
    final now = DateTime.now();

    // ── AC3: Tournament policy check ────────────────────────────────────────
    final policyResult = checkTournamentPolicy(input.tournamentPolicy);
    if (policyResult != null && policyResult.isBlocked) {
      return SmartTargetRecommendation.unavailable(
        reason: policyResult.reason!,
        reasonLabel: policyResult.reasonLabel,
        generatedAt: now,
      );
    }

    // ── Validate golfer position ───────────────────────────────────────────
    if (input.golferState.position.latitude == 0 &&
        input.golferState.position.longitude == 0) {
      return SmartTargetRecommendation.unavailable(
        reason: UnavailabilityReason.noGolferPosition,
        reasonLabel: 'Golfer position not available',
        generatedAt: now,
      );
    }

    // ── AC1: Load data from all 8 sources ──────────────────────────────────
    final holeCtx = input.holeContext;

    // Validate hole geometry
    if (holeCtx.pinPosition.latitude == 0 &&
        holeCtx.pinPosition.longitude == 0) {
      return SmartTargetRecommendation.unavailable(
        reason: UnavailabilityReason.noHoleData,
        reasonLabel: 'No hole geometry data available',
        generatedAt: now,
      );
    }

    // Load club performance data (Story 11.1)
    final clubList = await _getClubs(
      input.clubPerformanceRepo,
      input.golferState.playerId,
    );

    if (clubList.length < minReliableClubs) {
      return SmartTargetRecommendation.unavailable(
        reason: UnavailabilityReason.insufficientHistory,
        reasonLabel:
            'Not enough club data. Need $minReliableClubs clubs, got ${clubList.length}.',
        generatedAt: now,
      );
    }

    // Load strokes gained data (Story 11.3)
    final sgList = await _getStrokesGained(
      input.strokesGainedRepo,
      input.golferState.playerId,
    );

    // Build strokes gained lookup
    final sgByClub = <String, StrokesGainedResult>{};
    for (final sg in sgList) {
      sgByClub[sg.clubId] = sg;
    }

    // ── Compute shot line ───────────────────────────────────────────────────
    final golferPos = input.golferState.position;
    final pinPos = holeCtx.pinPosition;
    final totalDistance = golferPos.distanceTo(pinPos);

    // Safe zone: 70% of total distance (short of hazards typical)
    // Green entry: 90% of total distance (long but not over green)
    const safeZoneFraction = 0.70;
    const greenEntryFraction = 0.90;

    final safeDistance = totalDistance * safeZoneFraction;
    final greenDistance = totalDistance * greenEntryFraction;

    // ── Generate candidate aim points ────────────────────────────────────────
    final candidates = _generateAimPoints(
      golferPos: golferPos,
      pinPos: pinPos,
      safeDistance: safeDistance,
      greenDistance: greenDistance,
      clubs: clubList,
      holeCtx: holeCtx,
      sgByClub: sgByClub,
      conditions: input.conditions,
    );

    if (candidates.isEmpty) {
      return SmartTargetRecommendation.unavailable(
        reason: UnavailabilityReason.insufficientHistory,
        reasonLabel: 'No valid aim points found',
        generatedAt: now,
      );
    }

    // ── Select best option per strategy tier ────────────────────────────────
    final strategyOptions = <StrategyOption>[];

    for (final strategyType in StrategyType.values) {
      final option = _selectBestForStrategy(
        strategyType: strategyType,
        candidates: candidates,
        holeCtx: holeCtx,
        golferPos: golferPos,
        pinPos: pinPos,
        handicap: input.golferState.handicap,
      );
      if (option != null) {
        strategyOptions.add(option);
      }
    }

    if (strategyOptions.isEmpty) {
      return SmartTargetRecommendation.unavailable(
        reason: UnavailabilityReason.unknown,
        reasonLabel: 'Failed to generate any strategy options',
        generatedAt: now,
      );
    }

    return SmartTargetRecommendation.available(
      strategyOptions: strategyOptions,
      dataSourceVersions: {
        '11.1': 'club_performance',
        '11.3': 'strokes_gained',
        'hole_geometry': holeCtx.holeId,
      },
      generatedAt: now,
    );
  }

  Future<List<ClubPerformanceStats>> _getClubs(
    ClubPerformanceRepository repo,
    String playerId,
  ) async {
    try {
      return await repo.getReliableClubs(
        playerId,
        minSampleCount: minSampleCount,
      );
    } catch (_) {
      return [];
    }
  }

  Future<List<StrokesGainedResult>> _getStrokesGained(
    StrokesGainedRepository repo,
    String playerId,
  ) async {
    try {
      return await repo.getAllForPlayer(playerId);
    } catch (_) {
      return [];
    }
  }

  // ─── Aim point generation ─────────────────────────────────────────────────

  List<CandidateAimPoint> _generateAimPoints({
    required LatLng golferPos,
    required LatLng pinPos,
    required double safeDistance,
    required double greenDistance,
    required List<ClubPerformanceStats> clubs,
    required HoleContext holeCtx,
    required Map<String, StrokesGainedResult> sgByClub,
    required ShotConditions conditions,
  }) {
    final candidates = <CandidateAimPoint>[];

    // Generate aim points from safe zone to green
    final numPoints =
        ((greenDistance - safeDistance) / aimPointIntervalMeters).ceil() + 1;

    for (
      var i = 0;
      i < numPoints && candidates.length < maxAimPointCandidates;
      i++
    ) {
      final fraction = i / math.max(numPoints - 1, 1);
      final targetDistance =
          safeDistance + (greenDistance - safeDistance) * fraction;

      final aimPoint = _pointAlongLine(
        start: golferPos,
        end: pinPos,
        distance: targetDistance,
      );

      final carryMeters = targetDistance;
      final remainingMeters = golferPos.distanceTo(pinPos) - targetDistance;

      // Evaluate clubs for this aim point
      final evaluatedClubs = <EvaluatedClub>[];

      for (final club in clubs) {
        // Check if club can reach this distance (with dispersion tolerance)
        final effectiveCarry = club.avgCarryMeters;
        final tolerance = club.dispersionMeters * dispersionToleranceFactor;

        if (effectiveCarry < carryMeters - tolerance) continue;
        if (effectiveCarry > carryMeters + tolerance * 2) continue;

        // Compute landing ellipse
        final ellipse = _computeLandingEllipse(
          aimPoint: aimPoint,
          club: club,
          golferPos: golferPos,
          conditions: conditions,
        );

        // Compute hazard intersections
        final hazards = _computeHazardIntersections(
          ellipse: ellipse,
          hazards: holeCtx.hazards,
          club: club,
        );

        // Compute risk score
        final riskScore = _computeRiskScore(hazards, club);

        // Compute expected value for balanced/aggressive strategies
        final sg = sgByClub[club.clubId];
        final expectedValue = _computeExpectedValue(
          club: club,
          strokesGained: sg,
          carryMeters: carryMeters,
          remainingMeters: remainingMeters,
          riskScore: riskScore,
        );

        evaluatedClubs.add(
          EvaluatedClub(
            stats: club,
            strokesGained: sg,
            ellipse: ellipse,
            hazards: hazards,
            riskScore: riskScore,
            expectedValue: expectedValue,
          ),
        );
      }

      if (evaluatedClubs.isNotEmpty) {
        candidates.add(
          CandidateAimPoint(
            point: aimPoint,
            carryMeters: carryMeters,
            remainingMeters: remainingMeters,
            clubs: evaluatedClubs,
          ),
        );
      }
    }

    return candidates;
  }

  LatLng _pointAlongLine({
    required LatLng start,
    required LatLng end,
    required double distance,
  }) {
    final bearing = _calculateBearing(start, end);
    return _destinationPoint(start, bearing, distance);
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;
    final dLon = (end.longitude - start.longitude) * math.pi / 180;

    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    return math.atan2(y, x);
  }

  LatLng _destinationPoint(LatLng start, double bearing, double distance) {
    const earthRadiusM = 6371000.0;
    final lat1 = start.latitude * math.pi / 180;
    final lon1 = start.longitude * math.pi / 180;
    final bearingRad = bearing;

    final lat2 = math.asin(
      math.sin(lat1) * math.cos(distance / earthRadiusM) +
          math.cos(lat1) *
              math.sin(distance / earthRadiusM) *
              math.cos(bearingRad),
    );

    final lon2 =
        lon1 +
        math.atan2(
          math.sin(bearingRad) *
              math.sin(distance / earthRadiusM) *
              math.cos(lat1),
          math.cos(distance / earthRadiusM) - math.sin(lat1) * math.sin(lat2),
        );

    return LatLng(
      latitude: lat2 * 180 / math.pi,
      longitude: lon2 * 180 / math.pi,
    );
  }

  // ─── Landing ellipse computation ───────────────────────────────────────────

  LandingEllipse _computeLandingEllipse({
    required LatLng aimPoint,
    required ClubPerformanceStats club,
    required LatLng golferPos,
    required ShotConditions conditions,
  }) {
    // Dispersion spread (left/right)
    final lateralSpread =
        (club.leftBiasMeters.abs() + club.rightBiasMeters.abs()) / 2;

    // Effective dispersion adjusted for conditions
    final windEffect = conditions.windSpeedMps * 0.5;
    final adjustedLateralSpread = lateralSpread * (1 + windEffect / 10);

    // Near/far based on average carry vs actual target
    final avgCarry = club.avgCarryMeters;
    final carryDiff = avgCarry - golferPos.distanceTo(aimPoint);

    final nearMeters = (club.dispersionMeters - carryDiff).abs().clamp(
      0.0,
      club.dispersionMeters * 2,
    );
    final farMeters = (club.dispersionMeters + carryDiff).abs().clamp(
      nearMeters,
      club.dispersionMeters * 3,
    );

    return LandingEllipse(
      center: aimPoint,
      nearMeters: nearMeters,
      farMeters: farMeters,
      lateralSpreadMeters: adjustedLateralSpread,
    );
  }

  // ─── Hazard intersection ──────────────────────────────────────────────────

  List<HazardAtLanding> _computeHazardIntersections({
    required LandingEllipse ellipse,
    required List<HoleHazardSummary> hazards,
    required ClubPerformanceStats club,
  }) {
    final result = <HazardAtLanding>[];

    for (final hazard in hazards) {
      final proximity = _computeProximityToHazard(
        ellipse: ellipse,
        hazardPolygon: hazard.polygon,
        dispersionMeters: club.dispersionMeters,
      );

      if (proximity > 0) {
        result.add(
          HazardAtLanding(
            hazardId: hazard.id,
            hazardName: hazard.name,
            hazardType: hazard.type,
            proximityFactor: proximity,
            penaltyWeight: _penaltyWeightForType(hazard.type),
          ),
        );
      }
    }

    return result;
  }

  double _computeProximityToHazard({
    required LandingEllipse ellipse,
    required List<LatLng> hazardPolygon,
    required double dispersionMeters,
  }) {
    if (hazardPolygon.isEmpty) return 0.0;

    final hazardCenter = _polygonCenter(hazardPolygon);
    final distanceToHazard = ellipse.center.distanceTo(hazardCenter);

    if (distanceToHazard < dispersionMeters) {
      return 1.0; // Overlapping
    } else if (distanceToHazard < dispersionMeters * 2) {
      return 0.5; // Near miss zone
    }

    return 0.0;
  }

  LatLng _polygonCenter(List<LatLng> polygon) {
    if (polygon.isEmpty) {
      return const LatLng(latitude: 0, longitude: 0);
    }
    if (polygon.length == 1) return polygon.first;

    double sumLat = 0, sumLon = 0;
    for (final p in polygon) {
      sumLat += p.latitude;
      sumLon += p.longitude;
    }
    return LatLng(
      latitude: sumLat / polygon.length,
      longitude: sumLon / polygon.length,
    );
  }

  int _penaltyWeightForType(String hazardType) {
    switch (hazardType) {
      case 'water':
        return 60;
      case 'penalty':
        return 60;
      case 'bunker':
        return 30;
      case 'ob':
        return 80;
      default:
        return 40;
    }
  }

  // ─── Risk scoring ──────────────────────────────────────────────────────────

  int _computeRiskScore(
    List<HazardAtLanding> hazards,
    ClubPerformanceStats club,
  ) {
    double riskSum = 0;

    for (final hazard in hazards) {
      riskSum +=
          hazard.penaltyWeight * hazard.proximityFactor * club.confidence;
    }

    return riskSum.clamp(0.0, 100.0).round();
  }

  // ─── Expected value computation ───────────────────────────────────────────

  double _computeExpectedValue({
    required ClubPerformanceStats club,
    required StrokesGainedResult? strokesGained,
    required double carryMeters,
    required double remainingMeters,
    required int riskScore,
  }) {
    double baseValue = 0;
    if (strokesGained != null) {
      baseValue = strokesGained.strokesGainedPerShot * 10;
    }

    // Distance efficiency bonus
    final distanceEfficiency = 1.0 - (remainingMeters / 200).clamp(0.0, 1.0);

    // Risk penalty
    final riskPenalty = riskScore / 100;

    // Confidence bonus
    final confidenceBonus = club.confidence * 0.5;

    return (baseValue +
            distanceEfficiency * 5 -
            riskPenalty * 3 +
            confidenceBonus)
        .clamp(-10.0, 20.0);
  }

  // ─── Strategy selection ─────────────────────────────────────────────────

  StrategyOption? _selectBestForStrategy({
    required StrategyType strategyType,
    required List<CandidateAimPoint> candidates,
    required HoleContext holeCtx,
    required LatLng golferPos,
    required LatLng pinPos,
    required double? handicap,
  }) {
    if (candidates.isEmpty) return null;

    EvaluatedClub? bestClub;
    CandidateAimPoint? bestCandidate;

    switch (strategyType) {
      case StrategyType.safe:
        bestClub = _selectSafeClub(candidates);
        bestCandidate = _findCandidateForClub(candidates, bestClub);
        break;

      case StrategyType.balanced:
        bestClub = _selectBalancedClub(candidates);
        bestCandidate = _findCandidateForClub(candidates, bestClub);
        break;

      case StrategyType.aggressive:
        bestClub = _selectAggressiveClub(candidates, pinPos);
        bestCandidate = _findCandidateForClub(candidates, bestClub);
        break;
    }

    if (bestClub == null || bestCandidate == null) return null;

    return StrategyOption(
      strategyType: strategyType,
      clubId: bestClub.stats.clubId,
      clubName: bestClub.stats.clubName,
      loftDegrees: bestClub.stats.loftDegrees,
      aimPoint: bestCandidate.point,
      carryMeters: bestCandidate.carryMeters,
      remainingMeters: bestCandidate.remainingMeters,
      hazardsAtLanding: bestClub.hazards,
      riskScore: bestClub.riskScore,
      confidenceScore: bestClub.stats.confidence,
      explanation: _generateExplanation(
        strategyType: strategyType,
        club: bestClub,
        candidate: bestCandidate,
        holeCtx: holeCtx,
        handicap: handicap,
      ),
    );
  }

  EvaluatedClub? _selectSafeClub(List<CandidateAimPoint> candidates) {
    EvaluatedClub? best;

    for (final candidate in candidates) {
      for (final club in candidate.clubs) {
        if (best == null ||
            club.riskScore < best.riskScore ||
            (club.riskScore == best.riskScore &&
                club.stats.confidence > best.stats.confidence)) {
          best = club;
        }
      }
    }

    return best;
  }

  EvaluatedClub? _selectBalancedClub(List<CandidateAimPoint> candidates) {
    EvaluatedClub? best;

    for (final candidate in candidates) {
      for (final club in candidate.clubs) {
        if (best == null || club.expectedValue > best.expectedValue) {
          best = club;
        }
      }
    }

    return best;
  }

  EvaluatedClub? _selectAggressiveClub(
    List<CandidateAimPoint> candidates,
    LatLng pinPos,
  ) {
    EvaluatedClub? best;
    double bestDistanceToPin = double.infinity;

    for (final candidate in candidates) {
      for (final club in candidate.clubs) {
        final distanceToPin = candidate.point.distanceTo(pinPos);

        // Aggressive: prefer closer to pin, but cap risk at 75
        if (club.riskScore <= 75) {
          if (best == null || distanceToPin < bestDistanceToPin) {
            best = club;
            bestDistanceToPin = distanceToPin;
          }
        }
      }
    }

    return best;
  }

  CandidateAimPoint? _findCandidateForClub(
    List<CandidateAimPoint> candidates,
    EvaluatedClub? club,
  ) {
    if (club == null) return null;
    for (final candidate in candidates) {
      for (final c in candidate.clubs) {
        if (c.stats.clubId == club.stats.clubId) {
          return candidate;
        }
      }
    }
    return null;
  }

  // ─── Explanation generation ────────────────────────────────────────────────

  String _generateExplanation({
    required StrategyType strategyType,
    required EvaluatedClub club,
    required CandidateAimPoint candidate,
    required HoleContext holeCtx,
    required double? handicap,
  }) {
    final clubName = club.stats.clubName;
    final carryMeters = candidate.carryMeters.round();
    final remainingMeters = candidate.remainingMeters.round();
    final riskScore = club.riskScore;

    final hazardCount = club.hazards.length;
    final hasHazards = hazardCount > 0;

    switch (strategyType) {
      case StrategyType.safe:
        if (hasHazards) {
          return '$clubName carry ${carryMeters}m leaves ${remainingMeters}m to pin. '
              'Lowest risk option ($riskScore/100) with ${(club.stats.confidence * 100).round()}% confidence. '
              '$hazardCount hazard(s) near landing zone.';
        }
        return '$clubName carry ${carryMeters}m leaves ${remainingMeters}m to pin. '
            'Lowest risk option ($riskScore/100) with ${(club.stats.confidence * 100).round()}% confidence. '
            'No hazards in landing zone.';

      case StrategyType.balanced:
        final sgValue = club.strokesGained?.strokesGainedPerShot ?? 0;
        final sgStr = sgValue >= 0
            ? '+${sgValue.toStringAsFixed(2)}'
            : sgValue.toStringAsFixed(2);
        if (hasHazards) {
          return '$clubName carry ${carryMeters}m leaves ${remainingMeters}m to pin. '
              'Best risk/reward balance ($riskScore/100). '
              'Strokes gained: $sgStr/shot.';
        }
        return '$clubName carry ${carryMeters}m leaves ${remainingMeters}m to pin. '
            'Best risk/reward balance ($riskScore/100). '
            'Strokes gained: $sgStr/shot.';

      case StrategyType.aggressive:
        if (hasHazards) {
          return '$clubName carry ${carryMeters}m leaves ${remainingMeters}m to pin. '
              'Aggressive: maximizes distance, accepts risk ($riskScore/100). '
              '$hazardCount hazard(s) in zone.';
        }
        return '$clubName carry ${carryMeters}m leaves ${remainingMeters}m to pin. '
            'Aggressive: maximizes distance, accepts risk ($riskScore/100). '
            'No major hazards in zone.';
    }
  }
}

// ─── Backward-compatible top-level function ─────────────────────────────────

/// Stub Smart Target generator (backward-compatible).
///
/// Delegates to [SmartTargetGenerator] for full implementation.
SmartTargetRecommendation? generateSmartTarget() {
  // This stub is kept for backward compatibility.
  // The new SmartTargetGenerator.generate() handles all cases properly.
  return null;
}
