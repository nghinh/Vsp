// Course Map Style Builder — VSP Mobile App
//
// Builds the MapLibre style for the vector hole map in Dart, the same way
// SatelliteStyleBuilder does for the satellite view.
//
// It replaces `packages/map-style/style.json`, which the map asked for as
// `packages/map-style/style.json` — the Flutter "asset from another package"
// form. `map-style` is not a Dart package (no pubspec, and a hyphen is not
// legal in a Dart package name), it is not a dependency of this app, and it
// was never listed in the asset bundle, so that string could not resolve at
// runtime and the course-map mode has never rendered.
//
// Two things in that file could not have worked either, which is why this is a
// rewrite and not a copy:
//
//   * its only geometry source was a vector-tile endpoint,
//     https://tiles.vsp.vn/courses/{z}/{x}/{y}.mvt, which does not exist. The
//     app already ships the geometry it needs inside the downloaded course
//     package, so this style reads GeoJSON out of that instead — offline, on
//     the course, where a golfer actually stands.
//   * its labels were symbol layers, which need a glyph server
//     (fonts.openmaptiles.org). There are no symbol layers here, for the
//     reason already written down in SatelliteStyleBuilder: nobody should wait
//     on a font CDN to see the green. Labels are Flutter widgets over the map.

import 'dart:convert';

import 'hole_map_geojson.dart';
import 'map_layer.dart';

/// Builds the MapLibre style JSON used by the vector course map.
abstract final class CourseMapStyleBuilder {
  /// Source id for the hole's course-package geometry.
  static const String courseSourceId = 'course-geometry';

  /// Source id for the live overlay (golfer, pin, target, rings).
  static const String overlaySourceId = 'hole-overlay';

  // Palette — carried over from the style document this replaces.
  static const String _backgroundColor = '#0F172A';
  static const String _ringColor = '#F8FAFC';
  static const String _golferColor = '#3B82F6';
  static const String _pinColor = '#EA580C';
  static const String _targetColor = '#22D3EE';

  /// Course layers in draw order — rough underneath, hazards and tees on top.
  static const List<MapLayerType> courseLayerOrder = [
    MapLayerType.rough,
    MapLayerType.fairway,
    MapLayerType.green,
    MapLayerType.bunker,
    MapLayerType.water,
    MapLayerType.penaltyArea,
    MapLayerType.ob,
    MapLayerType.cartPath,
    MapLayerType.tee,
    MapLayerType.landmark,
  ];

  /// Builds the style as a JSON string ready for `MapLibreMap.styleString`.
  static String build() => jsonEncode(buildStyleMap());

  /// Builds the style as a map (kept separate so tests can assert on it).
  static Map<String, dynamic> buildStyleMap() {
    final layers = <Map<String, dynamic>>[
      {
        'id': 'background',
        'type': 'background',
        'paint': {'background-color': _backgroundColor},
      },
    ];

    for (final type in courseLayerOrder) {
      layers.addAll(_courseLayers(type));
    }
    layers.addAll(_overlayLayers());

    return {
      'version': 8,
      'name': 'VSP Golf Course Style',
      'sources': {
        courseSourceId: {'type': 'geojson', 'data': HoleMapGeoJson.empty},
        overlaySourceId: {'type': 'geojson', 'data': HoleMapGeoJson.empty},
      },
      'layers': layers,
    };
  }

  /// Style layer ids drawing the domain layer named [domainLayerName] (the
  /// [MapLayerType] name, or an overlay kind such as `distanceRing100`).
  ///
  /// A domain layer maps to several style layers, so visibility toggles have
  /// to move all of them together.
  static List<String> styleLayerIds(String domainLayerName) {
    for (final type in courseLayerOrder) {
      if (type.name == domainLayerName) {
        return [
          _fillId(type),
          _lineId(type),
          _pointId(type),
        ];
      }
    }
    switch (domainLayerName) {
      case HoleMapFeatureKind.distanceRing100:
        return const ['distance-ring-100'];
      case HoleMapFeatureKind.distanceRing150:
        return const ['distance-ring-150'];
      case HoleMapFeatureKind.distanceRing200:
        return const ['distance-ring-200'];
      case HoleMapFeatureKind.pin:
        return const ['pin-circle'];
      case HoleMapFeatureKind.golfer:
        return const ['golfer-circle', 'golfer-accuracy-fill'];
      case HoleMapFeatureKind.target:
        return const ['target-marker'];
      default:
        return const [];
    }
  }

  static String _fillId(MapLayerType type) => '${_slug(type)}-fill';

  static String _lineId(MapLayerType type) => '${_slug(type)}-line';

  static String _pointId(MapLayerType type) => '${_slug(type)}-point';

