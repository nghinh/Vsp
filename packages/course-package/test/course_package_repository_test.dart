// Tests for finding a downloaded course package on disk.
//
// This class had none, and it spent the project reading
// `<documents>/course_packages/<package_id>/` — a directory nothing has ever
// written to. The download service writes `<documents>/packages/<course>/<version>/`.
// So a package could download, verify every checksum, be promoted to active,
// and still be invisible: `listPackages()` returned an empty list, the hole map
// found no geometry, and the app fell through to its unsurveyed path for a
// course it had fully downloaded. Nothing errored anywhere along that chain.
//
// The fixtures below are written in the downloader's layout on purpose. A test
// that builds the layout the reader wants would have passed against the broken
// code too.

import 'dart:convert';
import 'dart:io';

import 'package:course_package/course_package.dart';
import 'package:test/test.dart';

void main() {
  late Directory documents;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('vsp-package-');
  });

  tearDown(() async {
    if (await documents.exists()) await documents.delete(recursive: true);
  });

  LocalCoursePackageRepository repository() =>
      LocalCoursePackageRepository(documentsDirectory: () async => documents);

  /// Writes a package exactly where CoursePackageDownloadService puts one.
  Future<Directory> writePackage({
    int courseId = 8,
    String version = '1.8.2',
    List<int> holes = const [1, 2],
    String? accuracyClass = 'C_VERIFIED_SATELLITE',
    String? verificationStatus = 'VERIFIED',
  }) async {
    final dir = Directory('${documents.path}/packages/$courseId/$version');
    await dir.create(recursive: true);

    await File('${dir.path}/manifest.json').writeAsString(jsonEncode({
      'packageId': 'server-side-uuid-nobody-on-disk-uses',
      // The API writes this as a number, and so does the download service.
      'courseId': courseId,
      'version': version,
      'effectiveDate': '2026-08-07T00:00:00.000Z',
      'checksum': 'abc123',
      'sizeBytes': 4096,
      'tilesFormat': 'PMTILES',
      'files': [],
    }));

    final geometry = Directory('${dir.path}/geometry');
    await geometry.create(recursive: true);
    for (final hole in holes) {
      await File('${geometry.path}/hole_$hole.geojson').writeAsString(jsonEncode({
        'holeId': 'hole-$hole',
        'courseId': '$courseId',
        'holeNumber': hole,
        'par': 4,
        'yardage': 382,
        if (accuracyClass != null) 'accuracyClass': accuracyClass,
        if (verificationStatus != null) 'verificationStatus': verificationStatus,
        'layers': {
          'tee': {
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'geometry': {'type': 'Point', 'coordinates': [106.9, 10.8]},
              },
            ],
          },
          'green': {
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'geometry': {'type': 'Point', 'coordinates': [106.905, 10.805]},
              },
            ],
          },
        },
      }));
    }

    return dir;
  }

  group('finding what the downloader wrote', () {
    test('a downloaded package is discovered', () async {
      await writePackage();

      final packages = await repository().listPackages();

      expect(packages, hasLength(1));
      expect(packages.first.courseId, '8');
      expect(packages.first.version, '1.8.2');
    });

    test('its geometry loads through the id listPackages reported', () async {
      await writePackage(holes: [1, 2, 3]);
      final repo = repository();

      final listed = await repo.listPackages();
      final bundle = await repo.getGeometryBundle(
        listed.first.packageId,
        listed.first.courseId,
      );

      // The round trip is the point. Every caller does exactly this — takes a
      // packageId off a listed manifest and asks for geometry with it — and it
      // resolved to a directory that did not exist.
      expect(bundle, isNotNull);
      expect(bundle!.holeCount, 3);
      expect(bundle.hole(2)?.holeNumber, 2);
    });

    test('two versions of a course are both visible', () async {
      await writePackage(version: '1.8.1');
      await writePackage(version: '1.8.2');

      expect(await repository().listPackages(), hasLength(2));
    });

    test('a course id written as a number is read', () async {
      await writePackage();

      // Read strictly as a String this threw, and the catch treated the throw
      // as "no package here" — silently, for every real manifest.
      expect((await repository().listPackages()).single.courseId, '8');
    });
  });

  group('provenance survives the trip to disk', () {
    test('the hole carries the class and status the package recorded', () async {
      await writePackage();
      final repo = repository();
      final listed = await repo.listPackages();

      final hole = await repo.getHoleGeometry(listed.first.packageId, '8', 1);

      // The app's gate is `verified && class != D`. If these are lost in
      // transit, verified geometry arrives looking unverified and the strategic
      // map stays switched off.
      expect(hole?.accuracyClass, 'C_VERIFIED_SATELLITE');
      expect(hole?.verificationStatus, 'VERIFIED');
    });

    test('a package without provenance does not gain one', () async {
      await writePackage(accuracyClass: null, verificationStatus: null);
      final repo = repository();
      final listed = await repo.listPackages();

      final hole = await repo.getHoleGeometry(listed.first.packageId, '8', 1);

      // Null is read downstream as class D. A default of anything else would
      // let a package label its own contents trustworthy.
      expect(hole?.accuracyClass, isNull);
      expect(hole?.verificationStatus, isNull);
    });
  });

  group('what is not a package', () {
    test('a directory with no manifest is skipped', () async {
      await Directory('${documents.path}/packages/9/1.9.1/geometry')
          .create(recursive: true);

      expect(await repository().listPackages(), isEmpty);
    });

    test('no packages directory yields no packages', () async {
      expect(await repository().listPackages(), isEmpty);
    });

    test('a half-written manifest is skipped rather than thrown', () async {
      final dir = Directory('${documents.path}/packages/9/1.9.1');
      await dir.create(recursive: true);
      await File('${dir.path}/manifest.json').writeAsString('{ not json');

      expect(await repository().listPackages(), isEmpty);
    });
  });
}
