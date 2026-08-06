// Package Readiness Service — VSP Mobile App
//
// Validates offline package readiness for a course.
// Returns reason codes (ok/notDownloaded/expired/checksumMismatch/filesMissing)
// and supports warning dialog acknowledgment with telemetry.
//
// Story 5.1 — Slice E: Offline Package Readiness Validation

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../repositories/package_manifest_repository.dart';
import '../../domain/models/course_package_manifest.dart';

/// Collects the single [Digest] a chunked SHA-256 conversion emits on close.
class _DigestSink implements Sink<Digest> {
  late final Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

/// Readiness reason codes.
enum PackageReadinessReason {
  /// Package is ready for offline play.
  ok,

  /// Course package not downloaded.
  notDownloaded,

  /// Package has expired.
  expired,

  /// Package checksum does not match manifest.
  checksumMismatch,

  /// Required package files are missing locally.
  filesMissing,
}

/// Result of offline readiness check.
class OfflineReadiness {
  final bool isReady;
  final PackageReadinessReason reason;
  final String reasonMessage;
  final CoursePackageManifest? manifest;
  final DateTime? expiresAt;

  const OfflineReadiness({
    required this.isReady,
    required this.reason,
    required this.reasonMessage,
    this.manifest,
    this.expiresAt,
  });

  /// Factory for ok status.
  factory OfflineReadiness.ok({required CoursePackageManifest manifest}) {
    return OfflineReadiness(
      isReady: true,
      reason: PackageReadinessReason.ok,
      reasonMessage: 'Package is ready for offline play',
      manifest: manifest,
      expiresAt: manifest.expiresAt,
    );
  }

  /// Factory for notDownloaded status.
  factory OfflineReadiness.notDownloaded() {
    return const OfflineReadiness(
      isReady: false,
      reason: PackageReadinessReason.notDownloaded,
      reasonMessage: 'Course package not downloaded. Download to play offline.',
    );
  }

  /// Factory for expired status.
  factory OfflineReadiness.expired({DateTime? expiresAt}) {
    return OfflineReadiness(
      isReady: false,
      reason: PackageReadinessReason.expired,
      reasonMessage: 'Course data may be outdated. Package has expired.',
      expiresAt: expiresAt,
    );
  }

  /// Factory for checksumMismatch status.
  factory OfflineReadiness.checksumMismatch() {
    return const OfflineReadiness(
      isReady: false,
      reason: PackageReadinessReason.checksumMismatch,
      reasonMessage: 'Course data is corrupted. Please re-download.',
    );
  }

  /// Factory for filesMissing status.
  factory OfflineReadiness.filesMissing() {
    return const OfflineReadiness(
      isReady: false,
      reason: PackageReadinessReason.filesMissing,
      reasonMessage: 'Some course files are missing. Please re-download.',
    );
  }
}

/// Service for checking offline package readiness.
///
/// Checks:
/// 1. Active manifest exists for courseId
/// 2. Manifest is effective (within effective date window)
/// 3. Package files exist locally
/// 4. Checksum integrity
class PackageReadinessService {
  final PackageManifestRepository _manifestRepo;

  PackageReadinessService({required PackageManifestRepository manifestRepo})
    : _manifestRepo = manifestRepo;

  /// Get offline readiness for a course.
  ///
  /// Returns [OfflineReadiness] with isReady and reason code.
  /// Callers should show a warning dialog if !isReady and allow
  /// user to acknowledge and proceed ("Play anyway?").
  Future<OfflineReadiness> getOfflineReadiness(int courseId) async {
    // 1. Check if active manifest exists
    final manifest = await _manifestRepo.getActiveManifest(courseId);
    if (manifest == null) {
      return OfflineReadiness.notDownloaded();
    }

    // 2. Check if manifest is effective
    if (!manifest.isEffective) {
      return OfflineReadiness.expired(expiresAt: manifest.expiresAt);
    }

    // 3. Check if package files exist locally
    final filesExist = await _checkFilesExist(manifest);
    if (!filesExist) {
      return OfflineReadiness.filesMissing();
    }

    // 4. Check checksum integrity
    final checksumValid = await _verifyChecksum(manifest);
    if (!checksumValid) {
      return OfflineReadiness.checksumMismatch();
    }

    // All checks pass
    return OfflineReadiness.ok(manifest: manifest);
  }

