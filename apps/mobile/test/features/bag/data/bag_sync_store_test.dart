import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/core/storage/bag_sync_store.dart';

void main() {
  group('QueuedBagUpdate', () {
    test('parses persisted queue row and payload', () {
      final entry = QueuedBagUpdate.fromRow({
        'idempotency_key': 'key-1',
        'operation': 'updateClub',
        'bag_id': 5,
        'club_id': 9,
        'payload': '{"loft":26.0}',
        'created_at': '2026-08-04T00:00:00.000Z',
        'synced_at': null,
      });

      expect(entry.operation, BagSyncOperation.updateClub);
      expect(entry.bagId, 5);
      expect(entry.clubId, 9);
      expect(entry.payloadMap, {'loft': 26.0});
      expect(entry.isSynced, isFalse);
    });

    test('recognizes synced entries', () {
      final entry = QueuedBagUpdate.fromRow({
        'idempotency_key': 'key-2',
        'operation': 'deleteBag',
        'bag_id': 5,
        'club_id': null,
        'payload': '{}',
        'created_at': '2026-08-04T00:00:00.000Z',
        'synced_at': '2026-08-04T00:01:00.000Z',
      });

      expect(entry.isSynced, isTrue);
      expect(entry.operation, BagSyncOperation.deleteBag);
    });
  });
}
