// Course Update State — VSP Mobile App
//
// Represents the result of checking for a package update.
// Story 4.4 INC-MOBILE-VC: version check state machine.

/// Result of checking for a package update.
sealed class CourseUpdateState {}

/// No update available — client has the latest version.
class UpdateNotAvailable extends CourseUpdateState {
  UpdateNotAvailable();
}

/// An update is available — new manifest returned.
class UpdateAvailable extends CourseUpdateState {
  final String etag;
  final int courseId;

  UpdateAvailable({required this.etag, required this.courseId});
}

/// Update check failed due to an error.
class UpdateCheckFailed extends CourseUpdateState {
  final String message;
  final bool isNetworkError;

  UpdateCheckFailed({required this.message, this.isNetworkError = false});
}
