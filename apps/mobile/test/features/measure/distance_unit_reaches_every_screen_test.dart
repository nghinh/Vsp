// The golfer's metres/yards preference, on the screens that used to ignore it.
//
// The report that prompted this was concrete: "Setting hồ sơ là yard nhưng rất
// nhiều chỗ vẫn hiện là met... ở chỗ carry của gậy trong bag vẫn là met." The
// bag was one of about forty places printing a hardcoded unit, and the reason
// none of them could have worked is below — ProfileScope only wrapped the map
// and the active round, so every other route resolved to the metres fallback
// no matter what was saved.
//
// So these tests are about reach, not about arithmetic: MeasureUnits already
// converted correctly and has its own tests. What is checked here is that the
// preference arrives at the widget at all.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/core/storage/profile_sync_store.dart';
import 'package:vsp_mobile/domain/models/hole_summary.dart';
import 'package:vsp_mobile/features/bag/data/bag_dto.dart';
import 'package:vsp_mobile/features/bag/presentation/widgets/club_card.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart';
import 'package:vsp_mobile/features/profile/data/profile_repository.dart';
import 'package:vsp_mobile/features/profile/data/profile_service.dart';
import 'package:vsp_mobile/features/profile/presentation/profile_scope.dart';
import 'package:vsp_mobile/features/round_setup/presentation/round_setup_state.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class _ProfileSaying implements ProfileService {
  _ProfileSaying(this.unit);

  final DistanceUnit unit;

  @override
  Future<ProfileDTO> getProfile() async =>
      ProfileDTO(id: 1, golferAccountId: 42, distanceUnit: unit);

  @override
  Future<ProfileDTO> updateProfile(
    UpdateProfileRequest request, {
    String? idempotencyKey,
  }) async => throw UnimplementedError();
}

class _NoSyncStore implements ProfileSyncStore {
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

class _Offline implements Connectivity {
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

/// Pumps [child] under a profile that reads in [unit], as the app now does.
Future<void> _pumpUnder(
  WidgetTester tester,
  DistanceUnit unit,
  Widget child,
) async {
  final connectivity = _Offline();
  addTearDown(connectivity.dispose);
  ProfileScope.sharedRepository = ProfileRepository(
    profileService: _ProfileSaying(unit),
    syncStore: _NoSyncStore(),
    connectivity: connectivity,
  );

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ProfileScope(child: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
}

const _driver = ClubDTO(
  id: 1,
  golfBagId: 5,
  clubType: ClubType.driver,
  carryDistance: 220.0,
);

void main() {
  group('the bag', () {
    testWidgets('prints a club carry in yards for a golfer who reads yards', (
      tester,
    ) async {
      await _pumpUnder(
        tester,
        DistanceUnit.yards,
        const ClubCard(club: _driver),
      );

      // 220 m × 1.09361, rounded.
      expect(find.text('241 yd'), findsOneWidget);
      expect(find.text('220 m'), findsNothing);
    });

    testWidgets('and in metres for a golfer who reads metres', (tester) async {
      await _pumpUnder(
        tester,
        DistanceUnit.meters,
        const ClubCard(club: _driver),
      );

      expect(find.text('220 m'), findsOneWidget);
    });
  });

  group('the context extension', () {
    testWidgets('answers with the saved unit on a plain route', (tester) async {
      late DistanceUnit resolved;
      late String formatted;

      await _pumpUnder(
        tester,
        DistanceUnit.yards,
        Builder(
          builder: (context) {
            resolved = context.distanceUnit;
            formatted = context.formatDistance(150);
            return const SizedBox();
          },
        ),
      );

      expect(resolved, DistanceUnit.yards);
      expect(formatted, '164 yd');
    });

    testWidgets('turns what the golfer typed back into metres', (tester) async {
      late double canonical;

      await _pumpUnder(
        tester,
        DistanceUnit.yards,
        Builder(
          builder: (context) {
            canonical = context.toCanonicalMeters(241);
            return const SizedBox();
          },
        ),
      );

      // The club form stores this, so a yards golfer typing 241 must not end
      // up with a 241-metre driver.
      expect(canonical, closeTo(220, 0.5));
    });

    testWidgets('falls back to metres where no profile is in scope', (
      tester,
    ) async {
      late String formatted;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              formatted = context.formatDistance(150);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(formatted, '150 m');
    });
  });

  group('values that are metres despite their name', () {
    test('a hole length reads in the golfer own unit', () {
      const hole = HoleSummary(
        holeNumber: 1,
        par: 4,
        playingLengthMeters: 362,
      );

      expect(hole.formattedLength(DistanceUnit.meters), '362 m');
      expect(hole.formattedLength(DistanceUnit.yards), '396 yd');
    });

    test('a tee total is metres, whatever the contract calls the field', () {
      // TeeOption.totalDistance is summed from TeeSetSummaryDto.yardages,
      // which the OpenAPI contract describes as metres. The label used to
      // suffix `y`, which did not overstate the number — it renamed the course.
      const gold = TeeOption(id: 1, name: 'GOLD', totalDistance: 6688);

      expect(teeLabel(gold, DistanceUnit.meters), 'GOLD · 6.688 m');
      expect(teeLabel(gold, DistanceUnit.yards), 'GOLD · 7.314 yd');
    });
  });
}
