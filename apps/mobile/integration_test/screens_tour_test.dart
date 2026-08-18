// A tour of the app on a simulator, for looking at.
//
// Widget tests render with a fixed-width stand-in font roughly 1.7× the width
// of the one the app ships, so a screenshot from one is unreadable and its
// layout is not the layout a golfer sees. This runs the real app with the real
// fonts, walks the screens that matter, and writes a PNG of each — which is
// how a design gets reviewed without asking somebody to hold a phone and take
// pictures, and how light mode got looked at for the first time.
//
// It asserts almost nothing on purpose. The suite already has two thousand
// tests making claims; this exists so those claims can be seen.
//
//   scripts/tour.sh <simulator-udid>
//
// Run it through that script rather than `flutter test` directly: it cycles
// the simulator first, without which the captured surface can be a frozen
// copy of whatever was on screen when the last run ended.
//
// Screenshots land in /tmp/vsp-tour.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_mobile/app.dart';
import 'package:vsp_mobile/features/basemap/data/basemap_config_service.dart';

import 'tour_support.dart';

/// Which palette to tour in — `dark` (the app's default) or `light`.
///
/// Light mode shipped as a setting nobody had seen. It was reasoned about from
/// the token file and measured for contrast by a test, and neither of those is
/// looking at it. Touring twice and writing to two directories is what makes
/// the two comparable screen by screen; toggling halfway through one run would
/// leave every screen photographed in one palette only, and the screens that
/// matter most here are the ones held in direct sun during a round.
const _theme = String.fromEnvironment('VSP_TOUR_THEME', defaultValue: 'dark');

/// Whether a few landmarks are on screen, so a wandering tour can say where
/// it got to.
///
/// Reports named landmarks rather than "the first fourteen Text widgets" —
/// that earlier version read the *background* screen under an open bottom
/// sheet and reported four steps of no movement while the picker was in fact
/// open the whole time. A diagnostic that lies is worse than none.
void describe(String step, List<String> landmarks) {
  final seen = landmarks
      .where((l) => find.textContaining(l).evaluate().isNotEmpty)
      .toList();
  debugPrint('TOUR[' + step + ']: ' + (seen.isEmpty ? '—' : seen.join(' | ')));
}

