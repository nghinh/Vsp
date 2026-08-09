// CoursePackageRepository — VSP Golf Platform
//
// Repository interface and local implementation for reading course package
// files from the app documents directory. Packages are downloaded and stored
// by the course package download service (story 4.3).

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'manifest.dart';
import 'hole_geometry.dart';

/// Abstract repository for accessing locally-stored course packages.
abstract class CoursePackageRepository {
  /// Lists all downloaded course packages on disk.
  Future<List<CoursePackageManifest>> listPackages();

  /// Returns the manifest for a specific package.
  Future<CoursePackageManifest?> getManifest(String packageId);

  /// Returns the geometry bundle for a specific package and course.
  Future<CourseGeometryBundle?> getGeometryBundle(String packageId, String courseId);

  /// Returns geometry for a specific hole.
  Future<HoleGeometry?> getHoleGeometry(String packageId, String courseId, int holeNumber);

  /// Returns the path to a package's root directory on disk.
  Future<String> getPackagePath(String packageId);

  /// Checks whether a package exists on disk.
  Future<bool> packageExists(String packageId);

  /// Removes a package from disk.
  Future<void> deletePackage(String packageId);
}

/// Loads course packages from the app's documents directory.
///
/// Directory structure, as [CoursePackageDownloadService] writes it:
///   <documents>/packages/<course_id>/<version>/
///     manifest.json
///     geometry/
///       hole_<n>.geojson
///     conditions/
///       conditions.json
///     metadata/
///       manifest.json
///     tiles/
///       (pmtiles / mbtiles files)
///
/// This class used to read `<documents>/course_packages/<package_id>/` — a
/// tree nothing ever wrote to. The downloader has always written the versioned
/// layout above, so a package could download successfully, verify every
/// checksum, be promoted to active, and still be invisible to every caller that
/// asked for its geometry. Both halves of that mismatch reported success, which
/// is why it survived: the app simply behaved as though no course had ever been
/// downloaded.
///
/// A package is identified here by `<course_id>/<version>`, which is also its
/// path under the root.
class LocalCoursePackageRepository implements CoursePackageRepository {
  /// Where the app keeps its documents. Injectable so this class can be tested
  /// without a platform channel — it had no tests at all while its directory
  /// layout disagreed with the downloader's.
  final Future<Directory> Function() _documentsDirectory;

  LocalCoursePackageRepository({
    Future<Directory> Function()? documentsDirectory,
  }) : _documentsDirectory = documentsDirectory ?? getApplicationDocumentsDirectory;

