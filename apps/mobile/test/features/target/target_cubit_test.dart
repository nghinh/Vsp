// Target Cubit Unit Tests — VSP Mobile App
//
// Tests cover:
// - placeTarget() creates target, persists, and emits distances
// - moveTarget() updates target position and recalculates distances
// - initialize() restores existing target from repository
// - clearTarget() removes target from state and repository
// - setHoleNumber() switches hole and restores target
// - setDragging() updates drag mode in state
// - Distance computation: ball→target and target→pin in meters
// - Error handling: repository failures emit error state
//
// Story 6.5 — Slice 1: Tap-to-Place Target

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/target/domain/target_model.dart';
import 'package:vsp_mobile/features/target/domain/target_repository.dart';
import 'package:vsp_mobile/features/target/presentation/target_cubit.dart';
import 'package:vsp_mobile/features/target/presentation/target_state.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

/// Fake implementation of TargetRepository for testing.
class FakeTargetRepository implements TargetRepository {
  final Map<String, TargetModel> _store = {}; // key: roundId_holeNumber

  @override
  Future<void> saveTarget(TargetModel target) async {
    _store['${target.roundId}_${target.holeNumber}'] = target;
  }

  @override
  Future<TargetModel?> getTarget(String roundId, int holeNumber) async {
    return _store['${roundId}_$holeNumber'];
  }

  @override
  Future<void> deleteTarget(String roundId, int holeNumber) async {
    _store.remove('${roundId}_$holeNumber');
  }

  @override
  Future<List<TargetModel>> getTargetsForRound(String roundId) async {
    return _store.values
        .where((t) => t.roundId == roundId)
        .toList();
  }

  @override
  Future<void> close() async {}
}

/// Test double that returns a fixed ball position instead of a GPS fix.
class FixedBallPositionProvider extends BallPositionProvider {
  final List<double> fixedPosition;

  FixedBallPositionProvider([this.fixedPosition = const [106.6280, 10.7620]]);

  @override
  List<double>? getBallPosition() => fixedPosition;

  @override
  GpsAccuracy getAccuracy() => GpsAccuracy.high;
}

/// Pin position fixture for tests.
TargetPinPosition makePin([double lon = 106.6294, double lat = 10.7629]) {
  return TargetPinPosition(
    coordinates: [lon, lat],
    accuracy: GpsAccuracy.high,
    source: 'fixture',
  );
}

