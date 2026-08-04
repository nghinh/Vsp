// Course Search BLoC — VSP Mobile App
//
// State management for Course Search screen with tab bar (All / Nearby / Favorites / Recent).
//
// AC-1: text and geographic filters with paginated results.
// AC-2: nearby search uses index-aware spatial filtering (server-side).
// AC-3: results show verification, data freshness, download, and update state.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/api/course_search_api.dart';
import '../../../data/repositories/course_search_repository.dart';
import '../../../domain/models/course_search_result.dart';
import 'course_search_event.dart';
import 'course_search_state.dart';

/// BLoC for course search screen.
///
/// Manages:
/// - Text search with debounce
/// - Nearby search with GPS location
/// - Favorites list
/// - Recent courses list
/// - Pagination for search results
class CourseSearchBloc extends Bloc<CourseSearchEvent, CourseSearchState> {
  final CourseSearchRepository _repository;

  /// Debounce timer for text search.
  Timer? _debounceTimer;

  /// Default page size.
  static const int _pageSize = 20;

  CourseSearchBloc({required CourseSearchRepository repository})
    : _repository = repository,
      super(const CourseSearchInitial()) {
    on<SearchTextChanged>(_onSearchTextChanged);
    on<SearchSubmitted>(_onSearchSubmitted);
    on<SearchNearby>(_onSearchNearby);
    on<NearbyLocationUpdated>(_onNearbyLocationUpdated);
    on<LoadFavorites>(_onLoadFavorites);
    on<ToggleFavorite>(_onToggleFavorite);
    on<LoadRecent>(_onLoadRecent);
    on<RecordCourseView>(_onRecordCourseView);
    on<LoadNextPage>(_onLoadNextPage);
    on<RefreshResults>(_onRefreshResults);
    on<TabSwitched>(_onTabSwitched);
    on<DismissError>(_onDismissError);
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }

  // ─── Text Search ────────────────────────────────────────────────────────────

