// Walks every screen this app has and writes down what is broken.
//
// Distinct from the two tours beside it. The screens tour photographs a design
// and the sale kit photographs a product; both are cameras. This one is an
// inspector: it visits each screen, checks it actually arrived, reads it for
// the app's own failure vocabulary, and collects every exception the framework
// raises along the way — then reports all of it at the end.
//
// ─── Why it records instead of failing ────────────────────────────────────
//
// A test that stops at the first problem answers "is there a bug", which is a
// question nobody needed to ask. What a sweep is for is "how many, where, and
// which of them matter" — and that answer only exists if the run continues
// past the first one. So every check appends to [_findings] and the run fails
// once, at the end, with the whole list.
//
// ─── What counts as broken ────────────────────────────────────────────────
//
// Three things, and the difference between them matters:
//
//   * A screen that never arrived. The tap missed, or the route threw. The
//     screenshot filed under that name is of somewhere else.
//   * A screen showing the app's own failure vocabulary — "Không tải được",
//     "thất bại", "Đã có lỗi xảy ra". These are the app admitting it could not
//     do its job, which is exactly what a sweep is looking for.
//   * A framework exception raised while that screen was up. These do not show
//     on the screen at all in a release build, which is why nobody finds them
//     by looking.
//
// An empty state is NOT broken. "Chưa có túi gậy nào" on an account with no
// bag is the app being correct, and a sweep that flagged it would train its
// reader to ignore it.
//
//   scripts/uat_sweep.sh <simulator-udid>

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_mobile/app.dart';
import 'package:vsp_mobile/features/basemap/data/basemap_config_service.dart';
import 'package:vsp_mobile/presentation/widgets/score/quick_score_strip.dart';

import 'tour_support.dart';

const _email = String.fromEnvironment(
  'VSP_UAT_EMAIL',
  defaultValue: 'golfer@vsp.local',
);
const _password = String.fromEnvironment(
  'VSP_UAT_PASSWORD',
  defaultValue: 'Golfer2026',
);

/// Run against a server that is not there.
///
/// The app is offline-first by design — packages on the device, scores written
/// locally and synced later — so "no server" is a state it claims to handle,
/// not an accident. This mode is how that claim gets checked: every screen is
/// opened with the API unreachable, and what matters changes. A screen saying
/// "Không tải được" is then correct and expected; a screen that hangs on a
/// spinner, throws, or shows a raw exception is not.
const _offline = bool.fromEnvironment('VSP_UAT_OFFLINE');

/// The app admitting it could not do its job.
///
/// Deliberately not every string with "chưa" in it: this app says "Chưa có túi
/// gậy nào" to a golfer who has no bag, and that is the app working. What is
/// listed here is failure — a load that did not load, a connection that did
/// not connect.
const _failureMarkers = <String>[
  'Không tải được',
  'thất bại',
  'Đã có lỗi xảy ra',
  'Lỗi khi tải',
  'Không thể kết nối',
  'Không kết nối được',
  'Không bỏ dở được',
];

final List<_Finding> _findings = [];

/// Framework exceptions seen since the last check, with the screen they were
/// raised on attached when the check runs.
final List<String> _pendingErrors = [];

class _Finding {
  _Finding(this.screen, this.kind, this.detail);

  final String screen;
  final String kind;
  final String detail;

  @override
  String toString() => '[$kind] $screen — $detail';
}

/// Everything the framework complains about, kept rather than printed.
///
/// A release build shows none of these to a golfer; a debug build paints a red
/// box and carries on. Either way the run stays green unless somebody is
/// collecting them, which is what this does.
void _catchFrameworkErrors() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final line = details.exceptionAsString().split('\n').first;
    // The overflow warnings are the ones worth having: they are how a button
    // ends up clipped and untappable, which this sweep found once already.
    _pendingErrors.add(line);
    previous?.call(details);
  };
}

/// Visits a screen and writes down what is wrong with it.
///
/// [landmarks] is what proves the screen arrived — any one of them is enough,
/// because several screens are titled differently in the two languages and
/// some carry their title only in a nav bar.
Future<void> check(
  WidgetTester tester,
  String screen, {
  required List<String> landmarks,
  bool shoot_ = true,
}) async {
  // Fifteen seconds, deliberately longer than anything the app waits for on
  // its own. The nearby-courses tab asks the device for a fix with a ten
  // second limit and shows a spinner until it answers; a sweep with a shorter
  // budget than that files the app's patience as a hang. It did once.
  // Twenty-five seconds. The longest thing the app waits for on its own is a
  // GPS fix, capped at ten, and every failure path there emits an error state
  // rather than leaving a spinner up. Anything still animating at 25s is
  // therefore the app breaking its own promise, not the app being patient.
  final settled = await settle(tester, const Duration(seconds: 25));
  if (!settled) {
    _findings.add(
      _Finding(screen, 'QUAY MÃI', 'không dừng hoạt ảnh sau 25 giây'),
    );
  }

  bool here() => landmarks.any(
    (l) => find.textContaining(l).evaluate().isNotEmpty,
  );

  // Looked for twice, with a wait between. A screen that arrives while this
  // check is running is a screen that arrived — the round summary posts to the
  // server before it paints, and the first pass filed it as never opening
  // while the screenshot taken two seconds later showed it on screen. A report
  // that cries wolf about a working screen is worse than no report.
  var arrived = here();
  if (!arrived) {
    await settle(tester, const Duration(seconds: 10));
    arrived = here();
  }
  if (!arrived) {
    _findings.add(_Finding(screen, 'KHÔNG TỚI', 'không thấy $landmarks'));
  }

  // Offline, the app's failure vocabulary is the right answer rather than a
  // finding. What still counts is a hang, an exception, or a screen that never
  // arrives — and those are checked above and below regardless.
  for (final marker in _offline ? const <String>[] : _failureMarkers) {
    final hit = find.textContaining(marker);
    if (hit.evaluate().isNotEmpty) {
      final widget = hit.evaluate().first.widget;
      final text = widget is Text ? (widget.data ?? marker) : marker;
      _findings.add(_Finding(screen, 'BÁO LỖI', text));
      break;
    }
  }

  for (final error in _pendingErrors) {
    _findings.add(_Finding(screen, 'NGOẠI LỆ', error));
  }
  _pendingErrors.clear();

  if (shoot_) {
    try {
      await shoot(tester, screen);
    } catch (e) {
      _findings.add(_Finding(screen, 'KHÔNG CHỤP ĐƯỢC', '$e'));
    }
  }
  debugPrint('UAT: $screen ${arrived ? 'ok' : 'MISSED'}');
}

