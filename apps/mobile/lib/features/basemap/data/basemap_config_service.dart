// Basemap Configuration — VSP Mobile App
//
// Where the satellite imagery provider comes from at runtime.
//
// ─── Why this exists ─────────────────────────────────────────────────────────
//
// SatelliteImageryConfig reads its provider from --dart-define values compiled
// into the binary. That is a sound design for a secret, and it is also why no
// build that has ever existed shows imagery: nothing in this repository passes
// the defines, and a define cannot be changed for an app already installed on a
// golfer's phone. Turning satellite on for a pilot meant shipping a release;
// turning it off after a billing surprise meant shipping another.
//
// The API now serves the same three values, so the provider is an operational
// setting with a revocation path. The build-time defines still win when
// present — a binary built with an explicit provider is an explicit decision,
// and a server should not quietly override it.
//
// ─── What is cached, and what is not ─────────────────────────────────────────
//
// The configuration is cached so the app knows its provider before the first
// network round trip, and on a course with no signal. Tiles are NOT cached:
// Mapbox's terms forbid permanent offline caching, so satellite stays an online
// feature that degrades to a stated "no imagery" rather than pretending.
//
// The cache holds a Mapbox public token (`pk.`). That is a client-distributed
// credential by design — it was already shipped inside the APK before this —
// and the server refuses to hand out a secret (`sk.`) one.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../domain/satellite_imagery_config.dart';

/// The three inputs an imagery provider is resolved from.
class BasemapConfigValues {
  final String mapboxAccessToken;
  final String satelliteTileUrl;
  final String satelliteAttribution;

  /// Deepest zoom the operator's endpoint serves. Null means "assume deep".
  final int? satelliteMaxZoom;

  const BasemapConfigValues({
    this.mapboxAccessToken = '',
    this.satelliteTileUrl = '',
    this.satelliteAttribution = '',
    this.satelliteMaxZoom,
  });

  static const BasemapConfigValues none = BasemapConfigValues();

  bool get isEmpty =>
      mapboxAccessToken.isEmpty &&
      (satelliteTileUrl.isEmpty || satelliteAttribution.isEmpty);

  factory BasemapConfigValues.fromJson(Map<String, dynamic> json) =>
      BasemapConfigValues(
        mapboxAccessToken: (json['mapboxAccessToken'] as String?)?.trim() ?? '',
        satelliteTileUrl: (json['satelliteTileUrl'] as String?)?.trim() ?? '',
        satelliteAttribution:
            (json['satelliteAttribution'] as String?)?.trim() ?? '',
        satelliteMaxZoom: (json['satelliteMaxZoom'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
    'mapboxAccessToken': mapboxAccessToken,
    'satelliteTileUrl': satelliteTileUrl,
    'satelliteAttribution': satelliteAttribution,
    if (satelliteMaxZoom != null) 'satelliteMaxZoom': satelliteMaxZoom,
  };

  /// Turns these values into a resolved provider.
  ///
  /// Reuses [SatelliteImageryConfig.resolve] rather than repeating it, so the
  /// server path inherits the same rules — including the refusal to display
  /// operator imagery that arrives without attribution.
  SatelliteImageryConfig resolve() => SatelliteImageryConfig.resolve(
    mapboxAccessToken: mapboxAccessToken,
    customTileUrl: satelliteTileUrl,
    customAttribution: satelliteAttribution,
    customMaxZoom: satelliteMaxZoom,
  );
}

/// Fetches and caches the imagery configuration.
class BasemapConfigService {
  static const String _cacheKey = 'vsp.basemap.config.v1';

  final ApiClient _apiClient;
  final Future<SharedPreferences> Function() _preferences;

  BasemapConfigService({
    ApiClient? apiClient,
    Future<SharedPreferences> Function()? preferences,
  }) : _apiClient = apiClient ?? ApiClient(),
       _preferences = preferences ?? SharedPreferences.getInstance;

  /// Last configuration this device was told about, or null when never told.
  Future<BasemapConfigValues?> cached() async {
    try {
      final stored = (await _preferences()).getString(_cacheKey);
      if (stored == null) return null;
      return BasemapConfigValues.fromJson(
        jsonDecode(stored) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Asks the server which provider to use, and remembers the answer.
  ///
  /// Returns the cached value on any failure. A golfer opening the app on the
  /// first tee with no signal keeps whatever imagery they had yesterday rather
  /// than losing it to a timeout.
  Future<BasemapConfigValues?> refresh() async {
    try {
      final response = await _apiClient.request(
        path: '/config/basemap',
        method: HttpMethod.get,
      );
      if (response is! Map<String, dynamic>) return cached();

      final values = BasemapConfigValues.fromJson(response);
      final preferences = await _preferences();
      if (values.isEmpty) {
        // An operator who switched imagery off must have it go off here too,
        // otherwise a revoked token keeps being requested from every device
        // that ever cached one.
        await preferences.remove(_cacheKey);
        return values;
      }
      await preferences.setString(_cacheKey, jsonEncode(values.toJson()));
      return values;
    } catch (_) {
      return cached();
    }
  }
}

/// The imagery provider the app is currently using.
///
/// Widgets read this synchronously while building, so the resolved value is
/// held here rather than threaded through every map screen. [load] is called
/// once at start-up and again after sign-in.
abstract final class SatelliteImagery {
  /// The provider in force, as something a widget can listen to.
  ///
  /// Listenable rather than a plain value because it arrives late. The config
  /// is fetched after sign-in, so a golfer who reaches the map first held a
  /// screen built from "no imagery" and kept it — the map read the provider
  /// once, into a `late final`, and never looked again. An operator who pasted
  /// a token saw nothing change until the app was restarted, which defeats the
  /// point of moving the provider off a build-time define.
  static final ValueNotifier<SatelliteImageryConfig> listenable =
      ValueNotifier<SatelliteImageryConfig>(
        SatelliteImageryConfig.fromEnvironment(),
      );

  static SatelliteImageryConfig get _current => listenable.value;

  static set _current(SatelliteImageryConfig config) {
    // ValueNotifier compares by identity for non-equal types;
    // SatelliteImageryConfig is Equatable, so an unchanged fetch is a no-op and
    // does not churn every map on screen.
    listenable.value = config;
  }

  /// Provider in force right now. Never null; [SatelliteImageryConfig.unavailable]
  /// when nothing is configured, which the map states plainly.
  static SatelliteImageryConfig get current => listenable.value;

  /// True when this binary was built with an explicit provider.
  static bool get isFixedByBuild =>
      SatelliteImageryConfig.fromEnvironment().isAvailable;

  /// Resolves the provider from the cache, then from the server.
  ///
  /// Never throws: imagery is an enhancement, and failing to configure it must
  /// not stop the app from starting.
  static Future<void> load(BasemapConfigService service) async {
    if (isFixedByBuild) {
      // A binary built with a provider carries a deliberate decision — an
      // operator's own licensed orthophotos, say. The server does not get to
      // silently replace it.
      return;
    }
    try {
      final cached = await service.cached();
      if (cached != null) {
        _current = cached.resolve();
      }
      final fresh = await service.refresh();
      if (fresh != null) {
        _current = fresh.resolve();
      }
    } catch (_) {
      // Leave whatever we had. Unavailable is a state the map handles.
    }
  }

  /// Test seam. Restores the build-time value when passed null.
  static void overrideForTesting(SatelliteImageryConfig? config) {
    _current = config ?? SatelliteImageryConfig.fromEnvironment();
  }
}
