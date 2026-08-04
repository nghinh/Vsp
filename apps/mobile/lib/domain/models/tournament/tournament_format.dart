// Tournament TournamentFormat enum — VSP Mobile App
//
// Tournament formats supported per Story 12.1 AC.
//
// Story 12.1 Slice F

/// Supported tournament scoring formats.
enum TournamentFormat {
  /// Total strokes (gross or net) — most common format.
  strokePlay,

  /// Hole-by-hole match play — player vs player.
  matchPlay,

  /// Stability points system — rewards consistent play.
  stableford,
}

extension TournamentFormatExtension on TournamentFormat {
  /// Display label for UI.
  String get label {
    switch (this) {
      case TournamentFormat.strokePlay:
        return 'Stroke Play';
      case TournamentFormat.matchPlay:
        return 'Match Play';
      case TournamentFormat.stableford:
        return 'Stableford';
    }
  }

  /// Parse from API string value.
  static TournamentFormat fromString(String value) {
    switch (value.toLowerCase()) {
      case 'strokeplay':
      case 'stroke_play':
      case 'stroke play':
        return TournamentFormat.strokePlay;
      case 'matchplay':
      case 'match_play':
      case 'match play':
        return TournamentFormat.matchPlay;
      case 'stableford':
        return TournamentFormat.stableford;
      default:
        throw ArgumentError('Unknown TournamentFormat: $value');
    }
  }
}