  /// `penaltyArea` → `penalty-area`, so layer ids read like the style document
  /// they replace.
  static String _slug(MapLayerType type) => type.name
      .replaceAllMapped(
        RegExp('[A-Z]'),
        (m) => '-${m.group(0)!.toLowerCase()}',
      );

  /// Each course layer gets a fill, a line and a circle layer on the shared
  /// source, and each is restricted to the geometry it is actually for.
  ///
  /// <strong>Why the geometry-type guard.</strong> The three layers used to
  /// share one filter, on the reasoning that "MapLibre draws only the geometry
  /// a layer type can render, so a polygons-only layer costs two no-ops". Two
  /// of the three are no-ops — a fill over a Point draws nothing, a line over a
  /// Point draws nothing. A **circle layer over a Polygon is not**: it draws a
  /// circle at every vertex. So a bunker traced with twenty points came out as
  /// twenty overlapping orange discs, a green as a cluster of green ones, and
  /// the tee boxes as a string of white beads. The hole was rendering its own
  /// vertices instead of its shapes, and it looked like abstract art rather
  /// than a golf hole.
  static List<Map<String, dynamic>> _courseLayers(MapLayerType type) {
    final style = _paletteFor(type);
    final ofType = ['==', ['get', 'layerType'], type.name];

    List<Object> withGeometry(List<String> kinds) => [
      'all',
      ofType,
      ['match', ['geometry-type'], kinds, true, false],
    ];

    /// Same, plus whether the shape itself has been confirmed.
    ///
    /// Provenance is per shape, not per hole. Long Thành's greens and bunkers
    /// were confirmed by a reviewer looking at imagery; its water hazards are
    /// 10 m Sentinel-2 pixels a script thresholded, and its fairway is a
    /// rectangle derived from the tee–green line. All four were drawn
    /// identically on a hole badged verified, so a golfer planning a lay-up
    /// could not tell the bunker that is really there from the pond that might
    /// not be. Anything unconfirmed is drawn faint and dashed — present, and
    /// visibly not a promise.
    List<Object> withGeometryAnd(List<String> kinds, {required bool verified}) => [
      'all',
      ofType,
      ['match', ['geometry-type'], kinds, true, false],
      // Absent reads as unverified, the same way the reader treats a package
      // with no provenance.
      [verified ? '==' : '!=', ['coalesce', ['get', 'verified'], false], true],
    ];

    return [
      {
        'id': _fillId(type),
        'type': 'fill',
        'source': courseSourceId,
        'filter': withGeometry(const ['Polygon', 'MultiPolygon']),
        'paint': {
          'fill-color': style.fill,
          // Half strength for a shape nobody has confirmed.
          'fill-opacity': [
            'case',
            ['==', ['coalesce', ['get', 'verified'], false], true],
            style.fillOpacity,
            style.fillOpacity * 0.45,
          ],
        },
      },
      {
        'id': _lineId(type),
        'type': 'line',
        'source': courseSourceId,
        // Polygons too: the outline is what gives a bunker or a green its edge
        // against the fill underneath.
        'filter': withGeometryAnd(const [
          'LineString',
          'MultiLineString',
          'Polygon',
          'MultiPolygon',
        ], verified: true),
        'layout': {'line-cap': 'round', 'line-join': 'round'},
        'paint': {
          'line-color': style.line,
          'line-width': style.lineWidth,
          'line-opacity': style.lineOpacity,
          if (style.lineDash != null) 'line-dasharray': style.lineDash,
        },
      },
      {
        // Unconfirmed shapes get a dashed edge. `line-dasharray` cannot be
        // driven by a property in MapLibre, so this is a second layer rather
        // than an expression.
        'id': '${_lineId(type)}-unverified',
        'type': 'line',
        'source': courseSourceId,
        'filter': withGeometryAnd(const [
          'LineString',
          'MultiLineString',
          'Polygon',
          'MultiPolygon',
        ], verified: false),
        'layout': {'line-cap': 'round', 'line-join': 'round'},
        'paint': {
          'line-color': style.line,
          'line-width': style.lineWidth,
          'line-opacity': style.lineOpacity * 0.8,
          'line-dasharray': const [2.0, 2.0],
        },
      },
      {
        'id': _pointId(type),
        'type': 'circle',
        'source': courseSourceId,
        // Points only. A hole carries a few real ones — the tee and green
        // reference points the package writes — and they are worth a marker.
        // Every polygon vertex is not.
        'filter': withGeometry(const ['Point', 'MultiPoint']),
        'paint': {
          'circle-color': style.fill,
          'circle-radius': 5.0,
          'circle-stroke-width': 1.5,
          'circle-stroke-color': style.line,
        },
      },
    ];
  }

