// InMemoryHoleGeometryProvider Stub — VSP Mobile App
//
// In-memory stub implementation of HoleGeometryProvider for testing.
//
// Story 11.4 — Slice 1: Data Access Interfaces + In-Memory Stubs

import '../../../value_objects/lat_lng.dart';
import 'hole_geometry_provider.dart';

/// In-memory stub for HoleGeometryProvider.
///
/// Provides synthetic hole geometry for unit testing without requiring
/// the full Epic 6 implementation.
class InMemoryHoleGeometryProvider implements HoleGeometryProvider {
  final Map<String, HoleContext> _holes = {};

  InMemoryHoleGeometryProvider({List<HoleContext>? seeds}) {
    if (seeds != null) {
      for (final hole in seeds) {
        _holes[hole.holeId] = hole;
      }
    }
  }

  void addHole(HoleContext hole) {
    _holes[hole.holeId] = hole;
  }

  void clear() => _holes.clear();

  @override
  Future<HoleContext?> getHoleContext(String holeId) async {
    return _holes[holeId];
  }

  @override
  Future<HoleContext?> getHoleContextByNumber(
    String courseId,
    int holeNumber,
  ) async {
    // Stub: lookup by holeId pattern "courseId:holeNumber".
    return _holes['$courseId:$holeNumber'];
  }

  @override
  Future<bool> hasGeometry(String holeId) async {
    return _holes.containsKey(holeId);
  }
}
