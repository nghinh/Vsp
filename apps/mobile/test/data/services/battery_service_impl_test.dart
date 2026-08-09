// Unit tests for the battery_plus adapter.
//
// Small class, three jobs, and each one is a place where a wrong answer would
// be written into telemetry and believed later: convert the plugin's percent
// into the 0–1 fraction the telemetry models validate, map the plugin's states
// onto ours, and never throw.

import 'package:battery_plus_platform_interface/battery_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/data/services/battery_service_impl.dart';
import 'package:vsp_mobile/domain/services/battery_service.dart';

class _FakeBatteryPlatform extends BatteryPlatform {
  final int level;
  final BatteryState state;
  final bool saver;
  final bool throws;

  _FakeBatteryPlatform({
    this.level = 80,
    this.state = BatteryState.discharging,
    this.saver = false,
    this.throws = false,
  });

  @override
  Future<int> get batteryLevel async {
    if (throws) throw StateError('no battery service on this host');
    return level;
  }

  @override
  Future<BatteryState> get batteryState async {
    if (throws) throw StateError('no battery service on this host');
    return state;
  }

  @override
  Future<bool> get isInBatterySaveMode async {
    if (throws) throw StateError('no battery service on this host');
    return saver;
  }
}

void main() {
  final original = BatteryPlatform.instance;
  tearDown(() => BatteryPlatform.instance = original);

  test(
    'reports the charge as the fraction the telemetry models validate',
    () async {
      BatteryPlatform.instance = _FakeBatteryPlatform(level: 43, saver: true);

      final sample = await BatteryServiceImpl().read();

      expect(sample.level, closeTo(0.43, 1e-9));
      expect(sample.saverActive, isTrue);
      expect(sample.status, BatteryStatus.discharging);
      expect(sample.isUnknown, isFalse);
    },
  );

  test('clamps a platform that answers outside 0–100', () async {
    // Both telemetry models reject a level outside 0–1 in their own validator,
    // so a platform answering 120 would otherwise write rows that fail it.
    BatteryPlatform.instance = _FakeBatteryPlatform(level: 120);
    expect((await BatteryServiceImpl().read()).level, 1.0);

    BatteryPlatform.instance = _FakeBatteryPlatform(level: -5);
    expect((await BatteryServiceImpl().read()).level, 0.0);
  });

  test('maps every state the plugin can report', () async {
    const expected = {
      BatteryState.charging: BatteryStatus.charging,
      BatteryState.discharging: BatteryStatus.discharging,
      BatteryState.full: BatteryStatus.full,
      BatteryState.connectedNotCharging: BatteryStatus.connectedNotCharging,
      BatteryState.unknown: BatteryStatus.unknown,
    };

    for (final entry in expected.entries) {
      BatteryPlatform.instance = _FakeBatteryPlatform(state: entry.key);
      expect(
        (await BatteryServiceImpl().read()).status,
        entry.value,
        reason: entry.key.name,
      );
    }
  });

  test(
    'answers unknown instead of throwing when there is no battery service',
    () async {
      // Widget tests, desktop hosts, and any platform channel that is simply not
      // there. Telemetry is a diagnostic; it is never worth an exception.
      BatteryPlatform.instance = _FakeBatteryPlatform(throws: true);

      final sample = await BatteryServiceImpl().read();

      expect(sample, BatterySample.unknown);
      expect(sample.isUnknown, isTrue);
    },
  );
}