/// Taps something and says nothing if it is not there — the caller's [check]
/// is what notices.
Future<void> tap(WidgetTester tester, List<String> labels) async {
  await tapAny(tester, labels);
}


/// Exercises what the screens *do*, not just that they open.
///
/// Opening a screen proves it does not crash. It says nothing about whether
/// the switch on it switches anything — and a settings screen that paints
/// perfectly while changing nothing is a bug a screen-by-screen pass cannot
/// see. Each check below performs an action and then looks for the effect.
Future<void> _functions(WidgetTester tester) async {
  // ── The palette actually changes ────────────────────────────────────────
  await tap(tester, ['Thêm']);
  await settle(tester, const Duration(seconds: 2));
  await tap(tester, ['Cài đặt']);
  await settle(tester, const Duration(seconds: 2));

  // Read from *inside* the app, not at the MaterialApp itself. `Theme.of` at
  // the MaterialApp's own element returns the theme inherited from above it —
  // Flutter's default, which is light — so the check reported "chọn Tối, app
  // vẫn light" while the screenshot showed a correctly dark screen. A
  // measurement that is wrong in one direction only is the worst kind.
  Brightness palette() =>
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

  final started = palette();
  await tap(tester, ['Sáng']);
  await settle(tester, const Duration(seconds: 2));
  if (palette() != Brightness.light) {
    _findings.add(
      _Finding('50-giao-dien-sang', 'KHÔNG ĐỔI', 'chọn Sáng, app vẫn ${palette().name}'),
    );
  }
  // The app-bar title, not the section heading: choosing a palette rebuilds
  // the list and "Giao diện" scrolls out of view, which is not a defect.
  await check(tester, '50-giao-dien-sang', landmarks: ['Cài đặt', 'Settings']);

  await tap(tester, ['Tối']);
  await settle(tester, const Duration(seconds: 2));
  if (palette() != Brightness.dark) {
    _findings.add(
      _Finding('51-giao-dien-toi', 'KHÔNG ĐỔI', 'chọn Tối, app vẫn ${palette().name}'),
    );
  }
  debugPrint('UAT: giao diện $started → ${palette().name}');

  // ── The language actually changes ───────────────────────────────────────
  await tap(tester, ['English']);
  await settle(tester, const Duration(seconds: 3));
  if (find.textContaining('Settings').evaluate().isEmpty &&
      find.textContaining('Appearance').evaluate().isEmpty) {
    _findings.add(
      _Finding('52-ngon-ngu', 'KHÔNG ĐỔI', 'chọn English, màn hình vẫn tiếng Việt'),
    );
  }
  await check(tester, '52-ngon-ngu', landmarks: ['Settings', 'Appearance', 'Cài đặt']);

  await tapAny(tester, ['Tiếng Việt']);
  await settle(tester, const Duration(seconds: 3));
  if (find.textContaining('Cài đặt').evaluate().isEmpty &&
      find.textContaining('Giao diện').evaluate().isEmpty) {
    _findings.add(
      _Finding('53-ngon-ngu-ve', 'KHÔNG ĐỔI', 'chọn Tiếng Việt, không trở lại được'),
    );
  }
  await popBack(tester);
  await settle(tester, const Duration(seconds: 2));

  // ── Searching without diacritics, which is how people type ──────────────
  await tap(tester, ['Sân golf']);
  await settle(tester, const Duration(seconds: 2));
  await tap(tester, ['Tất cả']);
  await settle(tester, const Duration(seconds: 2));
  final box = find.byType(TextField);
  if (box.evaluate().isEmpty) {
    _findings.add(_Finding('54-tim-khong-dau', 'THIẾU', 'không có ô tìm kiếm'));
  } else {
    await tester.enterText(box.first, 'long bien');
    await settle(tester, const Duration(seconds: 4));
    if (find.textContaining('Long Biên').evaluate().isEmpty) {
      _findings.add(
        _Finding('54-tim-khong-dau', 'KHÔNG TÌM THẤY',
            'gõ "long bien" không ra Long Biên'),
      );
    }
    await check(tester, '54-tim-khong-dau', landmarks: ['Long Biên', 'Tìm sân']);
    await tester.enterText(box.first, '');
    await settle(tester, const Duration(seconds: 3));
  }
}


