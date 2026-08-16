// The line a golfer plays along.
//
// Most holes in this database are a tee point and a green point and nothing
// else — the map drew them as two dots, which is a picture of nothing. A line
// between them with the distance on it is the one thing a golfer wants from a
// hole map, and it needs no polygons at all.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_geojson.dart';

void main() {
  const tee = LatLng(latitude: 21.0368, longitude: 105.8963);
  const green = LatLng(latitude: 21.0350, longitude: 105.8911);
  const target = LatLng(latitude: 21.0360, longitude: 105.8940);

  List<Map<String, dynamic>> featuresOf(Map<String, dynamic> collection) =>
      (collection['features'] as List).cast<Map<String, dynamic>>();

  test('one leg draws one line from the golfer to the flag', () {
    final overlay = HoleMapGeoJson.overlay(
      playLine: [PlayLeg(from: tee, to: green, label: '514 yd')],
    );

    final lines = featuresOf(overlay)
        .where((f) => (f['geometry'] as Map)['type'] == 'LineString')
        .toList();
    expect(lines, hasLength(1));
    expect(
      (lines.first['properties'] as Map)['layerType'],
      HoleMapFeatureKind.playLine,
    );
    // Longitude first, as GeoJSON requires — swapping them puts the hole in
    // the Gulf of Tonkin.
    final coords = ((lines.first['geometry'] as Map)['coordinates'] as List);
    expect(coords.first, [105.8963, 21.0368]);
    expect(coords.last, [105.8911, 21.0350]);
  });

  test('a placed target splits the line in two', () {
    final overlay = HoleMapGeoJson.overlay(
      playLine: [
        PlayLeg(from: tee, to: target, label: '239 yd'),
        PlayLeg(from: target, to: green, label: '240 yd'),
      ],
    );

    final lines = featuresOf(overlay)
        .where((f) => (f['geometry'] as Map)['type'] == 'LineString');
    expect(lines, hasLength(2));
  });

  test('no line at all where the hole has no green to aim at', () {
    final overlay = HoleMapGeoJson.overlay();

    expect(featuresOf(overlay), isEmpty);
  });

  /// The map has to draw with no signal, so the numbers are Flutter widgets
  /// and never map symbols — a symbol layer needs a glyph endpoint.
  test('the line carries no text of its own', () {
    final overlay = HoleMapGeoJson.overlay(
      playLine: [PlayLeg(from: tee, to: green, label: '514 yd')],
    );

    expect(
      featuresOf(overlay).any(
        (f) => (f['properties'] as Map).containsKey('label'),
      ),
      isFalse,
    );
  });
}
