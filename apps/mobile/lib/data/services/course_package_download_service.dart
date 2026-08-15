// Course Package Download Service — VSP Mobile App
//
// Orchestrates the full course package download lifecycle:
//   1. Fetch current manifest from server
//   2. Compare with local manifest (skip if same version)
//   3. Download all files listed in manifest
//   4. Validate and promote manifest
//   5. Emit progress updates
//
// Also handles: pause, resume, retry, cancel, delete (non-destructive).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/models/course_package_manifest.dart';
import '../../domain/models/download_progress.dart';
import '../../domain/models/download_state.dart';
import '../repositories/course_package_repository.dart';
import '../repositories/package_manifest_repository.dart';
import 'connectivity_service.dart';
import 'package_file_downloader.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';
import 'package:vsp_mobile/core/network/vsp_endpoints.dart';

/// Result of a download package operation.
sealed class DownloadPackageResult {}

/// Package downloaded and validated successfully.
class DownloadPackageSuccess extends DownloadPackageResult {
  final CoursePackageManifest manifest;

  DownloadPackageSuccess(this.manifest);
}

/// Package download was cancelled by user.
class DownloadPackageCancelled extends DownloadPackageResult {
  DownloadPackageCancelled();
}

/// Package download failed.
class DownloadPackageFailure extends DownloadPackageResult {
  final String message;
  final DownloadError? error;

  DownloadPackageFailure({required this.message, this.error});
}

/// Orchestrates course package download, pause, resume, retry, and delete.
///
/// Implements Story 4.3 AC-1, AC-2, AC-3:
/// - AC-1: Shows package size, version, update time, Wi-Fi preference,
///         progress, retry, completion.
/// - AC-2: Delete removes manifest + files but PRESERVES round/score data.
/// - AC-3: Emits offline_ready state when package is validated and ready.
class CoursePackageDownloadService {
  final PackageManifestRepository _manifestRepo;
  final CoursePackageRepository _packageRepo;
  final PackageFileDownloader _downloader;
  final ConnectivityService _connectivity;

  /// Active download progress streams keyed by courseId.
  final _progressControllers = <int, StreamController<DownloadProgress>>{};

  /// Active download cancel tokens keyed by courseId.
  final _cancelTokens = <int, CancelToken>{};

  /// Current download state per courseId (in-memory cache).
  final _stateCache = <int, DownloadServiceState>{};

  CoursePackageDownloadService({
    required PackageManifestRepository manifestRepo,
    required CoursePackageRepository packageRepo,
    required PackageFileDownloader downloader,
    required ConnectivityService connectivity,
  }) : _manifestRepo = manifestRepo,
       _packageRepo = packageRepo,
       _downloader = downloader,
       _connectivity = connectivity;

  /// Get download state for a course.
  DownloadServiceState getState(int courseId) {
    return _stateCache[courseId] ?? DownloadServiceState.idle;
  }

  /// Get a stream of download progress for a course.
  ///
  /// Emits [DownloadProgress] updates as the download progresses.
  /// The stream closes when the download completes, fails, or is cancelled.
  Stream<DownloadProgress> getProgressStream(int courseId) {
    _progressControllers[courseId] ??=
        StreamController<DownloadProgress>.broadcast();
    return _progressControllers[courseId]!.stream;
  }

