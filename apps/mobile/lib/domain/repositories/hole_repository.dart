// Hole Repository Interface — VSP Mobile App
//
// Query interface for hole geometry lookup.
// Used by course/hole detection for per-hole scoring.
//
// Hole geometries (tee-box centroids, green centroids, hole direction bearing)
// are consumed by [HoleDetectionScorer] for confidence scoring.
//
// Story 6.2 — Wave A: Interface Definitions

import '../models/hole_data_provenance.dart';

/// Repository interface for hole geometry queries.
abstract class HoleRepository {
  /// Get all holes with geometry for a given course.
  ///
  /// Returns [HoleGeometry] objects containing:
  /// - Tee-box centroid (for distance scoring)
  /// - Green centroid (for distance scoring)
  /// - Hole direction bearing (tee → green, for heading alignment)
  ///
  /// [courseId] — The course to query.
  Future<List<HoleGeometry>> findByCourseWithGeometry(String courseId);

  /// Get a single hole by its ID.
  Future<HoleGeometry?> getById(String holeId);
}

/// Geometry data for a single hole.
///
/// All coordinates are WGS84 (SRID 4326).
/// Centroids are pre-computed for efficient distance queries.
class HoleGeometry {
  /// Hole unique identifier.
  final String id;

  /// Hole number (1–18).
  final int holeNumber;

  /// Par for this hole.
  final int par;

  /// Tee-box centroid latitude.
  final double teeBoxLatitude;

  /// Tee-box centroid longitude.
  final double teeBoxLongitude;

  /// Green centroid latitude.
  final double greenLatitude;

  /// Green centroid longitude.
  final double greenLongitude;

  /// Bearing from tee-box centroid to green centroid in degrees
  /// (clockwise from north, 0–360).
  final double holeDirectionBearing;

  /// Where this hole's tee and green coordinates came from.
  ///
  /// Detection scores a golfer's position against exactly those two points, so
  /// provenance decides whether the answer means anything. Most holes in the
  /// database were generated arithmetically: the tee is the clubhouse pin
  /// nudged along a fixed 0.0008°/0.0006° diagonal and the green sits exactly
  /// `playing_length_meters` due north of it. Scoring against that geometry
  /// does not produce a weak answer — it produces a confident wrong one, hole
  /// after hole, all lined up in a neat diagonal near the car park.
  ///
  /// Defaults to [HoleDataProvenance.unknown], which is not surveyed: a hole
  /// that says nothing about its origin is the case with least reason for
  /// confidence, not most.
  final HoleDataProvenance provenance;

  /// True when these coordinates were obtained by survey, licence or satellite
  /// digitisation *and* somebody verified them.
  bool get isSurveyed => provenance.isSurveyed;

  const HoleGeometry({
    required this.id,
    required this.holeNumber,
    required this.par,
    required this.teeBoxLatitude,
    required this.teeBoxLongitude,
    required this.greenLatitude,
    required this.greenLongitude,
    required this.holeDirectionBearing,
    this.provenance = HoleDataProvenance.unknown,
  });
}
