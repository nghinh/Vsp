// Both nines of a paired round, on screen at once.
//
// Reported 17/8/2026 and then checked against the phone that reported it. Its
// app container held exactly one package — `packages/1352/1.107.2`, Đường B —
// and one manifest row, `course_id 1352`. No directory for 1351, no manifest,
// not even a pending one, and a pending manifest is written *before* the first
// file is fetched. So Đường A had never been downloaded and the app was
// telling the truth throughout.
//
// What it could not do was tell the truth twice at once. The banner described
// one đường per visit: download Đường B and it reads "Sẵn sàng ngoại tuyến";
// pick Đường A → Đường B and it reads "Chưa tải dữ liệu Đường A". A golfer
// reading those in sequence concludes the download did not stick, and no
// amount of rewording either sentence fixes that — the two facts have to share
// a screen.
//
// The readiness walk also stopped at the first failure, so the state could not
// have answered "what about the other one" if asked.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/round_setup/presentation/round_setup_state.dart';

void main() {
  const duongA = LayoutOption(id: 1351, name: 'Đường A', holeCount: 9);
  const duongB = LayoutOption(id: 1352, name: 'Đường B', holeCount: 9);
  const duongC = LayoutOption(id: 1353, name: 'Đường C', holeCount: 9);

  /// The phone as it actually was: B downloaded, A not.
  const asOnTheDevice = [
    SegmentPackage(courseId: 1351, name: 'Đường A', isReady: false),
    SegmentPackage(courseId: 1352, name: 'Đường B', isReady: true),
  ];

  RoundSetupReady form({
    int? selected = 1351,
    int? second = 1352,
    List<SegmentPackage> segments = asOnTheDevice,
    PackageStatus status = PackageStatus.notDownloaded,
  }) => RoundSetupReady(
    courseId: 1351,
    courseName: 'Long Biên Golf Course',
    layouts: const [duongA, duongB, duongC],
    selectedLayoutId: selected,
    selectedSecondLayoutId: second,
    packageReadiness: PackageReadiness(
      status: status,
      missingCourseId: 1351,
      segments: segments,
    ),
  );

  group('a paired round carries a state per đường', () {
    test('both are present, not just the one that failed', () {
      final segments = form().packageReadiness!.segments;

      expect(segments.map((s) => s.courseId), [1351, 1352]);
    });

    test('and they say which is which', () {
      final segments = form().packageReadiness!.segments;

      expect(segments.first.name, 'Đường A');
      expect(segments.first.isReady, isFalse);
      expect(segments.last.name, 'Đường B');
      expect(segments.last.isReady, isTrue);
    });

    test('in playing order, not id order', () {
      final state = form(selected: 1353, second: 1351, segments: const [
        SegmentPackage(courseId: 1353, name: 'Đường C', isReady: true),
        SegmentPackage(courseId: 1351, name: 'Đường A', isReady: false),
      ]);

      expect(
        state.packageReadiness!.segments.map((s) => s.name),
        ['Đường C', 'Đường A'],
      );
    });
  });

  group('the download button', () {
    test('offers the đường that is missing, not the first of the round', () {
      // Long Biên's A is first and B is downloaded here, so getting this
      // backwards sends the golfer to re-download something they have.
      final state = form();

      expect(state.packageDownloadCourseId, 1351);
      expect(state.packageDownloadCourseName, 'Đường A');
    });
  });

  group('a round on one đường', () {
    test('carries no per-segment list, because there is nothing to compare', () {
      final state = form(
        selected: 1352,
        second: null,
        segments: const [],
        status: PackageStatus.valid,
      );

      expect(state.packageReadiness!.segments, isEmpty);
      // The single-line answer still names it, which is the fix that came
      // first and is not enough on its own.
      expect(state.readyCourseNames, 'Đường B');
    });
  });

  _siblings();
}

// ─── One download covers the club ──────────────────────────────────────────
//
// "Khi tôi tải sân thì tải hết các đường luôn" — and the reason it was worth
// asking for: a package is per-nine, so downloading the nine that was asked
// for left the golfer to discover the next one by being refused. On a club
// with three nines that is three separate discoveries.

void _siblings() {
  const duongA = LayoutOption(id: 1351, name: 'Đường A', holeCount: 9);
  const duongB = LayoutOption(id: 1352, name: 'Đường B', holeCount: 9);
  const duongC = LayoutOption(id: 1353, name: 'Đường C', holeCount: 9);

  RoundSetupReady club(List<LayoutOption> layouts) => RoundSetupReady(
    courseId: 1351,
    courseName: 'Long Biên Golf Course',
    layouts: layouts,
  );

  group('downloading one đường', () {
    test('brings the club\'s other đường with it', () {
      final state = club(const [duongA, duongB, duongC]);

      expect(state.otherLayoutIds(1351), [1352, 1353]);
    });

    test('and never asks for the one already being fetched', () {
      final state = club(const [duongA, duongB, duongC]);

      expect(state.otherLayoutIds(1352), isNot(contains(1352)));
      expect(state.otherLayoutIds(1352), [1351, 1353]);
    });

    test('on a club with one layout there is nothing to bring', () {
      final state = club(const [duongA]);

      expect(state.otherLayoutIds(1351), isEmpty);
    });
  });
}
