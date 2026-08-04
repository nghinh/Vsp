// PinEntity — VSP Mobile App
//
// Pin (hole flag) position on the green.

import 'package:equatable/equatable.dart';

/// Source of the pin position data.
enum PinSource { official, estimated, manual }

/// The hole pin/flag position, either from official course data or estimation.
class PinEntity extends Equatable {
  final String holeId;
  final int holeNumber;
  final double latitude;
  final double longitude;
  final PinSource source;
  final double? confidence;
  final DateTime? snapshotDate;
  final DateTime? effectiveDate;
  final DateTime? expiryDate;

  const PinEntity({
    required this.holeId,
    required this.holeNumber,
    required this.latitude,
    required this.longitude,
    required this.source,
    this.confidence,
    this.snapshotDate,
    this.effectiveDate,
    this.expiryDate,
  });

  bool get isOfficial => source == PinSource.official;
  bool get isEstimated => source == PinSource.estimated;

  /// True when expiryDate is set and has passed.
  bool get isExpired =>
      expiryDate != null && DateTime.now().isAfter(expiryDate!);

  /// True when the pin is currently active: official source and not expired.
  /// Expired official pins must NOT be treated as current official data.
  bool get isActive => isOfficial && !isExpired;

  PinEntity copyWith({
    String? holeId,
    int? holeNumber,
    double? latitude,
    double? longitude,
    PinSource? source,
    double? confidence,
    DateTime? snapshotDate,
    DateTime? effectiveDate,
    DateTime? expiryDate,
  }) {
    return PinEntity(
      holeId: holeId ?? this.holeId,
      holeNumber: holeNumber ?? this.holeNumber,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      snapshotDate: snapshotDate ?? this.snapshotDate,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }

  factory PinEntity.fromJson(Map<String, dynamic> json) {
    return PinEntity(
      holeId: json['holeId'] as String,
      holeNumber: json['holeNumber'] as int,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      source: PinSource.values.firstWhere(
        (e) => e.name == (json['source'] as String? ?? 'manual'),
        orElse: () => PinSource.manual,
      ),
      confidence: (json['confidence'] as num?)?.toDouble(),
      snapshotDate: json['snapshotDate'] != null
          ? DateTime.tryParse(json['snapshotDate'] as String)
          : null,
      effectiveDate: json['effectiveDate'] != null
          ? DateTime.tryParse(json['effectiveDate'] as String)
          : null,
      expiryDate: json['expiryDate'] != null
          ? DateTime.tryParse(json['expiryDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'holeId': holeId,
    'holeNumber': holeNumber,
    'latitude': latitude,
    'longitude': longitude,
    'source': source.name,
    if (confidence != null) 'confidence': confidence,
    if (snapshotDate != null) 'snapshotDate': snapshotDate!.toIso8601String(),
    if (effectiveDate != null)
      'effectiveDate': effectiveDate!.toIso8601String(),
    if (expiryDate != null) 'expiryDate': expiryDate!.toIso8601String(),
  };

  @override
  List<Object?> get props => [
    holeId,
    holeNumber,
    latitude,
    longitude,
    source,
    confidence,
    snapshotDate,
    effectiveDate,
    expiryDate,
  ];
}
