// Tee Set Summary DTO — VSP Mobile App
//
// Tee set info for course detail tee set comparison section.
// Mirrors TeeSetSummaryDto from packages/contracts/schemas/course.yaml.

import 'package:equatable/equatable.dart';

/// Tee set summary with yardages per forward tee.
class TeeSetSummary extends Equatable {
  final int id;
  final String name;
  final String? gender;
  final int totalPar;
  final Map<String, int> yardages;
  final double? rating;
  final int? slope;
  final String accuracyClass;

  const TeeSetSummary({
    required this.id,
    required this.name,
    this.gender,
    required this.totalPar,
    required this.yardages,
    this.rating,
    this.slope,
    required this.accuracyClass,
  });

  factory TeeSetSummary.fromJson(Map<String, dynamic> json) {
    return TeeSetSummary(
      id: json['id'] as int,
      name: json['name'] as String,
      gender: json['gender'] as String?,
      totalPar: (json['totalPar'] as num?)?.toInt() ?? 0,
      yardages:
          // Accept both typed and untyped (e.g. empty literal) maps.
          (json['yardages'] as Map?)?.map(
            (k, v) => MapEntry(k as String, (v as num?)?.toInt() ?? 0),
          ) ??
          {},
      rating: (json['rating'] as num?)?.toDouble(),
      slope: json['slope'] as int?,
      accuracyClass: json['accuracyClass'] as String? ?? 'D',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (gender != null) 'gender': gender,
    'totalPar': totalPar,
    'yardages': yardages,
    if (rating != null) 'rating': rating,
    if (slope != null) 'slope': slope,
    'accuracyClass': accuracyClass,
  };

  /// Human-readable gender label.
  String? get genderLabel {
    if (gender == null) return null;
    switch (gender!.toUpperCase()) {
      case 'M':
        return 'Men';
      case 'F':
        return 'Women';
      case 'C':
        return 'Champion';
      default:
        // Unknown / unrecognized gender codes have no human-readable label.
        return null;
    }
  }

  @override
  List<Object?> get props => [
    id,
    name,
    gender,
    totalPar,
    yardages,
    rating,
    slope,
    accuracyClass,
  ];
}