/// A second round of functions, on things the first pass only opened.
///
/// Each of these performs the action a golfer performs and then looks for the
/// consequence — a club listed, a course in Favourites, a note that saved, a
/// distance that appeared. A screen can open perfectly and do none of them.
Future<void> _moreFunctions(WidgetTester tester) async {
  // ── Marking a course as a favourite puts it in Favourites ───────────────
  await tap(tester, ['Sân golf']);
  await settle(tester, const Duration(seconds: 2));
  await tap(tester, ['Tất cả']);
  await settle(tester, const Duration(seconds: 3));

  final hearts = find.byIcon(Icons.favorite_border);
  final firstCourse = find.byType(Card).evaluate().isEmpty
      ? null
      : find.byType(Card).first;
  if (hearts.evaluate().isEmpty) {
    _findings.add(_Finding('60-yeu-thich', 'THIẾU', 'không thấy nút yêu thích'));
  } else {
    await tester.tap(hearts.first, warnIfMissed: false);
    await settle(tester, const Duration(seconds: 3));
    await tap(tester, ['Yêu thích']);
    await settle(tester, const Duration(seconds: 3));
    if (find.byType(Card).evaluate().isEmpty &&
        find.textContaining('Golf').evaluate().isEmpty) {
      _findings.add(
        _Finding('60-yeu-thich', 'KHÔNG LƯU',
            'đánh dấu yêu thích xong, tab Yêu thích vẫn trống'),
      );
    }
    await check(tester, '60-yeu-thich', landmarks: ['Yêu thích']);
    // Put it back, so the sweep does not leave the account changed.
    await tap(tester, ['Tất cả']);
    await settle(tester, const Duration(seconds: 3));
    final filled = find.byIcon(Icons.favorite);
    if (filled.evaluate().isNotEmpty) {
      await tester.tap(filled.first, warnIfMissed: false);
      await settle(tester, const Duration(seconds: 2));
    }
  }
  if (firstCourse != null) debugPrint('UAT: yêu thích đã thử');

  // ── A bag actually lists its clubs ──────────────────────────────────────
  await tap(tester, ['Thêm']);
  await settle(tester, const Duration(seconds: 2));
  await tap(tester, ['Túi gậy của tôi']);
  await settle(tester, const Duration(seconds: 3));
  await tapIfPresent(tester, find.textContaining('My Bag'));
  await settle(tester, const Duration(seconds: 3));
  if (find.textContaining('Driver').evaluate().isEmpty &&
      find.textContaining('Gậy').evaluate().isEmpty) {
    _findings.add(
      _Finding('61-tui-gay-chi-tiet', 'TRỐNG',
          'mở túi gậy 14 gậy nhưng không thấy gậy nào'),
    );
  }
  await check(tester, '61-tui-gay-chi-tiet', landmarks: ['Driver', 'Gậy', 'Túi gậy']);
  await popBack(tester);
  await settle(tester, const Duration(seconds: 2));
  await popBack(tester);
  await settle(tester, const Duration(seconds: 2));
}


/// The screens with computation behind them, and the actions with consequences
/// on the server.
///
/// Everything here was reachable and had never been opened by anything: four
/// analytics screens each doing real arithmetic over the golfer's rounds, and
/// a package download that writes to the device. A screen that computes is a
/// screen that can divide by zero on an account with three rounds in it.
Future<void> _deepFunctions(WidgetTester tester) async {
  // ── The four analytics screens ──────────────────────────────────────────
  const analytics = <String, (String, List<String>)>{
    '70-strokes-gained': ('Strokes Gained', ['Strokes Gained', 'Chưa có dữ liệu']),
    '71-hieu-suat-gay': ('Hiệu suất gậy', ['Hiệu suất', 'Độ phân tán', 'Chưa có']),
    '72-vung-phat-bong': ('Vùng phát bóng', ['Vùng phát bóng', 'Chưa có']),
    '73-smart-target': ('Smart Target', ['Smart Target', 'Chưa có']),
  };

  for (final entry in analytics.entries) {
    await tap(tester, ['Thêm']);
    await settle(tester, const Duration(seconds: 2));
    await tap(tester, ['Phân tích']);
    await settle(tester, const Duration(seconds: 3));
    await tap(tester, [entry.value.$1]);
    await check(tester, entry.key, landmarks: entry.value.$2);
    await popBack(tester);
    await settle(tester, const Duration(seconds: 2));
    await popBack(tester);
    await settle(tester, const Duration(seconds: 2));
  }

  // ── Downloading a course for offline play ───────────────────────────────
  //
  // The one action in the app that writes a package to the device, and the one
  // a golfer takes in the car park with one bar of signal.
  await tap(tester, ['Sân golf']);
  await settle(tester, const Duration(seconds: 2));
  await tap(tester, ['Tất cả']);
  await settle(tester, const Duration(seconds: 3));
  final box = find.byType(TextField);
  if (box.evaluate().isNotEmpty) {
    await tester.enterText(box.first, 'Long Biên');
    await settle(tester, const Duration(seconds: 4));
  }

  // Two taps, not one, and a way back.
  //
  // The button on the card opens a screen of its own — size, version, the
  // Wi-Fi switch — with the real download button on it. The first version of
  // this step tapped the card, waited thirty seconds on the screen it had just
  // opened without pressing anything, and then carried on tapping as though it
  // were still on the course list. Every step after it landed on the download
  // screen: eighteen findings, all of them the same missing `popBack`.
  final download = find.text('Tải xuống');
  if (download.evaluate().isEmpty) {
    // Already downloaded is a valid state, not a failure — say which.
    debugPrint('UAT: không có nút Tải xuống (có thể đã tải rồi)');
    await check(tester, '74-tai-goi-san', landmarks: ['Long Biên', 'Tìm sân']);
  } else {
    await tester.tap(download.first, warnIfMissed: false);
    await settle(tester, const Duration(seconds: 4));
    await check(tester, '74-man-tai-goi', landmarks: ['Tải xuống', 'KB', 'Phiên bản']);

    // The button on the download screen itself.
    final start = find.widgetWithText(FilledButton, 'Tải xuống');
    final anyStart = start.evaluate().isNotEmpty ? start : find.text('Tải xuống');
    if (anyStart.evaluate().isEmpty) {
      _findings.add(_Finding('74-man-tai-goi', 'THIẾU', 'không có nút tải trên màn tải'));
    } else {
      await tester.tap(anyStart.first, warnIfMissed: false);
      // Packages here are a few hundred KB.
      await settle(tester, const Duration(seconds: 40));
      if (find.textContaining('Đã tải').evaluate().isEmpty &&
          find.textContaining('Cập nhật').evaluate().isEmpty &&
          find.textContaining('Xoá').evaluate().isEmpty) {
        _findings.add(
          _Finding('75-da-tai', 'KHÔNG XONG',
              'bấm tải, 40 giây sau vẫn chưa thấy trạng thái đã tải'),
        );
      }
      await check(tester, '75-da-tai', landmarks: ['KB', 'Phiên bản', 'Đã tải']);
    }
    await popBack(tester);
    await settle(tester, const Duration(seconds: 3));
  }
  if (box.evaluate().isNotEmpty) {
    await tester.enterText(box.first, '');
    await settle(tester, const Duration(seconds: 2));
  }
}


