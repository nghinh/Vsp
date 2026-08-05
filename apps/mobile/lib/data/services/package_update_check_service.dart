// Package Update Check Service — VSP Mobile App
//
// Checks for available course package updates using ETag conditional fetch.
// Story 4.4 INC-MOBILE-VC: version check service with ETag round-trip.
//
// Flow:
// 1. Read active manifest + stored ETag from PackageManifestRepository
// 2. Call GET /courses/{courseId}/packages/current with If-None-Match header
// 3. 200 + new manifest → UpdateAvailable(newEtag)
// 4. 304 Not Modified → UpdateNotAvailable
// 5. Error → UpdateCheckFailed

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/network/api_client.dart';
import '../../domain/models/course_package_manifest.dart';
import '../../domain/models/course_update_state.dart';
import '../repositories/package_manifest_repository.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

/// Service to check for available course package updates.
///
/// Uses ETag conditional fetch to avoid downloading full manifest
/// when client already has the latest version.
class PackageUpdateCheckService {
  final ApiClient _apiClient;
  final PackageManifestRepository _manifestRepo;

  PackageUpdateCheckService({
    required ApiClient apiClient,
    required PackageManifestRepository manifestRepo,
  }) : _apiClient = apiClient,
       _manifestRepo = manifestRepo;

  /// Check if an update is available for a course package.
  ///
  /// Returns:
  /// - [UpdateAvailable] with new ETag when server has newer version
  /// - [UpdateNotAvailable] when client already has latest
  /// - [UpdateCheckFailed] on network or server error
  Future<CourseUpdateState> checkForUpdate(int courseId) async {
    try {
      // Step 1: Get stored ETag from local active manifest
      final activeManifest = await _manifestRepo.getActiveManifest(courseId);
      final storedEtag = activeManifest != null
          ? await _manifestRepo.getActiveEtag(courseId)
          : null;

      // Step 2: Conditional fetch — send If-None-Match if we have a stored ETag
      final headers = <String, String>{};
      if (storedEtag != null) {
        headers['If-None-Match'] = storedEtag;
      }

      final response = await _apiClient.getRaw(
        '/courses/$courseId/packages/current',
        headers: headers.isNotEmpty ? headers : null,
      );

      switch (response.statusCode) {
        case 200:
          // Server has newer version — parse manifest and return ETag
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final newEtag = response.headers['etag'] ?? _computeEtag(body);
          return UpdateAvailable(etag: newEtag, courseId: courseId);

        case 304:
          // Client already has latest version
          return UpdateNotAvailable();

        case 404:
          // No active package for this course
          return UpdateCheckFailed(
            message: AppMessages.noActivePackage,
          );

        default:
          return UpdateCheckFailed(
            message: AppMessages.serverError,
          );
      }
    } on VspApiException catch (e) {
      if (e.isNotModified) {
        return UpdateNotAvailable();
      }
      return UpdateCheckFailed(
        message: e.message,
        isNetworkError: e.code == 'NETWORK_ERROR',
      );
    } on http.ClientException catch (e) {
      return UpdateCheckFailed(
        message: AppMessages.networkError,
        isNetworkError: true,
      );
    } catch (e) {
      debugPrint('[PackageUpdateCheckService] Unexpected error: $e');
      return UpdateCheckFailed(message: AppMessages.unexpectedError);
    }
  }

  /// Fetch the full manifest for a course.
  ///
  /// Called after checkForUpdate returns UpdateAvailable to get the new manifest.
  Future<CoursePackageManifest?> fetchManifest(
    int courseId, {
    String? etag,
  }) async {
    try {
      final headers = <String, String>{};
      if (etag != null) {
        headers['If-None-Match'] = etag;
      }

      final data = await _apiClient.get(
        '/courses/$courseId/packages/current',
        headers: headers.isNotEmpty ? headers : null,
      );

      if (data == null) return null;
      return CoursePackageManifest.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[PackageUpdateCheckService] Failed to fetch manifest: $e');
      return null;
    }
  }

  /// Compute ETag from manifest JSON (fallback when server doesn't return ETag header).
  String _computeEtag(Map<String, dynamic> manifestJson) {
    final courseId = manifestJson['courseId']?.toString() ?? '';
    final version = manifestJson['version']?.toString() ?? '';
    final generatedAt = manifestJson['generatedAt']?.toString() ?? '';
    final input = '$courseId;$version;$generatedAt';
    return input.hashCode.toString();
  }
}
