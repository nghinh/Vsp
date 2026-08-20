// A full eighteen at Long Biên, photographed, for showing people.
//
// The screens tour beside this one exists to review a design: it walks quickly,
// looks at one hole, and runs in both palettes so they can be compared. This
// one exists to produce pictures somebody can put in front of a customer, and
// that is a different job with different requirements:
//
//   * A course with real data. Long Biên's Đường A and Đường B are the only
//     nines in the database whose packages carry all seven layers — tee,
//     fairway, green, bunker, water, rough and cart path — so they are the only
//     holes where the drawn map looks like golf rather than two dots. Paired,
//     they are the app's one genuine eighteen.
//
//   * A golfer standing on the course. The simulator's GPS is set to Long Biên
//     by the script before this runs. Without it every distance reads "no fix"
//     and the satellite view opens over Cupertino, which is the single fastest
//     way to make a screenshot worthless.
//
//   * The whole round, not a sample of it. A scorecard with one hole filled in
//     photographs as an empty scorecard; the summary at the end is the picture
//     that shows what the app is for, and it needs eighteen scores behind it.
//
//   * An account with a history. `golfer@vsp.local` has a bag with clubs in it
//     and eleven rounds on file, so the profile, the bag and the round list are
//     screens with something on them.
//
// Run it through scripts/sale_kit.sh, which cycles the simulator, sets the
// location, and copies the finished set into the repository. Running it
// directly leaves the pictures in /tmp and may photograph a frozen surface.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_mobile/app.dart';
import 'package:vsp_mobile/features/basemap/data/basemap_config_service.dart';
import 'package:vsp_mobile/features/hole_map/presentation/widgets/layer_toggle_panel.dart';
import 'package:vsp_mobile/presentation/widgets/score/quick_score_strip.dart';

import 'tour_support.dart';

/// The palette the kit is shot in. Dark is the app's default and the one the
/// screens were designed against; light is there because a customer may ask.
const _theme = String.fromEnvironment('VSP_KIT_THEME', defaultValue: 'dark');

const _email = String.fromEnvironment(
  'VSP_KIT_EMAIL',
  defaultValue: 'golfer@vsp.local',
);
const _password = String.fromEnvironment(
  'VSP_KIT_PASSWORD',
  defaultValue: 'Golfer2026',
);

/// The club, and the pairing that makes eighteen holes of it.
const _club = 'Long Biên Golf Course';

/// The name the round is played under, which is also the row the score strip
/// hides behind.
const _golfer = String.fromEnvironment(
  'VSP_KIT_GOLFER',
  defaultValue: 'VSP Golfer',
);

/// Holes worth a picture of their own.
///
/// Not all eighteen: a sale kit is a story, and eighteen near-identical map
/// screenshots is a contact sheet. The 1st is the opening tee shot, the 9th is
/// the turn, the 10th is where the round crosses onto the second đường — the
/// transition this app gets wrong more often than any other — and the 18th is
/// the last card before the summary.
const _featuredHoles = {1, 9, 10, 18};

/// What a golfer shot, hole by hole, as an offset from par.
///
/// A card of eighteen pars is not a golf score; it is a placeholder, and it
/// photographs like one — every row identical, the summary reading level par.
/// This is an ordinary single-figure round: a couple of birdies, mostly pars
/// and bogeys, one hole that got away. It gives the scorecard its colours and
/// the summary something to say.
const _card = <int>[
  0, 1, 0, -1, 1, 0, 2, 0, 1, // out
  0, -1, 1, 0, 1, 0, 1, 0, 1, // in
];

/// The tour's own record of what it could not find, printed at the end.
///
/// A screen that quietly failed to open is the failure mode that matters here:
/// the run stays green, the directory is one picture short, and nobody notices
/// until the deck is being assembled.
final List<String> _missed = [];

Future<void> _shootIfArrived(
  WidgetTester tester,
  String name,
  List<String> labels,
) async {
  if (await tapAny(tester, labels)) {
    await shoot(tester, name);
  } else {
    _missed.add('$name (none of $labels)');
    debugPrint('KIT: missed $name');
  }
}

