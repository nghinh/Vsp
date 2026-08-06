// Target Model — VSP Mobile App
//
// Domain entity for a user-placed target on the hole map.
// Stores position as SRID 4326 (WGS84) point, GPS confidence,
// placement source, and timestamps.
//
// Story 6.5 — Slice 1: Tap-to-Place Target

import 'package:equatable/equatable.dart';

/// Source of the target placement.
enum TargetSource {
  /// User tapped on the map to place the target.
  tap,

  /// Target was placed via drag gesture.
  drag,

  /// Target was restored from local persistence.
  restored,
}

/// GPS accuracy level for target position.
enum GpsAccuracy {
  /// RTK / high-precision location (< 3m).
  high,

  /// Standard GPS (3–10m).
  medium,

  /// Low-accuracy GPS (> 10m or stale).
  low,

  /// Accuracy unknown (e.g., restored from DB without accuracy metadata).
  unknown,
}

/// A user-placed target on the hole map.
class TargetModel extends Equatable {
  /// Unique identifier for this target placement.
  /// Format: target_{roundId}_{holeNumber}_{uuid}
  final String id;

  /// Round this target belongs to.
  final String roundId;

  /// Hole number (1–18).
  final int holeNumber;

  /// Target position — [longitude, latitude] in SRID 4326 (WGS84).
  /// Stored as GeoJSON-compatible coordinate pair.
  final List<double> position; // [lon, lat]

  /// GPS accuracy at time of placement.
  final GpsAccuracy accuracy;

  /// Source of target placement.
  final TargetSource source;

  /// Timestamp when target was placed.
  final DateTime placedAt;

  /// Timestamp when target was last updated (moved, etc.).
  final DateTime updatedAt;

  const TargetModel({
    required this.id,
    required this.roundId,
    required this.holeNumber,
    required this.position,
    required this.accuracy,
    required this.source,
    required this.placedAt,
    required this.updatedAt,
  });

  /// Longitude from position coordinate.
  double get longitude => position[0];

  /// Latitude from position coordinate.
  double get latitude => position[1];

  /// Creates a new target for tap placement.
  factory TargetModel.placed({
    required String id,
    required String roundId,
    required int holeNumber,
    required List<double> position,
    required GpsAccuracy accuracy,
  }) {
    final now = DateTime.now();
    return TargetModel(
      id: id,
      roundId: roundId,
      holeNumber: holeNumber,
      position: position,
      accuracy: accuracy,
      source: TargetSource.tap,
      placedAt: now,
      updatedAt: now,
    );
  }

  /// Creates a moved copy of this target.
  TargetModel moveTo({
    required List<double> newPosition,
    required GpsAccuracy newAccuracy,
  }) {
    return TargetModel(
      id: id,
      roundId: roundId,
      holeNumber: holeNumber,
      position: newPosition,
      accuracy: newAccuracy,
      source: TargetSource.drag,
      placedAt: placedAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Parses from SQLite row.
  factory TargetModel.fromRow(Map<String, dynamic> row) {
    return TargetModel(
      id: row['id'] as String,
      roundId: row['round_id'] as String,
      holeNumber: (row['hole_number'] as num).toInt(),
      position: [
        (row['longitude'] as num).toDouble(),
        (row['latitude'] as num).toDouble(),
      ],
      accuracy: GpsAccuracy.values.firstWhere(
        (e) => e.name == row['accuracy'],
        orElse: () => GpsAccuracy.unknown,
      ),
      source: TargetSource.values.firstWhere(
        (e) => e.name == row['source'],
        orElse: () => TargetSource.tap,
      ),
      placedAt: DateTime.parse(row['placed_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  /// Converts to SQLite row map.
  Map<String, dynamic> toRow() {
    return {
      'id': id,
      'round_id': roundId,
      'hole_number': holeNumber,
      'longitude': position[0],
      'latitude': position[1],
      'accuracy': accuracy.name,
      'source': source.name,
      'placed_at': placedAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Parse from JSON (API responses if needed in future).
  factory TargetModel.fromJson(Map<String, dynamic> json) {
    final pos = json['position'] as Map<String, dynamic>;
    return TargetModel(
      id: json['id'] as String,
      roundId: json['roundId'] as String,
      holeNumber: (json['holeNumber'] as num).toInt(),
      position: [
        (pos['longitude'] as num).toDouble(),
        (pos['latitude'] as num).toDouble(),
      ],
      accuracy: GpsAccuracy.values.firstWhere(
        (e) => e.name == json['accuracy'],
        orElse: () => GpsAccuracy.unknown,
      ),
      source: TargetSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => TargetSource.tap,
      ),
      placedAt: DateTime.parse(json['placedAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'roundId': roundId,
    'holeNumber': holeNumber,
    'position': {'longitude': position[0], 'latitude': position[1]},
    'accuracy': accuracy.name,
    'source': source.name,
    'placedAt': placedAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [
    id,
    roundId,
    holeNumber,
    position,
    accuracy,
    source,
    placedAt,
    updatedAt,
  ];
}
