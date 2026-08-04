// Course Repository Interface — VSP Mobile App
//
// Query interface for course lookup within a facility.
// Used by course/hole detection to find the active course.
//
// Story 6.2 — Wave A: Interface Definitions

/// Repository interface for course queries.
abstract class CourseRepository {
  /// Get all courses at a facility.
  ///
  /// [facilityId] — The facility to query.
  ///
  /// Returns courses ordered by name.
  Future<List<CourseSearchResult>> findWithinFacility(String facilityId);

  /// Get a course by its unique ID.
  Future<CourseSearchResult?> getById(String courseId);
}

/// Result of a course search query.
class CourseSearchResult {
  /// Course unique identifier.
  final String id;

  /// Course display name.
  final String name;

  /// Number of holes (9 or 18).
  final int holeCount;

  /// Course par total.
  final int? par;

  const CourseSearchResult({
    required this.id,
    required this.name,
    required this.holeCount,
    this.par,
  });
}
