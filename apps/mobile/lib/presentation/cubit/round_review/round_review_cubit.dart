// Round Review Cubit — VSP Mobile App
//
// Manages the Round Review screen state.
// Handles data fetching and loading/error/empty states.
//
// Per Story 11.2: Deliver Driving Zone and Round Analytics.
// AC2: Round review includes required scoring and shot metrics with
//      incomplete-data warnings.

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/hole_repository_impl.dart';
import '../../../data/repositories/shot_repository_impl.dart';
import '../../../domain/models/round_review_metrics.dart';
import '../../../domain/models/score.dart';
import '../../../domain/repositories/hole_repository.dart';
import '../../../domain/repositories/score_repository.dart';
import '../../../data/repositories/score_repository_impl.dart';
import '../../../domain/repositories/shot_repository.dart';
import '../../../features/round/domain/score_entry.dart';
import 'round_review_state.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

/// Cubit for managing the Round Review screen.
class RoundReviewCubit extends Cubit<RoundReviewState> {
  final ShotRepository _shotRepository;
  final ScoreRepository _scoreRepository;
  final HoleRepository _holeRepository;

  /// Currently loaded round ID.
  String? _currentRoundId;

  /// Currently loaded player ID.
  String? _currentPlayerId;

  /// Course and date supplied by the caller, kept so [retry] does not lose
  /// them and drop the header back to "Unknown Course".
  String? _currentCourseName;
  DateTime? _currentRoundDate;

  /// Course the round was played on, used to put a par against each hole.
  int? _currentCourseId;

  RoundReviewCubit({
    ShotRepository? shotRepository,
    ScoreRepository? scoreRepository,
    HoleRepository? holeRepository,
  }) : _shotRepository = shotRepository ?? ShotRepositoryImpl(),
       _scoreRepository = scoreRepository ?? ScoreRepositoryImpl(),
       _holeRepository = holeRepository ?? HoleRepositoryImpl(),
       super(const RoundReviewInitial());

  /// Current round ID.
  String? get currentRoundId => _currentRoundId;

  /// Current player ID.
  String? get currentPlayerId => _currentPlayerId;

  /// Load round review metrics for the given [roundId] and [playerId].
  ///
  /// Per AC2: surfaces incomplete-data warnings when sample size is insufficient.
  Future<void> loadRoundReview({
    required String roundId,
    required String playerId,
    String? courseName,
    DateTime? roundDate,
    int? courseId,
  }) async {
    _currentRoundId = roundId;
    _currentPlayerId = playerId;
    _currentCourseName = courseName ?? _currentCourseName;
    _currentRoundDate = roundDate ?? _currentRoundDate;
    _currentCourseId = courseId ?? _currentCourseId;
    emit(const RoundReviewLoading());

    try {
      final metrics = await _shotRepository.getRoundReviewMetrics(
        roundId: roundId,
        playerId: playerId,
      );

      final played = await _cardOf(metrics.scoring.roundId, playerId);

      emit(
        RoundReviewLoaded(
          metrics: _withHeader(_withScorecard(metrics, playerId, played)),
          holeScores: await _holeEntries(played),
        ),
      );
    } catch (e) {
      emit(
        RoundReviewError(
          message: AppMessages.roundReviewLoadFailed,
          roundId: roundId,
        ),
      );
    }
  }


  /// Names the course and date the round was played on.
  ///
  /// `getRoundReviewMetrics` derives everything from the shot store, which
  /// records neither, so a review built from it alone is headed "Unknown
  /// Course". What the caller already knows is filled in here; what the
  /// metrics already carry wins, and an absent value stays absent rather than
  /// being invented.
  RoundReviewMetrics _withHeader(RoundReviewMetrics metrics) {
    final courseName = metrics.courseName ?? _currentCourseName;
    final roundDate = metrics.roundDate ?? _currentRoundDate;
    if (courseName == metrics.courseName && roundDate == metrics.roundDate) {
      return metrics;
    }
    return RoundReviewMetrics(
      scoring: metrics.scoring,
      shotMetrics: metrics.shotMetrics,
      incompleteDataWarning: metrics.incompleteDataWarning,
      generatedAt: metrics.generatedAt,
      courseName: courseName,
      roundDate: roundDate,
    );
  }

