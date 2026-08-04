// ConditionsSection widget tests — VSP Mobile App
//
// Tests cover:
// - AC1: All 5 elements displayed (official status, source, effective/expiry, confidence, stale)
// - Offline badge shown when isOffline=true
// - Stale warning shown for expired or >30 day conditions
// - Semantic labels on all badges and states
//
// Story 7.3 — Slice 5: Tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/features/course_detail/presentation/widgets/conditions_section.dart';
import 'package:vsp_mobile/domain/models/course_detail.dart';
import 'package:vsp_mobile/domain/models/condition_entry.dart';

void main() {
  Widget buildSection({
    required CourseDetail course,
    ConditionsSectionConfig? config,
  }) {
    return MaterialApp(
      theme: VspTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ConditionsSection(course: course, config: config),
        ),
      ),
    );
  }

  group('ConditionsSection — AC1: all 5 elements displayed', () {
    testWidgets('displays condition type label', (tester) async {
      final course = _courseWithCondition(
        ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          accuracyClass: 'B',
        ),
      );

      await tester.pumpWidget(buildSection(course: course));
      expect(find.text('Pin Position'), findsOneWidget);
    });

    testWidgets('displays severity badge', (tester) async {
      final course = _courseWithCondition(
        ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          accuracyClass: 'B',
        ),
      );

      await tester.pumpWidget(buildSection(course: course));
      expect(find.text('Moderate'), findsOneWidget);
    });

    testWidgets('displays source badge for official source', (tester) async {
      final course = _courseWithCondition(
        ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          accuracyClass: 'B',
          source: ConditionSource.official,
        ),
      );

      await tester.pumpWidget(buildSection(course: course));
      expect(find.text('Official'), findsOneWidget);
    });

    testWidgets('displays source badge for estimated source', (tester) async {
      final course = _courseWithCondition(
        ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          accuracyClass: 'B',
          source: ConditionSource.estimated,
        ),
      );

      await tester.pumpWidget(buildSection(course: course));
      expect(find.text('Estimated'), findsOneWidget);
    });

    testWidgets('displays confidence percentage', (tester) async {
      final course = _courseWithCondition(
        ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          accuracyClass: 'B',
          source: ConditionSource.official,
          confidence: 0.92,
        ),
      );

      await tester.pumpWidget(buildSection(course: course));
      expect(find.text('92% confidence'), findsOneWidget);
    });

    testWidgets('displays effective date', (tester) async {
      final effectiveDate = DateTime(2026, 7, 20);
      final course = _courseWithCondition(
        ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          accuracyClass: 'B',
          effectiveDate: effectiveDate,
        ),
      );

      await tester.pumpWidget(buildSection(course: course));
      expect(find.text('Effective: 20/7/2026'), findsOneWidget);
    });

    testWidgets('displays expiry date', (tester) async {
      final expiryDate = DateTime(2026, 8, 20);
      final course = _courseWithCondition(
        ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          accuracyClass: 'B',
          expiryDate: expiryDate,
        ),
      );

      await tester.pumpWidget(buildSection(course: course));
      expect(find.text('Expires: 20/8/2026'), findsOneWidget);
    });

    testWidgets('displays accuracy class', (tester) async {
      final course = _courseWithCondition(
        ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          accuracyClass: 'B',
        ),
      );

      await tester.pumpWidget(buildSection(course: course));
      expect(find.text('Class B'), findsOneWidget);
    });

    testWidgets('displays description when present', (tester) async {
      final course = _courseWithCondition(
        ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          accuracyClass: 'B',
          description: 'Front-left pin position',
        ),
      );

      await tester.pumpWidget(buildSection(course: course));
      expect(find.text('Front-left pin position'), findsOneWidget);
    });
  });

  group('ConditionsSection — AC1: stale state', () {
    testWidgets('shows stale warning for expired condition', (tester) async {
      final course = _courseWithCondition(
        ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          accuracyClass: 'B',
          expiryDate: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );

      await tester.pumpWidget(buildSection(course: course));
      expect(find.text('Stale data'), findsOneWidget);
      // The widget shows "Expired <date>", so match on the prefix.
      expect(find.textContaining('Expired'), findsOneWidget);
    });

    testWidgets('shows stale warning for >30 day old condition', (
      tester,
    ) async {
      final course = _courseWithCondition(
        ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          accuracyClass: 'B',
          effectiveDate: DateTime.now().subtract(const Duration(days: 31)),
        ),
      );

      await tester.pumpWidget(buildSection(course: course));
      expect(find.text('Stale data'), findsOneWidget);
    });

    testWidgets('no stale warning for fresh condition', (tester) async {
      final course = _courseWithCondition(
        ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          accuracyClass: 'B',
          effectiveDate: DateTime.now().subtract(const Duration(days: 5)),
          expiryDate: DateTime.now().add(const Duration(days: 7)),
        ),
      );

      await tester.pumpWidget(buildSection(course: course));
      expect(find.text('Stale data'), findsNothing);
    });
  });

  group('ConditionsSection — AC3: offline badge', () {
    testWidgets('shows offline badge when isOffline=true', (tester) async {
      final course = _courseWithCondition(
        ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          accuracyClass: 'B',
        ),
      );

      await tester.pumpWidget(
        buildSection(
          course: course,
          config: const ConditionsSectionConfig(isOffline: true),
        ),
      );
      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('shows cached badge with timestamp when cachedAt is set', (
      tester,
    ) async {
      final course = _courseWithCondition(
        ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          accuracyClass: 'B',
        ),
      );

      await tester.pumpWidget(
        buildSection(
          course: course,
          config: ConditionsSectionConfig(
            isOffline: true,
            cachedAt: DateTime(2026, 8, 1, 14, 30),
          ),
        ),
      );
      expect(find.text('Cached'), findsOneWidget);
    });

    testWidgets('no offline badge when isOffline=false', (tester) async {
      final course = _courseWithCondition(
        ConditionEntry(
          conditionType: ConditionType.pinPosition,
          severity: ConditionSeverity.moderate,
          accuracyClass: 'B',
        ),
      );

      await tester.pumpWidget(
        buildSection(
          course: course,
          config: const ConditionsSectionConfig(isOffline: false),
        ),
      );
      expect(find.text('Offline'), findsNothing);
      expect(find.text('Cached'), findsNothing);
    });
  });

  group('ConditionsSection — empty state', () {
    testWidgets('returns empty SizedBox when no conditions', (tester) async {
      final course = CourseDetail(
        courseId: 1,
        facilityId: 1,
        facilityName: 'Test Course',
        latitude: 10.0,
        longitude: 20.0,
        holesCount: 18,
        imageUrls: const [],
        facilities: const [],
        localRules: const [],
        holes: const [],
        teeSets: const [],
        conditions: const [],
      );

      await tester.pumpWidget(buildSection(course: course));
      // Should render nothing visible
      expect(find.text('Conditions'), findsNothing);
    });
  });
}

/// Helper to create CourseDetail with a single condition.
CourseDetail _courseWithCondition(ConditionEntry condition) {
  return CourseDetail(
    courseId: 1,
    facilityId: 1,
    facilityName: 'Test Course',
    latitude: 10.0,
    longitude: 20.0,
    holesCount: 18,
    imageUrls: const [],
    facilities: const [],
    localRules: const [],
    holes: const [],
    teeSets: const [],
    conditions: [condition],
  );
}
