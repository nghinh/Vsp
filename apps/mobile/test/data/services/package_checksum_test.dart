// Package checksum verification — VSP Mobile App
//
// These tests exist because the verification they cover did not. The readiness
// check ended in `_spotCheckChecksum`, whose entire body was a comment and
// `return true`, so a downloaded package could not fail integrity however its
// bytes had been mangled. The download check was worse than absent: it hashed
// `List.filled(cumulativeBytesReceived, 0)` — zeros, not the payload — so it
// could only ever have rejected genuine files, and never ran because the
// packages being served declare no files at all.
//
// Everything below therefore corrupts something on purpose and insists the
// code says so.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:vsp_mobile/data/repositories/package_manifest_repository.dart';
import 'package:vsp_mobile/data/services/package_file_downloader.dart';
import 'package:vsp_mobile/data/services/package_readiness_service.dart';
import 'package:vsp_mobile/domain/models/course_package_manifest.dart';
import 'package:vsp_mobile/domain/models/package_content_type.dart';
import 'package:vsp_mobile/domain/models/package_file_entry.dart';

/// Points `getApplicationDocumentsDirectory()` at a real temporary directory
/// so the service walks real files.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getTemporaryDirectory() async => root;
}

/// Hands back one manifest; nothing else on the repository is reached.
class _FakeManifestRepo implements PackageManifestRepository {
  _FakeManifestRepo(this.manifest);
  final CoursePackageManifest? manifest;

  @override
  Future<CoursePackageManifest?> getActiveManifest(int courseId) async =>
      manifest;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Serves fixed bytes to dio, so a download can be driven with no network.
class _BytesAdapter implements HttpClientAdapter {
  _BytesAdapter(this.bytes);
  final List<int> bytes;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(
    bytes,
    200,
    headers: {
      Headers.contentLengthHeader: [bytes.length.toString()],
    },
  );

  @override
  void close({bool force = false}) {}
}

String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

CoursePackageManifest manifestWith(List<PackageFileEntry> files) =>
    CoursePackageManifest(
      packageId: 'pkg-1',
      courseId: 7,
      version: '1.0.0',
      effectiveDate: DateTime.utc(2026, 1, 1),
      expiresAt: DateTime.utc(2030, 1, 1),
      checksum: 'irrelevant-package-level-label',
      sizeBytes: files.fold(0, (sum, f) => sum + f.sizeBytes),
      tilesFormat: TilesFormat.pmtiles,
      tilesUrl: 'https://example.invalid/tiles',
      geoJsonUrl: 'https://example.invalid/geo',
      files: files,
      minimumClientVersion: '1.0.0',
      licenses: const [],
      generatedAt: DateTime.utc(2026, 1, 1),
      generatedBy: 'test',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'PackageFileDownloader — the bytes that arrived are the bytes hashed',
    () {
      late Directory tmp;

      setUp(() async {
        tmp = await Directory.systemTemp.createTemp('vsp-download-');
      });
      tearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });

      PackageFileDownloader downloaderServing(List<int> bytes) {
        final dio = Dio()..httpClientAdapter = _BytesAdapter(bytes);
        return PackageFileDownloader(dio: dio);
      }

      test('accepts a file whose SHA-256 matches the manifest', () async {
        final payload = utf8.encode('{"holes":[{"number":1,"par":4}]}');
        final savePath = '${tmp.path}/geometry.geojson';

        final result = await downloaderServing(payload).downloadFile(
          url: 'https://example.invalid/geometry.geojson',
          savePath: savePath,
          expectedChecksum: sha256Hex(payload),
        );

        expect(result, isA<DownloadFileSuccess>());
        expect(await File(savePath).readAsBytes(), payload);
      });

      test('rejects a file whose bytes were altered in transit', () async {
        // The manifest describes the honest package; the server sends one byte
        // of something else. This is the case that used to be accepted.
        final honest = utf8.encode('{"holes":[{"number":1,"par":4}]}');
        final corrupted = utf8.encode('{"holes":[{"number":1,"par":5}]}');
        expect(
          corrupted.length,
          honest.length,
          reason:
              'same size, so a size '
              'check could not catch it — only the hash can',
        );

        final savePath = '${tmp.path}/geometry.geojson';
        final result = await downloaderServing(corrupted).downloadFile(
          url: 'https://example.invalid/geometry.geojson',
          savePath: savePath,
          expectedChecksum: sha256Hex(honest),
        );

        expect(result, isA<DownloadFileFailure>());
        expect((result as DownloadFileFailure).isChecksumMismatch, isTrue);
        // The corrupted file must not be left behind for the map to read.
        expect(await File(savePath).exists(), isFalse);
      });

