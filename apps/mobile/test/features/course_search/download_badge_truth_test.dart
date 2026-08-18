// "Đã tải" means this phone has it.
//
// It did not. The badge read `course.hasPackage`, which is the server saying a
// package exists to download, and rendered it as "Đã tải" — so every course
// with a package on the server told the golfer it was already on their phone.
// The screens tour caught it by accident: a simulator that has never
// downloaded anything showed "Đã tải" on Ba Na Hills.
//
// This is the badge the course card was reordered to put first, because it is
// the only one of the three with an action behind it and because "can I play
// this course without a signal?" is a real question asked at nine in the
// evening before a round. It was answering that question wrong, in the
// direction that leaves somebody on a tee with no map.
//
// Three facts, not two: the server has a package, this phone holds one, and
// the two are the same version.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/domain/models/course_search_result.dart';
import 'package:vsp_mobile/features/course_search/presentation/widgets/course_card.dart';
import 'package:vsp_mobile/features/course_search/presentation/widgets/download_state_badge.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

CourseSearchResult _course({
  required bool hasPackage,
  String? latestPackageVersion,
}) => CourseSearchResult(
  courseId: 1351,
  facilityId: 1,
  facilityName: 'Long Biên Golf Course',
  courseName: 'Đường A',
  holesCount: 9,
  hasPackage: hasPackage,
  courseCount: 3,
  updateAvailable: false,
  latestPackageVersion: latestPackageVersion,
);

Future<DownloadState> _badgeState(
  WidgetTester tester, {
  required CourseSearchResult course,
  String? downloadedVersion,
}) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: VspTheme.dark(),
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: CourseCard(
            course: course,
            downloadedVersion: downloadedVersion,
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  final badge = tester.widget<DownloadStateBadge>(
    find.byType(DownloadStateBadge),
  );
  return badge.state;
}

void main() {
  testWidgets('a course this phone has never downloaded does not say it has', (
    tester,
  ) async {
    final state = await _badgeState(
      tester,
      course: _course(hasPackage: true, latestPackageVersion: '1.106.3'),
      downloadedVersion: null,
    );

    expect(
      state,
      DownloadState.notDownloaded,
      reason:
          'the server having a package to give is not the golfer having it — '
          'this is the whole defect',
    );
  });

  testWidgets('a course this phone holds at the current version says so', (
    tester,
  ) async {
    final state = await _badgeState(
      tester,
      course: _course(hasPackage: true, latestPackageVersion: '1.106.3'),
      downloadedVersion: '1.106.3',
    );

    expect(state, DownloadState.downloaded);
  });

  testWidgets('a phone holding last week\'s package is offered the new one', (
    tester,
  ) async {
    // The reason any of this matters today: rebuilding Long Biên's package
    // takes 1.106.3 to 1.106.4, and until now nothing in the app could tell
    // the difference — the parameter that would have said so was never sent
    // by anybody.
    final state = await _badgeState(
      tester,
      course: _course(hasPackage: true, latestPackageVersion: '1.106.4'),
      downloadedVersion: '1.106.3',
    );

    expect(state, DownloadState.updateAvailable);
  });

  testWidgets('a server that will not say which version it has does not nag', (
    tester,
  ) async {
    // An older API answers without `latestPackageVersion`. Treating silence as
    // "yours is stale" would put an update badge on every downloaded course
    // for ever.
    final state = await _badgeState(
      tester,
      course: _course(hasPackage: true),
      downloadedVersion: '1.106.3',
    );

    expect(state, DownloadState.downloaded);
  });
}
