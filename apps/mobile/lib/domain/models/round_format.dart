// Round Format Enum — VSP Mobile App
//
// Supported round formats per PRD §8.4 and UX spec §5.2.
//
// Story 5.1 — Slice A: Domain Models

/// Round format types supported by the platform.
///
/// - casual:  Informal round, no stakes, no restrictions.
/// - practice: Practice round, scores not submitted to official record.
/// - tournament: Tournament round, feature restrictions apply (Tournament Mode).
enum RoundFormat {
  casual('CASUAL'),
  practice('PRACTICE'),
  tournament('TOURNAMENT');

  final String value;
  const RoundFormat(this.value);

  static RoundFormat fromString(String value) {
    return RoundFormat.values.firstWhere(
      (e) => e.value == value.toUpperCase(),
      orElse: () => RoundFormat.casual,
    );
  }

  /// Display label for UI.
  String get label {
    switch (this) {
      case RoundFormat.casual:
        return 'Casual';
      case RoundFormat.practice:
        return 'Practice';
      case RoundFormat.tournament:
        return 'Tournament';
    }
  }
}
