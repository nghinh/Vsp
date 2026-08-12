import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/domain/models/sync_event.dart';
import 'package:vsp_mobile/infrastructure/sync/idempotency_client.dart';

/// A corrected hole stayed on the phone. `POST /scores/rounds/{roundId}
/// /corrections` existed and nothing ever posted to it, so the server kept the
/// original score while the golfer looked at the amended one.
void main() {
  const roundId = 'f1f26951-8076-4d53-a23f-f33b95b67671';

  SyncEvent correctionEvent() => SyncEvent.forScoreCorrection(
    roundId: roundId,
    correctionPayload: {
      'playerId': 66,
      'corrections': [
        {
          'field': 'strokes',
          'holeNumber': 11,
          'oldValue': '4',
          'newValue': '5',
        },
      ],
    },
  );

  SyncRequest requestFor(SyncEvent event) => IdempotencyClient(
    apiClient: ApiClient(),
  ).requestFor(event, jsonDecode(event.payload) as Map<String, dynamic>);

  test('routes to the round it corrects, not to the geometry endpoint', () {
    final request = requestFor(correctionEvent());

    expect(request.method, 'POST');
    expect(request.path, '/scores/rounds/$roundId/corrections');
  });

  test('a score correction is not confused with a course correction', () {
    // Both are "corrections" and they are different endpoints; the queue only
    // ever knew the geometry one.
    expect(
      SyncEventType.scoreCorrection,
      isNot(SyncEventType.correctionSubmit),
    );
    expect(requestFor(correctionEvent()).path, contains('/scores/rounds/'));
  });

  test('sends the fields ScoreCorrectionRequest declares', () {
    final body = requestFor(correctionEvent()).body!;

    expect(body['playerId'], 66);
    final corrections = body['corrections'] as List;
    expect(corrections, hasLength(1));
    expect(
      (corrections.single as Map).keys.toSet(),
      {'field', 'holeNumber', 'oldValue', 'newValue'},
    );
  });

  test('every event type survives a round trip through its own name', () {
    // fromString compared against value.toLowerCase() while every name is
    // camelCase, so nothing matched and every type decoded as scoreUpdate.
    for (final type in SyncEventType.values) {
      expect(SyncEventType.fromString(type.name), type, reason: type.name);
    }
  });
}