/// Photographs the two maps under the finger, and says plainly what it cannot
/// prove.
///
/// ─── Why there is no assertion here ───────────────────────────────────────
///
/// Both maps are MapLibre platform views. A tap sent by `WidgetTester` is a
/// synthetic pointer event inside the Flutter engine, and it does not reach
/// the native view's own hit testing — so `onMapClick` never fires and no
/// target is placed. The first version of this step asserted that one was, and
/// filed two defects against an app that was working.
///
/// What made it convincing was the screenshot: a dot on the fairway, a line
/// labelled "316 yd", distance rings around it. None of it was a target. The
/// line is the play line to the green, the dot is the green marker, and the
/// rings are a layer somebody had switched on two steps earlier. A picture
/// that looks like the feature working is not the feature working.
///
/// The behaviour itself is covered where it can be: the widget tests in
/// `active_round_target_view_test.dart` drop a target the way a tap does and
/// assert the Target tab reads it, follows the golfer, and follows the target.
/// What remains unproven here is the bridge from finger to native view, and a
/// simulator cannot prove it. That needs a thumb.
Future<void> _mapTouch(WidgetTester tester) async {
  await tap(tester, ['Bản đồ']);
  await settle(tester, const Duration(seconds: 3));
  await check(tester, '80-ban-do-trong-vong', landmarks: ['Hố']);

  await tapIfPresent(tester, find.bySemanticsLabel('Chuyển sang bản đồ sân'));
  await settle(tester, const Duration(seconds: 4));
  await check(tester, '81-ban-do-ve-trong-vong', landmarks: ['Hố']);

  await tap(tester, ['Mục tiêu']);
  await check(tester, '82-tab-muc-tieu', landmarks: ['Mục tiêu', 'Tới green']);

  await tap(tester, ['Điểm']);
  await settle(tester, const Duration(seconds: 2));
}

/// Opening a club and saving it back.
///
/// The bag is where the strategy book gets its carry distances, so a club that
/// cannot be edited is a strategy book that cannot be corrected.
Future<void> _bagEditing(WidgetTester tester) async {
  await tap(tester, ['Thêm']);
  await settle(tester, const Duration(seconds: 2));
  await tap(tester, ['Túi gậy của tôi']);
  await settle(tester, const Duration(seconds: 3));
  await tapIfPresent(tester, find.textContaining('My Bag'));
  await settle(tester, const Duration(seconds: 3));

  // The first club in the bag, whatever it is called.
  //
  // This step used to look for "Driver" and reported the bag broken when it
  // could not find one. The bag was right: `My Bag` on this account holds
  // fourteen clubs starting at a 15° wood, and the driver lives in the other
  // bag, which is switched off. A sweep that assumes what the data contains
  // reports the data as a defect.
  Finder firstClub = find.textContaining('Gỗ');
  for (final name in ['Gỗ', 'Sắt', 'Hybrid', 'Driver', 'Wedge']) {
    if (find.textContaining(name).evaluate().isNotEmpty) {
      firstClub = find.textContaining(name);
      break;
    }
  }
  if (!await tapIfPresent(tester, firstClub)) {
    _findings.add(_Finding('83-sua-gay', 'THIẾU', 'không mở được gậy nào'));
  } else {
    await settle(tester, const Duration(seconds: 3));
    await check(tester, '83-sua-gay', landmarks: ['Cự ly', 'Lưu', 'Loft', 'Gậy']);

    // Save it back unchanged. The question is whether the form can commit at
    // all — a save button that never enables is a bag nobody can correct.
    final fields = find.byType(TextFormField);
    if (fields.evaluate().isNotEmpty) {
      await tester.enterText(fields.first, '210');
      await settle(tester, const Duration(seconds: 2));
    }
    if (!await tapAny(tester, ['Lưu', 'Save'])) {
      _findings.add(_Finding('83-sua-gay', 'KHÔNG LƯU', 'không bấm được Lưu'));
    }
    await settle(tester, const Duration(seconds: 4));
    await check(tester, '84-da-luu-gay', landmarks: ['Túi gậy', 'Gậy', 'My Bag']);
  }

  await popBack(tester);
  await settle(tester, const Duration(seconds: 2));
  await popBack(tester);
  await settle(tester, const Duration(seconds: 2));
  await popBack(tester);
  await settle(tester, const Duration(seconds: 2));
}


