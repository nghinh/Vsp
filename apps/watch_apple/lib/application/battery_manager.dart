// Battery Manager — VSP Watch Apple App
//
// Battery-aware behavior for watch app.
// AC-7: Battery requirements met through adaptive polling and animations.
//
// Story 10.1 — Slice 5: Crown/Touch & Accessibility

import 'dart:async';
import 'package:equatable/equatable.dart';

/// Battery state for the watch.
class WatchBatteryState extends Equatable {
  final int levelPercent;
  final bool isCharging;
  final WatchPowerMode powerMode;

  const WatchBatteryState({
    required this.levelPercent,
    this.isCharging = false,
    this.powerMode = WatchPowerMode.normal,
  });

  bool get isLow => levelPercent <= 20;
  // Critical == last-gasp / minimal band (see BatteryManager._minimalThreshold).
  bool get isCritical => levelPercent <= 5;

  @override
  List<Object?> get props => [levelPercent, isCharging, powerMode];
}

/// Power mode based on battery level.
enum WatchPowerMode {
  /// Full functionality - GPS polling at normal rate, animations enabled.
  normal,

  /// Reduced GPS polling, simplified animations.
  lowPower,

  /// Minimal GPS updates, no animations, essential UI only.
  conservation,

  /// Last-gasp mode - display only, no active sensing.
  minimal,
}

/// Battery-aware manager for watch resources.
///
/// Monitors battery level and adjusts app behavior:
/// - Normal (100-20%): Full GPS polling, animations, live updates
/// - Low Power (20-10%): Reduced GPS polling, simpler animations
/// - Conservation (10-5%): GPS on-demand only, no animations
/// - Minimal (<5%): Display-only mode
class BatteryManager {
  static const int _lowThreshold = 20;
  static const int _conservationThreshold = 10;
  static const int _minimalThreshold = 5;

  WatchBatteryState _state = const WatchBatteryState(levelPercent: 100);

  /// Current battery state.
  WatchBatteryState get state => _state;

  /// Current power mode based on battery level.
  WatchPowerMode get powerMode => _state.powerMode;

  /// GPS polling interval based on power mode.
  Duration get gpsPollingInterval {
    switch (_state.powerMode) {
      case WatchPowerMode.normal:
        return const Duration(seconds: 5);
      case WatchPowerMode.lowPower:
        return const Duration(seconds: 15);
      case WatchPowerMode.conservation:
        return const Duration(seconds: 30);
      case WatchPowerMode.minimal:
        return const Duration(minutes: 5);
    }
  }

  /// Whether animations should be enabled.
  bool get animationsEnabled =>
      _state.powerMode == WatchPowerMode.normal ||
      _state.powerMode == WatchPowerMode.lowPower;

  /// Animation duration multiplier (1.0 = normal, 0.5 = half speed).
  double get animationDurationMultiplier {
    switch (_state.powerMode) {
      case WatchPowerMode.normal:
        return 1.0;
      case WatchPowerMode.lowPower:
        return 0.5;
      case WatchPowerMode.conservation:
        return 0.25;
      case WatchPowerMode.minimal:
        return 0.0;
    }
  }

  /// Update battery state from platform.
  void updateBatteryState({
    required int levelPercent,
    bool isCharging = false,
  }) {
    final newMode = _computePowerMode(levelPercent);

    _state = WatchBatteryState(
      levelPercent: levelPercent,
      isCharging: isCharging,
      powerMode: newMode,
    );
  }

  WatchPowerMode _computePowerMode(int level) {
    if (level <= _minimalThreshold) return WatchPowerMode.minimal;
    if (level <= _conservationThreshold) return WatchPowerMode.conservation;
    if (level <= _lowThreshold) return WatchPowerMode.lowPower;
    return WatchPowerMode.normal;
  }

  /// Check if GPS should be actively polling.
  bool shouldPollGPS(bool isStationary) {
    if (_state.isCharging) return true;

    switch (_state.powerMode) {
      case WatchPowerMode.normal:
        return true;
      case WatchPowerMode.lowPower:
        return !isStationary;
      case WatchPowerMode.conservation:
        return false; // GPS on-demand only
      case WatchPowerMode.minimal:
        return false;
    }
  }

  /// Get human-readable battery description.
  String getBatteryDescription() {
    if (_state.isCharging) {
      return 'Charging (${_state.levelPercent}%)';
    }

    switch (_state.powerMode) {
      case WatchPowerMode.normal:
        return '${_state.levelPercent}%';
      case WatchPowerMode.lowPower:
        return 'Low Power (${_state.levelPercent}%)';
      case WatchPowerMode.conservation:
        return 'Conservation (${_state.levelPercent}%)';
      case WatchPowerMode.minimal:
        return 'Minimal (${_state.levelPercent}%)';
    }
  }
}
