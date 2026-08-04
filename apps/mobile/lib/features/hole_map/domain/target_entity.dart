// TargetEntity — VSP Mobile App
//
// User-placed target marker on the hole map.

import 'package:equatable/equatable.dart';

/// A target placed by the golfer for distance reference or strategy planning.
class TargetEntity extends Equatable {
  final String id;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final String? label;

  const TargetEntity({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.label,
  });

  TargetEntity copyWith({
    String? id,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    String? label,
  }) {
    return TargetEntity(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      label: label ?? this.label,
    );
  }

  @override
  List<Object?> get props => [id, latitude, longitude, createdAt, label];
}
