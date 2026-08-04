// Course Search State — VSP Mobile App
//
// State classes for CourseSearchBloc covering all search modes and tabs.
//
// AC-1: text and geographic search with pagination.
// AC-2: nearby search uses index-aware spatial filtering (server-side).
// AC-3: results surface verification, data freshness, download, update state.

import 'package:equatable/equatable.dart';

import '../../../domain/models/course_search_result.dart';
import '../../../domain/models/favorite_course.dart';
import '../../../domain/models/recent_course.dart';

/// Search tab type.
enum SearchTab { all, nearby, favorites, recent }

/// Base state for course search.
abstract class CourseSearchState extends Equatable {
  final SearchTab activeTab;
  final String? lastQuery;
  final double? lastLatitude;
  final double? lastLongitude;
  final double? lastRadius;

  const CourseSearchState({
    this.activeTab = SearchTab.all,
    this.lastQuery,
    this.lastLatitude,
    this.lastLongitude,
    this.lastRadius,
  });

  @override
  List<Object?> get props => [
    activeTab,
    lastQuery,
    lastLatitude,
    lastLongitude,
    lastRadius,
  ];
}

// ─── Concrete States ────────────────────────────────────────────────────────

/// Initial state — no search performed yet.
class CourseSearchInitial extends CourseSearchState {
  const CourseSearchInitial() : super();
}

/// Loading state — search in progress.
class CourseSearchLoading extends CourseSearchState {
  const CourseSearchLoading({
    required super.activeTab,
    super.lastQuery,
    super.lastLatitude,
    super.lastLongitude,
    super.lastRadius,
  });
}

/// Search results loaded successfully.
class CourseSearchLoaded extends CourseSearchState {
  /// Search results (for all/nearby tabs).
  final List<CourseSearchResult> results;

  /// Current page number (0-indexed).
  final int page;

  /// Whether there is a next page.
  final bool hasNext;

  /// Whether a page load is in progress (pagination).
  final bool isLoadingMore;

  /// Whether results were loaded from cache (not fresh).
  final bool fromCache;

  const CourseSearchLoaded({
    required this.results,
    required this.page,
    required this.hasNext,
    this.isLoadingMore = false,
    this.fromCache = false,
    required super.activeTab,
    super.lastQuery,
    super.lastLatitude,
    super.lastLongitude,
    super.lastRadius,
  });

  CourseSearchLoaded copyWith({
    List<CourseSearchResult>? results,
    int? page,
    bool? hasNext,
    bool? isLoadingMore,
    bool? fromCache,
    SearchTab? activeTab,
    String? lastQuery,
    double? lastLatitude,
    double? lastLongitude,
    double? lastRadius,
  }) {
    return CourseSearchLoaded(
      results: results ?? this.results,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      fromCache: fromCache ?? this.fromCache,
      activeTab: activeTab ?? this.activeTab,
      lastQuery: lastQuery ?? this.lastQuery,
      lastLatitude: lastLatitude ?? this.lastLatitude,
      lastLongitude: lastLongitude ?? this.lastLongitude,
      lastRadius: lastRadius ?? this.lastRadius,
    );
  }

  @override
  List<Object?> get props => [
    ...super.props,
    results,
    page,
    hasNext,
    isLoadingMore,
    fromCache,
  ];
}

/// Favorites loaded successfully.
class CourseSearchFavoritesLoaded extends CourseSearchState {
  final List<FavoriteCourse> favorites;
  final bool isLoading;

  const CourseSearchFavoritesLoaded({
    required this.favorites,
    this.isLoading = false,
    super.activeTab = SearchTab.favorites,
  });

  CourseSearchFavoritesLoaded copyWith({
    List<FavoriteCourse>? favorites,
    bool? isLoading,
    SearchTab? activeTab,
  }) {
    return CourseSearchFavoritesLoaded(
      favorites: favorites ?? this.favorites,
      isLoading: isLoading ?? this.isLoading,
      activeTab: activeTab ?? this.activeTab,
    );
  }

  @override
  List<Object?> get props => [...super.props, favorites, isLoading];
}

/// Recent courses loaded successfully.
class CourseSearchRecentLoaded extends CourseSearchState {
  final List<RecentCourse> recentCourses;
  final bool isLoading;

  const CourseSearchRecentLoaded({
    required this.recentCourses,
    this.isLoading = false,
    super.activeTab = SearchTab.recent,
  });

  CourseSearchRecentLoaded copyWith({
    List<RecentCourse>? recentCourses,
    bool? isLoading,
    SearchTab? activeTab,
  }) {
    return CourseSearchRecentLoaded(
      recentCourses: recentCourses ?? this.recentCourses,
      isLoading: isLoading ?? this.isLoading,
      activeTab: activeTab ?? this.activeTab,
    );
  }

  @override
  List<Object?> get props => [...super.props, recentCourses, isLoading];
}

/// Error state.
class CourseSearchError extends CourseSearchState {
  final String message;
  final List<CourseSearchResult>? lastResults;

  const CourseSearchError({
    required this.message,
    this.lastResults,
    required super.activeTab,
    super.lastQuery,
    super.lastLatitude,
    super.lastLongitude,
    super.lastRadius,
  });

  @override
  List<Object?> get props => [...super.props, message, lastResults];
}
