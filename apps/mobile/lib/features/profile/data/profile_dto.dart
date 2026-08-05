// Profile DTOs — VSP Mobile App
//
// Extended golfer profile with all golf-preference fields.
// Matches the OpenAPI contract in packages/contracts/schemas/profile.yaml
// and the backend GolferProfileResponse from Slice 2-3-A.
//
// Canonical storage: all distance values (driverDistance) are stored in METERS.
// Display conversion is a UI concern — canonical values are NEVER modified
// when the golfer changes their distanceUnit preference.

import 'package:equatable/equatable.dart';

// Type alias — existing BLoC code uses GolferProfileDto
typedef GolferProfileDto = ProfileDTO;

// ─── Enums ───────────────────────────────────────────────────────────────────

/// Preferred distance display unit.
enum DistanceUnit {
  meters('METERS'),
  yards('YARDS');

  final String value;
  const DistanceUnit(this.value);

  static DistanceUnit fromString(String value) {
    return DistanceUnit.values.firstWhere(
      (e) => e.value == value.toUpperCase(),
      orElse: () => DistanceUnit.meters,
    );
  }
}

/// Dominant hand for swinging.
enum DominantHand {
  left('LEFT'),
  right('RIGHT');

  final String value;
  const DominantHand(this.value);

  static DominantHand fromString(String value) {
    return DominantHand.values.firstWhere(
      (e) => e.value == value.toUpperCase(),
      orElse: () => DominantHand.right,
    );
  }
}

/// Golfer skill classification.
enum SkillLevel {
  beginner('BEGINNER'),
  intermediate('INTERMEDIATE'),
  advanced('ADVANCED'),
  pro('PRO');

  final String value;
  const SkillLevel(this.value);

  static SkillLevel fromString(String value) {
    return SkillLevel.values.firstWhere(
      (e) => e.value == value.toUpperCase(),
      orElse: () => SkillLevel.intermediate,
    );
  }

  String get displayName {
    switch (this) {
      case SkillLevel.beginner:
        return 'Beginner';
      case SkillLevel.intermediate:
        return 'Intermediate';
      case SkillLevel.advanced:
        return 'Advanced';
      case SkillLevel.pro:
        return 'Professional';
    }
  }
}

/// Gender for statistical and social features.
enum Gender {
  male('MALE'),
  female('FEMALE'),
  other('OTHER');

  final String value;
  const Gender(this.value);

  static Gender fromString(String value) {
    return Gender.values.firstWhere(
      (e) => e.value == value.toUpperCase(),
      orElse: () => Gender.other,
    );
  }
}

// ─── Canonical Conversion ─────────────────────────────────────────────────────

/// Meters-to-yards conversion factor (1 meter = 1.09361 yards).
const double _metersToYardsFactor = 1.09361;

/// Convert a canonical meters value to yards.
double toYards(double meters) => meters * _metersToYardsFactor;

/// Convert a yards value back to canonical meters.
double toMeters(double yards) => yards / _metersToYardsFactor;

// ─── Profile DTO ─────────────────────────────────────────────────────────────

/// Extended golfer profile with all golf-preference fields.
//
// AC-1: all required fields are present
// AC-2: driverDistance is always stored/returned in meters canonical;
//       displayDistance() applies the golfer's distanceUnit preference
// AC-3: serializable for offline queue storage
class ProfileDTO extends Equatable {
  // ─── Identity ─────────────────────────────────────────────────────────────
  final int id;
  final int golferAccountId;

  // ─── Golf Stats ──────────────────────────────────────────────────────────
  final double? handicap;
  final String? homeClub;
  final DistanceUnit distanceUnit;
  final DominantHand dominantHand;
  final SkillLevel skillLevel;
  final int? targetScore; // target round score (e.g. 90)

  // ─── Distance (canonical: meters) ───────────────────────────────────────
  /// Average driver carry distance — always stored in METERS.
  final double? driverDistance;

  // ─── Swing ───────────────────────────────────────────────────────────────
  final double? swingSpeed; // mph

  // ─── Personal ─────────────────────────────────────────────────────────────
  final Gender? gender;
  final int? birthYear;
  final String? country;
  final String? imageUrl;

