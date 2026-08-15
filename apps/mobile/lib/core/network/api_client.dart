// API Client — Vietnam Smart Golf Platform Mobile App
//
// Wraps HTTP calls to the VSP backend API.
// All auth-related calls use the /auth/* endpoints.
// Base URL configured via environment/build config.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'vsp_endpoints.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

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
      final code = body['code'] as String? ?? 'UNKNOWN';
      // Known server codes map to message keys the UI translates. The server
      // speaks English — "An unexpected error occurred. Please contact
      // support with the correlation ID." reached a Vietnamese golfer
      // verbatim, photographed, from the bag performance screen. Field-level
      // validation messages still pass through: they name the field and the
      // bound, which is better than a generic sentence.
      final serverMessage = body['message'] as String?;
      final message = switch (code) {
        'VSP-ERR-INTERNAL-001' => AppMessages.serverError,
        _ => serverMessage ?? AppMessages.serverError,
      };
      return VspApiException(
        code: code,
        message: message,
        statusCode: response.statusCode,
        data: body['data'],
        field: body['field'] as String?,
      );
    } catch (_) {
      return VspApiException(
        code: 'PARSE_ERROR',
        message: AppMessages.responseParseFailed,
        statusCode: response.statusCode,
      );
    }
  }

  factory VspApiException.network(String message) {
    return VspApiException(code: 'NETWORK_ERROR', message: message);
  }

  /// Returns true if this is a 304 Not Modified response.
  bool get isNotModified => statusCode == 304;

  /// True when the server was never reached — no status code came back.
  ///
  /// The distinction is the difference between "your session is over" and "you
  /// are on the 4th fairway": the first should sign a golfer out, the second
  /// must not.
  bool get isNetworkError => code == 'NETWORK_ERROR' || statusCode == null;

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
  /// Base URL of the VSP API — see [VspEndpoints].
  static String get _baseUrl => VspEndpoints.apiBaseUrl;

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

  /// Exchanges the stored refresh token for a fresh access token.
  ///
  /// Set once by the auth layer at start-up. Null in tests and before sign-in,
  /// which simply means a 401 stays a 401.
  ///
  /// <strong>Why this exists.</strong> An access token lives one hour and was
  /// refreshed in exactly one place: session restore, at app launch. A round of
  /// golf lasts four. So from the second hour onward every authenticated
  /// request failed with 401 — and the sync queue classifies 401 as retryable,
  /// tries five times, then marks the event permanently failed. A golfer's
  /// scores, shots and corrections from holes 5 through 18 were being written
  /// to the phone, rejected by the server, and given up on, with nothing on
  /// screen saying so.
  static Future<bool> Function()? refreshAccessToken;

  /// True while a refresh is in flight, so a burst of queued requests all
  /// hitting 401 at once produces one refresh rather than a dozen.
  static Future<bool>? _refreshInFlight;

  /// Refreshes the access token at most once per burst.
  ///
  /// Returns false when there is no refresh hook, no refresh token, or the
  /// server refused — in which case the caller should let the 401 stand rather
  /// than retrying into a loop.
  static Future<bool> _refreshOnce() {
    final refresh = refreshAccessToken;
    if (refresh == null) return Future.value(false);
    return _refreshInFlight ??= refresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  /// Whether a 401 from [path] is worth refreshing for.
  ///
  /// Never for the auth endpoints themselves: a refused login is a refused
  /// login, and refreshing on the refresh call is how a loop starts.
  static bool _isRefreshable(String path) => !path.startsWith('/auth/');

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
    /// False on the retry that follows a token refresh, so one lapsed token
    /// cannot turn into an endless chain of refreshes.
    bool retryOnUnauthorized = true,
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
      throw VspApiException.network(AppMessages.networkError);
    } on http.ClientException catch (ex) {
      debugPrint('[ApiClient] HTTP error: $ex');
      throw VspApiException.network(AppMessages.networkError);
    } catch (ex) {
      debugPrint('[ApiClient] Unexpected error: $ex');
      throw VspApiException.network(AppMessages.serverError);
    }

    // The token lapsed mid-session. Refresh once and repeat the request, with
    // the same idempotency key so a write the server already accepted replays
    // instead of duplicating. Guarded by `retryOnUnauthorized` so the retry
    // itself cannot recurse.
    if (response.statusCode == 401 &&
        retryOnUnauthorized &&
        _isRefreshable(path) &&
        await _refreshOnce()) {
      return request(
        path: path,
        method: method,
        body: body,
        queryParams: queryParams,
        idempotencyKey: idempotencyKey,
        headers: headers,
        retryOnUnauthorized: false,
      );
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
  }) => sendForReplay(
    method: 'POST',
    path: path,
    body: body,
    idempotencyKey: idempotencyKey,
  );

  /// Send any idempotent write and return the raw response with its headers.
  ///
  /// The sync queue needs more than POST: a finished shot is a
  /// `PATCH /shots/{id}`, a discarded one is a `DELETE /shots/{id}`. Those are
  /// the endpoints the API actually exposes, and a queue that can only POST
  /// cannot reach them.
  ///
  /// [body] is omitted entirely when null, because DELETE carries none.
  Future<http.Response> sendForReplay({
    required String method,
    required String path,
    required String idempotencyKey,
    Map<String, dynamic>? body,
  }) async {
    final response = await _sendOnce(
      method: method,
      path: path,
      idempotencyKey: idempotencyKey,
      body: body,
    );

    // One retry behind a fresh token. The request carries the same
    // Idempotency-Key, so a server that did process the first attempt before
    // the token lapsed replays rather than duplicating.
    if (response.statusCode == 401 && _isRefreshable(path)) {
      if (await _refreshOnce()) {
        return _sendOnce(
          method: method,
          path: path,
          idempotencyKey: idempotencyKey,
          body: body,
        );
      }
    }
    return response;
  }

  Future<http.Response> _sendOnce({
    required String method,
    required String path,
    required String idempotencyKey,
    Map<String, dynamic>? body,
  }) {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = _headers(idempotencyKey: idempotencyKey);
    final encoded = body == null ? null : jsonEncode(body);

    final Future<http.Response> pending;
    switch (method) {
      case 'POST':
        pending = _httpClient.post(uri, headers: headers, body: encoded);
      case 'PATCH':
        pending = _httpClient.patch(uri, headers: headers, body: encoded);
      case 'PUT':
        pending = _httpClient.put(uri, headers: headers, body: encoded);
      case 'DELETE':
        pending = _httpClient.delete(uri, headers: headers, body: encoded);
      default:
        throw ArgumentError.value(method, 'method', 'Unsupported sync method');
    }
    return pending.timeout(const Duration(seconds: 30));
  }

  void close() => _httpClient.close();
}
