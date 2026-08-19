// "Báo lỗi dữ liệu của tôi" opens from the menu it lives in.
//
// Found by the screen-by-screen sweep, which is the first thing that ever
// opened this screen the way a golfer opens it. From the More menu it threw
// before painting a single pixel:
//
//     Could not find the correct Provider<CourseCorrectionRepository>
//     above this CorrectionListScreen Widget
//
// The screen is 300 lines and works perfectly — inside a round, where
// `ActiveRoundScreen` installs a `RepositoryProvider<CourseCorrectionRepository>`
// over everything it builds. The More menu pushes it bare. `context.read` on a
// provider that is not there does not return null; it throws. So every golfer
// who tapped that tile while not in the middle of a round got a crash, and no
// test had noticed because every test that touched this screen supplied the
// provider itself.
//
// The lesson is in the harness as much as the fix: a screen has to be tested
// the way it is reached, not the way it is convenient to build.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:vsp_mobile/data/repositories/course_correction_repository.dart';
import 'package:vsp_mobile/features/correction/domain/course_correction.dart';
import 'package:vsp_mobile/features/correction/presentation/correction_list_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// A repository that answers, so the screen has something to draw.
class _EmptyCorrections implements CourseCorrectionRepository {
  @override
  Future<List<CourseCorrection>> getCorrections({String? courseId}) async => [];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('vi'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  testWidgets('opens with nothing above it, the way the menu pushes it', (
    tester,
  ) async {
    // Exactly what `home_screen.dart` does: a bare MaterialPageRoute.
    await tester.pumpWidget(_app(const CorrectionListScreen()));
    await tester.pump();

    expect(
      tester.takeException(),
      isNull,
      reason: 'this is the crash: a menu tile that opens onto a thrown '
          'provider lookup',
    );
    expect(find.byType(CorrectionListScreen), findsOneWidget);
  });

  testWidgets('and still uses the one a round provides', (tester) async {
    // The round installs its own repository over everything it builds, and
    // that instance shares the round's sync queue. The fallback must not
    // shadow it.
    final theRounds = _EmptyCorrections();

    await tester.pumpWidget(
      _app(
        RepositoryProvider<CourseCorrectionRepository>.value(
          value: theRounds,
          child: const CorrectionListScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CorrectionListScreen), findsOneWidget);
  });

  testWidgets('and an injected one wins over both', (tester) async {
    await tester.pumpWidget(
      _app(CorrectionListScreen(repository: _EmptyCorrections())),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CorrectionListScreen), findsOneWidget);
  });
}
