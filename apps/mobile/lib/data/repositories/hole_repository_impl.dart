// Hole Repository Implementation — VSP Mobile App
//
// Local course package-backed implementation of HoleRepository.
// Computes tee-box/green centroids and hole direction bearing from GeoJSON geometry.
//
// Story 6.2 — Wave B: Geospatial Query Layer

import 'dart:math' as math;

import 'package:course_package/course_package.dart' as cp;

import '../../domain/repositories/hole_repository.dart';

/// Local course package-backed implementation of HoleRepository.
///
/// Reads hole geometry from GeoJSON features in the course package.
/// Computes tee-box centroid, green centroid, and hole direction bearing
/// for confidence scoring in CourseHoleDetectionService.
class HoleRepositoryImpl implements HoleRepository {
  final cp.CoursePackageRepository _coursePackageRepository;

  HoleRepositoryImpl({cp.CoursePackageRepository? coursePackageRepository})
    : _coursePackageRepository =
          coursePackageRepository ?? cp.LocalCoursePackageRepository();

  @override
  Future<List<HoleGeometry>> findByCourseWithGeometry(String courseId) async {
    // Find the package for this course
    final packages = await _coursePackageRepository.listPackages();
    cp.CoursePackageManifest? matchingPackage;

    for (final pkg in packages) {
      if (pkg.courseId == courseId) {
        matchingPackage = pkg;
        break;
      }
    }

    if (matchingPackage == null) return [];

    final bundle = await _coursePackageRepository.getGeometryBundle(
      matchingPackage.packageId,
      courseId,
    );

    if (bundle == null) return [];

    final results = <HoleGeometry>[];

    for (final entry in bundle.holesByNumber.entries) {
      final holeGeom = entry.value;
      final domainGeom = _toDomainGeometry(holeGeom);
      if (domainGeom != null) {
        results.add(domainGeom);
      }
    }

    // Sort by hole number
    results.sort((a, b) => a.holeNumber.compareTo(b.holeNumber));
    return results;
  }

  @override
  Future<HoleGeometry?> getById(String holeId) async {
    final packages = await _coursePackageRepository.listPackages();

    for (final pkg in packages) {
      final bundle = await _coursePackageRepository.getGeometryBundle(
        pkg.packageId,
        pkg.courseId,
      );

      if (bundle != null) {
        for (final entry in bundle.holesByNumber.entries) {
          if (entry.value.holeId == holeId) {
            return _toDomainGeometry(entry.value);
          }
        }
      }
    }

    return null;
  }

  /// Convert course_package HoleGeometry to domain HoleGeometry.
  ///
  /// Computes:
  /// - Tee-box centroid from tee layer features
  /// - Green centroid from green layer features
  /// - Hole direction bearing from tee centroid to green centroid
  HoleGeometry? _toDomainGeometry(cp.HoleGeometry holeGeom) {
    final teeLayer = holeGeom.layers[cp.GeometryLayerType.tee];
    final greenLayer = holeGeom.layers[cp.GeometryLayerType.green];

    // Compute tee-box centroid
    double? teeLat;
    double? teeLon;
    if (teeLayer != null && teeLayer.features.isNotEmpty) {
      final centroid = _computeCentroid(teeLayer.features);
      if (centroid != null) {
        teeLat = centroid.$1;
        teeLon = centroid.$2;
      }
    }

    // Compute green centroid
    double? greenLat;
    double? greenLon;
    if (greenLayer != null && greenLayer.features.isNotEmpty) {
      final centroid = _computeCentroid(greenLayer.features);
      if (centroid != null) {
        greenLat = centroid.$1;
        greenLon = centroid.$2;
      }
    }

    // If we can't compute centroids, we can't do detection for this hole
    if (teeLat == null ||
        teeLon == null ||
        greenLat == null ||
        greenLon == null) {
      return null;
    }

    // Compute hole direction bearing (tee -> green)
    final bearing = _computeBearing(teeLat, teeLon, greenLat, greenLon);

    return HoleGeometry(
      id: holeGeom.holeId,
      holeNumber: holeGeom.holeNumber,
      par: holeGeom.par,
      teeBoxLatitude: teeLat,
      teeBoxLongitude: teeLon,
      greenLatitude: greenLat,
      greenLongitude: greenLon,
      holeDirectionBearing: bearing,
    );
  }

  /// Compute the centroid of a list of GeoJSON features.
  /// Returns (latitude, longitude).
  ///
  /// For Point features: uses the point coordinates directly.
  /// For Polygon features: uses the centroid of the polygon.
  /// For MultiPolygon features: uses the centroid of the first polygon.
  (double, double)? _computeCentroid(List<cp.GeometryFeature> features) {
    if (features.isEmpty) return null;

    double totalLat = 0;
    double totalLon = 0;
    int count = 0;

    for (final feature in features) {
      final geometry = feature.geometry;
      final type = geometry['type'] as String?;

      if (type == 'Point') {
        final coords = geometry['coordinates'] as List<dynamic>;
        if (coords.length >= 2) {
          // GeoJSON is [lon, lat] - swap to lat, lon
          totalLon += (coords[0] as num).toDouble();
          totalLat += (coords[1] as num).toDouble();
          count++;
        }
      } else if (type == 'Polygon') {
        final coords = geometry['coordinates'] as List<dynamic>;
        if (coords.isNotEmpty && coords[0] is List) {
          final ring = coords[0] as List<dynamic>;
          for (final point in ring) {
            if (point is List && point.length >= 2) {
              totalLon += (point[0] as num).toDouble();
              totalLat += (point[1] as num).toDouble();
              count++;
            }
          }
        }
      } else if (type == 'MultiPolygon') {
        final coords = geometry['coordinates'] as List<dynamic>;
        if (coords.isNotEmpty && coords[0] is List) {
          final poly = coords[0] as List<dynamic>;
          if (poly.isNotEmpty && poly[0] is List) {
            final ring = poly[0] as List<dynamic>;
            for (final point in ring) {
              if (point is List && point.length >= 2) {
                totalLon += (point[0] as num).toDouble();
                totalLat += (point[1] as num).toDouble();
                count++;
              }
            }
          }
        }
      }
      // Other geometry types (LineString, etc.) are not used for centroid
    }

    if (count == 0) return null;
    return (totalLat / count, totalLon / count);
  }

  /// Compute bearing from point 1 to point 2 in degrees (clockwise from north).
  double _computeBearing(double lat1, double lon1, double lat2, double lon2) {
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final dLambda = (lon2 - lon1) * math.pi / 180;

    final x = math.sin(dLambda) * math.cos(phi2);
    final y =
        math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLambda);

    final theta = math.atan2(x, y);
    final bearing = (theta * 180 / math.pi + 360) % 360;

    return bearing;
  }
}
