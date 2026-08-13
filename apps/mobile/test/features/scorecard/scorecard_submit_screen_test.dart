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
  List<Map<String, dynamic>>? tees;
  int? parOut;
  int? parIn;
  int? parTotal;
  String? evidenceUrl;
  int calls = 0;

  @override
  Future<int> submit({
    required int courseId,
    required String name,
    required List<int> segmentCourseIds,
    required List<ScorecardLine> holes,
    required String idempotencyKey,
    List<Map<String, dynamic>> tees = const [],
    int? parOut,
    int? parIn,
    int? parTotal,
    String? evidenceUrl,
    String? note,
  }) async {
    calls++;
    this.courseId = courseId;
    this.name = name;
    this.segmentCourseIds = segmentCourseIds;
    this.holes = holes;
    this.tees = tees;
    this.parOut = parOut;
    this.parIn = parIn;
    this.parTotal = parTotal;
    this.evidenceUrl = evidenceUrl;
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
      List<ScannedTee> tees = const [],
      int? parOutPrinted,
      int? parInPrinted,
      String? photoUrl,
    }) => ScannedCard(
      name: 'Đường A',
      holes: holes,
      tees: tees,
      photoUrl: photoUrl,
      checks: ScanChecks(
        holesRead: holes.length,
        parCellsRead: holes.length,
        strokeIndexCellsRead: indexCells,
        parTotalRead: parRead,
        parTotalPrinted: parPrinted,
        parTotalAgrees: parAgrees,
        strokeIndexComplete: indexComplete,
        parOutPrinted: parOutPrinted,
        parInPrinted: parInPrinted,
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

    testWidgets(
      "what the club printed, and the photograph, travel with the card",
      (tester) async {
        // The reader has always read the par row's printed sums and the app
        // has always shown them, but there was no field to send them in, so
        // they stopped at this screen. That left the server with no
        // independent check on eighteen hand-copied pars at all — only the
        // pars against themselves. The photograph went the same way: the only
        // means of attaching one was a URL typed by hand.
        final recording = _RecordingApi();
        final scan = _FakeScanApi(
          cardWith(
            holes: [
              for (var hole = 1; hole <= 9; hole++)
                ScannedLine(hole: hole, par: 4, strokeIndex: hole),
            ],
            parOutPrinted: 36,
            parInPrinted: 36,
            parPrinted: 72,
            photoUrl: '/scorecard-photos/abc.jpg',
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
              api: recording,
              scanApi: scan,
            ),
          ),
        );
        await tester.pumpAndSettle();

        tester
            .state<ScorecardSubmitScreenState>(
              find.byType(ScorecardSubmitScreen),
            )
            .applyScannedCard(scan.card);
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.byKey(const Key('scorecard_submit')),
          200,
          scrollable: list,
        );
        await tester.tap(find.byKey(const Key('scorecard_submit')));
        await tester.pumpAndSettle();

        expect(recording.parOut, 36);
        expect(recording.parIn, 36);
        expect(recording.parTotal, 72);
        expect(recording.evidenceUrl, '/scorecard-photos/abc.jpg');
      },
    );

    testWidgets('the tee rows the scan read travel with the card', (
      tester,
    ) async {
      // Course rating and slope are what turn a round into a handicap
      // differential, they are printed on the card and nowhere else, and a
      // golfer cannot check ninety yardages at the tee. Dropping them on the
      // floor would mean photographing the card twice: once for the pars now,
      // once for the ratings when somebody notices they are missing.
      final recording = _RecordingApi();
      final scan = _FakeScanApi(
        cardWith(
          holes: [
            for (var hole = 1; hole <= 9; hole++)
              ScannedLine(hole: hole, par: 4, strokeIndex: hole),
          ],
          tees: const [
            ScannedTee(
              name: 'GOLD',
              courseRating: 75.5,
              slopeRating: 138,
              yardages: {1: 418, 2: 383},
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
            api: recording,
            scanApi: scan,
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester
          .state<ScorecardSubmitScreenState>(find.byType(ScorecardSubmitScreen))
          .applyScannedCard(scan.card);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('scorecard_submit')),
        200,
        scrollable: list,
      );
      await tester.tap(find.byKey(const Key('scorecard_submit')));
      await tester.pumpAndSettle();

      expect(recording.calls, 1);
      expect(recording.tees, hasLength(1));
      expect(recording.tees!.single['name'], 'GOLD');
      expect(recording.tees!.single['courseRating'], 75.5);
      expect(recording.tees!.single['slopeRating'], 138);
      expect(recording.tees!.single['yardages'], [
        {'hole': 1, 'yards': 418},
        {'hole': 2, 'yards': 383},
      ]);
    });

    testWidgets('a tee row that contradicts its own printed sum is named', (
      tester,
    ) async {
      // Ninety three-digit cells on a five-tee card, against par's eighteen
      // single digits, and until now nothing compared any of them to
      // anything. The golfer cannot check ninety numbers at the tee; they can
      // check whether one row adds up to the figure printed beside it, which
      // is one glance and tells them which row to look at.
      final scan = _FakeScanApi(
        cardWith(
          holes: [
            for (var hole = 1; hole <= 9; hole++)
              ScannedLine(hole: hole, par: 4, strokeIndex: hole),
          ],
          tees: const [
            ScannedTee(
              name: 'GOLD',
              yardages: {1: 450, 2: 400},
              checks: TeeChecks(
                yardsOutRead: 850,
                yardsInRead: 0,
                yardsOutPrinted: 800,
                yardsAgree: false,
                yardsChecked: true,
              ),
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
            scanApi: scan,
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester
          .state<ScorecardSubmitScreenState>(find.byType(ScorecardSubmitScreen))
          .applyScannedCard(scan.card);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(RegExp(r'GOLD.*850.*800')),
        findsOneWidget,
        reason: 'the warning names the row, the sum read and the sum printed',
      );
    });

    testWidgets('a tee row that adds up raises nothing', (tester) async {
      final scan = _FakeScanApi(
        cardWith(
          holes: [
            for (var hole = 1; hole <= 9; hole++)
              ScannedLine(hole: hole, par: 4, strokeIndex: hole),
          ],
          tees: const [
            ScannedTee(
              name: 'GOLD',
              yardages: {1: 400, 2: 400},
              checks: TeeChecks(
                yardsOutRead: 800,
                yardsInRead: 0,
                yardsOutPrinted: 800,
                yardsAgree: true,
                yardsChecked: true,
              ),
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
            scanApi: scan,
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester
          .state<ScorecardSubmitScreenState>(find.byType(ScorecardSubmitScreen))
          .applyScannedCard(scan.card);
      await tester.pumpAndSettle();

      expect(find.textContaining('GOLD'), findsNothing);
    });

    testWidgets('a card photographed without its tee table sends no tees', (
      tester,
    ) async {
      // An empty list would read as "this club prints no tees", which is a
      // claim about the club rather than about the photograph.
      final recording = _RecordingApi();
      final scan = _FakeScanApi(
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
            api: recording,
            scanApi: scan,
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester
          .state<ScorecardSubmitScreenState>(find.byType(ScorecardSubmitScreen))
          .applyScannedCard(scan.card);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('scorecard_submit')),
        200,
        scrollable: list,
      );
      await tester.tap(find.byKey(const Key('scorecard_submit')));
      await tester.pumpAndSettle();

      expect(recording.calls, 1);
      expect(recording.tees, isEmpty);
    });
  });
}
