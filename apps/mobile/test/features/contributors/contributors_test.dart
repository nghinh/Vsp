// Credit for the people who filled in the cards.
//
// The line on a course is absent, not empty, where nobody contributed — most
// courses came from the import, and "đóng góp bởi: không ai" is worse than
// silence.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/contributors/contributors.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class _FakeApi extends ContributorApi {
  _FakeApi({this.people = const [], this.fail = false});

  final List<Contributor> people;
  final bool fail;

  @override
  Future<List<Contributor>> forCourse(int courseId) async {
    if (fail) throw Exception('offline');
    return people;
  }

  @override
  Future<List<Contributor>> leaderboard() async {
    if (fail) throw Exception('offline');
    return people;
  }
}

Widget host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('names who filled in this course', (tester) async {
    await tester.pumpWidget(host(CourseCreditLine(
      courseId: 1,
      api: _FakeApi(people: const [
        Contributor(
            displayName: 'Nghi', approvedCorrections: 11, coursesCovered: 9),
      ]),
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nghi'), findsOneWidget);
  });

  testWidgets('a course nobody contributed to shows no line', (tester) async {
    await tester.pumpWidget(host(CourseCreditLine(courseId: 1, api: _FakeApi())));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('course_credit_line')), findsNothing);
  });

  testWidgets('the board ranks contributors, most first', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: ContributorsScreen(
        api: _FakeApi(people: const [
          Contributor(
              displayName: 'Nghi', approvedCorrections: 11, coursesCovered: 9),
          Contributor(
              displayName: 'Minh', approvedCorrections: 2, coursesCovered: 1),
        ]),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Nghi'), findsOneWidget);
    expect(find.text('Minh'), findsOneWidget);
    expect(find.textContaining('11 thẻ đã duyệt'), findsOneWidget);
  });

  testWidgets('offline leaves the course page alone', (tester) async {
    await tester.pumpWidget(
        host(CourseCreditLine(courseId: 1, api: _FakeApi(fail: true))));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('course_credit_line')), findsNothing);
  });
}