  Future<void> _onSearchTextChanged(
    SearchTextChanged event,
    Emitter<CourseSearchState> emit,
  ) async {
    _debounceTimer?.cancel();

    if (event.query.trim().isEmpty) {
      _debounceTimer = null;
      return;
    }

    // Debounce: wait 400ms before firing search
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      add(SearchSubmitted(event.query));
    });
  }

  Future<void> _onSearchSubmitted(
    SearchSubmitted event,
    Emitter<CourseSearchState> emit,
  ) async {
    final query = event.query.trim();
    if (query.isEmpty) return;

    emit(CourseSearchLoading(activeTab: SearchTab.all, lastQuery: query));

    try {
      final page = await _repository.searchCourses(
        CourseSearchParams(query: query, page: 0, size: _pageSize),
      );

      emit(
        CourseSearchLoaded(
          results: page.content,
          page: 0,
          hasNext: page.hasNext,
          activeTab: SearchTab.all,
          lastQuery: query,
        ),
      );
    } catch (ex) {
      emit(
        CourseSearchError(
          message: 'Search failed. Please try again.',
          activeTab: SearchTab.all,
          lastQuery: query,
        ),
      );
    }
  }

  // ─── Nearby Search ──────────────────────────────────────────────────────────

  Future<void> _onSearchNearby(
    SearchNearby event,
    Emitter<CourseSearchState> emit,
  ) async {
    // Location will come from NearbyLocationUpdated with actual GPS coords
    // For now, emit loading state — actual search is triggered by
    // NearbyLocationUpdated after GPS resolves
    emit(
      CourseSearchLoading(
        activeTab: SearchTab.nearby,
        lastRadius: event.radiusMeters,
      ),
    );
  }

  Future<void> _onNearbyLocationUpdated(
    NearbyLocationUpdated event,
    Emitter<CourseSearchState> emit,
  ) async {
    emit(
      CourseSearchLoading(
        activeTab: SearchTab.nearby,
        lastLatitude: event.latitude,
        lastLongitude: event.longitude,
        lastRadius: event.radiusMeters,
      ),
    );

    try {
      final page = await _repository.findNearbyCourses(
        latitude: event.latitude,
        longitude: event.longitude,
        radiusMeters: event.radiusMeters,
        page: 0,
        size: _pageSize,
      );

      emit(
        CourseSearchLoaded(
          results: page.content,
          page: 0,
          hasNext: page.hasNext,
          activeTab: SearchTab.nearby,
          lastLatitude: event.latitude,
          lastLongitude: event.longitude,
          lastRadius: event.radiusMeters,
        ),
      );
    } catch (ex) {
      emit(
        CourseSearchError(
          message: 'Failed to find nearby courses.',
          activeTab: SearchTab.nearby,
          lastLatitude: event.latitude,
          lastLongitude: event.longitude,
          lastRadius: event.radiusMeters,
        ),
      );
    }
  }

  // ─── Favorites ──────────────────────────────────────────────────────────────

  Future<void> _onLoadFavorites(
    LoadFavorites event,
    Emitter<CourseSearchState> emit,
  ) async {
    final currentState = state;

    if (currentState is CourseSearchFavoritesLoaded && !event.forceReload) {
      return; // Already loaded, use cache
    }

    emit(
      CourseSearchFavoritesLoaded(
        favorites: currentState is CourseSearchFavoritesLoaded
            ? currentState.favorites
            : const [],
        isLoading: true,
        activeTab: SearchTab.favorites,
      ),
    );

    try {
      final favorites = await _repository.getFavorites(
        forceReload: event.forceReload,
      );

      emit(
        CourseSearchFavoritesLoaded(
          favorites: favorites,
          isLoading: false,
          activeTab: SearchTab.favorites,
        ),
      );
    } catch (ex) {
      emit(
        CourseSearchError(
          message: 'Failed to load favorites.',
          activeTab: SearchTab.favorites,
        ),
      );
    }
  }

  Future<void> _onToggleFavorite(
    ToggleFavorite event,
    Emitter<CourseSearchState> emit,
  ) async {
    final currentState = state;

    // Optimistic toggle
    if (currentState is CourseSearchFavoritesLoaded) {
      final isFav = currentState.favorites.any(
        (f) => f.courseId == event.courseId,
      );

      if (isFav) {
        final updated = currentState.favorites
            .where((f) => f.courseId != event.courseId)
            .toList();
        emit(currentState.copyWith(favorites: updated));
        try {
          await _repository.removeFavorite(event.courseId);
        } catch (_) {
          // Revert on failure
          add(const LoadFavorites(forceReload: true));
        }
      } else {
        try {
          await _repository.addFavorite(event.courseId);
          final favorites = await _repository.getFavorites(forceReload: true);
          emit(currentState.copyWith(favorites: favorites));
        } catch (_) {
          add(const LoadFavorites(forceReload: true));
        }
      }
    }

    // Also update course card in results if on all/nearby tab
    if (currentState is CourseSearchLoaded) {
      try {
        await _repository.isFavorite(event.courseId);
      } catch (_) {
        // Ignore for results list
      }
    }
  }

  // ─── Recent Courses ─────────────────────────────────────────────────────────

  Future<void> _onLoadRecent(
    LoadRecent event,
    Emitter<CourseSearchState> emit,
  ) async {
    final currentState = state;

    if (currentState is CourseSearchRecentLoaded && !event.forceReload) {
      return; // Already loaded, use cache
    }

    emit(
      CourseSearchRecentLoaded(
        recentCourses: currentState is CourseSearchRecentLoaded
            ? currentState.recentCourses
            : const [],
        isLoading: true,
        activeTab: SearchTab.recent,
      ),
    );

    try {
      final recent = await _repository.getRecentCourses(
        forceReload: event.forceReload,
      );

      emit(
        CourseSearchRecentLoaded(
          recentCourses: recent,
          isLoading: false,
          activeTab: SearchTab.recent,
        ),
      );
    } catch (ex) {
      emit(
        CourseSearchError(
          message: 'Failed to load recent courses.',
          activeTab: SearchTab.recent,
        ),
      );
    }
  }

  Future<void> _onRecordCourseView(
    RecordCourseView event,
    Emitter<CourseSearchState> emit,
  ) async {
    try {
      await _repository.recordRecentView(event.courseId);
    } catch (_) {
      // Non-critical — swallow errors
    }
  }

  // ─── Pagination ─────────────────────────────────────────────────────────────

  Future<void> _onLoadNextPage(
    LoadNextPage event,
    Emitter<CourseSearchState> emit,
  ) async {
    final currentState = state;
    if (currentState is! CourseSearchLoaded) return;
    if (!currentState.hasNext || currentState.isLoadingMore) return;

    emit(currentState.copyWith(isLoadingMore: true));

    try {
      final CourseSearchPage page;
      if (currentState.activeTab == SearchTab.nearby &&
          currentState.lastLatitude != null &&
          currentState.lastLongitude != null) {
        page = await _repository.findNearbyCourses(
          latitude: currentState.lastLatitude!,
          longitude: currentState.lastLongitude!,
          radiusMeters: currentState.lastRadius ?? 50000,
          page: currentState.page + 1,
          size: _pageSize,
        );
      } else {
        page = await _repository.searchCourses(
          CourseSearchParams(
            query: currentState.lastQuery ?? '',
            page: currentState.page + 1,
            size: _pageSize,
          ),
        );
      }

      emit(
        CourseSearchLoaded(
          results: [...currentState.results, ...page.content],
          page: page.page,
          hasNext: page.hasNext,
          isLoadingMore: false,
          activeTab: currentState.activeTab,
          lastQuery: currentState.lastQuery,
          lastLatitude: currentState.lastLatitude,
          lastLongitude: currentState.lastLongitude,
          lastRadius: currentState.lastRadius,
        ),
      );
    } catch (ex) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onRefreshResults(
    RefreshResults event,
    Emitter<CourseSearchState> emit,
  ) async {
    final currentState = state;

    if (currentState is CourseSearchLoaded) {
      if (currentState.activeTab == SearchTab.nearby &&
          currentState.lastLatitude != null &&
          currentState.lastLongitude != null) {
        add(
          NearbyLocationUpdated(
            latitude: currentState.lastLatitude!,
            longitude: currentState.lastLongitude!,
            radiusMeters: currentState.lastRadius ?? 50000,
          ),
        );
      } else if (currentState.lastQuery != null) {
        add(SearchSubmitted(currentState.lastQuery!));
      }
    } else if (currentState is CourseSearchFavoritesLoaded) {
      add(const LoadFavorites(forceReload: true));
    } else if (currentState is CourseSearchRecentLoaded) {
      add(const LoadRecent(forceReload: true));
    }
  }

  // ─── Tab Switch ─────────────────────────────────────────────────────────────

  Future<void> _onTabSwitched(
    TabSwitched event,
    Emitter<CourseSearchState> emit,
  ) async {
    final tab = SearchTab.values[event.tabIndex];

    switch (tab) {
      case SearchTab.all:
        if (state is CourseSearchLoaded ||
            state is CourseSearchLoading ||
            state is CourseSearchError) {
          emit(
            CourseSearchLoaded(
              results: state is CourseSearchLoaded
                  ? (state as CourseSearchLoaded).results
                  : const [],
              page: state is CourseSearchLoaded
                  ? (state as CourseSearchLoaded).page
                  : 0,
              hasNext: state is CourseSearchLoaded
                  ? (state as CourseSearchLoaded).hasNext
                  : false,
              activeTab: SearchTab.all,
            ),
          );
        } else {
          emit(const CourseSearchInitial());
        }
        break;

      case SearchTab.nearby:
        await _onSearchNearby(const SearchNearby(), emit);
        break;

      case SearchTab.favorites:
        await _onLoadFavorites(const LoadFavorites(), emit);
        break;

      case SearchTab.recent:
        await _onLoadRecent(const LoadRecent(), emit);
        break;
    }
  }

  // ─── Error Dismiss ─────────────────────────────────────────────────────────

  void _onDismissError(DismissError event, Emitter<CourseSearchState> emit) {
    final currentState = state;
    if (currentState is CourseSearchError) {
      if (currentState.lastResults != null) {
        emit(
          CourseSearchLoaded(
            results: currentState.lastResults!,
            page: 0,
            hasNext: false,
            activeTab: currentState.activeTab,
            lastQuery: currentState.lastQuery,
            lastLatitude: currentState.lastLatitude,
            lastLongitude: currentState.lastLongitude,
            lastRadius: currentState.lastRadius,
          ),
        );
      } else {
        emit(const CourseSearchInitial());
      }
    }
  }
}
