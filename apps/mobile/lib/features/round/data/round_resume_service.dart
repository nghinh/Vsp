// Round Resume Service — VSP Mobile App
//
// Rebuilds everything an in-progress round needs to be reopened from history.
//
// A round in the history list carries only its id, course and status. Reopening
// it needs the flight's players, a par for every hole, the hole the golfer had
// got to, and — for the map, the satellite basemap and the measuring tool — the
// id of the downloaded course package the round was started against. All four
// are recoverable from what round start already wrote down:
//
//   players       → the local round database, written at round start
//   pars/lengths  → GET /courses/{id}
//   current hole  → the first hole of this round with no score entered yet
//   package id    → the local round row (round start stores the package id it
//                   locked the round to in `packageVersion`; the history API
//                   does not return it at all)
//
// Where a lookup cannot answer, the round still has to be resumable — a golfer
// standing on the 7th tee cannot be told to start over — so each one degrades
// to a documented default or to null rather than throwing. Null matters here:
// an invented package id resolves to no geometry and an invented par is a lie
// on the hole header, so both are reported as unknown instead.

import '../../../core/network/api_client.dart';
import '../../../data/api/course_detail_api.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../data/repositories/round_repository.dart';
import '../../../data/repositories/score_repository_impl.dart';
import '../../../domain/models/round.dart';
import '../../../domain/repositories/score_repository.dart';

/// Everything the active-round screen needs to reopen an in-progress round.
class RoundResumePlan {
  /// Hole ids in play order, as strings ('1'…'18').
  final List<String> holeIds;

  /// Player ids in flight order.
  final List<String> playerIds;

  /// playerId → display name.
  final Map<String, String> playerNames;

  /// holeId → par.
  final Map<String, int> holePars;

  /// Hole the golfer is resuming on: the first hole of this round with no
  /// score entered yet, or the last hole once every hole has one.
  final int currentHole;

  /// Par for [currentHole], or null when the course's real pars could not be
  /// loaded. [holePars] still falls back to par 4 because the scorecard needs
  /// a number for every hole; the round header shows nothing rather than a
  /// guess.
  final int? currentPar;

  /// Playing length of [currentHole] in metres, or null when unknown.
  final int? currentYardage;

  /// Downloaded course package this round was started against, or null when
  /// the round was started without one or the local round row is gone.
  final String? packageId;

  /// True when the course's real per-hole pars could not be loaded and every
  /// hole fell back to par 4.
  final bool parsAreDefaults;

  /// True when no locally-stored players were found and the flight fell back
  /// to the signed-in golfer alone.
  final bool playersAreDefaults;

  const RoundResumePlan({
    required this.holeIds,
    required this.playerIds,
    required this.playerNames,
    required this.holePars,
    required this.currentHole,
    this.currentPar,
    this.currentYardage,
    this.packageId,
    required this.parsAreDefaults,
    required this.playersAreDefaults,
  });
}

/// Builds a [RoundResumePlan] for an in-progress round.
class RoundResumeService {
  /// Par used where the course data does not cover a hole.
  static const int defaultPar = 4;

  /// Hole count assumed when the course detail is unavailable.
  static const int defaultHoleCount = 18;

  /// Player id used for the signed-in golfer, matching the id the round-setup
  /// flow assigns to the primary player.
  static const String selfPlayerId = 'me';

  /// Value round start writes when the course had no downloaded package.
  static const String unknownPackage = 'unknown';

  final PlayerRepository _players;
  final CourseDetailApi _courses;
  final RoundRepository _rounds;
  final ScoreRepository _scores;

  RoundResumeService({
    PlayerRepository? players,
    CourseDetailApi? courses,
    RoundRepository? rounds,
    ScoreRepository? scores,
  }) : _players = players ?? PlayerRepository(),
       _courses = courses ?? CourseDetailApi(apiClient: ApiClient()),
       _rounds = rounds ?? RoundRepository(),
       _scores = scores ?? ScoreRepositoryImpl();

