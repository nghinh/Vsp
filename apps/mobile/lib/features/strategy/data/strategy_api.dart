// Course strategy — VSP Mobile App
//
// The whole card at once: the page a caddie would pencil before the round.
// Same facts the per-hole advice computes — shots received, net par, which
// club covers what, this golfer's own record — for all eighteen holes, with
// no model sentence. It is read in the cart and shared to the flight's Zalo,
// which is why it exists as one page rather than eighteen taps.

import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/features/hole_map/data/hole_advice_api.dart'
    show ClubForShot;

class CourseStrategy {
  const CourseStrategy({
    required this.courseName,
    this.backNineCourseName,
    this.handicapUsed,
    this.clubsAreStandard = false,
    this.strokesReceivedTotal,
    this.netParTotal,
    required this.holes,
  });

  final String courseName;

  /// Present when the round is two nines from different courses; [holes]
  /// then runs 1–18 with the back nine renumbered.
  final String? backNineCourseName;

  /// The handicap the allocation ran off — profile's where one exists, the
  /// app-computed one otherwise. Null when neither exists.
  final double? handicapUsed;

  /// True while every carry behind the club picks is still the seeded
  /// standard rather than something this golfer measured.
  final bool clubsAreStandard;

  final int? strokesReceivedTotal;
  final int? netParTotal;

  final List<StrategyHole> holes;

  factory CourseStrategy.fromJson(Map<String, dynamic> json) => CourseStrategy(
    courseName: json['courseName'] as String? ?? '',
    backNineCourseName: json['backNineCourseName'] as String?,
    handicapUsed: (json['handicapUsed'] as num?)?.toDouble(),
    clubsAreStandard: json['clubsAreStandard'] as bool? ?? false,
    strokesReceivedTotal: json['strokesReceivedTotal'] as int?,
    netParTotal: json['netParTotal'] as int?,
    holes: (json['holes'] as List<dynamic>? ?? [])
        .map((e) => StrategyHole.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class StrategyHole {
  const StrategyHole({
    required this.displayHole,
    required this.par,
    this.strokeIndex,
    this.yards,
    this.meters,
    this.strokesReceived,
    this.netPar,
    required this.roundsPlayed,
    this.averageStrokes,
    this.bestStrokes,
    this.clubs = const [],
  });

  /// 1–18 as the golfer plays them, even when the back nine's own card
  /// numbers its holes 1–9.
  final int displayHole;
  final int par;
  final int? strokeIndex;
  final int? yards;
  final double? meters;
  final int? strokesReceived;
  final int? netPar;
  final int roundsPlayed;
  final double? averageStrokes;
  final int? bestStrokes;
  final List<ClubForShot> clubs;

  /// The hole's length in metres — the card's yardage where it exists, the
  /// measured coordinates otherwise.
  double? get lengthMeters =>
      yards != null ? yards! * 0.9144 : meters;

  factory StrategyHole.fromJson(Map<String, dynamic> json) => StrategyHole(
    displayHole: json['displayHole'] as int? ?? 0,
    par: json['par'] as int? ?? 0,
    strokeIndex: json['strokeIndex'] as int?,
    yards: json['yards'] as int?,
    meters: (json['meters'] as num?)?.toDouble(),
    strokesReceived: json['strokesReceived'] as int?,
    netPar: json['netPar'] as int?,
    roundsPlayed: json['roundsPlayed'] as int? ?? 0,
    averageStrokes: (json['averageStrokes'] as num?)?.toDouble(),
    bestStrokes: json['bestStrokes'] as int?,
    clubs: (json['clubs'] as List<dynamic>? ?? [])
        .map((e) => ClubForShot.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class StrategyApi {
  StrategyApi({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<CourseStrategy> forCourse({
    required int courseId,
    int? backNineCourseId,
    String? tee,
  }) async {
    final json = await _apiClient.get(
      '/courses/$courseId/strategy',
      queryParams: {
        if (backNineCourseId != null)
          'backNineCourseId': '$backNineCourseId',
        if (tee != null && tee.isNotEmpty) 'tee': tee,
      },
    );
    return CourseStrategy.fromJson(json as Map<String, dynamic>);
  }
}
