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

  // Palette — daylight, the way a golfer sees the hole they are standing on.
  //
  // It was midnight navy with neon-bright shapes on it, inherited from the
  // style document this replaces. That reads as a dashboard, not as a golf
  // hole: on a phone held up in the sun the dark ground is a mirror, and the
  // saturated greens do not tell a golfer which patch is fairway and which is
  // the green they are aiming at, because both are "bright green".
  //
  // So: grass in the greens grass is actually in, sand the colour of sand,
  // paths the colour of concrete. The shapes are told apart by hue the way
  // they are on the ground rather than by luminance, and the only things
  // allowed to be loud are the three that are not scenery — the golfer, the
  // flag, and the spot being aimed at.
  //
  // <strong>The background is ground, not sky.</strong> It was #DCEAF6, a pale
  // blue, described here as "pale sky behind" — but this is a plan view and
  // there is nothing behind. Every pixel no polygon covers is a piece of the
  // course a golfer can walk on, and painting it sky blue says the opposite:
  // on Long Biên's 10th, where the model had traced a fairway and a patch of
  // rough and nothing else, the hole rendered as three pale islands in an
  // ocean, and the first thing reported about it was that the lake was drawn
  // wrong. There was no lake. There was a blue background.
  //
  // A turf tone that is duller and darker than the rough above it, so that
  // rough still reads as a drawn shape where somebody drew one, and so that
  // the one genuinely blue thing on the map is water.
  static const String _backgroundColor = '#6E9C56';
  static const String _ringColor = '#43584C';
  static const String _golferColor = '#4A6E8F';
  static const String _pinColor = '#111827';
  static const String _targetColor = '#DA2B3C';

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
          _draftFillId(type),
          _lineId(type),
          // Left off this list once, so turning water off left every
          // unconfirmed pond outlined on the map with nothing inside it.
          _draftLineId(type),
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
        // All three rings of the bullseye, or turning the target off leaves
        // its outer ring on the map with a hole in the middle.
        return const ['target-ring', 'target-ring-inner', 'target-marker'];
      default:
        return const [];
    }
  }

  static String _fillId(MapLayerType type) => '${_slug(type)}-fill';

  static String _draftFillId(MapLayerType type) => '${_fillId(type)}-unverified';

  static String _lineId(MapLayerType type) => '${_slug(type)}-line';

  static String _draftLineId(MapLayerType type) => '${_lineId(type)}-unverified';

  static String _pointId(MapLayerType type) => '${_slug(type)}-point';

  /// `penaltyArea` → `penalty-area`, so layer ids read like the style document
  /// they replace.
  static String _slug(MapLayerType type) => type.name
      .replaceAllMapped(
        RegExp('[A-Z]'),
        (m) => '-${m.group(0)!.toLowerCase()}',
      );

  /// Each course layer gets fills, outlines and a circle layer on the shared
  /// source, and each draws only the features [HoleMapGeoJson] addressed to it.
  ///
  /// <strong>Why the filters are this dumb.</strong> Which layer should draw a
  /// feature depends on three things — its layer type, whether it is an area or
  /// a line or a point, and whether anybody has confirmed it — and this style
  /// used to ask MapLibre to work that out: `all` over `==` over `match` over
  /// `geometry-type` over `coalesce`. On device the course map drew nothing at
  /// all: no fills, no outlines. The overlay drew fine on the same map at the
  /// same moment, and its filters are a single `==` against a property. So the
  /// three questions are answered in Dart now, where they are unit-tested, and
  /// each feature arrives carrying `fillOf` / `strokeOf` / `pointOf` naming the
  /// layer that should draw it. A filter that cannot be misread cannot fail
  /// silently, and a golfer standing on the 4th does not care how elegant the
  /// expression was.
  ///
  /// The geometry question is still a real one, and worth keeping written
  /// down: a fill over a Point draws nothing and a line over a Point draws
  /// nothing, but a **circle layer over a Polygon draws a disc at every
  /// vertex**. A bunker traced with twenty points came out as twenty
  /// overlapping orange discs, a green as a cluster of green ones, the tees as
  /// a string of white beads — the hole rendering its own vertices instead of
  /// its shapes. `pointOf` is set on points only, which is what stops that.
  ///
  /// Provenance is per shape, not per hole. Long Thành's greens and bunkers
  /// were confirmed by a reviewer looking at imagery; its water hazards are
  /// 10 m Sentinel-2 pixels a script thresholded, and its fairway is a
  /// rectangle derived from the tee–green line. All four were drawn identically
  /// on a hole badged verified, so a golfer planning a lay-up could not tell
  /// the bunker that is really there from the pond that might not be. Anything
  /// unconfirmed is drawn faint and dashed — present, and visibly not a
  /// promise.
  static List<Map<String, dynamic>> _courseLayers(MapLayerType type) {
    final style = _paletteFor(type);

    List<Object> drawnBy(String property) => [
      '==',
      ['get', property],
      type.name,
    ];

    Map<String, dynamic> fill(String id, String property, double opacity) => {
      'id': id,
      'type': 'fill',
      'source': courseSourceId,
      'filter': drawnBy(property),
      'paint': {'fill-color': style.fill, 'fill-opacity': opacity},
    };

    return [
      fill(_fillId(type), HoleMapGeoJson.fillKey, style.fillOpacity),
      // Softer for a shape nobody has confirmed — but still a shape.
      //
      // This was 0.45, chosen against the old blue background where a green
      // fill at 45% still read as green because nothing else on screen was.
      // Against turf it reads as turf: the fairway and the bunkers vanished
      // into the ground they sit on, and every unreviewed course in this
      // database — which is all of them GolfSeg has touched — looked empty.
      // The dashed outline below is what says "provisional"; the fill only
      // has to say "here". 0.8 keeps both.
      fill(_draftFillId(type), HoleMapGeoJson.draftFillKey,
          style.fillOpacity * 0.8),
      {
        'id': _lineId(type),
        'type': 'line',
        'source': courseSourceId,
        // Polygons too: the outline is what gives a bunker or a green its edge
        // against the fill underneath.
        'filter': drawnBy(HoleMapGeoJson.strokeKey),
        'layout': {'line-cap': 'round', 'line-join': 'round'},
        'paint': {
          'line-color': style.line,
          'line-width': style.lineWidth,
          'line-opacity': style.lineOpacity,
        },
      },
      {
        // Unconfirmed shapes get a dashed edge. `line-dasharray` cannot be
        // driven by a property in MapLibre, so this is a second layer rather
        // than an expression — the same trade the fills above make.
        'id': _draftLineId(type),
        'type': 'line',
        'source': courseSourceId,
        'filter': drawnBy(HoleMapGeoJson.draftStrokeKey),
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
        // Points only — a hole carries a few real ones, the tee and green
        // reference points the package writes, and they are worth a marker.
        'filter': drawnBy(HoleMapGeoJson.pointKey),
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
      double radius, {
      double strokeWidth = 2.0,
    }) => {
      'id': id,
      'type': 'circle',
      'source': overlaySourceId,
      'filter': ['==', ['get', 'layerType'], kind],
      'paint': {
        'circle-color': color,
        'circle-radius': radius,
        'circle-stroke-width': strokeWidth,
        'circle-stroke-color': '#FFFFFF',
      },
    };

    return [
      // The play line, under everything: from where the golfer stands (or the
      // tee) through the target to the flag, with the distance written on it.
      //
      // Two layers. A white line on grass is white-on-light — legible in the
      // office, gone in the sun with a phone at arm's length — so a soft dark
      // casing goes under it. Same trick the satellite view already uses,
      // where the ground underneath is a photograph and even less predictable.
      {
        'id': 'play-line-casing',
        'type': 'line',
        'source': overlaySourceId,
        'filter': ['==', ['get', 'layerType'], HoleMapFeatureKind.playLine],
        'layout': {'line-cap': 'round', 'line-join': 'round'},
        'paint': {
          'line-color': '#1F2E23',
          'line-width': 5.0,
          'line-opacity': 0.22,
        },
      },
      {
        'id': 'play-line',
        'type': 'line',
        'source': overlaySourceId,
        'filter': ['==', ['get', 'layerType'], HoleMapFeatureKind.playLine],
        'layout': {'line-cap': 'round', 'line-join': 'round'},
        'paint': {
          'line-color': '#FFFFFF',
          'line-width': 3.0,
          'line-opacity': 0.95,
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
      // The target is a bullseye, not a dot: three circles stacked, because it
      // is the one thing on the map the golfer put there themselves and it has
      // to be findable among a dozen shapes the map put there. A single disc
      // the same size reads as one more marker.
      marker('target-ring', HoleMapFeatureKind.target, _targetColor, 11.0),
      marker('target-ring-inner', HoleMapFeatureKind.target, '#FFFFFF', 7.0,
          strokeWidth: 0.0),
      marker('target-marker', HoleMapFeatureKind.target, _targetColor, 3.5,
          strokeWidth: 0.0),
      marker('golfer-circle', HoleMapFeatureKind.golfer, _golferColor, 9.0),
    ];
  }

  static _LayerPalette _paletteFor(MapLayerType type) {
    switch (type) {
      // The body of the hole. Everything else sits on this, so it is opaque
      // and its outline is barely darker than its fill — a hard edge here
      // would draw a black line round the whole hole.
      case MapLayerType.rough:
        return const _LayerPalette(
          fill: '#79B356',
          fillOpacity: 1.0,
          line: '#6DA44C',
          lineWidth: 1.0,
          lineOpacity: 0.6,
        );
      // Lighter than the rough, the way mown grass is.
      case MapLayerType.fairway:
        return const _LayerPalette(
          fill: '#9BCE6C',
          fillOpacity: 1.0,
          line: '#8DC15E',
          lineWidth: 1.2,
          lineOpacity: 0.7,
        );
      // Lighter again, and outlined white: this is the one shape on the hole
      // a golfer is aiming at, and it has to be findable at a glance.
      case MapLayerType.green:
        return const _LayerPalette(
          fill: '#B7E07A',
          fillOpacity: 1.0,
          line: '#FFFFFF',
          lineWidth: 1.6,
          lineOpacity: 0.85,
        );
      case MapLayerType.bunker:
        return const _LayerPalette(
          fill: '#F2E3B8',
          fillOpacity: 1.0,
          line: '#DCC68A',
          lineWidth: 1.2,
        );
      case MapLayerType.water:
        return const _LayerPalette(
          fill: '#5EB3E4',
          fillOpacity: 0.95,
          line: '#3E96CC',
          lineWidth: 1.4,
        );
      case MapLayerType.penaltyArea:
        return const _LayerPalette(
          fill: '#E9A9A9',
          fillOpacity: 0.75,
          line: '#C96A6A',
          lineWidth: 1.4,
        );
      case MapLayerType.ob:
        return const _LayerPalette(
          fill: '#C7C2B6',
          fillOpacity: 0.55,
          line: '#B3453F',
          lineWidth: 1.4,
        );
      // A solid concrete ribbon, not a dashed hairline. The cart path is the
      // one thing on the hole that tells a golfer where they are when nothing
      // else on screen matches what they can see.
      case MapLayerType.cartPath:
        return const _LayerPalette(
          fill: '#CFC9BE',
          fillOpacity: 0.9,
          line: '#CFC9BE',
          lineWidth: 3.0,
          lineOpacity: 0.95,
        );
      case MapLayerType.tee:
        return const _LayerPalette(
          fill: '#C4E39A',
          fillOpacity: 1.0,
          line: '#A8CC79',
          lineWidth: 1.2,
        );
      case MapLayerType.landmark:
        return const _LayerPalette(
          fill: '#FFFFFF',
          fillOpacity: 0.95,
          line: '#5B6B57',
          lineWidth: 1.2,
        );
      default:
        return const _LayerPalette(fill: '#B9C3AE', line: '#94A38C');
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

  const _LayerPalette({
    required this.fill,
    this.fillOpacity = 0.8,
    required this.line,
    this.lineWidth = 1.0,
    this.lineOpacity = 0.9,
  });
}
