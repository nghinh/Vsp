// Location Quality — VSP Mobile App
//
// Story 6.1: Acquire and Qualify Location
// AC2: Accuracy above 10m or stale positions trigger warning state.
//
// Quality classification for GPS fix: ready, lowAccuracy, stale, unavailable.
// Displayed in the UI as semantic color + icon (per UX spec §4.2 state colors).

import 'package:equatable/equatable.dart';
import 'qualified_location.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

/// GPS quality classification for UI display.
///
/// Maps to UX spec §4.2 state colors:
/// - ready: accent green
/// - lowAccuracy: amber/orange warning
/// - stale: red/gray with explicit label
/// - unavailable: red/gray with explicit label
enum LocationQuality {
  /// Fix is recent (<5s) and accurate (≤10m). Safe for auto-hole switch.
  ready,

  /// Fix is recent but accuracy >10m. Show amber warning.
  lowAccuracy,

  /// Fix is stale (age >5s) regardless of accuracy. Show stale warning.
  stale,

  /// No GPS fix available at all.
  unavailable,
}

/// A warning condition detected in a QualifiedLocation.
///
/// Carries the quality level, a human-readable message, and whether
/// the warning should block auto-hole switching (per AC2).
class LocationWarning extends Equatable {
  /// The quality level this warning corresponds to.
  final LocationQuality quality;

  /// Short warning title for display.
  final String title;

  /// Detailed message explaining the warning.
  final String message;

  /// If true, features relying on this location (auto-hole switch) should
  /// be blocked until the warning clears.
  final bool blocksAutoAction;

  /// Numeric detail (age in seconds, accuracy in metres) for messages that
  /// interpolate a value; the UI formats it in the active locale.
  final String? detail;

  const LocationWarning({
    required this.quality,
    required this.title,
    required this.message,
    required this.blocksAutoAction,
    this.detail,
  });

  /// Builds a warning from QualifiedLocation.
  ///
  /// Returns null if hasWarning is false.
  factory LocationWarning.fromQualifiedLocation(QualifiedLocation loc) {
    if (loc.source == LocationSource.unavailable) {
      return const LocationWarning(
        quality: LocationQuality.unavailable,
        title: AppMessages.gpsUnavailable,
        message: AppMessages.gpsUnavailableMessage,
        blocksAutoAction: true,
      );
    }

    if (loc.isStale) {
      return LocationWarning(
        quality: LocationQuality.stale,
        title: AppMessages.gpsStale,
        message: AppMessages.gpsStaleMessage,
        detail: loc.ageSeconds >= 0 ? '${loc.ageSeconds}' : null,
        blocksAutoAction: true,
      );
    }

    if (loc.isLowAccuracy) {
      return LocationWarning(
        quality: LocationQuality.lowAccuracy,
        title: AppMessages.gpsLowAccuracy,
        message: AppMessages.gpsLowAccuracyMessage,
        detail: loc.accuracyMeters != null
            ? '${loc.accuracyMeters!.round()}'
            : null,
        blocksAutoAction: true,
      );
    }

    return const LocationWarning(
      quality: LocationQuality.ready,
      title: AppMessages.gpsReady,
      message: AppMessages.gpsReadyMessage,
      blocksAutoAction: false,
    );
  }

  /// True if this warning blocks auto-hole switching.
  bool get shouldBlockAutoSwitch => blocksAutoAction;

  @override
  List<Object?> get props => [quality, title, message, blocksAutoAction];
}