  /// Rebuilds the active-round inputs for [round].
  ///
  /// [selfPlayerName] is the localized name used when the flight cannot be
  /// recovered (round started on another install, or local store wiped).
  Future<RoundResumePlan> planFor(
    Round round, {
    required String selfPlayerName,
  }) async {
    var players = <_ResumePlayer>[];
    try {
      players = [
        for (final p in await _players.getPlayersForRound(round.id))
          _ResumePlayer(p.id, p.name),
      ];
    } catch (_) {
      // No local player store — handled by the fallback below.
    }
    final playersAreDefaults = players.isEmpty;
    if (playersAreDefaults) {
      players = [_ResumePlayer(selfPlayerId, selfPlayerName)];
    }

    var parsByHoleNumber = <int, int>{};
    var lengthsByHoleNumber = <int, int>{};
    try {
      final detail = await _courses.getCourseDetail(round.courseId);
      parsByHoleNumber = {for (final h in detail.holes) h.holeNumber: h.par};
      lengthsByHoleNumber = {
        for (final h in detail.holes)
          if (h.playingLengthMeters != null)
            h.holeNumber: h.playingLengthMeters!,
      };
    } catch (_) {
      // Offline or course removed — handled by the fallback below.
    }
    final parsAreDefaults = parsByHoleNumber.isEmpty;

    final holeNumbers = parsAreDefaults
        ? [for (var h = 1; h <= defaultHoleCount; h++) h]
        : (parsByHoleNumber.keys.toList()..sort());
    final holeIds = [for (final h in holeNumbers) '$h'];

    final currentHole = await _resumeHole(round.id, holeNumbers);

    return RoundResumePlan(
      holeIds: holeIds,
      playerIds: [for (final p in players) p.id],
      playerNames: {for (final p in players) p.id: p.name},
      holePars: {
        for (final h in holeNumbers) '$h': parsByHoleNumber[h] ?? defaultPar,
      },
      currentHole: currentHole,
      // Only the real par, never the par-4 stand-in: the scorecard needs a
      // number for scoring, the hole header does not need to invent one.
      currentPar: parsByHoleNumber[currentHole],
      currentYardage: lengthsByHoleNumber[currentHole],
      packageId: await _packageId(round.id),
      parsAreDefaults: parsAreDefaults,
      playersAreDefaults: playersAreDefaults,
    );
  }

  /// The hole to reopen on: the first one in play order with no score entered.
  ///
  /// A round with every hole scored is waiting to be finished, not to be
  /// played on, so it reopens on its last hole rather than wrapping around.
  /// Without a readable score store the honest answer is the round's first
  /// hole — the golfer can page to where they are in one tap.
  Future<int> _resumeHole(String roundId, List<int> holeNumbers) async {
    if (holeNumbers.isEmpty) return 1;
    try {
      final scores = await _scores.getScoresForFlight(roundId);
      final scored = <int>{};
      for (final score in scores) {
        if (score.grossScore == null) continue;
        final hole = int.tryParse(score.holeId);
        if (hole != null) scored.add(hole);
      }
      for (final hole in holeNumbers) {
        if (!scored.contains(hole)) return hole;
      }
      return holeNumbers.last;
    } catch (_) {
      return holeNumbers.first;
    }
  }

  /// The downloaded package this round was locked to, when there was one.
  ///
  /// Round start stores it in the local round's `packageVersion` column — the
  /// column is named for what it was originally for, but what it holds is the
  /// package id, and it is the only place the id survives: the history API
  /// does not return it.
  Future<String?> _packageId(String roundId) async {
    try {
      final local = await _rounds.getRound(roundId);
      final stored = local?.packageVersion.trim();
      if (stored == null || stored.isEmpty || stored == unknownPackage) {
        return null;
      }
      return stored;
    } catch (_) {
      // No local round store — the map tab says the hole is unsurveyed, which
      // is the same thing it says for a course that was never downloaded.
      return null;
    }
  }
}

class _ResumePlayer {
  final String id;
  final String name;

  const _ResumePlayer(this.id, this.name);
}