/// Starting a round and abandoning it, which is the other way a round ends.
///
/// The sweep's main round is finished properly. This one is left, the way a
/// golfer leaves a round when the weather turns — and it is the only path that
/// exercises `roundsAbandon`, whose failure message the sweep has been
/// scanning for all along without ever being able to trigger it.
Future<void> _abandonARound(WidgetTester tester) async {
  await tap(tester, ['Chơi golf']);
  await settle(tester, const Duration(seconds: 2));
  await tapAny(tester, ['Bắt đầu vòng đấu']);
  await settle(tester, const Duration(seconds: 3));
  await tapAny(tester, ['Chọn sân']);
  await settle(tester, const Duration(seconds: 2));
  final box = find.byType(TextField);
  if (box.evaluate().isNotEmpty) {
    await tester.enterText(box.first, 'Long Biên');
    await settle(tester, const Duration(seconds: 3));
  }
  await tapIfPresent(tester, find.text('Long Biên Golf Course'));
  await settle(tester, const Duration(seconds: 4));
  final pairings = find.textContaining('→');
  if (pairings.evaluate().isNotEmpty) {
    await tapIfPresent(tester, pairings.first);
    await settle(tester, const Duration(seconds: 3));
  }
  var started = false;
  for (final label in ['Bắt đầu vòng đấu', 'Start Round']) {
    if (await tapIfPresent(tester, find.widgetWithText(FilledButton, label))) {
      started = true;
      break;
    }
  }
  if (!started) {
    _findings.add(_Finding('90-bo-do', 'THIẾU', 'không mở được vòng thứ hai'));
    return;
  }
  await settle(tester, const Duration(seconds: 8));

  // Walk out of it the way a golfer does: back, without finishing.
  await popBack(tester);
  await settle(tester, const Duration(seconds: 3));

  await tap(tester, ['Vòng đấu']);
  await settle(tester, const Duration(seconds: 4));
  await check(tester, '90-vong-dang-choi', landmarks: ['Vòng đấu']);

  // The abandon action lives in the round's own sheet, behind the card — the
  // list itself only shows a status pill and a chevron.
  await tapIfPresent(tester, find.textContaining('Đang chơi'));
  await settle(tester, const Duration(seconds: 3));
  await check(tester, '90b-chi-tiet-vong', landmarks: ['Long Biên', 'Đang chơi']);

  if (!await tapAny(tester, ['Bỏ dở vòng đấu'])) {
    _findings.add(
      _Finding('91-bo-do', 'THIẾU',
          'có vòng đang chơi nhưng không thấy nút Bỏ dở'),
    );
    return;
  }
  await settle(tester, const Duration(seconds: 2));
  await check(tester, '91-xac-nhan-bo-do', landmarks: ['Bỏ dở']);

  // The confirmation is not always a FilledButton, and guessing its type left
  // the dialog open — which left the sheet open under it, which swallowed
  // every tap the sweep made afterwards. That is how one stuck dialog became
  // twenty findings about screens that were fine.
  await settle(tester, const Duration(seconds: 2));
  for (final label in ['Bỏ dở vòng đấu', 'Bỏ dở', 'Xác nhận']) {
    final button = find.descendant(
      of: find.byType(Dialog),
      matching: find.text(label),
    );
    if (button.evaluate().isNotEmpty) {
      await tester.tap(button.first, warnIfMissed: false);
      break;
    }
    if (await tapIfPresent(tester, find.widgetWithText(TextButton, label))) {
      break;
    }
    if (await tapIfPresent(tester, find.widgetWithText(FilledButton, label))) {
      break;
    }
  }
  await settle(tester, const Duration(seconds: 8));
  await check(tester, '92-da-bo-do', landmarks: ['Vòng đấu']);

  // Whatever happened above, leave nothing open behind us.
  await tapAny(tester, ['Đóng']);
  await settle(tester, const Duration(seconds: 2));
  if (find.textContaining('Đang chơi').evaluate().isNotEmpty) {
    _findings.add(
      _Finding('92-da-bo-do', 'CÒN SÓT',
          'sau khi bỏ dở, danh sách vẫn còn vòng "Đang chơi"'),
    );
  }
}


