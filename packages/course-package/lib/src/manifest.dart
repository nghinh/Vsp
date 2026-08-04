// CoursePackageManifest — VSP Golf Platform
//
// Represents the metadata manifest bundled with each downloaded course package.
// Corresponds to manifest.schema.json in the package root.

import 'package:equatable/equatable.dart';

/// Accuracy class for course geometry data quality.
enum AccuracyClass { a, b, c, d }

/// License entry governing package or content usage.
class PackageLicense extends Equatable {
  final String name;
  final String? url;
  final String? spdxId;

  const PackageLicense({
    required this.name,
    this.url,
    this.spdxId,
  });

  factory PackageLicense.fromJson(Map<String, dynamic> json) {
    return PackageLicense(
      name: json['name'] as String,
      url: json['url'] as String?,
      spdxId: json['spdxId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (url != null) 'url': url,
        if (spdxId != null) 'spdxId': spdxId,
      };

  @override
  List<Object?> get props => [name, url, spdxId];
}

/// A single file entry within the course package archive.
class PackageFileEntry extends Equatable {
  final String path;
  final String checksum;
  final int sizeBytes;
  final String contentType;

  const PackageFileEntry({
    required this.path,
    required this.checksum,
    required this.sizeBytes,
    required this.contentType,
  });

  factory PackageFileEntry.fromJson(Map<String, dynamic> json) {
    return PackageFileEntry(
      path: json['path'] as String,
      checksum: json['checksum'] as String,
      sizeBytes: json['sizeBytes'] as int,
      contentType: json['contentType'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'checksum': checksum,
        'sizeBytes': sizeBytes,
        'contentType': contentType,
      };

  @override
  List<Object?> get props => [path, checksum, sizeBytes, contentType];
}

/// Course package manifest — top-level metadata for a downloadable course package.
class CoursePackageManifest extends Equatable {
  final String packageId;
  final String courseId;
  final String version;
  final DateTime effectiveDate;
  final DateTime? expiresAt;
  final String checksum;
  final int sizeBytes;
  final String tilesFormat;
  final String? tilesUrl;
  final String? geoJsonUrl;
  final String? dataVersion;
  final DateTime? pinSnapshotDate;
  final DateTime? weatherSnapshotDate;
  final AccuracyClass? accuracyClass;
  final double? confidence;
  final List<PackageFileEntry> files;
  final String? minimumClientVersion;
  final List<PackageLicense> licenses;
  final String? scorecardUrl;
  final String? rulesUrl;
  final String? conditionsUrl;
  final String? metadataUrl;
  final DateTime? generatedAt;
  final String? generatedBy;

  // Facility / course descriptor metadata.
  //
  // Optional, additive fields that let the mobile app resolve which facility
  // and course a downloaded package represents without unpacking full geometry.
  // Used by the offline course/hole detection layer (Story 6.2).
  final String? facilityId;
  final String? facilityName;
  final String? facilityAddress;
  final double? facilityLatitude;
  final double? facilityLongitude;
  final String? courseName;
  final int? holesCount;
  final int? parTotal;

  const CoursePackageManifest({
    required this.packageId,
    required this.courseId,
    required this.version,
    required this.effectiveDate,
    this.expiresAt,
    required this.checksum,
    required this.sizeBytes,
    required this.tilesFormat,
    this.tilesUrl,
    this.geoJsonUrl,
    this.dataVersion,
    this.pinSnapshotDate,
    this.weatherSnapshotDate,
    this.accuracyClass,
    this.confidence,
    this.files = const [],
    this.minimumClientVersion,
    this.licenses = const [],
    this.scorecardUrl,
    this.rulesUrl,
    this.conditionsUrl,
    this.metadataUrl,
    this.generatedAt,
    this.generatedBy,
    this.facilityId,
    this.facilityName,
    this.facilityAddress,
    this.facilityLatitude,
    this.facilityLongitude,
    this.courseName,
    this.holesCount,
    this.parTotal,
  });

  factory CoursePackageManifest.fromJson(Map<String, dynamic> json) {
    return CoursePackageManifest(
      packageId: json['packageId'] as String,
      courseId: json['courseId'] as String,
      version: json['version'] as String,
      effectiveDate: DateTime.parse(json['effectiveDate'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      checksum: json['checksum'] as String,
      sizeBytes: json['sizeBytes'] as int,
      tilesFormat: json['tilesFormat'] as String? ?? 'pmtiles',
      tilesUrl: json['tilesUrl'] as String?,
      geoJsonUrl: json['geoJsonUrl'] as String?,
      dataVersion: json['dataVersion'] as String?,
      pinSnapshotDate: json['pinSnapshotDate'] != null
          ? DateTime.parse(json['pinSnapshotDate'] as String)
          : null,
      weatherSnapshotDate: json['weatherSnapshotDate'] != null
          ? DateTime.parse(json['weatherSnapshotDate'] as String)
          : null,
      accuracyClass: _parseAccuracyClass(json['accuracyClass'] as String?),
      confidence: (json['confidence'] as num?)?.toDouble(),
      files: (json['files'] as List<dynamic>?)
              ?.map((e) => PackageFileEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      minimumClientVersion: json['minimumClientVersion'] as String?,
      licenses: (json['licenses'] as List<dynamic>?)
              ?.map((e) => PackageLicense.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      scorecardUrl: json['scorecardUrl'] as String?,
      rulesUrl: json['rulesUrl'] as String?,
      conditionsUrl: json['conditionsUrl'] as String?,
      metadataUrl: json['metadataUrl'] as String?,
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'] as String)
          : null,
      generatedBy: json['generatedBy'] as String?,
      facilityId: json['facilityId'] as String?,
      facilityName: json['facilityName'] as String?,
      facilityAddress: json['facilityAddress'] as String?,
      facilityLatitude: (json['facilityLatitude'] as num?)?.toDouble(),
      facilityLongitude: (json['facilityLongitude'] as num?)?.toDouble(),
      courseName: json['courseName'] as String?,
      holesCount: json['holesCount'] as int?,
      parTotal: json['parTotal'] as int?,
    );
  }

  static AccuracyClass? _parseAccuracyClass(String? value) {
    if (value == null) return null;
    switch (value.toUpperCase()) {
      case 'A':
        return AccuracyClass.a;
      case 'B':
        return AccuracyClass.b;
      case 'C':
        return AccuracyClass.c;
      case 'D':
        return AccuracyClass.d;
      default:
        return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'packageId': packageId,
        'courseId': courseId,
        'version': version,
        'effectiveDate': effectiveDate.toIso8601String(),
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        'checksum': checksum,
        'sizeBytes': sizeBytes,
        'tilesFormat': tilesFormat,
        if (tilesUrl != null) 'tilesUrl': tilesUrl,
        if (geoJsonUrl != null) 'geoJsonUrl': geoJsonUrl,
        if (dataVersion != null) 'dataVersion': dataVersion,
        if (pinSnapshotDate != null)
          'pinSnapshotDate': pinSnapshotDate!.toIso8601String(),
        if (weatherSnapshotDate != null)
          'weatherSnapshotDate': weatherSnapshotDate!.toIso8601String(),
        if (accuracyClass != null)
          'accuracyClass': accuracyClass!.name.toUpperCase(),
        if (confidence != null) 'confidence': confidence,
        'files': files.map((e) => e.toJson()).toList(),
        if (minimumClientVersion != null)
          'minimumClientVersion': minimumClientVersion,
        'licenses': licenses.map((e) => e.toJson()).toList(),
        if (scorecardUrl != null) 'scorecardUrl': scorecardUrl,
        if (rulesUrl != null) 'rulesUrl': rulesUrl,
        if (conditionsUrl != null) 'conditionsUrl': conditionsUrl,
        if (metadataUrl != null) 'metadataUrl': metadataUrl,
        if (generatedAt != null) 'generatedAt': generatedAt!.toIso8601String(),
        if (generatedBy != null) 'generatedBy': generatedBy,
        if (facilityId != null) 'facilityId': facilityId,
        if (facilityName != null) 'facilityName': facilityName,
        if (facilityAddress != null) 'facilityAddress': facilityAddress,
        if (facilityLatitude != null) 'facilityLatitude': facilityLatitude,
        if (facilityLongitude != null) 'facilityLongitude': facilityLongitude,
        if (courseName != null) 'courseName': courseName,
        if (holesCount != null) 'holesCount': holesCount,
        if (parTotal != null) 'parTotal': parTotal,
      };

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
        pinSnapshotDate,
        weatherSnapshotDate,
        accuracyClass,
        confidence,
        files,
        minimumClientVersion,
        licenses,
        scorecardUrl,
        rulesUrl,
        conditionsUrl,
        metadataUrl,
        generatedAt,
        generatedBy,
        facilityId,
        facilityName,
        facilityAddress,
        facilityLatitude,
        facilityLongitude,
        courseName,
        holesCount,
        parTotal,
      ];
}
