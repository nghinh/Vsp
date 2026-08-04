// FlightDto — VSP Contracts Package
//
// API serialization model for Flight entity.
// Mirrors Flight domain model in apps/mobile/lib/domain/models/flight.dart.
//
// Story 5.3 — Slice 1: Domain Models & Contracts

/// Flight DTO for API request/response serialization.
class FlightDto {
  final String id;
  final String roundId;
  final int flightIndex;
  final List<String> playerIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FlightDto({
    required this.id,
    required this.roundId,
    required this.flightIndex,
    required this.playerIds,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Parse from API response JSON.
  factory FlightDto.fromJson(Map<String, dynamic> json) {
    return FlightDto(
      id: json['id'] as String,
      roundId: json['roundId'] as String,
      flightIndex: json['flightIndex'] as int,
      playerIds: (json['playerIds'] as List<dynamic>).cast<String>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'roundId': roundId,
        'flightIndex': flightIndex,
        'playerIds': playerIds,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
