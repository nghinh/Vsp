// ManualHoleSelection unit tests — VSP Mobile App
//
// Tests:
// - ManualHoleSelection construction and computed properties
// - wasOverride, wasPrompted, reasonLabel
// - Serialization (toMap / fromMap for SQLite persistence)
// - ManualSelectionReason enum
// - ManualHoleSelectionSyncStatus enum
//
// Story 6.2 — Wave A

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/manual_hole_selection.dart';
import 'package:vsp_mobile/domain/models/qualified_location.dart';

void main() {
  QualifiedLocation makeLocation() => QualifiedLocation(
        latitude: 10.762917,
        longitude: 106.687074,
        accuracyMeters: 5.0,
        timestamp: DateTime.parse('2026-08-02T10:00:00Z'),
        heading: 45.0,
        source: LocationSource.gps,
        isStale: false,
      );

  group('ManualHoleSelection', () {
    group('construction', () {
      test('creates with all fields', () {
        final selection = ManualHoleSelection(
          id: 'selection-1',
          roundId: 'round-1',
          detectedHoleId: 'hole-4',
          selectedHoleId: 'hole-5',
          reason: ManualSelectionReason.override,
          confidenceBefore: 0.35,
          locationAtSelection: makeLocation(),
          selectedAt: DateTime.parse('2026-08-02T10:05:00Z'),
          syncStatus: ManualHoleSelectionSyncStatus.pending,
        );

        expect(selection.id, 'selection-1');
        expect(selection.roundId, 'round-1');
        expect(selection.detectedHoleId, 'hole-4');
        expect(selection.selectedHoleId, 'hole-5');
        expect(selection.reason, ManualSelectionReason.override);
        expect(selection.confidenceBefore, 0.35);
        expect(selection.syncStatus, ManualHoleSelectionSyncStatus.pending);
      });

      test('creates with null optional fields', () {
        final selection = ManualHoleSelection(
          id: 'selection-1',
          roundId: 'round-1',
          selectedHoleId: 'hole-1',
          reason: ManualSelectionReason.roundSetup,
          locationAtSelection: makeLocation(),
          selectedAt: DateTime.parse('2026-08-02T10:05:00Z'),
        );

        expect(selection.detectedHoleId, isNull);
        expect(selection.confidenceBefore, isNull);
        expect(selection.syncStatus, ManualHoleSelectionSyncStatus.local);
      });
    });

    group('computed properties', () {
      test('wasOverride returns true for override reason', () {
        final selection = ManualHoleSelection(
          id: 'selection-1',
          roundId: 'round-1',
          selectedHoleId: 'hole-5',
          reason: ManualSelectionReason.override,
          locationAtSelection: makeLocation(),
          selectedAt: DateTime.now(),
        );
        expect(selection.wasOverride, true);
      });

      test('wasOverride returns true for correction reason', () {
        final selection = ManualHoleSelection(
          id: 'selection-1',
          roundId: 'round-1',
          selectedHoleId: 'hole-5',
          reason: ManualSelectionReason.correction,
          locationAtSelection: makeLocation(),
          selectedAt: DateTime.now(),
        );
        expect(selection.wasOverride, true);
      });

      test('wasOverride returns false for userChoice', () {
        final selection = ManualHoleSelection(
          id: 'selection-1',
          roundId: 'round-1',
          selectedHoleId: 'hole-5',
          reason: ManualSelectionReason.userChoice,
          locationAtSelection: makeLocation(),
          selectedAt: DateTime.now(),
        );
        expect(selection.wasOverride, false);
      });

      test('wasPrompted returns true for promptedByLowConfidence', () {
        final selection = ManualHoleSelection(
          id: 'selection-1',
          roundId: 'round-1',
          selectedHoleId: 'hole-5',
          reason: ManualSelectionReason.promptedByLowConfidence,
          locationAtSelection: makeLocation(),
          selectedAt: DateTime.now(),
        );
        expect(selection.wasPrompted, true);
      });

      test('wasPrompted returns false for other reasons', () {
        final selection = ManualHoleSelection(
          id: 'selection-1',
          roundId: 'round-1',
          selectedHoleId: 'hole-5',
          reason: ManualSelectionReason.userChoice,
          locationAtSelection: makeLocation(),
          selectedAt: DateTime.now(),
        );
        expect(selection.wasPrompted, false);
      });

      test('reasonLabel returns correct labels', () {
        expect(
          ManualHoleSelection(
            id: '1', roundId: 'r', selectedHoleId: 'h',
            reason: ManualSelectionReason.userChoice,
            locationAtSelection: makeLocation(), selectedAt: DateTime.now(),
          ).reasonLabel,
          'User chose hole manually',
        );
        expect(
          ManualHoleSelection(
            id: '1', roundId: 'r', selectedHoleId: 'h',
            reason: ManualSelectionReason.override,
            locationAtSelection: makeLocation(), selectedAt: DateTime.now(),
          ).reasonLabel,
          'Override — corrected wrong detection',
        );
        expect(
          ManualHoleSelection(
            id: '1', roundId: 'r', selectedHoleId: 'h',
            reason: ManualSelectionReason.correction,
            locationAtSelection: makeLocation(), selectedAt: DateTime.now(),
          ).reasonLabel,
          'Correction — fixed previous selection',
        );
        expect(
          ManualHoleSelection(
            id: '1', roundId: 'r', selectedHoleId: 'h',
            reason: ManualSelectionReason.promptedByLowConfidence,
            locationAtSelection: makeLocation(), selectedAt: DateTime.now(),
          ).reasonLabel,
          'Prompted — low confidence detection',
        );
        expect(
          ManualHoleSelection(
            id: '1', roundId: 'r', selectedHoleId: 'h',
            reason: ManualSelectionReason.roundSetup,
            locationAtSelection: makeLocation(), selectedAt: DateTime.now(),
          ).reasonLabel,
          'Round setup or resume',
        );
      });
    });

    group('toMap / fromMap SQLite round-trip', () {
      test('round-trip preserves all fields', () {
        final original = ManualHoleSelection(
          id: 'selection-1',
          roundId: 'round-1',
          detectedHoleId: 'hole-4',
          selectedHoleId: 'hole-5',
          reason: ManualSelectionReason.override,
          confidenceBefore: 0.35,
          locationAtSelection: makeLocation(),
          selectedAt: DateTime.parse('2026-08-02T10:05:00Z'),
          syncStatus: ManualHoleSelectionSyncStatus.pending,
        );

        final map = original.toMap();
        final restored = ManualHoleSelection.fromMap(map);

        expect(restored.id, original.id);
        expect(restored.roundId, original.roundId);
        expect(restored.detectedHoleId, original.detectedHoleId);
        expect(restored.selectedHoleId, original.selectedHoleId);
        expect(restored.reason, original.reason);
        expect(restored.confidenceBefore, original.confidenceBefore);
        expect(
          restored.locationAtSelection.latitude,
          original.locationAtSelection.latitude,
        );
        expect(
          restored.locationAtSelection.longitude,
          original.locationAtSelection.longitude,
        );
        expect(restored.selectedAt.toUtc(), original.selectedAt.toUtc());
        expect(restored.syncStatus, original.syncStatus);
      });

      test('toMap handles null optional fields', () {
        final selection = ManualHoleSelection(
          id: 'selection-1',
          roundId: 'round-1',
          selectedHoleId: 'hole-5',
          reason: ManualSelectionReason.roundSetup,
          locationAtSelection: makeLocation(),
          selectedAt: DateTime.parse('2026-08-02T10:05:00Z'),
        );

        final map = selection.toMap();
        expect(map['detected_hole_id'], isNull);
        expect(map['confidence_before'], isNull);
        expect(map['sync_status'], 'local');
      });
    });
  });

  group('ManualSelectionReason enum', () {
    test('has expected values', () {
      expect(ManualSelectionReason.values, contains(ManualSelectionReason.userChoice));
      expect(ManualSelectionReason.values, contains(ManualSelectionReason.override));
      expect(ManualSelectionReason.values, contains(ManualSelectionReason.correction));
      expect(
        ManualSelectionReason.values,
        contains(ManualSelectionReason.promptedByLowConfidence),
      );
      expect(ManualSelectionReason.values, contains(ManualSelectionReason.roundSetup));
    });
  });

  group('ManualHoleSelectionSyncStatus', () {
    test('fromString handles known values', () {
      expect(
        ManualHoleSelectionSyncStatus.fromString('local'),
        ManualHoleSelectionSyncStatus.local,
      );
      expect(
        ManualHoleSelectionSyncStatus.fromString('pending'),
        ManualHoleSelectionSyncStatus.pending,
      );
      expect(
        ManualHoleSelectionSyncStatus.fromString('synced'),
        ManualHoleSelectionSyncStatus.synced,
      );
      expect(
        ManualHoleSelectionSyncStatus.fromString('failed'),
        ManualHoleSelectionSyncStatus.failed,
      );
    });

    test('fromString defaults to local for unknown values', () {
      expect(
        ManualHoleSelectionSyncStatus.fromString('unknown'),
        ManualHoleSelectionSyncStatus.local,
      );
    });
  });
}
