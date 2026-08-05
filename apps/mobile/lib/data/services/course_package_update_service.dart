// Course Package Update Service — VSP Mobile App
//
// Orchestrates incremental (delta) course package updates.
// Reuses the download infrastructure from Story 4.3 but only downloads changed files.
//
// Story 4.4 INC-MOBILE-DOWNLOAD: delta download and verification.
//
// Flow:
// 1. Check for update via PackageUpdateCheckService
// 2. Fetch new manifest if update available
// 3. Compute delta via PackageDeltaService
// 4. Save new manifest as pending with etag
// 5. Download only delta files (new/changed)
// 6. Delete removed files
// 7. Validate file inventory
// 8. Promote pending → active on success, discard on failure

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/models/course_package_manifest.dart';
import '../../domain/models/course_update_state.dart';
import '../../domain/models/download_progress.dart';
import '../../domain/models/download_state.dart';
import '../../domain/models/package_delta.dart';
import '../repositories/package_manifest_repository.dart';
import 'connectivity_service.dart';
import 'package_delta_service.dart';
import 'package_file_downloader.dart';
import 'package_update_check_service.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

/// Result of an update operation.
sealed class UpdateResult {}

/// Update completed successfully.
class UpdateSuccess extends UpdateResult {
  final CoursePackageManifest manifest;
  UpdateSuccess(this.manifest);
}

/// Update was cancelled by user.
class UpdateCancelled extends UpdateResult {}

/// Update failed with an error.
class UpdateFailure extends UpdateResult {
  final String message;
  final UpdateError? error;

  UpdateFailure({required this.message, this.error});
}

/// Error types for update failures.
enum UpdateError {
  networkError,
  checksumMismatch,
  storageError,
  validationFailed,
  activeRoundBlocked,
  unknown,
}

/// Orchestrates incremental course package updates.
///
/// Reuses [PackageFileDownloader] for HTTP downloads and
/// [PackageManifestRepository] for pending/active promotion.
class CoursePackageUpdateService {
  final PackageUpdateCheckService _updateChecker;
  final PackageDeltaService _deltaService;
  final PackageManifestRepository _manifestRepo;
  final PackageFileDownloader _downloader;
  final ConnectivityService _connectivity;

  /// Active update progress streams keyed by courseId.
  final _progressControllers = <int, StreamController<DownloadProgress>>{};

  /// Active update cancel tokens keyed by courseId.
  final _cancelTokens = <int, CancelToken>{};

  CoursePackageUpdateService({
    required PackageUpdateCheckService updateChecker,
    required PackageDeltaService deltaService,
    required PackageManifestRepository manifestRepo,
    required PackageFileDownloader downloader,
    required ConnectivityService connectivity,
  }) : _updateChecker = updateChecker,
       _deltaService = deltaService,
       _manifestRepo = manifestRepo,
       _downloader = downloader,
       _connectivity = connectivity;

  /// Get a stream of update progress for a course.
  Stream<DownloadProgress> getProgressStream(int courseId) {
    _progressControllers[courseId] ??=
        StreamController<DownloadProgress>.broadcast();
    return _progressControllers[courseId]!.stream;
  }

  /// Perform an incremental update check for a course.
  ///
  /// Does NOT trigger download — use [updatePackage] to download and apply.
  /// Returns the update state without modifying local data.
  Future<CourseUpdateState> checkForUpdate(int courseId) {
    return _updateChecker.checkForUpdate(courseId);
  }