  /// Download (or update) a course package.
  ///
  /// [courseId] — the course to download.
  /// [wifiOnly] — if true, only download when Wi-Fi is connected.
  ///
  /// Flow:
  /// 1. Check Wi-Fi policy via [ConnectivityService.shouldDownload].
  /// 2. Fetch current manifest from server.
  /// 3. Compare with local active manifest — skip if same version.
  /// 4. Save pending manifest, download all files.
  /// 5. Validate files, promote pending → active on success.
  /// 6. On failure: discard pending, leave active manifest intact.
  Future<DownloadPackageResult> downloadPackage(
    int courseId, {
    bool wifiOnly = false,
  }) async {
    if (wifiOnly) {
      await _connectivity.setWifiOnly(true);
    }

    // Check connectivity policy
    if (!await _connectivity.shouldDownload) {
      _emitProgress(
        _createProgress(
          courseId,
          DownloadServiceState.error,
          error: DownloadError.networkError,
          errorMessage:
              'Wi-Fi required for download. Connect to Wi-Fi and try again.',
        ),
      );
      return DownloadPackageFailure(
        message: AppMessages.wifiRequiredDownload,
        error: DownloadError.networkError,
      );
    }

    final cancelToken = CancelToken();
    _cancelTokens[courseId] = cancelToken;

    try {
      _setState(courseId, DownloadServiceState.fetchingManifest);

      // Step 1: Fetch remote manifest
      final remoteManifest = await _fetchRemoteManifest(courseId);
      if (remoteManifest == null) {
        // Two different situations wearing the same null. Most courses in
        // this database have never had a package built — that is a fact
        // about the course, not a failure, and reporting it as a server
        // error sends the golfer to look for a problem that is not theirs.
        var published = false;
        try {
          published = await _packageRepo.hasPublishedPackage(courseId);
        } catch (_) {
          // Could not even ask. Treat it as the network problem it is.
          published = true;
        }
        _emitError(
          courseId,
          published
              ? 'Could not fetch course package manifest from server.'
              : 'No package has been published for this course.',
        );
        return DownloadPackageFailure(
          message: published
              ? AppMessages.manifestFetchFailed
              : AppMessages.noPackagePublished,
          error: DownloadError.serverError,
        );
      }

      // A manifest with no files cannot make the course playable offline.
      // Without this guard the loop below has nothing to do, the pending
      // manifest is promoted to active, and the app tells the golfer the course
      // is "Offline Ready" having downloaded zero bytes — they would find out
      // on the tee, with no map.
      if (remoteManifest.files.isEmpty) {
        _emitError(
          courseId,
          'Course package contains no files.',
          error: DownloadError.serverError,
        );
        return DownloadPackageFailure(
          message: AppMessages.emptyPackage,
          error: DownloadError.serverError,
        );
      }

      // Step 2: Compare with local active manifest
      final localManifest = await _manifestRepo.getActiveManifest(courseId);
      if (localManifest != null &&
          localManifest.version == remoteManifest.version) {
        _emitProgress(
          _createProgress(
            courseId,
            DownloadServiceState.offlineReady,
            totalBytes: remoteManifest.sizeBytes,
            downloadedBytes: remoteManifest.sizeBytes,
          ),
        );
        _setState(courseId, DownloadServiceState.offlineReady);
        return DownloadPackageSuccess(remoteManifest);
      }

      _setState(courseId, DownloadServiceState.downloading);

      // Step 3: Save pending manifest
      await _manifestRepo.savePendingManifest(remoteManifest);

      // Step 4: Download all files
      final packageDir = await _getPackageDir(courseId, remoteManifest.version);
      final totalFiles = remoteManifest.files.length;
      int downloadedBytes = 0;
      int fileIndex = 0;

      for (final file in remoteManifest.files) {
        if (cancelToken.isCancelled) {
          _setState(courseId, DownloadServiceState.idle);
          return DownloadPackageCancelled();
        }

        _emitProgress(
          _createProgress(
            courseId,
            DownloadServiceState.downloading,
            totalBytes: remoteManifest.sizeBytes,
            downloadedBytes: downloadedBytes,
            currentFile: file.path,
            currentFileIndex: fileIndex,
            totalFiles: totalFiles,
          ),
        );

        final savePath = '${packageDir.path}/${file.path}';
        final result = await _downloader.downloadFile(
          url: _cdnUrl(remoteManifest, file.path),
          savePath: savePath,
          expectedChecksum: file.checksum,
          cancelToken: cancelToken,
          onProgress: (received, total) {
            // Progress is emitted per-file; aggregate below
          },
        );

        switch (result) {
          case DownloadFileSuccess():
            downloadedBytes += result.totalBytes;
            fileIndex++;
          case DownloadFileCancelled():
            _setState(courseId, DownloadServiceState.idle);
            return DownloadPackageCancelled();
          case DownloadFileFailure():
            // On failure, discard pending manifest, keep active intact
            await _manifestRepo.discardPending(courseId);
            _emitError(
              courseId,
              result.message,
              error: result.isChecksumMismatch
                  ? DownloadError.checksumMismatch
                  : result.isNetworkError
                  ? DownloadError.networkError
                  : result.isStorageError
                  ? DownloadError.storageError
                  : DownloadError.unknown,
            );
            return DownloadPackageFailure(
              message: result.message,
              error: result.isChecksumMismatch
                  ? DownloadError.checksumMismatch
                  : result.isNetworkError
                  ? DownloadError.networkError
                  : result.isStorageError
                  ? DownloadError.storageError
                  : DownloadError.unknown,
            );
        }
      }

      // Step 5: Validate (all files downloaded, checksum verified per-file)
      _setState(courseId, DownloadServiceState.validating);
      _emitProgress(
        _createProgress(
          courseId,
          DownloadServiceState.validating,
          totalBytes: remoteManifest.sizeBytes,
          downloadedBytes: downloadedBytes,
          totalFiles: totalFiles,
        ),
      );

      // Step 6: Write the manifest beside the files it describes, then promote
      // pending → active.
      //
      // The manifest was only ever kept in SQLite, but everything that reads
      // geometry goes through LocalCoursePackageRepository, which discovers a
      // package by finding a manifest.json in its directory. Without this file
      // the package sits complete and checksum-verified on disk and is treated
      // as absent — the download succeeds and the golfer still gets no map.
      //
      // Written before promotion so a failure here fails the download rather
      // than marking active a package the reader cannot see.
      await _writePackageManifestFile(packageDir, remoteManifest);

      await _manifestRepo.promotePendingToActive(courseId);

      _setState(courseId, DownloadServiceState.offlineReady);
      _emitProgress(
        _createProgress(
          courseId,
          DownloadServiceState.offlineReady,
          totalBytes: remoteManifest.sizeBytes,
          downloadedBytes: downloadedBytes,
          totalFiles: totalFiles,
        ),
      );

      // Clear persisted download state on success
      await _packageRepo.clearDownloadState(courseId);

      return DownloadPackageSuccess(remoteManifest);
    } catch (e) {
      debugPrint('[CoursePackageDownloadService] Unexpected error: $e');
      await _manifestRepo.discardPending(courseId);
      _emitError(courseId, 'Unexpected error: $e');
      return DownloadPackageFailure(message: AppMessages.unexpectedError);
    } finally {
      _cancelTokens.remove(courseId);
    }
  }

