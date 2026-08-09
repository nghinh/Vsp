// Imagery Attribution — VSP Mobile App
//
// Satellite imagery is licensed, not free. Mapbox's terms require the Mapbox
// logo on the map plus linked text attribution to Mapbox, OpenStreetMap and
// their feedback tool. This widget is that obligation, in code — it is not
// decoration and must not be removed or hidden behind a menu.
//
// assets/imagery/mapbox-logo.png is Mapbox's own logo, taken from the logo
// Mapbox ship in mapbox-gl for exactly this purpose. It is a Mapbox trademark;
// it is bundled solely to satisfy their attribution requirement and is only
// ever shown while Mapbox imagery is on screen.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:vsp_mobile/features/basemap/domain/satellite_imagery_config.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// On-map attribution for the active imagery provider.
class ImageryAttribution extends StatelessWidget {
  /// Imagery configuration currently in use.
  final SatelliteImageryConfig config;

  /// Opens a URL. Injectable so tests do not hit the platform channel.
  final Future<bool> Function(Uri url)? onOpenUrl;

  const ImageryAttribution({super.key, required this.config, this.onOpenUrl});

  /// Where "© Mapbox" links, per Mapbox's attribution guidance.
  static final Uri mapboxUrl = Uri.parse('https://www.mapbox.com/about/maps/');

  /// Where "© OpenStreetMap" links.
  static final Uri openStreetMapUrl = Uri.parse(
    'https://www.openstreetmap.org/copyright',
  );

  /// Where "Improve this map" links.
  static final Uri improveMapUrl = Uri.parse(
    'https://www.mapbox.com/map-feedback/',
  );

  @override
  Widget build(BuildContext context) {
    if (!config.isAvailable) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final isMapbox = config.provider == SatelliteImageryProvider.mapbox;

    return Semantics(
      label: l10n.basemapAttributionSemantics(config.attributionText),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0x99000000),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (config.requiresMapboxLogo) ...[
              // Required by Mapbox's terms — the logo, not just the words.
              ExcludeSemantics(
                child: Image.asset(
                  'assets/imagery/mapbox-logo.png',
                  width: 62,
                  height: 16,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (isMapbox)
              Flexible(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    _AttributionLink(
                      label: '© Mapbox',
                      url: mapboxUrl,
                      onOpenUrl: onOpenUrl,
                    ),
                    _AttributionLink(
                      label: '© OpenStreetMap',
                      url: openStreetMapUrl,
                      onOpenUrl: onOpenUrl,
                    ),
                    _AttributionLink(
                      label: l10n.basemapAttributionImproveMap,
                      url: improveMapUrl,
                      onOpenUrl: onOpenUrl,
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: Text(
                  config.attributionText,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AttributionLink extends StatelessWidget {
  final String label;
  final Uri url;
  final Future<bool> Function(Uri url)? onOpenUrl;

  const _AttributionLink({
    required this.label,
    required this.url,
    this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => (onOpenUrl ?? _defaultOpen)(url),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFE2E8F0),
          fontSize: 10,
          decoration: TextDecoration.underline,
          decorationColor: Color(0x66E2E8F0),
        ),
      ),
    );
  }

  static Future<bool> _defaultOpen(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);
}
