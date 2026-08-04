// WeatherError — VSP Mobile App
//
// Story 7.1 Wave 2: Error types for weather operations.

/// Errors that can occur when fetching or caching weather data.
enum WeatherErrorCode {
  /// Network unavailable and no cached data.
  networkUnavailable,

  /// API returned an error response.
  apiError,

  /// Provider returned an invalid or unexpected response.
  providerError,

  /// No cached data available and network request failed.
  cacheMiss,

  /// Cached data has expired.
  cacheExpired,

  /// Location services unavailable.
  locationUnavailable,

  /// Generic unknown error.
  unknown,
}

/// Weather operation error with code and message.
class WeatherError {
  final WeatherErrorCode code;
  final String message;
  final int? statusCode;

  const WeatherError({
    required this.code,
    required this.message,
    this.statusCode,
  });

  factory WeatherError.network([String? message]) => WeatherError(
    code: WeatherErrorCode.networkUnavailable,
    message: message ?? 'Network unavailable',
  );

  factory WeatherError.api(int? statusCode, String message) => WeatherError(
    code: WeatherErrorCode.apiError,
    message: message,
    statusCode: statusCode,
  );

  factory WeatherError.provider(String message) =>
      WeatherError(code: WeatherErrorCode.providerError, message: message);

  factory WeatherError.cacheMiss() => const WeatherError(
    code: WeatherErrorCode.cacheMiss,
    message: 'No cached weather data available',
  );

  factory WeatherError.cacheExpired() => const WeatherError(
    code: WeatherErrorCode.cacheExpired,
    message: 'Cached weather data has expired',
  );

  factory WeatherError.locationUnavailable() => const WeatherError(
    code: WeatherErrorCode.locationUnavailable,
    message: 'Location services unavailable',
  );

  factory WeatherError.unknown([String? message]) => WeatherError(
    code: WeatherErrorCode.unknown,
    message: message ?? 'An unknown error occurred',
  );

  @override
  String toString() => 'WeatherError($code): $message';
}