  /// Pause an active download.
  void pauseDownload(int courseId) {
    final token = _cancelTokens[courseId];
    if (token != null && !token.isCancelled) {
      token.cancel('User paused download');
      _setState(courseId, DownloadServiceState.paused);
    }
  }

  /// Resume a paused download (re-starts from beginning).
  Future<DownloadPackageResult> resumeDownload(int courseId) async {
    return downloadPackage(courseId);
  }

  /// Cancel an active or paused download.
  void cancelDownload(int courseId) {
    final token = _cancelTokens[courseId];
    if (token != null && !token.isCancelled) {
      token.cancel('User cancelled download');
    }
    _setState(courseId, DownloadServiceState.idle);
  }

  /// Retry a failed or cancelled download.
  Future<DownloadPackageResult> retryDownload(int courseId) async {
    final currentProgress = await _packageRepo.getDownloadState(courseId);
    if (currentProgress != null) {
      final newProgress = currentProgress.copyWith(
        retryCount: currentProgress.retryCount + 1,
      );
      await _packageRepo.saveDownloadState(courseId, newProgress);
    }
    return downloadPackage(courseId);
  }

  /// Delete a downloaded course package.
  ///
  /// AC-2: Removes manifest + package files but PRESERVES round/score data
  /// (which live in separate SQLite tables: round_sync_store, score_sync_store).
  Future<void> deletePackage(int courseId) async {
    // Cancel any active download
    cancelDownload(courseId);

    // Delete manifest from SQLite (rounds/scores are NOT in this table)
    await _manifestRepo.deleteManifest(courseId);

    // Delete package files from app documents directory
    final appDir = await getApplicationDocumentsDirectory();
    final packageBase = Directory('${appDir.path}/packages/$courseId');
    if (await packageBase.exists()) {
      await packageBase.delete(recursive: true);
    }

    // Clear persisted download state
    await _packageRepo.clearDownloadState(courseId);

    _setState(courseId, DownloadServiceState.idle);
  }

