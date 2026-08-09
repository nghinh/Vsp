// Relative time — VSP Mobile App
//
// One formatter for "how long ago", because there were five.
//
// The round setup banner said "today / yesterday / 3 days ago" and then fell
// back to `8/3/2026` — month first, in a country that reads that as 3 August.
// The package card said "Just now / Yesterday / 3 days ago / 2 months ago".
// The privacy screen and the course detail page had two more. All five were
// English-only, so a Vietnamese golfer read "3 days ago" on a screen that was
// otherwise entirely in Vietnamese.
//
// Duplication is what let them drift: nobody who fixed one knew about the other
// four. This is the only one now.

import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Formats a past instant as something a golfer reads at a glance.
abstract final class RelativeTime {
  /// "Vừa xong" / "3 giờ trước" / "Hôm qua" / "5 ngày trước" / "2 tháng trước".
  ///
  /// Beyond a year it gives a date rather than "3 years ago", because at that
  /// distance the exact day is the useful part.
  static String format(AppLocalizations l10n, DateTime when, {DateTime? now}) {
    final difference = (now ?? DateTime.now()).difference(when);

    // A clock skew or a timestamp from the future reads as "just now" rather
    // than "-2 days ago".
    if (difference.isNegative) return l10n.relativeJustNow;

    if (difference.inDays == 0) {
      if (difference.inHours == 0) return l10n.relativeJustNow;
      return l10n.relativeHoursAgo(difference.inHours);
    }
    if (difference.inDays == 1) return l10n.relativeYesterday;
    if (difference.inDays < 30) return l10n.relativeDaysAgo(difference.inDays);
    if (difference.inDays < 365) {
      return l10n.relativeMonthsAgo((difference.inDays / 30).floor());
    }
    return date(when);
  }

  /// A plain date, day first.
  ///
  /// `8/3/2026` is 3 August to a Vietnamese reader and 8 March to an American
  /// one. The app is Vietnamese; two of the old formatters were not.
  static String date(DateTime when) => '${when.day}/${when.month}/${when.year}';
}
