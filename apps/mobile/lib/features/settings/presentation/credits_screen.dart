// Credits Screen — VSP Mobile App
//
// Where the app says whose data and whose code it is built on.
//
// There was no about, credits or legal screen anywhere: the settings screen was
// a language picker and nothing else, and `showLicensePage` / `LicenseRegistry`
// were never called — so Flutter's own generated NOTICES file, which every
// bundled package's licence ends up in, shipped inside the binary and was
// unreachable from the UI.
//
// Two obligations meet here:
//
//   • Data. OpenStreetMap geometry is ODbL, which requires the licence notice
//     to travel with public use of a derived database, and the Sentinel-2 water
//     hazards require the Copernicus notice. The one-line versions sit on the
//     map itself; the full statement belongs here.
//   • Code. Every third-party package's licence, via showLicensePage.
//
// One thing this screen does NOT claim: ODbL §4.4's share-alike offer for the
// derived database VSP distributes in course packages. That is a decision about
// what the business publishes, not a string — see the note at the bottom.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../basemap/data/basemap_config_service.dart';
import '../../basemap/domain/satellite_imagery_config.dart';
import '../../basemap/presentation/widgets/map_data_attribution.dart';

/// Attribution and licences for the data and code this app is built on.
class CreditsScreen extends StatelessWidget {
  /// Opens a URL. Injectable so tests do not hit the platform channel.
  final Future<bool> Function(Uri url)? onOpenUrl;

  /// Imagery provider to credit. Defaults to the one actually in force.
  ///
  /// Injectable for tests only. In the app this must never be passed a
  /// constant — see the note on the imagery section below.
  final SatelliteImageryConfig? imagery;

  const CreditsScreen({super.key, this.onOpenUrl, this.imagery});

  /// Mapbox's terms of service, for the satellite basemap.
  static final Uri mapboxTermsUrl = Uri.parse(
    'https://www.mapbox.com/legal/tos',
  );

  /// The Copernicus data licence.
  static final Uri copernicusUrl = Uri.parse(
    'https://sentinels.copernicus.eu/web/sentinel/terms-conditions',
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.creditsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _Section(title: l10n.creditsCourseDataTitle),
            _Entry(
              title: kOpenStreetMapAttribution,
              body: l10n.creditsOpenStreetMapBody,
              onTap: () => (onOpenUrl ?? _open)(kOpenStreetMapCopyrightUrl),
            ),
            _Entry(
              title: kCopernicusAttribution,
              body: l10n.creditsCopernicusBody,
              onTap: () => (onOpenUrl ?? _open)(copernicusUrl),
            ),
            _Section(title: l10n.creditsImageryTitle),
            _imageryEntry(context, l10n),
            _Section(title: l10n.creditsSoftwareTitle),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: Text(l10n.creditsOpenSourceLicences),
              subtitle: Text(l10n.creditsOpenSourceLicencesBody),
              onTap: () => showLicensePage(
                context: context,
                applicationName: l10n.appTitle,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              child: Text(
                l10n.creditsDataQualityNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Credits whoever is actually serving the tiles.
  ///
  /// This used to be the constant "© Mapbox © OpenStreetMap" with a link to
  /// Mapbox's terms. The provider moved to a server-side setting and the
  /// deployment now serves Esri — so the map footer said "Powered by Esri —
  /// Esri, Maxar, Earthstar Geographics" while this screen, the one that
  /// exists to discharge the attribution obligation, credited a company whose
  /// imagery was not on screen. Crediting the wrong provider is a licence
  /// problem in both directions at once.
  Widget _imageryEntry(BuildContext context, AppLocalizations l10n) {
    final injected = imagery;
    if (injected != null) return _imageryFor(injected, l10n);

    return ValueListenableBuilder<SatelliteImageryConfig>(
      valueListenable: SatelliteImagery.listenable,
      builder: (context, config, _) => _imageryFor(config, l10n),
    );
  }

  Widget _imageryFor(SatelliteImageryConfig config, AppLocalizations l10n) {
    switch (config.provider) {
      case SatelliteImageryProvider.mapbox:
        return _Entry(
          title: config.attributionText,
          body: l10n.creditsMapboxBody,
          onTap: () => (onOpenUrl ?? _open)(mapboxTermsUrl),
        );
      case SatelliteImageryProvider.custom:
        // No terms link: the operator supplies the credit line, and we have no
        // URL we can honestly claim is their licence.
        return _Entry(
          title: config.attributionText,
          body: l10n.creditsImageryProviderBody,
        );
      case SatelliteImageryProvider.none:
        // Saying nothing would leave the previous provider's credit as the
        // last thing the screen showed. This build has no imagery and says so.
        return _Entry(
          title: l10n.creditsImageryNoneTitle,
          body: l10n.creditsImageryNoneBody,
        );
    }
  }

  static Future<bool> _open(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);
}

class _Section extends StatelessWidget {
  final String title;

  const _Section({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  final String title;
  final String body;

  /// Null where there is no licence page we can honestly link to — an
  /// operator's own imagery, for one. The row then carries no open-in-new
  /// icon either, rather than promising a link that does nothing.
  final VoidCallback? onTap;

  const _Entry({required this.title, required this.body, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(body),
      trailing: onTap == null ? null : const Icon(Icons.open_in_new, size: 18),
      onTap: onTap,
    );
  }
}