  Future<Directory> get _packagesRoot async {
    final dir = await _documentsDirectory();
    final root = Directory('${dir.path}/packages');
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  @override
  Future<List<CoursePackageManifest>> listPackages() async {
    final root = await _packagesRoot;
    if (!await root.exists()) return [];

    final manifests = <CoursePackageManifest>[];
    await for (final courseDir in root.list()) {
      if (courseDir is! Directory) continue;
      // One level down from the course: each downloaded version keeps its own
      // directory so a failed update cannot damage the package already on the
      // phone.
      await for (final versionDir in courseDir.list()) {
        if (versionDir is! Directory) continue;
        final manifest = await _readManifest(versionDir.path);
        if (manifest != null) manifests.add(manifest);
      }
    }
    return manifests;
  }

  @override
  Future<CoursePackageManifest?> getManifest(String packageId) async {
    final pkgDir = await _packageDir(packageId);
    if (!await pkgDir.exists()) return null;
    return _readManifest(pkgDir.path);
  }

  @override
  Future<bool> packageExists(String packageId) async {
    final pkgDir = await _packageDir(packageId);
    return pkgDir.exists();
  }

  @override
  Future<String> getPackagePath(String packageId) async {
    final pkgDir = await _packageDir(packageId);
    return pkgDir.path;
  }

  @override
  Future<void> deletePackage(String packageId) async {
    final pkgDir = await _packageDir(packageId);
    if (await pkgDir.exists()) {
      await pkgDir.delete(recursive: true);
    }
  }

  @override
  Future<CourseGeometryBundle?> getGeometryBundle(
    String packageId,
    String courseId,
  ) async {
    final pkgDir = await _packageDir(packageId);
    if (!await pkgDir.exists()) return null;

    final geometryDir = Directory('${pkgDir.path}/geometry');
    if (!await geometryDir.exists()) return null;

    final holesByNumber = <int, HoleGeometry>{};

    await for (final entity in geometryDir.list()) {
      if (entity is File && entity.path.endsWith('.geojson')) {
        final holeGeom = await _readHoleGeometry(entity);
        if (holeGeom != null) {
          holesByNumber[holeGeom.holeNumber] = holeGeom;
        }
      }
    }

    return CourseGeometryBundle(
      packageId: packageId,
      courseId: courseId,
      holesByNumber: holesByNumber,
    );
  }

  @override
  Future<HoleGeometry?> getHoleGeometry(
    String packageId,
    String courseId,
    int holeNumber,
  ) async {
    final bundle = await getGeometryBundle(packageId, courseId);
    return bundle?.hole(holeNumber);
  }

  Future<Directory> _packageDir(String packageId) async {
    final root = await _packagesRoot;
    return Directory('${root.path}/$packageId');
  }

  Future<CoursePackageManifest?> _readManifest(String packagePath) async {
    final file = File('$packagePath/manifest.json');
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final root = (await _packagesRoot).path;
      // The manifest carries the server's package id, but every method here
      // takes a packageId and turns it back into a path. Reporting the local
      // path means `getGeometryBundle(pkg.packageId, …)` reaches the directory
      // the manifest was just read from, rather than a sibling named after a
      // UUID that no directory on this device uses.
      if (packagePath.startsWith(root)) {
        json['packageId'] = packagePath
            .substring(root.length)
            .replaceAll(RegExp(r'^/+'), '');
      }
      return CoursePackageManifest.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<HoleGeometry?> _readHoleGeometry(File file) async {
    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      final holeNum = _parseHoleNumber(file.path);
      final holeId = json['holeId'] as String? ?? 'hole_$holeNum';
      final courseId = json['courseId'] as String? ?? '';
      final par = json['par'] as int? ?? 4;
      final yardage = json['yardage'] as int?;

      final layersJson = json['layers'] as Map<String, dynamic>? ?? {};
      final layers = <GeometryLayerType, LayerGeometry>{};

      for (final entry in layersJson.entries) {
        final type = _parseLayerType(entry.key);
        if (type != null) {
          layers[type] = LayerGeometry.fromGeoJson(
            type,
            holeNum,
            holeId,
            entry.value as Map<String, dynamic>,
          );
        }
      }

      return HoleGeometry(
        holeId: holeId,
        holeNumber: holeNum,
        courseId: courseId,
        par: par,
        yardage: yardage,
        layers: layers,
        // Absent in packages built before provenance was carried per hole.
        // Left null here and read as "not surveyed" downstream rather than
        // defaulted to something friendlier.
        accuracyClass: json['accuracyClass'] as String?,
        verificationStatus: json['verificationStatus'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  int _parseHoleNumber(String path) {
    final filename = path.split('/').last;
    final match = RegExp(r'hole_(\d+)').firstMatch(filename);
    return match != null ? int.parse(match.group(1)!) : 1;
  }

  GeometryLayerType? _parseLayerType(String name) {
    switch (name.toLowerCase()) {
      case 'tee':
        return GeometryLayerType.tee;
      case 'fairway':
        return GeometryLayerType.fairway;
      case 'rough':
        return GeometryLayerType.rough;
      case 'green':
        return GeometryLayerType.green;
      case 'bunker':
        return GeometryLayerType.bunker;
      case 'water':
        return GeometryLayerType.water;
      case 'penalty_area':
      case 'penaltyarea':
        return GeometryLayerType.penaltyArea;
      case 'ob':
        return GeometryLayerType.ob;
      case 'cart_path':
      case 'cartpath':
        return GeometryLayerType.cartPath;
      case 'landmark':
        return GeometryLayerType.landmark;
      default:
        return null;
    }
  }
}
