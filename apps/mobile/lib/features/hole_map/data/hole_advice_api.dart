// Hole advice — VSP Mobile App
//
// What one golfer should think about standing on one tee. The numbers on the
// header — 415 yards, par 4, index 4 — are the same for everyone; this is the
// part that depends on who is asking.
//
// The facts and the sentence arrive separately and are treated separately. A
// deployment with no model configured returns the facts and a null advice, and
// the sheet still has a golfer's own scoring record to show. Treating that as
// a failed request would hide their history from them over a server setting.

import 'package:vsp_mobile/core/network/api_client.dart';

/// One hole as this golfer should see it before playing it.
class HoleAdvice {
  const HoleAdvice({
    required this.par,
    this.strokeIndex,
    this.yards,
    this.meters,
    this.tee,
    required this.roundsPlayed,
    this.averageStrokes,
    this.bestStrokes,
    this.fairwaysHit,
    this.greensInRegulation,
    this.strokesReceived,
    this.netPar,
    this.clubs = const [],
    this.advice,
    this.cached = false,
  });

  final int par;

  /// Null where the club published no index row — most of the country.
  final int? strokeIndex;

  /// The tee's own yardage, and the hole's measured length in metres. Both,
  /// because the card and the coordinates are different evidence and the
  /// golfer's unit preference decides which is shown.
  final int? yards;
  final double? meters;
  final String? tee;

  final int roundsPlayed;
  final double? averageStrokes;
  final int? bestStrokes;
  final int? fairwaysHit;
  final int? greensInRegulation;

  /// How many shots this golfer receives here, from their handicap and the
  /// hole's stroke index. Null when either is unknown — half the country's
  /// cards publish no index, and guessing one hands out shots on the wrong
  /// holes.
  final int? strokesReceived;

  /// Par plus the shots received: what this golfer is really playing it in.
  final int? netPar;

  /// Which club covers each shot the hole asks for, from the carry distances
  /// in this golfer's own bag. Empty when the bag has none — there is no table
  /// of averages, because a 7-iron is not a distance.
  final List<ClubForShot> clubs;

  /// Null when the server has no model configured. Never a placeholder.
  final String? advice;

  /// True when the sentence came from the server's cache rather than the
  /// model, so a refresh control can exist without guessing.
  final bool cached;

  bool get hasHistory => roundsPlayed > 0;

  factory HoleAdvice.fromJson(Map<String, dynamic> json) => HoleAdvice(
    par: json['par'] as int? ?? 0,
    strokeIndex: json['strokeIndex'] as int?,
    yards: json['yards'] as int?,
    meters: (json['meters'] as num?)?.toDouble(),
    tee: json['tee'] as String?,
    roundsPlayed: json['roundsPlayed'] as int? ?? 0,
    averageStrokes: (json['averageStrokes'] as num?)?.toDouble(),
    bestStrokes: json['bestStrokes'] as int?,
    fairwaysHit: json['fairwaysHit'] as int?,
    greensInRegulation: json['greensInRegulation'] as int?,
    strokesReceived: json['strokesReceived'] as int?,
    netPar: json['netPar'] as int?,
    clubs: (json['clubs'] as List<dynamic>? ?? [])
        .map((e) => ClubForShot.fromJson(e as Map<String, dynamic>))
        .toList(),
    advice: json['advice'] as String?,
    cached: json['cached'] as bool? ?? false,
  );
}

/// One shot of the hole, and the club that covers it.
class ClubForShot {
  const ClubForShot({
    required this.shot,
    required this.label,
    required this.remainingMeters,
    this.club,
    this.carryMeters,
  });

  final int shot;
  final String label;
  final int remainingMeters;

  /// Null where nothing in the bag reaches — which is itself the answer.
  final String? club;
  final int? carryMeters;

  factory ClubForShot.fromJson(Map<String, dynamic> json) => ClubForShot(
    shot: json['shot'] as int? ?? 0,
    label: json['label'] as String? ?? '',
    remainingMeters: json['remainingMeters'] as int? ?? 0,
    club: json['club'] as String?,
    carryMeters: json['carryMeters'] as int?,
  );
}

class HoleAdviceApi {
  HoleAdviceApi({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// The hole, this golfer's record on it, and what to think about.
  ///
  /// [tee] narrows the yardage to the set the golfer is actually playing;
  /// omitted, the server answers with the longest it has.
  Future<HoleAdvice> forHole({
    required int courseId,
    required int holeNumber,
    String? tee,
  }) async {
    final json = await _apiClient.get(
      '/courses/$courseId/holes/$holeNumber/advice',
      queryParams: tee != null && tee.isNotEmpty ? {'tee': tee} : null,
    );
    return HoleAdvice.fromJson(json as Map<String, dynamic>);
  }
}
