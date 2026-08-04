// Facility Repository Interface — VSP Mobile App
//
// Spatial query interface for facility (golf club) lookup.
// Used by course/hole detection to find the nearest facility.
//
// Implementation: PostgreSQL/PostGIS with ST_DWithin (story 6.2, Wave B).
//
// Story 6.2 — Wave A: Interface Definitions

/// Repository interface for facility (golf club) spatial queries.
abstract class FacilityRepository {
  /// Find the nearest facility to a given position within a radius.
  ///
  /// Uses PostGIS [ST_DWithin] for index-aware spatial search.
  ///
  /// [latitude] — WGS84 latitude in decimal degrees.
  /// [longitude] — WGS84 longitude in decimal degrees.
  /// [radiusMeters] — Search radius in meters (default 200m per architecture §2.1).
  ///
  /// Returns the nearest facility within the radius, or null if none found.
  Future<FacilitySearchResult?> findNearby({
    required double latitude,
    required double longitude,
    double radiusMeters = 200,
  });

  /// Get a facility by its unique ID.
  Future<FacilitySearchResult?> getById(String facilityId);
}

/// Result of a facility search query.
class FacilitySearchResult {
  /// Facility unique identifier.
  final String id;

  /// Facility display name.
  final String name;

  /// Facility address (optional).
  final String? address;

  /// WGS84 latitude of facility center.
  final double latitude;

  /// WGS84 longitude of facility center.
  final double longitude;

  /// Distance in meters from query point to facility center.
  final double? distanceMeters;

  const FacilitySearchResult({
    required this.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    this.distanceMeters,
  });
}