      test('rejects a truncated download', () async {
        final honest = utf8.encode('a' * 4096);
        final truncated = utf8.encode('a' * 2048);

        final result = await downloaderServing(truncated).downloadFile(
          url: 'https://example.invalid/tiles.pmtiles',
          savePath: '${tmp.path}/tiles.pmtiles',
          expectedChecksum: sha256Hex(honest),
        );

        expect((result as DownloadFileFailure).isChecksumMismatch, isTrue);
      });
    },
  );

  group(
    'PackageReadinessService — a package on disk is verified, not assumed',
    () {
      late Directory tmp;
      late Directory packageDir;

      setUp(() async {
        tmp = await Directory.systemTemp.createTemp('vsp-readiness-');
        PathProviderPlatform.instance = _FakePathProvider(tmp.path);
        packageDir = Directory('${tmp.path}/packages/7/1.0.0');
        await packageDir.create(recursive: true);
      });
      tearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });

      Future<PackageFileEntry> write(String name, String contents) async {
        final bytes = utf8.encode(contents);
        await File('${packageDir.path}/$name').writeAsBytes(bytes);
        return PackageFileEntry(
          path: name,
          checksum: sha256Hex(bytes),
          sizeBytes: bytes.length,
          contentType: PackageContentType.GEOMETRY,
        );
      }

      Future<PackageReadinessReason> readinessFor(
        CoursePackageManifest manifest,
      ) async {
        final service = PackageReadinessService(
          manifestRepo: _FakeManifestRepo(manifest),
        );
        final readiness = await service.getOfflineReadiness(7);
        return readiness.reason;
      }

      test('an intact package is ready', () async {
        final entries = [
          await write('geometry.geojson', '{"holes":[]}'),
          await write('conditions.json', '{"green":"firm"}'),
        ];
        expect(
          await readinessFor(manifestWith(entries)),
          PackageReadinessReason.ok,
        );
      });

      test('one corrupted byte is a checksum mismatch', () async {
        final entries = [
          await write('geometry.geojson', '{"holes":[]}'),
          await write('conditions.json', '{"green":"firm"}'),
        ];

        // Corrupt one file after the manifest recorded its hash — a failing SD
        // card, an interrupted write, or a substitution. Same length, so nothing
        // but the digest can tell.
        await File(
          '${packageDir.path}/conditions.json',
        ).writeAsBytes(utf8.encode('{"green":"soft"}'));

        expect(
          await readinessFor(manifestWith(entries)),
          PackageReadinessReason.checksumMismatch,
        );
      });

      test('a truncated file is a checksum mismatch', () async {
        final entries = [await write('tiles.pmtiles', 'a' * 4096)];
        await File(
          '${packageDir.path}/tiles.pmtiles',
        ).writeAsBytes(utf8.encode('a' * 2048));

        expect(
          await readinessFor(manifestWith(entries)),
          PackageReadinessReason.checksumMismatch,
        );
      });

      test('a declared file that is not on disk is reported missing', () async {
        final entries = [await write('geometry.geojson', '{"holes":[]}')];
        await File('${packageDir.path}/geometry.geojson').delete();

        expect(
          await readinessFor(manifestWith(entries)),
          PackageReadinessReason.filesMissing,
        );
      });

      // The manifests currently in the database carry sizeBytes 0 and no files.
      // The download path already refuses those. Readiness has to agree, or a
      // package that was refused at download time is reported ready afterwards.
      test('a manifest that declares no files is never ready', () async {
        expect(
          await readinessFor(manifestWith(const [])),
          isNot(PackageReadinessReason.ok),
        );
      });

      // A manifest entry with an empty checksum verifies nothing. Treating it as
      // a pass is how a stub becomes permanent.
      test('an entry with no checksum does not pass', () async {
        final bytes = utf8.encode('{"holes":[]}');
        await File('${packageDir.path}/geometry.geojson').writeAsBytes(bytes);
        final entries = [
          PackageFileEntry(
            path: 'geometry.geojson',
            checksum: '',
            sizeBytes: bytes.length,
            contentType: PackageContentType.GEOMETRY,
          ),
        ];

        expect(
          await readinessFor(manifestWith(entries)),
          PackageReadinessReason.checksumMismatch,
        );
      });
    },
  );
}
