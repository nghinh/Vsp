// Tests for DistanceUnitScope — reading the golfer's metres/yards preference
// out of the widget tree, and reacting when it arrives late.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/core/storage/profile_sync_store.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart';
import 'package:vsp_mobile/features/profile/data/profile_repository.dart';
import 'package:vsp_mobile/features/profile/data/profile_service.dart';
import 'package:vsp_mobile/features/profile/presentation/profile_bloc.dart';

// ─── Fakes ──────────────────────────────────────────────────────────────────

class _FakeProfileService implements ProfileService {
  _FakeProfileService(this.profile);

  ProfileDTO profile;
  final Completer<void> gate = Completer<void>();

  @override
  Future<ProfileDTO> getProfile() async {
    await gate.future;
    return profile;
  }

  @override
  Future<ProfileDTO> updateProfile(
    UpdateProfileRequest request, {
    String? idempotencyKey,
  }) async => profile;
}

class _FakeSyncStore implements ProfileSyncStore {
  @override
  Future<void> close() async {}

  @override
  Future<List<QueuedProfileUpdate>> dequeueAll() async => const [];

  @override
  Future<void> enqueue(String key, UpdateProfileRequest request) async {}

  @override
  Future<bool> hasPending() async => false;

  @override
  Future<void> markSynced(String idempotencyKey) async {}

  @override
  Future<int> pendingCount() async => 0;

  @override
  Future<int> purgeSynced() async => 0;
}

class _FakeConnectivity implements Connectivity {
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => const [
    ConnectivityResult.none,
  ];

  void dispose() => _controller.close();
}

ProfileDTO _profile(DistanceUnit unit) =>
    ProfileDTO(id: 1, golferAccountId: 42, distanceUnit: unit);

/// Bloc + fakes, built inside the test body on purpose: a bloc created in
/// setUp() belongs to the outer zone, and its async work never runs under the
/// widget tester's clock.
class _Harness {
  _Harness({DistanceUnit unit = DistanceUnit.yards})
    : service = _FakeProfileService(_profile(unit)) {
    bloc = ProfileBloc(
      profileRepository: ProfileRepository(
        profileService: service,
        syncStore: _FakeSyncStore(),
        connectivity: connectivity,
      ),
    );
  }

  final _FakeProfileService service;
  final _FakeConnectivity connectivity = _FakeConnectivity();
  late final ProfileBloc bloc;

  /// Not awaited: a test that leaves the profile fetch in flight would block
  /// forever on Bloc.close(), which waits for the handler to finish.
  void dispose() {
    unawaited(bloc.close());
    connectivity.dispose();
  }
}

void main() {
  Future<DistanceUnit> pumpResolve(
    WidgetTester tester, {
    ProfileBloc? bloc,
    DistanceUnit fallback = DistanceUnit.meters,
  }) async {
    late DistanceUnit resolved;
    Widget probe = Builder(
      builder: (context) {
        resolved = DistanceUnitScope.resolve(context, fallback: fallback);
        return const SizedBox();
      },
    );
    if (bloc != null) {
      probe = BlocProvider<ProfileBloc>.value(value: bloc, child: probe);
    }
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: probe,
    ));
    return resolved;
  }

  testWidgets('falls back when no ProfileBloc is in scope', (tester) async {
    expect(
      await pumpResolve(tester, fallback: DistanceUnit.yards),
      DistanceUnit.yards,
    );
  });

  testWidgets('falls back while the profile is still loading', (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    harness.bloc.add(const LoadProfile());
    await tester.pump();

    expect(
      await pumpResolve(tester, bloc: harness.bloc),
      DistanceUnit.meters,
      reason: 'nothing is known yet — do not guess yards',
    );
  });

  testWidgets('reads the golfer\'s saved unit once the profile is loaded', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.dispose);

    harness.bloc.add(const LoadProfile());
    harness.service.gate.complete();
    await tester.pumpAndSettle();

    expect(
      await pumpResolve(tester, bloc: harness.bloc),
      DistanceUnit.yards,
    );
  });

  testWidgets('listen delivers the unit when the profile arrives late', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    final delivered = <DistanceUnit>[];

    await tester.pumpWidget(
      _listenProbe(bloc: harness.bloc, onUnit: delivered.add),
    );

    harness.bloc.add(const LoadProfile());
    await tester.pump();
    expect(delivered, isEmpty, reason: 'still loading');

    harness.service.gate.complete();
    await tester.pumpAndSettle();

    // The golfer opened the map before the profile came back, and still ends
    // up on their own unit.
    expect(delivered, [DistanceUnit.yards]);
  });

  testWidgets('listen reports later changes to the preference', (tester) async {
    final harness = _Harness(unit: DistanceUnit.meters);
    addTearDown(harness.dispose);
    final delivered = <DistanceUnit>[];

    await tester.pumpWidget(
      _listenProbe(bloc: harness.bloc, onUnit: delivered.add),
    );

    harness.bloc.add(const LoadProfile());
    harness.service.gate.complete();
    await tester.pumpAndSettle();
    expect(delivered, [DistanceUnit.meters]);

    harness.bloc.add(
      const UpdateProfileField(
        field: ProfileField.distanceUnit,
        value: DistanceUnit.yards,
      ),
    );
    await tester.pumpAndSettle();

    expect(delivered, [DistanceUnit.meters, DistanceUnit.yards]);
  });

  testWidgets('listen passes the child through with no ProfileBloc in scope', (
    tester,
  ) async {
    var called = false;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) => DistanceUnitScope.listen(
            context: context,
            onUnit: (_, __) => called = true,
            child: const SizedBox(key: Key('child')),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('child')), findsOneWidget);
    expect(called, isFalse);
  });
}

/// A tree with [bloc] in scope and DistanceUnitScope.listen wired to [onUnit].
Widget _listenProbe({
  required ProfileBloc bloc,
  required void Function(DistanceUnit unit) onUnit,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: BlocProvider<ProfileBloc>.value(
      value: bloc,
      child: Builder(
        builder: (context) => DistanceUnitScope.listen(
          context: context,
          onUnit: (_, unit) => onUnit(unit),
          child: const SizedBox(),
        ),
      ),
    ),
  );
}
