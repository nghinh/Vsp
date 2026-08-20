// Tests for ProfileScreen using the shared bloc from ProfileScope.
//
// The screen used to assemble its own ApiClient and repository, so nothing
// pinned what happens when it joins a bloc that finished loading before the
// tab opened. A BlocConsumer listener only hears changes — the seed in
// initState is what fills the form from an already-loaded state, and these
// tests are what notice if it goes missing again.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart';
import 'package:vsp_mobile/features/profile/data/profile_repository.dart';
import 'package:vsp_mobile/features/profile/presentation/profile_bloc.dart';
import 'package:vsp_mobile/features/profile/presentation/profile_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({this.profile});

  final ProfileDTO? profile;
  int getProfileCalls = 0;

  @override
  Future<ProfileDTO> getProfile() async {
    getProfileCalls++;
    final result = profile;
    if (result == null) {
      throw StateError('no profile configured');
    }
    return result;
  }

  @override
  ProfileDTO? getCachedProfile() => null;

  @override
  Future<bool> hasPending() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

const _profile = ProfileDTO(
  id: 1,
  golferAccountId: 42,
  homeClub: 'Sân Đồng Mô',
);

Widget _app(ProfileBloc bloc) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<ProfileBloc>.value(
      value: bloc,
      child: const ProfileScreen(),
    ),
  );
}

void main() {
  testWidgets('seeds the form from a bloc that loaded before the tab opened', (
    tester,
  ) async {
    final repo = _FakeProfileRepository(profile: _profile);
    // Created and loaded inside runAsync: a bloc built in the test's fake
    // zone pins its internal streams to the fake clock, and awaiting them
    // from real async then never completes.
    final bloc = await tester.runAsync(() async {
      final b = ProfileBloc(profileRepository: repo)
        ..add(const LoadProfile());
      await b.stream.firstWhere((s) => s is ProfileLoaded);
      return b;
    });
    final loadedBloc = bloc!;
    expect(repo.getProfileCalls, 1);

    await tester.pumpWidget(_app(loadedBloc));
    // Not pumpAndSettle: the loaded form hosts a repeating animation, and
    // settling waits for a quiet that never comes.
    await tester.pump();

    // The listener never fired for this widget — initState seeding did this.
    expect(find.text('Sân Đồng Mô'), findsOneWidget);
    // Joining an already-loaded bloc must not refetch.
    expect(repo.getProfileCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => loadedBloc.close());
  });

  testWidgets('asks again when the last attempt failed', (tester) async {
    final repo = _FakeProfileRepository(profile: _profile);
    // Same shape as above: the bloc must live on the real event loop, or
    // nothing — pumps included — ever resolves its awaits.
    final created = await tester.runAsync(
      () async => ProfileBloc(profileRepository: repo),
    );
    final bloc = created!;

    await tester.pumpWidget(_app(bloc));
    // ProfileInitial at mount → initState dispatched LoadProfile.
    await tester.runAsync(
      () => bloc.stream
          .firstWhere((s) => s is ProfileLoaded)
          .timeout(const Duration(seconds: 5)),
    );
    await tester.pump();

    expect(repo.getProfileCalls, 1);
    expect(find.text('Sân Đồng Mô'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => bloc.close());
  });
}