  // ─── Timestamps ────────────────────────────────────────────────────────────
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProfileDTO({
    required this.id,
    required this.golferAccountId,
    this.handicap,
    this.homeClub,
    this.distanceUnit = DistanceUnit.meters,
    this.dominantHand = DominantHand.right,
    this.skillLevel = SkillLevel.intermediate,
    this.targetScore,
    this.driverDistance,
    this.swingSpeed,
    this.gender,
    this.birthYear,
    this.country,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
  });

  /// Parse from GET /profiles/me JSON response.
  factory ProfileDTO.fromJson(Map<String, dynamic> json) {
    return ProfileDTO(
      id: (json['id'] as num).toInt(),
      golferAccountId: (json['golferAccountId'] as num).toInt(),
      handicap: (json['handicap'] as num?)?.toDouble(),
      homeClub: json['homeClub'] as String?,
      distanceUnit: DistanceUnit.fromString(
        json['distanceUnit'] as String? ?? 'METERS',
      ),
      dominantHand: DominantHand.fromString(
        json['dominantHand'] as String? ?? 'RIGHT',
      ),
      skillLevel: SkillLevel.fromString(
        json['skillLevel'] as String? ?? 'INTERMEDIATE',
      ),
      targetScore: (json['targetScore'] as num?)?.toInt(),
      driverDistance: (json['driverDistance'] as num?)?.toDouble(),
      swingSpeed: (json['swingSpeed'] as num?)?.toDouble(),
      gender: json['gender'] != null
          ? Gender.fromString(json['gender'] as String)
          : null,
      birthYear: (json['birthYear'] as num?)?.toInt(),
      country: json['country'] as String?,
      imageUrl: json['imageUrl'] as String?,
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
    'handicap': handicap,
    'homeClub': homeClub,
    'distanceUnit': distanceUnit.value,
    'dominantHand': dominantHand.value,
    'skillLevel': skillLevel.value,
    'targetScore': targetScore,
    'driverDistance': driverDistance,
    'swingSpeed': swingSpeed,
    'gender': gender?.value,
    'birthYear': birthYear,
    'country': country,
    'imageUrl': imageUrl,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  // ─── AC-2: Unit Conversion ───────────────────────────────────────────────

  /// Convert a meters value to this profile's display unit.
  ///
  /// If distanceUnit is YARDS, multiplies by 1.09361.
  /// If distanceUnit is METERS, returns the value unchanged.
  /// Canonical values are NEVER modified.
  double toDisplayDistance(double? meters) {
    if (meters == null) return 0;
    return distanceUnit == DistanceUnit.yards ? toYards(meters) : meters;
  }

  /// Shortcut: convert driverDistance canonical meters to display value.
  double? get displayDriverDistance =>
      driverDistance != null ? toDisplayDistance(driverDistance!) : null;

  /// Format a meters value as a display string with unit suffix.
  /// e.g. "220 m" or "240 yd"
  String formatDistance(double? meters) {
    if (meters == null) return '—';
    final display = toDisplayDistance(meters);
    final unit = distanceUnit == DistanceUnit.yards ? ' yd' : ' m';
    return '${display.round()}$unit';
  }

  /// Shortcut: format driverDistance as a display string with unit.
  /// e.g. "220 m" or "240 yd"
  String? get displayDriverDistanceLabel =>
      driverDistance != null ? formatDistance(driverDistance) : null;

  /// Human-readable distance unit label ("meters" or "yards").
  String get distanceUnitLabel =>
      distanceUnit == DistanceUnit.yards ? 'yards' : 'meters';

  /// Convert an input display value (in the current display unit) to canonical meters.
  /// Used when saving user input: converts yards → meters if needed.
  double displayToCanonical(double displayValue) {
    return distanceUnit == DistanceUnit.yards
        ? displayValue / 1.09361
        : displayValue;
  }

  // ─── Copy With ────────────────────────────────────────────────────────────

  ProfileDTO copyWith({
    int? id,
    int? golferAccountId,
    double? handicap,
    String? homeClub,
    DistanceUnit? distanceUnit,
    DominantHand? dominantHand,
    SkillLevel? skillLevel,
    int? targetScore,
    double? driverDistance,
    double? swingSpeed,
    Gender? gender,
    int? birthYear,
    String? country,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProfileDTO(
      id: id ?? this.id,
      golferAccountId: golferAccountId ?? this.golferAccountId,
      handicap: handicap ?? this.handicap,
      homeClub: homeClub ?? this.homeClub,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      dominantHand: dominantHand ?? this.dominantHand,
      skillLevel: skillLevel ?? this.skillLevel,
      targetScore: targetScore ?? this.targetScore,
      driverDistance: driverDistance ?? this.driverDistance,
      swingSpeed: swingSpeed ?? this.swingSpeed,
      gender: gender ?? this.gender,
      birthYear: birthYear ?? this.birthYear,
      country: country ?? this.country,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    golferAccountId,
    handicap,
    homeClub,
    distanceUnit,
    dominantHand,
    skillLevel,
    targetScore,
    driverDistance,
    swingSpeed,
    gender,
    birthYear,
    country,
    imageUrl,
    createdAt,
    updatedAt,
  ];
}

// ─── Update Request DTO ──────────────────────────────────────────────────────

/// Partial update request for PUT /profiles/me.
// Only non-null fields are sent to the server (partial update support).
class UpdateProfileRequest extends Equatable {
  final double? handicap;
  final String? homeClub;
  final String? distanceUnit;
  final String? dominantHand;
  final String? skillLevel;
  final int? targetScore;
  final double? driverDistance; // always in meters canonical
  final double? swingSpeed;
  final String? gender;
  final int? birthYear;
  final String? country;
  final String? imageUrl;

  const UpdateProfileRequest({
    this.handicap,
    this.homeClub,
    this.distanceUnit,
    this.dominantHand,
    this.skillLevel,
    this.targetScore,
    this.driverDistance,
    this.swingSpeed,
    this.gender,
    this.birthYear,
    this.country,
    this.imageUrl,
  });

  /// Deserialize from JSON (used by offline queue deserialization).
  factory UpdateProfileRequest.fromJson(Map<String, dynamic> json) {
    return UpdateProfileRequest(
      handicap: (json['handicap'] as num?)?.toDouble(),
      homeClub: json['homeClub'] as String?,
      distanceUnit: json['distanceUnit'] as String?,
      dominantHand: json['dominantHand'] as String?,
      skillLevel: json['skillLevel'] as String?,
      targetScore: (json['targetScore'] as num?)?.toInt(),
      driverDistance: (json['driverDistance'] as num?)?.toDouble(),
      swingSpeed: (json['swingSpeed'] as num?)?.toDouble(),
      gender: json['gender'] as String?,
      birthYear: (json['birthYear'] as num?)?.toInt(),
      country: json['country'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  /// Build from a ProfileDTO — only changed fields are included.
  /// This enables partial updates: server only processes non-null fields.
  factory UpdateProfileRequest.fromDto(ProfileDTO dto) {
    return UpdateProfileRequest(
      handicap: dto.handicap,
      homeClub: dto.homeClub,
      distanceUnit: dto.distanceUnit.value,
      dominantHand: dto.dominantHand.value,
      skillLevel: dto.skillLevel.value,
      targetScore: dto.targetScore,
      driverDistance: dto.driverDistance,
      swingSpeed: dto.swingSpeed,
      gender: dto.gender?.value,
      birthYear: dto.birthYear,
      country: dto.country,
      imageUrl: dto.imageUrl,
    );
  }

  /// Serialize to JSON body for PUT /profiles/me.
  /// Omits null fields for partial update support.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (handicap != null) map['handicap'] = handicap;
    if (homeClub != null) map['homeClub'] = homeClub;
    if (distanceUnit != null) map['distanceUnit'] = distanceUnit;
    if (dominantHand != null) map['dominantHand'] = dominantHand;
    if (skillLevel != null) map['skillLevel'] = skillLevel;
    if (targetScore != null) map['targetScore'] = targetScore;
    if (driverDistance != null) map['driverDistance'] = driverDistance;
    if (swingSpeed != null) map['swingSpeed'] = swingSpeed;
    if (gender != null) map['gender'] = gender;
    if (birthYear != null) map['birthYear'] = birthYear;
    if (country != null) map['country'] = country;
    if (imageUrl != null) map['imageUrl'] = imageUrl;
    return map;
  }

  @override
  List<Object?> get props => [
    handicap,
    homeClub,
    distanceUnit,
    dominantHand,
    skillLevel,
    targetScore,
    driverDistance,
    swingSpeed,
    gender,
    birthYear,
    country,
    imageUrl,
  ];
}
