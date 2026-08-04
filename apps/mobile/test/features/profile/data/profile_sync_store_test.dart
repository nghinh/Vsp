import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/core/storage/profile_sync_store.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart';

void main() {
  group('QueuedProfileUpdate', () {
    test('parses persisted row and request payload', () {
      final entry = QueuedProfileUpdate.fromRow({
        'idempotency_key': 'profile-1',
        'payload': '{"handicap":12.4,"distanceUnit":"YARDS"}',
        'created_at': '2026-08-04T00:00:00.000Z',
        'synced_at': null,
      });

      expect(entry.request.handicap, 12.4);
      expect(entry.request.distanceUnit, DistanceUnit.yards.value);
      expect(entry.isSynced, isFalse);
    });

    test('recognizes synced entries', () {
      final entry = QueuedProfileUpdate.fromRow({
        'idempotency_key': 'profile-2',
        'payload': '{"country":"VN"}',
        'created_at': '2026-08-04T00:00:00.000Z',
        'synced_at': '2026-08-04T00:01:00.000Z',
      });

      expect(entry.request.country, 'VN');
      expect(entry.isSynced, isTrue);
    });
  });
}
