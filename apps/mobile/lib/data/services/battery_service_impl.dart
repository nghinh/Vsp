// Battery Service Implementation — VSP Mobile App
//
// battery_plus behind the domain's BatteryService port.

import 'package:battery_plus/battery_plus.dart' as plugin;

import '../../domain/services/battery_service.dart';

/// Reads the device battery through `battery_plus`.
class BatteryServiceImpl implements BatteryService {
  final plugin.Battery _battery;

  BatteryServiceImpl({plugin.Battery? battery})
    : _battery = battery ?? plugin.Battery();

  @override
  Future<BatterySample> read() async {
    try {
      // Three separate platform calls; asked for together so the reading is
      // one moment in time rather than three.
      final results = await Future.wait([
        _battery.batteryLevel,
        _battery.batteryState,
        _battery.isInBatterySaveMode,
      ]);

      final percent = results[0] as int;
      return BatterySample(
        // The plugin answers a percentage and the telemetry models validate a
        // 0–1 fraction; a platform that answers out of range is clamped rather
        // than allowed to write a row that fails its own validator.
        level: (percent / 100).clamp(0.0, 1.0),
        status: _status(results[1] as plugin.BatteryState),
        saverActive: results[2] as bool,
      );
    } catch (_) {
      // Every caller here is recording telemetry. A platform channel that is
      // absent (widget tests, desktop hosts) or that throws is a reason to
      // record less, never a reason to interrupt a round.
      return BatterySample.unknown;
    }
  }

  static BatteryStatus _status(plugin.BatteryState state) {
    switch (state) {
      case plugin.BatteryState.charging:
        return BatteryStatus.charging;
      case plugin.BatteryState.discharging:
        return BatteryStatus.discharging;
      case plugin.BatteryState.full:
        return BatteryStatus.full;
      case plugin.BatteryState.connectedNotCharging:
        return BatteryStatus.connectedNotCharging;
      case plugin.BatteryState.unknown:
        return BatteryStatus.unknown;
    }
  }
}
