// GenerateSmartTargetUseCase — VSP Mobile App
//
// Use case that orchestrates Smart Target generation using data from
// Club Performance (11.1), Strokes Gained (11.3), and Hole Geometry (Epic 6).
//
// Story 11.4 — Slice 2: Use Case

import '../../../domain/analytics/smart_target/models/smart_target_recommendation.dart';
import '../../../domain/analytics/smart_target/repositories/club_performance_repository.dart';
import '../../../domain/analytics/smart_target/repositories/hole_geometry_provider.dart';
import '../../../domain/analytics/smart_target/repositories/strokes_gained_repository.dart';
import '../../../domain/analytics/smart_target/smart_target_generator.dart';
import '../../../domain/models/tournament_policy.dart';
import '../../../domain/value_objects/lat_lng.dart';

/// Use case input for Smart Target generation.
class GenerateSmartTargetInput {
  final String playerId;
  final LatLng golferPosition;
  final double? handicap;
  final String holeId;
  final String? courseId;
  final int holeNumber;
  final TournamentPolicy? tournamentPolicy;
  final double windSpeedMps;
  final double windDirectionRadians;
  final double temperatureCelsius;

  const GenerateSmartTargetInput({
    required this.playerId,
    required this.golferPosition,
    this.handicap,
    required this.holeId,
    this.courseId,
    required this.holeNumber,
    this.tournamentPolicy,
    this.windSpeedMps = 0,
    this.windDirectionRadians = 0,
    this.temperatureCelsius = 20,
  });
}

/// Use case output for Smart Target generation.
typedef GenerateSmartTargetOutput = SmartTargetRecommendation;

/// Use case for generating Smart Target recommendations.
///
/// Orchestrates data fetching from 11.1, 11.3, Epic 6, and Epic 7,
/// then delegates to [SmartTargetGenerator].
class GenerateSmartTargetUseCase {
  final ClubPerformanceRepository clubPerformanceRepo;
  final StrokesGainedRepository strokesGainedRepo;
  final HoleGeometryProvider holeGeometryProvider;

  const GenerateSmartTargetUseCase({
    required this.clubPerformanceRepo,
    required this.strokesGainedRepo,
    required this.holeGeometryProvider,
  });

  /// Execute the use case.
  ///
  /// Returns a [SmartTargetRecommendation] which may be:
  /// - `available: false` if data is insufficient or policy blocks
  /// - `available: true` with strategy options
  Future<GenerateSmartTargetOutput> execute(
    GenerateSmartTargetInput input,
  ) async {
    // Fetch hole geometry
    final holeCtx = await (input.courseId != null
        ? holeGeometryProvider.getHoleContextByNumber(
            input.courseId!,
            input.holeNumber,
          )
        : holeGeometryProvider.getHoleContext(input.holeId));

    if (holeCtx == null) {
      return SmartTargetRecommendation.unavailable(
        reason: UnavailabilityReason.noHoleData,
        reasonLabel: 'Hole geometry not available',
        generatedAt: DateTime.now(),
      );
    }

    // Build golfer state
    final golferState = GolferState(
      playerId: input.playerId,
      position: input.golferPosition,
      handicap: input.handicap,
    );

    // Build shot conditions
    final conditions = ShotConditions(
      windSpeedMps: input.windSpeedMps,
      windDirectionRadians: input.windDirectionRadians,
      temperatureCelsius: input.temperatureCelsius,
    );

    // Build generator input
    final generatorInput = SmartTargetInput(
      holeContext: holeCtx,
      golferState: golferState,
      clubPerformanceRepo: clubPerformanceRepo,
      strokesGainedRepo: strokesGainedRepo,
      tournamentPolicy: input.tournamentPolicy,
      conditions: conditions,
    );

    // Generate recommendation
    final generator = SmartTargetGenerator();
    return await generator.generate(generatorInput);
  }
}
