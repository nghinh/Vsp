// Bag DTOs — VSP Mobile App
//
// Bag and Club data transfer objects matching the OpenAPI contract
// in packages/contracts/schemas/bag.yaml.
//
// Canonical storage: carryDistance and totalDistance are stored in METERS.
// Display conversion (meters ↔ yards) is a UI concern.

import 'package:equatable/equatable.dart';

import 'package:vsp_mobile/features/measure/domain/measure_units.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;

// ─── Club Type Enum ───────────────────────────────────────────────────────────

/// Golf club type classification.
enum ClubType {
  driver('DRIVER'),
  wood('WOOD'),
  hybrid('HYBRID'),
  iron('IRON'),
  wedge('WEDGE'),
  putter('PUTTER');

  final String value;
  const ClubType(this.value);

  static ClubType fromString(String value) {
    return ClubType.values.firstWhere(
      (e) => e.value == value.toUpperCase(),
      orElse: () => ClubType.iron,
    );
  }

  /// Human-readable display name.
  String get displayName {
    switch (this) {
      case ClubType.driver:
        return 'Driver';
      case ClubType.wood:
        return 'Fairway Wood';
      case ClubType.hybrid:
        return 'Hybrid';
      case ClubType.iron:
        return 'Iron';
      case ClubType.wedge:
        return 'Wedge';
      case ClubType.putter:
        return 'Putter';
    }
  }

  /// Icon name for this club type.
  String get iconName {
    switch (this) {
      case ClubType.driver:
        return 'golf_course';
      case ClubType.wood:
        return 'golf_course';
      case ClubType.hybrid:
        return 'golf_course';
      case ClubType.iron:
        return 'golf_course';
      case ClubType.wedge:
        return 'golf_course';
      case ClubType.putter:
        return 'sports_golf';
    }
  }
}

// ─── Canonical Conversion ─────────────────────────────────────────────────────

/// Meters-to-yards conversion factor (1 meter = 1.09361 yards).
const double _metersToYardsFactor = 1.09361;

/// Convert a canonical meters value to yards.
double bagToYards(double meters) => meters * _metersToYardsFactor;

/// Convert a yards value back to canonical meters.
double bagToMeters(double yards) => yards / _metersToYardsFactor;

// ─── Club DTO ────────────────────────────────────────────────────────────────

/// Club data transfer object — mirrors ClubResponse in bag.yaml.
///
/// AC-1: all club fields (clubType, loft, carryDistance, totalDistance,
///        dispersion, shaft, useDate) are stored.
/// AC-3: hasMinimumData() checks clubType != null && carryDistance != null.
class ClubDTO extends Equatable {
  final int id;
  final int golfBagId;
  final ClubType clubType;
  final double? loft; // degrees
  final double? carryDistance; // meters (canonical)
  final double? totalDistance; // meters (canonical)
  final double?
  dispersion; // degrees — Phase 2 scope, stored but not used in MVP
  final String? shaft;
  final DateTime? useDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ClubDTO({
    required this.id,
    required this.golfBagId,
    required this.clubType,
    this.loft,
    this.carryDistance,
    this.totalDistance,
    this.dispersion,
    this.shaft,
    this.useDate,
    this.createdAt,
    this.updatedAt,
  });

