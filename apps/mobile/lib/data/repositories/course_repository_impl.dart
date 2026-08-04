// Course Repository Implementation — VSP Mobile App
//
// Local course package-backed implementation of CourseRepository.
// Uses the CoursePackageRepository for offline-first course queries.
//
// Story 6.2 — Wave B: Geospatial Query Layer

import 'package:course_package/course_package.dart';

import '../../domain/repositories/course_repository.dart';

/// SQLite-backed implementation of CourseRepository.
///
/// Queries local course packages for course data.
/// Used by CourseHoleDetectionService to find courses within a facility.
class CourseRepositoryImpl implements CourseRepository {
  final CoursePackageRepository _coursePackageRepository;

  CourseRepositoryImpl({CoursePackageRepository? coursePackageRepository})
    : _coursePackageRepository =
          coursePackageRepository ?? LocalCoursePackageRepository();

  @override
  Future<List<CourseSearchResult>> findWithinFacility(String facilityId) async {
    final packages = await _coursePackageRepository.listPackages();
    final results = <CourseSearchResult>[];

    for (final manifest in packages) {
      if (manifest.facilityId == facilityId) {
        // Each package represents one course at the facility
        results.add(
          CourseSearchResult(
            id: manifest.courseId,
            name: manifest.courseName ?? manifest.facilityName ?? manifest.courseId,
            holeCount: manifest.holesCount ?? 0,
            par: manifest.parTotal,
          ),
        );
      }
    }

    return results;
  }

  @override
  Future<CourseSearchResult?> getById(String courseId) async {
    final packages = await _coursePackageRepository.listPackages();

    for (final manifest in packages) {
      if (manifest.courseId == courseId) {
        return CourseSearchResult(
          id: manifest.courseId,
          name: manifest.courseName ?? manifest.facilityName ?? manifest.courseId,
          holeCount: manifest.holesCount ?? 0,
          par: manifest.parTotal,
        );
      }
    }

    return null;
  }
}
