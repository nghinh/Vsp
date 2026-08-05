// API Client — Vietnam Smart Golf Platform Mobile App
//
// Wraps HTTP calls to the VSP backend API.
// All auth-related calls use the /auth/* endpoints.
// Base URL configured via environment/build config.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// VSP API error with structured code, message, and optional field context.
class VspApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  final dynamic data;

  /// The field that caused the error, if the error is field-level.
  /// Maps to the "field" property in the backend ErrorResponse.
  final String? field;

  const VspApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.data,
    this.field,
  });

  factory VspApiException.fromHttpException(HttpException ex) {
    return VspApiException(code: 'NETWORK_ERROR', message: ex.message);
  }

  factory VspApiException.fromResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return VspApiException(
        code: body['code'] as String? ?? 'UNKNOWN',
        message: body['message'] as String? ?? 'An error occurred',
        statusCode: response.statusCode,
        data: body['data'],
        field: body['field'] as String?,
      );
    } catch (_) {
      return VspApiException(
        code: 'PARSE_ERROR',
        message: 'Failed to parse server response',
        statusCode: response.statusCode,
      );
    }
  }

  factory VspApiException.network(String message) {
    return VspApiException(code: 'NETWORK_ERROR', message: message);
  }

  /// Returns true if this is a 304 Not Modified response.
  bool get isNotModified => statusCode == 304;

  @override
  String toString() => 'VspApiException($code): $message';
}

/// Special response for 304 Not Modified ETag check.
class NotModifiedResponse {
  const NotModifiedResponse();
}

/// HTTP methods supported by the API client.
enum HttpMethod { get, post, put, patch, delete }

/// API client for VSP backend.
class ApiClient {
  /// Base URL of the VSP API.
  /// In development, point to local backend.
  /// In production, point to deployed API endpoint.
  static const String _baseUrl = String.fromEnvironment(
    'VSP_API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  final http.Client _httpClient;

  /// Access token shared across every [ApiClient] instance.
  ///
  /// Feature screens each build their own [ApiClient], but they all represent
  /// the same signed-in user, so the bearer token is held statically. Setting
  /// it once after login/session-restore authenticates every client (and
  /// clearing it on logout de-authenticates them all).
  static String? _accessToken;

  ApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  /// Set the access token for authenticated requests (shared across clients).
  void setAccessToken(String? token) {
    _accessToken = token;
  }

  /// The shared bearer token, so other API clients (e.g. PerformanceApi) can
  /// authenticate with the same session instead of holding their own token.
  static String? get sharedAccessToken => _accessToken;

  /// Build request headers including auth token, idempotency key, and custom headers.
  Map<String, String> _headers({
    String? idempotencyKey,
    Map<String, String>? extra,
  }) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    if (idempotencyKey != null) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  /// Make an HTTP request to the API.
  Future<dynamic> request({
    required String path,
    required HttpMethod method,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    String? idempotencyKey,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl$path',
    ).replace(queryParameters: queryParams);

    http.Response response;
    try {
      switch (method) {
        case HttpMethod.get:
          response = await _httpClient
              .get(
                uri,
                headers: _headers(
                  idempotencyKey: idempotencyKey,
                  extra: headers,
                ),
              )
              .timeout(const Duration(seconds: 30));
        case HttpMethod.post:
          response = await _httpClient
              .post(
                uri,
                headers: _headers(
                  idempotencyKey: idempotencyKey,
                  extra: headers,
                ),
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(const Duration(seconds: 30));
        case HttpMethod.put:
          response = await _httpClient
              .put(
                uri,
                headers: _headers(
                  idempotencyKey: idempotencyKey,
                  extra: headers,
                ),
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(const Duration(seconds: 30));
        case HttpMethod.patch:
          response = await _httpClient
              .patch(
                uri,
                headers: _headers(
                  idempotencyKey: idempotencyKey,
                  extra: headers,
                ),
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(const Duration(seconds: 30));
        case HttpMethod.delete:
          response = await _httpClient
              .delete(
                uri,
                headers: _headers(
                  idempotencyKey: idempotencyKey,
                  extra: headers,
                ),
              )
              .timeout(const Duration(seconds: 30));
      }
    } on SocketException catch (ex) {
      debugPrint('[ApiClient] Network error: $ex');
      throw VspApiException.network(
        'Check your internet connection and try again.',
      );
    } on http.ClientException catch (ex) {
      debugPrint('[ApiClient] HTTP error: $ex');
      throw VspApiException.network(
        'Unable to reach the server. Try again later.',
      );
    } catch (ex) {
      debugPrint('[ApiClient] Unexpected error: $ex');
      throw VspApiException.network('An unexpected error occurred. Try again.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    throw VspApiException.fromResponse(response);
  }

  /// GET request.
  Future<dynamic> get(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
  }) {
    return request(
      path: path,
      method: HttpMethod.get,
      queryParams: queryParams,
      headers: headers,
    );
  }

  /// POST request with JSON body.
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
    Map<String, String>? headers,
  }) {
    return request(
      path: path,
      method: HttpMethod.post,
      body: body,
      idempotencyKey: idempotencyKey,
      headers: headers,
    );
  }

  /// PUT request with JSON body and optional idempotency key.
  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
    Map<String, String>? headers,
  }) {
    return request(
      path: path,
      method: HttpMethod.put,
      body: body,
      idempotencyKey: idempotencyKey,
      headers: headers,
    );
  }

  /// DELETE request.
  Future<dynamic> delete(String path, {Map<String, String>? headers}) {
    return request(path: path, method: HttpMethod.delete, headers: headers);
  }

  /// GET request and return raw http.Response for access to headers (e.g., ETag).
  Future<http.Response> getRaw(
    String path, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    return _httpClient
        .get(uri, headers: _headers(extra: headers))
        .timeout(const Duration(seconds: 30));
  }

  /// POST with idempotency key and return raw response with headers.
  ///
  /// Used by [IdempotencyClient] to check the `X-Idempotent-Replay` header
  /// for server-side deduplication detection.
  Future<http.Response> postForReplay({
    required String path,
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    return _httpClient
        .post(
          uri,
          headers: _headers(idempotencyKey: idempotencyKey),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
  }

  void close() => _httpClient.close();
}