/// The last two corners nothing had touched: the golfer's own profile, and the
/// privacy screen.
///
/// Nothing here submits a privacy request and nothing goes near deleting an
/// account or a round. The dialog is opened to prove it builds and then
/// dismissed — a sweep that exercised the destructive half would be a sweep
/// nobody could run twice.
Future<void> _profileAndPrivacy(WidgetTester tester) async {
  // ── Metres and yards, and the labels that follow them ───────────────────
  await tap(tester, ['Hồ sơ']);
  await settle(tester, const Duration(seconds: 3));

  // Scrolled to first. The profile page opens on the stats card and the unit
  // picker is further down a lazy list, so it is not merely off-screen — it
  // has not been built, and `find.text` cannot find what does not exist yet.
  // The step reported "không thấy nút chọn Mét/Yard" against a control that
  // was simply below the fold.
  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isNotEmpty) {
    for (var i = 0; i < 6; i++) {
      if (find.text('Yard').evaluate().isNotEmpty) break;
      await tester.drag(scrollable.first, const Offset(0, -400));
      await settle(tester, const Duration(seconds: 1));
    }
  }

  final yards = find.text('Yard');
  final metres = find.text('Mét');
  if (yards.evaluate().isEmpty || metres.evaluate().isEmpty) {
    _findings.add(
      _Finding('95-doi-don-vi', 'THIẾU', 'không thấy nút chọn Mét/Yard'),
    );
  } else {
    await tester.tap(yards.first, warnIfMissed: false);
    await settle(tester, const Duration(seconds: 3));
    // The driver-distance field is labelled with the unit in force, so the
    // label is the consequence: picking yards and being shown metres would be
    // a picker that paints and does nothing.
    if (find.textContaining('Yard').evaluate().isEmpty) {
      _findings.add(
        _Finding('95-doi-don-vi', 'KHÔNG ĐỔI',
            'chọn Yard nhưng nhãn cự ly không đổi theo'),
      );
    }
    await check(tester, '95-doi-don-vi', landmarks: ['Hồ sơ', 'Đơn vị']);

    await tester.tap(metres.first, warnIfMissed: false);
    await settle(tester, const Duration(seconds: 3));
    if (find.textContaining('Mét').evaluate().isEmpty) {
      _findings.add(
        _Finding('96-don-vi-ve-met', 'KHÔNG ĐỔI', 'không quay lại Mét được'),
      );
    }
  }

  // ── The privacy request dialog, opened and closed ───────────────────────
  await tap(tester, ['Thêm']);
  await settle(tester, const Duration(seconds: 2));
  await tap(tester, ['Bảo mật']);
  await settle(tester, const Duration(seconds: 3));

  if (!await tapAny(tester, ['Yêu cầu mới'])) {
    _findings.add(
      _Finding('97-yeu-cau-rieng-tu', 'THIẾU', 'không thấy nút Yêu cầu mới'),
    );
  } else {
    await settle(tester, const Duration(seconds: 2));
    await check(tester, '97-yeu-cau-rieng-tu',
        landmarks: ['Yêu cầu', 'Xuất dữ liệu', 'Xoá']);
    // Out, without submitting anything.
    if (!await tapAny(tester, ['Huỷ', 'Hủy', 'Đóng'])) {
      await popBack(tester);
    }
    await settle(tester, const Duration(seconds: 2));
  }
  await popBack(tester);
  await settle(tester, const Duration(seconds: 2));
}

Future<void> _tabs(WidgetTester tester) async {
  await tap(tester, ['Sân golf']);
  await check(tester, '10-san-golf', landmarks: ['Tìm sân golf']);

  // The four filters on the course list, each a different query and each able
  // to fail on its own.
  for (final entry in const {
    '11-san-gan-day': 'Gần đây',
    '12-san-yeu-thich': 'Yêu thích',
    '13-san-da-xem': 'Đã xem',
    '14-san-tat-ca': 'Tất cả',
  }.entries) {
    await tap(tester, [entry.value]);
    await check(tester, entry.key, landmarks: [entry.value]);
  }

  await tap(tester, ['Vòng đấu']);
  await check(tester, '15-vong-dau', landmarks: ['Vòng đấu']);

  await tap(tester, ['Hồ sơ']);
  await check(tester, '16-ho-so', landmarks: ['Hồ sơ', 'Thành tích']);

  await tap(tester, ['Thêm']);
  await check(tester, '17-them', landmarks: ['Thêm', 'Cài đặt']);
}

/// Everything reachable from the More menu, one at a time, coming back after
/// each. These are the screens no tour had ever opened.
Future<void> _fromMore(WidgetTester tester) async {
  const screens = <String, (String, List<String>)>{
    '18-tui-gay': ('Túi gậy của tôi', ['Túi gậy']),
    '19-phan-tich': ('Phân tích', ['Phân tích', 'Hiệu suất']),
    '20-san-da-tai': ('Sân đã tải', ['Sân đã tải', 'Đã tải']),
    '21-bao-loi-du-lieu': ('Báo lỗi dữ liệu', ['Báo lỗi']),
    '22-phien-dang-nhap': ('Phiên đăng nhập', ['Phiên']),
    '23-bao-mat': ('Bảo mật', ['Bảo mật', 'Quyền riêng tư']),
    '24-cai-dat': ('Cài đặt', ['Cài đặt', 'Giao diện']),
  };

  for (final entry in screens.entries) {
    await tap(tester, ['Thêm']);
    await settle(tester, const Duration(seconds: 2));
    await tap(tester, [entry.value.$1]);
    await check(tester, entry.key, landmarks: entry.value.$2);
    await popBack(tester);
    await settle(tester, const Duration(seconds: 2));
  }
}

