// A tee with no published par says nothing, rather than "Par 0".
//
// Found on the club page for Long Biên's Đường A during the screen sweep. Under
// the Gold tee, beside four real yardages, the app printed:
//
//     Par
//     0
//
// The server sends `totalPar: null` for every tee at that club — nobody has
// entered it — and the model coerced null to zero on the way in. Zero is not
// "unknown". It is a number, on the screen a golfer reads before deciding
// which tee to play, and it is wrong: the nine is par 36.
//
// The rating and slope chips sitting beside it already omit themselves when
// they have nothing to say. This one now does the same, which is the whole fix:
// the app should be as sure as its data and no surer.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/domain/models/course_detail.dart';
import 'package:vsp_mobile/domain/models/tee_set_summary.dart';
import 'package:vsp_mobile/features/course_detail/presentation/widgets/tee_set_section.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Long Biên's Gold tee exactly as the server sends it: real yardages, no par,
/// no rating, no slope.
TeeSetSummary _gold({int? totalPar}) => TeeSetSummary(
  id: 1,
  name: 'Gold',
  totalPar: totalPar,
  yardages: const {
    '1': 481, '2': 449, '3': 381, '4': 208, '5': 543,
    '6': 199, '7': 383, '8': 480, '9': 539,
  },
  accuracyClass: 'C',
);

/// The club page as the course-detail screen builds it, with one tee on it.
CourseDetail _club(TeeSetSummary tee) => CourseDetail(
  courseId: 1351,
  facilityId: 3,
  facilityName: 'Long Biên Golf Course',
  latitude: 21.0384,
  longitude: 105.8920,
  holesCount: 9,
  imageUrls: const [],
  facilities: const [],
  localRules: const [],
  holes: const [],
  teeSets: [tee],
  conditions: const [],
);

Future<void> _pump(WidgetTester tester, TeeSetSummary tee) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: TeeSetSection(course: _club(tee))),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no published par means no par chip', (tester) async {
    await _pump(tester, _gold());

    expect(
      find.text('0'),
      findsNothing,
      reason: 'this is the defect: "Par 0" on a nine that is par 36',
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
    expect(find.text(l10n.fieldPar), findsNothing);
  });

  testWidgets('and a published par is still shown', (tester) async {
    // The fix must not hide real data. A club that has entered its par gets it
    // printed exactly as before.
    await _pump(tester, _gold(totalPar: 36));

    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
    expect(find.text(l10n.fieldPar), findsOneWidget);
    expect(find.text('36'), findsOneWidget);
  });

  test('null survives the wire rather than becoming zero', () {
    final parsed = TeeSetSummary.fromJson(const {
      'id': 1,
      'name': 'Gold',
      'totalPar': null,
      'yardages': {'1': 481},
      'accuracyClass': 'C',
    });

    expect(
      parsed.totalPar,
      isNull,
      reason: 'the coercion in fromJson is where the zero came from',
    );
  });

  test('and a real par is parsed', () {
    final parsed = TeeSetSummary.fromJson(const {
      'id': 1,
      'name': 'Gold',
      'totalPar': 72,
      'yardages': <String, int>{},
      'accuracyClass': 'C',
    });

    expect(parsed.totalPar, 72);
  });
}
