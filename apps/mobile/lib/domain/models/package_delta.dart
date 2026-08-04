// Package Delta Model — VSP Mobile App
//
// Represents the delta (difference) between two course package manifests.
// Used by incremental updates to determine which files need downloading.
//
// Story 4.4 INC-MOBILE-DIFF: delta computation between old and new manifest.

import 'package:equatable/equatable.dart';

import 'package_file_entry.dart';

/// Delta between two course package manifests.
///
/// Files are categorized as:
/// - toDownload: files that are new or changed (checksum differs)
/// - toDelete: files that existed locally but are no longer in the new manifest
/// - unchanged: files that are identical in both manifests (can reuse cached version)
class PackageDelta extends Equatable {
  /// Files that need to be downloaded (new or changed checksums).
  final List<PackageFileEntry> toDownload;

  /// Files that should be deleted locally (no longer in new manifest).
  final List<String> toDelete;

  /// Number of files that are unchanged (can reuse cached).
  final int unchangedCount;

  /// Total bytes to download across all changed/new files.
  final int totalDownloadBytes;

  const PackageDelta({
    required this.toDownload,
    required this.toDelete,
    required this.unchangedCount,
    required this.totalDownloadBytes,
  });

  /// True if no files need updating.
  bool get isEmpty => toDownload.isEmpty && toDelete.isEmpty;

  /// Human-readable summary of the delta.
  String get summary {
    if (isEmpty) return 'No update needed';
    final parts = <String>[];
    if (toDownload.isNotEmpty) {
      parts.add(
        '${toDownload.length} file${toDownload.length == 1 ? '' : 's'} to update',
      );
    }
    if (toDelete.isNotEmpty) {
      parts.add(
        '${toDelete.length} file${toDelete.length == 1 ? '' : 's'} to remove',
      );
    }
    if (unchangedCount > 0) {
      parts.add('$unchangedCount unchanged');
    }
    return parts.join(', ');
  }

  @override
  List<Object?> get props => [
    toDownload,
    toDelete,
    unchangedCount,
    totalDownloadBytes,
  ];
}
