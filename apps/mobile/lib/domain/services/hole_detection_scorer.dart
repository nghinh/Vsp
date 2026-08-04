// Hole Detection Scorer — VSP Mobile App
//
// Pure confidence scoring for hole detection.
//
// Weighted multi-signal scoring algorithm (architecture §2.1):
//   - Distance to tee-box centroid (weight: 0.3)
//   - Distance to green centroid (weight: 0.3)
//   - Heading alignment with hole direction (weight: 0.2)
//   - GPS accuracy signal (weight: 0.2)
//
// All scoring is deterministic and has no side effects.
//
// Story 6.2 — Wave A: Interface & Model Definitions

import 'dart:math' as math;

import '../models/qualified_location.dart';
import '../repositories/hole_repository.dart';

/// Pure function class for computing hole detection confidence scores.
///
/// Scoring weights (fixed for MVP, per architecture §2.1):
///   - Distance to tee-box centroid: 0.3
///   - Distance to green centroid:   0.3
///   - Heading alignment:           0.2
///   - GPS accuracy:                0.2
///
/// Score range: 0.0 – 1.0
///
/// No side effects: this is a pure scoring function.
class HoleDetectionScorer {
  static const double _weightTeeBox = 0.3;
  static const double _weightGreen = 0.3;
  static const double _weightHeading = 0.2;
  static const double _weightAccuracy = 0.2;

  /// Score a list of hole geometries against a qualified location.
  ///
  /// [location]        — Current GPS location.
  /// [holeGeometries]  — Pre-fetched hole geometries for the active course.
  ///
  /// Returns a sorted list of [HoleScore] results, best match first.
  /// Returns empty list if [holeGeometries] is empty.
  List<HoleScore> scoreAll({
    required QualifiedLocation location,
    required List<HoleGeometry> holeGeometries,
  }) {
    if (holeGeometries.isEmpty) return [];

    final results = <HoleScore>[];

    for (final hole in holeGeometries) {
      final score = _scoreHole(location: location, hole: hole);
      results.add(HoleScore(holeGeometry: hole, score: score));
    }

    // Sort descending by score
    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  /// Score a single hole against a qualified location.
  ///
  /// Returns a score between 0.0 and 1.0.
  double _scoreHole({
    required QualifiedLocation location,
    required HoleGeometry hole,
  }) {
    // 1. Distance score — tee-box (weight 0.3)
    // Closer to tee-box = more likely on this hole's tee.
    final teeBoxDistScore = _distanceScore(
      location: location,
      holeLat: hole.teeBoxLatitude,
      holeLon: hole.teeBoxLongitude,
      referenceDistance: 50.0, // 50m reference for max score
    );

    // 2. Distance score — green (weight 0.3)
    // Closer to green = more likely approaching this green.
    final greenDistScore = _distanceScore(
      location: location,
      holeLat: hole.greenLatitude,
      holeLon: hole.greenLongitude,
      referenceDistance: 50.0,
    );

    // 3. Heading alignment score (weight 0.2)
    // Player heading aligned with hole direction = more likely on this hole.
    final headingScore = _headingScore(
      location: location,
      holeDirectionBearing: hole.holeDirectionBearing,
    );

    // 4. GPS accuracy score (weight 0.2)
    // Better accuracy = higher confidence.
    final accuracyScore = _accuracyScore(location.accuracyMeters);

    // Weighted sum
    final totalScore =
        (teeBoxDistScore * _weightTeeBox) +
        (greenDistScore * _weightGreen) +
        (headingScore * _weightHeading) +
        (accuracyScore * _weightAccuracy);

    return totalScore.clamp(0.0, 1.0);
  }

  /// Distance score: 1.0 at 0m, decays to 0.0 at or beyond [referenceDistance].
  double _distanceScore({
    required QualifiedLocation location,
    required double holeLat,
    required double holeLon,
    required double referenceDistance,
  }) {
    final distance = _haversineDistanceMeters(
      location.latitude,
      location.longitude,
      holeLat,
      holeLon,
    );

    if (distance >= referenceDistance) return 0.0;
    if (distance <= 0) return 1.0;

    // Linear decay from 1.0 at 0m to 0.0 at referenceDistance
    return 1.0 - (distance / referenceDistance);
  }

  /// Heading score: 1.0 when aligned with hole direction, 0.0 when opposite.
  /// Requires location heading to be non-null.
  double _headingScore({
    required QualifiedLocation location,
    required double holeDirectionBearing,
  }) {
    final heading = location.heading;
    if (heading == null) return 0.5; // Neutral when no heading available

    // Angular difference between player heading and hole direction
    final diff = (heading - holeDirectionBearing).abs();
    final angularDiff = diff > 180 ? 360 - diff : diff;

    // Score from 1.0 (same direction) to 0.0 (opposite direction)
    return 1.0 - (angularDiff / 180.0);
  }

  /// GPS accuracy score: 1.0 at 0m error, 0.0 at or beyond 20m error.
  double _accuracyScore(double? accuracyMeters) {
    if (accuracyMeters == null) return 0.5; // Neutral when unknown

    const double bestAccuracy = 0.0;
    const double worstAccuracy = 20.0; // 20m error = zero score

    if (accuracyMeters <= bestAccuracy) return 1.0;
    if (accuracyMeters >= worstAccuracy) return 0.0;

    return 1.0 - (accuracyMeters / worstAccuracy);
  }

  /// Haversine distance in meters between two WGS84 points.
  static double _haversineDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double a = 6378137.0; // WGS84 semi-major axis
    const double f = 1 / 298.257223563;
    final b = a * (1 - f);
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final dPhi = (lat2 - lat1) * math.pi / 180;
    final dLambda = (lon2 - lon1) * math.pi / 180;

    final sinPhi = math.sin(dPhi / 2);
    final sinLambda = math.sin(dLambda / 2);

    final x =
        sinPhi * sinPhi +
        math.cos(phi1) * math.cos(phi2) * sinLambda * sinLambda;
    final c = 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));

    return a * c;
  }
}

/// Result of scoring a single hole.
class HoleScore {
  /// The hole geometry that was scored.
  final HoleGeometry holeGeometry;

  /// Confidence score 0.0–1.0.
  final double score;

  const HoleScore({required this.holeGeometry, required this.score});
}
