// Watch Package Generator — VSP API
//
// Generates watch subset packages from full course packages.
// Used by the backend to create downloadable watch packages.
//
// Story 10.1 — Slice 4: Offline Course Subset

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../../../course_package/lib/src/watch_package_manifest.dart';

/// Generates watch subset packages from full course packages.
class WatchPackageGenerator {
  /// Generate a watch package manifest from full course data.
  ///
  /// [courseId] - Course identifier
  /// [courseName] - Course name
  /// [fullManifestPath] - Path to full course manifest JSON
  /// [version] - Package version string
  Future<WatchPackageManifest> generate({
    required int courseId,
    required String courseName,
    required String version,
    required String fullManifestPath,
  }) async {
    final fullManifest = await _loadFullManifest(fullManifestPath);
    final watchManifest = await _createWatchManifest(
      courseId: courseId,
      courseName: courseName,
      version: version,
      fullManifest: fullManifest,
    );

    return watchManifest;
  }

  /// Create watch manifest JSON file.
  Future<void> writeManifestFile({
    required WatchPackageManifest manifest,
    required String outputPath,
  }) async {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(manifest.toJson());
    await File(outputPath).writeAsString(jsonStr);
  }

  /// Calculate SHA-256 checksum for a file.
  Future<String> calculateChecksum(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    return sha256.convert(bytes).toString();
  }

  /// Estimate watch package size in bytes.
  int estimateSize(List<WatchHoleData> holes) {
    // Rough estimation: ~200 bytes per hole
    return holes.length * 200 + 500; // +500 for manifest overhead
  }

  // ─── Private helpers ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _loadFullManifest(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('Manifest not found', path);
    }
    final contents = await file.readAsString();
    return jsonDecode(contents) as Map<String, dynamic>;
  }

  Future<WatchPackageManifest> _createWatchManifest({
    required int courseId,
    required String courseName,
    required String version,
    required Map<String, dynamic> fullManifest,
  }) async {
    // Extract holes from full manifest
    // In production, this would parse the actual course geometry
    final holes = <WatchHoleData>[];

    // Placeholder: generate watch holes from full manifest
    // Real implementation would compute distances from tee to green
    final holesData = fullManifest['holes'] as List<dynamic>? ?? [];
    for (final holeData in holesData) {
      final hole = _createWatchHole(holeData as Map<String, dynamic>);
      if (hole != null) {
        holes.add(hole);
      }
    }

    final sizeBytes = estimateSize(holes);
    final now = DateTime.now();
    final manifest = WatchPackageManifest(
      packageId: 'watch_${courseId}_$version',
      courseId: courseId,
      courseName: courseName,
      version: version,
      effectiveDate: now,
      expiresAt: now.add(const Duration(days: 90)),
      checksum: '', // Will be calculated after writing
      sizeBytes: sizeBytes,
      holes: holes,
      generatedAt: now,
      generatedBy: 'WatchPackageGenerator v1.0',
    );

    return manifest;
  }

  WatchHoleData? _createWatchHole(Map<String, dynamic> fullHole) {
    try {
      final holeNumber = fullHole['holeNumber'] as int;
      final par = fullHole['par'] as int? ?? 4;

      // Extract geometry (placeholder - real impl would compute distances)
      final tee = fullHole['tee'] as Map<String, dynamic>? ?? {};
      final green = fullHole['green'] as Map<String, dynamic>? ?? {};

      return WatchHoleData(
        holeNumber: holeNumber,
        par: par,
        teeLat: (tee['lat'] as num?)?.toDouble() ?? 0,
        teeLng: (tee['lng'] as num?)?.toDouble() ?? 0,
        greenLat: (green['lat'] as num?)?.toDouble() ?? 0,
        greenLng: (green['lng'] as num?)?.toDouble() ?? 0,
        frontGreenMeters: (fullHole['frontGreenMeters'] as num?)?.toDouble() ?? 0,
        centerGreenMeters: (fullHole['centerGreenMeters'] as num?)?.toDouble() ?? 0,
        backGreenMeters: (fullHole['backGreenMeters'] as num?)?.toDouble() ?? 0,
        pinLat: (fullHole['pinLat'] as num?)?.toDouble(),
        pinLng: (fullHole['pinLng'] as num?)?.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
