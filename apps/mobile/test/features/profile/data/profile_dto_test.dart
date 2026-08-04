// ProfileDTO unit tests — VSP Mobile App
//
// Tests cover:
// - AC-1: fromJson parses all fields correctly
// - AC-2: toDisplayDistance does NOT modify canonical meters
// - AC-2: formatDistance formats with correct unit suffix
// - Serialization round-trip (toJson -> fromJson)

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart';

void main() {
  group('ProfileDTO', () {
    group('fromJson — AC-1: all fields parsed', () {
      test('parses full profile response from API', () {
        final json = {
          'id': 1,
          'golferAccountId': 42,
          'handicap': 12.5,
          'homeClub': 'Vietnam Golf & Country Club',
          'distanceUnit': 'YARDS',
          'dominantHand': 'LEFT',
          'skillLevel': 'ADVANCED',
          'targetScore': 88,
          'driverDistance': 220.0,
          'swingSpeed': 95.0,
          'gender': 'MALE',
          'birthYear': 1985,
          'country': 'Vietnam',
          'imageUrl': 'https://cdn.vsp.example.com/profiles/42/avatar.jpg',
          'createdAt': '2026-08-01T10:00:00Z',
          'updatedAt': '2026-08-02T12:30:00Z',
        };

        final dto = ProfileDTO.fromJson(json);

        expect(dto.id, 1);
        expect(dto.golferAccountId, 42);
        expect(dto.handicap, 12.5);
        expect(dto.homeClub, 'Vietnam Golf & Country Club');
        expect(dto.distanceUnit, DistanceUnit.yards);
        expect(dto.dominantHand, DominantHand.left);
        expect(dto.skillLevel, SkillLevel.advanced);
        expect(dto.targetScore, 88);
        expect(dto.driverDistance, 220.0);
        expect(dto.swingSpeed, 95.0);
        expect(dto.gender, Gender.male);
        expect(dto.birthYear, 1985);
        expect(dto.country, 'Vietnam');
        expect(dto.imageUrl, 'https://cdn.vsp.example.com/profiles/42/avatar.jpg');
        expect(dto.createdAt, DateTime.parse('2026-08-01T10:00:00Z'));
        expect(dto.updatedAt, DateTime.parse('2026-08-02T12:30:00Z'));
      });

      test('defaults to METERS, RIGHT, INTERMEDIATE when fields are null', () {
        final json = {
          'id': 1,
          'golferAccountId': 42,
        };

        final dto = ProfileDTO.fromJson(json);

        expect(dto.distanceUnit, DistanceUnit.meters);
        expect(dto.dominantHand, DominantHand.right);
        expect(dto.skillLevel, SkillLevel.intermediate);
      });

      test('handles null optional fields', () {
        final json = {
          'id': 1,
          'golferAccountId': 42,
          'handicap': null,
          'homeClub': null,
          'driverDistance': null,
          'gender': null,
          'birthYear': null,
          'country': null,
          'imageUrl': null,
        };

        final dto = ProfileDTO.fromJson(json);

        expect(dto.handicap, isNull);
        expect(dto.homeClub, isNull);
        expect(dto.driverDistance, isNull);
        expect(dto.gender, isNull);
        expect(dto.birthYear, isNull);
        expect(dto.country, isNull);
        expect(dto.imageUrl, isNull);
      });
    });

    group('toJson — serialization round-trip', () {
      test('serializes all fields correctly', () {
        final dto = ProfileDTO(
          id: 1,
          golferAccountId: 42,
          handicap: 12.5,
          homeClub: 'Saigon Golf Club',
          distanceUnit: DistanceUnit.yards,
          dominantHand: DominantHand.left,
          skillLevel: SkillLevel.pro,
          targetScore: 85,
          driverDistance: 230.0,
          swingSpeed: 100.0,
          gender: Gender.male,
          birthYear: 1980,
          country: 'Vietnam',
          imageUrl: 'https://cdn.vsp.example.com/profiles/42/avatar.jpg',
          createdAt: DateTime.parse('2026-08-01T10:00:00Z'),
          updatedAt: DateTime.parse('2026-08-02T12:30:00Z'),
        );

        final json = dto.toJson();
        final roundTrip = ProfileDTO.fromJson(json);

        expect(roundTrip.id, dto.id);
        expect(roundTrip.golferAccountId, dto.golferAccountId);
        expect(roundTrip.handicap, dto.handicap);
        expect(roundTrip.homeClub, dto.homeClub);
        expect(roundTrip.distanceUnit, dto.distanceUnit);
        expect(roundTrip.dominantHand, dto.dominantHand);
        expect(roundTrip.skillLevel, dto.skillLevel);
        expect(roundTrip.targetScore, dto.targetScore);
        expect(roundTrip.driverDistance, dto.driverDistance);
        expect(roundTrip.swingSpeed, dto.swingSpeed);
        expect(roundTrip.gender, dto.gender);
        expect(roundTrip.birthYear, dto.birthYear);
        expect(roundTrip.country, dto.country);
        expect(roundTrip.imageUrl, dto.imageUrl);
      });
    });

    group('AC-2: Unit conversion — canonical meters never corrupted', () {
      test('toDisplayDistance returns meters unchanged when unit is METERS', () {
        final dto = ProfileDTO(
          id: 1,
          golferAccountId: 42,
          distanceUnit: DistanceUnit.meters,
        );

        expect(dto.toDisplayDistance(200.0), 200.0);
        expect(dto.toDisplayDistance(250.5), 250.5);
      });

      test('toDisplayDistance converts to yards when unit is YARDS', () {
        final dto = ProfileDTO(
          id: 1,
          golferAccountId: 42,
          distanceUnit: DistanceUnit.yards,
        );

        // 200 meters * 1.09361 = ~218.72 yards
        expect(dto.toDisplayDistance(200.0), closeTo(218.72, 0.01));
        // 220 meters * 1.09361 = ~240.59 yards
        expect(dto.toDisplayDistance(220.0), closeTo(240.59, 0.01));
      });

      test('toDisplayDistance returns 0 for null input', () {
        final dto = ProfileDTO(
          id: 1,
          golferAccountId: 42,
          distanceUnit: DistanceUnit.yards,
        );

        expect(dto.toDisplayDistance(null), 0);
      });

      test('displayDriverDistance applies conversion to stored canonical', () {
        final dtoMeters = ProfileDTO(
          id: 1,
          golferAccountId: 42,
          distanceUnit: DistanceUnit.meters,
          driverDistance: 220.0,
        );
        final dtoYards = ProfileDTO(
          id: 1,
          golferAccountId: 42,
          distanceUnit: DistanceUnit.yards,
          driverDistance: 220.0,
        );

        // Canonical 220m stays 220m when display is meters
        expect(dtoMeters.displayDriverDistance, 220.0);
        // Canonical 220m converts to yards when display is yards
        expect(dtoYards.displayDriverDistance, closeTo(240.59, 0.01));
      });

      test('changing distanceUnit does NOT modify driverDistance', () {
        // Simulate server response: canonical stays 220m even when unit changes to YARDS
        final canonicalMeters = 220.0;
        final dtoYards = ProfileDTO(
          id: 1,
          golferAccountId: 42,
          distanceUnit: DistanceUnit.yards,
          driverDistance: canonicalMeters, // stored as meters canonical
        );

        // The canonical value is unchanged
        expect(dtoYards.driverDistance, canonicalMeters);
        // The display value is converted
        expect(dtoYards.displayDriverDistance, closeTo(240.59, 0.01));
        // Switching back to meters restores original
        final dtoMeters = dtoYards.copyWith(distanceUnit: DistanceUnit.meters);
        expect(dtoMeters.displayDriverDistance, canonicalMeters);
        // The canonical is still intact
        expect(dtoMeters.driverDistance, canonicalMeters);
      });

      test('formatDistance appends correct unit suffix', () {
        final dtoMeters = ProfileDTO(
          id: 1,
          golferAccountId: 42,
          distanceUnit: DistanceUnit.meters,
        );
        final dtoYards = ProfileDTO(
          id: 1,
          golferAccountId: 42,
          distanceUnit: DistanceUnit.yards,
        );

        expect(dtoMeters.formatDistance(220.0), '220 m');
        expect(dtoYards.formatDistance(220.0), '241 yd'); // 220 * 1.09361 rounded
        expect(dtoMeters.formatDistance(null), '—');
      });
    });

    group('UpdateProfileRequest', () {
      test('toJson omits null fields (partial update)', () {
        final request = UpdateProfileRequest(
          handicap: 10.0,
          distanceUnit: 'YARDS',
        );

        final json = request.toJson();

        expect(json.containsKey('handicap'), isTrue);
        expect(json.containsKey('distanceUnit'), isTrue);
        expect(json.containsKey('homeClub'), isFalse);
        expect(json.containsKey('driverDistance'), isFalse);
        expect(json['handicap'], 10.0);
        expect(json['distanceUnit'], 'YARDS');
      });

      test('fromDto creates request from ProfileDTO', () {
        final dto = ProfileDTO(
          id: 1,
          golferAccountId: 42,
          handicap: 11.0,
          homeClub: 'New Club',
          distanceUnit: DistanceUnit.yards,
          dominantHand: DominantHand.left,
          skillLevel: SkillLevel.advanced,
          targetScore: 86,
          driverDistance: 225.0,
          swingSpeed: 98.0,
          gender: Gender.male,
          birthYear: 1982,
          country: 'Vietnam',
          imageUrl: 'https://cdn.vsp.example.com/new.jpg',
        );

        final request = UpdateProfileRequest.fromDto(dto);

        expect(request.handicap, 11.0);
        expect(request.homeClub, 'New Club');
        expect(request.distanceUnit, 'YARDS');
        expect(request.dominantHand, 'LEFT');
        expect(request.skillLevel, 'ADVANCED');
        expect(request.targetScore, 86);
        expect(request.driverDistance, 225.0);
        expect(request.swingSpeed, 98.0);
        expect(request.gender, 'MALE');
        expect(request.birthYear, 1982);
        expect(request.country, 'Vietnam');
        expect(request.imageUrl, 'https://cdn.vsp.example.com/new.jpg');
      });
    });

    group('Enums', () {
      test('DistanceUnit.fromString handles case-insensitivity', () {
        expect(DistanceUnit.fromString('METERS'), DistanceUnit.meters);
        expect(DistanceUnit.fromString('meters'), DistanceUnit.meters);
        expect(DistanceUnit.fromString('YARDS'), DistanceUnit.yards);
        expect(DistanceUnit.fromString('yards'), DistanceUnit.yards);
        expect(DistanceUnit.fromString('unknown'), DistanceUnit.meters); // default
      });

      test('DominantHand.fromString handles case-insensitivity', () {
        expect(DominantHand.fromString('LEFT'), DominantHand.left);
        expect(DominantHand.fromString('left'), DominantHand.left);
        expect(DominantHand.fromString('RIGHT'), DominantHand.right);
        expect(DominantHand.fromString('unknown'), DominantHand.right); // default
      });

      test('SkillLevel.fromString handles case-insensitivity', () {
        expect(SkillLevel.fromString('BEGINNER'), SkillLevel.beginner);
        expect(SkillLevel.fromString('intermediate'), SkillLevel.intermediate);
        expect(SkillLevel.fromString('ADVANCED'), SkillLevel.advanced);
        expect(SkillLevel.fromString('PRO'), SkillLevel.pro);
        expect(SkillLevel.fromString('unknown'), SkillLevel.intermediate); // default
      });

      test('Gender.fromString handles case-insensitivity', () {
        expect(Gender.fromString('MALE'), Gender.male);
        expect(Gender.fromString('female'), Gender.female);
        expect(Gender.fromString('OTHER'), Gender.other);
        expect(Gender.fromString('unknown'), Gender.other); // default
      });
    });
  });
}
