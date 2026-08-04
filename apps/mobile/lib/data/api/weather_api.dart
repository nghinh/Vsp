// WeatherApi — VSP Mobile App
//
// Story 7.1 Wave 2: API Client
// Per slice plan §2.3 — calls GET /weather?lat={}&lng={} and parses response headers.
//
// Headers consumed:
// - X-Weather-Source: provider display name
// - X-Weather-Cached-At: cache timestamp
// - X-Weather-Fresh-Until: expiry timestamp
// - X-Weather-Stale: 'true' if served from stale cache

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/network/api_client.dart';
import '../../domain/models/weather_snapshot.dart';

/// Weather API response including parsed headers.
class WeatherApiResponse {
  final WeatherSnapshot snapshot;
  final String? sourceHeader;
  final DateTime? cachedAt;
  final DateTime? freshUntil;
  final bool staleFlag;

  const WeatherApiResponse({
    required this.snapshot,
    this.sourceHeader,
    this.cachedAt,
    this.freshUntil,
    this.staleFlag = false,
  });
}

/// API client for the /weather endpoint.
class WeatherApi {
  // Must match ApiClient._baseUrl
  static const String _baseUrl = String.fromEnvironment(
    'VSP_API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  final http.Client _httpClient;
  String? _accessToken;

  WeatherApi({http.Client? httpClient, String? accessToken})
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
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  /// GET /weather?lat={latitude}&lng={longitude}
  ///
  /// Fetches a fresh weather snapshot from the backend.
  /// Parses X-Weather-* response headers for cache metadata.
  ///
  /// Throws [VspApiException] on network or HTTP errors.
  Future<WeatherApiResponse> getWeather({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse('$_baseUrl/weather').replace(
      queryParameters: {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
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
      final snapshot = WeatherSnapshot.fromJson(json);
      final headers = response.headers;

      return WeatherApiResponse(
        snapshot: snapshot,
        sourceHeader: headers['x-weather-source'],
        cachedAt: _parseInstant(headers['x-weather-cached-at']),
        freshUntil: _parseInstant(headers['x-weather-fresh-until']),
        staleFlag: headers['x-weather-stale']?.toLowerCase() == 'true',
      );
    }

    throw VspApiException.fromResponse(response);
  }

  DateTime? _parseInstant(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