  /// Check that all required package files exist locally.
  Future<bool> _checkFilesExist(CoursePackageManifest manifest) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final packageDir = Directory(
        '${appDir.path}/packages/${manifest.courseId}/${manifest.version}',
      );

      if (!await packageDir.exists()) {
        return false;
      }

      // A manifest that declares no files describes nothing that was ever
      // downloaded, so there is nothing on disk that could make this course
      // playable offline. The loop below would pass it — zero files, zero
      // failures — and the golfer would be told the course is ready having
      // received no map. This is the same judgement the download path makes
      // when it refuses an empty package; it has to hold here too, or a
      // package refused at download time is reported ready afterwards.
      if (manifest.files.isEmpty) {
        return false;
      }

      // Check that at least the key files exist
      for (final file in manifest.files) {
        final filePath = '${packageDir.path}/${file.path}';
        final f = File(filePath);
        if (!await f.exists()) {
          return false;
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Verify package integrity: every file the manifest declares must hash to
  /// the SHA-256 the manifest recorded for it.
  ///
  /// What was here before could not fail. It summed the on-disk sizes and
  /// compared them to `manifest.sizeBytes`; on a mismatch it deferred to
  /// `_spotCheckChecksum`, which was a comment and `return true`. So the only
  /// ways this method ever returned false were an exception or a missing
  /// directory — never a byte that had changed. A truncated download, a half
  /// written tile pack, a file corrupted on a failing SD card, or bytes
  /// substituted in transit all read as "Offline Ready", and the golfer found
  /// out on the tee.
  ///
  /// The size comparison is gone rather than kept as a fast path. It could not
  /// do the job — `sizeBytes` is the sum of the declared files, while the walk
  /// counted everything in the directory, so any extra file made the totals
  /// disagree for a reason that says nothing about integrity — and hashing the
  /// declared files answers the question it was standing in for.
  Future<bool> _verifyChecksum(CoursePackageManifest manifest) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final packageDir = Directory(
        '${appDir.path}/packages/${manifest.courseId}/${manifest.version}',
      );

      if (!await packageDir.exists()) {
        return false;
      }

      // Nothing declared means nothing verified. Reporting a package with no
      // files as intact would be the same falsehood in a different place.
      if (manifest.files.isEmpty) {
        return false;
      }

      for (final entry in manifest.files) {
        final file = File('${packageDir.path}/${entry.path}');
        if (!await file.exists()) {
          return false;
        }
        final computed = await sha256OfFile(file);
        if (!_checksumsMatch(computed, entry.checksum)) {
          debugPrint(
            '[PackageReadinessService] Checksum mismatch for ${entry.path}: '
            'manifest ${entry.checksum}, on disk $computed',
          );
          return false;
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Compare a computed digest with the manifest's, tolerating case and an
  /// optional `sha256:` prefix, but never tolerating an absent expectation:
  /// an empty manifest checksum verifies nothing and must not pass.
  static bool _checksumsMatch(String computed, String expected) {
    final wanted = expected.trim().toLowerCase().replaceFirst('sha256:', '');
    if (wanted.isEmpty) {
      return false;
    }
    return computed.toLowerCase() == wanted;
  }

  /// SHA-256 of a file's contents, hex, streamed rather than read whole so a
  /// large tile pack is not loaded into memory to be checked.
  static Future<String> sha256OfFile(File file) async {
    final sink = _DigestSink();
    final hashOutput = sha256.startChunkedConversion(sink);
    await for (final chunk in file.openRead()) {
      hashOutput.add(chunk);
    }
    hashOutput.close();
    return sink.value.toString();
  }

  /// Record telemetry when user acknowledges warning and proceeds.
  ///
  /// Called when user taps "Play anyway?" on the warning dialog.
  Future<void> recordWarningAcknowledged({
    required int courseId,
    required String packageId,
    required PackageReadinessReason reason,
  }) async {
    // TODO: Send telemetry event to backend or local analytics
    // For now, this is a no-op. Real implementation would call
    // an analytics service or write to local telemetry store.
  }
}
