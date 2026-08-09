// Map Data Attribution — VSP Mobile App
//
// Credits the sources of the *geometry* the vector hole map draws, as opposed
// to [ImageryAttribution], which credits the photograph underneath the
// satellite view.
//
// The distinction is why this had to exist. ImageryAttribution was rendered in
// exactly one place — the satellite measuring view — so it appeared only while
// Mapbox imagery was on screen. The vector hole map draws OpenStreetMap-derived
// greens, bunkers, water and fairway corridors, and Sentinel-2-derived water
// hazards, and carried no attribution at all.
//
// Both obligations were already incurred. The ingest pipeline stamps them
// correctly — tools/course-digitization/osm/fetch_osm.py writes `ODbL-1.0` and
// `OpenStreetMap contributors`, detect_water_ndwi.py writes "Contains modified
// Copernicus Sentinel data" — and the chain then broke between the database and
// the golfer's screen:
//
//   • ODbL §4.3 requires the licence notice to be conveyed wherever a derived
//     database is publicly used. 332 bunkers and 5 water hazards come straight
//     from OSM; 900 fairway corridors and 840 greens are derived from OSM and
//     seed coordinates.
//   • The Copernicus Sentinel terms require the "Contains modified Copernicus
//     Sentinel data" notice on anything derived from the imagery. 40 water
//     hazards are Sentinel-2 NDWI derivations, and a grep for "copernicus" or
//     "sentinel" across the whole app returned nothing.
//
// Kept to one compact line so it can sit on a map without covering a hazard —
// the full text, and the reasoning above, live on the credits screen.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Where the ODbL notice links.
final Uri kOpenStreetMapCopyrightUrl = Uri.parse(
  'https://www.openstreetmap.org/copyright',
);

/// Attribution text required for anything derived from Copernicus imagery.
const String kCopernicusAttribution =
    'Contains modified Copernicus Sentinel data';

/// Attribution required for OpenStreetMap-derived geometry.
const String kOpenStreetMapAttribution = '© OpenStreetMap contributors (ODbL)';

/// On-map credit for the course geometry being drawn.
class MapDataAttribution extends StatelessWidget {
  /// True when this hole draws geometry derived from Copernicus imagery.
  ///
  /// Water hazards are the only Sentinel-derived layer, so a hole with no
  /// water does not carry the notice — crediting a source a screen does not
  /// use is noise, and noise is what gets attribution removed later.
  final bool includesCopernicus;

  /// Opens a URL. Injectable so tests do not hit the platform channel.
  final Future<bool> Function(Uri url)? onOpenUrl;

  const MapDataAttribution({
    super.key,
    this.includesCopernicus = false,
    this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = includesCopernicus
        ? '$kOpenStreetMapAttribution · $kCopernicusAttribution'
        : kOpenStreetMapAttribution;

    return Semantics(
      label: l10n.basemapAttributionSemantics(text),
      child: GestureDetector(
        onTap: () => (onOpenUrl ?? _defaultOpen)(kOpenStreetMapCopyrightUrl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0x99000000),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 10,
              decoration: TextDecoration.underline,
              decorationColor: Color(0x66E2E8F0),
            ),
          ),
        ),
      ),
    );
  }

  static Future<bool> _defaultOpen(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);
}
