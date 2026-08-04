// LatLng — VSP Mobile App
//
// Simple WGS84 coordinate pair used across domain models.
// Mirrors the common LatLng type used in mapping libraries.
// All coordinates are in degrees (WGS84 / SRID 4326).

import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// A WGS84 geographic coordinate.
class LatLng extends Equatable {
  /// Latitude in degrees (-90 to 90).
  final double latitude;

  /// Longitude in degrees (-180 to 180).
  final double longitude;

  const LatLng({required this.latitude, required this.longitude});

  /// Parse from GeoJSON coordinate array [lon, lat].
  factory LatLng.fromGeoJson(List<num> coord) {
    return LatLng(
      longitude: coord[0].toDouble(),
      latitude: coord[1].toDouble(),
    );
  }

  /// Convert to GeoJSON coordinate array [lon, lat].
  List<double> toGeoJson() => [longitude, latitude];

  /// Parse from map annotation (lat, lng) if available.
  factory LatLng.fromMapPosition(double lat, double lng) {
    return LatLng(latitude: lat, longitude: lng);
  }

  /// Haversine distance to [other] in meters.
  /// Suitable for golf distances (<1km range, <0.3% error).
  double distanceTo(LatLng other) {
    return _haversineMeters(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
    );
  }

  /// Haversine distance between two points in meters.
  static double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusM = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusM * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;

  /// Human-readable string for debugging.
  @override
  String toString() => 'LatLng($latitude, $longitude)';

  /// Check if coordinates are valid WGS84 values.
  bool get isValid =>
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  /// Check if this coordinate is near [other] (within [toleranceMeters]).
  bool isNearby(LatLng other, {double toleranceMeters = 100}) {
    return distanceTo(other) < toleranceMeters;
  }

  @override
  List<Object?> get props => [latitude, longitude];
}
