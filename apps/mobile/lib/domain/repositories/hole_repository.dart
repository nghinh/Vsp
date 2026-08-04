// Hole Repository Interface — VSP Mobile App
//
// Query interface for hole geometry lookup.
// Used by course/hole detection for per-hole scoring.
//
// Hole geometries (tee-box centroids, green centroids, hole direction bearing)
// are consumed by [HoleDetectionScorer] for confidence scoring.
//
// Story 6.2 — Wave A: Interface Definitions

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

  const HoleGeometry({
    required this.id,
    required this.holeNumber,
    required this.par,
    required this.teeBoxLatitude,
    required this.teeBoxLongitude,
    required this.greenLatitude,
    required this.greenLongitude,
    required this.holeDirectionBearing,
  });
}
