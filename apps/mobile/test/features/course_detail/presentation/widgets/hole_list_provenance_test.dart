// The course detail hole list must not print a bare length for a hole whose
// coordinates nobody verified.
//
// This table is where a golfer meets a course's numbers for the first time,
// and for most holes in the database the number is measured between two points
// that were generated arithmetically. Before this, the row said "362m" and
// nothing else — no badge, no tolerance, no provenance — while the honest
// machinery (the ± in the measuring tool, the "not surveyed" banner on the
// hole map) sat two screens away.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/core/locale/locale_cubit.dart';
import 'package:vsp_mobile/domain/models/course_detail.dart';
import 'package:vsp_mobile/domain/models/data_freshness.dart';
import 'package:vsp_mobile/domain/models/data_quality.dart';
import 'package:vsp_mobile/domain/models/hole_data_provenance.dart';
import 'package:vsp_mobile/domain/models/hole_summary.dart';
import 'package:vsp_mobile/features/course_detail/presentation/widgets/hole_list_section.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/presentation/widgets/distance/not_surveyed_chip.dart';

const HoleDataProvenance _synthetic = HoleDataProvenance(
  accuracyClass: AccuracyClass.classD,
  verificationStatus: VerificationStatus.unverified,
  source: 'synthetic:seed-arithmetic',
);

const HoleDataProvenance _surveyed = HoleDataProvenance(
  accuracyClass: AccuracyClass.classC,
  verificationStatus: VerificationStatus.verified,
);

CourseDetail _course(List<HoleSummary> holes) => CourseDetail(
  courseId: 1,
  facilityId: 1,
  facilityName: 'Long Thành Golf Resort',
  latitude: 10.79,
  longitude: 106.95,
  holesCount: holes.length,
  imageUrls: const [],
  facilities: const [],
  localRules: const [],
  holes: holes,
  teeSets: const [],
  conditions: const [],
);

Future<AppLocalizations> _pump(
  WidgetTester tester,
  CourseDetail course, {
  Locale locale = const Locale('en'),
}) async {
  late AppLocalizations l10n;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return HoleListSection(course: course);
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return l10n;
}

void main() {
  testWidgets('an unverified hole is marked beside its own length', (
    tester,
  ) async {
    final course = _course(const [
      HoleSummary(
        holeNumber: 1,
        par: 4,
        playingLengthMeters: 362,
        provenance: _synthetic,
      ),
      HoleSummary(
        holeNumber: 2,
        par: 5,
        playingLengthMeters: 377,
        provenance: _surveyed,
      ),
    ]);

    await _pump(tester, course);

    expect(find.text('362 m'), findsOneWidget);
    expect(find.text('377 m'), findsOneWidget);

    // One marker on the row, one in the notice above the table. The row marker
    // is what matters: a golfer reading a single line must not have to have
    // read the notice to know what they are looking at.
    expect(find.byType(NotSurveyedChip), findsNWidgets(2));
  });

  testWidgets('a fully surveyed course carries no marker at all', (
    tester,
  ) async {
    final course = _course(const [
      HoleSummary(
        holeNumber: 1,
        par: 4,
        playingLengthMeters: 362,
        provenance: _surveyed,
      ),
    ]);

    await _pump(tester, course);

    expect(find.text('362 m'), findsOneWidget);
    expect(find.byType(NotSurveyedChip), findsNothing);
  });

  testWidgets('a hole with no provenance at all is marked', (tester) async {
    // Fails closed. An older API or a cached payload carries no dataQuality
    // block, and silence is not evidence of a survey.
    final course = _course(const [
      HoleSummary(holeNumber: 1, par: 4, playingLengthMeters: 362),
    ]);

    await _pump(tester, course);

    expect(find.byType(NotSurveyedChip), findsNWidgets(2));
  });

  testWidgets('the notice reads from l10n in both languages', (tester) async {
    final course = _course(const [
      HoleSummary(
        holeNumber: 1,
        par: 4,
        playingLengthMeters: 362,
        provenance: _synthetic,
      ),
    ]);

    final en = await _pump(tester, course);
    final englishNotice = en.holeListUnverifiedNotice(1);
    expect(find.text(englishNotice), findsOneWidget);

    final vi = await _pump(tester, course, locale: const Locale('vi'));
    final vietnameseNotice = vi.holeListUnverifiedNotice(1);
    expect(find.text(vietnameseNotice), findsOneWidget);

    expect(vietnameseNotice, isNot(englishNotice));
  });
}
