// Package File Downloader — VSP Mobile App
//
// Downloads a single file from a URL to a local path, computing SHA-256
// checksum during download and validating against the expected checksum.
//
// Uses dio for download with cancel token support (pause/resume).

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

/// Result of a file download operation.
sealed class DownloadFileResult {}

/// File downloaded successfully.
class DownloadFileSuccess extends DownloadFileResult {
  final File file;
  final int totalBytes;

  DownloadFileSuccess({required this.file, required this.totalBytes});
}

/// Download was cancelled (e.g., paused by user).
class DownloadFileCancelled extends DownloadFileResult {
  DownloadFileCancelled();
}

/// Download failed with an error.
class DownloadFileFailure extends DownloadFileResult {
  final String message;
  final bool isChecksumMismatch;
  final bool isNetworkError;
  final bool isStorageError;

  DownloadFileFailure({
    required this.message,
    this.isChecksumMismatch = false,
    this.isNetworkError = false,
    this.isStorageError = false,
  });
}

/// Downloads a single file with progress reporting and SHA-256 checksum validation.
class PackageFileDownloader {
  final Dio _dio;

  PackageFileDownloader({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(minutes: 10),
              sendTimeout: const Duration(seconds: 30),
            ),
          );

  /// Download a file from [url] to [savePath].
  ///
  /// [onProgress] is called with (bytesReceived, totalBytes) during download.
  ///
  /// [expectedChecksum] is the SHA-256 hex string to validate against.
  /// If the computed checksum doesn't match, returns [DownloadFileFailure] with
  /// [DownloadFileFailure.isChecksumMismatch] = true.
  ///
  /// Returns [DownloadFileSuccess], [DownloadFileCancelled], or [DownloadFileFailure].
  Future<DownloadFileResult> downloadFile({
    required String url,
    required String savePath,
    required String expectedChecksum,
    void Function(int bytesReceived, int totalBytes)? onProgress,
    CancelToken? cancelToken,
  }) async {
    cancelToken ??= CancelToken();

    final file = File(savePath);
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    int totalBytes = 0;

    try {
      await _dio.download(
        url,
        file.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          totalBytes = total > 0 ? total : 0;
          onProgress?.call(received, total);
        },
        deleteOnError: true,
      );

      // Hash what was actually written, read back off disk.
      //
      // This used to be computed inside onReceiveProgress, from
      // `List.filled(received, 0)` — a zero-filled buffer whose length was the
      // *cumulative* progress counter. dio's callback reports how many bytes
      // have arrived, not which bytes; the payload was never available there.
      // So the digest was of a growing run of zeros, fed in overlapping
      // slices, and bore no relation to the file. It could not have matched
      // any real manifest checksum, which means this check had two states —
      // reject everything, or never run — and only the second was ever
      // observed, because the packages being served carry no files at all.
      final computed = await _sha256OfFile(file);

      if (computed != expectedChecksum) {
        debugPrint(
          '[PackageFileDownloader] Checksum mismatch for $url: '
          'expected $expectedChecksum, got $computed',
        );
        // Delete corrupted file
        if (await file.exists()) {
          await file.delete();
        }
        return DownloadFileFailure(
          message: AppMessages.checksumMismatch,
          isChecksumMismatch: true,
        );
      }

      return DownloadFileSuccess(file: file, totalBytes: totalBytes);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return DownloadFileCancelled();
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return DownloadFileFailure(
          message: AppMessages.networkError,
          isNetworkError: true,
        );
      }
      if (e.type == DioExceptionType.badResponse) {
        return DownloadFileFailure(
          message: AppMessages.serverError,
          isNetworkError: true,
        );
      }
      return DownloadFileFailure(message: e.message ?? 'Download failed');
    } on FileSystemException catch (e) {
      final isStorage = e.osError?.errorCode == 28; // ENOSPC
      return DownloadFileFailure(
        message: AppMessages.storageError,
        isStorageError: isStorage,
      );
    } catch (e) {
      return DownloadFileFailure(message: AppMessages.unexpectedError);
    }
  }

  /// SHA-256 of a file's contents, hex, streamed so a large tile pack is never
  /// held in memory.
  static Future<String> _sha256OfFile(File file) async {
    final sink = AccumulatorSink<Digest>();
    final hashOutput = sha256.startChunkedConversion(sink);
    await for (final chunk in file.openRead()) {
      hashOutput.add(chunk);
    }
    hashOutput.close();
    return sink.events.single.toString();
  }

  /// Cancel an active download.
  void cancelDownload(CancelToken token) {
    token.cancel('User cancelled download');
  }

  void close() {
    _dio.close();
  }
}

/// Helper to accumulate digest chunks.
class AccumulatorSink<T> implements Sink<T> {
  final List<T> events = [];

  @override
  void add(T event) => events.add(event);

  @override
  void close() {}
}
