// Course Card Tests — VSP Mobile App
//
// Widget tests for CourseCard widget.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/features/course_search/presentation/widgets/course_card.dart';
import 'package:vsp_mobile/domain/models/course_search_result.dart';
import 'package:vsp_mobile/domain/models/data_freshness.dart';

void main() {
  group('CourseCard', () {
    final verifiedCourse = CourseSearchResult(
      courseId: 1,
      facilityId: 1,
      facilityName: 'Thuyle Golf Club',
      courseName: 'Thuyle Championship',
      address: 'Hanoi, Vietnam',
      latitude: 21.0285,
      longitude: 105.8542,
      holesCount: 18,
      parTotal: 72,
      rating: 4.5,
      slope: 125,
      hasPackage: true,
      updateAvailable: false,
      dataFreshness: DataFreshness(
        publishedAt: DateTime.now().subtract(const Duration(days: 5)),
        versionNumber: 3,
        publisher: 'Thuyle Golf Club',
        verificationStatus: VerificationStatus.verified,
        lastVerifiedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    );

    final unverifiedCourse = CourseSearchResult(
      courseId: 2,
      facilityId: 2,
      facilityName: 'Community Course',
      address: 'Ho Chi Minh City',
      latitude: 10.8231,
      longitude: 106.6297,
      holesCount: 9,
      parTotal: 35,
      hasPackage: false,
      updateAvailable: false,
      dataFreshness: DataFreshness(
        publishedAt: DateTime.now().subtract(const Duration(days: 45)),
        versionNumber: 1,
        verificationStatus: VerificationStatus.unverified,
      ),
    );

    final staleCourse = CourseSearchResult(
      courseId: 3,
      facilityId: 3,
      facilityName: 'Old Course',
      address: 'Da Nang',
      latitude: 16.0544,
      longitude: 108.2022,
      holesCount: 18,
      hasPackage: true,
      updateAvailable: true,
      dataFreshness: DataFreshness(
        publishedAt: DateTime.now().subtract(const Duration(days: 60)),
        versionNumber: 2,
        verificationStatus: VerificationStatus.pendingReview,
      ),
    );

    Widget buildCard({
      required CourseSearchResult course,
      VoidCallback? onTap,
      VoidCallback? onFavoriteToggle,
      bool isFavorite = false,
      bool compact = false,
    }) {
      return MaterialApp(
        theme: VspTheme.light(),
        home: Scaffold(
          body: CourseCard(
            course: course,
            onTap: onTap,
            onFavoriteToggle: onFavoriteToggle,
            isFavorite: isFavorite,
            compact: compact,
          ),
        ),
      );
    }

    testWidgets('displays course name', (tester) async {
      await tester.pumpWidget(buildCard(course: verifiedCourse));
      expect(find.text('Thuyle Championship'), findsOneWidget);
    });

    testWidgets('displays course address', (tester) async {
      await tester.pumpWidget(buildCard(course: verifiedCourse));
      expect(find.text('Hanoi, Vietnam'), findsOneWidget);
    });

    testWidgets('displays holes count', (tester) async {
      await tester.pumpWidget(buildCard(course: verifiedCourse));
      expect(find.text('18 holes'), findsOneWidget);
    });

    testWidgets('displays par total', (tester) async {
      await tester.pumpWidget(buildCard(course: verifiedCourse));
      expect(find.text('Par 72'), findsOneWidget);
    });

    testWidgets('displays rating', (tester) async {
      await tester.pumpWidget(buildCard(course: verifiedCourse));
      expect(find.text('4.5'), findsOneWidget);
    });

    testWidgets('triggers onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildCard(course: verifiedCourse, onTap: () => tapped = true),
      );
      await tester.tap(find.byType(InkWell).first);
      expect(tapped, isTrue);
    });

    testWidgets('triggers onFavoriteToggle callback', (tester) async {
      var toggled = false;
      await tester.pumpWidget(
        buildCard(
          course: verifiedCourse,
          onFavoriteToggle: () => toggled = true,
        ),
      );
      await tester.tap(find.byIcon(Icons.favorite_border));
      expect(toggled, isTrue);
    });

    testWidgets('shows filled favorite icon when isFavorite=true', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildCard(course: verifiedCourse, isFavorite: true, onFavoriteToggle: () {}),
      );
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('shows outlined favorite icon when isFavorite=false', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildCard(course: verifiedCourse, isFavorite: false, onFavoriteToggle: () {}),
      );
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });

    testWidgets('compact mode hides some details', (tester) async {
      await tester.pumpWidget(buildCard(course: verifiedCourse, compact: true));
      // Address should not be visible in compact mode
      expect(find.text('Hanoi, Vietnam'), findsNothing);
    });
  });
}
