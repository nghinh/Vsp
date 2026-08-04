// GolferPositionEntity — VSP Mobile App
//
// GPS-derived golfer position on the hole.

import 'package:equatable/equatable.dart';

/// Source of golfer position.
enum PositionSource { gps, wifi, manual }

/// Confidence level for position quality.
enum PositionConfidence { high, medium, low }

/// Golfer's current GPS position and accuracy metadata.
class GolferPositionEntity extends Equatable {
  final double latitude;
  final double longitude;
  final double? accuracy; // meters
  final PositionSource source;
  final PositionConfidence confidence;
  final DateTime timestamp;
  final bool isStale;

  const GolferPositionEntity({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.source,
    required this.confidence,
    required this.timestamp,
    this.isStale = false,
  });

  bool get isHighConfidence => confidence == PositionConfidence.high;
  bool get isLowConfidence => confidence == PositionConfidence.low;

  /// Accuracy radius in degrees (approximate, for rendering accuracy circle).
  double? get accuracyDegrees {
    if (accuracy == null) return null;
    // 1 degree ≈ 111,000 meters at equator
    return accuracy! / 111000.0;
  }

  GolferPositionEntity copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    PositionSource? source,
    PositionConfidence? confidence,
    DateTime? timestamp,
    bool? isStale,
  }) {
    return GolferPositionEntity(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      timestamp: timestamp ?? this.timestamp,
      isStale: isStale ?? this.isStale,
    );
  }

  @override
  List<Object?> get props => [
    latitude,
    longitude,
    accuracy,
    source,
    confidence,
    timestamp,
    isStale,
  ];
}
