// When the home shell builds its tabs.
//
// IndexedStack builds every child. That is what preserves a tab's state when
// you come back to it, and it also meant a cold start built all five tabs at
// once — Profile, Courses and Rounds each fetch on construction, so opening
// the app fired four requests for screens nobody was looking at.
//
// One of them was visible. The profile fetch raced session restore, lost, got
// a 401, and posted "Failed to load profile. Please try again." across the
// bottom of the Play tab before the golfer had touched anything. The bug was
// never in the profile code — /profiles/me answers 200 — it was in *when* it
// was called.
//
// These pin both halves: nothing unvisited is built, and a tab that has been
// visited stays built so switching away and back does not reload it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/auth/presentation/home_screen.dart';
import 'package:vsp_mobile/features/course_search/presentation/course_search_screen.dart';
import 'package:vsp_mobile/features/profile/presentation/profile_screen.dart';
import 'package:vsp_mobile/features/round/presentation/rounds_history_tab.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomeScreen(),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('a cold start builds only the tab on screen', (tester) async {
    await _pump(tester);

    expect(
      find.byType(ProfileScreen, skipOffstage: false),
      findsNothing,
      reason: 'Profile fetches on construction and its failure lands on Play',
    );
    expect(find.byType(CourseSearchScreen, skipOffstage: false), findsNothing);
    expect(find.byType(RoundsHistoryTab, skipOffstage: false), findsNothing);
  });

  testWidgets('the stack still has a slot for every tab', (tester) async {
    // Lazy must not mean absent: IndexedStack indexes by position, so dropping
    // a child would shift every tab after it onto the wrong screen.
    await _pump(tester);

    final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(stack.children.length, 5);
    expect(stack.index, 0);
  });

  testWidgets('opening a tab builds it, and it stays built afterwards', (
    tester,
  ) async {
    await _pump(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l10n.navRounds));
    await tester.pump();
    expect(find.byType(RoundsHistoryTab, skipOffstage: false), findsOneWidget);

    // Back to Play: the visited tab keeps its state rather than being rebuilt
    // from scratch the next time it is opened.
    await tester.tap(find.text(l10n.navPlay));
    await tester.pump();
    expect(find.byType(RoundsHistoryTab, skipOffstage: false), findsOneWidget);
  });
}
