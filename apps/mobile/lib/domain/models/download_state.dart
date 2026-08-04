// Download State — VSP Mobile App
//
// State machine for course package download lifecycle.
// Mirrors AC-1/AC-2/AC-3 from Story 4.3.
//
// States:
//   idle           — no download in progress or scheduled
//   fetching_manifest — fetching current manifest from server
//   downloading    — actively downloading package files
//   paused         — download paused by user
//   validating     — validating downloaded package
//   offline_ready  — package validated and ready for offline use
//   error          — download failed with error (see DownloadError)

/// Error types for download failures.
enum DownloadError {
  /// Network connectivity issue.
  networkError,

  /// Downloaded file checksum does not match manifest.
  checksumMismatch,

  /// Server manifest version is older than downloaded version.
  versionTooOld,

  /// Insufficient storage space.
  storageError,

  /// Server returned an unexpected response.
  serverError,

  /// Unknown error.
  unknown,
}

/// State machine for course package download lifecycle.
enum DownloadServiceState {
  /// No download in progress or scheduled.
  idle,

  /// Fetching current manifest from server to check for updates.
  fetchingManifest,

  /// Actively downloading package files from CDN.
  downloading,

  /// Download paused by user.
  paused,

  /// Validating downloaded package against manifest.
  validating,

  /// Package validated and ready for offline use.
  offlineReady,

  /// Download failed with error. Check [DownloadError] for details.
  error,
}