  static List<Map<String, dynamic>> _overlayLayers() {
    Map<String, dynamic> ring(String id, String kind) => {
      'id': id,
      'type': 'line',
      'source': overlaySourceId,
      'filter': ['==', ['get', 'layerType'], kind],
      'paint': {
        'line-color': _ringColor,
        'line-width': 1.0,
        'line-opacity': 0.5,
        'line-dasharray': [3.0, 3.0],
      },
    };

    Map<String, dynamic> marker(
      String id,
      String kind,
      String color,
      double radius,
    ) => {
      'id': id,
      'type': 'circle',
      'source': overlaySourceId,
      'filter': ['==', ['get', 'layerType'], kind],
      'paint': {
        'circle-color': color,
        'circle-radius': radius,
        'circle-stroke-width': 2.0,
        'circle-stroke-color': '#FFFFFF',
      },
    };

    return [
      // The play line, under everything: from where the golfer stands (or the
      // tee) through the target to the flag, with the distance written on it.
      {
        'id': 'play-line',
        'type': 'line',
        'source': overlaySourceId,
        'filter': ['==', ['get', 'layerType'], HoleMapFeatureKind.playLine],
        'paint': {
          'line-color': '#FFFFFF',
          'line-width': 2.0,
          'line-opacity': 0.9,
        },
      },
      // The accuracy disc is a real geodesic polygon (see HoleMapGeoJson), so
      // it is filled, not a pixel-radius circle that lies at every other zoom.
      {
        'id': 'golfer-accuracy-fill',
        'type': 'fill',
        'source': overlaySourceId,
        'filter': [
          '==',
          ['get', 'layerType'],
          HoleMapFeatureKind.golferAccuracy,
        ],
        'paint': {'fill-color': _golferColor, 'fill-opacity': 0.15},
      },
      ring('distance-ring-100', HoleMapFeatureKind.distanceRing100),
      ring('distance-ring-150', HoleMapFeatureKind.distanceRing150),
      ring('distance-ring-200', HoleMapFeatureKind.distanceRing200),
      marker('pin-circle', HoleMapFeatureKind.pin, _pinColor, 7.0),
      marker('target-marker', HoleMapFeatureKind.target, _targetColor, 8.0),
      marker('golfer-circle', HoleMapFeatureKind.golfer, _golferColor, 9.0),
    ];
  }

  static _LayerPalette _paletteFor(MapLayerType type) {
    switch (type) {
      case MapLayerType.rough:
        return const _LayerPalette(fill: '#14532D', line: '#166534');
      case MapLayerType.fairway:
        return const _LayerPalette(
          fill: '#166534',
          fillOpacity: 0.85,
          line: '#15803D',
        );
      case MapLayerType.green:
        return const _LayerPalette(
          fill: '#22C55E',
          fillOpacity: 0.9,
          line: '#16A34A',
        );
      case MapLayerType.bunker:
        return const _LayerPalette(
          fill: '#D4A853',
          fillOpacity: 0.9,
          line: '#A16207',
        );
      case MapLayerType.water:
        return const _LayerPalette(
          fill: '#1D4ED8',
          fillOpacity: 0.8,
          line: '#1E40AF',
          lineWidth: 1.5,
        );
      case MapLayerType.penaltyArea:
        return const _LayerPalette(
          fill: '#9333EA',
          fillOpacity: 0.6,
          line: '#7E22CE',
        );
      case MapLayerType.ob:
        return const _LayerPalette(
          fill: '#1E293B',
          fillOpacity: 0.9,
          line: '#F87171',
        );
      case MapLayerType.cartPath:
        return const _LayerPalette(
          fill: '#64748B',
          fillOpacity: 0.4,
          line: '#64748B',
          lineWidth: 2.5,
          lineOpacity: 0.8,
          lineDash: [4.0, 2.0],
        );
      case MapLayerType.tee:
        return const _LayerPalette(
          fill: '#E2E8F0',
          fillOpacity: 0.8,
          line: '#94A3B8',
        );
      case MapLayerType.landmark:
        return const _LayerPalette(
          fill: '#F8FAFC',
          fillOpacity: 0.9,
          line: '#0F172A',
        );
      default:
        return const _LayerPalette(fill: '#64748B', line: '#94A3B8');
    }
  }
}

/// Colours for one course layer's fill / line / point rendering.
class _LayerPalette {
  final String fill;
  final double fillOpacity;
  final String line;
  final double lineWidth;
  final double lineOpacity;
  final List<double>? lineDash;

  const _LayerPalette({
    required this.fill,
    this.fillOpacity = 0.8,
    required this.line,
    this.lineWidth = 1.0,
    this.lineOpacity = 0.9,
    this.lineDash,
  });
}
