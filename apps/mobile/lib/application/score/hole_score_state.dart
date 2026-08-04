// Hole Score State — VSP Mobile App
//
// State classes for hole-level score entry.
//
// Story 5.3 — Slice 3: Score Entry UI

import 'package:equatable/equatable.dart';

import '../../../domain/models/score.dart';

/// State for a single hole's score entry form.
class HoleScoreState extends Equatable {
  /// The flight ID for this hole.
  final String flightId;

  /// The hole ID being scored.
  final String holeId;

  /// Player ID → Score map for this hole.
  final Map<String, Score> scores;

  /// True if scores are currently being loaded.
  final bool isLoading;

  /// Error message if loading failed.
  final String? errorMessage;

  /// True if there are unsaved changes.
  final bool hasUnsavedChanges;

  const HoleScoreState({
    required this.flightId,
    required this.holeId,
    this.scores = const {},
    this.isLoading = false,
    this.errorMessage,
    this.hasUnsavedChanges = false,
  });

  /// Returns the score for a specific player on this hole.
  Score? getScoreForPlayer(String playerId) => scores[playerId];

  /// Returns true if all players have entered a score for this hole.
  bool get isComplete {
    if (scores.isEmpty) return false;
    return scores.values.every((s) => s.hasScore);
  }

  /// Number of players who have entered a score.
  int get filledCount {
    return scores.values.where((s) => s.hasScore).length;
  }

  HoleScoreState copyWith({
    String? flightId,
    String? holeId,
    Map<String, Score>? scores,
    bool? isLoading,
    String? errorMessage,
    bool? hasUnsavedChanges,
  }) {
    return HoleScoreState(
      flightId: flightId ?? this.flightId,
      holeId: holeId ?? this.holeId,
      scores: scores ?? this.scores,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
    );
  }

  @override
  List<Object?> get props => [
    flightId,
    holeId,
    scores,
    isLoading,
    errorMessage,
    hasUnsavedChanges,
  ];
}
