// Photographing the club's card — VSP Mobile App
//
// The server reads the photograph and hands back a draft. Nothing it returns
// is saved by looking at it: the golfer checks the numbers against the card in
// their hand first, and for a course card an admin reviews them after that.
//
// The read is not reliable enough to skip either check. Measured against a
// real Vietnamese card, the configured model returned eleven of eighteen pars
// and twelve of eighteen stroke indexes, and gave one tee's whole yardage row
// as the row's printed total repeated eighteen times. What comes back is a
// starting point that saves typing, not an answer.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../../core/network/vsp_endpoints.dart';

/// What the card's own arithmetic says about a read.
///
/// A printed card adds up: the par row equals the total printed beside it, and
/// the stroke indexes are 1..18 used once each. Neither is proof — a read that
/// swaps two pars keeps the total, and one that drops an index column and
/// shifts the rest along is still a permutation — but they say which row to
/// look at first.
class ScanChecks {
  const ScanChecks({
    required this.holesRead,
    required this.parCellsRead,
    required this.strokeIndexCellsRead,
    required this.parTotalRead,
    this.parTotalPrinted,
    required this.parTotalAgrees,
    required this.strokeIndexComplete,
  });

  final int holesRead;
  final int parCellsRead;
  final int strokeIndexCellsRead;
  final int parTotalRead;
  final int? parTotalPrinted;
  final bool parTotalAgrees;
  final bool strokeIndexComplete;

  factory ScanChecks.fromJson(Map<String, dynamic> json) => ScanChecks(
    holesRead: json['holesRead'] as int? ?? 0,
    parCellsRead: json['parCellsRead'] as int? ?? 0,
    strokeIndexCellsRead: json['strokeIndexCellsRead'] as int? ?? 0,
    parTotalRead: json['parTotalRead'] as int? ?? 0,
    parTotalPrinted: json['parTotalPrinted'] as int?,
    parTotalAgrees: json['parTotalAgrees'] as bool? ?? false,
    strokeIndexComplete: json['strokeIndexComplete'] as bool? ?? false,
  );
}

/// One line of a card as the server read it. Either number may be absent:
/// the server drops any value a printed card could not hold rather than
/// passing on a plausible wrong one.
class ScannedLine {
  const ScannedLine({required this.hole, this.par, this.strokeIndex});

  final int hole;
  final int? par;
  final int? strokeIndex;

  factory ScannedLine.fromJson(Map<String, dynamic> json) => ScannedLine(
    hole: json['hole'] as int,
    par: json['par'] as int?,
    strokeIndex: json['strokeIndex'] as int?,
  );
}

/// One tee row of the card: what it measures and how it is rated.
///
/// These ride along with the card rather than being checked hole by hole on
/// the phone. Ninety yardages is not something a golfer can verify at the tee,
/// and the numbers that matter for a handicap — course rating and slope — are
/// two per tee and printed in their own small table. They go to the admin as
/// part of the same submission, and the admin has the photograph.
class ScannedTee {
  const ScannedTee({
    required this.name,
    this.courseRating,
    this.slopeRating,
    required this.yardages,
  });

  final String name;
  final double? courseRating;
  final int? slopeRating;

  /// hole number → yards.
  final Map<int, int> yardages;

  factory ScannedTee.fromJson(Map<String, dynamic> json) => ScannedTee(
    name: (json['name'] as String? ?? '').trim(),
    courseRating: (json['courseRating'] as num?)?.toDouble(),
    slopeRating: json['slopeRating'] as int?,
    yardages: {
      for (final entry in (json['yardages'] as List<dynamic>? ?? []))
        (entry as Map<String, dynamic>)['hole'] as int: entry['yards'] as int,
    },
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (courseRating != null) 'courseRating': courseRating,
    if (slopeRating != null) 'slopeRating': slopeRating,
    'yardages': [
      for (final entry in yardages.entries)
        {'hole': entry.key, 'yards': entry.value},
    ],
  };
}

class ScannedCard {
  const ScannedCard({
    this.name,
    required this.holes,
    required this.tees,
    required this.checks,
  });

  final String? name;
  final List<ScannedLine> holes;
  final List<ScannedTee> tees;
  final ScanChecks checks;

  factory ScannedCard.fromJson(Map<String, dynamic> json) => ScannedCard(
    name: json['name'] as String?,
    holes: (json['holes'] as List<dynamic>? ?? [])
        .map((e) => ScannedLine.fromJson(e as Map<String, dynamic>))
        .toList(),
    tees: (json['tees'] as List<dynamic>? ?? [])
        .map((e) => ScannedTee.fromJson(e as Map<String, dynamic>))
        .where((tee) => tee.name.isNotEmpty)
        .toList(),
    checks: ScanChecks.fromJson(
      (json['checks'] as Map<String, dynamic>?) ?? const {},
    ),
  );
}

