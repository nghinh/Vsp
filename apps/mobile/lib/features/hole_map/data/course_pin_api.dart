// Today's pin — VSP Mobile App
//
// The greenkeeper has been publishing flag positions from the portal since the
// operations module landed, and the golfer they matter to could not see them:
// every pin route was under /admin. This reads the golfer-facing one.
//
// Coordinates arrive already decoded. The column is WKB and this app has no
// decoder for it, so the server — which has PostGIS — sends latitude and
// longitude instead.

import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/features/hole_map/domain/pin_entity.dart';

class CoursePinApi {
  CoursePinApi({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Today's flag per hole number. Empty where the club publishes none,
  /// which is most clubs — a course with no greenkeeper on the portal is not
  /// a failure, it is the ordinary case.
  Future<Map<int, PinEntity>> forCourse(String courseId) async {
    final json = await _apiClient.get('/courses/$courseId/pins');
    final pins = <int, PinEntity>{};
    for (final item in json as List<dynamic>) {
      final map = item as Map<String, dynamic>;
      final holeNumber = map['holeNumber'] as int?;
      final lat = (map['latitude'] as num?)?.toDouble();
      final lng = (map['longitude'] as num?)?.toDouble();
      if (holeNumber == null || lat == null || lng == null) continue;
      pins[holeNumber] = PinEntity(
        holeId: '$courseId-$holeNumber',
        holeNumber: holeNumber,
        latitude: lat,
        longitude: lng,
        // Published by the club's own greenkeeper: official, as opposed to
        // the estimated centre of a green polygon.
        source: PinSource.official,
        confidence: (map['confidence'] as num?)?.toDouble(),
        expiryDate: map['expiresAt'] == null
            ? null
            : DateTime.tryParse(map['expiresAt'] as String),
      );
    }
    return pins;
  }
}
