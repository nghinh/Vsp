// Tests for the hole nobody downloaded.
//
// A golfer opened Long Biên's 1st and was shown a bare satellite photograph
// under the words "this hole has no surveyed map". The server had eight
// bunkers, two fairway segments, four tees and an OpenStreetMap green for that
// hole and was never asked: the traced-shapes fetch sat after the package
// branch, so the only holes that could reach it were holes on courses already
// downloaded — the ones least likely to need it.
//
// Course 1351 is Long Biên's Đường A on the live deployment. The properties in
// `_serverResponse` are copied from what it actually returns, `source:
// golfseg` and all, because the parser reads those strings.

import 'package:bloc_test/bloc_test.dart';
import 'package:course_package/course_package.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/features/hole_map/data/hole_feature_api.dart';
import 'package:vsp_mobile/features/hole_map/data/hole_map_repository.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/domain/map_layer.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_bloc.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_event.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_state.dart';

/// A device holding no packages at all, which is the normal device.
class _NoPackages implements HoleMapRepository {
  @override
  Future<HoleMapEntity?> getHoleMap({
    required String packageId,
    required String courseId,
    required String courseName,
    required int holeNumber,
  }) async => null;

  @override
  Future<CourseGeometryBundle?> getGeometryBundle({
    required String packageId,
    required String courseId,
  }) async => null;

  @override
  Future<List<CoursePackageManifest>> listPackages() async => const [];

  @override
  Future<String?> findPackageIdForCourse(String courseId) async => null;
}

class _FeatureApi implements HoleFeatureApi {
  _FeatureApi(this.response);

  /// What the server answers with, or null to fail the way being offline does.
  final Map<String, dynamic>? response;

  /// Holes this asked the server to trace.
  final List<int> traceRequests = [];

  @override
  Future<TracedFeatures> forHole({
    required String courseId,
    required int holeNumber,
  }) async {
    final json = response;
    if (json == null) throw Exception('offline');
    return HoleFeatureApi.parse(json);
  }

  @override
  Future<bool> requestTrace({
    required String courseId,
    required int holeNumber,
  }) async {
    traceRequests.add(holeNumber);
    return true;
  }
}

Map<String, dynamic> _feature(String layer, String source, bool verified) => {
  'type': 'Feature',
  'geometry': {
    'type': 'Polygon',
    'coordinates': [
      [
        [105.892017, 21.036720],
        [105.891985, 21.036713],
        [105.891969, 21.036698],
        [105.892017, 21.036720],
      ],
    ],
  },
  'properties': {
    'layerType': layer,
    'source': source,
    'verified': verified,
    'verificationStatus': verified ? 'VERIFIED' : 'PENDING_REVIEW',
  },
};

/// Long Biên hole 1 as the deployment returns it, trimmed to one shape a layer.
Map<String, dynamic> get _serverResponse => {
  'type': 'FeatureCollection',
  'features': [
    _feature('bunker', 'golfseg', false),
    _feature('fairway', 'golfseg', false),
    _feature('tee', 'golfseg', false),
    _feature('green', 'openstreetmap', true),
  ],
};

LoadHoleMap load() => const LoadHoleMap(
  courseId: '1351',
  courseName: 'Long Biên Golf Course',
  holeNumber: 1,
);

void main() {
  group('a course with no package on the device', () {
    blocTest<HoleMapBloc, HoleMapState>(
      'is drawn from the shapes the server holds',
      build: () => HoleMapBloc(
        repository: _NoPackages(),
        featureApi: _FeatureApi(_serverResponse),
      ),
      act: (bloc) => bloc.add(load()),
      expect: () => [isA<HoleMapLoading>(), isA<HoleMapReady>()],
    );

    test('every layer the server sent is on the map and visible', () async {
      final bloc = HoleMapBloc(
        repository: _NoPackages(),
        featureApi: _FeatureApi(_serverResponse),
      );

      bloc.add(load());
      final state =
          await bloc.stream.firstWhere((s) => s is! HoleMapLoading)
              as HoleMapReady;

      expect(state.holeMap.layers.keys, {
        MapLayerType.bunker,
        MapLayerType.fairway,
        MapLayerType.tee,
        MapLayerType.green,
      });
      // A green is what every distance on this screen is measured to. Without
      // it the panel reads "this hole has no green position" over imagery
      // that plainly shows one.
      expect(state.holeMap.layers[MapLayerType.green], isNotNull);
      expect(
        state.layerVisibility.values.every((visible) => visible),
        isTrue,
      );
      await bloc.close();
    });

    test('the shapes are marked as a model traced, not as survey', () async {
      final bloc = HoleMapBloc(
        repository: _NoPackages(),
        featureApi: _FeatureApi(_serverResponse),
      );

      bloc.add(load());
      final state =
          await bloc.stream.firstWhere((s) => s is! HoleMapLoading)
              as HoleMapReady;

      // GolfSeg files as `golfseg`. The parser knew only `ai-satellite`, so
      // this was false on every hole it drew and the caveat never appeared.
      expect(state.tracedShapesUnverified, isTrue);
      expect(state.holeMap.isSurveyed, isFalse);
      await bloc.close();
    });

    test('par is not invented for a hole with no scorecard behind it', () async {
      final bloc = HoleMapBloc(
        repository: _NoPackages(),
        featureApi: _FeatureApi(_serverResponse),
      );

      bloc.add(load());
      final state =
          await bloc.stream.firstWhere((s) => s is! HoleMapLoading)
              as HoleMapReady;

      expect(state.holeMap.par, 0);
      await bloc.close();
    });

    blocTest<HoleMapBloc, HoleMapState>(
      'is still unsurveyed when the server has nothing either',
      build: () => HoleMapBloc(
        repository: _NoPackages(),
        featureApi: _FeatureApi(const {
          'type': 'FeatureCollection',
          'features': <dynamic>[],
        }),
      ),
      act: (bloc) => bloc.add(load()),
      expect: () => [isA<HoleMapLoading>(), isA<HoleMapUnsurveyed>()],
    );

    test('and asks for that hole to be traced', () async {
      final api = _FeatureApi(const {
        'type': 'FeatureCollection',
        'features': <dynamic>[],
      });
      final bloc = HoleMapBloc(repository: _NoPackages(), featureApi: api);

      bloc.add(load());
      await bloc.stream.firstWhere((s) => s is! HoleMapLoading);

      expect(api.traceRequests, [1]);
      await bloc.close();
    });

    blocTest<HoleMapBloc, HoleMapState>(
      'falls back to satellite when the phone cannot reach the server',
      build: () => HoleMapBloc(
        repository: _NoPackages(),
        featureApi: _FeatureApi(null),
      ),
      act: (bloc) => bloc.add(load()),
      // Offline on the 7th is not an error worth a red screen: the imagery is
      // cached and the measuring tool works on it.
      expect: () => [isA<HoleMapLoading>(), isA<HoleMapUnsurveyed>()],
    );
  });
}
