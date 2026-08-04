// Watch Package Manifest — VSP Golf Platform
//
// Subset of course data sufficient for 18-hole watch-only round.
// Derived from the full CoursePackageManifest but trimmed for watch storage.
//
// Story 10.1 — Slice 4: Offline Course Subset

import 'package:equatable/equatable.dart';

/// Accuracy class for watch course geometry.
enum WatchAccuracyClass { a, b, c, d }

/// A single hole's watch subset data.
class WatchHoleData extends Equatable {
  /// Hole number (1-18).
  final int holeNumber;

  /// Par for this hole.
  final int par;

  /// Tee box coordinates (lat/lng in WGS84).
  final double teeLat;
  final double teeLng;

  /// Green center coordinates.
  final double greenLat;
  final double greenLng;

  /// Front green distance from tee (meters).
  final double frontGreenMeters;

  /// Center green distance from tee (meters).
  final double centerGreenMeters;

  /// Back green distance from tee (meters).
  final double backGreenMeters;

  /// Pin/target position (optional, for target mode).
  final double? pinLat;
  final double? pinLng;

  const WatchHoleData({
    required this.holeNumber,
    required this.par,
    required this.teeLat,
    required this.teeLng,
    required this.greenLat,
    required this.greenLng,
    required this.frontGreenMeters,
    required this.centerGreenMeters,
    required this.backGreenMeters,
    this.pinLat,
    this.pinLng,
  });

  factory WatchHoleData.fromJson(Map<String, dynamic> json) {
    return WatchHoleData(
      holeNumber: json['holeNumber'] as int,
      par: json['par'] as int,
      teeLat: (json['teeLat'] as num).toDouble(),
      teeLng: (json['teeLng'] as num).toDouble(),
      greenLat: (json['greenLat'] as num).toDouble(),
      greenLng: (json['greenLng'] as num).toDouble(),
      frontGreenMeters: (json['frontGreenMeters'] as num).toDouble(),
      centerGreenMeters: (json['centerGreenMeters'] as num).toDouble(),
      backGreenMeters: (json['backGreenMeters'] as num).toDouble(),
      pinLat: (json['pinLat'] as num?)?.toDouble(),
      pinLng: (json['pinLng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'holeNumber': holeNumber,
        'par': par,
        'teeLat': teeLat,
        'teeLng': teeLng,
        'greenLat': greenLat,
        'greenLng': greenLng,
        'frontGreenMeters': frontGreenMeters,
        'centerGreenMeters': centerGreenMeters,
        'backGreenMeters': backGreenMeters,
        if (pinLat != null) 'pinLat': pinLat,
        if (pinLng != null) 'pinLng': pinLng,
      };

  @override
  List<Object?> get props => [
        holeNumber,
        par,
        teeLat,
        teeLng,
        greenLat,
        greenLng,
        frontGreenMeters,
        centerGreenMeters,
        backGreenMeters,
        pinLat,
        pinLng,
      ];
}

/// Watch package manifest — metadata for watch course subset.
class WatchPackageManifest extends Equatable {
  final String packageId;
  final int courseId;
  final String courseName;
  final String version;
  final DateTime effectiveDate;
  final DateTime? expiresAt;
  final String checksum;
  final int sizeBytes;
  final WatchAccuracyClass? accuracyClass;
  final double? confidence;
  final List<WatchHoleData> holes;
  final DateTime generatedAt;
  final String? generatedBy;

  const WatchPackageManifest({
    required this.packageId,
    required this.courseId,
    required this.courseName,
    required this.version,
    required this.effectiveDate,
    this.expiresAt,
    required this.checksum,
    required this.sizeBytes,
    this.accuracyClass,
    this.confidence,
    required this.holes,
    required this.generatedAt,
    this.generatedBy,
  });

  factory WatchPackageManifest.fromJson(Map<String, dynamic> json) {
    return WatchPackageManifest(
      packageId: json['packageId'] as String,
      courseId: json['courseId'] as int,
      courseName: json['courseName'] as String,
      version: json['version'] as String,
      effectiveDate: DateTime.parse(json['effectiveDate'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      checksum: json['checksum'] as String,
      sizeBytes: json['sizeBytes'] as int,
      accuracyClass: _parseAccuracyClass(json['accuracyClass'] as String?),
      confidence: (json['confidence'] as num?)?.toDouble(),
      holes: (json['holes'] as List<dynamic>)
          .map((e) => WatchHoleData.fromJson(e as Map<String, dynamic>))
          .toList(),
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      generatedBy: json['generatedBy'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'packageId': packageId,
        'courseId': courseId,
        'courseName': courseName,
        'version': version,
        'effectiveDate': effectiveDate.toIso8601String(),
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        'checksum': checksum,
        'sizeBytes': sizeBytes,
        'accuracyClass': accuracyClass?.name.toUpperCase(),
        if (confidence != null) 'confidence': confidence,
        'holes': holes.map((h) => h.toJson()).toList(),
        'generatedAt': generatedAt.toIso8601String(),
        if (generatedBy != null) 'generatedBy': generatedBy,
      };

  static WatchAccuracyClass? _parseAccuracyClass(String? value) {
    if (value == null) return null;
    switch (value.toUpperCase()) {
      case 'A':
        return WatchAccuracyClass.a;
      case 'B':
        return WatchAccuracyClass.b;
      case 'C':
        return WatchAccuracyClass.c;
      case 'D':
        return WatchAccuracyClass.d;
      default:
        return null;
    }
  }

  @override
  List<Object?> get props => [
        packageId,
        courseId,
        courseName,
        version,
        effectiveDate,
        expiresAt,
        checksum,
        sizeBytes,
        accuracyClass,
        confidence,
        holes,
        generatedAt,
        generatedBy,
      ];
}
