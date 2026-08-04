// Facility Repository Implementation — VSP Mobile App
//
// Local course package-backed implementation of FacilityRepository.
// Uses the CoursePackageRepository for offline-first geospatial queries.
//
// Data source: downloaded course packages in app documents directory.
// Spatial queries use Haversine distance for proximity ranking.
//
// Story 6.2 — Wave B: Geospatial Query Layer

import 'dart:math' as math;

import 'package:course_package/course_package.dart';

import '../../domain/repositories/facility_repository.dart';

/// SQLite-backed implementation of FacilityRepository.
///
/// Queries local course packages for facility data.
/// Used by CourseHoleDetectionService to find the nearest facility
/// within a search radius.
class FacilityRepositoryImpl implements FacilityRepository {
  final CoursePackageRepository _coursePackageRepository;

  FacilityRepositoryImpl({CoursePackageRepository? coursePackageRepository})
    : _coursePackageRepository =
          coursePackageRepository ?? LocalCoursePackageRepository();

  @override
  Future<FacilitySearchResult?> findNearby({
    required double latitude,
    required double longitude,
    double radiusMeters = 200,
  }) async {
    final packages = await _coursePackageRepository.listPackages();

    FacilitySearchResult? nearest;
    double nearestDistance = double.infinity;

    for (final manifest in packages) {
      // Skip packages that don't have location data
      final facilityLat = manifest.facilityLatitude;
      final facilityLon = manifest.facilityLongitude;
      if (facilityLat == null || facilityLon == null) continue;

      final distance = _haversineDistanceMeters(
        latitude,
        longitude,
        facilityLat,
        facilityLon,
      );

      // Only consider facilities within the search radius
      if (distance <= radiusMeters && distance < nearestDistance) {
        nearestDistance = distance;
        nearest = FacilitySearchResult(
          id: manifest.facilityId ?? manifest.courseId,
          name: manifest.facilityName ?? manifest.courseId,
          address: manifest.facilityAddress,
          latitude: facilityLat,
          longitude: facilityLon,
          distanceMeters: distance,
        );
      }
    }

    return nearest;
  }

  @override
  Future<FacilitySearchResult?> getById(String facilityId) async {
    final packages = await _coursePackageRepository.listPackages();

    for (final manifest in packages) {
      if (manifest.facilityId == facilityId) {
        return FacilitySearchResult(
          id: manifest.facilityId ?? manifest.courseId,
          name: manifest.facilityName ?? manifest.courseId,
          address: manifest.facilityAddress,
          latitude: manifest.facilityLatitude ?? 0,
          longitude: manifest.facilityLongitude ?? 0,
          distanceMeters: null,
        );
      }
    }

    return null;
  }

  /// Haversine distance in meters between two WGS84 points.
  double _haversineDistanceMeters(
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
