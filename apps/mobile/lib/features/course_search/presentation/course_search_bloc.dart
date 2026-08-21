// Course Search BLoC — VSP Mobile App
//
// State management for Course Search screen with tab bar (All / Nearby / Favorites / Recent).
//
// AC-1: text and geographic filters with paginated results.
// AC-2: nearby search uses index-aware spatial filtering (server-side).
// AC-3: results show verification, data freshness, download, and update state.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_client.dart';
import '../../../data/api/course_search_api.dart';
import '../../../data/repositories/course_search_repository.dart';
import '../../../data/services/location_service_impl.dart';
import '../../../domain/models/course_search_result.dart';
import '../../../domain/models/qualified_location.dart';
import '../../../domain/services/location_service.dart';
import 'course_search_event.dart';
import 'course_search_state.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

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
  final LocationService _locationService;

  /// Debounce timer for text search.
  Timer? _debounceTimer;

  /// The last course list the "All" tab held.
  ///
  /// Four tabs share this one bloc, so a single state has to stand for all of
  /// them and the most recent load wins. Opening the screen fires three loads
  /// at once, and switching tabs fires more, so the All tab's results were
  /// routinely overwritten by whichever sibling finished last — and returning
  /// to All then rebuilt it with an empty list, leaving a golfer staring at an
  /// empty course picker. Holding the list here lets that tab be restored
  /// instead of blanked.
  CourseSearchLoaded? _lastAllResults;

  /// Default page size.
  static const int _pageSize = 20;

  CourseSearchBloc({
    required CourseSearchRepository repository,
    LocationService? locationService,
  }) : _repository = repository,
       _locationService = locationService ?? LocationServiceImpl(),
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
  void onChange(Change<CourseSearchState> change) {
    super.onChange(change);
    final next = change.nextState;
    if (next is CourseSearchLoaded && next.activeTab == SearchTab.all) {
      _lastAllResults = next;
    }
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
    // An empty query is a valid "browse all courses" request — the server
    // returns the full catalogue when no text/geo filter is supplied.
    final query = event.query.trim();

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
          favoriteCourseIds: await _loadFavoriteIds(),
        ),
      );
    } catch (ex) {
      if (_sessionIsOver(ex)) {
        emit(
          CourseSearchSessionExpired(
            activeTab: SearchTab.all,
            lastQuery: query,
          ),
        );
        return;
      }
      emit(
        CourseSearchError(
          message: AppMessages.courseSearchFailed,
          activeTab: SearchTab.all,
          lastQuery: query,
        ),
      );
    }
  }

  /// Whether this failure means the golfer is signed out.
  ///
  /// A 401 alone does not mean that, and reading it that way is dangerous on
  /// this app. [ApiClient] tries one refresh before the exception gets here,
  /// and that refresh fails two very different ways: the server answered and
  /// refused — the session is spent, [AuthRepository.logout] has already run
  /// and cleared the token — or the phone could not reach the server at all,
  /// which is the ordinary state of a golf course and leaves the stored
  /// session intact and still good.
  ///
  /// The token is what tells them apart. Signing a golfer out because a
  /// refresh could not get a bar of signal destroys a session the server would
  /// have honoured and strands them at a login screen they cannot pass.
  bool _sessionIsOver(Object ex) =>
      ex is VspApiException &&
      ex.statusCode == 401 &&
      ApiClient.sharedAccessToken == null;

  // ─── Nearby Search ──────────────────────────────────────────────────────────

  Future<void> _onSearchNearby(
    SearchNearby event,
    Emitter<CourseSearchState> emit,
  ) async {
    emit(
      CourseSearchLoading(
        activeTab: SearchTab.nearby,
        lastRadius: event.radiusMeters,
      ),
    );

    // Acquire the device location, then run the nearby search. Never leave the
    // tab spinning: a denied/disabled/timed-out fix emits an error state so the
    // UI can prompt the user to enable location and retry.
    try {
      final available = await _locationService.isLocationAvailable();
      if (!available) {
        emit(
          const CourseSearchError(
            message: AppMessages.locationPermissionNeeded,
            activeTab: SearchTab.nearby,
          ),
        );
        return;
      }
      final loc = await _locationService.getCurrentLocation();
      if (loc.source == LocationSource.unavailable) {
        emit(
          const CourseSearchError(
            message: AppMessages.locationUnavailable,
            activeTab: SearchTab.nearby,
          ),
        );
        return;
      }
      add(
        NearbyLocationUpdated(
          latitude: loc.latitude,
          longitude: loc.longitude,
          radiusMeters: event.radiusMeters,
        ),
      );
    } catch (_) {
      emit(
        const CourseSearchError(
          message: AppMessages.locationUnavailable,
          activeTab: SearchTab.nearby,
        ),
      );
    }
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
      if (_sessionIsOver(ex)) {
        emit(
          CourseSearchSessionExpired(
            activeTab: SearchTab.nearby,
            lastLatitude: event.latitude,
            lastLongitude: event.longitude,
            lastRadius: event.radiusMeters,
          ),
        );
        return;
      }
      emit(
        CourseSearchError(
          message: AppMessages.nearbyLoadFailed,
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
      if (_sessionIsOver(ex)) {
        emit(const CourseSearchSessionExpired(activeTab: SearchTab.favorites));
        return;
      }
      emit(
        CourseSearchError(
          message: AppMessages.favoritesLoadFailed,
          activeTab: SearchTab.favorites,
        ),
      );
    }
  }

  /// Adds or removes a favourite, from whichever tab the golfer is on.
  ///
  /// This only ever did the work when the state was CourseFavoritesLoaded —
  /// that is, only on the Favourites tab itself. Tapping the heart on a search
  /// result reached the second branch, which called isFavorite and threw the
  /// answer away: nothing was added, nothing removed, and the heart stayed
  /// hollow. Which is what "chức năng yêu thích chưa hoạt động" was.
  Future<void> _onToggleFavorite(
    ToggleFavorite event,
    Emitter<CourseSearchState> emit,
  ) async {
    final currentState = state;

    if (currentState is CourseSearchFavoritesLoaded) {
      final isFav =
          currentState.favorites.any((f) => f.courseId == event.courseId);

      // Optimistic, so the list reacts to the tap rather than to the network.
      emit(currentState.copyWith(
        favorites: isFav
            ? currentState.favorites
                .where((f) => f.courseId != event.courseId)
                .toList()
            : currentState.favorites,
      ));

      try {
        if (isFav) {
          await _repository.removeFavorite(event.courseId);
        } else {
          await _repository.addFavorite(event.courseId);
          emit(currentState.copyWith(
            favorites: await _repository.getFavorites(forceReload: true),
          ));
        }
      } catch (_) {
        add(const LoadFavorites(forceReload: true));
      }
      return;
    }

    if (currentState is CourseSearchLoaded) {
      final isFav = currentState.favoriteCourseIds.contains(event.courseId);
      final updated = Set<int>.from(currentState.favoriteCourseIds);
      isFav ? updated.remove(event.courseId) : updated.add(event.courseId);
      emit(currentState.copyWith(favoriteCourseIds: updated));

      try {
        if (isFav) {
          await _repository.removeFavorite(event.courseId);
        } else {
          await _repository.addFavorite(event.courseId);
        }
        _favoriteIds = updated;
      } catch (_) {
        // Put the heart back where it was rather than leaving it lying about
        // a favourite the server never took.
        emit(currentState.copyWith(
          favoriteCourseIds: currentState.favoriteCourseIds,
        ));
      }
    }
  }

  /// The favourites known to this bloc, so a results page can fill in its
  /// hearts without asking per card.
  Set<int> _favoriteIds = const {};

  /// Loads them once, quietly. A failure leaves the hearts hollow, which is
  /// the same as not knowing — and better than a search that fails because
  /// favourites did.
  Future<Set<int>> _loadFavoriteIds() async {
    try {
      final favorites = await _repository.getFavorites();
      _favoriteIds = favorites.map((f) => f.courseId).toSet();
    } catch (_) {
      // Leave whatever was known.
    }
    return _favoriteIds;
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
      if (_sessionIsOver(ex)) {
        emit(const CourseSearchSessionExpired(activeTab: SearchTab.recent));
        return;
      }
      emit(
        CourseSearchError(
          message: AppMessages.recentLoadFailed,
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
      if (_sessionIsOver(ex)) {
        emit(
          CourseSearchSessionExpired(
            activeTab: currentState.activeTab,
            lastQuery: currentState.lastQuery,
            lastLatitude: currentState.lastLatitude,
            lastLongitude: currentState.lastLongitude,
            lastRadius: currentState.lastRadius,
          ),
        );
        return;
      }
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
        final current = state;
        // Prefer whatever this tab last held. Rebuilding it from the current
        // state discarded the list whenever a sibling tab had replaced it,
        // which is the ordinary case: the screen loads favourites and recent
        // alongside the course list on open.
        if (current is CourseSearchLoaded) {
          emit(current.copyWith(activeTab: SearchTab.all));
        } else if (_lastAllResults != null) {
          emit(_lastAllResults!);
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
