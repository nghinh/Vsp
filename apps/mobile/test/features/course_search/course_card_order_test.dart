// What a course card says first.
//
// Three badges sit at the foot of every course in the list: whether it is
// downloaded, whether the data is verified, and how old the data is. They were
// in that order reversed — provenance, provenance, then the one thing a golfer
// can act on.
//
// "Can I play this offline" is the question a course list is being asked at
// home the night before a round, and it is the only badge here with an action
// behind it: tapping it opens the download screen. Verification and freshness
// qualify the data; they are not a decision. Same order the weather panel
// takes with its source badges, and the round summary with the course name
// under the score.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/domain/models/course_search_result.dart';
import 'package:vsp_mobile/domain/models/data_freshness.dart';
import 'package:vsp_mobile/features/course_search/presentation/widgets/course_card.dart';
import 'package:vsp_mobile/features/course_search/presentation/widgets/download_state_badge.dart';
import 'package:vsp_mobile/features/course_search/presentation/widgets/freshness_badge.dart';
import 'package:vsp_mobile/features/course_search/presentation/widgets/verification_badge.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

CourseSearchResult courseWith({required bool hasPackage}) => CourseSearchResult(
  courseId: 1351,
  facilityId: 3,
  facilityName: 'Long Biên Golf Course',
  courseName: 'Đường A',
  address: 'Long Biên, Hà Nội',
  holesCount: 9,
  parTotal: 36,
  hasPackage: hasPackage,
  updateAvailable: false,
  courseCount: 3,
  dataFreshness: DataFreshness(
    publishedAt: DateTime.utc(2026, 8, 16),
    versionNumber: 1,
    verificationStatus: VerificationStatus.verified,
  ),
);

Future<void> pumpCard(WidgetTester tester, {bool hasPackage = true}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: VspTheme.dark(),
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CourseCard(
          course: courseWith(hasPackage: hasPackage),
          onTap: () {},
          onDownloadTap: () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Reading order: down a line first, then across it. Comparing only `dx`
/// would call two badges on different lines of a Wrap equal, because a wrapped
/// row starts back at the same left edge.
int Function(Finder) readingOrderOf(WidgetTester tester) => (finder) {
  final offset = tester.getTopLeft(finder);
  return (offset.dy * 10000 + offset.dx).round();
};

void main() {
  group('the badges under a course', () {
    testWidgets('lead with whether it can be played offline', (tester) async {
      await pumpCard(tester);

      final order = readingOrderOf(tester);

      expect(
        order(find.byType(DownloadStateBadge)),
        lessThan(order(find.byType(VerificationBadge))),
      );
      expect(
        order(find.byType(DownloadStateBadge)),
        lessThan(order(find.byType(FreshnessBadge))),
      );
    });

    testWidgets('and still say where the data came from', (tester) async {
      // Demoting provenance is not deleting it. A course whose geometry
      // nobody checked must still say so on the card somebody picks it from.
      await pumpCard(tester);

      expect(find.byType(VerificationBadge), findsOneWidget);
      expect(find.byType(FreshnessBadge), findsOneWidget);
    });

    testWidgets('for an undownloaded course too', (tester) async {
      await pumpCard(tester, hasPackage: false);

      expect(find.byType(DownloadStateBadge), findsOneWidget);
      final order = readingOrderOf(tester);
      expect(
        order(find.byType(DownloadStateBadge)),
        lessThan(order(find.byType(VerificationBadge))),
      );
    });
  });

  group('the badge with an action behind it', () {
    testWidgets('is not the faintest thing in the row', (tester) async {
      // It was: transparent background, third text tier — the colour the
      // token file reserves for units and timestamps. So "Tải xuống", which
      // needs a tap, read as quieter than "Đã tải", which needs nothing.
      await pumpCard(tester, hasPackage: false);

      final label = tester.widget<Text>(
        find.descendant(
          of: find.byType(DownloadStateBadge),
          matching: find.byType(Text),
        ).first,
      );
      final tiers = VspTextTiers.dark;

      expect(label.style?.color, isNot(tiers.tertiary));
      expect(label.style?.color, VspTheme.dark().colorScheme.primary);
    });
  });

  group('the badges themselves', () {
    testWidgets('flow onto a second line rather than clip', (tester) async {
      // Three badges of translated text on a 360 dp card. At a larger text
      // size the question is not whether they still fit on one line — they
      // cannot — but whether they wrap or overflow. Reading order proves it:
      // a wrapped badge starts a new line, a clipped one never moves.
      await pumpCard(tester);
      final atNormal = tester.getTopLeft(find.byType(FreshnessBadge)).dy;

      tester.view.physicalSize = const Size(1080, 2400);
      await tester.pumpWidget(
        MaterialApp(
          theme: VspTheme.dark(),
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: CourseCard(
                course: courseWith(hasPackage: true),
                onTap: () {},
                onDownloadTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.byType(FreshnessBadge)).dy,
        greaterThan(atNormal),
        reason: 'the last badge should have moved down a line, not vanished',
      );
    });
  });
}
