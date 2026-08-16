// My performance — VSP Mobile App
//
// The golfer's own record, counted from their own rounds. Every field can be
// null and several usually are: nobody records putts on a casual round, and
// most golfers never tick a fairway. Null means "nothing was written down",
// which the screen shows as a dash — a confident 0% would be a different
// claim entirely, and a wrong one.

import 'package:vsp_mobile/core/network/api_client.dart';

/// The three ways a golfer asks the question: how do I play, how am I
/// playing, how did the last few go.
enum PerformanceWindow {
  allTime(null),
  last20(20),
  last5(5);

  const PerformanceWindow(this.rounds);

  final int? rounds;
}

class ScoreBucket {
  const ScoreBucket({
    required this.label,
    required this.holes,
    required this.percent,
  });

  /// EAGLE_OR_BETTER, BIRDIE, PAR, BOGEY, DOUBLE_BOGEY, TRIPLE_OR_WORSE.
  final String label;
  final int holes;
  final double percent;

  factory ScoreBucket.fromJson(Map<String, dynamic> json) => ScoreBucket(
    label: json['label'] as String? ?? '',
    holes: json['holes'] as int? ?? 0,
    percent: (json['percent'] as num?)?.toDouble() ?? 0,
  );
}

class ParAverage {
  const ParAverage({
    required this.par,
    required this.holes,
    required this.average,
    this.best,
    this.worst,
  });

  final int par;
  final int holes;
  final double average;
  final int? best;
  final int? worst;

  factory ParAverage.fromJson(Map<String, dynamic> json) => ParAverage(
    par: json['par'] as int? ?? 0,
    holes: json['holes'] as int? ?? 0,
    average: (json['average'] as num?)?.toDouble() ?? 0,
    best: json['best'] as int?,
    worst: json['worst'] as int?,
  );
}

class Performance {
  const Performance({
    required this.rounds,
    required this.holes,
    this.handicap,
    this.bestToPar,
    this.bestToParHoles,
    this.strokesOverParPerHole,
    this.puttsPerHole,
    this.holesWithPutts = 0,
    this.girPercent,
    this.holesWithGir = 0,
    this.fairwayPercent,
    this.holesWithFairway = 0,
    this.penaltiesPerRound,
    this.distribution = const [],
    this.byPar = const [],
  });

  final int rounds;
  final int holes;
  final double? handicap;

  /// The best round against par, and the size of card it was played on —
  /// "+9" over nine holes is not "+9" over eighteen.
  final int? bestToPar;
  final int? bestToParHoles;

  final double? strokesOverParPerHole;

  final double? puttsPerHole;
  final int holesWithPutts;
  final double? girPercent;
  final int holesWithGir;
  final double? fairwayPercent;
  final int holesWithFairway;
  final double? penaltiesPerRound;

  final List<ScoreBucket> distribution;
  final List<ParAverage> byPar;

  bool get isEmpty => rounds == 0;

  factory Performance.fromJson(Map<String, dynamic> json) => Performance(
    rounds: json['rounds'] as int? ?? 0,
    holes: json['holes'] as int? ?? 0,
    handicap: (json['handicap'] as num?)?.toDouble(),
    bestToPar: json['bestToPar'] as int?,
    bestToParHoles: json['bestToParHoles'] as int?,
    strokesOverParPerHole:
        (json['strokesOverParPerHole'] as num?)?.toDouble(),
    puttsPerHole: (json['puttsPerHole'] as num?)?.toDouble(),
    holesWithPutts: json['holesWithPutts'] as int? ?? 0,
    girPercent: (json['girPercent'] as num?)?.toDouble(),
    holesWithGir: json['holesWithGir'] as int? ?? 0,
    fairwayPercent: (json['fairwayPercent'] as num?)?.toDouble(),
    holesWithFairway: json['holesWithFairway'] as int? ?? 0,
    penaltiesPerRound: (json['penaltiesPerRound'] as num?)?.toDouble(),
    distribution: (json['distribution'] as List<dynamic>? ?? [])
        .map((e) => ScoreBucket.fromJson(e as Map<String, dynamic>))
        .toList(),
    byPar: (json['byPar'] as List<dynamic>? ?? [])
        .map((e) => ParAverage.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class PerformanceApi {
  PerformanceApi({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Performance> forWindow(PerformanceWindow window) async {
    final json = await _apiClient.get(
      '/golfers/me/performance',
      queryParams: {
        if (window.rounds != null) 'window': '${window.rounds}',
      },
    );
    return Performance.fromJson(json as Map<String, dynamic>);
  }
}
