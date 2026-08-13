// What the phone actually puts on the wire when it sends a photograph, and
// what it makes of the answer.
//
// Both were wrong at once, and the second hid the first. The part went up as
// application/octet-stream because MultipartFile.fromPath does not infer a
// type, and the server accepts only JPEG, PNG and WebP — so every scan was
// refused before the photograph was looked at, whatever its size. And the
// refusal said which field and why, under a key this client did not read, so
// the golfer saw the generic "Request validation failed" and nothing to act on.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:vsp_mobile/features/scorecard/data/scorecard_scan_api.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('scan_api_test');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  // Contents are ASCII so the assertions can read the multipart body as text.
  // What is under test is the part's declared type, not its bytes.
  Future<File> photo(String name) async {
    final f = File('${tmp.path}/$name');
    await f.writeAsString('not-really-an-image');
    return f;
  }

  test('a photograph goes up as an image, not as unnamed bytes', () async {
    late String contentType;
    final client = MockClient((request) async {
      // The multipart body carries the part's own Content-Type header.
      contentType = request.body
          .split('\r\n')
          .firstWhere((l) => l.toLowerCase().startsWith('content-type: image'),
              orElse: () => 'content-type: <none>');
      return http.Response(jsonEncode({'holes': [], 'tees': []}), 200);
    });

    await ScorecardScanApi(client: client)
        .scanCourseCard(courseId: 1, image: await photo('card.jpg'));

    expect(contentType, contains('image/jpeg'),
        reason: 'octet-stream is what the server refuses');
  });

  test('a PNG says PNG', () async {
    late String body;
    final client = MockClient((request) async {
      body = request.body;
      return http.Response(jsonEncode({'holes': [], 'tees': []}), 200);
    });

    await ScorecardScanApi(client: client)
        .scanCourseCard(courseId: 1, image: await photo('card.png'));

    expect(body, contains('image/png'));
  });

  test('the reason the server gave is the reason the golfer is shown',
      () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'code': 'VSP-ERR-VALIDATION-001',
            'message': 'Request validation failed',
            'field': 'image',
            'details': {'image': 'send a JPEG, PNG or WebP photograph of the card'},
          }),
          400,
        ));

    await expectLater(
      ScorecardScanApi(client: client)
          .scanCourseCard(courseId: 1, image: await photo('card.jpg')),
      throwsA(isA<ScorecardScanException>().having(
        (e) => e.message,
        'message',
        contains('JPEG'),
      )),
    );
  });

  test('a server with no per-field detail still says something', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({'message': 'Request validation failed'}),
          400,
        ));

    await expectLater(
      ScorecardScanApi(client: client)
          .scanCourseCard(courseId: 1, image: await photo('card.jpg')),
      throwsA(isA<ScorecardScanException>().having(
        (e) => e.message,
        'message',
        'Request validation failed',
      )),
    );
  });
}