/// Chooses the club, then the eighteen-hole pairing it offers.
Future<void> _setUpTheRound(WidgetTester tester) async {
  await _shootIfArrived(tester, '06-play', ['Chơi golf', 'Play']);

  await tapAny(tester, ['Bắt đầu vòng đấu', 'Start a round', 'Start Round']);
  await tester.pumpAndSettle(const Duration(seconds: 2));
  await shoot(tester, '07-round-setup');

  // The picker is a screen of its own behind "Chọn sân golf".
  await tapAny(tester, ['Chọn sân', 'Select a course']);
  await tester.pumpAndSettle(const Duration(seconds: 3));
  describe('picker', ['Chọn sân', 'Select Course']);
  await shoot(tester, '08-course-picker');

  // The sheet lists clubs alphabetically and Long Biên is below the fold, so
  // it is searched for rather than scrolled to.
  final search = find.byType(TextField);
  if (search.evaluate().isNotEmpty) {
    await tester.enterText(search.first, 'Long Biên');
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }
  // The full club name, not the substring just typed: `textContaining` matches
  // the search field's own contents, and `.first` in tree order is the field.
  await tapIfPresent(tester, find.text(_club));
  await tester.pumpAndSettle(const Duration(seconds: 4));

  // The club offers ten ways to be played and picks none of them for the
  // golfer — see RoundSetupReady.awaitingPlayOption. The pairings are listed
  // first, in playing order, so the first row carrying an arrow is A → B.
  describe('layouts', ['Chọn vòng chơi', 'Đường']);
  await shoot(tester, '09-choose-the-round');

  final pairings = find.textContaining('→');
  if (pairings.evaluate().isEmpty) {
    _missed.add('09 — no pairing offered, so this is not an eighteen');
  } else {
    await tapIfPresent(tester, pairings.first);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }
  // The form suggests the 10th after midday, which is thoughtful on a course
  // and wrong for a kit: the pictures tell the story of a round, and a round
  // starts on the 1st.
  await _startOnTheFirst(tester);
  await shoot(tester, '10-ready-to-start');

  // The button, not the screen's own title — both say "Bắt đầu vòng đấu",
  // and a bare text finder picks whichever the traversal meets first. It
  // met the button while the button lived in the body; the day the button
  // moved to bottomNavigationBar, the finder started tapping the AppBar
  // title and the kit photographed a round that never began.
  for (final label in ['Bắt đầu vòng đấu', 'Start Round']) {
    if (await tapIfPresent(
      tester,
      find.widgetWithText(FilledButton, label),
    )) {
      break;
    }
  }
  await tester.pumpAndSettle(const Duration(seconds: 6));
  expectArrived('the round', ['Hố', 'Hole']);
}

/// Moves the start hole to the 1st, and photographs the picker on the way.
///
/// Retried, because it is flaky in a way that matters: it worked on some runs
/// and not others, and a run where it failed produced a kit whose story opens
/// on the 10th tee. Checked by exact text — `find.text('Hố 1')` does not match
/// "Hố 10", which `textContaining` does, and that is precisely the confusion
/// that let a failed attempt report success.
Future<void> _startOnTheFirst(WidgetTester tester) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    // The chip's own words, not the heading above it and not its semantics
    // node. "Hố xuất phát" is the section heading — a bare Text with no
    // handler — so tapping it is a green step that does nothing. And the
    // semantics label sits *above* the InkWell here, so `tapIfPresent`, which
    // scrolls to whatever it can find an InkWell ancestor for, found none and
    // pressed a node that handles nothing. The Text inside the chip has the
    // InkWell as an ancestor, which is the shape every other tap here relies
    // on.
    final chip = find.textContaining('Gợi ý: Hố');
    if (!await tapIfPresent(tester, chip)) {
      // Already off the suggestion, which means a previous attempt took.
      break;
    }
    await tester.pumpAndSettle(const Duration(seconds: 2));

    if (find.textContaining('Chọn hố xuất phát').evaluate().isEmpty) {
      continue;
    }
    if (attempt == 0) await shoot(tester, '09b-start-hole');

    // Inside the grid: '1' on its own matches a form that is mostly numbers.
    final one = find.descendant(
      of: find.byType(GridView),
      matching: find.text('1'),
    );
    await tapIfPresent(tester, one);
    await tapIfPresent(tester, find.widgetWithText(FilledButton, 'Xác nhận'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    if (find.text('Hố 1').evaluate().isNotEmpty) return;
  }

  if (find.text('Hố 1').evaluate().isEmpty) {
    _missed.add('the round would not start on the 1st');
  }
}

