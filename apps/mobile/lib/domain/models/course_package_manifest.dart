// Course Package Manifest Model — VSP Mobile App
//
// The manifest contract for an offline course package.
// Mirrors CoursePackageManifest from the backend (Story 4.1 PKG-CONTRACT-2).
//
// Story 4.1 AC-1: defines course/version identifiers, checksums, size,
// effective time, files, minimum client version, and licenses.

import 'package:equatable/equatable.dart';

import 'package_content_type.dart';
import 'package_file_entry.dart';
import 'package_license.dart';

/// Accuracy class for package data quality.
enum AccuracyClass {
  aRtkSurveyed('A_RTK_SURVEYED'),
  bLicensedProvider('B_LICENSED_PROVIDER'),
  cVerifiedSatellite('C_VERIFIED_SATELLITE'),
  dUnverifiedCommunity('D_UNVERIFIED_COMMUNITY');

  final String value;
  const AccuracyClass(this.value);

  static AccuracyClass? fromString(String? value) {
    if (value == null) return null;
    return AccuracyClass.values.cast<AccuracyClass?>().firstWhere(
      (e) => e!.value == value,
      orElse: () => null,
    );
  }
}

/// Tiles format used in this package.
enum TilesFormat {
  pmtiles('PMTILES'),
  mbtiles('MBTILES'),
  vectorTiles('VECTOR_TILES');

  final String value;
  const TilesFormat(this.value);

  static TilesFormat fromString(String value) {
    return TilesFormat.values.firstWhere(
      (e) => e.value == value.toUpperCase(),
      orElse: () => TilesFormat.pmtiles,
    );
  }
}

/// Course package manifest — the offline package contract.
class CoursePackageManifest extends Equatable {
  final String packageId;
  final int courseId;
  final String version;
  final DateTime effectiveDate;
  final DateTime? expiresAt;
  final String checksum;
  final int sizeBytes;
  final TilesFormat tilesFormat;
  final String tilesUrl;
  final String geoJsonUrl;
  final String? dataVersion;
  final List<PackageFileEntry> files;
  final String minimumClientVersion;
  final List<PackageLicense> licenses;
  final String? scorecardUrl;
  final String? rulesUrl;
  final String? conditionsUrl;
  final String? metadataUrl;
  final DateTime generatedAt;
  final String generatedBy;
  final DateTime? pinSnapshotDate;
  final DateTime? weatherSnapshotDate;
  final AccuracyClass? accuracyClass;
  final double? confidence;

  const CoursePackageManifest({
    required this.packageId,
    required this.courseId,
    required this.version,
    required this.effectiveDate,
    this.expiresAt,
    required this.checksum,
    required this.sizeBytes,
    required this.tilesFormat,
    required this.tilesUrl,
    required this.geoJsonUrl,
    this.dataVersion,
    required this.files,
    required this.minimumClientVersion,
    required this.licenses,
    this.scorecardUrl,
    this.rulesUrl,
    this.conditionsUrl,
    this.metadataUrl,
    required this.generatedAt,
    required this.generatedBy,
    this.pinSnapshotDate,
    this.weatherSnapshotDate,
    this.accuracyClass,
    this.confidence,
  });

  /// Parse from API response JSON.
  factory CoursePackageManifest.fromJson(Map<String, dynamic> json) {
    return CoursePackageManifest(
      packageId: json['packageId'] as String,
      courseId: int.parse(json['courseId'].toString().split('/').last),
      version: json['version'] as String,
      effectiveDate: DateTime.parse(json['effectiveDate'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      checksum: json['checksum'] as String,
      sizeBytes: json['sizeBytes'] as int,
      tilesFormat: TilesFormat.fromString(json['tilesFormat'] as String),
      tilesUrl: json['tilesUrl'] as String,
      geoJsonUrl: json['geoJsonUrl'] as String,
      dataVersion: json['dataVersion'] as String?,
      files:
          (json['files'] as List<dynamic>?)
              ?.map((e) => PackageFileEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      minimumClientVersion: json['minimumClientVersion'] as String,
      licenses:
          (json['licenses'] as List<dynamic>?)
              ?.map((e) => PackageLicense.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      scorecardUrl: json['scorecardUrl'] as String?,
      rulesUrl: json['rulesUrl'] as String?,
      conditionsUrl: json['conditionsUrl'] as String?,
      metadataUrl: json['metadataUrl'] as String?,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      generatedBy: json['generatedBy'] as String,
      pinSnapshotDate: json['pinSnapshotDate'] != null
          ? DateTime.parse(json['pinSnapshotDate'] as String)
          : null,
      weatherSnapshotDate: json['weatherSnapshotDate'] != null
          ? DateTime.parse(json['weatherSnapshotDate'] as String)
          : null,
      accuracyClass: AccuracyClass.fromString(json['accuracyClass'] as String?),
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'packageId': packageId,
    'courseId': courseId,
    'version': version,
    'effectiveDate': effectiveDate.toIso8601String(),
    if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    'checksum': checksum,
    'sizeBytes': sizeBytes,
    'tilesFormat': tilesFormat.value,
    'tilesUrl': tilesUrl,
    'geoJsonUrl': geoJsonUrl,
    if (dataVersion != null) 'dataVersion': dataVersion,
    'files': files.map((f) => f.toJson()).toList(),
    'minimumClientVersion': minimumClientVersion,
    'licenses': licenses.map((l) => l.toJson()).toList(),
    if (scorecardUrl != null) 'scorecardUrl': scorecardUrl,
    if (rulesUrl != null) 'rulesUrl': rulesUrl,
    if (conditionsUrl != null) 'conditionsUrl': conditionsUrl,
    if (metadataUrl != null) 'metadataUrl': metadataUrl,
    'generatedAt': generatedAt.toIso8601String(),
    'generatedBy': generatedBy,
    if (pinSnapshotDate != null)
      'pinSnapshotDate': pinSnapshotDate!.toIso8601String(),
    if (weatherSnapshotDate != null)
      'weatherSnapshotDate': weatherSnapshotDate!.toIso8601String(),
    if (accuracyClass != null) 'accuracyClass': accuracyClass!.value,
    if (confidence != null) 'confidence': confidence,
  };

  /// True if this package is currently within its effective date window.
  bool get isEffective {
    final now = DateTime.now();
    return effectiveDate.isBefore(now) &&
        (expiresAt == null || expiresAt!.isAfter(now));
  }

  @override
  List<Object?> get props => [
    packageId,
    courseId,
    version,
    effectiveDate,
    expiresAt,
    checksum,
    sizeBytes,
    tilesFormat,
    tilesUrl,
    geoJsonUrl,
    dataVersion,
    files,
    minimumClientVersion,
    licenses,
    scorecardUrl,
    rulesUrl,
    conditionsUrl,
    metadataUrl,
    generatedAt,
    generatedBy,
    pinSnapshotDate,
    weatherSnapshotDate,
    accuracyClass,
    confidence,
  ];
}
