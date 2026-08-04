// ScoreEntry Model — VSP Mobile App
//
// Per-hole score entry for round summary display.
// Per Story 5.5 Slice 2: AC-2 summary display.

/// A single hole's score entry in the round summary.
class ScoreEntry {
  final int holeNumber;
  final int par;
  final int strokes;
  final int? putts;
  final int? penalties;
  final bool? fairwayHit; // null for par-3
  final bool? gir;
  final bool? bunker;
  final String? club;
  final String? notes;

  const ScoreEntry({
    required this.holeNumber,
    required this.par,
    required this.strokes,
    this.putts,
    this.penalties,
    this.fairwayHit,
    this.gir,
    this.bunker,
    this.club,
    this.notes,
  });

  /// Score relative to par.
  int get relativeToPar => strokes - par;

  /// Score notation (e.g., "Birdie", "Par", "Bogey").
  String get scoreNotation {
    final diff = relativeToPar;
    if (diff < -2) return 'Eagle';
    if (diff == -2) return 'Albatross';
    if (diff == -1) return 'Birdie';
    if (diff == 0) return 'Par';
    if (diff == 1) return 'Bogey';
    if (diff == 2) return 'Double Bogey';
    return '+${diff}';
  }

  Map<String, dynamic> toMap() => {
    'holeNumber': holeNumber,
    'par': par,
    'strokes': strokes,
    'putts': putts,
    'penalties': penalties,
    'fairwayHit': fairwayHit,
    'gir': gir,
    'bunker': bunker,
    'club': club,
    'notes': notes,
  };

  factory ScoreEntry.fromMap(Map<String, dynamic> map) {
    return ScoreEntry(
      holeNumber: map['holeNumber'] as int,
      par: map['par'] as int,
      strokes: map['strokes'] as int,
      putts: map['putts'] as int?,
      penalties: map['penalties'] as int?,
      fairwayHit: map['fairwayHit'] as bool?,
      gir: map['gir'] as bool?,
      bunker: map['bunker'] as bool?,
      club: map['club'] as String?,
      notes: map['notes'] as String?,
    );
  }
}
