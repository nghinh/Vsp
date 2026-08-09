// PerformanceApi — VSP Mobile App
//
// API client for club performance and dispersion overlay endpoints.
// Per Story 11.1 Slice 1 (backend) API contracts.

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:vsp_mobile/core/network/vsp_endpoints.dart';

import '../../core/network/api_client.dart';
import '../../domain/models/performance/club_performance_stats.dart';
import '../../domain/models/performance/dispersion_overlay.dart';

/// API response wrapper for club performance.
class ClubPerformanceApiResponse {
  final ClubPerformanceStats stats;
  final DateTime? cachedAt;

  const ClubPerformanceApiResponse({required this.stats, this.cachedAt});
}

/// API response wrapper for bag performance.
class BagPerformanceApiResponse {
  final BagPerformance performance;
  final DateTime? cachedAt;

  const BagPerformanceApiResponse({required this.performance, this.cachedAt});
}

/// API response wrapper for dispersion overlay.
class DispersionOverlayApiResponse {
  final DispersionOverlay overlay;

  const DispersionOverlayApiResponse({required this.overlay});
}

/// API client for club performance and dispersion endpoints.
///
/// Endpoints:
/// - GET /bags/{bagId}/clubs/{clubId}/performance
/// - GET /bags/{bagId}/performance
/// - GET /bags/{bagId}/clubs/{clubId}/dispersion?holeId={holeId}&layoutId={layoutId}
class PerformanceApi {
  // Must match ApiClient._baseUrl
  static String get _baseUrl => VspEndpoints.apiBaseUrl;

  final http.Client _httpClient;
  String? _accessToken;

  PerformanceApi({http.Client? httpClient, String? accessToken})
    : _httpClient = httpClient ?? http.Client(),
      _accessToken = accessToken;

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    // Fall back to the app-wide shared token so this client is authenticated
    // even when constructed without an explicit token (the common case).
    final token = _accessToken ?? ApiClient.sharedAccessToken;
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // ─── Club Performance ───────────────────────────────────────────────────────

