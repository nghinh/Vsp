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

class ScannedCard {
  const ScannedCard({this.name, required this.holes, required this.checks});

  final String? name;
  final List<ScannedLine> holes;
  final ScanChecks checks;

  factory ScannedCard.fromJson(Map<String, dynamic> json) => ScannedCard(
    name: json['name'] as String?,
    holes: (json['holes'] as List<dynamic>? ?? [])
        .map((e) => ScannedLine.fromJson(e as Map<String, dynamic>))
        .toList(),
    checks: ScanChecks.fromJson(
      (json['checks'] as Map<String, dynamic>?) ?? const {},
    ),
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
