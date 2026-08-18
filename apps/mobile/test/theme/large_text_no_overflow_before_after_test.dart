// The same sweep, over the screens either side of a round.
//
// The in-round sweep found three overflows in one pass — a fixed-height score
// key, a distance row, a summary headline — all of them written the same day
// by somebody who had not thought about a golfer turning their text up. There
// is no reason the pre-round and post-round screens would be any different,
// and every reason to check: these are lists and cards full of club names,
// course names and Vietnamese labels, none of whose widths anybody controls.
//
// Flutter throws on a RenderFlex overflow during layout, so pumping is the
// assertion.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/domain/models/course_search_result.dart';
import 'package:vsp_mobile/domain/models/data_freshness.dart';
import 'package:vsp_mobile/domain/models/performance/club_performance_stats.dart';
import 'package:vsp_mobile/features/course_search/presentation/widgets/course_card.dart';
import 'package:vsp_mobile/features/course_search/presentation/widgets/freshness_badge.dart';
import 'package:vsp_mobile/features/course_search/presentation/widgets/verification_badge.dart';
import 'package:vsp_mobile/features/performance/presentation/widgets/confidence_badge.dart';
import 'package:vsp_mobile/features/performance/presentation/widgets/sample_size_badge.dart';
import 'package:vsp_mobile/features/round/presentation/widgets/round_stats_card.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// A real club: a long Vietnamese facility name, a named đường, an address.
/// Short fixtures are how a layout passes a test and fails on a phone.
final _course = CourseSearchResult(
  courseId: 1351,
  facilityId: 3,
  facilityName: 'Long Biên Golf Course',
  courseName: 'Đường A',
  address: 'Long Biên, Hà Nội',
  holesCount: 9,
  parTotal: 36,
  rating: 71.4,
  slope: 128,
  hasPackage: true,
  updateAvailable: false,
  courseCount: 3,
  dataFreshness: DataFreshness(
    publishedAt: DateTime.utc(2026, 8, 16),
    versionNumber: 1,
    verificationStatus: VerificationStatus.verified,
  ),
);

final _beforeAndAfter = <String, Widget Function()>{
  'thẻ sân': () => CourseCard(course: _course, onTap: () {}),
  'thẻ sân gọn': () => CourseCard(course: _course, compact: true),
  'huy hiệu dữ liệu mới': () =>
      FreshnessBadge(dataFreshness: _course.dataFreshness),
  'huy hiệu xác minh': () =>
      const VerificationBadge(status: VerificationStatus.verified),
  'thống kê vòng đấu': () => const RoundStatsCard(
    fairwaysHit: 9,
    par4Or5Count: 14,
    girCount: 7,
    totalHoles: 18,
    totalPutts: 34,
    totalPenalties: 2,
  ),
  'độ tin cậy': () => const ConfidenceBadge(
    level: ConfidenceLevel.medium,
    showExplanation: true,
  ),
  'cỡ mẫu': () => const SampleSizeBadge(
    label: SampleSizeLabel.moderate,
    sampleSize: 12,
  ),
};

void main() {
  for (final scale in [1.0, 1.3, 2.0]) {
    group('at ${scale}× text', () {
      for (final entry in _beforeAndAfter.entries) {
        testWidgets('${entry.key} vẫn vừa màn hình', (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 3.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp(
              theme: VspTheme.dark(),
              locale: const Locale('vi'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(child: entry.value()),
                ),
              ),
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
        });
      }
    });
  }
}
