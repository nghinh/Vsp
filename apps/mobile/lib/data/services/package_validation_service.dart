// Package Validation Service — VSP Mobile App
//
// Validates downloaded course packages against manifest checksums and client version.
// Story 4.1 AC-3: corrupt or incompatible packages are rejected without replacing
// the last valid package.

import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../../domain/models/course_package_manifest.dart';

/// Result of package validation.
enum PackageValidationResult {
  /// Package passed all validation checks.
  valid,

  /// SHA-256 checksum of downloaded archive does not match manifest.
  checksumMismatch,

  /// Client version is older than minimumClientVersion in manifest.
  incompatibleVersion,

  /// Required file is missing from the downloaded package.
  missingFile,
}

/// Service for validating course package manifests and downloaded archives.
class PackageValidationService {
  /// Validate a manifest against client version.
  ///
  /// Returns [PackageValidationResult.valid] if the client version meets
  /// the minimum required version in the manifest.
  ///
  /// Returns [PackageValidationResult.incompatibleVersion] if the client
  /// version is older than the manifest's minimumClientVersion.
  PackageValidationResult validateManifestVersion(
    CoursePackageManifest manifest,
    String clientVersion,
  ) {
    if (_compareSemver(clientVersion, manifest.minimumClientVersion) < 0) {
      return PackageValidationResult.incompatibleVersion;
    }
    return PackageValidationResult.valid;
  }

  /// Validate a downloaded archive against the manifest checksum.
  ///
  /// The [archiveBytes] are the raw bytes of the downloaded .tar.gz or .zip archive.
  /// Computes SHA-256 and compares to manifest.checksum.
  PackageValidationResult validateArchiveChecksum(
    CoursePackageManifest manifest,
    List<int> archiveBytes,
  ) {
    final computed = sha256.convert(archiveBytes).toString();
    if (computed != manifest.checksum) {
      return PackageValidationResult.checksumMismatch;
    }
    return PackageValidationResult.valid;
  }

  /// Validate that all files listed in manifest.files are present in the extracted directory.
  ///
  /// [extractedPaths] is the set of relative paths found in the extracted package.
  /// Returns [PackageValidationResult.missingFile] if any manifest file is absent.
  PackageValidationResult validateFileInventory(
    CoursePackageManifest manifest,
    Set<String> extractedPaths,
  ) {
    for (final file in manifest.files) {
      if (!extractedPaths.contains(file.path)) {
        return PackageValidationResult.missingFile;
      }
    }
    return PackageValidationResult.valid;
  }

  /// Compare two semver strings.
  /// Returns negative if v < minVersion, zero if equal, positive if v > minVersion.
  int _compareSemver(String v, String minVersion) {
    final vParts = v
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final mParts = minVersion
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final length = vParts.length > mParts.length
        ? vParts.length
        : mParts.length;
    for (int i = 0; i < length; i++) {
      final vPart = i < vParts.length ? vParts[i] : 0;
      final mPart = i < mParts.length ? mParts[i] : 0;
      if (vPart != mPart) return vPart - mPart;
    }
    return 0;
  }
}
