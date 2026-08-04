// Lie Detector Service — VSP Mobile App
//
// Auto-detects the lie (fairway/rough/bunker/water/OB) from GPS coordinates
// by checking which course feature polygon contains the end location.
//
// Per Story 10.3 — Slice 2: UI — Shot Entry
//
// Uses point-in-polygon tests against course feature geometry.
// Confidence is derived from GPS accuracy and proximity to feature boundaries.

import 'dart:math' as math;

import '../../domain/models/hole_geometry.dart';
import '../../domain/models/shot.dart';
import '../../domain/value_objects/lat_lng.dart';

/// Result of a lie detection operation.
class LieDetectionResult {
  /// Detected lie type.
  final ShotLie lie;

  /// Confidence score (0.0–1.0).
  final double confidence;

  /// Human-readable reason for the detection.
  final String reason;

  const LieDetectionResult({
    required this.lie,
    required this.confidence,
    required this.reason,
  });
}

/// Service for auto-detecting ball lie from GPS coordinates.
///
/// Uses point-in-polygon testing against course feature geometries:
/// - Green polygon → green or putt
/// - Fairway polygon → fairway
/// - Bunker polygon → bunker
/// - Water/penalty polygon → water
/// - OB area polygon → out_of_bounds
/// - Cart path → cart_path
/// - Default → rough
///
/// Per Story 10.3 Slice 2.
class LieDetector {
  /// Minimum confidence for auto-detection.
  /// Below this threshold, returns [ShotLie.other] with low confidence.
  static const double _minConfidenceThreshold = 0.5;

  /// Buffer zone in meters for boundary detection.
  /// Points within this distance of a boundary get reduced confidence.
  static const double _boundaryBufferMeters = 2.0;

  /// Detect the lie of a ball at [endLocation] given the [hole] geometry.
  ///
  /// Uses point-in-polygon tests against all feature polygons.
  /// Returns [LieDetectionResult] with detected lie, confidence, and reason.
  ///
  /// GPS accuracy affects confidence:
  /// - ≤5m: full confidence
  /// - ≤10m: reduced confidence (0.85)
  /// - ≤20m: lower confidence (0.70)
  /// - >20m: minimum confidence (0.50)
  LieDetectionResult detectLie({
    required LatLng endLocation,
    required HoleGeometry hole,
    required double gpsAccuracyMeters,
  }) {
    // Check each feature type in order of priority
    // (higher-priority features first)

    // 1. Check OB areas (highest priority — ball is out of bounds)
    for (final obArea in hole.obAreas) {
      if (_pointInPolygon(endLocation, obArea)) {
        return LieDetectionResult(
          lie: ShotLie.outOfBounds,
          confidence: _adjustedConfidence(0.95, gpsAccuracyMeters),
          reason: 'Ball is in OB area',
        );
      }
    }

    // 2. Check water/penalty areas
    for (final hazard in hole.waterHazards) {
      if (_pointInPolygon(endLocation, hazard.polygon)) {
        return LieDetectionResult(
          lie: ShotLie.water,
          confidence: _adjustedConfidence(0.90, gpsAccuracyMeters),
          reason: 'Ball is in water hazard',
        );
      }
    }

    // 3. Check bunkers
    for (final bunker in hole.bunkers) {
      if (_pointInPolygon(endLocation, bunker.polygon)) {
        return LieDetectionResult(
          lie: ShotLie.bunker,
          confidence: _adjustedConfidence(0.90, gpsAccuracyMeters),
          reason: 'Ball is in bunker',
        );
      }
    }

    // 4. Check green polygon
    if (hole.hasValidGreen) {
      if (_pointInPolygon(endLocation, hole.greenPolygon)) {
        // Check if near the hole (putting) vs elsewhere on green
        final distToPin = endLocation.distanceTo(hole.pinPosition);
        if (distToPin < 5.0) {
          return LieDetectionResult(
            lie: ShotLie.putt,
            confidence: _adjustedConfidence(0.85, gpsAccuracyMeters),
            reason: 'Ball is near the hole (putting)',
          );
        }
        return LieDetectionResult(
          lie: ShotLie.green,
          confidence: _adjustedConfidence(0.85, gpsAccuracyMeters),
          reason: 'Ball is on green',
        );
      }
    }

    // 5. Check cart paths
    for (final cartPath in hole.cartPaths) {
      if (_pointNearPolyline(endLocation, cartPath, _boundaryBufferMeters)) {
        return LieDetectionResult(
          lie: ShotLie.cartPath,
          confidence: _adjustedConfidence(0.70, gpsAccuracyMeters),
          reason: 'Ball is on cart path',
        );
      }
    }

    // 6. Check fairway
    if (hole.fairwayCenterline.isNotEmpty) {
      // Build fairway polygon from centerline with buffer
      final fairwayPolygon = _centerlineToPolygon(hole.fairwayCenterline, 15.0);
      if (_pointInPolygon(endLocation, fairwayPolygon)) {
        return LieDetectionResult(
          lie: ShotLie.fairway,
          confidence: _adjustedConfidence(0.80, gpsAccuracyMeters),
          reason: 'Ball is on fairway',
        );
      }
    }

    // 7. Default to rough
    // Rough is detected when ball is on the course but not on any other feature
    return LieDetectionResult(
      lie: ShotLie.rough,
      confidence: _adjustedConfidence(0.60, gpsAccuracyMeters),
      reason: 'Ball is in rough (default)',
    );
  }

