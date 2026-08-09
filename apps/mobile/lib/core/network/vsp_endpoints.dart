// VSP Endpoints — VSP Mobile App
//
// Where this build talks to, in one place.
//
// It was in four places and each was wrong for a release build. Three API
// clients each declared their own
// `String.fromEnvironment('VSP_API_BASE_URL', defaultValue: 'http://localhost:8080')`,
// with no debug guard and nothing in the repository passing the define — no CI
// step, no Makefile, no fastlane config — so a release build called localhost
// from the phone and every request failed. The tournament client did not even
// use a define: it hardcoded `https://api.vsp.local`, and `.local` is the mDNS
// reserved TLD, so that host cannot resolve anywhere. Course packages pointed
// at `https://cdn.vnptgolf.vn`, which does not exist (NXDOMAIN), while the
// API's own `/packages/**` endpoint — deliberately public, written to stand in
// for a CDN — was never called.
//
// Configure a real build with:
//
//   flutter build apk --dart-define=VSP_API_BASE_URL=https://api.example.vn
//
// and optionally, when packages are served from a CDN rather than the API:
//
//   --dart-define=VSP_PACKAGE_BASE_URL=https://cdn.example.vn
//
// A debug build with no defines keeps pointing at the local backend, which is
// what a developer wants. A *release* build with no defines is a mistake that
// must not be silent — see [isConfigured].

import 'package:flutter/foundation.dart';

/// Base URLs for everything this app talks to.
abstract final class VspEndpoints {
  /// Local backend, as `infra/scripts/runLocalServices.sh` starts it.
  static const String devApiBaseUrl = 'http://localhost:8080';

  static const String _apiBaseUrl = String.fromEnvironment('VSP_API_BASE_URL');

  static const String _packageBaseUrl = String.fromEnvironment(
    'VSP_PACKAGE_BASE_URL',
  );

  /// True when this build knows which server it belongs to.
  ///
  /// False only in a release build compiled without `VSP_API_BASE_URL`. The
  /// app surfaces that rather than spending the golfer's afternoon failing to
  /// reach a host that only exists on a developer's laptop.
  static bool get isConfigured => _apiBaseUrl.isNotEmpty || !kReleaseMode;

  /// Base URL of the VSP API.
  ///
  /// Falls back to the local backend in debug and profile builds only.
  static String get apiBaseUrl =>
      _apiBaseUrl.isNotEmpty ? _apiBaseUrl : devApiBaseUrl;

  /// Base URL course package files are fetched from.
  ///
  /// Defaults to the API itself, which serves `/packages/**` for exactly this
  /// reason. Point it at a CDN when there is one.
  static String get packageBaseUrl =>
      _packageBaseUrl.isNotEmpty ? _packageBaseUrl : apiBaseUrl;

  /// Directory a course version's files live under.
  static String packageDirUrl({
    required int courseId,
    required String version,
  }) => '$packageBaseUrl/packages/$courseId/$version';

  /// URL of one file inside a course version's package.
  static String packageFileUrl({
    required int courseId,
    required String version,
    required String filePath,
  }) => '${packageDirUrl(courseId: courseId, version: version)}/$filePath';
}
