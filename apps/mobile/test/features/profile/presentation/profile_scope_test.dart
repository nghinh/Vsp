// Tests for ProfileScope — putting the golfer's profile in scope for subtrees
// that need the saved preferences but do not own the profile screen.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/core/storage/profile_sync_store.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart';
import 'package:vsp_mobile/features/profile/data/profile_repository.dart';
import 'package:vsp_mobile/features/profile/data/profile_service.dart';
import 'package:vsp_mobile/features/profile/presentation/profile_bloc.dart';
import 'package:vsp_mobile/features/profile/presentation/profile_scope.dart';

class _FakeProfileService implements ProfileService {
  int calls = 0;

  @override
  Future<ProfileDTO> getProfile() async {
    calls++;
    return const ProfileDTO(
      id: 1,
      golferAccountId: 42,
      distanceUnit: DistanceUnit.yards,
    );
  }

  @override
  Future<ProfileDTO> updateProfile(
    UpdateProfileRequest request, {
    String? idempotencyKey,
  }) async => throw UnimplementedError();
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

void main() {
  testWidgets('provides a profile and loads it for the subtree', (
    tester,
  ) async {
    final service = _FakeProfileService();
    final connectivity = _FakeConnectivity();
    addTearDown(connectivity.dispose);
    ProfileScope.sharedRepository = ProfileRepository(
      profileService: service,
      syncStore: _FakeSyncStore(),
      connectivity: connectivity,
    );

    ProfileState? seen;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ProfileScope(
          child: BlocBuilder<ProfileBloc, ProfileState>(
            builder: (context, state) {
              seen = state;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.calls, 1, reason: 'the scope loads the profile itself');
    expect(seen, isA<ProfileLoaded>());
    expect(
      (seen! as ProfileLoaded).profile.distanceUnit,
      DistanceUnit.yards,
    );
  });

  testWidgets('does not create a second bloc when one is already in scope', (
    tester,
  ) async {
    final service = _FakeProfileService();
    final connectivity = _FakeConnectivity();
    addTearDown(connectivity.dispose);
    final outer = ProfileBloc(
      profileRepository: ProfileRepository(
        profileService: service,
        syncStore: _FakeSyncStore(),
        connectivity: connectivity,
      ),
    );
    addTearDown(() => unawaited(outer.close()));

    late ProfileBloc resolved;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: BlocProvider<ProfileBloc>.value(
          value: outer,
          // The round screen wraps the map screen, and both scope the profile.
          child: ProfileScope(
            child: ProfileScope(
              child: Builder(
                builder: (context) {
                  resolved = context.read<ProfileBloc>();
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      ),
    );

    expect(identical(resolved, outer), isTrue);
    expect(service.calls, 0, reason: 'the outer bloc owns the loading');
  });

  testWidgets('uses an injected bloc when given one', (tester) async {
    final service = _FakeProfileService();
    final connectivity = _FakeConnectivity();
    addTearDown(connectivity.dispose);
    final injected = ProfileBloc(
      profileRepository: ProfileRepository(
        profileService: service,
        syncStore: _FakeSyncStore(),
        connectivity: connectivity,
      ),
    );
    addTearDown(() => unawaited(injected.close()));

    late ProfileBloc resolved;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ProfileScope(
          profileBloc: injected,
          child: Builder(
            builder: (context) {
              resolved = context.read<ProfileBloc>();
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(identical(resolved, injected), isTrue);
  });
}