/// The four screens a golfer lives in, on the opening hole.
Future<void> _theScreensOfAHole(WidgetTester tester) async {
  await shoot(tester, '11-scorecard-hole-1');

  await _shootIfArrived(tester, '12-satellite', ['Bản đồ', 'Map']);

  // The Map tab opens on the photograph by a deliberate choice — the imagery
  // is the course the golfer is standing in — so the drawn map, which is what
  // the whole geometry pipeline exists to produce, is one tap further in.
  await _toCourseMap(tester, '13-course-map');

  await _shootIfArrived(tester, '14-target', ['Mục tiêu', 'Target']);
  await _shootIfArrived(tester, '15-conditions', ['Điều kiện', 'Conditions']);
}

/// Switches the map to the drawn hole and photographs it.
///
/// The switch carries icons rather than words — it shares a row with the
/// distances at the foot of the map, and at ordinary text size the words came
/// back as "B…" and "Th…". So it is reached the way a screen reader reaches
/// it, which is also the only way left to name which half is being pressed.
Future<void> _toCourseMap(WidgetTester tester, String name) async {
  final toggle = find.bySemanticsLabel('Chuyển sang bản đồ sân');
  if (toggle.evaluate().isEmpty) {
    _missed.add('$name (no course-map switch)');
    return;
  }
  await tester.tap(toggle.first, warnIfMissed: false);
  await tester.pumpAndSettle(const Duration(seconds: 4));
  await shoot(tester, name);
}

/// Puts the card on the [hole]th hole of the round, and says whether it stuck.
///
/// ─── Why a walk needs checking ────────────────────────────────────────────
///
/// The round follows the golfer: automatic hole detection watches the GPS and
/// moves the card to the hole they are standing on. On a simulator the golfer
/// never moves — they are parked on the first tee for the whole tour — so
/// every advance was liable to be undone a second later, and the first kit
/// came back with a card of ten holes and a summary that said so.
///
/// Checked by position rather than by the hole's number, because a paired
/// round numbers its holes 1-9 and then 1-9 again: "Hố 1" is two different
/// holes and "Hố 1 trên 18" is only ever the first. That is also the string
/// that showed the first kit had gone round twice.
Future<bool> _standOn(WidgetTester tester, int hole) async {
  Finder here() => find.textContaining('Hố $hole trên 18');
  if (here().evaluate().isNotEmpty) return true;

  // Three pushes. More than that is not a race with detection, it is a fight
  // with it, and a kit assembled by fighting the app is not evidence about
  // the app.
  for (var attempt = 0; attempt < 3; attempt++) {
    if (!await tapIfPresent(tester, find.bySemanticsLabel('Hố sau'))) break;
    await tester.pumpAndSettle(const Duration(seconds: 2));
    if (here().evaluate().isNotEmpty) return true;
  }
  return here().evaluate().isNotEmpty;
}

