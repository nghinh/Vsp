// Incomplete Data Warning Model Tests — VSP Mobile App
//
// Per Story 11.2: Deliver Driving Zone and Round Analytics.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/incomplete_data_warning.dart';

void main() {
  group('WarningSeverity', () {
    test('fromString returns correct enum for known values', () {
      expect(WarningSeverity.fromString('info'), WarningSeverity.info);
      expect(WarningSeverity.fromString('warning'), WarningSeverity.warning);
      expect(WarningSeverity.fromString('error'), WarningSeverity.error);
    });

    test('fromString returns info for null or unknown input', () {
      expect(WarningSeverity.fromString(null), WarningSeverity.info);
      expect(WarningSeverity.fromString('unknown'), WarningSeverity.info);
    });
  });

  group('InsufficientDataCategory', () {
    test('fromString returns correct enum for known values', () {
      expect(InsufficientDataCategory.fromString('totalShots'), InsufficientDataCategory.totalShots);
      expect(InsufficientDataCategory.fromString('clubShots'), InsufficientDataCategory.clubShots);
      expect(InsufficientDataCategory.fromString('holeShots'), InsufficientDataCategory.holeShots);
    });

    test('fromString returns totalShots for null or unknown input', () {
      expect(InsufficientDataCategory.fromString(null), InsufficientDataCategory.totalShots);
      expect(InsufficientDataCategory.fromString('unknown'), InsufficientDataCategory.totalShots);
    });
  });

  group('IncompleteDataWarning', () {
    test('isBlocking returns true only for error severity', () {
      expect(
        const IncompleteDataWarning(
          id: 'w1',
          severity: WarningSeverity.error,
          category: InsufficientDataCategory.totalShots,
          title: 'Test',
          message: 'Test message',
          requiredMinimum: 20,
          actualCount: 5,
          generatedAt: null,
        ).isBlocking,
        true,
      );
      expect(
        const IncompleteDataWarning(
          id: 'w2',
          severity: WarningSeverity.warning,
          category: InsufficientDataCategory.totalShots,
          title: 'Test',
          message: 'Test message',
          requiredMinimum: 20,
          actualCount: 5,
          generatedAt: null,
        ).isBlocking,
        false,
      );
    });

    test('shortageRatio calculates correctly', () {
      final warning = IncompleteDataWarning(
        id: 'w1',
        category: InsufficientDataCategory.totalShots,
        title: 'Test',
        message: 'Test message',
        requiredMinimum: 20,
        actualCount: 10,
        generatedAt: DateTime.now(),
      );
      // shortageRatio = (requiredMinimum - actualCount) / requiredMinimum
      expect(warning.shortageRatio, 0.5);
    });

    test('shortageRatio returns 1.0 when requiredMinimum is 0', () {
      final warning = IncompleteDataWarning(
        id: 'w1',
        category: InsufficientDataCategory.totalShots,
        title: 'Test',
        message: 'Test message',
        requiredMinimum: 0,
        actualCount: 0,
        generatedAt: DateTime.now(),
      );
      expect(warning.shortageRatio, 1.0);
    });

    test('toJson and fromJson round-trip correctly', () {
      final original = IncompleteDataWarning(
        id: 'w1',
        severity: WarningSeverity.warning,
        category: InsufficientDataCategory.clubShots,
        title: 'Limited Club Data',
        message: 'Only 3 shots recorded.',
        requiredMinimum: 20,
        actualCount: 3,
        recommendedAction: 'Use this club more often.',
        generatedAt: DateTime(2025, 8, 1),
        context: 'driver',
      );
      final json = original.toJson();
      final restored = IncompleteDataWarning.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.severity, original.severity);
      expect(restored.category, original.category);
      expect(restored.title, original.title);
      expect(restored.actualCount, original.actualCount);
      expect(restored.context, original.context);
    });
  });

  group('IncompleteDataWarning factory methods', () {
    test('forTotalShots creates correct warning with error severity when actualCount is 0', () {
      final warning = IncompleteDataWarning.forTotalShots(
        requiredMinimum: 20,
        actualCount: 0,
        generatedAt: DateTime(2025, 8, 1),
      );
      expect(warning.severity, WarningSeverity.error);
      expect(warning.category, InsufficientDataCategory.totalShots);
      expect(warning.title, 'Insufficient Shot Data');
      expect(warning.actualCount, 0);
      expect(warning.requiredMinimum, 20);
    });

    test('forTotalShots creates warning with warning severity when actualCount > 0', () {
      final warning = IncompleteDataWarning.forTotalShots(
        requiredMinimum: 20,
        actualCount: 5,
        generatedAt: DateTime(2025, 8, 1),
      );
      expect(warning.severity, WarningSeverity.warning);
    });

    test('forClubShots includes clubName in message', () {
      final warning = IncompleteDataWarning.forClubShots(
        clubId: 'driver',
        clubName: 'Driver',
        requiredMinimum: 20,
        actualCount: 3,
        generatedAt: DateTime(2025, 8, 1),
      );
      expect(warning.category, InsufficientDataCategory.clubShots);
      expect(warning.context, 'driver');
      expect(warning.message, contains('Driver'));
    });

    test('forHoleShots includes hole number in message', () {
      final warning = IncompleteDataWarning.forHoleShots(
        holeNumber: 5,
        requiredMinimum: 10,
        actualCount: 2,
        generatedAt: DateTime(2025, 8, 1),
      );
      expect(warning.category, InsufficientDataCategory.holeShots);
      expect(warning.message, contains('Hole 5'));
    });
  });
}
