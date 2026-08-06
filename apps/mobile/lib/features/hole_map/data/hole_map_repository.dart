// HoleMapRepository — VSP Mobile App
//
// Application-level repository wrapping LocalCoursePackageRepository.
// Provides hole map data to the presentation layer, including geometry
// layers, pin positions, and course metadata.

import 'package:course_package/course_package.dart';

import '../domain/hole_map_entity.dart';
import '../domain/map_layer.dart';
import 'hole_geometry_dto.dart';

/// Repository that provides hole map data from local course packages.
abstract class HoleMapRepository {
  /// Loads the full hole map entity for a specific hole.
  Future<HoleMapEntity?> getHoleMap({
    required String packageId,
    required String courseId,
    required String courseName,
    required int holeNumber,
  });

  /// Returns the geometry bundle for a course (for preloading).
  Future<CourseGeometryBundle?> getGeometryBundle({
    required String packageId,
    required String courseId,
  });

  /// Lists all downloaded course packages.
  Future<List<CoursePackageManifest>> listPackages();
}

/// Implementation that reads from locally stored course packages.
class LocalHoleMapRepository implements HoleMapRepository {
  final LocalCoursePackageRepository _packageRepo;

  LocalHoleMapRepository({LocalCoursePackageRepository? packageRepo})
    : _packageRepo = packageRepo ?? LocalCoursePackageRepository();

  @override
  Future<HoleMapEntity?> getHoleMap({
    required String packageId,
    required String courseId,
    required String courseName,
    required int holeNumber,
  }) async {
    final geom = await _packageRepo.getHoleGeometry(
      packageId,
      courseId,
      holeNumber,
    );
    if (geom == null) return null;

    final dto = HoleGeometryDto.fromHoleGeometry(geom, courseName: courseName);

    // Build domain layers map
    final domainLayers = <MapLayerType, MapLayerEntity>{};
    for (final entry in dto.layers.entries) {
      domainLayers[entry.key] = entry.value;
    }

    return HoleMapEntity(
      courseId: dto.courseId,
      courseName: courseName,
      holeNumber: dto.holeNumber,
      par: dto.par,
      yardage: dto.yardage,
      layers: domainLayers,
      provenance: dto.provenance,
    );
  }

  @override
  Future<CourseGeometryBundle?> getGeometryBundle({
    required String packageId,
    required String courseId,
  }) {
    return _packageRepo.getGeometryBundle(packageId, courseId);
  }

  @override
  Future<List<CoursePackageManifest>> listPackages() {
    return _packageRepo.listPackages();
  }
}
