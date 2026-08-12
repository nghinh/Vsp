// The screen a golfer types the club's card into.
//
// The card reaches the review queue exactly as typed or it should not leave
// the phone at all: a reviewer looking at a photograph cannot tell that the
// transcription lost a line on the way.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/course_detail.dart';
import 'dart:io';

import 'package:vsp_mobile/features/scorecard/data/scorecard_api.dart';
import 'package:vsp_mobile/features/scorecard/data/scorecard_scan_api.dart';
import 'package:vsp_mobile/features/scorecard/presentation/scorecard_submit_screen.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class _RecordingApi extends ScorecardApi {
  _RecordingApi() : super(apiClient: null);

  int? courseId;
  String? name;
  List<int>? segmentCourseIds;
  List<ScorecardLine>? holes;
  int calls = 0;

  @override
  Future<int> submit({
    required int courseId,
    required String name,
    required List<int> segmentCourseIds,
    required List<ScorecardLine> holes,
    required String idempotencyKey,
    String? evidenceUrl,
    String? note,
  }) async {
    calls++;
    this.courseId = courseId;
    this.name = name;
    this.segmentCourseIds = segmentCourseIds;
    this.holes = holes;
    return 1;
  }
}

class _FakeScanApi extends ScorecardScanApi {
  _FakeScanApi(this.card);

  final ScannedCard card;
  int calls = 0;

  @override
  Future<ScannedCard> scanCourseCard({
    required int courseId,
    required File image,
  }) async {
    calls++;
    return card;
  }
}