/// Starts a round and photographs the four screens a golfer lives in.
///
/// These are the screens this review keeps making claims about and the only
/// ones nobody has looked at with the real font — they need a round in
/// progress, which is more than tapping a tab.
Future<void> startARound(WidgetTester tester) async {
  for (final label in ['Chơi golf', 'Play']) {
    if (await tapIfPresent(tester, find.text(label))) break;
  }
  await shoot(tester, '11-play-tab');

  for (final label in ['Bắt đầu vòng đấu', 'Start a round', 'Start Round']) {
    if (await tapIfPresent(tester, find.textContaining(label))) break;
  }
  await shoot(tester, '12-round-setup');

  // The picker is a screen of its own behind "Select a course" — the tour
  // sat on the setup form tapping a club name that was never on it.
  for (final label in ['Chọn sân', 'Select a course']) {
    if (await tapIfPresent(tester, find.textContaining(label))) break;
  }
  await tester.pumpAndSettle(const Duration(seconds: 3));
  describe('picker', ['Select Course', 'Chọn sân']);
  await shoot(tester, '13-course-picker');

  // The sheet lists clubs alphabetically and Long Biên is below the fold, so
  // the tour searched for a name that was never on screen and tapped nothing.
  final search = find.byType(TextField);
  if (search.evaluate().isNotEmpty) {
    await tester.enterText(search.first, 'Long Biên');
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }
  // The full club name, not the substring that was just typed into the search
  // field: `find.textContaining('Long Biên')` matches the field's own contents
  // too, and `.first` in tree order is the field — so the tour spent three
  // steps tapping the box it had just typed into.
  await tapIfPresent(tester, find.text('Long Biên Golf Course'));
  await tester.pumpAndSettle(const Duration(seconds: 3));
  describe('after club', ['Đường', 'Long Biên', 'Select a course']);

  // A club with several đường asks which one before it comes back.
  await tapIfPresent(tester, find.textContaining('Đường A'));
  await tester.pumpAndSettle(const Duration(seconds: 3));
  describe('after duong', ['Long Biên', 'Đường']);
  await shoot(tester, '13b-course-chosen');

  // A layout that is not the one already chosen.
  //
  // The picker comes back with the first row selected, so the old step — tap
  // "Đường A" — pressed the radio that was already filled and photographed
  // identical pixels. It read as a broken control for a week and was a step
  // that asked nothing. The arrow is what marks a layout row apart from the
  // đường names elsewhere on the form.
  final layouts = find.textContaining('→');
  if (layouts.evaluate().length > 1) {
    await tapIfPresent(tester, layouts.at(1));
  } else {
    debugPrint('TOUR: no second layout to choose — one-đường club?');
  }
  await tester.pumpAndSettle(const Duration(seconds: 2));
  await shoot(tester, '13c-layout-chosen');

  for (final label in ['Bắt đầu vòng đấu', 'Start Round']) {
    if (await tapIfPresent(tester, find.widgetWithText(FilledButton, label))) {
      break;
    }
  }
  await tester.pumpAndSettle(const Duration(seconds: 4));
  describe('after start', ['Hố', 'Hole', 'Điểm', 'Score']);
  // Whatever tab a round opens on — the scorecard, as it happens. This shot
  // was named `14-hole-map` and was never the hole map: the Map tab was not
  // in the list below either, so the one screen a golfer spends the round
  // looking at had no picture at all while every claim here was made about it.
  await shoot(tester, '14-round-open');
  // Same reason as the Settings check: a round that never started still
  // photographs something, and the four screens below are the ones every claim
  // in this sweep is about.
  expectArrived('14-round-open', ['Hố', 'Hole']);

  for (final entry in <String, List<String>>{
    '15-map': ['Bản đồ', 'Map'],
    '16-score': ['Điểm', 'Score'],
    '17-target': ['Mục tiêu', 'Target'],
    '18-conditions': ['Điều kiện', 'Conditions'],
  }.entries) {
    for (final label in entry.value) {
      if (await tapIfPresent(tester, find.text(label))) {
        await shoot(tester, entry.key);
        break;
      }
    }
    // The Map tab opens on the measuring tool, by a deliberate choice recorded
    // in BasemapPreference: satellite first, because the photograph is the
    // course the golfer is standing in. So the vector hole map — the greens,
    // fairways and bunkers this whole geometry pipeline exists to draw — sits
    // one tap further in and had never been photographed at all. Every claim
    // made about it was made from the code.
    if (entry.key == '15-map') {
      for (final label in ['Bản đồ sân', 'Course map']) {
        if (await tapIfPresent(tester, find.text(label))) {
          await shoot(tester, '15b-course-map');
          break;
        }
      }
      await stepToTheNextHole(tester);
    }
  }

  await finishTheRound(tester);
}

/// Walks to the next hole, which is where the map is rebuilt from nothing.
///
/// Every tour before this one looked at hole 1 of Long Biên and no other hole,
/// so every claim about the map was a claim about one hole in one state. The
/// code is explicit that this is the interesting transition — "the hole map is
/// rebuilt from scratch on every hole: a hole change is a new camera, a new
/// basemap decision and a new measuring session" — and it is the path the
/// controller-lifecycle bugs live on. Nothing had ever taken it.
Future<void> stepToTheNextHole(WidgetTester tester) async {
  for (final tip in ['Hố sau', 'Next hole']) {
    if (await tapIfPresent(tester, find.byTooltip(tip))) break;
  }
  await tester.pumpAndSettle(const Duration(seconds: 3));
  describe('hole 2', ['Hố 2', 'Hole 2']);
  await shoot(tester, '15c-next-hole');
}

