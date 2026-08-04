// Download Progress Model — VSP Mobile App
//
// Tracks real-time progress of a course package download.
// Used by CourseDownloadScreen and DownloadProgressIndicator.

import 'package:equatable/equatable.dart';

import 'download_state.dart';

/// Real-time download progress for a course package.
class DownloadProgress extends Equatable {
  /// Course ID being downloaded.
  final int courseId;

  /// Current state of the download.
  final DownloadServiceState state;

  /// Total bytes to download across all files.
  final int totalBytes;

  /// Bytes downloaded so far.
  final int downloadedBytes;

  /// Name of the currently downloading file.
  final String? currentFile;

  /// 0-based index of the current file being downloaded.
  final int currentFileIndex;

  /// Total number of files to download.
  final int totalFiles;

  /// Human-readable error message when state is error.
  final String? errorMessage;

  /// Type of error when state is error.
  final DownloadError? error;

  /// Number of retry attempts made.
  final int retryCount;

  const DownloadProgress({
    required this.courseId,
    required this.state,
    required this.totalBytes,
    required this.downloadedBytes,
    this.currentFile,
    required this.currentFileIndex,
    required this.totalFiles,
    this.errorMessage,
    this.error,
    this.retryCount = 0,
  });

  /// Percent complete as a value from 0.0 to 1.0.
  double get percentComplete {
    if (totalBytes == 0) return 0.0;
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
  }

  /// Percent complete as an integer from 0 to 100.
  int get percentCompleteInt => (percentComplete * 100).round();

  @override
  List<Object?> get props => [
    courseId,
    state,
    totalBytes,
    downloadedBytes,
    currentFile,
    currentFileIndex,
    totalFiles,
    errorMessage,
    error,
    retryCount,
  ];

  DownloadProgress copyWith({
    int? courseId,
    DownloadServiceState? state,
    int? totalBytes,
    int? downloadedBytes,
    String? currentFile,
    int? currentFileIndex,
    int? totalFiles,
    String? errorMessage,
    DownloadError? error,
    int? retryCount,
  }) {
    return DownloadProgress(
      courseId: courseId ?? this.courseId,
      state: state ?? this.state,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      currentFile: currentFile ?? this.currentFile,
      currentFileIndex: currentFileIndex ?? this.currentFileIndex,
      totalFiles: totalFiles ?? this.totalFiles,
      errorMessage: errorMessage ?? this.errorMessage,
      error: error ?? this.error,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}