  /// Replaces the shot-derived scoring block with the golfer's actual card.
  ///
  /// `getRoundReviewMetrics` computes `totalGrossScore` as `shots.length +
  /// penalties` — the number of individually tracked shots. A golfer who
  /// enters strokes on the scorecard and never records a shot therefore saw
  /// "Gross 0" under a heading that says Round Summary, next to a card that
  /// says otherwise.
  ///
  /// The shot half of the screen is left exactly as it was: driving zone and
  /// club distances genuinely need tracked shots, and reporting them from a
  /// scorecard would be inventing them.
  /// The golfer's scored holes for this round, newest read from storage.
  ///
  /// A card that cannot be read costs the scoring block, not the whole screen:
  /// the shot metrics beside it are already loaded and still true.
  Future<List<Score>> _cardOf(String roundId, String playerId) async {
    try {
      final scores = await _scoreRepository.getScoresForFlight(roundId);
      return scores
          .where((s) => s.playerId == playerId && s.grossScore != null)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  RoundReviewMetrics _withScorecard(
    RoundReviewMetrics metrics,
    String playerId,
    List<Score> played,
  ) {
    if (played.isEmpty) {
      return metrics;
    }

    int? sumOf(int? Function(Score s) field) {
      final values = played.map(field).whereType<int>();
      return values.isEmpty ? null : values.reduce((a, b) => a + b);
    }

    final girHoles = played.where((s) => s.gir != null);
    final firHoles = played.where((s) => s.fairwayHit != null);

    return RoundReviewMetrics(
      shotMetrics: metrics.shotMetrics,
      incompleteDataWarning: metrics.incompleteDataWarning,
      generatedAt: metrics.generatedAt,
      courseName: metrics.courseName,
      roundDate: metrics.roundDate,
      scoring: RoundScoringSummary(
        roundId: metrics.scoring.roundId,
        playerId: playerId,
        totalGrossScore: played.fold<int>(0, (sum, s) => sum + s.grossScore!),
        totalPutts: sumOf((s) => s.putts),
        totalPenalties: sumOf((s) => s.penalties),
        girCount: girHoles.isEmpty
            ? null
            : girHoles.where((s) => s.gir == true).length,
        girTotal: girHoles.isEmpty ? null : girHoles.length,
        firCount: firHoles.isEmpty
            ? null
            : firHoles.where((s) => s.fairwayHit == true).length,
        firTotal: firHoles.isEmpty ? null : firHoles.length,
        // Up-and-down, sand saves and the birdie/par/bogey split need each
        // hole's par, which the card does not carry here. Left null rather
        // than reported as zero, so the screen shows "–" instead of claiming
        // the golfer made none.
        upAndDownCount: metrics.scoring.upAndDownCount,
        upAndDownTotal: metrics.scoring.upAndDownTotal,
        sandSaveCount: metrics.scoring.sandSaveCount,
        sandSaveTotal: metrics.scoring.sandSaveTotal,
      ),
    );
  }

  /// The card as a list of holes, ordered, with each hole's par where the
  /// course package carries one.
  ///
  /// `Score.holeId` holds the hole number — the same reading the round summary
  /// makes of it. A row whose hole cannot be read is dropped rather than shown
  /// under a made-up number, and par falls back to 0, which the row renders as
  /// "no par known" instead of claiming the golfer was that far over.
  Future<List<ScoreEntry>> _holeEntries(List<Score> played) async {
    if (played.isEmpty) return const [];

    final parByHole = <int, int>{};
    final courseId = _currentCourseId;
    if (courseId != null) {
      try {
        final holes = await _holeRepository.findByCourseWithGeometry(
          '$courseId',
        );
        for (final hole in holes) {
          parByHole[hole.holeNumber] = hole.par;
        }
      } catch (_) {
        // No package for this course on the device — the card still stands,
        // it just cannot say what par was.
      }
    }

    final entries = <ScoreEntry>[];
    for (final score in played) {
      final holeNumber = int.tryParse(score.holeId);
      if (holeNumber == null) continue;
      entries.add(
        ScoreEntry(
          holeNumber: holeNumber,
          par: parByHole[holeNumber] ?? 0,
          strokes: score.grossScore!,
          putts: score.putts,
          penalties: score.penalties,
          fairwayHit: score.fairwayHit,
          gir: score.gir,
          bunker: score.bunker,
          notes: score.notes,
        ),
      );
    }
    entries.sort((a, b) => a.holeNumber.compareTo(b.holeNumber));
    return entries;
  }

  /// Retry the last failed request.
  Future<void> retry() async {
    final roundId = _currentRoundId;
    final playerId = _currentPlayerId;
    if (roundId == null || playerId == null) return;
    await loadRoundReview(roundId: roundId, playerId: playerId);
  }
}
