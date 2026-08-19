// Shared machinery for the tours that photograph this app on a simulator.
//
// Two tours use it: `screens_tour_test.dart`, which walks the screens once in
// each palette so a design can be reviewed, and `sale_kit_test.dart`, which
// plays a full eighteen at a course with real geometry to produce pictures fit
// to show somebody.
//
// Everything here is a scar. The comments say which one.

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

late IntegrationTestWidgetsFlutterBinding binding;

/// Where the PNGs land. Set by each tour before its first shot.
///
/// Always somewhere under /tmp. The simulator writes these itself, and while
/// it does share the Mac's filesystem, a run that fails half way through
/// should not leave a half-populated directory inside the repository. The
/// script that drives the tour copies the finished set in.
String tourOutputDir = '/tmp/vsp-tour';

/// Digest of the last frame written, so a tour can tell a step that moved from
/// a step that did nothing.
///
/// Three separate diagnostics once said a tour had advanced when it had not:
/// blank PNGs from a stuck simulator surface, a describe() that read the screen
/// *under* an open sheet, and a landmark check where 'Hole' matched 'Start
/// Hole'. Pixels are the one thing that cannot be argued with.
String? _lastFrame;

/// Every frame written, in order, so a run can be judged as a whole.
///
/// A tour that photographed the same stuck surface seventeen times used to end
/// with "All tests passed!". That is the worst thing a diagnostic can do, and
/// no amount of care inside the app fixes it — so the run now fails when the
/// pictures stop moving. See [expectTheTourMoved].
final List<String> _frames = [];

/// Names of frames that came out identical to the one before, for the summary.
final List<String> repeatedFrames = [];

Future<void> shoot(WidgetTester tester, String name) async {
  await settle(tester, const Duration(seconds: 3));
  // Converted before every shot, not once at the start. Converting once was
  // tried and produced twelve blank PNGs.
  //
  // Blank frames also come from a simulator whose surface is stuck after an
  // earlier run — `simctl shutdown` then `boot` between runs is what clears
  // it. That was misdiagnosed once as "MapLibre platform views cannot be
  // captured", which may also be true and was not what was happening.
  await binding.convertFlutterSurfaceToImage();
  await settle(tester, const Duration(seconds: 3));
  final bytes = await binding.takeScreenshot(name);
  final file = File('$tourOutputDir/$name.png');
  await file.create(recursive: true);
  await file.writeAsBytes(bytes);

  final digest = md5.convert(bytes).toString();
  final moved = _lastFrame == null || digest != _lastFrame;
  if (!moved) repeatedFrames.add(name);
  _lastFrame = digest;
  _frames.add(digest);
  debugPrint(
    'shot $name${moved ? '' : '  ← IDENTICAL to the previous frame'}',
  );
}

/// Fails a run that photographed nothing.
///
/// The stuck-surface failure cannot be prevented from inside the test — it is
/// the simulator's compositor, and the remedy is to cycle it, which the
/// scripts do before every run. What can be prevented is the run claiming
/// success anyway. Half the frames distinct is a wide margin: a healthy tour
/// repeats one or two, a stuck one repeats every single frame.
void expectTheTourMoved() {
  final distinct = _frames.toSet().length;
  debugPrint('TOUR: $distinct distinct frames of ${_frames.length}');
  if (repeatedFrames.isNotEmpty) {
    debugPrint('TOUR: repeats — ${repeatedFrames.join(', ')}');
  }
  expect(
    distinct,
    greaterThan(_frames.length ~/ 2),
    reason:
        'only $distinct of ${_frames.length} frames differ — the simulator '
        'surface is stuck. Run the tour through its script, which cycles it '
        'first.',
  );
}


/// Waits for the screen to stop moving, and says whether it ever did.
///
/// ─── Why not `pumpAndSettle` ──────────────────────────────────────────────
///
/// `pumpAndSettle` throws when the frames never stop coming, which is exactly
/// what a screen stuck on a spinner does — so a single hung screen ended the
/// whole sweep at its second step, and the twenty-odd screens after it went
/// unexamined. A hung screen is a finding, not a reason to stop looking.
///
/// Returns false when the timeout was reached. The caller decides whether that
/// is worth writing down; either way the run goes on.
Future<bool> settle(
  WidgetTester tester, [
  Duration timeout = const Duration(seconds: 6),
]) async {
  try {
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, timeout);
    return true;
  } catch (_) {
    // Still animating. Give it one more frame so the tree is consistent, and
    // carry on with whatever is on screen now.
    await tester.pump(const Duration(milliseconds: 400));
    return false;
  }
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
    await settle(tester, const Duration(seconds: 2));
  } catch (_) {}

  await tester.tap(target, warnIfMissed: false);
  await settle(tester, const Duration(seconds: 6));
  return true;
}

