// Satellite Imagery Configuration — VSP Mobile App
//
// Only 69 of ~900 holes have surveyed geometry. On the rest, a vector hole map
// draws almost nothing real. Satellite imagery is honest in a way our vector
// data is not: the picture under the golfer's finger is the actual course.
//
// ─── Imagery licensing ───────────────────────────────────────────────────────
//
// PROVIDER: Mapbox Satellite (tileset `mapbox.satellite`) served through the
// Mapbox Raster Tiles API.
//
// Why Mapbox and not Esri World Imagery:
//   • Esri's World Imagery layer on services.arcgisonline.com carries an
//     explicit restriction — Esri state the service "is not available for
//     commercial use" and "can only be used with an ArcGIS Online or ArcGIS
//     Enterprise license". VSP is a commercial product, so the keyless
//     arcgisonline endpoint that is popular in hobby projects is not lawfully
//     available to us. Licensed ArcGIS Location Platform access would also
//     need a key, so it buys us nothing over Mapbox.
//   • Mapbox explicitly document Mapbox APIs being consumed from third-party
//     libraries such as MapLibre GL; tile requests are simply billed
//     individually under the Maps API instead of being bundled by their SDK.
//
// What Mapbox's terms require of us (all implemented here / in
// ImageryAttribution):
//   • A valid access token on every tile request. Tokens are secrets and are
//     supplied at build time via --dart-define, never committed.
//   • The Mapbox logo displayed on the map (assets/imagery/mapbox-logo.png).
//   • Text attribution "© Mapbox © OpenStreetMap" plus an "Improve this map"
//     link, each linking to the documented Mapbox/OSM/feedback URLs.
//   • No permanent offline caching of tiles: the Raster Tiles API sets
//     Cache-Control max-age=43200, so tiles are transient. The satellite
//     basemap is therefore an ONLINE feature — it degrades to a clear
//     "imagery unavailable" state rather than pretending to work offline.
//   • Usage is metered. Tiles are only requested when the golfer actually
//     opens satellite view.
//
// GOOGLE MAPS / EARTH TILES ARE NEVER USED — their terms forbid this and
// would encumber the product.
//
// ─── Build-time configuration ────────────────────────────────────────────────
//
//   flutter build apk --dart-define=MAPBOX_ACCESS_TOKEN=pk.xxxxx
//
// An operator holding a licence for other imagery (their own orthophotos, a
// national imagery service, licensed ArcGIS access) can point the app at it
// instead, supplying their own attribution string:
//
//   --dart-define=VSP_SATELLITE_TILE_URL=https://tiles.example.vn/{z}/{x}/{y}.jpg
//   --dart-define=VSP_SATELLITE_ATTRIBUTION=© Example Imagery
//
// When neither is configured the app says so plainly instead of silently
// pulling tiles we have no right to.

import 'package:equatable/equatable.dart';

/// Which imagery provider backs the satellite basemap.
enum SatelliteImageryProvider {
  /// Mapbox Satellite via the Raster Tiles API. Requires an access token.
  mapbox,

  /// Operator-supplied tile endpoint with operator-supplied attribution.
  custom,

  /// Nothing configured — satellite view is unavailable in this build.
  none,
}

/// Resolved satellite imagery settings for this build.
///
/// Immutable. Never logs or exposes the access token — see [toString].
class SatelliteImageryConfig extends Equatable {
  /// Provider backing the imagery.
  final SatelliteImageryProvider provider;

  /// XYZ tile template with `{z}`, `{x}`, `{y}` placeholders.
  /// Empty when [provider] is [SatelliteImageryProvider.none].
  final String tileUrlTemplate;

  /// Plain-text attribution embedded in the MapLibre raster source.
  ///
  /// This is the machine-readable copy; [ImageryAttribution] renders the
  /// human-visible, link-bearing version required by the provider's terms.
  final String attributionText;

  /// True when the provider's terms require the Mapbox logo on screen.
  final bool requiresMapboxLogo;

  /// Tile edge length in pixels (512 for Mapbox `@2x` tiles).
  final double tileSize;

  /// Highest zoom level the provider serves tiles for.
  final double maxZoom;

  const SatelliteImageryConfig({
    required this.provider,
    required this.tileUrlTemplate,
    required this.attributionText,
    required this.requiresMapboxLogo,
    required this.tileSize,
    required this.maxZoom,
  });

