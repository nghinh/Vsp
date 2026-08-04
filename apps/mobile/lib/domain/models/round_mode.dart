// Round Mode Enum — VSP Mobile App
//
// Game mode (scoring system) for a round.
//
// Story 5.1 — Slice A: Domain Models

/// Round scoring modes.
///
/// - strokePlay: Standard stroke-count scoring (MVP fully supported).
/// - stableford: Points-based scoring (future — locked in MVP).
enum RoundMode {
  strokePlay('STROKE_PLAY'),
  stableford('STABLEFORD');

  final String value;
  const RoundMode(this.value);

  static RoundMode fromString(String value) {
    return RoundMode.values.firstWhere(
      (e) => e.value == value.toUpperCase(),
      orElse: () => RoundMode.strokePlay,
    );
  }

  /// Display label for UI.
  String get label {
    switch (this) {
      case RoundMode.strokePlay:
        return 'Stroke Play';
      case RoundMode.stableford:
        return 'Stableford';
    }
  }

  /// True if this mode is fully implemented and unlocked.
  ///
  /// MVP: only strokePlay is unlocked. Stableford is future work.
  bool get isUnlocked => this == RoundMode.strokePlay;
}