void main() {
  group('TargetCubit', () {
    late FakeTargetRepository repository;
    late FixedBallPositionProvider ballProvider;
    late TargetCubit cubit;

    setUp(() {
      repository = FakeTargetRepository();
      ballProvider = FixedBallPositionProvider();
      cubit = TargetCubit(
        repository: repository,
        ballPositionProvider: ballProvider,
      );
    });

    tearDown(() async {
      await cubit.close();
      await repository.close();
    });

    group('initial state', () {
      test('starts with no target and not loading', () {
        expect(cubit.state.hasTarget, isFalse);
        expect(cubit.state.hasDistances, isFalse);
        expect(cubit.state.isLoading, isFalse);
        expect(cubit.state.errorMessage, isNull);
        expect(cubit.state.isDragging, isFalse);
      });
    });

    group('placeTarget', () {
      test('places target and emits distances when stub pin is set', () async {
        await cubit.initialize(
          roundId: 'round-1',
          holeNumber: 1,
          pin: makePin(),
        );

        await cubit.placeTarget([106.6300, 10.7630]);

        expect(cubit.state.hasTarget, isTrue);
        expect(cubit.state.target!.roundId, 'round-1');
        expect(cubit.state.target!.holeNumber, 1);
        expect(cubit.state.target!.position, [106.6300, 10.7630]);
        expect(cubit.state.target!.accuracy, GpsAccuracy.high);
        expect(cubit.state.hasDistances, isTrue);
        expect(cubit.state.distances!.ballToTargetMeters, greaterThan(0));
        expect(cubit.state.distances!.targetToPinMeters, greaterThan(0));
        expect(cubit.state.isLoading, isFalse);
        expect(cubit.state.errorMessage, isNull);
      });

      test('placeTarget persists to repository', () async {
        await cubit.initialize(
          roundId: 'round-1',
          holeNumber: 3,
          pin: makePin(),
        );

        await cubit.placeTarget([106.6300, 10.7630]);

        final saved = await repository.getTarget('round-1', 3);
        expect(saved, isNotNull);
        expect(saved!.position, [106.6300, 10.7630]);
      });

      test('placeTarget emits error state on repository failure', () async {
        // Use a repository that throws on save
        final throwingRepo = _ThrowingTargetRepository();
        final throwingCubit = TargetCubit(
          repository: throwingRepo,
          ballPositionProvider: ballProvider,
        );

        await throwingCubit.initialize(
          roundId: 'round-1',
          holeNumber: 1,
          pin: makePin(),
        );

        await throwingCubit.placeTarget([106.6300, 10.7630]);

        expect(throwingCubit.state.hasTarget, isFalse);
        // The cubit emits a message key now, translated where it is shown —
        // the English literal it used to carry reached a Vietnamese golfer
        // untranslated.
        expect(
          throwingCubit.state.errorMessage,
          AppMessages.targetActionFailed,
        );
        expect(throwingCubit.state.isLoading, isFalse);

        await throwingCubit.close();
      });

      test('placing without initialization does nothing', () async {
        // cubit has no roundId set
        await cubit.placeTarget([106.6300, 10.7630]);

        expect(cubit.state.hasTarget, isFalse);
        expect(cubit.state.errorMessage, isNull);
      });
    });

    group('moveTarget', () {
      test('moves existing target and recalculates distances', () async {
        await cubit.initialize(
          roundId: 'round-1',
          holeNumber: 2,
          pin: makePin(),
        );

        // Place initial target
        await cubit.placeTarget([106.6300, 10.7630]);
        final originalDistances = cubit.state.distances!;

        // Move target
        await cubit.moveTarget([106.6310, 10.7640]);

        expect(cubit.state.hasTarget, isTrue);
        expect(cubit.state.target!.position, [106.6310, 10.7640]);
        expect(cubit.state.target!.source, TargetSource.drag);
        expect(cubit.state.hasDistances, isTrue);
        // Ball→target distance should be different after move
        expect(
          cubit.state.distances!.ballToTargetMeters,
          isNot(closeTo(originalDistances.ballToTargetMeters, 0.1)),
        );
        expect(cubit.state.isLoading, isFalse);
      });

      test('moveTarget without existing target does nothing', () async {
        await cubit.initialize(
          roundId: 'round-1',
          holeNumber: 4,
          pin: makePin(),
        );

        await cubit.moveTarget([106.6310, 10.7640]);

        expect(cubit.state.hasTarget, isFalse);
      });
    });

    group('initialize', () {
      test('restores existing target from repository', () async {
        // Pre-populate repository
        await repository.saveTarget(TargetModel.placed(
          id: 'target_r1_h5_uuid1',
          roundId: 'round-1',
          holeNumber: 5,
          position: [106.6300, 10.7630],
          accuracy: GpsAccuracy.medium,
        ));

        await cubit.initialize(
          roundId: 'round-1',
          holeNumber: 5,
          pin: makePin(),
        );

        expect(cubit.state.hasTarget, isTrue);
        expect(cubit.state.target!.holeNumber, 5);
        expect(cubit.state.target!.position, [106.6300, 10.7630]);
        expect(cubit.state.hasDistances, isTrue);
      });

      test('initialize with no existing target leaves state empty', () async {
        await cubit.initialize(
          roundId: 'round-1',
          holeNumber: 6,
          pin: makePin(),
        );

        expect(cubit.state.hasTarget, isFalse);
        expect(cubit.state.hasDistances, isFalse);
      });

      test('initialize sets roundId and holeNumber', () async {
        await cubit.initialize(
          roundId: 'round-2',
          holeNumber: 9,
          pin: makePin(),
        );

        await cubit.placeTarget([106.6300, 10.7630]);

        expect(cubit.state.target!.roundId, 'round-2');
        expect(cubit.state.target!.holeNumber, 9);
      });
    });

    group('setHoleNumber', () {
      test('switching hole with existing target clears state', () async {
        await cubit.initialize(
          roundId: 'round-1',
          holeNumber: 1,
          pin: makePin(),
        );
        await cubit.placeTarget([106.6300, 10.7630]);

        await cubit.setHoleNumber(2, pin: makePin());

        expect(cubit.state.hasTarget, isFalse);
      });

      test('switching hole restores target for new hole', () async {
        // Pre-populate hole 3
        await repository.saveTarget(TargetModel.placed(
          id: 'target_r1_h3_uuid1',
          roundId: 'round-1',
          holeNumber: 3,
          position: [106.6300, 10.7630],
          accuracy: GpsAccuracy.high,
        ));

        await cubit.initialize(
          roundId: 'round-1',
          holeNumber: 1,
          pin: makePin(),
        );
        await cubit.placeTarget([106.6300, 10.7630]);

        await cubit.setHoleNumber(3, pin: makePin());

        expect(cubit.state.hasTarget, isTrue);
        expect(cubit.state.target!.holeNumber, 3);
      });
    });

    group('clearTarget', () {
      test('clears target and distances from state and repository', () async {
        await cubit.initialize(
          roundId: 'round-1',
          holeNumber: 7,
          pin: makePin(),
        );
        await cubit.placeTarget([106.6300, 10.7630]);

        await cubit.clearTarget();

        expect(cubit.state.hasTarget, isFalse);
        expect(cubit.state.hasDistances, isFalse);

        final saved = await repository.getTarget('round-1', 7);
        expect(saved, isNull);
      });
    });

    group('setDragging', () {
      test('setDragging(true) updates isDragging in state', () async {
        expect(cubit.state.isDragging, isFalse);

        cubit.setDragging(true);
        expect(cubit.state.isDragging, isTrue);

        cubit.setDragging(false);
        expect(cubit.state.isDragging, isFalse);
      });
    });

    group('startDrag / endDrag (Slice 2)', () {
      test('startDrag enters dragging mode', () async {
        expect(cubit.state.dragMode, TargetDragMode.none);
        expect(cubit.state.isDragging, isFalse);

        cubit.startDrag();

        expect(cubit.state.dragMode, TargetDragMode.dragging);
        expect(cubit.state.isDragging, isTrue);
      });

      test('endDrag exits dragging mode', () async {
        cubit.startDrag();
        expect(cubit.state.dragMode, TargetDragMode.dragging);

        cubit.endDrag();

        expect(cubit.state.dragMode, TargetDragMode.none);
        expect(cubit.state.isDragging, isFalse);
      });

      test('startDrag then endDrag is idempotent', () async {
        cubit.startDrag();
        cubit.startDrag(); // call twice
        cubit.endDrag();

        expect(cubit.state.dragMode, TargetDragMode.none);
      });

      test('setDragging(true) is equivalent to startDrag', () async {
        cubit.setDragging(true);
        expect(cubit.state.dragMode, TargetDragMode.dragging);
        expect(cubit.state.isDragging, isTrue);
      });

      test('setDragging(false) is equivalent to endDrag', () async {
        cubit.startDrag();
        cubit.setDragging(false);
        expect(cubit.state.dragMode, TargetDragMode.none);
        expect(cubit.state.isDragging, isFalse);
      });

      test('drag mode is preserved when target is placed', () async {
        await cubit.initialize(
          roundId: 'round-1',
          holeNumber: 12,
          pin: makePin(),
        );

        cubit.startDrag();
        expect(cubit.state.dragMode, TargetDragMode.dragging);

        await cubit.placeTarget([106.6300, 10.7630]);

        // Placing target does not change drag mode
        expect(cubit.state.dragMode, TargetDragMode.dragging);
        expect(cubit.state.hasTarget, isTrue);

        cubit.endDrag();
        expect(cubit.state.dragMode, TargetDragMode.none);
      });

      test('drag mode is preserved when target is moved', () async {
        await cubit.initialize(
          roundId: 'round-1',
          holeNumber: 13,
          pin: makePin(),
        );
        await cubit.placeTarget([106.6300, 10.7630]);

        cubit.startDrag();
        expect(cubit.state.dragMode, TargetDragMode.dragging);

        await cubit.moveTarget([106.6310, 10.7640]);

        // Moving target does not change drag mode
        expect(cubit.state.dragMode, TargetDragMode.dragging);
        expect(cubit.state.target!.position, [106.6310, 10.7640]);

        cubit.endDrag();
        expect(cubit.state.dragMode, TargetDragMode.none);
      });
    });

    group('clearError', () {
      test('clears error message', () async {
        final throwingRepo = _ThrowingTargetRepository();
        final throwingCubit = TargetCubit(
          repository: throwingRepo,
          ballPositionProvider: ballProvider,
        );

        await throwingCubit.initialize(
          roundId: 'round-1',
          holeNumber: 1,
          pin: makePin(),
        );
        await throwingCubit.placeTarget([106.6300, 10.7630]);

        expect(throwingCubit.state.errorMessage, isNotNull);

        throwingCubit.clearError();
        expect(throwingCubit.state.errorMessage, isNull);

        await throwingCubit.close();
      });
    });

    group('distance calculation', () {
      test('ball→target and target→pin distances are positive', () async {
        await cubit.initialize(
          roundId: 'round-1',
          holeNumber: 8,
          pin: makePin(),
        );

        await cubit.placeTarget([106.6300, 10.7630]);

        expect(cubit.state.distances!.ballToTargetMeters, greaterThan(0));
        expect(cubit.state.distances!.targetToPinMeters, greaterThan(0));
      });

      test('distances timestamp is set', () async {
        await cubit.initialize(
          roundId: 'round-1',
          holeNumber: 10,
          pin: makePin(),
        );

        await cubit.placeTarget([106.6300, 10.7630]);

        expect(cubit.state.distances!.timestamp, isNotNull);
        expect(cubit.state.distances!.timestamp.year, 2026);
      });

      test('without stub pin, no distances computed', () async {
        await cubit.initialize(
          roundId: 'round-1',
          holeNumber: 11,
          pin: null, // no pin available for this hole
        );

        await cubit.placeTarget([106.6300, 10.7630]);

        expect(cubit.state.hasTarget, isTrue);
        expect(cubit.state.hasDistances, isFalse);
      });
    });

    group('TargetDistances', () {
      test('ballToTarget converts to correct unit', () {
        final d = TargetDistances(
          ballToTargetMeters: 100.0,
          targetToPinMeters: 50.0,
          unit: DistanceUnit.meters,
          accuracy: GpsAccuracy.high,
          timestamp: DateTime.now(),
        );

        expect(d.ballToTarget(DistanceUnit.meters), 100.0);
        expect(d.ballToTarget(DistanceUnit.yards), closeTo(109.361, 0.01));
      });

      test('targetToPin converts to correct unit', () {
        final d = TargetDistances(
          ballToTargetMeters: 100.0,
          targetToPinMeters: 50.0,
          unit: DistanceUnit.meters,
          accuracy: GpsAccuracy.high,
          timestamp: DateTime.now(),
        );

        expect(d.targetToPin(DistanceUnit.meters), 50.0);
        expect(d.targetToPin(DistanceUnit.yards), closeTo(54.6805, 0.01));
      });
    });

    group('DistanceCalculator', () {
      test('haversineDistanceMeters returns correct distance', () {
        // Hanoi area: ~111m per degree latitude
        final from = [106.6294, 10.7629];
        final to = [106.6304, 10.7639]; // ~0.001 degree each direction

        final dist = DistanceCalculator.haversineDistanceMeters(from, to);

        // Rough check: ~0.001 degree ≈ 111m at equator
        expect(dist, greaterThan(100));
        expect(dist, lessThan(200));
      });

      test('haversineDistanceMeters zero for identical points', () {
        final point = [106.6294, 10.7629];
        final dist = DistanceCalculator.haversineDistanceMeters(point, point);
        expect(dist, 0);
      });
    });
  });
}

/// Repository that throws on save.
class _ThrowingTargetRepository implements TargetRepository {
  @override
  Future<void> saveTarget(TargetModel target) async {
    throw Exception('Simulated save failure');
  }

  @override
  Future<TargetModel?> getTarget(String roundId, int holeNumber) async => null;

  @override
  Future<void> deleteTarget(String roundId, int holeNumber) async {}

  @override
  Future<List<TargetModel>> getTargetsForRound(String roundId) async => [];

  @override
  Future<void> close() async {}
}
