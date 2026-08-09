// Tests for the map finding a package nobody handed it.
//
// A golfer downloaded Long Thành, saw "Offline Ready", started a round from the
// course picker and got a map that said the hole was unsurveyed — with the
// package sitting complete and checksum-verified on disk. The picker built its
// course list with `packageId: null` hardcoded, the bloc took a null package id
// to mean "nothing on this device", and no layer in between ever asked the
// device what it had.
//
// So the bloc now resolves the package from the course when it is not given
// one. These tests pin that: a null package id is a question, not an answer.

import 'package:bloc_test/bloc_test.dart';
import 'package:course_package/course_package.dart' hide AccuracyClass;
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/domain/models/data_freshness.dart';
import 'package:vsp_mobile/domain/models/data_quality.dart' show AccuracyClass;
import 'package:vsp_mobile/domain/models/hole_data_provenance.dart';
import 'package:vsp_mobile/features/hole_map/data/hole_map_repository.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_map_entity.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_bloc.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_event.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_state.dart';

class _Repository implements HoleMapRepository {
  /// Package the device holds for course "8", or null for none.
  final String? installedPackageId;

  /// Package ids getHoleMap was actually asked for.
  final List<String> asked = [];

  _Repository({this.installedPackageId});

  @override
  Future<HoleMapEntity?> getHoleMap({
    required String packageId,
    required String courseId,
    required String courseName,
    required int holeNumber,
  }) async {
    asked.add(packageId);
    if (packageId != installedPackageId) return null;
    return HoleMapEntity(
      courseId: courseId,
      courseName: courseName,
      holeNumber: holeNumber,
      par: 4,
      yardage: 361,
      layers: const {},
      provenance: HoleDataProvenance(
        accuracyClass: AccuracyClass.classC,
        verificationStatus: VerificationStatus.verified,
      ),
    );
  }

  @override
  Future<CourseGeometryBundle?> getGeometryBundle({
    required String packageId,
    required String courseId,
  }) async => null;

  @override
  Future<List<CoursePackageManifest>> listPackages() async => const [];

  @override
  Future<String?> findPackageIdForCourse(String courseId) async =>
      courseId == '8' ? installedPackageId : null;
}

HoleMapBloc blocWith(_Repository repository) =>
    HoleMapBloc(repository: repository);

LoadHoleMap load({String? packageId}) => LoadHoleMap(
  packageId: packageId,
  courseId: '8',
  courseName: 'Long Thành Golf Resort — Championship',
  holeNumber: 1,
);

void main() {
  group('when the caller did not pass a package id', () {
    blocTest<HoleMapBloc, HoleMapState>(
      'the downloaded package is found and the hole is drawn',
      build: () => blocWith(_Repository(installedPackageId: '8/1.8.2')),
      act: (bloc) => bloc.add(load()),
      // This is the exact path from the course picker, and it ended in
      // HoleMapUnsurveyed for a fully downloaded course.
      expect: () => [isA<HoleMapLoading>(), isA<HoleMapReady>()],
    );

    blocTest<HoleMapBloc, HoleMapState>(
      'a course with nothing downloaded is still unsurveyed',
      build: () => blocWith(_Repository()),
      act: (bloc) => bloc.add(load()),
      // Most of ~900 holes. Not an error, and not something to invent a
      // package for.
      expect: () => [isA<HoleMapLoading>(), isA<HoleMapUnsurveyed>()],
    );

    test('the device is asked, not guessed at', () async {
      final repository = _Repository(installedPackageId: '8/1.8.2');
      final bloc = blocWith(repository);

      bloc.add(load());
      await bloc.stream.firstWhere((s) => s is! HoleMapLoading);

      expect(repository.asked, ['8/1.8.2']);
      await bloc.close();
    });
  });

  group('when the caller did pass one', () {
    blocTest<HoleMapBloc, HoleMapState>(
      'it is used as given',
      build: () => blocWith(_Repository(installedPackageId: '8/1.8.2')),
      act: (bloc) => bloc.add(load(packageId: '8/1.8.2')),
      expect: () => [isA<HoleMapLoading>(), isA<HoleMapReady>()],
    );

    blocTest<HoleMapBloc, HoleMapState>(
      'a package that holds nothing for this hole reads as unsurveyed',
      build: () => blocWith(_Repository(installedPackageId: '8/1.8.2')),
      act: (bloc) => bloc.add(load(packageId: '8/9.9.9')),
      // Deliberately not falling back to the resolver here: the caller named a
      // package, and quietly substituting a different one would draw a course
      // the screen did not ask for.
      expect: () => [isA<HoleMapLoading>(), isA<HoleMapUnsurveyed>()],
    );
  });
}
