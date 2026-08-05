// Round Resume Service — VSP Mobile App
//
// Rebuilds everything the scorecard needs to reopen a round that was started
// but never finished.
//
// A round in the history list carries only its id, course and status; the
// scorecard needs the flight's players and a par for every hole. Both are
// recoverable: players from the local round database (written at round start),
// pars from GET /courses/{id}. Where neither is available the round still has
// to be resumable — a golfer standing on the 7th tee cannot be told to start
// over — so each lookup degrades to a documented default instead of throwing.

import '../../../core/network/api_client.dart';
import '../../../data/api/course_detail_api.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../domain/models/round.dart';

/// Everything [ScorecardScreen] needs to reopen an in-progress round.
class RoundResumePlan {
  /// Hole ids in play order, as strings ('1'…'18').
  final List<String> holeIds;

  /// Player ids in flight order.
  final List<String> playerIds;

  /// playerId → display name.
  final Map<String, String> playerNames;

  /// holeId → par.
  final Map<String, int> holePars;

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

  final PlayerRepository _players;
  final CourseDetailApi _courses;

  RoundResumeService({PlayerRepository? players, CourseDetailApi? courses})
    : _players = players ?? PlayerRepository(),
      _courses = courses ?? CourseDetailApi(apiClient: ApiClient());

  /// Rebuilds the scorecard inputs for [round].
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
    try {
      final detail = await _courses.getCourseDetail(round.courseId);
      parsByHoleNumber = {for (final h in detail.holes) h.holeNumber: h.par};
    } catch (_) {
      // Offline or course removed — handled by the fallback below.
    }
    final parsAreDefaults = parsByHoleNumber.isEmpty;

    final holeNumbers = parsAreDefaults
        ? [for (var h = 1; h <= defaultHoleCount; h++) h]
        : (parsByHoleNumber.keys.toList()..sort());
    final holeIds = [for (final h in holeNumbers) '$h'];

    return RoundResumePlan(
      holeIds: holeIds,
      playerIds: [for (final p in players) p.id],
      playerNames: {for (final p in players) p.id: p.name},
      holePars: {
        for (final h in holeNumbers) '$h': parsByHoleNumber[h] ?? defaultPar,
      },
      parsAreDefaults: parsAreDefaults,
      playersAreDefaults: playersAreDefaults,
    );
  }
}

class _ResumePlayer {
  final String id;
  final String name;

  const _ResumePlayer(this.id, this.name);
}
