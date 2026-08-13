// DistanceRingEntity — VSP Mobile App
//
// Concentric distance rings rendered around a center point (golfer or target).

import 'package:equatable/equatable.dart';

/// A single concentric distance ring for range reference.
class DistanceRingEntity extends Equatable {
  /// Unique identifier for this ring.
  final String id;

  /// Center latitude for the ring.
  final double centerLat;

  /// Center longitude for the ring.
  final double centerLng;

  /// Ring radius in meters.
  final int radiusMeters;

  /// Optional label displayed on/near the ring (e.g., "100m").
  final String? label;

  /// Visibility toggle.
  final bool visible;

  const DistanceRingEntity({
    required this.id,
    this.centerLat = 0,
    this.centerLng = 0,
    required this.radiusMeters,
    this.label,
    this.visible = true,
  });

  DistanceRingEntity copyWith({
    String? id,
    double? centerLat,
    double? centerLng,
    int? radiusMeters,
    String? label,
    bool? visible,
  }) {
    return DistanceRingEntity(
      id: id ?? this.id,
      centerLat: centerLat ?? this.centerLat,
      centerLng: centerLng ?? this.centerLng,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      label: label ?? this.label,
      visible: visible ?? this.visible,
    );
  }

  @override
  List<Object?> get props => [
    id,
    centerLat,
    centerLng,
    radiusMeters,
    label,
    visible,
  ];
}

/// Preset distance ring configurations.
class DistanceRingPresets {
  static const ring100 = DistanceRingEntity(
    id: 'ring_100',
    radiusMeters: 100,
  );

  static const ring150 = DistanceRingEntity(
    id: 'ring_150',
    radiusMeters: 150,
  );

  static const ring200 = DistanceRingEntity(
    id: 'ring_200',
    radiusMeters: 200,
  );

  static List<DistanceRingEntity> standardSet({
    required double centerLat,
    required double centerLng,
  }) => [
    ring100.copyWith(centerLat: centerLat, centerLng: centerLng),
    ring150.copyWith(centerLat: centerLat, centerLng: centerLng),
    ring200.copyWith(centerLat: centerLat, centerLng: centerLng),
  ];
}
