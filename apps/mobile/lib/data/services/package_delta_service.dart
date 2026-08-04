// Package Delta Service — VSP Mobile App
//
// Computes the delta between two course package manifests.
// Determines which files need downloading (new or changed) and which should be deleted.
//
// Story 4.4 INC-MOBILE-DIFF: delta file computation.
//
// Algorithm:
// 1. Compare version field — if identical, return empty delta
// 2. Build a map of old files by path+checksum
// 3. For each new file:
//    - If checksum differs or file is new → toDownload
//    - If checksum same → unchanged
// 4. Files in oldManifest but not in newManifest → toDelete

import '../../domain/models/course_package_manifest.dart';
import '../../domain/models/package_delta.dart';

/// Service to compute delta between old and new package manifests.
class PackageDeltaService {
  /// Compute the delta between the old (current) and new (available) manifest.
  ///
  /// Returns a [PackageDelta] describing:
  /// - [PackageDelta.toDownload]: files that are new or have changed checksums
  /// - [PackageDelta.toDelete]: files that existed locally but are no longer needed
  /// - [PackageDelta.unchangedCount]: files that can be reused from cache
  PackageDelta computeDelta(
    CoursePackageManifest oldManifest,
    CoursePackageManifest newManifest,
  ) {
    // If versions are the same, no update possible
    if (oldManifest.version == newManifest.version) {
      return const PackageDelta(
        toDownload: [],
        toDelete: [],
        unchangedCount: 0,
        totalDownloadBytes: 0,
      );
    }

    // Build a map of old files by path for quick lookup
    final oldFilesByPath = <String, String>{};
    for (final file in oldManifest.files) {
      oldFilesByPath[file.path] = file.checksum;
    }

    // Track which old files are still needed
    final stillNeeded = <String>{};

    // Files to download (new or changed)
    final toDownload = <dynamic>[];
    int totalDownloadBytes = 0;
    int unchangedCount = 0;

    for (final newFile in newManifest.files) {
      final oldChecksum = oldFilesByPath[newFile.path];
      if (oldChecksum == null) {
        // New file — needs download
        toDownload.add(newFile);
        totalDownloadBytes += newFile.sizeBytes;
      } else if (oldChecksum != newFile.checksum) {
        // Changed file — needs download
        toDownload.add(newFile);
        totalDownloadBytes += newFile.sizeBytes;
        stillNeeded.add(newFile.path);
      } else {
        // Unchanged — can reuse cached
        unchangedCount++;
        stillNeeded.add(newFile.path);
      }
    }

    // Files to delete (existed locally but no longer in new manifest)
    final toDelete = <String>[];
    for (final oldPath in oldFilesByPath.keys) {
      if (!stillNeeded.contains(oldPath)) {
        toDelete.add(oldPath);
      }
    }

    return PackageDelta(
      toDownload: toDownload.cast(),
      toDelete: toDelete,
      unchangedCount: unchangedCount,
      totalDownloadBytes: totalDownloadBytes,
    );
  }
}
