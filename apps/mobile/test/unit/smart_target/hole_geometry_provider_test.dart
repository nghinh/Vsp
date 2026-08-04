// HoleGeometryProvider Unit Tests — VSP Mobile App
//
// Tests for InMemoryHoleGeometryProvider stub.
//
// Story 11.4 — Slice 1: Unit Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/analytics/smart_target/repositories/hole_geometry_provider.dart';
import 'package:vsp_mobile/domain/analytics/smart_target/repositories/in_memory_hole_geometry_provider.dart';
import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';

void main() {
  late InMemoryHoleGeometryProvider provider;

  final seedHoles = [
    HoleContext(
      holeId: 'hole-1',
      holeNumber: 1,
      par: 4,
      pinPosition: const LatLng(latitude: 37.5, longitude: -122.3),
      teeBox: const LatLng(latitude: 37.4, longitude: -122.3),
      fairwayCenterline: const [
        LatLng(latitude: 37.4, longitude: -122.3),
        LatLng(latitude: 37.45, longitude: -122.3),
        LatLng(latitude: 37.5, longitude: -122.3),
      ],
      greenPolygon: const [
        LatLng(latitude: 37.5, longitude: -122.31),
        LatLng(latitude: 37.51, longitude: -122.3),
        LatLng(latitude: 37.5, longitude: -122.29),
        LatLng(latitude: 37.5, longitude: -122.31),
      ],
      hazards: [
        HoleHazardSummary(
          id: 'hazard-1',
          name: 'Bunker 1',
          type: 'bunker',
          polygon: const [
            LatLng(latitude: 37.45, longitude: -122.31),
            LatLng(latitude: 37.46, longitude: -122.31),
            LatLng(latitude: 37.46, longitude: -122.30),
            LatLng(latitude: 37.45, longitude: -122.30),
          ],
        ),
        HoleHazardSummary(
          id: 'hazard-2',
          name: 'Water Hole 1',
          type: 'water',
          polygon: const [
            LatLng(latitude: 37.47, longitude: -122.30),
            LatLng(latitude: 37.48, longitude: -122.30),
            LatLng(latitude: 37.48, longitude: -122.29),
            LatLng(latitude: 37.47, longitude: -122.29),
          ],
        ),
      ],
    ),
    HoleContext(
      holeId: 'hole-2',
      holeNumber: 2,
      par: 5,
      pinPosition: const LatLng(latitude: 37.6, longitude: -122.4),
      teeBox: const LatLng(latitude: 37.5, longitude: -122.3),
      fairwayCenterline: const [],
      greenPolygon: const [],
      hazards: const [],
    ),
  ];

  setUp(() {
    provider = InMemoryHoleGeometryProvider(seeds: seedHoles);
  });

  group('HoleHazardSummary', () {
    test('isBunker returns true for bunker type', () {
      final hazard = HoleHazardSummary(
        id: 'h1',
        name: 'Bunker',
        type: 'bunker',
        polygon: const [],
      );
      expect(hazard.isBunker, true);
      expect(hazard.isWater, false);
      expect(hazard.isOb, false);
    });

    test('isWater returns true for water and penalty types', () {
      final water = HoleHazardSummary(
        id: 'h1',
        name: 'Water',
        type: 'water',
        polygon: const [],
      );
      final penalty = HoleHazardSummary(
        id: 'h2',
        name: 'Penalty',
        type: 'penalty',
        polygon: const [],
      );
      expect(water.isWater, true);
      expect(penalty.isWater, true);
    });

    test('isOb returns true for ob type', () {
      final ob = HoleHazardSummary(
        id: 'h1',
        name: 'OB',
        type: 'ob',
        polygon: const [],
      );
      expect(ob.isOb, true);
    });
  });

  group('HoleContext', () {
    test('totalHazardCount returns correct count', () {
      expect(seedHoles[0].totalHazardCount, 2);
      expect(seedHoles[1].totalHazardCount, 0);
    });

    test('bunkers returns only bunker hazards', () {
      final bunkers = seedHoles[0].bunkers;
      expect(bunkers.length, 1);
      expect(bunkers.first.type, 'bunker');
    });

    test('waterHazards returns water and penalty hazards', () {
      final water = seedHoles[0].waterHazards;
      expect(water.length, 1);
      expect(water.first.type, 'water');
    });

    test('obHazards returns only OB hazards', () {
      final ob = seedHoles[0].obHazards;
      expect(ob, isEmpty);
    });

    test('holeLengthMeters computes from centerline', () {
      // Seed hole 1 has a 3-point centerline.
      final length = seedHoles[0].holeLengthMeters;
      expect(length, greaterThan(0));
    });

    test('holeLengthMeters falls back to tee-to-pin distance', () {
      // Seed hole 2 has empty centerline.
      final length = seedHoles[1].holeLengthMeters;
      expect(length, greaterThan(0));
    });
  });

  group('InMemoryHoleGeometryProvider', () {
    test('getHoleContext returns correct hole', () async {
      final hole = await provider.getHoleContext('hole-1');
      expect(hole, isNotNull);
      expect(hole!.holeNumber, 1);
      expect(hole.par, 4);
      expect(hole.totalHazardCount, 2);
    });

    test('getHoleContext returns null for unknown hole', () async {
      final hole = await provider.getHoleContext('hole-unknown');
      expect(hole, isNull);
    });

    test('getHoleContextByNumber uses courseId:holeNumber key', () async {
      final hole = await provider.getHoleContextByNumber('my-course', 1);
      // Stub uses "courseId:holeNumber" pattern.
      final holeDirect = await provider.getHoleContext('my-course:1');
      expect(hole, isNull); // Not found with default stub key
      // Add it properly.
      provider.addHole(HoleContext(
        holeId: 'my-course:1',
        holeNumber: 1,
        par: 4,
        pinPosition: const LatLng(latitude: 37.5, longitude: -122.3),
        teeBox: const LatLng(latitude: 37.4, longitude: -122.3),
        fairwayCenterline: const [],
        greenPolygon: const [],
        hazards: const [],
      ));
      final hole2 = await provider.getHoleContextByNumber('my-course', 1);
      expect(hole2, isNotNull);
    });

    test('hasGeometry returns true for known hole', () async {
      final has = await provider.hasGeometry('hole-1');
      expect(has, true);
    });

    test('hasGeometry returns false for unknown hole', () async {
      final has = await provider.hasGeometry('hole-unknown');
      expect(has, false);
    });

    test('addHole adds new hole', () async {
      provider.addHole(HoleContext(
        holeId: 'hole-new',
        holeNumber: 19,
        par: 3,
        pinPosition: const LatLng(latitude: 37.7, longitude: -122.5),
        teeBox: const LatLng(latitude: 37.65, longitude: -122.5),
        fairwayCenterline: const [],
        greenPolygon: const [],
        hazards: const [],
      ));

      final hole = await provider.getHoleContext('hole-new');
      expect(hole, isNotNull);
      expect(hole!.holeNumber, 19);
    });

    test('clear removes all holes', () async {
      provider.clear();
      final hole = await provider.getHoleContext('hole-1');
      expect(hole, isNull);
    });
  });
}
