// Which package the download button fetches, and for whom.
//
// A golfer downloaded Long Biên's data, came back to the setup screen, and was
// told again that the course data was not downloaded. Two separate faults, and
// the banner looked identical under both.
//
// The first is here: the button downloaded `courseId`, which on a club with
// several đường is whichever one the course search happened to return. The
// readiness check is careful about this — it walks every đường the round is
// actually played on — so a round on A+B with B missing would report "not
// downloaded", download A, and find nothing had changed. Twice, three times,
// as many times as the golfer was willing to try.
//
// The second fault is not testable here and is worth writing down anyway: the
// screen pushed the download route without awaiting it and never re-ran the
// check when it closed. Readiness is read once when the form is built, so
// returning from a successful download changed nothing the banner was
// watching. That fix is three lines of control flow in
// `_RoundSetupScaffold._openDownload`.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/round_setup/presentation/round_setup_state.dart';

void main() {
  const duongA = LayoutOption(id: 21, name: 'Đường A', holeCount: 9);
  const duongB = LayoutOption(id: 22, name: 'Đường B', holeCount: 9);

  RoundSetupReady form({
    int? courseId = 21,
    int? selected,
    int? second,
    PackageReadiness? readiness,
  }) => RoundSetupReady(
    courseId: courseId,
    courseName: 'Long Biên Golf Course',
    layouts: const [duongA, duongB],
    selectedLayoutId: selected,
    selectedSecondLayoutId: second,
    packageReadiness: readiness,
  );

  group('the course the download button fetches', () {
    test('is the đường the check found wanting, not the one on the form', () {
      // A+B, and it is B that has no package. This is the whole bug: the
      // button used to fetch 21, which was already on the phone.
      final state = form(
        courseId: 21,
        selected: 21,
        second: 22,
        readiness: const PackageReadiness(
          status: PackageStatus.notDownloaded,
          missingCourseId: 22,
        ),
      );

      expect(state.packageDownloadCourseId, 22);
    });

    test('is the first đường when that is the one missing', () {
      final state = form(
        selected: 21,
        second: 22,
        readiness: const PackageReadiness(
          status: PackageStatus.notDownloaded,
          missingCourseId: 21,
        ),
      );

      expect(state.packageDownloadCourseId, 21);
    });

    test('falls back to the chosen course before any check has run', () {
      // No readiness yet: the form is still resolving, and the golfer may
      // still tap. The club's own course is the best guess available and it
      // is right whenever there is only one đường.
      final state = form(courseId: 21, readiness: null);

      expect(state.packageDownloadCourseId, 21);
    });

    test('is nothing at all when no course is chosen', () {
      // Nothing to download, and the banner renders no button rather than one
      // that opens a download screen for a course that does not exist.
      final state = form(courseId: null, readiness: null);

      expect(state.packageDownloadCourseId, isNull);
    });

    test('a corrupted package is re-fetched for the đường that is corrupt', () {
      // The same button serves "download" and "download again", and the
      // second one has exactly the same way of picking the wrong nine.
      final state = form(
        selected: 21,
        second: 22,
        readiness: const PackageReadiness(
          status: PackageStatus.invalid,
          missingCourseId: 22,
        ),
      );

      expect(state.packageDownloadCourseId, 22);
    });
  });
}