void main() {
  const duongA = FacilityCourse(courseId: 21, name: 'Đường A', holesCount: 9);
  const duongB = FacilityCourse(courseId: 22, name: 'Đường B', holesCount: 9);

  Future<_RecordingApi> pump(
    WidgetTester tester, {
    List<FacilityCourse> courses = const [duongA, duongB],
  }) async {
    final api = _RecordingApi();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: ScorecardSubmitScreen(
          courseId: 21,
          facilityCourses: courses,
          defaultName: '',
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  /// The screen holds more than one Scrollable — the list itself, and every
  /// dropdown menu — so the list has to be named rather than guessed at.
  final list = find.byType(Scrollable).first;

  Future<void> fill(WidgetTester tester, int holes) async {
    for (var hole = 1; hole <= holes; hole++) {
      await tester.scrollUntilVisible(
        find.byKey(Key('scorecard_index_$hole')),
        200,
        scrollable: list,
      );
      await tester.tap(find.byKey(Key('scorecard_par_$hole')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(Key('scorecard_index_$hole')), '$hole');
      await tester.pump();
    }
  }

  testWidgets('a card for one đường has nine lines, not eighteen', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byKey(const Key('scorecard_index_9')), findsOneWidget);
    expect(find.byKey(const Key('scorecard_index_10')), findsNothing);
  });

  testWidgets('pairing a second đường makes it eighteen', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('scorecard_segment_22')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('scorecard_index_18')),
      300,
      scrollable: list,
    );
    expect(find.byKey(const Key('scorecard_index_18')), findsOneWidget);
  });

  testWidgets('an incomplete card is not sent', (tester) async {
    // The reviewer's time is the scarce resource here, and a half-typed card
    // costs them a decision they cannot make.
    final api = await pump(tester);

    await tester.enterText(find.byKey(const Key('scorecard_name')), 'A');
    await tester.scrollUntilVisible(
      find.byKey(const Key('scorecard_submit')),
      300,
      scrollable: list,
    );
    await tester.tap(find.byKey(const Key('scorecard_submit')));
    await tester.pump();

    expect(api.calls, 0);
    expect(find.textContaining('chưa có par'), findsOneWidget);
  });

  testWidgets('a complete card goes up whole', (tester) async {
    final api = await pump(tester, courses: const [duongA]);

    await tester.enterText(find.byKey(const Key('scorecard_name')), 'Đường A');
    await fill(tester, 9);
    await tester.scrollUntilVisible(
      find.byKey(const Key('scorecard_submit')),
      300,
      scrollable: list,
    );
    await tester.tap(find.byKey(const Key('scorecard_submit')));
    await tester.pumpAndSettle();

    expect(api.calls, 1);
    expect(api.courseId, 21);
    expect(api.name, 'Đường A');
    expect(api.segmentCourseIds, [21]);
    expect(api.holes, hasLength(9));
    expect(api.holes!.map((h) => h.strokeIndex).toList(), [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
    ]);
    expect(api.holes!.every((h) => h.par == 4), isTrue);
  });

  group('reading the card from a photograph', () {
    ScannedCard cardWith({
      required List<ScannedLine> holes,
      bool parAgrees = true,
      bool indexComplete = true,
      int parRead = 36,
      int? parPrinted = 36,
      int indexCells = 9,
    }) => ScannedCard(
      name: 'Đường A',
      holes: holes,
      checks: ScanChecks(
        holesRead: holes.length,
        parCellsRead: holes.length,
        strokeIndexCellsRead: indexCells,
        parTotalRead: parRead,
        parTotalPrinted: parPrinted,
        parTotalAgrees: parAgrees,
        strokeIndexComplete: indexComplete,
      ),
    );

    testWidgets('a scanned index shows in the box the golfer checks', (
      tester,
    ) async {
      // TextFormField reads initialValue once, on the first build. A scan that
      // only filled the draft would submit numbers the golfer never saw.
      final api = _FakeScanApi(
        cardWith(
          holes: [
            for (var hole = 1; hole <= 9; hole++)
              ScannedLine(hole: hole, par: 4, strokeIndex: hole),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: ScorecardSubmitScreen(
            courseId: 21,
            facilityCourses: const [duongA],
            defaultName: '',
            api: _RecordingApi(),
            scanApi: api,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Drive the screen the way a finished scan does, without a camera.
      tester
          .state<ScorecardSubmitScreenState>(find.byType(ScorecardSubmitScreen))
          .applyScannedCard(api.card);
      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(
        find.byKey(const Key('scorecard_index_3')),
      );
      expect(field.controller?.text, '3');
    });

    testWidgets('shows the card\'s own doubts about the read', (tester) async {
      // The read is not reliable enough to accept silently: eleven of eighteen
      // pars on a real card. What the golfer needs is not a verdict but a
      // pointer to the row worth checking first.
      final api = _FakeScanApi(
        cardWith(
          holes: [
            for (var hole = 1; hole <= 9; hole++)
              ScannedLine(hole: hole, par: 4, strokeIndex: hole),
          ],
          parAgrees: false,
          parRead: 38,
          parPrinted: 36,
          indexComplete: false,
          indexCells: 8,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: ScorecardSubmitScreen(
            courseId: 21,
            facilityCourses: const [duongA],
            defaultName: '',
            api: _RecordingApi(),
            scanApi: api,
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester
          .state<ScorecardSubmitScreenState>(find.byType(ScorecardSubmitScreen))
          .applyScannedCard(api.card);
      await tester.pumpAndSettle();

      expect(find.textContaining('38'), findsOneWidget);
      expect(find.textContaining('chỉ số'), findsOneWidget);
    });

    testWidgets('a card read with gaps leaves them blank, not guessed', (
      tester,
    ) async {
      // The server drops any value a printed card could not hold. A blank box
      // is one tap to fill; a plausible wrong number has to be spotted first.
      final api = _FakeScanApi(
        cardWith(
          holes: [
            for (var hole = 1; hole <= 9; hole++)
              ScannedLine(
                hole: hole,
                par: hole == 4 ? null : 4,
                strokeIndex: hole == 7 ? null : hole,
              ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: ScorecardSubmitScreen(
            courseId: 21,
            facilityCourses: const [duongA],
            defaultName: '',
            api: _RecordingApi(),
            scanApi: api,
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester
          .state<ScorecardSubmitScreenState>(find.byType(ScorecardSubmitScreen))
          .applyScannedCard(api.card);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('scorecard_index_7')))
            .controller
            ?.text,
        isEmpty,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<int>>(
              find.byKey(const Key('scorecard_par_4')),
            )
            .initialValue,
        isNull,
      );
    });
  });
}