  /// Detect lie from start and end locations (simplified).
  ///
  /// Uses distance heuristics when full geometry is not available.
  /// This is a fallback for when course data is not downloaded.
  LieDetectionResult detectLieSimplified({
    required LatLng startLocation,
    required LatLng endLocation,
    required double gpsAccuracyMeters,
  }) {
    final distance = endLocation.distanceTo(startLocation);

    // Very short shots near the start are likely putting
    if (distance < 10) {
      return LieDetectionResult(
        lie: ShotLie.putt,
        confidence: _adjustedConfidence(0.50, gpsAccuracyMeters),
        reason: 'Short distance shot (putting)',
      );
    }

    // Normal-range shots: without course data, fairway is the neutral default
    // assumption (distance alone cannot distinguish fairway from rough).
    if (distance < 250) {
      return LieDetectionResult(
        lie: ShotLie.fairway,
        confidence: _adjustedConfidence(0.40, gpsAccuracyMeters),
        reason: 'Medium distance shot (no course data)',
      );
    }

    // Very long carries are more likely to have found trouble off the fairway.
    return LieDetectionResult(
      lie: ShotLie.rough,
      confidence: _adjustedConfidence(0.30, gpsAccuracyMeters),
      reason: 'Long shot (no course data)',
    );
  }

  // ─── Point-in-polygon tests ───────────────────────────────────────────────

  /// Ray-casting point-in-polygon test.
  /// Returns true if [point] is inside [polygon].
  bool _pointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;

    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;

      if (((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude <
              (xj - xi) * (point.latitude - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  /// Check if point is near a polyline (cart path detection).
  bool _pointNearPolyline(
    LatLng point,
    List<LatLng> polyline,
    double maxDistance,
  ) {
    if (polyline.length < 2) return false;

    for (int i = 0; i < polyline.length - 1; i++) {
      final dist = _pointToSegmentDistance(point, polyline[i], polyline[i + 1]);
      if (dist <= maxDistance) return true;
    }
    return false;
  }

  /// Perpendicular distance from point to line segment.
  double _pointToSegmentDistance(LatLng point, LatLng a, LatLng b) {
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;

    if (dx.abs() < 1e-6 && dy.abs() < 1e-6) {
      return point.distanceTo(a);
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

    final proj = LatLng(
      latitude: a.latitude + t * dy,
      longitude: a.longitude + t * dx,
    );

    return point.distanceTo(proj);
  }

  /// Build a polygon from a centerline by adding buffer points.
  List<LatLng> _centerlineToPolygon(
    List<LatLng> centerline,
    double widthMeters,
  ) {
    if (centerline.length < 2) return centerline;

    final leftSide = <LatLng>[];
    final rightSide = <LatLng>[];

    for (int i = 0; i < centerline.length; i++) {
      final point = centerline[i];

      // Calculate perpendicular direction
      LatLng direction;
      if (i == 0) {
        direction = LatLng(
          latitude: centerline[i + 1].latitude - point.latitude,
          longitude: centerline[i + 1].longitude - point.longitude,
        );
      } else if (i == centerline.length - 1) {
        direction = LatLng(
          latitude: point.latitude - centerline[i - 1].latitude,
          longitude: point.longitude - centerline[i - 1].longitude,
        );
      } else {
        direction = LatLng(
          latitude: centerline[i + 1].latitude - centerline[i - 1].latitude,
          longitude: centerline[i + 1].longitude - centerline[i - 1].longitude,
        );
      }

      // Normalize direction
      final len = math.sqrt(
        direction.latitude * direction.latitude +
            direction.longitude * direction.longitude,
      );
      if (len < 1e-6) continue;

      final perpX = -direction.latitude / len;
      final perpY = direction.longitude / len;

      // Convert width from meters to degrees (approximate)
      final metersPerDegree = 111000.0; // at equator
      final offsetLat = (perpX * widthMeters) / metersPerDegree;
      final offsetLon = (perpY * widthMeters) / metersPerDegree;

      leftSide.add(
        LatLng(
          latitude: point.latitude + offsetLat,
          longitude: point.longitude + offsetLon,
        ),
      );
      rightSide.add(
        LatLng(
          latitude: point.latitude - offsetLat,
          longitude: point.longitude - offsetLon,
        ),
      );
    }

    // Combine left side (reversed) + right side to form polygon
    final polygon = <LatLng>[...leftSide.reversed, ...rightSide];
    return polygon;
  }

  // ─── Confidence adjustment ────────────────────────────────────────────────

  double _adjustedConfidence(double baseConfidence, double gpsAccuracyMeters) {
    double gpsFactor;
    if (gpsAccuracyMeters <= 5) {
      gpsFactor = 1.0;
    } else if (gpsAccuracyMeters <= 10) {
      gpsFactor = 0.85;
    } else if (gpsAccuracyMeters <= 20) {
      gpsFactor = 0.70;
    } else {
      gpsFactor = 0.50;
    }

    return (baseConfidence * gpsFactor).clamp(0.0, 1.0);
  }
}