  /// The unconfigured state — satellite view must be disabled.
  static const SatelliteImageryConfig unavailable = SatelliteImageryConfig(
    provider: SatelliteImageryProvider.none,
    tileUrlTemplate: '',
    attributionText: '',
    requiresMapboxLogo: false,
    tileSize: 512,
    maxZoom: 22,
  );

  /// True when tiles can actually be requested.
  bool get isAvailable => provider != SatelliteImageryProvider.none;

  /// Identifies the rendered style without exposing the token.
  ///
  /// Used as a widget key so a map rebuilds when the provider changes. It must
  /// not be the tile template: that carries the access token, and a key ends up
  /// in widget diagnostics and error output.
  String get styleKey =>
      '${provider.name}:${tileSize.round()}:${maxZoom.round()}:'
      '${tileUrlTemplate.hashCode}';

  // ─── Build-time values ──────────────────────────────────────────────────────

  /// Mapbox public access token, supplied with `--dart-define`.
  /// NEVER hardcode a token here — the default is deliberately empty.
  static const String _mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
  );

  /// Operator-supplied XYZ tile template, supplied with `--dart-define`.
  static const String _customTileUrl = String.fromEnvironment(
    'VSP_SATELLITE_TILE_URL',
  );

  /// Attribution text for the operator-supplied endpoint.
  static const String _customAttribution = String.fromEnvironment(
    'VSP_SATELLITE_ATTRIBUTION',
  );

  /// Deepest zoom the operator's endpoint actually serves.
  static const int _customMaxZoom = int.fromEnvironment(
    'VSP_SATELLITE_MAX_ZOOM',
    defaultValue: 22,
  );

  /// Mapbox tileset used for satellite imagery.
  static const String mapboxTilesetId = 'mapbox.satellite';

  /// Attribution text required by Mapbox's terms.
  static const String mapboxAttributionText = '© Mapbox © OpenStreetMap';

  /// Reads the configuration baked into this build.
  factory SatelliteImageryConfig.fromEnvironment() => resolve(
    mapboxAccessToken: _mapboxAccessToken,
    customTileUrl: _customTileUrl,
    customAttribution: _customAttribution,
    customMaxZoom: _customMaxZoom,
  );

  /// Resolves a configuration from explicit values.
  ///
  /// An operator-supplied endpoint wins over Mapbox, so a club running its own
  /// licensed orthophotos never pays Mapbox for tiles it does not need. A
  /// custom endpoint without attribution text is rejected: we will not display
  /// imagery we cannot credit.
  static SatelliteImageryConfig resolve({
    String mapboxAccessToken = '',
    String customTileUrl = '',
    String customAttribution = '',
    int? customMaxZoom,
  }) {
    final customUrl = customTileUrl.trim();
    final customCredit = customAttribution.trim();
    if (customUrl.isNotEmpty && customCredit.isNotEmpty) {
      return SatelliteImageryConfig(
        provider: SatelliteImageryProvider.custom,
        tileUrlTemplate: customUrl,
        attributionText: customCredit,
        requiresMapboxLogo: false,
        tileSize: 256,
        // Most imagery services stop well short of 22 — Esri's World Imagery
        // tops out around 19, and asking for 20 gets a 404. MapLibre reads
        // maxzoom as "stop requesting past here and stretch the last level",
        // so an accurate value keeps a deep zoom looking soft; an inflated one
        // makes the map go blank exactly when a golfer zooms in on a green.
        maxZoom: (customMaxZoom ?? 22).clamp(1, 24).toDouble(),
      );
    }

    final token = mapboxAccessToken.trim();
    if (token.isNotEmpty) {
      return SatelliteImageryConfig(
        provider: SatelliteImageryProvider.mapbox,
        tileUrlTemplate:
            'https://api.mapbox.com/v4/$mapboxTilesetId/{z}/{x}/{y}@2x.jpg90'
            '?access_token=$token',
        attributionText: mapboxAttributionText,
        requiresMapboxLogo: true,
        tileSize: 512,
        maxZoom: 22,
      );
    }

    return unavailable;
  }

  /// Redacts the tile template so an access token can never reach a log line.
  @override
  String toString() =>
      'SatelliteImageryConfig(provider: ${provider.name}, '
      'attribution: $attributionText, tiles: <redacted>)';

  @override
  List<Object?> get props => [
    provider,
    tileUrlTemplate,
    attributionText,
    requiresMapboxLogo,
    tileSize,
    maxZoom,
  ];
}
