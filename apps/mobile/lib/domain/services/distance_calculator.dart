// Distance Calculator Service — VSP Mobile App
//
// Core calculation engine for all golf distances.
// Uses Haversine for point-to-point distances.
// Uses perpendicular polygon-edge distance for front/center/back green.
// Uses polygon intersection for carry distances.
//
// Story 6.4 — Wave 1: Domain & Calculation Engine

import 'dart:math' as math;

import '../models/hazard_geometry.dart';
import '../models/hole_geometry.dart';
import '../value_objects/distance_measurement.dart';
import '../value_objects/distance_type.dart';
import '../value_objects/lat_lng.dart';

/// Service for calculating golf distances from GPS position to course features.
class DistanceCalculator {
  /// Maximum reasonable golf distance in meters (drive + full iron).
  static const double _maxGolfDistanceMeters = 400.0;

  /// Small epsilon for floating-point comparison.
  static const double _epsilon = 1e-6;

  // ─── Green distances ─────────────────────────────────────────────────────────

  /// Calculate all green distances from [golferPosition] to [hole].
  ///
  /// Returns a map of DistanceType → DistanceMeasurement.
  /// Uses perpendicular polygon-edge distance for front green,
  /// minimum straight-line for center, maximum straight-line for back.
  Map<DistanceType, DistanceMeasurement> calculateGreenDistances({
    required LatLng golferPosition,
    required HoleGeometry hole,
    required double gpsAccuracyMeters,
    required DateTime timestamp,
    DistanceSource source = DistanceSource.official,
  }) {
    if (!hole.hasValidGreen) {
      return {};
    }

    final green = hole.greenPolygon;

    // Front green: minimum PERPENDICULAR distance to polygon edge
    final frontGreen = _perpendicularDistanceToPolygonEdge(
      golferPosition,
      green,
    );

    // Center green: minimum straight-line distance to any polygon vertex/edge
    final centerGreen = _minimumDistanceToPolygon(golferPosition, green);

    // Back green: maximum straight-line distance to any polygon vertex
    final backGreen = _maximumDistanceToPolygon(golferPosition, green);

    // Pin distance: straight-line to pin position
    final pinDistance = golferPosition.distanceTo(hole.pinPosition);

    return {
      DistanceType.frontGreen: _makeMeasurement(
        meters: frontGreen,
        type: DistanceType.frontGreen,
        gpsAccuracyMeters: gpsAccuracyMeters,
        timestamp: timestamp,
        source: source,
        confidence: _greenConfidence(frontGreen, gpsAccuracyMeters),
      ),
      DistanceType.centerGreen: _makeMeasurement(
        meters: centerGreen,
        type: DistanceType.centerGreen,
        gpsAccuracyMeters: gpsAccuracyMeters,
        timestamp: timestamp,
        source: source,
        confidence: _greenConfidence(centerGreen, gpsAccuracyMeters),
      ),
      DistanceType.backGreen: _makeMeasurement(
        meters: backGreen,
        type: DistanceType.backGreen,
        gpsAccuracyMeters: gpsAccuracyMeters,
        timestamp: timestamp,
        source: source,
        confidence: _greenConfidence(backGreen, gpsAccuracyMeters),
      ),
      DistanceType.pin: _makeMeasurement(
        meters: pinDistance,
        type: DistanceType.pin,
        gpsAccuracyMeters: gpsAccuracyMeters,
        timestamp: timestamp,
        source: source,
        confidence: _pinConfidence(pinDistance, gpsAccuracyMeters),
      ),
    };
  }

  // ─── Hazard distances ────────────────────────────────────────────────────────

