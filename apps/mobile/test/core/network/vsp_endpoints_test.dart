// Tests for where this build talks to.
//
// Three API clients each carried their own
// `String.fromEnvironment('VSP_API_BASE_URL', defaultValue: 'http://localhost:8080')`
// with no debug guard, the tournament client hardcoded the unroutable
// `https://api.vsp.local`, and course packages pointed at `cdn.vnptgolf.vn`,
// which does not resolve. Nothing in the repository passed the define, so every
// release build called a host that only exists on a developer's laptop.
//
// The tests run against a binary compiled without any --dart-define, which is
// the case that used to be silently broken.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/core/network/vsp_endpoints.dart';

void main() {
  test('an unconfigured debug build points at the local backend', () {
    // What a developer wants, and the only build allowed to assume it.
    expect(VspEndpoints.apiBaseUrl, VspEndpoints.devApiBaseUrl);
    expect(VspEndpoints.isConfigured, !kReleaseMode);
  });

  test('packages are served by the API unless a CDN is configured', () {
    // The server exposes /packages/** deliberately, "in place of a CDN", and
    // it was never called: the client asked cdn.vnptgolf.vn, which is NXDOMAIN.
    expect(VspEndpoints.packageBaseUrl, VspEndpoints.apiBaseUrl);
    expect(
      VspEndpoints.packageDirUrl(courseId: 7, version: '2026.08.01'),
      '${VspEndpoints.apiBaseUrl}/packages/7/2026.08.01',
    );
    expect(
      VspEndpoints.packageFileUrl(
        courseId: 7,
        version: '2026.08.01',
        filePath: 'geometry.geojson',
      ),
      '${VspEndpoints.apiBaseUrl}/packages/7/2026.08.01/geometry.geojson',
    );
  });

  test('no unroutable host survives anywhere in the resolved URLs', () {
    // `.local` is the mDNS reserved TLD and cdn.vnptgolf.vn does not exist.
    // Neither can be reached from any device, so neither may be a default.
    final urls = [
      VspEndpoints.apiBaseUrl,
      VspEndpoints.packageBaseUrl,
      VspEndpoints.packageDirUrl(courseId: 1, version: 'v1'),
    ];
    for (final url in urls) {
      expect(url, isNot(contains('api.vsp.local')));
      expect(url, isNot(contains('cdn.vnptgolf.vn')));
    }
  });
}