  /// Parse from GET /bags/{bagId}/clubs JSON response.
  factory ClubDTO.fromJson(Map<String, dynamic> json) {
    return ClubDTO(
      id: (json['id'] as num).toInt(),
      golfBagId: (json['golfBagId'] as num).toInt(),
      clubType: ClubType.fromString(json['clubType'] as String? ?? 'IRON'),
      loft: (json['loft'] as num?)?.toDouble(),
      carryDistance: (json['carryDistance'] as num?)?.toDouble(),
      totalDistance: (json['totalDistance'] as num?)?.toDouble(),
      dispersion: (json['dispersion'] as num?)?.toDouble(),
      shaft: json['shaft'] as String?,
      useDate: json['useDate'] != null
          ? DateTime.tryParse(json['useDate'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Serialize to JSON (for offline queue storage).
  Map<String, dynamic> toJson() => {
    'id': id,
    'golfBagId': golfBagId,
    'clubType': clubType.value,
    'loft': loft,
    'carryDistance': carryDistance,
    'totalDistance': totalDistance,
    'dispersion': dispersion,
    'shaft': shaft,
    'useDate': useDate?.toIso8601String().split('T').first,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  /// AC-3: minimum data threshold check.
  ///
  /// A club counts once it has a carry distance. It used to also test
  /// `clubType != null`, which is a required non-nullable field — the test
  /// could not fail, and reading the line suggested a club without a type was
  /// a state the app handles.
  bool get hasMinimumData => carryDistance != null;

  /// Carry distance in the golfer's own unit, e.g. `220 m` / `241 yd`.
  ///
  /// Takes the unit rather than a `'meters'`/`'yards'` string. The string
  /// version defaulted to metres, so every caller that forgot to pass one
  /// silently showed metres — which is how the bag came to print metres for a
  /// golfer who had saved yards, while the shot-entry club picker printed
  /// yards for the same club by passing the literal `'yards'`.
  String formatCarryDistance(DistanceUnit unit) => carryDistance == null
      ? '—'
      : MeasureUnits.format(carryDistance!, unit);

  /// Total distance in the golfer's own unit.
  String formatTotalDistance(DistanceUnit unit) => totalDistance == null
      ? '—'
      : MeasureUnits.format(totalDistance!, unit);

  ClubDTO copyWith({
    int? id,
    int? golfBagId,
    ClubType? clubType,
    double? loft,
    double? carryDistance,
    double? totalDistance,
    double? dispersion,
    String? shaft,
    DateTime? useDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClubDTO(
      id: id ?? this.id,
      golfBagId: golfBagId ?? this.golfBagId,
      clubType: clubType ?? this.clubType,
      loft: loft ?? this.loft,
      carryDistance: carryDistance ?? this.carryDistance,
      totalDistance: totalDistance ?? this.totalDistance,
      dispersion: dispersion ?? this.dispersion,
      shaft: shaft ?? this.shaft,
      useDate: useDate ?? this.useDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    golfBagId,
    clubType,
    loft,
    carryDistance,
    totalDistance,
    dispersion,
    shaft,
    useDate,
    createdAt,
    updatedAt,
  ];
}

// ─── Bag DTO ─────────────────────────────────────────────────────────────────

/// Golf bag data transfer object — mirrors GolfBagResponse in bag.yaml.
///
/// AC-2: exactly one bag is active. The active bag is used for round setup.
class BagDTO extends Equatable {
  final int id;
  final int golferAccountId;
  final String name;
  final bool isActive;
  final List<ClubDTO> clubs;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BagDTO({
    required this.id,
    required this.golferAccountId,
    required this.name,
    required this.isActive,
    this.clubs = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// Parse from GET /bags JSON response (list item).
  factory BagDTO.fromJson(Map<String, dynamic> json) {
    return BagDTO(
      id: (json['id'] as num).toInt(),
      golferAccountId: (json['golferAccountId'] as num).toInt(),
      name: json['name'] as String,
      isActive: json['isActive'] as bool? ?? false,
      clubs:
          (json['clubs'] as List<dynamic>?)
              ?.map((e) => ClubDTO.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Serialize to JSON (for offline queue storage).
  Map<String, dynamic> toJson() => {
    'id': id,
    'golferAccountId': golferAccountId,
    'name': name,
    'isActive': isActive,
    'clubs': clubs.map((c) => c.toJson()).toList(),
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  /// AC-3: check if this bag has minimum club data for recommendations.
  /// Threshold: at least one club with a non-null carryDistance.
  bool get hasMinimumClubData => clubs.any((club) => club.hasMinimumData);

  /// Number of clubs in this bag.
  int get clubCount => clubs.length;

  BagDTO copyWith({
    int? id,
    int? golferAccountId,
    String? name,
    bool? isActive,
    List<ClubDTO>? clubs,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BagDTO(
      id: id ?? this.id,
      golferAccountId: golferAccountId ?? this.golferAccountId,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      clubs: clubs ?? this.clubs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    golferAccountId,
    name,
    isActive,
    clubs,
    createdAt,
    updatedAt,
  ];
}

// ─── Create Club Request ─────────────────────────────────────────────────────

/// Request DTO for POST /bags/{bagId}/clubs.
class CreateClubRequest extends Equatable {
  final String clubType;
  final double? loft;
  final double? carryDistance; // meters (canonical)
  final double? totalDistance; // meters (canonical)
  final double? dispersion; // Phase 2 scope
  final String? shaft;
  final String? useDate; // ISO date string YYYY-MM-DD

  const CreateClubRequest({
    required this.clubType,
    this.loft,
    this.carryDistance,
    this.totalDistance,
    this.dispersion,
    this.shaft,
    this.useDate,
  });

  factory CreateClubRequest.fromDto(ClubDTO dto) {
    return CreateClubRequest(
      clubType: dto.clubType.value,
      loft: dto.loft,
      carryDistance: dto.carryDistance,
      totalDistance: dto.totalDistance,
      dispersion: dto.dispersion,
      shaft: dto.shaft,
      useDate: dto.useDate?.toIso8601String().split('T').first,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'clubType': clubType};
    if (loft != null) map['loft'] = loft;
    if (carryDistance != null) map['carryDistance'] = carryDistance;
    if (totalDistance != null) map['totalDistance'] = totalDistance;
    if (dispersion != null) map['dispersion'] = dispersion;
    if (shaft != null) map['shaft'] = shaft;
    if (useDate != null) map['useDate'] = useDate;
    return map;
  }

  @override
  List<Object?> get props => [
    clubType,
    loft,
    carryDistance,
    totalDistance,
    dispersion,
    shaft,
    useDate,
  ];
}

// ─── Update Club Request ─────────────────────────────────────────────────────

/// Request DTO for PUT /bags/{bagId}/clubs/{clubId}.
/// All fields are optional (partial update support).
class UpdateClubRequest extends Equatable {
  final String? clubType;
  final double? loft;
  final double? carryDistance; // meters (canonical)
  final double? totalDistance; // meters (canonical)
  final double? dispersion; // Phase 2 scope
  final String? shaft;
  final String? useDate; // ISO date string YYYY-MM-DD

  const UpdateClubRequest({
    this.clubType,
    this.loft,
    this.carryDistance,
    this.totalDistance,
    this.dispersion,
    this.shaft,
    this.useDate,
  });

  factory UpdateClubRequest.fromDto(ClubDTO dto) {
    return UpdateClubRequest(
      clubType: dto.clubType.value,
      loft: dto.loft,
      carryDistance: dto.carryDistance,
      totalDistance: dto.totalDistance,
      dispersion: dto.dispersion,
      shaft: dto.shaft,
      useDate: dto.useDate?.toIso8601String().split('T').first,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (clubType != null) map['clubType'] = clubType;
    if (loft != null) map['loft'] = loft;
    if (carryDistance != null) map['carryDistance'] = carryDistance;
    if (totalDistance != null) map['totalDistance'] = totalDistance;
    if (dispersion != null) map['dispersion'] = dispersion;
    if (shaft != null) map['shaft'] = shaft;
    if (useDate != null) map['useDate'] = useDate;
    return map;
  }

  @override
  List<Object?> get props => [
    clubType,
    loft,
    carryDistance,
    totalDistance,
    dispersion,
    shaft,
    useDate,
  ];
}

// ─── Create Bag Request ──────────────────────────────────────────────────────

/// Request DTO for POST /bags.
class CreateBagRequest extends Equatable {
  final String name;

  const CreateBagRequest({required this.name});

  Map<String, dynamic> toJson() => {'name': name};

  @override
  List<Object?> get props => [name];
}

// ─── Update Bag Request ──────────────────────────────────────────────────────

/// Request DTO for PUT /bags/{bagId}.
/// All fields optional (partial update support).
class UpdateBagRequest extends Equatable {
  final String? name;
  final bool? isActive;

  const UpdateBagRequest({this.name, this.isActive});

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (isActive != null) map['isActive'] = isActive;
    return map;
  }

  @override
  List<Object?> get props => [name, isActive];
}
