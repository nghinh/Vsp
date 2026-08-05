// Watch Package Notifier — VSP Mobile App
//
// State management for watch package download and sync.
// Coordinates between mobile and watch for course data.
//
// Story 10.1 — Slice 4: Offline Course Subset

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:watch_connectivity/watch_connectivity.dart';
import '../core/network/api_client.dart';
import '../data/repositories/course_package_repository.dart';
import '../data/repositories/package_manifest_repository.dart';
import '../data/services/connectivity_service.dart';
import '../data/services/course_package_download_service.dart';
import '../data/services/package_file_downloader.dart';
import '../l10n/app_messages.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Events ─────────────────────────────────────────────────────────────────

abstract class WatchPackageEvent extends Equatable {
  const WatchPackageEvent();

  @override
  List<Object?> get props => [];
}

class WatchPackageStarted extends WatchPackageEvent {
  const WatchPackageStarted();
}

class WatchPackageCheckStatus extends WatchPackageEvent {
  const WatchPackageCheckStatus();
}

class WatchPackageDownloadRequested extends WatchPackageEvent {
  final int courseId;
  const WatchPackageDownloadRequested(this.courseId);

  @override
  List<Object?> get props => [courseId];
}

class WatchPackageSyncRequested extends WatchPackageEvent {
  const WatchPackageSyncRequested();
}

class WatchPackageReceived extends WatchPackageEvent {
  final Map<String, dynamic> packageData;
  const WatchPackageReceived(this.packageData);

  @override
  List<Object?> get props => [packageData];
}

class WatchPackageError extends WatchPackageEvent {
  final String message;
  const WatchPackageError(this.message);

  @override
  List<Object?> get props => [message];
}

// ─── State ──────────────────────────────────────────────────────────────────

enum WatchConnectionStatus { disconnected, connecting, connected, transferring }

class WatchPackageState extends Equatable {
  final WatchConnectionStatus connectionStatus;
  final String? pairedWatchName;
  final List<int> downloadedCourseIds;
  final bool isDownloading;
  final double? downloadProgress;
  final String? errorMessage;
  final DateTime? lastSyncTime;

  const WatchPackageState({
    this.connectionStatus = WatchConnectionStatus.disconnected,
    this.pairedWatchName,
    this.downloadedCourseIds = const [],
    this.isDownloading = false,
    this.downloadProgress,
    this.errorMessage,
    this.lastSyncTime,
  });

  WatchPackageState copyWith({
    WatchConnectionStatus? connectionStatus,
    String? pairedWatchName,
    List<int>? downloadedCourseIds,
    bool? isDownloading,
    double? downloadProgress,
    String? errorMessage,
    DateTime? lastSyncTime,
  }) {
    return WatchPackageState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      pairedWatchName: pairedWatchName ?? this.pairedWatchName,
      downloadedCourseIds: downloadedCourseIds ?? this.downloadedCourseIds,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress,
      errorMessage: errorMessage,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  @override
  List<Object?> get props => [
    connectionStatus,
    pairedWatchName,
    downloadedCourseIds,
    isDownloading,
    downloadProgress,
    errorMessage,
    lastSyncTime,
  ];
}

/// Builds the real package download service. Async because the connectivity
/// service needs SharedPreferences for the Wi-Fi-only preference.
Future<CoursePackageDownloadService> _buildDownloadService() async {
  final apiClient = ApiClient();
  return CoursePackageDownloadService(
    manifestRepo: PackageManifestRepository(),
    packageRepo: CoursePackageRepository(apiClient: apiClient),
    downloader: PackageFileDownloader(),
    connectivity: ConnectivityService(prefs: await SharedPreferences.getInstance()),
  );
}

// ─── Notifier/Cubit ─────────────────────────────────────────────────────────

class WatchPackageNotifier extends Cubit<WatchPackageState> {
  final WatchConnectivity _watch;
  CoursePackageDownloadService? _downloadService;

  WatchPackageNotifier({
    WatchConnectivity? watch,
    CoursePackageDownloadService? downloadService,
  }) : _watch = watch ?? WatchConnectivity(),
       _downloadService = downloadService,
       super(const WatchPackageState());

  Future<CoursePackageDownloadService> _service() async =>
      _downloadService ??= await _buildDownloadService();

  /// Start listening for watch connectivity.
  Future<void> startListening() async {
    _watch.messageStream.listen(_handleWatchMessage);

    // Report the watch's real reachability rather than assuming disconnected.
    emit(state.copyWith(connectionStatus: WatchConnectionStatus.connecting));
    await checkStatus();
  }

  /// Check watch connection status.
  Future<void> checkStatus() async {
    emit(state.copyWith(connectionStatus: WatchConnectionStatus.connecting));

    // Check if watch is reachable
    final isReachable = await _watch.isReachable;

    emit(
      state.copyWith(
        connectionStatus: isReachable
            ? WatchConnectionStatus.connected
            : WatchConnectionStatus.disconnected,
      ),
    );
  }

  /// Download watch package for a course.
  Future<void> downloadPackage(int courseId) async {
    emit(
      state.copyWith(
        isDownloading: true,
        downloadProgress: 0,
        errorMessage: null,
      ),
    );

    // Mirror the real package download: progress comes from the download
    // service's stream, and only a successful download marks the course as
    // available to the watch.
    final service = await _service();
    final progressSub = service
        .getProgressStream(courseId)
        .listen(
          (progress) =>
              emit(state.copyWith(downloadProgress: progress.percentComplete)),
        );

    try {
      final result = await service.downloadPackage(courseId);
      if (result is DownloadPackageSuccess) {
        emit(
          state.copyWith(
            downloadedCourseIds: {
              ...state.downloadedCourseIds,
              courseId,
            }.toList(),
            isDownloading: false,
            downloadProgress: 1.0,
          ),
        );
      } else if (result is DownloadPackageFailure) {
        emit(
          state.copyWith(
            isDownloading: false,
            errorMessage: result.message,
          ),
        );
      } else {
        emit(state.copyWith(isDownloading: false));
      }
    } catch (e) {
      emit(
        state.copyWith(
          isDownloading: false,
          errorMessage: AppMessages.unexpectedError,
        ),
      );
    } finally {
      await progressSub.cancel();
    }
  }

  /// Sync packages to watch.
  Future<void> syncToWatch() async {
    if (state.downloadedCourseIds.isEmpty) {
      emit(state.copyWith(errorMessage: 'No packages to sync'));
      return;
    }

    emit(state.copyWith(connectionStatus: WatchConnectionStatus.transferring));

    try {
      // Send package data to watch
      await _watch.sendMessage({
        'type': 'package_sync',
        'courseIds': state.downloadedCourseIds,
      });

      emit(
        state.copyWith(
          connectionStatus: WatchConnectionStatus.connected,
          lastSyncTime: DateTime.now(),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          connectionStatus: WatchConnectionStatus.connected,
          errorMessage: 'Sync failed: $e',
        ),
      );
    }
  }

  void _handleWatchMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    switch (type) {
      case 'watch_paired':
        emit(
          state.copyWith(
            connectionStatus: WatchConnectionStatus.connected,
            pairedWatchName: message['name'] as String?,
          ),
        );
        break;

      case 'package_received':
        // Watch confirms package receipt
        break;

      case 'error':
        emit(state.copyWith(errorMessage: message['message'] as String?));
        break;
    }
  }
}
