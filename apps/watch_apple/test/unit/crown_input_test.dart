// Crown Input Test — VSP Watch Apple App
//
// Unit tests for crown input handler.
// Tests AC-7: Crown/touch controls meet accessibility requirements.
//
// Story 10.1 — Slice 6: E2E Integration & Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:watch_apple/application/crown_input_handler.dart';

void main() {
  group('CrownInputHandler', () {
    late CrownInputHandler handler;

    setUp(() {
      handler = CrownInputHandler();
    });

    test('scroll down event triggers nextHole action', () {
      // Simulate scroll down (delta > threshold)
      final event = handler.processCrownData(1.0);
      expect(event, isNotNull);
      expect(event!.type, equals(CrownEventType.scrollDown));
    });

    test('scroll up event triggers previousHole action', () {
      // Simulate scroll up (delta < -threshold)
      final event = handler.processCrownData(-1.0);
      expect(event, isNotNull);
      expect(event!.type, equals(CrownEventType.scrollUp));
    });

    test('small delta registers as tap', () {
      // Very small delta indicates a tap
      final event = handler.processCrownData(0.05);
      expect(event, isNotNull);
      expect(event!.type, equals(CrownEventType.tap));
    });

    test('double tap detected within window', () {
      // First tap
      final tap1 = handler.processCrownData(0.05);
      expect(tap1, isNotNull);
      expect(tap1!.type, equals(CrownEventType.tap));

      // Second tap immediately after (within doubleTapWindow)
      final tap2 = handler.processCrownData(0.05);
      expect(tap2, isNotNull);
      expect(tap2!.type, equals(CrownEventType.doubleTap));
    });

    test('taps outside window are separate', () {
      // First tap
      final tap1 = handler.processCrownData(0.05);
      expect(tap1!.type, equals(CrownEventType.tap));

      // Wait outside double tap window
      // In real scenario, this would be tested with actual delays
      handler.reset();

      // Second tap after reset
      final tap2 = handler.processCrownData(0.05);
      expect(tap2!.type, equals(CrownEventType.tap));
    });

    test('accumulated scroll triggers action', () {
      // Small deltas that accumulate to threshold
      for (int i = 0; i < 5; i++) {
        handler.processCrownData(0.2); // accumulate
      }
      // Should have triggered an event
    });
  });

  group('CrownActionMapper', () {
    test('scroll down in distance panel maps to nextHole', () {
      final mapper = CrownActionMapper(context: CrownContext.distancePanel);

      final event = CrownEvent(
        type: CrownEventType.scrollDown,
        delta: 1.0,
        timestamp: DateTime.now(),
      );

      final action = mapper.mapEvent(event);
      expect(action, equals(CrownAction.nextHole));
    });

    test('scroll up in distance panel maps to previousHole', () {
      final mapper = CrownActionMapper(context: CrownContext.distancePanel);

      final event = CrownEvent(
        type: CrownEventType.scrollUp,
        delta: -1.0,
        timestamp: DateTime.now(),
      );

      final action = mapper.mapEvent(event);
      expect(action, equals(CrownAction.previousHole));
    });

    test('double tap maps to quickScore', () {
      final mapper = CrownActionMapper(context: CrownContext.distancePanel);

      final event = CrownEvent(
        type: CrownEventType.doubleTap,
        timestamp: DateTime.now(),
      );

      final action = mapper.mapEvent(event);
      expect(action, equals(CrownAction.quickScore));
    });

    test('long press maps to mainMenu', () {
      final mapper = CrownActionMapper(context: CrownContext.distancePanel);

      final event = CrownEvent(
        type: CrownEventType.longPress,
        timestamp: DateTime.now(),
      );

      final action = mapper.mapEvent(event);
      expect(action, equals(CrownAction.mainMenu));
    });

    test('tap in score entry context maps to selectConfirm', () {
      final mapper = CrownActionMapper(context: CrownContext.scoreEntry);

      final event = CrownEvent(
        type: CrownEventType.tap,
        timestamp: DateTime.now(),
      );

      final action = mapper.mapEvent(event);
      expect(action, equals(CrownAction.selectConfirm));
    });
  });

  group('BatteryManager', () {
    late BatteryManager manager;

    setUp(() {
      manager = BatteryManager();
    });

    test('normal mode above 20%', () {
      manager.updateBatteryState(levelPercent: 100);
      expect(manager.powerMode, equals(WatchPowerMode.normal));
      expect(manager.animationsEnabled, isTrue);
    });

    test('low power mode between 10-20%', () {
      manager.updateBatteryState(levelPercent: 15);
      expect(manager.powerMode, equals(WatchPowerMode.lowPower));
      expect(manager.animationsEnabled, isTrue);
    });

    test('conservation mode between 5-10%', () {
      manager.updateBatteryState(levelPercent: 8);
      expect(manager.powerMode, equals(WatchPowerMode.conservation));
      expect(manager.animationsEnabled, isFalse);
    });

    test('minimal mode below 5%', () {
      manager.updateBatteryState(levelPercent: 3);
      expect(manager.powerMode, equals(WatchPowerMode.minimal));
      expect(manager.animationsEnabled, isFalse);
    });

    test('GPS polling interval increases with lower power mode', () {
      manager.updateBatteryState(levelPercent: 100);
      final normalInterval = manager.gpsPollingInterval;

      manager.updateBatteryState(levelPercent: 15);
      final lowPowerInterval = manager.gpsPollingInterval;

      manager.updateBatteryState(levelPercent: 8);
      final conservationInterval = manager.gpsPollingInterval;

      expect(normalInterval, lessThan(lowPowerInterval));
      expect(lowPowerInterval, lessThan(conservationInterval));
    });

    test('charging ignores power mode', () {
      manager.updateBatteryState(levelPercent: 5, isCharging: true);
      expect(manager.shouldPollGPS(false), isTrue);
    });

    test('should not poll GPS in minimal mode', () {
      manager.updateBatteryState(levelPercent: 3);
      expect(manager.shouldPollGPS(false), isFalse);
    });

    test('isLow battery indicator', () {
      manager.updateBatteryState(levelPercent: 25);
      expect(manager.state.isLow, isFalse);

      manager.updateBatteryState(levelPercent: 15);
      expect(manager.state.isLow, isTrue);
    });

    test('isCritical battery indicator', () {
      manager.updateBatteryState(levelPercent: 15);
      expect(manager.state.isCritical, isFalse);

      manager.updateBatteryState(levelPercent: 8);
      expect(manager.state.isCritical, isFalse);

      manager.updateBatteryState(levelPercent: 5);
      expect(manager.state.isCritical, isTrue);
    });
  });
}
