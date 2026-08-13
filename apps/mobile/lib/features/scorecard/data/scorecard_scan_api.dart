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
import 'package:http_parser/http_parser.dart' show MediaType;

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
  const ScannedLine({
    required this.hole,
    this.par,
    this.strokeIndex,
    this.strokeIndexLadies,
  });

  final int hole;
  final int? par;
  final int? strokeIndex;

  /// The ladies index row, where the card prints a second one.
  ///
  /// A hole's difficulty ranking changes with the distance played, so many
  /// Vietnamese cards rank the eighteen twice. Null means the card printed one
  /// row — not that women play the hole unranked.
  final int? strokeIndexLadies;

  factory ScannedLine.fromJson(Map<String, dynamic> json) => ScannedLine(
    hole: json['hole'] as int,
    par: json['par'] as int?,
    strokeIndex: json['strokeIndex'] as int?,
    strokeIndexLadies: json['strokeIndexLadies'] as int?,
  );
}

/// A tee row against the OUT, IN and TOTAL the club printed beside it.
///
/// The same test the par row has always had, applied to the row that needed it
/// far more: five tees over eighteen holes is ninety three-digit numbers,
/// against par's eighteen single digits, and until now nothing compared any of
/// them to anything. The portal's per-tee total was summed from what the model
/// had just read, so a 3 misread as an 8 produced a total in perfect agreement
/// with itself.
class TeeChecks {
  const TeeChecks({
    required this.yardsOutRead,
    required this.yardsInRead,
    this.yardsOutPrinted,
    this.yardsInPrinted,
    this.yardsTotalPrinted,
    required this.yardsAgree,
    required this.yardsChecked,
  });

  final int yardsOutRead;
  final int yardsInRead;
  final int? yardsOutPrinted;
  final int? yardsInPrinted;
  final int? yardsTotalPrinted;

  /// False only when a printed sum disagrees with what was read.
  final bool yardsAgree;

  /// Null when the card printed no sums, so nothing could be checked.
  final bool? yardsChecked;

  int get yardsTotalRead => yardsOutRead + yardsInRead;

  /// True when a sum was checked and came out wrong — the case worth a warning.
  bool get contradictsTheCard => yardsChecked == true && !yardsAgree;

  factory TeeChecks.fromJson(Map<String, dynamic> json) => TeeChecks(
    yardsOutRead: json['yardsOutRead'] as int? ?? 0,
    yardsInRead: json['yardsInRead'] as int? ?? 0,
    yardsOutPrinted: json['yardsOutPrinted'] as int?,
    yardsInPrinted: json['yardsInPrinted'] as int?,
    yardsTotalPrinted: json['yardsTotalPrinted'] as int?,
    yardsAgree: json['yardsAgree'] as bool? ?? true,
    yardsChecked: json['yardsChecked'] as bool?,
  );
}

/// Whose rating a tee row carries.
///
/// A course is rated separately for men and for women, and a card that prints
/// ratings prints both — commonly two rows against the same tee colour. The
/// second used to be dropped as a duplicate name, silently, along with the
/// ratings that were the reason to photograph the card at all.
enum TeeGender {
  men('MEN'),
  ladies('LADIES'),

  /// What most cards are. Not a synonym for men's.
  unspecified('UNSPECIFIED');

  const TeeGender(this.wire);

  final String wire;

  static TeeGender fromWire(String? value) => switch (value?.toUpperCase()) {
    'MEN' => TeeGender.men,
    'LADIES' => TeeGender.ladies,
    _ => TeeGender.unspecified,
  };
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
    this.gender = TeeGender.unspecified,
    required this.yardages,
    this.checks,
  });

  final String name;
  final TeeGender gender;
  final double? courseRating;
  final int? slopeRating;

  /// hole number → yards.
  final Map<int, int> yardages;

  /// What this row adds up to against what the card says it should.
  final TeeChecks? checks;

  factory ScannedTee.fromJson(Map<String, dynamic> json) => ScannedTee(
    name: (json['name'] as String? ?? '').trim(),
    courseRating: (json['courseRating'] as num?)?.toDouble(),
    slopeRating: json['slopeRating'] as int?,
    gender: TeeGender.fromWire(json['gender'] as String?),
    yardages: {
      for (final entry in (json['yardages'] as List<dynamic>? ?? []))
        (entry as Map<String, dynamic>)['hole'] as int: entry['yards'] as int,
    },
    checks: json['checks'] == null
        ? null
        : TeeChecks.fromJson(json['checks'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (courseRating != null) 'courseRating': courseRating,
    if (slopeRating != null) 'slopeRating': slopeRating,
    'gender': gender.wire,
    // The club's own sums travel with the row. They are not stored — the
    // yardages are the data — but without them the reviewer sees only a total
    // the portal added up from the numbers being questioned.
    if (checks?.yardsOutPrinted != null) 'yardsOut': checks!.yardsOutPrinted,
    if (checks?.yardsInPrinted != null) 'yardsIn': checks!.yardsInPrinted,
    if (checks?.yardsTotalPrinted != null)
      'yardsTotal': checks!.yardsTotalPrinted,
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
    this.photoUrl,
  });

  final String? name;
  final List<ScannedLine> holes;
  final List<ScannedTee> tees;
  final ScanChecks checks;

  /// Where the server kept the photograph this card was read from.
  ///
  /// Carried straight through to the submission as its evidence, so the
  /// reviewer decides on the card rather than on the typing. Null when the
  /// deployment keeps no photographs — then the submission goes without one,
  /// exactly as it did before, rather than pointing at a URL that would 404.
  final String? photoUrl;

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
    photoUrl: json['photoUrl'] as String?,
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
    // Say what the part is. MultipartFile.fromPath does not infer a type and
    // falls back to application/octet-stream, which the server refuses — it
    // only accepts JPEG, PNG and WebP, because it pays a model per image and
    // an accidental video frame is not worth sending. So every scan failed
    // validation before the photograph was ever looked at, whatever its size.
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        image.path,
        contentType: _mediaTypeOf(image.path),
      ),
    );

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

  /// What the file is, from what it is called.
  ///
  /// The picker re-encodes to JPEG whenever an imageQuality is set, which is
  /// every call site here, so that is the answer nearly always and the right
  /// default when a name says nothing. The others are listed because a photo
  /// chosen from the library arrives as whatever it was saved as.
  static MediaType _mediaTypeOf(String path) {
    final name = path.toLowerCase();
    if (name.endsWith('.png')) return MediaType('image', 'png');
    if (name.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'jpeg');
  }

  /// The server's own words where it has them — "no scorecard could be read in
  /// this photograph" tells the golfer to retake it; a status code does not.
  String _messageFrom(String body, int statusCode) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      // `details` is what the server sends. This read `fieldErrors`, a name
      // nothing produces, so every per-field explanation was skipped and the
      // golfer got the generic "Request validation failed" instead of being
      // told what was wrong with the photograph. `fieldErrors` is still read
      // second, in case an older server is on the other end.
      for (final key in const ['details', 'fieldErrors']) {
        final fields = json[key];
        if (fields is Map && fields['image'] != null) {
          return fields['image'].toString();
        }
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
