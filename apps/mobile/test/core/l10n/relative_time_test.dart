// Tests for the one relative-time formatter.
//
// There were five, and they disagreed. The round setup banner said
// "today / yesterday / 3 days ago" then fell back to `8/3/2026` — month first,
// in a country that reads that as 3 August. The package card said
// "Just now / Yesterday / 2 months ago". Two more lived in the privacy screen
// and the course detail page. All five were English-only, on screens that were
// otherwise entirely Vietnamese.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/core/l10n/relative_time.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

void main() {
  late AppLocalizations vi;
  late AppLocalizations en;

  setUpAll(() async {
    vi = await AppLocalizations.delegate.load(const Locale('vi'));
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final now = DateTime(2026, 8, 8, 12);
  String viFor(DateTime when) => RelativeTime.format(vi, when, now: now);

  test('a fresh timestamp reads as just now', () {
    expect(viFor(now.subtract(const Duration(minutes: 5))), vi.relativeJustNow);
  });

  test('hours are hours', () {
    expect(
      viFor(now.subtract(const Duration(hours: 3))),
      vi.relativeHoursAgo(3),
    );
  });

  test('yesterday is named, not counted', () {
    expect(viFor(now.subtract(const Duration(days: 1))), vi.relativeYesterday);
  });

  test('days are days', () {
    expect(viFor(now.subtract(const Duration(days: 5))), vi.relativeDaysAgo(5));
  });

  test('past a month it counts months', () {
    expect(
      viFor(now.subtract(const Duration(days: 70))),
      vi.relativeMonthsAgo(2),
    );
  });

  test('past a year it gives the date, because the day is the useful part', () {
    expect(viFor(DateTime(2024, 3, 9)), '9/3/2024');
  });

  test('the date is day first', () {
    // 8/3/2026 is 3 August to a Vietnamese reader and 8 March to an American
    // one. Two of the five old formatters wrote the American order.
    expect(RelativeTime.date(DateTime(2026, 8, 3)), '3/8/2026');
  });

  test('a timestamp from the future is just now, not negative days', () {
    // Clock skew between a phone and the server is routine, and "-2 ngày trước"
    // is worse than a small lie.
    expect(viFor(now.add(const Duration(hours: 2))), vi.relativeJustNow);
  });

  test('it speaks whichever language is loaded', () {
    expect(
      RelativeTime.format(en, now.subtract(const Duration(days: 5)), now: now),
      en.relativeDaysAgo(5),
    );
    expect(
      viFor(now.subtract(const Duration(days: 5))),
      isNot(en.relativeDaysAgo(5)),
    );
  });
}