  /// Calculate all hazard distances from [golferPosition] to [hazards].
  ///
  /// Returns near/far for each hazard, and carry if applicable.
  Map<String, Map<DistanceType, DistanceMeasurement>> calculateHazardDistances({
    required LatLng golferPosition,
    required List<HazardGeometry> hazards,
    required double gpsAccuracyMeters,
    required DateTime timestamp,
    required HoleGeometry hole,
    DistanceSource source = DistanceSource.official,
  }) {
    final result = <String, Map<DistanceType, DistanceMeasurement>>{};

    for (final hazard in hazards) {
      final hazardDistances = <DistanceType, DistanceMeasurement>{};

      // Near: minimum straight-line distance to hazard polygon
      final nearDist = _minimumDistanceToPolygon(
        golferPosition,
        hazard.polygon,
      );
      hazardDistances[_nearType(hazard)] = _makeMeasurement(
        meters: nearDist,
        type: _nearType(hazard),
        gpsAccuracyMeters: gpsAccuracyMeters,
        timestamp: timestamp,
        source: source,
        confidence: _hazardConfidence(nearDist, gpsAccuracyMeters),
      );

      // Far: maximum straight-line distance to hazard polygon
      final farDist = _maximumDistanceToPolygon(golferPosition, hazard.polygon);
      hazardDistances[_farType(hazard)] = _makeMeasurement(
        meters: farDist,
        type: _farType(hazard),
        gpsAccuracyMeters: gpsAccuracyMeters,
        timestamp: timestamp,
        source: source,
        confidence: _hazardConfidence(farDist, gpsAccuracyMeters),
      );

      // Carry: distance from golfer through hazard to green boundary intersection
      if (hole.hasValidGreen && (hazard.isBunker || hazard.isWater)) {
        final carryDist = _calculateCarryDistance(
          golferPosition,
          hazard.polygon,
          hole.greenPolygon,
        );
        if (carryDist != null) {
          hazardDistances[_carryType(hazard)] = _makeMeasurement(
            meters: carryDist,
            type: _carryType(hazard),
            gpsAccuracyMeters: gpsAccuracyMeters,
            timestamp: timestamp,
            source: source,
            confidence: _hazardConfidence(carryDist, gpsAccuracyMeters),
          );
        }
      }

      result[hazard.id] = hazardDistances;
    }

    return result;
  }

  // ─── OB distances ────────────────────────────────────────────────────────────

  /// Calculate minimum distance to any OB area.
  DistanceMeasurement? calculateObDistance({
    required LatLng golferPosition,
    required List<List<LatLng>> obAreas,
    required double gpsAccuracyMeters,
    required DateTime timestamp,
    DistanceSource source = DistanceSource.official,
  }) {
    if (obAreas.isEmpty) return null;

    double minDist = double.infinity;
    for (final obArea in obAreas) {
      final dist = _minimumDistanceToPolygon(golferPosition, obArea);
      if (dist < minDist) minDist = dist;
    }

    if (minDist == double.infinity) return null;

    return _makeMeasurement(
      meters: minDist,
      type: DistanceType.ob,
      gpsAccuracyMeters: gpsAccuracyMeters,
      timestamp: timestamp,
      source: source,
      confidence: _hazardConfidence(minDist, gpsAccuracyMeters),
    );
  }

  // ─── Strategic distances ─────────────────────────────────────────────────────

  /// Calculate dogleg distance — distance to the furthest bend in the fairway centerline.
  DistanceMeasurement? calculateDoglegDistance({
    required LatLng golferPosition,
    required List<LatLng> fairwayCenterline,
    required double gpsAccuracyMeters,
    required DateTime timestamp,
    DistanceSource source = DistanceSource.estimated,
  }) {
    if (fairwayCenterline.length < 2) return null;

    // Find the point on the centerline furthest from the direct tee-to-green line
    if (fairwayCenterline.length < 2) return null;

    final tee = fairwayCenterline.first;
    final green = fairwayCenterline.last;

    double maxOffset = 0;
    double maxOffsetDist = 0;

    for (int i = 1; i < fairwayCenterline.length - 1; i++) {
      final point = fairwayCenterline[i];
      // Distance from point to direct line between tee and green
      final offset = _perpendicularDistanceToLine(tee, green, point);
      if (offset > maxOffset) {
        maxOffset = offset;
        maxOffsetDist = golferPosition.distanceTo(point);
      }
    }

    if (maxOffset < 10) return null; // No significant dogleg

    return _makeMeasurement(
      meters: maxOffsetDist,
      type: DistanceType.dogleg,
      gpsAccuracyMeters: gpsAccuracyMeters,
      timestamp: timestamp,
      source: source,
      confidence: 0.6,
    );
  }

