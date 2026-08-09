// Battery Service — VSP Mobile App
//
// Reads the device battery, for telemetry only.
//
// Story 6.6 asks whether a phone finishes 18 holes on one charge, and the GPS
// and map-latency records both carry the battery level at the moment they were
// taken — a 12 m fix at 80% battery and the same fix at 8% are different
// evidence. That is the whole reason this exists: nothing in the product
// behaviour reads it, and nothing should start to without a decision to make
// battery a first-class input.
//
// Behind an interface because the plugin is a platform channel: it answers
// nothing in a widget test and can throw on a desktop host, and telemetry is
// never worth failing a round over.

import 'package:equatable/equatable.dart';

/// How the battery is being used right now.
enum BatteryStatus {
  unknown,
  charging,
  discharging,
  full,
  connectedNotCharging,
}

/// One reading of the device battery.
class BatterySample extends Equatable {
  /// Charge remaining, 0.0–1.0.
  ///
  /// The telemetry models validate this range, so a platform that answers
  /// something else is clamped rather than allowed to write an invalid row.
  final double level;

  /// What the battery is doing.
  final BatteryStatus status;

  /// Whether the OS power-saving mode is on.
  ///
  /// Worth recording next to a GPS fix: power saving is exactly what throttles
  /// location updates, so a run of stale fixes with this true is explained.
  final bool saverActive;

  const BatterySample({
    required this.level,
    required this.status,
    required this.saverActive,
  });

  /// What to record when the device will not say.
  ///
  /// A level of zero would read as a flat battery, so this is deliberately
  /// paired with [BatteryStatus.unknown]: a reader that cares can tell the
  /// difference, and the row is still valid.
  static const BatterySample unknown = BatterySample(
    level: 0.0,
    status: BatteryStatus.unknown,
    saverActive: false,
  );

  /// True when this is the [unknown] placeholder rather than a real reading.
  bool get isUnknown => status == BatteryStatus.unknown;

  @override
  List<Object?> get props => [level, status, saverActive];
}

/// Reads the device battery.
abstract class BatteryService {
  /// Current battery reading, or [BatterySample.unknown] when unavailable.
  ///
  /// Implementations must not throw: every caller is recording telemetry, and
  /// a round must not fail because a battery plugin did.
  Future<BatterySample> read();
}
