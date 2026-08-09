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

  /// Finds the downloaded package covering [courseId], newest first.
  ///
  /// Callers used to have to carry a package id from wherever the round was
  /// started, and one of them — the course picker in round setup — passed a
  /// hardcoded null. So a golfer who downloaded a course, saw "Offline Ready",
  /// and then chose that course from the picker got a map that reported the
  /// hole as unsurveyed, with the package sitting complete on disk. Asking the
  /// device what it actually has removes the whole class of mistake.
  Future<String?> findPackageIdForCourse(String courseId);
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
      // The database row id, which is what anything reported back to the
      // server must name — the hole number alone points at a different course.
      holeId: dto.holeId,
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

  @override
  Future<String?> findPackageIdForCourse(String courseId) async {
    final matching = (await _packageRepo.listPackages())
        .where((p) => p.courseId == courseId)
        .toList();
    if (matching.isEmpty) return null;

    // A course keeps every version it has downloaded so an interrupted update
    // cannot damage the package already on the phone. Newest effective wins.
    matching.sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
    return matching.first.packageId;
  }
}
