// Distance Type Enum — VSP Mobile App
//
// All distance measurement types used in the app.
// Covers green, hazard, OB, dogleg, layup, and target distances.
//
// Story 6.4 — Wave 1: Domain models

/// Types of distance measurements used in the app.
enum DistanceType {
  // ─── Green distances ────────────────────────────────────────────────────────
  /// Front edge of the green — minimum perpendicular distance to green polygon.
  frontGreen('Front Green', 'Front'),

  /// Center of the green — minimum straight-line distance to green polygon.
  centerGreen('Center Green', 'Center'),

  /// Back edge of the green — maximum straight-line distance to green polygon.
  backGreen('Back Green', 'Back'),

  /// Pin position distance (straight-line to pin).
  pin('Pin', 'Pin'),

  // ─── Hazard distances ────────────────────────────────────────────────────────
  /// Bunker — nearest point on the bunker polygon.
  bunkerNear('Bunker Near', 'Bunker Near'),

  /// Bunker — farthest point on the bunker polygon.
  bunkerFar('Bunker Far', 'Bunker Far'),

  /// Bunker — carry distance through bunker to green boundary.
  bunkerCarry('Bunker Carry', 'Bunker Carry'),

  /// Water — nearest point on the water/penalty area polygon.
  waterNear('Water Near', 'Water Near'),

  /// Water — farthest point on the water/penalty area polygon.
  waterFar('Water Far', 'Water Far'),

  /// Water — carry distance through water to green boundary.
  waterCarry('Water Carry', 'Water Carry'),

  // ─── OB / Penalty ───────────────────────────────────────────────────────────
  /// Out-of-bounds — minimum distance to OB boundary.
  ob('OB', 'OB'),

  // ─── Strategic distances ────────────────────────────────────────────────────
  /// Dogleg — distance to the bend/corner of a dogleg hole.
  dogleg('Dogleg', 'Dogleg'),

  /// Layup — recommended layup distance before a hazard.
  layup('Layup', 'Layup'),

  // ─── Target distances ───────────────────────────────────────────────────────
  /// Ball to user-placed target.
  target('Target', 'Target'),

  /// Target to pin distance.
  targetToPin('Target → Pin', 'T→Pin');

  /// Full display name, e.g. "Front Green".
  final String displayName;

  /// Short label for compact UI, e.g. "Front".
  final String shortLabel;

  const DistanceType(this.displayName, this.shortLabel);

  /// True if this is a green distance type.
  bool get isGreen =>
      this == DistanceType.frontGreen ||
      this == DistanceType.centerGreen ||
      this == DistanceType.backGreen ||
      this == DistanceType.pin;

  /// True if this is a bunker distance type.
  bool get isBunker =>
      this == DistanceType.bunkerNear ||
      this == DistanceType.bunkerFar ||
      this == DistanceType.bunkerCarry;

  /// True if this is a water/penalty area distance type.
  bool get isWater =>
      this == DistanceType.waterNear ||
      this == DistanceType.waterFar ||
      this == DistanceType.waterCarry;

  /// True if this is a carry distance type (through a hazard).
  bool get isCarry =>
      this == DistanceType.bunkerCarry || this == DistanceType.waterCarry;

  /// True if this is a hazard distance (near/far for bunker or water).
  bool get isHazard =>
      (this == DistanceType.bunkerNear ||
      this == DistanceType.bunkerFar ||
      this == DistanceType.waterNear ||
      this == DistanceType.waterFar ||
      this == DistanceType.bunkerCarry ||
      this == DistanceType.waterCarry);

  /// True if this is a target distance type.
  bool get isTarget =>
      this == DistanceType.target || this == DistanceType.targetToPin;
}
