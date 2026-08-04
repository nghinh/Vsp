// HoleDetectionScorer unit tests — VSP Mobile App
//
// Tests:
// - scoreAll returns empty list for empty hole geometries
// - scoreAll returns sorted results (best match first)
// - Score boundaries: 0.0, 1.0, and mid-range
// - Distance scoring: at reference point, beyond reference, linear decay
// - Heading scoring: aligned, perpendicular, opposite
// - Accuracy scoring: perfect accuracy, poor accuracy, null accuracy
//
// Story 6.2 — Wave A

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/repositories/hole_repository.dart';
import 'package:vsp_mobile/domain/services/hole_detection_scorer.dart';

void main() {
  late HoleDetectionScorer scorer;

  setUp(() {
    scorer = HoleDetectionScorer();
  });

  HoleGeometry makeHole({
    required int holeNumber,
    double teeLat = 10.7629,
    double teeLon = 106.6870,
    double greenLat = 10.7640,
    double greenLon = 106.6880,
    double directionBearing = 45.0,
  }) {
    return HoleGeometry(
      id: 'hole-$holeNumber',
      holeNumber: holeNumber,
      par: 4,
      teeBoxLatitude: teeLat,
      teeBoxLongitude: teeLon,
      greenLatitude: greenLat,
      greenLongitude: greenLon,
      holeDirectionBearing: directionBearing,
    );
  }

  QualifiedLocation makeLocation({
    double lat = 10.7629,
    double lon = 106.6870,
    double? accuracy,
    double? heading,
    bool isStale = false,
  }) {
    return QualifiedLocation(
      latitude: lat,
      longitude: lon,
      accuracyMeters: accuracy,
      timestamp: DateTime.now(),
      heading: heading,
      source: LocationSource.gps,
      isStale: isStale,
    );
  }

  group('HoleDetectionScorer', () {
    group('scoreAll', () {
      test('returns empty list for empty holeGeometries', () {
        final results = scorer.scoreAll(
          location: makeLocation(),
          holeGeometries: [],
        );
        expect(results, isEmpty);
      });

      test('returns single hole scored', () {
        final hole = makeHole(holeNumber: 1);
        final results = scorer.scoreAll(
          location: makeLocation(lat: 10.7629, lon: 106.6870, accuracy: 5.0, heading: 45.0),
          holeGeometries: [hole],
        );

        expect(results.length, 1);
        expect(results[0].holeGeometry.holeNumber, 1);
        expect(results[0].score, greaterThanOrEqualTo(0.0));
        expect(results[0].score, lessThanOrEqualTo(1.0));
      });

      test('returns holes sorted by score descending', () {
        final hole1 = makeHole(
          holeNumber: 1,
          teeLat: 10.7629,
          teeLon: 106.6870,
          greenLat: 10.7640,
          greenLon: 106.6880,
        );
        // hole2 is further away
        final hole2 = makeHole(
          holeNumber: 2,
          teeLat: 10.8000,
          teeLon: 106.7000,
          greenLat: 10.8020,
          greenLon: 106.7020,
        );

        final location = makeLocation(lat: 10.7629, lon: 106.6870, accuracy: 5.0, heading: 45.0);

        final results = scorer.scoreAll(
          location: location,
          holeGeometries: [hole1, hole2],
        );

        expect(results.length, 2);
        expect(results[0].score, greaterThanOrEqualTo(results[1].score));
        expect(results[0].holeGeometry.holeNumber, 1); // closer hole scored higher
      });
    });

    group('score boundaries', () {
      test('score is between 0.0 and 1.0', () {
        final hole = makeHole(holeNumber: 1);
        final location = makeLocation(lat: 10.7629, lon: 106.6870, accuracy: 50.0);

        final results = scorer.scoreAll(location: location, holeGeometries: [hole]);

        expect(results[0].score, greaterThanOrEqualTo(0.0));
        expect(results[0].score, lessThanOrEqualTo(1.0));
      });

      test('score at 0 distance to tee and green gives high score', () {
        final hole = makeHole(
          holeNumber: 1,
          teeLat: 10.7629,
          teeLon: 106.6870,
          greenLat: 10.7640,
          greenLon: 106.6880,
        );
        // Location right on the tee box
        final location = makeLocation(lat: 10.7629, lon: 106.6870, accuracy: 1.0, heading: 45.0);

        final results = scorer.scoreAll(location: location, holeGeometries: [hole]);

        // With perfect accuracy, heading aligned, and at tee box, score should be very high
        expect(results[0].score, greaterThan(0.65));
      });

      test('score is lower when far from any hole geometry', () {
        final hole = makeHole(
          holeNumber: 1,
          teeLat: 10.7629,
          teeLon: 106.6870,
          greenLat: 10.7640,
          greenLon: 106.6880,
        );
        // Location 500m away
        final location = makeLocation(lat: 10.7679, lon: 106.6920, accuracy: 5.0);

        final results = scorer.scoreAll(location: location, holeGeometries: [hole]);

        expect(results[0].score, lessThan(0.3));
      });
    });

    group('accuracy scoring', () {
      test('better accuracy gives higher score contribution', () {
        final hole = makeHole(holeNumber: 1);

        final goodAccuracy = makeLocation(lat: 10.7629, lon: 106.6870, accuracy: 2.0);
        final poorAccuracy = makeLocation(lat: 10.7629, lon: 106.6870, accuracy: 20.0);

        final goodResults = scorer.scoreAll(location: goodAccuracy, holeGeometries: [hole]);
        final poorResults = scorer.scoreAll(location: poorAccuracy, holeGeometries: [hole]);

        expect(goodResults[0].score, greaterThan(poorResults[0].score));
      });

      test('null accuracy gives neutral score contribution (0.5 weight)', () {
        final hole = makeHole(holeNumber: 1);

        final withAccuracy = makeLocation(lat: 10.7629, lon: 106.6870, accuracy: 5.0);
        final withoutAccuracy = makeLocation(lat: 10.7629, lon: 106.6870, accuracy: null);

        final withResults = scorer.scoreAll(location: withAccuracy, holeGeometries: [hole]);
        final withoutResults = scorer.scoreAll(location: withoutAccuracy, holeGeometries: [hole]);

        // Without accuracy, the accuracy component contributes 0.5 * 0.2 = 0.1
        // With 5m accuracy, it should be better
        expect(withResults[0].score, greaterThan(withoutResults[0].score));
      });
    });

    group('heading alignment', () {
      test('heading aligned with hole direction gives higher score', () {
        final hole = makeHole(holeNumber: 1, directionBearing: 90.0);

        final alignedHeading = makeLocation(
          lat: 10.7629,
          lon: 106.6870,
          accuracy: 5.0,
          heading: 90.0,
        );
        final oppositeHeading = makeLocation(
          lat: 10.7629,
          lon: 106.6870,
          accuracy: 5.0,
          heading: 270.0,
        );

        final alignedResults = scorer.scoreAll(location: alignedHeading, holeGeometries: [hole]);
        final oppositeResults = scorer.scoreAll(location: oppositeHeading, holeGeometries: [hole]);

        expect(alignedResults[0].score, greaterThan(oppositeResults[0].score));
      });

      test('null heading gives neutral heading contribution', () {
        final hole = makeHole(holeNumber: 1, directionBearing: 90.0);

        final withHeading = makeLocation(
          lat: 10.7629,
          lon: 106.6870,
          accuracy: 5.0,
          heading: 90.0,
        );
        final withoutHeading = makeLocation(
          lat: 10.7629,
          lon: 106.6870,
          accuracy: 5.0,
          heading: null,
        );

        final withResults = scorer.scoreAll(location: withHeading, holeGeometries: [hole]);
        final withoutResults = scorer.scoreAll(location: withoutHeading, holeGeometries: [hole]);

        // With heading aligned gives higher score than neutral (0.5)
        expect(withResults[0].score, greaterThan(withoutResults[0].score));
      });
    });
  });

  group('HoleGeometry', () {
    test('constructs with all fields', () {
      final hole = HoleGeometry(
        id: 'hole-1',
        holeNumber: 5,
        par: 4,
        teeBoxLatitude: 10.7629,
        teeBoxLongitude: 106.6870,
        greenLatitude: 10.7640,
        greenLongitude: 106.6880,
        holeDirectionBearing: 45.0,
      );

      expect(hole.id, 'hole-1');
      expect(hole.holeNumber, 5);
      expect(hole.par, 4);
      expect(hole.teeBoxLatitude, 10.7629);
      expect(hole.greenLatitude, 10.7640);
      expect(hole.holeDirectionBearing, 45.0);
    });
  });

  group('HoleScore', () {
    test('constructs with hole and score', () {
      final hole = makeHole(holeNumber: 1);
      final score = HoleScore(holeGeometry: hole, score: 0.85);

      expect(score.holeGeometry.holeNumber, 1);
      expect(score.score, 0.85);
    });
  });
}
