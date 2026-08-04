// Course Search Events — VSP Mobile App
//
// Events for CourseSearchBloc covering all search modes and user actions.
//
// AC-1: text and geographic search with pagination.
// AC-2: nearby search uses index-aware spatial filtering (server-side).
// AC-3: results surface verification, data freshness, download, update state.

import 'package:equatable/equatable.dart';

/// Base event for course search.
abstract class CourseSearchEvent extends Equatable {
  const CourseSearchEvent();

  @override
  List<Object?> get props => [];
}

// ─── Text Search ─────────────────────────────────────────────────────────────

/// Trigger text search when query string changes.
class SearchTextChanged extends CourseSearchEvent {
  final String query;

  const SearchTextChanged(this.query);

  @override
  List<Object?> get props => [query];
}

/// Submit text search query.
class SearchSubmitted extends CourseSearchEvent {
  final String query;

  const SearchSubmitted(this.query);

  @override
  List<Object?> get props => [query];
}

// ─── Nearby Search ────────────────────────────────────────────────────────────

/// Trigger nearby search using device GPS location.
class SearchNearby extends CourseSearchEvent {
  /// Search radius in meters.
  final double radiusMeters;

  const SearchNearby({this.radiusMeters = 50000}); // default 50km

  @override
  List<Object?> get props => [radiusMeters];
}

/// Update location and re-trigger nearby search.
class NearbyLocationUpdated extends CourseSearchEvent {
  final double latitude;
  final double longitude;
  final double radiusMeters;

  const NearbyLocationUpdated({
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 50000,
  });

  @override
  List<Object?> get props => [latitude, longitude, radiusMeters];
}

// ─── Favorites ───────────────────────────────────────────────────────────────

/// Load favorited courses.
class LoadFavorites extends CourseSearchEvent {
  final bool forceReload;

  const LoadFavorites({this.forceReload = false});

  @override
  List<Object?> get props => [forceReload];
}

/// Toggle favorite status for a course.
class ToggleFavorite extends CourseSearchEvent {
  final int courseId;

  const ToggleFavorite(this.courseId);

  @override
  List<Object?> get props => [courseId];
}

// ─── Recent Courses ─────────────────────────────────────────────────────────

/// Load recently viewed courses.
class LoadRecent extends CourseSearchEvent {
  final bool forceReload;

  const LoadRecent({this.forceReload = false});

  @override
  List<Object?> get props => [forceReload];
}

/// Record a course view.
class RecordCourseView extends CourseSearchEvent {
  final int courseId;

  const RecordCourseView(this.courseId);

  @override
  List<Object?> get props => [courseId];
}

// ─── Pagination ─────────────────────────────────────────────────────────────

/// Load next page of search results.
class LoadNextPage extends CourseSearchEvent {
  const LoadNextPage();
}

/// Refresh current search results.
class RefreshResults extends CourseSearchEvent {
  const RefreshResults();
}

// ─── Tab Switch ─────────────────────────────────────────────────────────────

/// Switch active tab.
class TabSwitched extends CourseSearchEvent {
  final int tabIndex;

  const TabSwitched(this.tabIndex);

  @override
  List<Object?> get props => [tabIndex];
}

// ─── Error Dismiss ─────────────────────────────────────────────────────────

/// Dismiss error state.
class DismissError extends CourseSearchEvent {
  const DismissError();
}
