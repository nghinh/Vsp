// Course Search BLoC Tests — VSP Mobile App
//
// Unit tests for CourseSearchBloc.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/features/course_search/presentation/course_search_bloc.dart';
import 'package:vsp_mobile/features/course_search/presentation/course_search_event.dart';
import 'package:vsp_mobile/features/course_search/presentation/course_search_state.dart';
import 'package:vsp_mobile/domain/models/course_search_result.dart';
import 'package:vsp_mobile/domain/models/favorite_course.dart';
import 'package:vsp_mobile/domain/models/recent_course.dart';
import 'package:vsp_mobile/domain/models/data_freshness.dart';
import 'package:vsp_mobile/data/repositories/course_search_repository.dart';
import 'package:vsp_mobile/data/api/course_search_api.dart';

import '../mocks/mock_course_search_repository.dart';

void main() {
  group('CourseSearchBloc', () {
    late MockCourseSearchRepository mockRepository;
    late CourseSearchBloc bloc;

    setUp(() {
      mockRepository = MockCourseSearchRepository();
      bloc = CourseSearchBloc(repository: mockRepository);
    });

    tearDown(() {
      bloc.close();
    });

    test('initial state is CourseSearchInitial', () {
      expect(bloc.state, isA<CourseSearchInitial>());
    });

    blocTest<CourseSearchBloc, CourseSearchState>(
      'LoadFavorites emits CourseSearchFavoritesLoaded on success',
      build: () {
        mockRepository.mockGetFavorites = [
          FavoriteCourse(
            courseId: 1,
            facilityId: 1,
            facilityName: 'Test Course',
            holesCount: 18,
            favoritedAt: DateTime.now(),
          ),
        ];
        return CourseSearchBloc(repository: mockRepository);
      },
      act: (bloc) => bloc.add(const LoadFavorites()),
      expect: () => [
        isA<CourseSearchFavoritesLoaded>().having(
          (s) => s.isLoading,
          'isLoading',
          true,
        ),
        isA<CourseSearchFavoritesLoaded>()
            .having((s) => s.favorites.length, 'favorites.length', 1)
            .having((s) => s.isLoading, 'isLoading', false),
      ],
    );

    blocTest<CourseSearchBloc, CourseSearchState>(
      'LoadFavorites emits error on failure',
      build: () {
        mockRepository.mockGetFavoritesError = Exception('Network error');
        return CourseSearchBloc(repository: mockRepository);
      },
      act: (bloc) => bloc.add(const LoadFavorites()),
      expect: () => [
        isA<CourseSearchFavoritesLoaded>(),
        isA<CourseSearchError>().having(
          (s) => s.message,
          'message',
          contains('Failed'),
        ),
      ],
    );

    blocTest<CourseSearchBloc, CourseSearchState>(
      'LoadRecent emits CourseSearchRecentLoaded on success',
      build: () {
        mockRepository.mockGetRecentCourses = [
          RecentCourse(
            courseId: 1,
            facilityId: 1,
            facilityName: 'Test Course',
            holesCount: 18,
            viewedAt: DateTime.now(),
          ),
        ];
        return CourseSearchBloc(repository: mockRepository);
      },
      act: (bloc) => bloc.add(const LoadRecent()),
      expect: () => [
        isA<CourseSearchRecentLoaded>().having(
          (s) => s.isLoading,
          'isLoading',
          true,
        ),
        isA<CourseSearchRecentLoaded>()
            .having((s) => s.recentCourses.length, 'recentCourses.length', 1)
            .having((s) => s.isLoading, 'isLoading', false),
      ],
    );

    blocTest<CourseSearchBloc, CourseSearchState>(
      'ToggleFavorite removes course from favorites',
      build: () {
        mockRepository.mockFavorites = [
          FavoriteCourse(
            courseId: 1,
            facilityId: 1,
            facilityName: 'Test Course',
            holesCount: 18,
            favoritedAt: DateTime.now(),
          ),
        ];
        return CourseSearchBloc(repository: mockRepository);
      },
      seed: () => CourseSearchFavoritesLoaded(
        favorites: [
          FavoriteCourse(
            courseId: 1,
            facilityId: 1,
            facilityName: 'Test Course',
            holesCount: 18,
            favoritedAt: DateTime.now(),
          ),
        ],
        isLoading: false,
        activeTab: SearchTab.favorites,
      ),
      act: (bloc) => bloc.add(const ToggleFavorite(1)),
      expect: () => [
        // Optimistic removal
        isA<CourseSearchFavoritesLoaded>().having(
          (s) => s.favorites.length,
          'favorites.length',
          0,
        ),
      ],
    );

    blocTest<CourseSearchBloc, CourseSearchState>(
      'SearchNearby emits loading then triggers NearbyLocationUpdated',
      build: () {
        mockRepository.mockNearbyPage = CourseSearchPage(
          content: [
            CourseSearchResult(
              courseId: 1,
              facilityId: 1,
              facilityName: 'Nearby Course',
              latitude: 21.0285,
              longitude: 105.8542,
              holesCount: 18,
              hasPackage: true,
              updateAvailable: false,
            ),
          ],
          page: 0,
          size: 20,
          totalElements: 1,
          totalPages: 1,
          first: true,
          last: true,
        );
        return CourseSearchBloc(repository: mockRepository);
      },
      act: (bloc) => bloc.add(
        const NearbyLocationUpdated(
          latitude: 21.0285,
          longitude: 105.8542,
          radiusMeters: 50000,
        ),
      ),
      expect: () => [
        isA<CourseSearchLoading>().having(
          (s) => s.activeTab,
          'activeTab',
          SearchTab.nearby,
        ),
        isA<CourseSearchLoaded>()
            .having((s) => s.results.length, 'results.length', 1)
            .having((s) => s.activeTab, 'activeTab', SearchTab.nearby),
      ],
    );

    blocTest<CourseSearchBloc, CourseSearchState>(
      'TabSwitched(2) triggers LoadFavorites',
      build: () {
        mockRepository.mockGetFavorites = [];
        return CourseSearchBloc(repository: mockRepository);
      },
      act: (bloc) => bloc.add(const TabSwitched(2)),
      // Loading placeholder (isLoading: true) then the loaded result.
      expect: () => [
        isA<CourseSearchFavoritesLoaded>(),
        isA<CourseSearchFavoritesLoaded>(),
      ],
    );

    blocTest<CourseSearchBloc, CourseSearchState>(
      'TabSwitched(3) triggers LoadRecent',
      build: () {
        mockRepository.mockRecentCourses = [];
        return CourseSearchBloc(repository: mockRepository);
      },
      act: (bloc) => bloc.add(const TabSwitched(3)),
      // Loading placeholder (isLoading: true) then the loaded result.
      expect: () => [
        isA<CourseSearchRecentLoaded>(),
        isA<CourseSearchRecentLoaded>(),
      ],
    );
  });
}
