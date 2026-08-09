// Tests for dragging a measured point.
//
// Correcting a mis-tapped point used to mean deleting it and dropping a new
// one — and a new point goes on the end of the chain. So fixing the second of
// four legs silently re-ordered the measurement into a different route, and the
// golfer's "from you, then to the bunker, then to the green" became something
// else with the same total.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/services/location_service.dart';
import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/measure/presentation/measure_cubit.dart';

class _NoLocation implements LocationService {
  @override
  Stream<QualifiedLocation> get locationStream => const Stream.empty();
  @override
  QualifiedLocation? get lastLocation => null;
  @override
  Future<QualifiedLocation> getCurrentLocation() async =>
      QualifiedLocation.unavailable();
  @override
  void start() {}
  @override
  void stop() {}
  @override
  Future<bool> isLocationAvailable() async => false;
  @override
  Duration get stationaryInterval => const Duration(seconds: 30);
  @override
  Duration get activeInterval => const Duration(seconds: 5);
  @override
  void dispose() {}
}

LatLng at(double lat, double lng) => LatLng(latitude: lat, longitude: lng);

void main() {
  late MeasureCubit cubit;

  setUp(() => cubit = MeasureCubit(locationService: _NoLocation()));
  tearDown(() => cubit.close());

  test('a dragged point keeps its place in the chain', () {
    cubit.addPoint(at(10.8580, 106.9000));
    cubit.addPoint(at(10.8590, 106.9010));
    cubit.addPoint(at(10.8600, 106.9020));
    final second = cubit.state.points[1].id;

    cubit.movePoint(second, at(10.8595, 106.9015));

    // The order is the measurement. Delete-and-retap put the corrected point
    // last and turned a three-leg walk into a different one.
    expect(cubit.state.points[1].id, second);
    expect(cubit.state.points, hasLength(3));
    expect(cubit.state.points[1].position.latitude, closeTo(10.8595, 1e-9));
  });

  test('the distances follow the point', () {
    cubit.addPoint(at(10.8580, 106.9000));
    cubit.addPoint(at(10.8590, 106.9000));
    final before = cubit.state.result.totalMeters;

    cubit.movePoint(cubit.state.points[1].id, at(10.8600, 106.9000));

    expect(cubit.state.result.totalMeters, greaterThan(before));
  });

  test('moving a point that is not there changes nothing', () {
    cubit.addPoint(at(10.8580, 106.9000));
    final before = cubit.state.points;

    cubit.movePoint('not-a-point', at(10.9, 107.0));

    expect(cubit.state.points, same(before));
  });

  test('a point keeps its identity so it can be dragged again', () {
    cubit.addPoint(at(10.8580, 106.9000));
    final id = cubit.state.points.single.id;

    cubit.movePoint(id, at(10.8585, 106.9005));
    cubit.movePoint(id, at(10.8590, 106.9010));

    expect(cubit.state.points.single.id, id);
    expect(cubit.state.points.single.position.latitude, closeTo(10.8590, 1e-9));
  });
}