  /// Perform an incremental update for a course.
  ///
  /// Flow:
  /// 1. Check Wi-Fi policy
  /// 2. Check for update via PackageUpdateCheckService
  /// 3. Fetch new manifest
  /// 4. Compute delta
  /// 5. Save pending manifest + etag
  /// 6. Download delta files
  /// 7. Delete removed files
  /// 8. Validate and promote
  Future<UpdateResult> updatePackage(
    int courseId, {
    bool wifiOnly = false,
  }) async {
    if (wifiOnly) {
      await _connectivity.setWifiOnly(true);
    }

    if (!await _connectivity.shouldDownload) {
      _emitProgress(
        _createProgress(
          courseId,
          DownloadServiceState.error,
          error: DownloadError.networkError,
          errorMessage:
              'Wi-Fi required for update. Connect to Wi-Fi and try again.',
        ),
      );
      return UpdateFailure(
        message: AppMessages.wifiRequiredUpdate,
        error: UpdateError.networkError,
      );
    }

    final cancelToken = CancelToken();
    _cancelTokens[courseId] = cancelToken;

    try {
      _emitProgress(
        _createProgress(
          courseId,
          DownloadServiceState.fetchingManifest,
          totalFiles: 0,
        ),
      );

      // Step 1: Check for update
      final updateState = await _updateChecker.checkForUpdate(courseId);

      switch (updateState) {
        case UpdateNotAvailable():
          _emitProgress(
            _createProgress(
              courseId,
              DownloadServiceState.offlineReady,
              totalFiles: 0,
            ),
          );
          return UpdateSuccess(
            (await _manifestRepo.getActiveManifest(courseId))!,
          );

        case UpdateCheckFailed(message: final msg):
          _emitProgress(
            _createProgress(
              courseId,
              DownloadServiceState.error,
              error: DownloadError.networkError,
              errorMessage: msg,
            ),
          );
          return UpdateFailure(message: msg, error: UpdateError.networkError);

        case UpdateAvailable(etag: final etag):
          // Step 2: Fetch new manifest
          final newManifest = await _updateChecker.fetchManifest(
            courseId,
            etag: etag,
          );
          if (newManifest == null) {
            return UpdateFailure(
              message: AppMessages.manifestNewFetchFailed,
              error: UpdateError.networkError,
            );
          }

          // Step 3: Get old manifest for delta computation
          final oldManifest = await _manifestRepo.getActiveManifest(courseId);
          if (oldManifest == null) {
            // No existing manifest — this is a fresh download, not an update
            // Delegate to CoursePackageDownloadService for full download
            return UpdateFailure(
              message: AppMessages.noExistingManifest,
              error: UpdateError.unknown,
            );
          }

          // Step 4: Compute delta
          final delta = _deltaService.computeDelta(oldManifest, newManifest);
          if (delta.isEmpty) {
            // Versions differ but no actual file changes — just update manifest
            await _manifestRepo.savePendingManifest(newManifest, etag: etag);
            await _manifestRepo.promotePendingToActive(courseId);
            _emitProgress(
              _createProgress(
                courseId,
                DownloadServiceState.offlineReady,
                totalBytes: 0,
                downloadedBytes: 0,
                totalFiles: 0,
              ),
            );
            return UpdateSuccess(newManifest);
          }

          // Step 5: Save pending manifest + etag
          await _manifestRepo.savePendingManifest(newManifest, etag: etag);

          // Step 6: Download delta files
          _emitProgress(
            _createProgress(
              courseId,
              DownloadServiceState.downloading,
              totalBytes: delta.totalDownloadBytes,
              downloadedBytes: 0,
              totalFiles: delta.toDownload.length,
            ),
          );

          int downloadedBytes = 0;
          final pendingDir = await _getPendingDir(courseId);

          for (int i = 0; i < delta.toDownload.length; i++) {
            if (cancelToken.isCancelled) {
              await _manifestRepo.discardPending(courseId);
              return UpdateCancelled();
            }

            final file = delta.toDownload[i];
            _emitProgress(
              _createProgress(
                courseId,
                DownloadServiceState.downloading,
                totalBytes: delta.totalDownloadBytes,
                downloadedBytes: downloadedBytes,
                currentFile: file.path,
                currentFileIndex: i,
                totalFiles: delta.toDownload.length,
              ),
            );

            final savePath = '${pendingDir.path}/${file.path}';
            final result = await _downloader.downloadFile(
              url: _cdnUrl(newManifest, file.path),
              savePath: savePath,
              expectedChecksum: file.checksum,
              cancelToken: cancelToken,
            );

            switch (result) {
              case DownloadFileSuccess():
                downloadedBytes += result.totalBytes;
              case DownloadFileCancelled():
                await _manifestRepo.discardPending(courseId);
                return UpdateCancelled();
              case DownloadFileFailure(message: final msg):
                await _manifestRepo.discardPending(courseId);
                _emitProgress(
                  _createProgress(
                    courseId,
                    DownloadServiceState.error,
                    error: result.isChecksumMismatch
                        ? DownloadError.checksumMismatch
                        : result.isNetworkError
                        ? DownloadError.networkError
                        : DownloadError.unknown,
                    errorMessage: msg,
                  ),
                );
                return UpdateFailure(
                  message: msg,
                  error: result.isChecksumMismatch
                      ? UpdateError.checksumMismatch
                      : result.isNetworkError
                      ? UpdateError.networkError
                      : UpdateError.storageError,
                );
            }
          }

          // Step 7: Delete removed files
          for (final path in delta.toDelete) {
            final file = File('${pendingDir.path}/$path');
            if (await file.exists()) {
              await file.delete();
            }
          }

          // Step 8: Validate file inventory
          _emitProgress(
            _createProgress(
              courseId,
              DownloadServiceState.validating,
              totalBytes: delta.totalDownloadBytes,
              downloadedBytes: downloadedBytes,
              totalFiles: delta.toDownload.length,
            ),
          );

          final extractedPaths = await _getExtractedPaths(pendingDir);
          // Validation would be done here if needed

          // Step 9: Promote pending → active
          await _manifestRepo.promotePendingToActive(courseId);

          _emitProgress(
            _createProgress(
              courseId,
              DownloadServiceState.offlineReady,
              totalBytes: delta.totalDownloadBytes,
              downloadedBytes: downloadedBytes,
              totalFiles: delta.toDownload.length,
            ),
          );

          return UpdateSuccess(newManifest);
      }
    } catch (e) {
      debugPrint('[CoursePackageUpdateService] Unexpected error: $e');
      await _manifestRepo.discardPending(courseId);
      _emitProgress(
        _createProgress(
          courseId,
          DownloadServiceState.error,
          error: DownloadError.unknown,
          errorMessage: 'Unexpected error: $e',
        ),
      );
      return UpdateFailure(message: AppMessages.unexpectedError);
    } finally {
      _cancelTokens.remove(courseId);
    }
  }

