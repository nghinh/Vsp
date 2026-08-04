// Package Content Type Enum — VSP Mobile App
//
// Content type classification for files within a course package.
// Mirrors PackageFileEntry.ContentType from the backend entity (Story 4.1 PKG-CONTRACT-2).

/// Content type classification for package files.
enum PackageContentType {
  METADATA,
  GEOMETRY,
  TILES,
  SCORECARD,
  RULES,
  CONDITIONS,
  WEATHER,
  SATELLITE;

  /// Parse from API response string.
  static PackageContentType fromString(String value) {
    return PackageContentType.values.firstWhere(
      (e) => e.name == value.toUpperCase(),
      orElse: () => PackageContentType.METADATA,
    );
  }
}
