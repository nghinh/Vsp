// Data Quality Badge Widget Tests — VSP Mobile App

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/data_quality.dart';
import 'package:vsp_mobile/domain/models/data_freshness.dart';
import 'package:vsp_mobile/features/course_detail/presentation/widgets/data_quality_badge.dart';
import 'package:vsp_mobile/core/locale/locale_cubit.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

void main() {
  Widget buildBadge({DataQuality? dataQuality, bool compact = false}) {
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: kSupportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: DataQualityBadge(
          dataQuality: dataQuality,
          compact: compact,
        ),
      ),
    );
  }

  group('DataQualityBadge', () {
    testWidgets('renders Official badge for official data quality', (tester) async {
      final dq = DataQuality.fromJson({
        'publishedAt': '2026-08-01T00:00:00.000Z',
        'versionNumber': 1,
        'verificationStatus': 'VERIFIED',
        'accuracyClass': 'A',
      });

      await tester.pumpWidget(buildBadge(dataQuality: dq));
      expect(find.text('Official'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);
    });

    testWidgets('renders Estimated badge for Class C', (tester) async {
      final dq = DataQuality.fromJson({
        'publishedAt': '2026-08-01T00:00:00.000Z',
        'versionNumber': 1,
        'verificationStatus': 'VERIFIED',
        'accuracyClass': 'C',
      });

      await tester.pumpWidget(buildBadge(dataQuality: dq));
      expect(find.text('Estimated'), findsOneWidget);
      expect(find.byIcon(Icons.pending), findsOneWidget);
    });

    testWidgets('renders Community badge for Class D', (tester) async {
      final dq = DataQuality.fromJson({
        'publishedAt': '2026-08-01T00:00:00.000Z',
        'versionNumber': 1,
        'verificationStatus': 'VERIFIED',
        'accuracyClass': 'D',
      });

      await tester.pumpWidget(buildBadge(dataQuality: dq));
      expect(find.text('Community'), findsOneWidget);
      expect(find.byIcon(Icons.groups), findsOneWidget);
    });

    testWidgets('renders Stale badge for stale data', (tester) async {
      final dq = DataQuality.fromJson({
        'publishedAt': '2020-01-01T00:00:00.000Z',
        'versionNumber': 1,
        'verificationStatus': 'VERIFIED',
        'accuracyClass': 'A',
      });

      await tester.pumpWidget(buildBadge(dataQuality: dq));
      expect(find.text('Stale'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    });

    testWidgets('renders Unknown when dataQuality is null', (tester) async {
      await tester.pumpWidget(buildBadge(dataQuality: null));
      expect(find.text('Unknown'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline), findsOneWidget);
    });

    testWidgets('compact mode renders with smaller padding', (tester) async {
      final dq = DataQuality.fromJson({
        'publishedAt': '2026-08-01T00:00:00.000Z',
        'versionNumber': 1,
        'verificationStatus': 'VERIFIED',
        'accuracyClass': 'A',
      });

      // Should not throw in compact mode
      await tester.pumpWidget(buildBadge(dataQuality: dq, compact: true));
      expect(find.text('Official'), findsOneWidget);
    });

    testWidgets('Semantics label is set correctly for official', (tester) async {
      final dq = DataQuality.fromJson({
        'publishedAt': '2026-08-01T00:00:00.000Z',
        'versionNumber': 1,
        'verificationStatus': 'VERIFIED',
        'accuracyClass': 'A',
      });

      await tester.pumpWidget(buildBadge(dataQuality: dq));
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Official verified data',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Semantics label is set correctly for unknown', (tester) async {
      await tester.pumpWidget(buildBadge(dataQuality: null));
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Data quality unknown',
        ),
        findsOneWidget,
      );
    });
  });
}