  /// Fetch remote manifest for a course from the backend.
  Future<CoursePackageManifest?> _fetchRemoteManifest(int courseId) async {
    try {
      final data = await _packageRepo.fetchManifest(courseId);
      if (data == null) return null;
      return CoursePackageManifest.fromJson(data);
    } catch (e) {
      debugPrint('[CoursePackageDownloadService] Failed to fetch manifest: $e');
      return null;
    }
  }

  /// Writes `manifest.json` at the package root.
  ///
  /// This is the file [LocalCoursePackageRepository] looks for when it scans
  /// for downloaded packages, so it is what makes the download visible to the
  /// hole map, hole detection and every other geometry reader.
  Future<void> _writePackageManifestFile(
    Directory packageDir,
    CoursePackageManifest manifest,
  ) async {
    final file = File('${packageDir.path}/manifest.json');
    await file.writeAsString(jsonEncode(manifest.toJson()));
  }

  /// Build CDN URL for a file within a package.
  String _cdnUrl(CoursePackageManifest manifest, String filePath) {
    // CDN URL pattern from Story 4.2: packages/{courseId}/{version}/...
    // manifest.tilesUrl / manifest.geoJsonUrl are the full CDN URLs
    // For individual files, derive from base CDN path
    return VspEndpoints.packageFileUrl(
      courseId: manifest.courseId,
      version: manifest.version,
      filePath: filePath,
    );
  }

  /// Get the package directory for a course version.
  Future<Directory> _getPackageDir(int courseId, String version) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/packages/$courseId/$version');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  void _setState(int courseId, DownloadServiceState state) {
    _stateCache[courseId] = state;
  }

  void _emitProgress(DownloadProgress progress) {
    final controller = _progressControllers[progress.courseId];
    if (controller != null && !controller.isClosed) {
      controller.add(progress);
    }
  }

  void _emitError(int courseId, String message, {DownloadError? error}) {
    _setState(courseId, DownloadServiceState.error);
    _emitProgress(
      _createProgress(
        courseId,
        DownloadServiceState.error,
        error: error,
        errorMessage: message,
      ),
    );
  }

  DownloadProgress _createProgress(
    int courseId,
    DownloadServiceState state, {
    int totalBytes = 0,
    int downloadedBytes = 0,
    String? currentFile,
    int currentFileIndex = 0,
    int totalFiles = 0,
    DownloadError? error,
    String? errorMessage,
    int retryCount = 0,
  }) {
    return DownloadProgress(
      courseId: courseId,
      state: state,
      totalBytes: totalBytes,
      downloadedBytes: downloadedBytes,
      currentFile: currentFile,
      currentFileIndex: currentFileIndex,
      totalFiles: totalFiles,
      error: error,
      errorMessage: errorMessage,
      retryCount: retryCount,
    );
  }

  /// Dispose of all resources.
  void dispose() {
    for (final controller in _progressControllers.values) {
      controller.close();
    }
    _progressControllers.clear();
    _cancelTokens.clear();
  }
}