/// Ends the round, which is the half of the round nobody had ever run here.
///
/// Every tour before this one walked in, photographed four screens and walked
/// out, so every run left a round open on the server: nine IN_PROGRESS rows on
/// course 1351 in one morning, all of them ours. That is untidy, and it also
/// meant the one transition worth testing — in progress becoming completed —
/// had never been exercised end to end by anything.
Future<void> finishTheRound(WidgetTester tester) async {
  for (final label in ['Điểm', 'Score']) {
    if (await tapIfPresent(tester, find.text(label))) break;
  }

  // The action is an icon with a tooltip, not a labelled button.
  for (final tip in ['Kết thúc vòng đấu', 'Finish Round']) {
    if (await tapIfPresent(tester, find.byTooltip(tip))) break;
  }
  await tester.pumpAndSettle(const Duration(seconds: 1));
  describe('finish', ['Kết thúc vòng đấu?', 'Finish round?']);
  await shoot(tester, '19-finish-confirm');

  // The button in the dialog, not the dialog's own heading.
  for (final label in ['Kết thúc', 'Finish']) {
    if (await tapIfPresent(
      tester,
      find.widgetWithText(FilledButton, label),
    )) {
      break;
    }
  }
  await tester.pumpAndSettle(const Duration(seconds: 6));
  await shoot(tester, '20-finished');
  describe('after finish', ['Hoàn thành', 'Completed', 'Vòng đấu của bạn']);
}

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('walks the screens a golfer sees', (tester) async {
    // Set before the first frame, because ThemeModeCubit reads the preference
    // during startup and a golfer who has chosen light does not watch the app
    // open dark and then change its mind.
    //
    // The language is pinned here too, and not as a tidy-up. It used to come
    // from the welcome screen's "Tiếng Việt" button, which the tour only
    // reaches when signed out — so a run that inherited a live session
    // photographed the app in English and a run that did not photographed it
    // in Vietnamese. Two sets of screenshots in two languages cannot be
    // compared, and the difference is invisible until you read the words.
    tourOutputDir = '/tmp/vsp-tour/$_theme';
    SharedPreferences.setMockInitialValues({
      'app_theme_mode': _theme,
      'app_locale': 'vi',
    });
    debugPrint('TOUR: touring in $_theme, writing to $tourOutputDir');

    await tester.pumpWidget(
      const VspApp(syncOfflineQueue: false, loadBasemapConfig: false),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await shoot(tester, '01-first-screen');

    if (await tapIfPresent(tester, find.text('Tiếng Việt'))) {
      await shoot(tester, '02-welcome-vi');
    }

    // A session from a previous run is restored and there is then nothing to
    // sign in to. Coping with both is what stops the tour quietly ending after
    // one screenshot the second time it is run — which is exactly how it
    // behaved before this check existed.
    // Both languages. The check used to be the Vietnamese label alone, so a
    // run that restored an English session decided it was signed out, went
    // looking for a sign-in sheet that was not there, and printed "no way in
    // from the welcome screen" while sitting on the home screen.
    final signedIn = ['Sân golf', 'Courses']
        .any((label) => find.text(label).evaluate().isNotEmpty);
    debugPrint('TOUR: already signed in = $signedIn');
    if (!signedIn) {
      await signIn(
        tester,
        email: 'admin@vsp.local',
        password: 'Admin2026',
        shotPrefix: '0',
      );
    }
    // The imagery provider, fetched the way the app fetches it.
    //
    // The tour ran with `loadBasemapConfig: false` from the day it was
    // written, so `SatelliteImagery.current` was always "none" and every
    // photograph of the measuring tool showed the same screen: the one that
    // says this build has no satellite imagery. The Map tab opens on that
    // tool by default. So the single screen a golfer sees most of a round had
    // never been photographed in the state a golfer actually meets.
    //
    // Loaded here rather than at start-up because `/config/basemap` needs a
    // bearer token, and at start-up the request races session restore — the
    // race the app itself works around by asking twice.
    await SatelliteImagery.load(BasemapConfigService());
    await tester.pumpAndSettle(const Duration(seconds: 2));
    debugPrint('TOUR: imagery = ${SatelliteImagery.current.provider.name}');

    await shoot(tester, '05-home');

    for (final entry in <String, List<String>>{
      '06-course-list': ['Sân golf', 'Courses'],
      '07-rounds': ['Vòng đấu', 'Rounds'],
      '08-profile': ['Hồ sơ', 'Profile'],
      '09-more': ['Thêm', 'More'],
    }.entries) {
      for (final label in entry.value) {
        if (await tapIfPresent(tester, find.text(label))) {
          await shoot(tester, entry.key);
          break;
        }
      }
    }

    // Settings, which now owns the light/dark choice.
    for (final label in ['Cài đặt', 'Settings']) {
      if (await tapIfPresent(tester, find.textContaining(label))) {
        await shoot(tester, '10-settings');
        break;
      }
    }
    // The screen the palette is chosen on has to be the screen in the picture.
    expectArrived('10-settings', ['Giao diện', 'Appearance']);
    // Back to the tab shell, or the round below never starts.
    await popBack(tester);

    await startARound(tester);

    debugPrint('TOUR: finished');
    expectTheTourMoved();
  });
}
