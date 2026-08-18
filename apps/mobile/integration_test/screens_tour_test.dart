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

import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_mobile/app.dart';

/// Which palette to tour in — `dark` (the app's default) or `light`.
///
/// Light mode shipped as a setting nobody had seen. It was reasoned about from
/// the token file and measured for contrast by a test, and neither of those is
/// looking at it. Touring twice and writing to two directories is what makes
/// the two comparable screen by screen; toggling halfway through one run would
/// leave every screen photographed in one palette only, and the screens that
/// matter most here are the ones held in direct sun during a round.
const _theme = String.fromEnvironment('VSP_TOUR_THEME', defaultValue: 'dark');

final _outputDir = '/tmp/vsp-tour/$_theme';

late final IntegrationTestWidgetsFlutterBinding binding;

/// Digest of the last frame written, so the tour can tell a step that moved
/// from a step that did nothing.
///
/// Three times today a diagnostic said the tour had advanced when it had not:
/// blank PNGs from a stuck simulator surface, a describe() that read the
/// screen *under* an open sheet, and a landmark check where 'Hole' matched
/// 'Start Hole'. Pixels are the one thing that cannot be argued with.
String? _lastFrame;

/// Every frame written, in order, so the run can be judged as a whole.
///
/// A tour that photographs the same stuck surface seventeen times used to end
/// with "All tests passed!". That is the worst thing a diagnostic can do, and
/// no amount of care inside the app fixes it — so the run now fails when the
/// pictures stop moving. See [_expectTheTourMoved].
final List<String> _frames = [];

Future<void> shoot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 500));
  // Converted before every shot, not once at the start. Converting once was
  // tried and produced twelve blank PNGs.
  //
  // Blank frames also come from a simulator whose surface is stuck after an
  // earlier run — `simctl shutdown` then `boot` between runs is what clears
  // it. That was misdiagnosed once as "MapLibre platform views cannot be
  // captured", which may also be true and was not what was happening.
  await binding.convertFlutterSurfaceToImage();
  await tester.pumpAndSettle();
  final bytes = await binding.takeScreenshot(name);
  final file = File('$_outputDir/$name.png');
  await file.create(recursive: true);
  await file.writeAsBytes(bytes);

  final digest = md5.convert(bytes).toString();
  final moved = _lastFrame == null || digest != _lastFrame;
  _lastFrame = digest;
  _frames.add(digest);
  debugPrint(
    'shot $name${moved ? '' : '  ← IDENTICAL to the previous frame'}',
  );
}

/// Fails a run that photographed nothing.
///
/// The stuck-surface failure cannot be prevented from inside the test — it is
/// the simulator's compositor, and the remedy is to cycle it, which is what
/// `tool/tour.sh` does before every run. What can be prevented is the run
/// claiming success anyway. Half the frames distinct is a wide margin: a
/// healthy tour repeats one or two, a stuck one repeats every single frame.
void _expectTheTourMoved() {
  final distinct = _frames.toSet().length;
  debugPrint('TOUR: $distinct distinct frames of ${_frames.length}');
  expect(
    distinct,
    greaterThan(_frames.length ~/ 2),
    reason:
        'only $distinct of ${_frames.length} frames differ — the simulator '
        'surface is stuck. Run tool/tour.sh, which cycles it first.',
  );
}