/// Taps the first of several labels that is present, and says so.
Future<bool> tapAny(WidgetTester tester, List<String> labels) async {
  for (final label in labels) {
    if (await tapIfPresent(tester, find.text(label))) return true;
  }
  for (final label in labels) {
    if (await tapIfPresent(tester, find.textContaining(label))) return true;
  }
  return false;
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
      await settle(tester, const Duration(seconds: 4));
      return;
    }
  }
  debugPrint('TOUR: nothing to pop');
}

/// Fails the run when a step did not arrive where it claimed to.
///
/// The frame-distinctness check cannot catch this: a tap that lands on the
/// wrong control still produces a different picture, so the run stays green
/// while a named screenshot shows a different screen. Only the step itself
/// knows what it was aiming at.
void expectArrived(String step, List<String> landmarks) {
  expect(
    landmarks.any((l) => find.textContaining(l).evaluate().isNotEmpty),
    isTrue,
    reason:
        '$step never reached its screen — none of $landmarks on it. The '
        'screenshot filed under that name is of somewhere else.',
  );
}

/// Whether a few landmarks are on screen, so a wandering tour can say where it
/// got to.
///
/// Reports named landmarks rather than "the first fourteen Text widgets" —
/// that earlier version read the *background* screen under an open bottom
/// sheet and reported four steps of no movement while the picker was in fact
/// open the whole time. A diagnostic that lies is worse than none.
void describe(String step, List<String> landmarks) {
  final seen = landmarks
      .where((l) => find.textContaining(l).evaluate().isNotEmpty)
      .toList();
  debugPrint('TOUR[$step]: ${seen.isEmpty ? '—' : seen.join(' | ')}');
}

/// Tells whatever is driving the simulator which hole the golfer is on.
///
/// ─── Why a tour has to say where it is ───────────────────────────────────
///
/// The round follows the golfer: hole detection watches the GPS and moves the
/// card to the hole they are standing on. That is right on a course and fatal
/// on a simulator, where the golfer never moves — parked on the first tee, the
/// app dragged the card back to the 1st a second after every advance, and the
/// first sale kit came back with a card of ten holes and a summary that said
/// so.
///
/// Fighting it would have been the wrong fix twice over: it would have made
/// the kit a picture of the tour beating the app, and it would have hidden the
/// feature. So the tour walks instead. It writes the hole it is playing here,
/// the script watches the file and moves the simulator's location to that
/// hole, and detection agrees with the tour rather than arguing with it.
///
/// Best effort: a tour run without the watcher simply has a golfer who does
/// not move, which is where this started.
void walkTo(int hole) {
  try {
    File('$tourOutputDir/../hole.txt').writeAsStringSync('$hole');
  } catch (_) {
    // No watcher, or nowhere to write. The tour goes on.
  }
}

/// Signs in with an email and password, from the welcome screen.
Future<void> signIn(
  WidgetTester tester, {
  required String email,
  required String password,
  String? shotPrefix,
}) async {
  if (!await tapIfPresent(tester, find.textContaining('email'))) {
    debugPrint('TOUR: no way in from the welcome screen');
    return;
  }
  if (shotPrefix != null) await shoot(tester, '$shotPrefix-sign-in');

  final fields = find.byType(TextField);
  if (fields.evaluate().length < 2) {
    debugPrint('TOUR: sheet has ${fields.evaluate().length} fields — stopping');
    return;
  }

  await tester.enterText(fields.at(0), email);
  await settle(tester, const Duration(seconds: 2));
  await tester.enterText(fields.at(1), password);
  await settle(tester, const Duration(seconds: 2));
  if (shotPrefix != null) await shoot(tester, '$shotPrefix-credentials');

  // The button, not the sheet's heading — "Đăng nhập" is both, and
  // find.text().first is the heading.
  for (final label in ['Đăng nhập', 'Sign In', 'Sign in']) {
    if (await tapIfPresent(tester, find.widgetWithText(FilledButton, label))) {
      break;
    }
  }
  await settle(tester, const Duration(seconds: 12));
}
