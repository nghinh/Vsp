import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/sync_event.dart';
import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/infrastructure/sync/idempotency_client.dart';

/// Scores never left the phone. `SyncEvent.forScore` existed and had no caller
/// anywhere in the app, so a finished round produced zero `/scores/sync`
/// requests and the server held a scorecard with no holes on it.
///
/// These pin the request the queue builds against what
/// `ScoreSyncRequest`/`ScoreUpdate` actually declare, so a field drifting on
/// either side fails here rather than silently on a golfer's round.
void main() {
  /// The payload ScorecardCubit enqueues for one hole.
  Map<String, dynamic> payloadForOneHole() => {
    'roundId': '2b1c0f74-0f2e-4a7f-9c3d-5a6b7c8d9e01',
    'flightId': '2b1c0f74-0f2e-4a7f-9c3d-5a6b7c8d9e01',
    'scores': [
      {
        'scoreId': 'c9f1a6e0-1111-5222-8333-444455556666',
        'holeIndex': 7,
        'playerId': 66,
        'grossScore': 5,
        'putts': 2,
        'penalties': 0,
        'fairwayHit': true,
        'gir': false,
        'bunker': false,
        'notes': null,
        'version': 1,
      },
    ],
  };

  test('routes a score update to the batch endpoint', () {
    final event = SyncEvent.forScore(
      scoreId: 'r1_7_66',
      scorePayload: payloadForOneHole(),
    );
    final request = IdempotencyClient(apiClient: ApiClient()).requestFor(
      event,
      jsonDecode(event.payload) as Map<String, dynamic>,
    );

    expect(request.method, 'POST');
    expect(request.path, '/scores/sync');
  });

  test('sends the envelope ScoreSyncRequest declares', () {
    final event = SyncEvent.forScore(
      scoreId: 'r1_7_66',
      scorePayload: payloadForOneHole(),
    );
    final body = IdempotencyClient(apiClient: ApiClient())
        .requestFor(event, jsonDecode(event.payload) as Map<String, dynamic>)
        .body!;

    expect(body['roundId'], '2b1c0f74-0f2e-4a7f-9c3d-5a6b7c8d9e01');
    expect(body['flightId'], '2b1c0f74-0f2e-4a7f-9c3d-5a6b7c8d9e01');
    expect(body['clientEventId'], event.id);
    expect(body['scores'], isA<List<dynamic>>());
    expect(body['scores'], hasLength(1));
  });

  test('a score update carries only the fields ScoreUpdate declares', () {
    // roundId and flightId belong to the envelope. Leaving them on the update
    // would depend on the server ignoring unknown properties, which is a
    // Jackson setting, not a contract.
    const declared = {
      'scoreId',
      'holeIndex',
      'playerId',
      'grossScore',
      'putts',
      'penalties',
      'fairwayHit',
      'gir',
      'bunker',
      'notes',
      'version',
    };

    final event = SyncEvent.forScore(
      scoreId: 'r1_7_66',
      scorePayload: payloadForOneHole(),
    );
    final body = IdempotencyClient(apiClient: ApiClient())
        .requestFor(event, jsonDecode(event.payload) as Map<String, dynamic>)
        .body!;
    final update = (body['scores'] as List).single as Map<String, dynamic>;

    expect(update.keys.toSet().difference(declared), isEmpty);
    expect(update['holeIndex'], 7);
    expect(update['playerId'], 66);
    expect(update['grossScore'], 5);
  });
}