  /// GET /bags/{bagId}/clubs/{clubId}/performance
  ///
  /// Fetches performance statistics for a specific club.
  /// Always returns 200; stats may be insufficient/empty.
  ///
  /// Throws [VspApiException] on network or HTTP errors.
  Future<ClubPerformanceApiResponse> getClubPerformance({
    required int bagId,
    required int clubId,
  }) async {
    final uri = Uri.parse('$_baseUrl/bags/$bagId/clubs/$clubId/performance');

    http.Response response;
    try {
      response = await _httpClient
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 30));
    } on http.ClientException catch (ex) {
      throw VspApiException.network('Unable to reach the server: $ex');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ClubPerformanceApiResponse(
        stats: _parseClubPerformanceStats(json),
        cachedAt: _parseInstant(response.headers['date']),
      );
    }

    throw VspApiException.fromResponse(response);
  }

  // ─── Bag Performance ────────────────────────────────────────────────────────

  /// GET /bags/{bagId}/performance
  ///
  /// Fetches performance statistics for all clubs in a bag.
  ///
  /// Throws [VspApiException] on network or HTTP errors.
  Future<BagPerformanceApiResponse> getBagPerformance({
    required int bagId,
  }) async {
    final uri = Uri.parse('$_baseUrl/bags/$bagId/performance');

    http.Response response;
    try {
      response = await _httpClient
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 30));
    } on http.ClientException catch (ex) {
      throw VspApiException.network('Unable to reach the server: $ex');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return BagPerformanceApiResponse(
        performance: _parseBagPerformance(json),
        cachedAt: _parseInstant(response.headers['date']),
      );
    }

    throw VspApiException.fromResponse(response);
  }

  // ─── Dispersion Overlay ────────────────────────────────────────────────────

  /// GET /bags/{bagId}/clubs/{clubId}/dispersion?holeId={holeId}&layoutId={layoutId}
  ///
  /// Fetches dispersion overlay with scatter points and hazard features.
  ///
  /// Throws [VspApiException] on network or HTTP errors.
  Future<DispersionOverlayApiResponse> getDispersionOverlay({
    required int bagId,
    required int clubId,
    required int holeId,
    required int layoutId,
  }) async {
    final uri = Uri.parse('$_baseUrl/bags/$bagId/clubs/$clubId/dispersion')
        .replace(
          queryParameters: {
            'holeId': holeId.toString(),
            'layoutId': layoutId.toString(),
          },
        );

    http.Response response;
    try {
      response = await _httpClient
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 30));
    } on http.ClientException catch (ex) {
      throw VspApiException.network('Unable to reach the server: $ex');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return DispersionOverlayApiResponse(
        overlay: _parseDispersionOverlay(json),
      );
    }

    throw VspApiException.fromResponse(response);
  }

  // ─── Parsers ───────────────────────────────────────────────────────────────

  ClubPerformanceStats _parseClubPerformanceStats(Map<String, dynamic> json) {
    return ClubPerformanceStats(
      clubId: (json['clubId'] as num).toInt(),
      bagId: (json['bagId'] as num).toInt(),
      sampleSize: (json['sampleSize'] as num).toInt(),
      sampleSizeLabel: ClubPerformanceStats.parseSampleSizeLabel(
        json['sampleSizeLabel'] as String?,
      ),
      confidenceLevel: ClubPerformanceStats.parseConfidenceLevel(
        json['confidenceLevel'] as String?,
      ),
      recommendationsLocked: json['recommendationsLocked'] as bool? ?? true,
      carryAvg: _parseDouble(json['carryAvg']),
      carryMedian: _parseDouble(json['carryMedian']),
      carryStdDev: _parseDouble(json['carryStdDev']),
      carryMin: _parseDouble(json['carryMin']),
      carryMax: _parseDouble(json['carryMax']),
      totalAvg: _parseDouble(json['totalAvg']),
      totalMedian: _parseDouble(json['totalMedian']),
      totalStdDev: _parseDouble(json['totalStdDev']),
      totalMin: _parseDouble(json['totalMin']),
      totalMax: _parseDouble(json['totalMax']),
      leftRightAvg: _parseDouble(json['leftRightAvg']),
      leftRightStdDev: _parseDouble(json['leftRightStdDev']),
      shortLongAvg: _parseDouble(json['shortLongAvg']),
      shortLongStdDev: _parseDouble(json['shortLongStdDev']),
      computedAt: _parseInstantFromString(json['computedAt']),
      basedOnShotAt: _parseInstantFromString(json['basedOnShotAt']),
    );
  }

  BagPerformance _parseBagPerformance(Map<String, dynamic> json) {
    final bagId = (json['bagId'] as num).toInt();
    final clubsList = json['clubs'] as List<dynamic>? ?? [];
    final clubs = clubsList
        .map((e) => _parseClubPerformanceStats(e as Map<String, dynamic>))
        .toList();

    return BagPerformance(bagId: bagId, clubs: clubs);
  }

  DispersionOverlay _parseDispersionOverlay(Map<String, dynamic> json) {
    return DispersionOverlay(
      clubId: (json['clubId'] as num).toInt(),
      bagId: (json['bagId'] as num).toInt(),
      holeId: (json['holeId'] as num).toInt(),
      layoutId: (json['layoutId'] as num).toInt(),
      shotCount: (json['shotCount'] as num).toInt(),
      scatterGeoJSON:
          json['scatterGeoJSON'] as Map<String, dynamic>? ??
          {'type': 'FeatureCollection', 'features': []},
      hazardGeoJSON:
          json['hazardGeoJSON'] as Map<String, dynamic>? ??
          {'type': 'FeatureCollection', 'features': []},
      centerX: _parseDouble(json['centerX']),
      centerY: _parseDouble(json['centerY']),
      centerToHazardMeters: _parseDouble(json['centerToHazardMeters']),
      nearestHazardType: json['nearestHazardType'] as String?,
      outcomeCounts:
          (json['outcomeCounts'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ) ??
          {},
      computedAt: _parseInstantFromString(json['computedAt']),
    );
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  DateTime? _parseInstant(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  DateTime? _parseInstantFromString(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  void close() => _httpClient.close();
}