/// Plays the eighteen, entering a real score on every hole.
///
/// The scorecard is where the round is walked from: its own navigation bar has
/// the next-hole button, and staying on one tab means the card fills in as the
/// round goes, which is the thing being photographed.
Future<void> _playEighteen(WidgetTester tester) async {
  await tapAny(tester, ['Điểm', 'Score']);
  await tester.pumpAndSettle(const Duration(seconds: 2));
  await shoot(tester, '16-score-entry');

  for (var hole = 1; hole <= 18; hole++) {
    // Walk there first, so hole detection is agreeing rather than arguing.
    // Two seconds is a stroll between greens and enough for a location change
    // to reach the app.
    walkTo(hole);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    if (!await _standOn(tester, hole)) {
      _missed.add('the round would not stay on hole $hole');
      break;
    }
    final offset = _card[hole - 1];
    // The quick strip is captioned by name and labelled by number: "Par 4",
    // "Bogey 5". The caption is what identifies the button whatever the hole's
    // par is, which is the point of choosing an offset rather than a score.
    final caption = switch (offset) {
      -1 => 'Birdie',
      0 => 'Par',
      1 => 'Bogey',
      _ => '+$offset',
    };
    // The strip lives under the player's own row and only when that row is
    // open — "Chạm để nhập" is the whole of a closed row. A four-ball would
    // otherwise put the first player's buttons under the fourth player's name,
    // which is why they are placed this way; it also means the tour has to
    // open the row before it can press anything.
    final label = RegExp('^${RegExp.escape(caption)} ');
    // Opened only when it is shut. The row is a toggle and it stays open after
    // a score, so tapping it unconditionally closed it on every second hole —
    // which is why the run reported "no Bogey button" for holes 2, 4, 6, 8 and
    // so on, in exactly that pattern. The strip's own presence is the signal;
    // the semantics label is not, because the hole header says "Par 4" too.
    if (find.byType(QuickScoreStrip).evaluate().isEmpty) {
      await tapIfPresent(tester, find.text(_golfer));
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
    }

    // Scoped to the strip. The hole header prints "Par 4" as well, so an
    // unscoped semantics match finds the heading first — and tapping a heading
    // records nothing while reporting nothing. That is where the eight missing
    // holes went: eighteen taps, ten of them on a title.
    final button = find.descendant(
      of: find.byType(QuickScoreStrip),
      matching: find.bySemanticsLabel(label),
    );
    if (button.evaluate().isEmpty) {
      _missed.add('hole $hole — no "$caption" button');
    } else {
      await tester.tap(button.first, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
    }

    if (_featuredHoles.contains(hole)) {
      await shoot(tester, '17-hole-${hole.toString().padLeft(2, '0')}-card');
      // The 10th is where the round crosses from Đường A onto Đường B. The map
      // is rebuilt from nothing on every hole — a new camera, a new basemap
      // decision, a new measuring session — and this is the crossing where
      // that has gone wrong before.
      if (hole == 10) {
        await _shootIfArrived(tester, '18-hole-10-map', ['Bản đồ', 'Map']);
        await _toCourseMap(tester, '19-hole-10-course-map');
        await tapAny(tester, ['Điểm', 'Score']);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }
    }

    if (hole == 18) break;
    if (!await tapIfPresent(tester, find.bySemanticsLabel('Hố sau'))) {
      _missed.add('hole $hole — could not walk on');
      break;
    }
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  describe('the 18th', ['Hố 18', 'Hole 18']);
}


/// The three things this app does that a scorecard app does not.
///
/// Each lives behind a control the tours had never pressed, so none of them
/// had ever been photographed: the club plan behind a button on the
/// photograph, the strategy book and the games sheet behind two icons in the
/// scorecard's app bar, and the layer control behind the count in the corner
/// of the drawn map.
Future<void> _theThreeFeatures(WidgetTester tester) async {
  // 1 — What to hit. Reads the golfer's own carry distances out of their bag.
  //
  // The button lives on the photograph, and the Map tab opens on whichever
  // basemap the golfer last used — so the tab has to be put into satellite
  // before the button exists to be pressed.
  await tapAny(tester, ['Bản đồ']);
  await tester.pumpAndSettle(const Duration(seconds: 3));

  // 2 — What is on the ground, and what to hit across it. Both live on the
  // drawn hole map; every earlier kit hunted the plan button on the
  // measuring tool and shipped without it.
  await tester.pumpAndSettle(const Duration(seconds: 2));
  await _toCourseMap(tester, '28-ban-do-lop');

  // 1 — the club plan. It sits over the PHOTOGRAPH, not the drawn map —
  // and the old switch label ('công cụ đo khoảng cách') only exists when
  // there is no imagery, so every earlier kit tapped a control that was
  // not there, stayed on the drawn map, and shipped without this scene.
  if (await tapIfPresent(
    tester,
    find.bySemanticsLabel('Chuyển sang ảnh vệ tinh'),
  )) {
    await tester.pumpAndSettle(const Duration(seconds: 4));
  }
  if (await tapIfPresent(tester, find.text('Gợi ý chia gậy'))) {
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await shoot(tester, '27-chia-gay');
  } else {
    _missed.add('27-chia-gay (không thấy nút gợi ý chia gậy)');
  }
  // Back to the drawn map for the layer panel below.
  await tapIfPresent(
    tester,
    find.bySemanticsLabel('Chuyển sang bản đồ sân'),
  );
  await tester.pumpAndSettle(const Duration(seconds: 3));

  if (await tapIfPresent(tester, find.byType(LayerTogglePanel))) {
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await shoot(tester, '29-lop-du-lieu');
  } else {
    _missed.add('24-lop-du-lieu (không mở được bảng lớp)');
  }

  // 3 — The strategy book, and the games sheet where handicap, skins and team
  // formats are settled.
  await tapAny(tester, ['Điểm']);
  await tester.pumpAndSettle(const Duration(seconds: 2));
  if (await tapIfPresent(tester, find.byKey(const Key('scorecard_strategy')))) {
    await tester.pumpAndSettle(const Duration(seconds: 4));
    await shoot(tester, '30-so-chien-thuat');
    await popBack(tester);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  } else {
    _missed.add('25-so-chien-thuat (không thấy sổ chiến thuật)');
  }

  if (await tapIfPresent(tester, find.byKey(const Key('scorecard_games')))) {
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await shoot(tester, '31-chia-do');
    await popBack(tester);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  } else {
    _missed.add('26-chia-do (không mở được chia độ)');
  }

  // 4 — What this hole did to you last time. The history sheet reads the
  // golfer's previous rounds on the very hole they are standing on.
  if (await tapIfPresent(
    tester,
    find.byKey(const Key('scorecard_hole_history')),
  )) {
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await shoot(tester, '32-lich-su-ho');
    await popBack(tester);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  } else {
    _missed.add('32-lich-su-ho (không thấy nút lịch sử hố)');
  }

  // 5 — The paper card, photographed instead of typed. The sheet under the
  // camera button is the doorway to OCR score entry.
  if (await tapIfPresent(tester, find.byTooltip('Chụp ảnh card'))) {
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await shoot(tester, '33-quet-the-diem');
    await popBack(tester);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  } else {
    _missed.add('33-quet-the-diem (không thấy nút chụp ảnh card)');
  }

  await tapAny(tester, ['Điểm']);
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

Future<void> _finish(WidgetTester tester) async {
  for (final tip in ['Kết thúc vòng đấu', 'Finish Round']) {
    if (await tapIfPresent(tester, find.byTooltip(tip))) break;
  }
  await tester.pumpAndSettle(const Duration(seconds: 1));
  describe('finish', ['Kết thúc vòng đấu?', 'Finish round?']);
  await shoot(tester, '20-finish-confirm');

  // The button in the dialog, not the dialog's own heading.
  for (final label in ['Kết thúc', 'Finish']) {
    if (await tapIfPresent(
      tester,
      find.widgetWithText(FilledButton, label),
    )) {
      break;
    }
  }
  await tester.pumpAndSettle(const Duration(seconds: 8));
  await shoot(tester, '21-round-summary');
  describe('after finish', ['Hoàn thành', 'Completed', 'Vòng đấu của bạn']);
}

/// The analytics that sell the app to a golfer who already keeps score:
/// the menu naming all four engines, and Smart Target's worked example —
/// the one screen that shows the AI weighing risk against a real bag.
Future<void> _theAnalyticsHighlights(WidgetTester tester) async {
  // Settings is a pushed route, so the tab bar may not be on screen when
  // this starts. Pop until Thêm is reachable rather than assuming.
  for (var i = 0; i < 3 && !await tapAny(tester, ['Thêm']); i++) {
    await popBack(tester);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }
  await tester.pumpAndSettle(const Duration(seconds: 2));
  if (await tapIfPresent(tester, find.textContaining('Phân tích'))) {
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await shoot(tester, '34-phan-tich');
    if (await tapIfPresent(tester, find.textContaining('Smart Target'))) {
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await shoot(tester, '35-smart-target');
      await popBack(tester);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    } else {
      _missed.add('35-smart-target (không thấy mục Smart Target)');
    }
    await popBack(tester);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  } else {
    _missed.add('34-phan-tich (không thấy menu phân tích)');
  }
}

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plays eighteen at Long Biên and photographs it', (tester) async {
    tourOutputDir = '/tmp/vsp-sale-kit/$_theme';

    // Set before the first frame: ThemeModeCubit reads the preference during
    // startup, and the language is pinned because a run that inherits a live
    // session would otherwise photograph the app in whatever language that
    // session was left in.
    SharedPreferences.setMockInitialValues({
      'app_theme_mode': _theme,
      'app_locale': 'vi',
    });
    debugPrint('KIT: $_theme, writing to $tourOutputDir');

    await tester.pumpWidget(
      const VspApp(syncOfflineQueue: false, loadBasemapConfig: false),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await shoot(tester, '01-welcome');

    await tapIfPresent(tester, find.text('Tiếng Việt'));

    final signedIn = ['Sân golf', 'Courses']
        .any((label) => find.text(label).evaluate().isNotEmpty);
    debugPrint('KIT: already signed in = $signedIn');
    if (!signedIn) {
      await signIn(
        tester,
        email: _email,
        password: _password,
        shotPrefix: '02',
      );
    }

    // The imagery provider, fetched the way the app fetches it. Loaded here
    // rather than at start-up because /config/basemap needs a bearer token,
    // and at start-up the request races session restore.
    await SatelliteImagery.load(BasemapConfigService());
    await tester.pumpAndSettle(const Duration(seconds: 2));
    debugPrint('KIT: imagery = ${SatelliteImagery.current.provider.name}');
    expect(
      SatelliteImagery.current.isAvailable,
      isTrue,
      reason:
          'without imagery every map screenshot is the "no satellite imagery" '
          'placeholder, which is half the kit',
    );

    await shoot(tester, '03-home');
    await _shootIfArrived(tester, '04-courses', ['Sân golf', 'Courses']);

    // Into a course, which is where the club's own page lives. The list is
    // alphabetical and Long Biên is a long way down it, so it is searched for
    // — which is what a golfer does too.
    final courseSearch = find.byType(TextField);
    if (courseSearch.evaluate().isNotEmpty) {
      await tester.enterText(courseSearch.first, 'Long Biên');
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }
    if (await tapIfPresent(tester, find.textContaining(_club))) {
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await shoot(tester, '05-course-detail');
      await popBack(tester);
    } else {
      _missed.add('05-course-detail');
    }

    await _setUpTheRound(tester);
    await _theScreensOfAHole(tester);
    await _theThreeFeatures(tester);
    await _playEighteen(tester);
    await _finish(tester);

    // The summary is a route on top of the tab shell, so the bottom navigation
    // is not on screen while it is open. Every tab below it was "missed" for
    // exactly this reason, and the run stayed green.
    if (!await tapAny(tester, ['Xong', 'Done'])) await popBack(tester);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await _shootIfArrived(tester, '22-round-history', ['Vòng đấu', 'Rounds']);
    await _shootIfArrived(tester, '23-profile', ['Hồ sơ', 'Profile']);
    await _shootIfArrived(tester, '24-more', ['Thêm', 'More']);
    await _shootIfArrived(tester, '25-bag', ['Túi gậy', 'My Bag']);
    await popBack(tester);
    await _shootIfArrived(tester, '26-settings', ['Cài đặt', 'Settings']);

    await _theAnalyticsHighlights(tester);

    debugPrint('KIT: finished');
    if (_missed.isNotEmpty) {
      debugPrint('KIT: MISSED — ${_missed.join('; ')}');
    }
    expectTheTourMoved();
    // Named separately from the frame check: a kit with holes in it is not a
    // kit, and "the pictures moved" does not notice a screen that never
    // opened.
    expect(
      _missed,
      isEmpty,
      reason: 'these screens were never photographed: ${_missed.join('; ')}',
    );
  });
}