  /// Calculate layup distance — recommended distance before a hazard.
  DistanceMeasurement? calculateLayupDistance({
    required LatLng golferPosition,
    required List<HazardGeometry> hazards,
    required List<LatLng> fairwayCenterline,
    required double gpsAccuracyMeters,
    required DateTime timestamp,
    DistanceSource source = DistanceSource.estimated,
  }) {
    // Find the first significant hazard on the hole
    for (final hazard in hazards) {
      if (hazard.isBunker || hazard.isWater) {
        // Distance to the near edge of the hazard
        final nearDist = _minimumDistanceToPolygon(
          golferPosition,
          hazard.polygon,
        );

        // Recommend a layup ~20 yards short of the hazard
        const layupShortfallMeters = 18.0; // ~20 yards
        final layupDist = math.max(0.0, nearDist - layupShortfallMeters);

        return _makeMeasurement(
          meters: layupDist,
          type: DistanceType.layup,
          gpsAccuracyMeters: gpsAccuracyMeters,
          timestamp: timestamp,
          source: source,
          confidence: 0.5,
        );
      }
    }
    return null;
  }

  // ─── Target distances ────────────────────────────────────────────────────────

  /// Calculate ball-to-target distance.
  DistanceMeasurement calculateTargetDistance({
    required LatLng golferPosition,
    required LatLng targetPosition,
    required double gpsAccuracyMeters,
    required DateTime timestamp,
    DistanceSource source = DistanceSource.official,
  }) {
    return _makeMeasurement(
      meters: golferPosition.distanceTo(targetPosition),
      type: DistanceType.target,
      gpsAccuracyMeters: gpsAccuracyMeters,
      timestamp: timestamp,
      source: source,
      confidence: _pinConfidence(
        golferPosition.distanceTo(targetPosition),
        gpsAccuracyMeters,
      ),
    );
  }

  /// Calculate target-to-pin distance.
  DistanceMeasurement calculateTargetToPinDistance({
    required LatLng targetPosition,
    required LatLng pinPosition,
    required double gpsAccuracyMeters,
    required DateTime timestamp,
    DistanceSource source = DistanceSource.official,
  }) {
    return _makeMeasurement(
      meters: targetPosition.distanceTo(pinPosition),
      type: DistanceType.targetToPin,
      gpsAccuracyMeters: gpsAccuracyMeters,
      timestamp: timestamp,
      source: source,
      confidence: 0.95,
    );
  }

  // ─── Polygon distance algorithms ─────────────────────────────────────────────

  /// Minimum straight-line distance from [point] to any vertex or edge of [polygon].
  static double _minimumDistanceToPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return double.infinity;

    double minDist = double.infinity;

    // Check distance to each vertex
    for (final vertex in polygon) {
      final d = point.distanceTo(vertex);
      if (d < minDist) minDist = d;
    }

    // Check distance to each edge
    for (int i = 0; i < polygon.length - 1; i++) {
      final d = _pointToSegmentDistance(point, polygon[i], polygon[i + 1]);
      if (d < minDist) minDist = d;
    }