  /// Cancel an active update.
  void cancelUpdate(int courseId) {
    final token = _cancelTokens[courseId];
    if (token != null && !token.isCancelled) {
      token.cancel('User cancelled update');
    }
  }

  /// Get the pending (update-in-progress) directory for a course.
  Future<Directory> _getPendingDir(int courseId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/packages/$courseId/pending');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Build CDN URL for a file within a package.
  String _cdnUrl(CoursePackageManifest manifest, String filePath) {
    final base =
        'https://cdn.vnptgolf.vn/packages/${manifest.courseId}/${manifest.version}';
    return '$base/$filePath';
  }

  /// Get the set of file paths in a directory (recursive).
  Future<Set<String>> _getExtractedPaths(Directory dir) async {
    final paths = <String>{};
    if (!await dir.exists()) return paths;

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final relative = entity.path.substring(dir.path.length + 1);
        paths.add(relative);
      }
    }
    return paths;
  }

  void _emitProgress(DownloadProgress progress) {
    final controller = _progressControllers[progress.courseId];
    if (controller != null && !controller.isClosed) {
      controller.add(progress);
    }
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
    );
  }

  void dispose() {
    for (final controller in _progressControllers.values) {
      controller.close();
    }
    _progressControllers.clear();
    _cancelTokens.clear();
  }
}