/// The round: setup, the five tabs, the note sheet, and finishing.
Future<void> _round(WidgetTester tester) async {
  await tap(tester, ['Chơi golf']);
  await check(tester, '30-choi-golf', landmarks: ['Sẵn sàng', 'Bắt đầu']);

  await tap(tester, ['Bắt đầu vòng đấu']);
  await check(tester, '31-tao-vong-dau', landmarks: ['Người chơi', 'Thể thức']);

  // One finding, not fifteen.
  //
  // Everything below needs a round. When the form does not open — most often
  // because an unfinished round from an earlier run is still blocking new ones
  // — the old code carried on tapping and filed a "KHÔNG TỚI" against every
  // screen of the round in turn. Twenty findings, one cause, and a report
  // nobody can read.
  if (find.textContaining('Thể thức').evaluate().isEmpty &&
      find.textContaining('Người chơi').evaluate().isEmpty) {
    _findings.add(
      _Finding('31-tao-vong-dau', 'CHẶN',
          'không mở được form tạo vòng — bỏ qua toàn bộ phần vòng đấu'),
    );
    return;
  }

  await tap(tester, ['Chọn sân']);
  await settle(tester, const Duration(seconds: 2));
  final search = find.byType(TextField);
  if (search.evaluate().isNotEmpty) {
    await tester.enterText(search.first, 'Long Biên');
    await settle(tester, const Duration(seconds: 3));
  }
  await check(tester, '32-chon-san', landmarks: ['Chọn sân']);

  await tapIfPresent(tester, find.text('Long Biên Golf Course'));
  await settle(tester, const Duration(seconds: 4));
  await check(tester, '33-chon-vong-choi', landmarks: ['Đường', 'Chọn vòng']);

  final pairings = find.textContaining('→');
  if (pairings.evaluate().isEmpty) {
    _findings.add(
      _Finding('33-chon-vong-choi', 'THIẾU', 'không có cặp 18 hố nào'),
    );
  } else {
    await tapIfPresent(tester, pairings.first);
    await settle(tester, const Duration(seconds: 3));
  }

  for (final label in ['Bắt đầu vòng đấu', 'Start Round']) {
    if (await tapIfPresent(
      tester,
      find.widgetWithText(FilledButton, label),
    )) {
      break;
    }
  }
  await settle(tester, const Duration(seconds: 8));
  await check(tester, '34-vong-dau-mo', landmarks: ['Hố', 'Điểm số']);

  // The five tabs of a live round.
  await tap(tester, ['Bản đồ']);
  await check(tester, '35-ban-do-ve-tinh', landmarks: ['Hố', 'Đo khoảng cách']);

  if (await tapIfPresent(
    tester,
    find.bySemanticsLabel('Chuyển sang bản đồ sân'),
  )) {
    await settle(tester, const Duration(seconds: 4));
  }
  await check(tester, '36-ban-do-ve', landmarks: ['Hố']);

  await tap(tester, ['Mục tiêu']);
  await check(tester, '37-muc-tieu', landmarks: ['Mục tiêu']);

  await tap(tester, ['Điều kiện']);
  await check(tester, '38-dieu-kien', landmarks: ['Điều kiện']);

  await tap(tester, ['Điểm']);
  await check(tester, '39-the-diem', landmarks: ['Điểm số', 'Hố']);

  // A score, so the card is not empty when the round is finished.
  //
  // Scoped to the strip, and that is not fussiness. The hole header prints
  // "Par 4" too, so `bySemanticsLabel(RegExp('^Par '))` on its own matches the
  // heading — and a tour that taps a heading records no score, reports no
  // failure, and leaves a card reading "0/1 đã nhập" behind it. That is
  // exactly what the sale kit's missing eight holes turned out to be.
  await tapIfPresent(tester, find.text('VSP Golfer'));
  await settle(tester, const Duration(seconds: 2));

  final button = find.descendant(
    of: find.byType(QuickScoreStrip),
    matching: find.bySemanticsLabel(RegExp('^Par ')),
  );
  if (button.evaluate().isEmpty) {
    _findings.add(_Finding('39-the-diem', 'THIẾU', 'không mở được dải điểm'));
  } else {
    await tester.tap(button.first, warnIfMissed: false);
    await settle(tester, const Duration(seconds: 2));
  }
  await check(tester, '40-nhap-diem', landmarks: ['Điểm số']);
  if (find.textContaining('0/1').evaluate().isNotEmpty) {
    _findings.add(
      _Finding('40-nhap-diem', 'KHÔNG GHI', 'thẻ điểm vẫn đọc 0/1 đã nhập'),
    );
  }

  // The note sheet, which is where the keyboard covered the save button. Its
  // tooltip carries the hole number — "Hố 10 — lần trước" — so it is matched
  // on the part that does not change.
  // By its key. The tooltip carries the hole number — "Hố 10 — lần trước" —
  // so matching it means matching a moving string.
  await tapIfPresent(tester, find.byKey(const Key('scorecard_hole_history')));
  await settle(tester, const Duration(seconds: 2));
  await check(tester, '41-ghi-chu-ho', landmarks: ['Ghi chú', 'Lịch sử']);

  // Typing a note and saving it, which is the only thing this sheet is for.
  final noteField = find.byKey(const Key('hole_note_field'));
  if (noteField.evaluate().isEmpty) {
    _findings.add(_Finding('41-ghi-chu-ho', 'THIẾU', 'không có ô ghi chú'));
  } else {
    await tester.enterText(noteField.first, 'Gió ngược, lấy thêm một gậy.');
    await settle(tester, const Duration(seconds: 2));
    final save = find.byKey(const Key('hole_note_save'));
    if (save.evaluate().isEmpty) {
      _findings.add(_Finding('41-ghi-chu-ho', 'THIẾU', 'không có nút lưu'));
    } else {
      await tester.tap(save.first, warnIfMissed: false);
      await settle(tester, const Duration(seconds: 5));
      await check(tester, '41b-ghi-chu-da-luu', landmarks: ['Ghi chú', 'Lịch sử', 'Hố']);
    }
  }
  await popBack(tester);

  await _mapTouch(tester);

  // ── Walking the whole round ───────────────────────────────────────────
  //
  // Eighteen presses of "Hố sau", checked by position rather than by the
  // hole's number: a paired round numbers its holes 1-9 and then 1-9 again, so
  // "Hố 1" is two different holes and only "Hố 1 trên 18" is unambiguous. This
  // is the walk that used to loop back to the first tee at the turn.
  await tap(tester, ['Điểm']);
  await settle(tester, const Duration(seconds: 2));
  var reached = 0;
  for (var i = 0; i < 24; i++) {
    for (var hole = 1; hole <= 18; hole++) {
      if (find.textContaining('Hố $hole trên 18').evaluate().isNotEmpty) {
        reached = hole;
        break;
      }
    }
    if (reached >= 18) break;
    if (!await tapIfPresent(tester, find.bySemanticsLabel('Hố sau'))) break;
    await settle(tester, const Duration(seconds: 2));
  }
  if (reached < 18) {
    _findings.add(
      _Finding('44-di-het-18-ho', 'KHÔNG TỚI',
          'bấm Hố sau 24 lần chỉ tới được hố $reached / 18'),
    );
  }
  await check(tester, '44-di-het-18-ho', landmarks: ['Hố 18 trên 18', 'Hố']);

  // ── Reading a paper card with the camera ──────────────────────────────
  //
  // Only as far as the source chooser. What comes after it is the system photo
  // picker, which is not a Flutter widget and cannot be driven from here — so
  // the tour stops where the app stops being the thing on screen, and says so.
  for (final tip in ['Chụp ảnh card']) {
    if (await tapIfPresent(tester, find.byTooltip(tip))) break;
  }
  await settle(tester, const Duration(seconds: 2));
  await check(tester, '45-chup-the-diem', landmarks: ['Chụp', 'Thư viện', 'Huỷ', 'Máy ảnh']);
  await tapAny(tester, ['Huỷ', 'Hủy', 'Đóng']);
  await settle(tester, const Duration(seconds: 2));
  if (find.textContaining('Chụp ảnh').evaluate().isNotEmpty) {
    await popBack(tester);
    await settle(tester, const Duration(seconds: 2));
  }

  // Finish, so the sweep does not leave a round open on the server.
  await tap(tester, ['Điểm']);
  for (final tip in ['Kết thúc vòng đấu', 'Finish Round']) {
    if (await tapIfPresent(tester, find.byTooltip(tip))) break;
  }
  await settle(tester, const Duration(seconds: 1));
  await check(tester, '42-ket-thuc', landmarks: ['Kết thúc']);

  for (final label in ['Kết thúc', 'Finish']) {
    if (await tapIfPresent(
      tester,
      find.widgetWithText(FilledButton, label),
    )) {
      break;
    }
  }
  await settle(tester, const Duration(seconds: 8));
  await check(tester, '43-tong-ket', landmarks: ['Vòng đấu hoàn', 'Tổng kết']);

  if (!await tapAny(tester, ['Xong', 'Done'])) await popBack(tester);
  await settle(tester, const Duration(seconds: 3));
}

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rà toàn bộ màn hình và chức năng', (tester) async {
    tourOutputDir = '/tmp/vsp-uat';
    _catchFrameworkErrors();

    SharedPreferences.setMockInitialValues({
      'app_theme_mode': 'dark',
      'app_locale': 'vi',
    });

    await tester.pumpWidget(
      const VspApp(syncOfflineQueue: false, loadBasemapConfig: false),
    );
    await settle(tester, const Duration(seconds: 3));

    final signedIn = ['Sân golf', 'Courses']
        .any((label) => find.text(label).evaluate().isNotEmpty);
    if (!signedIn) {
      await check(tester, '01-mo-dau', landmarks: ['Tiếng Việt', 'email']);
      await signIn(tester, email: _email, password: _password);
    }

    await SatelliteImagery.load(BasemapConfigService());
    await settle(tester, const Duration(seconds: 2));
    // Online only. The imagery provider is fetched from `/config/basemap`, so
    // offline there is nothing to fetch and "no imagery" is the right answer
    // rather than a defect — the maps fall back to the drawn hole, which is
    // the whole point of carrying a package.
    if (!_offline && !SatelliteImagery.current.isAvailable) {
      _findings.add(
        _Finding('cấu hình', 'THIẾU', 'bản dựng này không có ảnh vệ tinh'),
      );
    }

    await check(tester, '02-trang-chu', landmarks: ['Sân golf', 'Chơi golf']);

    await _tabs(tester);
    await _fromMore(tester);

    if (_offline) {
      // Everything below needs a server to have answered at least once —
      // starting a round, downloading a package, abandoning one. Offline, the
      // question is only whether the screens above hold together, and they
      // have just been asked.
      debugPrint('UAT: chế độ mất mạng — chỉ rà màn hình');
    } else {
      await _functions(tester);
      await _moreFunctions(tester);
      await _deepFunctions(tester);
      await _bagEditing(tester);
      await _profileAndPrivacy(tester);
      await _round(tester);
      await _abandonARound(tester);
    }

    // ── The report ────────────────────────────────────────────────────────
    debugPrint('');
    debugPrint('════════ KẾT QUẢ RÀ SOÁT ════════');
    if (_findings.isEmpty) {
      debugPrint('Không phát hiện lỗi nào.');
    } else {
      for (var i = 0; i < _findings.length; i++) {
        debugPrint('${i + 1}. ${_findings[i]}');
      }
    }
    debugPrint('Tổng: ${_findings.length} phát hiện');
    debugPrint('═════════════════════════════════');

    expectTheTourMoved();
    expect(
      _findings,
      isEmpty,
      reason: 'còn ${_findings.length} vấn đề:\n'
          '${_findings.map((f) => '  • $f').join('\n')}',
    );
  });
}