    return minDist;
  }

  /// Maximum straight-line distance from [point] to any vertex of [polygon].
  static double _maximumDistanceToPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.isEmpty) return 0;

    double maxDist = 0;
    for (final vertex in polygon) {
      final d = point.distanceTo(vertex);
      if (d > maxDist) maxDist = d;
    }
    return maxDist;
  }

  /// Perpendicular distance from [point] to the nearest edge of [polygon].
  ///
  /// This is the "front green" distance — how far the golfer is from
  /// the front edge of the green (perpendicular to the nearest edge).
  static double _perpendicularDistanceToPolygonEdge(
    LatLng point,
    List<LatLng> polygon,
  ) {
    if (polygon.length < 3) return double.infinity;

    double minPerpDist = double.infinity;
    LatLng? nearestPoint;

    for (int i = 0; i < polygon.length - 1; i++) {
      final a = polygon[i];
      final b = polygon[i + 1];

      final proj = _projectPointOntoSegment(point, a, b);
      if (proj != null) {
        final perpDist = point.distanceTo(proj);
        if (perpDist < minPerpDist) {
          minPerpDist = perpDist;
          nearestPoint = proj;
        }
      }
    }

    // Also check first and last vertex connection
    if (polygon.length >= 2) {
      final last = polygon.last;
      final first = polygon.first;
      final proj = _projectPointOntoSegment(point, last, first);
      if (proj != null) {
        final perpDist = point.distanceTo(proj);
        if (perpDist < minPerpDist) {
          minPerpDist = perpDist;
          nearestPoint = proj;
        }
      }
    }

    return minPerpDist;
  }

  /// Project [point] onto the segment [a]–[b], returning the closest point
  /// or null if projection falls outside the segment.
  static LatLng? _projectPointOntoSegment(LatLng point, LatLng a, LatLng b) {
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;

    if (dx.abs() < _epsilon && dy.abs() < _epsilon) {
      return a; // Segment is a point
    }

    final t = math.max(
      0,
      math.min(
        1,
        ((point.longitude - a.longitude) * dx +
                (point.latitude - a.latitude) * dy) /
            (dx * dx + dy * dy),
      ),
    );

    return LatLng(
      latitude: a.latitude + t * dy,
      longitude: a.longitude + t * dx,
    );
  }

  /// Minimum distance from [point] to line segment [a]–[b].
  static double _pointToSegmentDistance(LatLng point, LatLng a, LatLng b) {
    final proj = _projectPointOntoSegment(point, a, b);
    if (proj != null) {
      return point.distanceTo(proj);
    }
    // Falls back to vertex distance
    return math.min(point.distanceTo(a), point.distanceTo(b));
  }

  /// Perpendicular distance from [point] to the infinite line through [a] and [b].
  static double _perpendicularDistanceToLine(LatLng a, LatLng b, LatLng point) {
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < _epsilon) return point.distanceTo(a);
    return ((dy * point.longitude -
                dx * point.latitude +
                b.longitude * a.latitude -
                b.latitude * a.longitude)
            .abs()) /
        len;
  }

  // ─── Carry distance ─────────────────────────────────────────────────────────

  /// Calculate carry distance: from [golferPosition] through [hazardPolygon]
  /// to the first intersection with [greenPolygon].
  ///
  /// Returns null if no carry is applicable (hazard is not between golfer and green).
  static double? _calculateCarryDistance(
    LatLng golferPosition,
    List<LatLng> hazardPolygon,
    List<LatLng> greenPolygon,
  ) {
    if (hazardPolygon.length < 3 || greenPolygon.length < 3) return null;

    // Find the direction from golfer to green center
    final greenCenter = _polygonCentroid(greenPolygon);
    final dirToGreen = LatLng(
      latitude: greenCenter.latitude - golferPosition.latitude,
      longitude: greenCenter.longitude - golferPosition.longitude,
    );

    // Check if hazard is in the direction of the green
    final hazardDist = _minimumDistanceToPolygon(golferPosition, hazardPolygon);
    final greenDist = _minimumDistanceToPolygon(golferPosition, greenPolygon);

    if (hazardDist >= greenDist) return null; // Hazard is beyond green

    // Simple carry approximation: distance from golfer to hazard near edge
    // + distance from hazard far edge to green
    final hazardNear = _minimumDistanceToPolygon(golferPosition, hazardPolygon);
    final hazardFar = _maximumDistanceToPolygon(golferPosition, hazardPolygon);

    // Carry = distance through hazard = hazard far - hazard near (simplified)
    // More accurate: find intersection points through hazard polygon
    // For now: use a conservative estimate
    final carryApprox = hazardFar - hazardNear * 0.5;
    return carryApprox.clamp(0, _maxGolfDistanceMeters);
  }

  /// Centroid of a polygon.
  static LatLng _polygonCentroid(List<LatLng> polygon) {
    if (polygon.isEmpty) {
      return const LatLng(latitude: 0, longitude: 0);
    }
    double sumLat = 0;
    double sumLon = 0;
    for (final p in polygon) {
      sumLat += p.latitude;
      sumLon += p.longitude;
    }
    return LatLng(
      latitude: sumLat / polygon.length,
      longitude: sumLon / polygon.length,
    );
  }

  // ─── Confidence scoring ────────────────────────────────────────────────────

  /// Compute confidence for green distances.
  static double _greenConfidence(
    double distanceMeters,
    double gpsAccuracyMeters,
  ) {
    // Base confidence from GPS accuracy
    final gpsFactor = 1.0 - (gpsAccuracyMeters / 20.0).clamp(0.0, 0.9);

    // Distance also affects confidence (closer = more confident)
    final distanceFactor = distanceMeters < 200
        ? 1.0
        : math.max(0.5, 1.0 - (distanceMeters - 200) / 400.0);

    return (gpsFactor * 0.6 + distanceFactor * 0.4).clamp(0.1, 1.0);
  }

  /// Compute confidence for pin distances.
  static double _pinConfidence(
    double distanceMeters,
    double gpsAccuracyMeters,
  ) {
    final gpsFactor = 1.0 - (gpsAccuracyMeters / 15.0).clamp(0.0, 0.9);
    return gpsFactor.clamp(0.1, 1.0);
  }

  /// Compute confidence for hazard distances.
  static double _hazardConfidence(
    double distanceMeters,
    double gpsAccuracyMeters,
  ) {
    final gpsFactor = 1.0 - (gpsAccuracyMeters / 25.0).clamp(0.0, 0.85);
    return gpsFactor.clamp(0.1, 1.0);
  }

  // ─── Helper methods ────────────────────────────────────────────────────────

  static DistanceMeasurement _makeMeasurement({
    required double meters,
    required DistanceType type,
    required double gpsAccuracyMeters,
    required DateTime timestamp,
    required DistanceSource source,
    required double confidence,
  }) {
    return DistanceMeasurement(
      valueMeters: meters.clamp(0, _maxGolfDistanceMeters),
      type: type,
      source: source,
      timestamp: timestamp,
      gpsAccuracyMeters: gpsAccuracyMeters,
      confidence: confidence,
    );
  }

  static DistanceType _nearType(HazardGeometry hazard) {
    switch (hazard.type) {
      case HazardType.bunker:
        return DistanceType.bunkerNear;
      case HazardType.water:
      case HazardType.penaltyArea:
        return DistanceType.waterNear;
      case HazardType.ob:
        return DistanceType.ob;
    }
  }

  static DistanceType _farType(HazardGeometry hazard) {
    switch (hazard.type) {
      case HazardType.bunker:
        return DistanceType.bunkerFar;
      case HazardType.water:
      case HazardType.penaltyArea:
        return DistanceType.waterFar;
      case HazardType.ob:
        return DistanceType.ob;
    }
  }

  static DistanceType _carryType(HazardGeometry hazard) {
    switch (hazard.type) {
      case HazardType.bunker:
        return DistanceType.bunkerCarry;
      case HazardType.water:
      case HazardType.penaltyArea:
        return DistanceType.waterCarry;
      case HazardType.ob:
        return DistanceType.ob;
    }
  }
}
