// BagDTO unit tests — VSP Mobile App
//
// Tests cover:
// - AC-1: BagDTO and ClubDTO parse all fields from API JSON
// - AC-1: serialization round-trip (toJson -> fromJson)
// - AC-2: isActive flag is correctly parsed
// - AC-3: hasMinimumClubData() returns true when at least one club has carryDistance
// - AC-3: ClubDTO.hasMinimumData() checks clubType + carryDistance
// - Display helpers format distances correctly

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/bag/data/bag_dto.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;

void main() {
  group('ClubDTO', () {
    group('fromJson — AC-1: all fields parsed', () {
      test('parses full club response from API', () {
        final json = {
          'id': 1,
          'golfBagId': 5,
          'clubType': 'DRIVER',
          'loft': 10.5,
          'carryDistance': 220.0,
          'totalDistance': 235.0,
          'dispersion': 5.2,
          'shaft': 'Graphite, Regular Flex',
          'useDate': '2026-01-15',
          'createdAt': '2026-08-01T10:00:00Z',
          'updatedAt': '2026-08-02T12:30:00Z',
        };

        final dto = ClubDTO.fromJson(json);

        expect(dto.id, 1);
        expect(dto.golfBagId, 5);
        expect(dto.clubType, ClubType.driver);
        expect(dto.loft, 10.5);
        expect(dto.carryDistance, 220.0);
        expect(dto.totalDistance, 235.0);
        expect(dto.dispersion, 5.2);
        expect(dto.shaft, 'Graphite, Regular Flex');
        expect(dto.useDate, DateTime.parse('2026-01-15'));
        expect(dto.createdAt, DateTime.parse('2026-08-01T10:00:00Z'));
        expect(dto.updatedAt, DateTime.parse('2026-08-02T12:30:00Z'));
      });

      test('defaults to IRON when clubType is null', () {
        final json = {'id': 1, 'golfBagId': 5};

        final dto = ClubDTO.fromJson(json);

        expect(dto.clubType, ClubType.iron);
      });

      test('handles null optional fields', () {
        final json = {'id': 1, 'golfBagId': 5, 'clubType': 'WEDGE'};

        final dto = ClubDTO.fromJson(json);

        expect(dto.loft, isNull);
        expect(dto.carryDistance, isNull);
        expect(dto.totalDistance, isNull);
        expect(dto.dispersion, isNull);
        expect(dto.shaft, isNull);
        expect(dto.useDate, isNull);
      });
    });

    group('toJson — serialization round-trip', () {
      test('serializes all fields correctly', () {
        final dto = ClubDTO(
          id: 1,
          golfBagId: 5,
          clubType: ClubType.iron,
          loft: 25.0,
          carryDistance: 150.0,
          totalDistance: 160.0,
          dispersion: 4.5,
          shaft: 'Steel, Stiff Flex',
          useDate: DateTime.parse('2026-02-01'),
          createdAt: DateTime.parse('2026-08-01T10:00:00Z'),
          updatedAt: DateTime.parse('2026-08-02T12:30:00Z'),
        );

        final json = dto.toJson();
        final roundTrip = ClubDTO.fromJson(json);

        expect(roundTrip.id, dto.id);
        expect(roundTrip.golfBagId, dto.golfBagId);
        expect(roundTrip.clubType, dto.clubType);
        expect(roundTrip.loft, dto.loft);
        expect(roundTrip.carryDistance, dto.carryDistance);
        expect(roundTrip.totalDistance, dto.totalDistance);
        expect(roundTrip.dispersion, dto.dispersion);
        expect(roundTrip.shaft, dto.shaft);
        expect(roundTrip.useDate, dto.useDate);
      });
    });

    group('AC-3: hasMinimumData()', () {
      test('returns true when clubType and carryDistance are set', () {
        final dto = ClubDTO(
          id: 1,
          golfBagId: 5,
          clubType: ClubType.driver,
          carryDistance: 220.0,
        );
        expect(dto.hasMinimumData, isTrue);
      });

      test('returns false when carryDistance is null', () {
        final dto = ClubDTO(
          id: 1,
          golfBagId: 5,
          clubType: ClubType.driver,
          // carryDistance: null
        );
        expect(dto.hasMinimumData, isFalse);
      });

      test('returns true for any clubType with carryDistance', () {
        for (final type in ClubType.values) {
          final dto = ClubDTO(
            id: 1,
            golfBagId: 5,
            clubType: type,
            carryDistance: 100.0,
          );
          expect(dto.hasMinimumData, isTrue, reason: '$type should qualify');
        }
      });
    });

    group('display helpers', () {
      test('formatCarryDistance reads in metres for a metric golfer', () {
        final dto = ClubDTO(
          id: 1,
          golfBagId: 5,
          clubType: ClubType.driver,
          carryDistance: 220.0,
        );
        expect(dto.formatCarryDistance(DistanceUnit.meters), '220 m');
      });

      test('formatCarryDistance converts for a golfer who reads yards', () {
        final dto = ClubDTO(
          id: 1,
          golfBagId: 5,
          clubType: ClubType.driver,
          carryDistance: 220.0,
        );
        // 220 * 1.09361 = ~240.59 → rounded to 241
        expect(dto.formatCarryDistance(DistanceUnit.yards), '241 yd');
      });

      test('formatCarryDistance returns — for null', () {
        final dto = ClubDTO(id: 1, golfBagId: 5, clubType: ClubType.driver);
        expect(dto.formatCarryDistance(DistanceUnit.meters), '—');
      });

      test('formatTotalDistance reads in metres for a metric golfer', () {
        final dto = ClubDTO(
          id: 1,
          golfBagId: 5,
          clubType: ClubType.iron,
          totalDistance: 160.0,
        );
        expect(dto.formatTotalDistance(DistanceUnit.meters), '160 m');
      });

      test('formatTotalDistance converts for a golfer who reads yards', () {
        final dto = ClubDTO(
          id: 1,
          golfBagId: 5,
          clubType: ClubType.iron,
          totalDistance: 160.0,
        );
        // 160 * 1.09361 = ~174.98 → rounded to 175
        expect(dto.formatTotalDistance(DistanceUnit.yards), '175 yd');
      });
    });

    group('ClubType enum', () {
      test('fromString handles case-insensitivity', () {
        expect(ClubType.fromString('DRIVER'), ClubType.driver);
        expect(ClubType.fromString('driver'), ClubType.driver);
        expect(ClubType.fromString('WOOD'), ClubType.wood);
        expect(ClubType.fromString('hybrid'), ClubType.hybrid);
        expect(ClubType.fromString('IRON'), ClubType.iron);
        expect(ClubType.fromString('wedge'), ClubType.wedge);
        expect(ClubType.fromString('PUTTER'), ClubType.putter);
      });

      test('fromString defaults to iron for unknown', () {
        expect(ClubType.fromString('unknown'), ClubType.iron);
      });

      test('label returns human-readable name', () {
        expect(ClubType.driver.displayName, 'Driver');
        expect(ClubType.wood.displayName, 'Fairway Wood');
        expect(ClubType.hybrid.displayName, 'Hybrid');
        expect(ClubType.iron.displayName, 'Iron');
        expect(ClubType.wedge.displayName, 'Wedge');
        expect(ClubType.putter.displayName, 'Putter');
      });
    });
  });

  group('BagDTO', () {
    group('fromJson — AC-1 and AC-2', () {
      test('parses full bag response with clubs', () {
        final json = {
          'id': 1,
          'golferAccountId': 42,
          'name': 'My Bag',
          'isActive': true,
          'clubs': [
            {
              'id': 1,
              'golfBagId': 1,
              'clubType': 'DRIVER',
              'loft': 10.5,
              'carryDistance': 220.0,
              'totalDistance': 235.0,
              'dispersion': 5.2,
              'shaft': 'Graphite',
              'useDate': '2026-01-15',
              'createdAt': '2026-08-01T10:00:00Z',
              'updatedAt': '2026-08-02T12:30:00Z',
            },
          ],
          'createdAt': '2026-08-01T10:00:00Z',
          'updatedAt': '2026-08-02T12:30:00Z',
        };

        final dto = BagDTO.fromJson(json);

        expect(dto.id, 1);
        expect(dto.golferAccountId, 42);
        expect(dto.name, 'My Bag');
        expect(dto.isActive, isTrue);
        expect(dto.clubs.length, 1);
        expect(dto.clubs[0].clubType, ClubType.driver);
        expect(dto.clubs[0].carryDistance, 220.0);
      });

      test('defaults isActive to false when null', () {
        final json = {'id': 1, 'golferAccountId': 42, 'name': 'Test Bag'};

        final dto = BagDTO.fromJson(json);

        expect(dto.isActive, isFalse);
      });

      test('rejects a response without required name', () {
        final json = {'id': 1, 'golferAccountId': 42};

        expect(() => BagDTO.fromJson(json), throwsA(isA<TypeError>()));
      });

      test('handles empty clubs list', () {
        final json = {
          'id': 1,
          'golferAccountId': 42,
          'name': 'Empty Bag',
          'isActive': false,
          'clubs': null,
        };

        final dto = BagDTO.fromJson(json);

        expect(dto.clubs, isEmpty);
      });
    });

    group('AC-3: hasMinimumClubData', () {
      test('returns true when at least one club has carryDistance', () {
        final dto = BagDTO(
          id: 1,
          golferAccountId: 42,
          name: 'Test Bag',
          isActive: true,
          clubs: [
            ClubDTO(id: 1, golfBagId: 1, clubType: ClubType.driver),
            ClubDTO(
              id: 2,
              golfBagId: 1,
              clubType: ClubType.iron,
              carryDistance: 150.0,
            ),
          ],
        );
        expect(dto.hasMinimumClubData, isTrue);
      });

      test('returns false when no club has carryDistance', () {
        final dto = BagDTO(
          id: 1,
          golferAccountId: 42,
          name: 'Test Bag',
          isActive: true,
          clubs: [
            ClubDTO(id: 1, golfBagId: 1, clubType: ClubType.driver),
            ClubDTO(id: 2, golfBagId: 1, clubType: ClubType.iron),
          ],
        );
        expect(dto.hasMinimumClubData, isFalse);
      });

      test('returns false when bag has no clubs', () {
        final dto = BagDTO(
          id: 1,
          golferAccountId: 42,
          name: 'Empty Bag',
          isActive: true,
          clubs: const [],
        );
        expect(dto.hasMinimumClubData, isFalse);
      });
    });

    group('toJson — serialization round-trip', () {
      test('serializes all fields correctly', () {
        final club = ClubDTO(
          id: 1,
          golfBagId: 1,
          clubType: ClubType.wedge,
          loft: 52.0,
          carryDistance: 100.0,
          totalDistance: 105.0,
          dispersion: 3.5,
          shaft: 'Steel',
          useDate: DateTime.parse('2026-03-01'),
          createdAt: DateTime.parse('2026-08-01T10:00:00Z'),
          updatedAt: DateTime.parse('2026-08-02T12:30:00Z'),
        );
        final dto = BagDTO(
          id: 1,
          golferAccountId: 42,
          name: 'Competition Bag',
          isActive: true,
          clubs: [club],
          createdAt: DateTime.parse('2026-08-01T10:00:00Z'),
          updatedAt: DateTime.parse('2026-08-02T12:30:00Z'),
        );

        final json = dto.toJson();
        final roundTrip = BagDTO.fromJson(json);

        expect(roundTrip.id, dto.id);
        expect(roundTrip.golferAccountId, dto.golferAccountId);
        expect(roundTrip.name, dto.name);
        expect(roundTrip.isActive, dto.isActive);
        expect(roundTrip.clubs.length, 1);
        expect(roundTrip.clubs[0].clubType, ClubType.wedge);
      });
    });
  });

  group('CreateClubRequest', () {
    test('toJson omits null fields', () {
      final request = CreateClubRequest(clubType: 'DRIVER', loft: 10.5);

      final json = request.toJson();

      expect(json['clubType'], 'DRIVER');
      expect(json['loft'], 10.5);
      expect(json.containsKey('carryDistance'), isFalse);
      expect(json.containsKey('shaft'), isFalse);
    });

    test('fromDto creates request from ClubDTO', () {
      final dto = ClubDTO(
        id: 1,
        golfBagId: 1,
        clubType: ClubType.iron,
        loft: 25.0,
        carryDistance: 150.0,
        totalDistance: 160.0,
        dispersion: 4.5,
        shaft: 'Steel',
        useDate: DateTime.parse('2026-02-01'),
      );

      final request = CreateClubRequest.fromDto(dto);

      expect(request.clubType, 'IRON');
      expect(request.loft, 25.0);
      expect(request.carryDistance, 150.0);
      expect(request.totalDistance, 160.0);
      expect(request.dispersion, 4.5);
      expect(request.shaft, 'Steel');
      expect(request.useDate, '2026-02-01');
    });

    test('toJson serializes all provided fields', () {
      const request = CreateClubRequest(
        clubType: 'WEDGE',
        loft: 52.0,
        carryDistance: 100.0,
        shaft: 'Graphite',
      );

      expect(request.toJson(), {
        'clubType': 'WEDGE',
        'loft': 52.0,
        'carryDistance': 100.0,
        'shaft': 'Graphite',
      });
    });
  });

  group('UpdateClubRequest', () {
    test('toJson omits null fields (partial update)', () {
      final request = UpdateClubRequest(loft: 26.0, carryDistance: 155.0);

      final json = request.toJson();

      expect(json.containsKey('clubType'), isFalse);
      expect(json['loft'], 26.0);
      expect(json['carryDistance'], 155.0);
      expect(json.containsKey('shaft'), isFalse);
    });

    test('toJson serializes only provided fields', () {
      const request = UpdateClubRequest(clubType: 'HYBRID', dispersion: 4.0);

      expect(request.toJson(), {'clubType': 'HYBRID', 'dispersion': 4.0});
    });
  });

  group('CreateBagRequest', () {
    test('toJson returns name only', () {
      const request = CreateBagRequest(name: 'New Bag');

      final json = request.toJson();

      expect(json['name'], 'New Bag');
    });
  });

  group('UpdateBagRequest', () {
    test('toJson omits null fields', () {
      const request = UpdateBagRequest(name: 'Renamed Bag');

      final json = request.toJson();

      expect(json['name'], 'Renamed Bag');
      expect(json.containsKey('isActive'), isFalse);
    });

    test('toJson includes isActive when set', () {
      const request = UpdateBagRequest(isActive: true);

      final json = request.toJson();

      expect(json['isActive'], isTrue);
      expect(json.containsKey('name'), isFalse);
    });
  });
}
