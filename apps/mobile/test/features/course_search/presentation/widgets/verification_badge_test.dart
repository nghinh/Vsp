// Verification Badge Tests — VSP Mobile App
//
// Widget tests for VerificationBadge widget.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/features/course_search/presentation/widgets/verification_badge.dart';
import 'package:vsp_mobile/domain/models/data_freshness.dart';
import 'package:vsp_mobile/core/locale/locale_cubit.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

void main() {
  group('VerificationBadge', () {
    Widget buildBadge(VerificationStatus status, {bool compact = false}) {
      return MaterialApp(
        locale: const Locale('en'),
      supportedLocales: kSupportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: VspTheme.light(),
        home: Scaffold(
          body: Center(
            child: VerificationBadge(
              status: status,
              compact: compact,
            ),
          ),
        ),
      );
    }

    testWidgets('VERIFIED shows Verified label', (tester) async {
      await tester.pumpWidget(buildBadge(VerificationStatus.verified));
      expect(find.text('Verified'), findsOneWidget);
    });

    testWidgets('VERIFIED shows verified icon', (tester) async {
      await tester.pumpWidget(buildBadge(VerificationStatus.verified));
      expect(find.byIcon(Icons.verified), findsOneWidget);
    });

    testWidgets('PENDING_REVIEW shows Pending label', (tester) async {
      await tester.pumpWidget(buildBadge(VerificationStatus.pendingReview));
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('UNVERIFIED shows Unverified label', (tester) async {
      await tester.pumpWidget(buildBadge(VerificationStatus.unverified));
      expect(find.text('Unverified'), findsOneWidget);
    });

    testWidgets('REJECTED shows Rejected label', (tester) async {
      await tester.pumpWidget(buildBadge(VerificationStatus.rejected));
      expect(find.text('Rejected'), findsOneWidget);
    });

    testWidgets('compact mode renders smaller', (tester) async {
      await tester.pumpWidget(buildBadge(VerificationStatus.verified, compact: true));
      final container = tester.widget<Container>(find.byType(Container).first);
      final padding = container.padding as EdgeInsets;
      expect(padding.horizontal, lessThan(16)); // compact has smaller padding
    });
  });
}