/// What the golfer's own arithmetic says about a row of handwriting.
///
/// A player writes their OUT, IN and TOTAL at the end of each nine, and those
/// three numbers are the only independent check on their own handwriting there
/// will ever be. On the card this was built against they earned their place at
/// once: the front nine summed to the +2 written beside it, and the back nine
/// summed to 2 against a written 1 — one hole misread, invisible in the
/// numbers themselves.
class ScannedRowChecks {
  const ScannedRowChecks({
    required this.holesRead,
    required this.cellsRead,
    this.writtenOut,
    this.writtenIn,
    this.writtenTotal,
    required this.outAgrees,
    required this.inAgrees,
    required this.totalAgrees,
  });

  final int holesRead;
  final int cellsRead;
  final int? writtenOut;
  final int? writtenIn;
  final int? writtenTotal;
  final bool outAgrees;
  final bool inAgrees;
  final bool totalAgrees;

  factory ScannedRowChecks.fromJson(Map<String, dynamic> json) =>
      ScannedRowChecks(
        holesRead: json['holesRead'] as int? ?? 0,
        cellsRead: json['cellsRead'] as int? ?? 0,
        writtenOut: json['writtenOut'] as int?,
        writtenIn: json['writtenIn'] as int?,
        writtenTotal: json['writtenTotal'] as int?,
        outAgrees: json['outAgrees'] as bool? ?? false,
        inAgrees: json['inAgrees'] as bool? ?? false,
        totalAgrees: json['totalAgrees'] as bool? ?? false,
      );
}

/// How the numbers in a row are meant to be read.
///
/// A golfer writes either the strokes they took (4, 5, 6) or the score against
/// par (0, +1, -1). The same "1" is a hole in one or a bogey depending on
/// which, so this is never guessed on the golfer's behalf: an unknown notation
/// is asked about before a single stroke is written down.
enum ScannedNotation { strokes, toPar, unknown }

/// One hole of one player's row. `written` is absent where the server would
/// have had to guess at a smudge.
class ScannedStroke {
  const ScannedStroke({required this.hole, this.written});

  final int hole;
  final int? written;

  factory ScannedStroke.fromJson(Map<String, dynamic> json) => ScannedStroke(
    hole: json['hole'] as int,
    written: json['written'] as int?,
  );
}

/// One player's row, as the server read it off the photograph.
class ScannedScoreRow {
  const ScannedScoreRow({
    this.player,
    required this.notation,
    required this.holes,
    required this.checks,
  });

  /// Whatever is written at the left edge of the row — an initial, a name, or
  /// nothing at all.
  final String? player;
  final ScannedNotation notation;
  final List<ScannedStroke> holes;
  final ScannedRowChecks checks;

  factory ScannedScoreRow.fromJson(Map<String, dynamic> json) =>
      ScannedScoreRow(
        player: json['player'] as String?,
        notation: switch (json['notation'] as String?) {
          'strokes' => ScannedNotation.strokes,
          'to_par' => ScannedNotation.toPar,
          _ => ScannedNotation.unknown,
        },
        holes: (json['holes'] as List<dynamic>? ?? [])
            .map((e) => ScannedStroke.fromJson(e as Map<String, dynamic>))
            .toList(),
        checks: ScannedRowChecks.fromJson(
          (json['checks'] as Map<String, dynamic>?) ?? const {},
        ),
      );
}

class ScannedScores {
  const ScannedScores({required this.players});

  final List<ScannedScoreRow> players;

  factory ScannedScores.fromJson(Map<String, dynamic> json) => ScannedScores(
    players: (json['players'] as List<dynamic>? ?? [])
        .map((e) => ScannedScoreRow.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class ScorecardScanApi {
  ScorecardScanApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Read a photograph of a club's printed card.
  Future<ScannedCard> scanCourseCard({
    required int courseId,
    required File image,
  }) async {
    final json = await _upload(
      '/courses/$courseId/scorecard-corrections/extract',
      image,
    );
    return ScannedCard.fromJson(json);
  }

  /// Read the strokes a golfer wrote on their card by hand.
  ///
  /// The same photograph as [scanCourseCard] read for the opposite half of
  /// itself: there the printed rows are the answer and the handwriting is
  /// noise, here it is the other way round.
  Future<ScannedScores> scanScores({
    required String roundId,
    required File image,
  }) async {
    final json = await _upload('/rounds/$roundId/scores/extract', image);
    return ScannedScores.fromJson(json);
  }

  Future<Map<String, dynamic>> _upload(String path, File image) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${VspEndpoints.apiBaseUrl}$path'),
    );

    final token = ApiClient.sharedAccessToken;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(await http.MultipartFile.fromPath('image', image.path));

    // Reading a card takes the model ten to twenty seconds; the default
    // client timeout would give up while the answer is still being written.
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 120));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      throw ScorecardScanException(_messageFrom(body, streamed.statusCode));
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }

  /// The server's own words where it has them — "no scorecard could be read in
  /// this photograph" tells the golfer to retake it; a status code does not.
  String _messageFrom(String body, int statusCode) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final fields = json['fieldErrors'];
      if (fields is Map && fields['image'] != null) {
        return fields['image'].toString();
      }
      final message = json['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    } catch (_) {
      // Fall through to the status code.
    }
    return 'HTTP $statusCode';
  }
}

class ScorecardScanException implements Exception {
  const ScorecardScanException(this.message);

  final String message;

  @override
  String toString() => message;
}