/// Taps the first match if there is one, and reports when there is not — a
/// tour that silently stops halfway is worse than one that says where it got.
///
/// Taps the row rather than the label. A `Text` is not what handles the tap:
/// the gesture lives on an InkWell or a ListTile wrapping it, and tapping the
/// glyphs is a hit on a widget with no callback. With `warnIfMissed: false`
/// that failed in complete silence — the tour reported four steps and had not
/// moved from the first screen for any of them.
///
/// Scrolls the row into view first, and that is not a nicety. "Cài đặt" is the
/// last row on the More screen and sits below the fold. Being in the widget
/// tree, it was found; being off-screen, its centre lay under the bottom
/// navigation bar — so the tap landed on whichever tab happened to be at that
/// x, which is the middle one. The tour then photographed the Rounds screen
/// and filed it as `10-settings`, byte-identical to `07-rounds`. Nothing in
/// the run said otherwise, and the one screen light mode is chosen on had
/// never been photographed at all.
Future<bool> tapIfPresent(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) return false;

  Finder target = finder.first;
  for (final wrapper in [InkWell, ListTile, GestureDetector]) {
    final row = find.ancestor(of: finder.first, matching: find.byType(wrapper));
    if (row.evaluate().isNotEmpty) {
      target = row.first;
      break;
    }
  }

  // Not every tappable thing lives in a scrollable — a bottom-nav item does
  // not, and asking to scroll to it throws.
  try {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
  } catch (_) {}

  await tester.tap(target, warnIfMissed: false);
  await tester.pumpAndSettle(const Duration(milliseconds: 800));
  return true;
}

/// Comes back out of a pushed screen.
///
/// Settings is a route on top of the tab shell, not a tab, so the bottom
/// navigation is not on screen while it is open. The first version of the tour
/// never noticed: its Settings tap missed and left it inside the shell the
/// whole time. Once the tap landed, every step after it — the whole round —
/// photographed the Settings screen and the run still called that six distinct
/// frames.
///
/// Pops the innermost navigator that has anything to pop, rather than
/// `pageBack()`, which looks for a back button with a standard tooltip and
/// this app draws its own chevron.
Future<void> popBack(WidgetTester tester) async {
  for (final element in find.byType(Navigator).evaluate().toList().reversed) {
    final nav = (element as StatefulElement).state as NavigatorState;
    if (nav.canPop()) {
      nav.pop();
      await tester.pumpAndSettle(const Duration(milliseconds: 800));
      return;
    }
  }
  debugPrint('TOUR: nothing to pop');
}

/// Fails the run when a step did not arrive where it claimed to.
///
/// The tour's own frame-distinctness check cannot catch this: a tap that lands
/// on the wrong control still produces a different picture, so the run stays
/// green while a named screenshot shows a different screen. Only the step
/// itself knows what it was aiming at.
void _expectArrived(String step, List<String> landmarks) {
  expect(
    landmarks.any((l) => find.textContaining(l).evaluate().isNotEmpty),
    isTrue,
    reason:
        '$step never reached its screen — none of $landmarks on it. The '
        'screenshot filed under that name is of somewhere else.',
  );
}

Future<void> signIn(WidgetTester tester) async {
  if (!await tapIfPresent(tester, find.textContaining('email'))) {
    debugPrint('TOUR: no way in from the welcome screen');
    return;
  }
  await shoot(tester, '03-sign-in');

  final fields = find.byType(TextField);
  if (fields.evaluate().length < 2) {
    debugPrint('TOUR: sheet has ${fields.evaluate().length} fields — stopping');
    return;
  }

  await tester.enterText(fields.at(0), 'admin@vsp.local');
  await tester.pumpAndSettle();
  await tester.enterText(fields.at(1), 'Admin2026');
  await tester.pumpAndSettle();
  await shoot(tester, '04-credentials');

  // The button, not the sheet's heading — "Đăng nhập" is both, and
  // find.text().first is the heading.
  for (final label in ['Đăng nhập', 'Sign In', 'Sign in']) {
    if (await tapIfPresent(tester, find.widgetWithText(FilledButton, label))) {
      break;
    }
  }
  await tester.pumpAndSettle(const Duration(seconds: 6));
}

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
  _expectArrived('14-round-open', ['Hố', 'Hole']);

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
    }
  }
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
    SharedPreferences.setMockInitialValues({
      'app_theme_mode': _theme,
      'app_locale': 'vi',
    });
    debugPrint('TOUR: touring in $_theme, writing to $_outputDir');

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
      await signIn(tester);
    }
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
    _expectArrived('10-settings', ['Giao diện', 'Appearance']);
    // Back to the tab shell, or the round below never starts.
    await popBack(tester);

    await startARound(tester);

    debugPrint('TOUR: finished');
    _expectTheTourMoved();
  });
}
