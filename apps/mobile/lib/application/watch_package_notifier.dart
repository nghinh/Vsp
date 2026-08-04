// Watch Package Notifier — VSP Mobile App
//
// State management for watch package download and sync.
// Coordinates between mobile and watch for course data.
//
// Story 10.1 — Slice 4: Offline Course Subset

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

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

// ─── Notifier/Cubit ─────────────────────────────────────────────────────────

class WatchPackageNotifier extends Cubit<WatchPackageState> {
  final WatchConnectivity _watch;

  WatchPackageNotifier({WatchConnectivity? watch})
    : _watch = watch ?? WatchConnectivity(),
      super(const WatchPackageState());

  /// Start listening for watch connectivity.
  Future<void> startListening() async {
    _watch.messageStream.listen(_handleWatchMessage);

    // Check current connection
    emit(state.copyWith(connectionStatus: WatchConnectionStatus.connecting));

    // Simulate connection check
    await Future.delayed(const Duration(milliseconds: 500));

    emit(state.copyWith(connectionStatus: WatchConnectionStatus.disconnected));
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

    try {
      // Simulate download progress
      for (var i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        emit(state.copyWith(downloadProgress: i / 10));
      }

      // Add to downloaded list
      final updated = [...state.downloadedCourseIds, courseId];

      emit(
        state.copyWith(
          downloadedCourseIds: updated,
          isDownloading: false,
          downloadProgress: 1.0,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isDownloading: false,
          errorMessage: 'Download failed: $e',
        ),
      );
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
