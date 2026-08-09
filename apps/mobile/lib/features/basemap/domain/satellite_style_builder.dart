// Satellite Style Builder — VSP Mobile App
//
// Builds a self-contained MapLibre style for the satellite + measuring view.
//
// Deliberately contains NO symbol layers. Symbol layers need a `glyphs`
// endpoint, and a golfer on a Vietnamese course with two bars of signal should
// not be waiting on a font server to see how far it is to the water. Labels
// are rendered as Flutter widgets over the map instead.

import 'dart:convert';

import 'package:vsp_mobile/features/measure/domain/measure_overlay_builder.dart';

import 'satellite_imagery_config.dart';

/// Builds the MapLibre style JSON used by the satellite measuring view.
abstract final class SatelliteStyleBuilder {
  /// Source id for the raster imagery.
  static const String satelliteSourceId = 'satellite-imagery';

  /// Layer id for the raster imagery.
  static const String satelliteLayerId = 'satellite-imagery-raster';

  /// Source id for the measuring overlay GeoJSON.
  static const String measureSourceId = 'measure-overlay';

  // Palette — matches the app's dark map surfaces.
  static const String _backgroundColor = '#0F172A';
  static const String _legColor = '#FACC15';
  static const String _greenLegColor = '#22C55E';
  static const String _pointColor = '#FACC15';
  static const String _golferColor = '#38BDF8';
  static const String _greenMarkerColor = '#22C55E';
  static const String _outlineColor = '#0F172A';

  /// Builds the style as a JSON string ready for `MapLibreMap.styleString`.
  static String build({required SatelliteImageryConfig config}) =>
      jsonEncode(buildStyleMap(config: config));

  /// Builds the style as a map (kept separate so tests can assert on it).
  static Map<String, dynamic> buildStyleMap({
    required SatelliteImageryConfig config,
  }) {
    final sources = <String, dynamic>{
      measureSourceId: {
        'type': 'geojson',
        'data': const {'type': 'FeatureCollection', 'features': []},
      },
    };

    final layers = <Map<String, dynamic>>[
      {
        'id': 'background',
        'type': 'background',
        'paint': {'background-color': _backgroundColor},
      },
    ];

    if (config.isAvailable) {
      sources[satelliteSourceId] = {
        'type': 'raster',
        'tiles': [config.tileUrlTemplate],
        'tileSize': config.tileSize.round(),
        'maxzoom': config.maxZoom.round(),
        // MapLibre surfaces this in its own attribution plumbing; the
        // human-visible, link-bearing attribution required by the provider's
        // terms is rendered by ImageryAttribution.
        'attribution': config.attributionText,
      };
      layers.add({
        'id': satelliteLayerId,
        'type': 'raster',
        'source': satelliteSourceId,
        'paint': {'raster-opacity': 1.0},
      });
    }

    layers.addAll(_measureLayers());

    return {
      'version': 8,
      'name': 'VSP Satellite Measure',
      'sources': sources,
      'layers': layers,
    };
  }

  static List<Map<String, dynamic>> _measureLayers() {
    return [
      // GPS accuracy disc — drawn first so markers sit on top of it.
      {
        'id': 'measure-accuracy-fill',
        'type': 'fill',
        'source': measureSourceId,
        'filter': ['==', 'kind', MeasureFeatureKind.accuracy],
        'paint': {'fill-color': _golferColor, 'fill-opacity': 0.15},
      },
      {
        'id': 'measure-accuracy-outline',
        'type': 'line',
        'source': measureSourceId,
        'filter': ['==', 'kind', MeasureFeatureKind.accuracy],
        'paint': {
          'line-color': _golferColor,
          'line-width': 1.0,
          'line-opacity': 0.6,
        },
      },
      // Measured chain.
      {
        'id': 'measure-leg-casing',
        'type': 'line',
        'source': measureSourceId,
        'filter': ['==', 'kind', MeasureFeatureKind.leg],
        'layout': {'line-cap': 'round', 'line-join': 'round'},
        'paint': {
          'line-color': _outlineColor,
          'line-width': 6.0,
          'line-opacity': 0.55,
        },
      },
      {
        'id': 'measure-leg-line',
        'type': 'line',
        'source': measureSourceId,
        'filter': ['==', 'kind', MeasureFeatureKind.leg],
        'layout': {'line-cap': 'round', 'line-join': 'round'},
        'paint': {'line-color': _legColor, 'line-width': 3.0},
      },
      // Run-on to the green is dashed: it is a different kind of claim.
      {
        'id': 'measure-green-line',
        'type': 'line',
        'source': measureSourceId,
        'filter': ['==', 'kind', MeasureFeatureKind.greenLeg],
        'layout': {'line-cap': 'round', 'line-join': 'round'},
        'paint': {
          'line-color': _greenLegColor,
          'line-width': 3.0,
          'line-dasharray': [2.0, 2.0],
        },
      },
      // Markers.
      {
        'id': 'measure-golfer-circle',
        'type': 'circle',
        'source': measureSourceId,
        'filter': ['==', 'kind', MeasureFeatureKind.golfer],
        'paint': {
          'circle-radius': 7.0,
          'circle-color': _golferColor,
          'circle-stroke-width': 2.0,
          'circle-stroke-color': '#FFFFFF',
        },
      },
      {
        'id': 'measure-green-circle',
        'type': 'circle',
        'source': measureSourceId,
        'filter': ['==', 'kind', MeasureFeatureKind.green],
        'paint': {
          'circle-radius': 8.0,
          'circle-color': _greenMarkerColor,
          'circle-stroke-width': 2.0,
          'circle-stroke-color': '#FFFFFF',
        },
      },
      {
        'id': 'measure-point-circle',
        'type': 'circle',
        'source': measureSourceId,
        'filter': ['==', 'kind', MeasureFeatureKind.point],
        'paint': {
          'circle-radius': 8.0,
          'circle-color': _pointColor,
          'circle-stroke-width': 2.0,
          'circle-stroke-color': _outlineColor,
        },
      },
    ];
  }
}
